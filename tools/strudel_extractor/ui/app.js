// Strudel Extractor — page logic.
// Sections: 1 tap · 2 network tracker · 3 engine · 4 capture · 5 slicing · 6 encoders
//           7 settings · 8 rows UI · 9 render queue

// ---------------------------------------------------------------- 1. master tap
// Patched before any engine node exists: every connect() aimed at ctx.destination
// is rerouted through a tap gain, which feeds (a) the recorder worklet and
// (b) a monitor gain the owner can mute. Capturing inside the graph means system
// volume / monitor state never affect the recording.
const TAPS = new Map(); // AudioContext -> { input, monitor, mute, node? }
const origConnect = AudioNode.prototype.connect;

function tapFor(ctx) {
  let tap = TAPS.get(ctx);
  if (!tap) {
    const input = ctx.createGain();
    const monitor = ctx.createGain();
    const mute = ctx.createGain();
    mute.gain.value = 0;
    origConnect.call(input, monitor);
    origConnect.call(monitor, ctx.destination);
    origConnect.call(mute, ctx.destination);
    tap = { input, monitor, mute, node: null };
    TAPS.set(ctx, tap);
  }
  return tap;
}

AudioNode.prototype.connect = function (dest, ...rest) {
  try {
    if (dest instanceof AudioNode && dest === dest.context?.destination && !(this instanceof GainNode && TAPS.get(dest.context) &&
        [TAPS.get(dest.context).monitor, TAPS.get(dest.context).mute].includes(this))) {
      return origConnect.call(this, tapFor(dest.context).input, ...rest);
    }
  } catch (e) { console.warn('[extractor] tap reroute error', e); }
  return origConnect.call(this, dest, ...rest);
};

// ------------------------------------------------------- 2. network activity tracker
// Warm-up correctness depends on knowing when lazy sample/soundfont fetches settle.
let inflight = 0;
let lastNet = performance.now();
const origFetch = window.fetch.bind(window);
window.fetch = (...a) => {
  inflight += 1;
  lastNet = performance.now();
  return origFetch(...a).finally(() => { inflight -= 1; lastNet = performance.now(); });
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function networkQuiet(quietMs = 900, capMs = 45000) {
  const begun = performance.now();
  for (;;) {
    if (inflight === 0 && performance.now() - lastNet > quietMs) return true;
    if (performance.now() - begun > capMs) return false;
    await sleep(100);
  }
}

// ---------------------------------------------------------------- 3. engine
// Fidelity note (2026-08-09): the vendored @strudel/web 1.3.0 refused bare-scalar
// arithmetic on control patterns (m1/m2's `.off(…, x => x.add(-12))` octave-down
// echo silently played UNtransposed — the owner's "phantom high note"). Fixed by
// a marked patch inside vendor/strudel-web.js (search "EXTRACTOR PATCH") that
// remaps the scalar onto the note/n control, matching strudel.cc. A page-level
// wrapper is impossible: Pattern.prototype.add is a non-configurable getter.

// 4 s, not the design's 2 s: s7's reverb ring measured ~2.3 s to reach −60 dBFS
// (Milestone A, 2026-08-09). The silence scan trims the excess, so long tails only
// cost capture time, never file length.
const TAIL_SEC = 4;
const SILENCE_LIN = Math.pow(10, -60 / 20); // −60 dBFS
const SILENCE_RUN_SEC = 0.25;

let repl = null;
let ctx = null;
let tap = null;
let monitorOn = true;

async function ensureEngine(status) {
  if (repl) return;
  const S = window.strudel;
  status('loading engine…');
  const { registerSoundfonts } = await import('/vendor/soundfonts/index.mjs');
  const DOUGH = 'https://raw.githubusercontent.com/felixroos/dough-samples/main/';
  // Same prebake set strudel.cc uses, so the same names resolve to the same sounds.
  repl = await S.initStrudel({
    prebake: () => Promise.all([
      registerSoundfonts(),
      S.samples(DOUGH + 'tidal-drum-machines.json'),
      S.samples(DOUGH + 'piano.json'),
      S.samples(DOUGH + 'Dirt-Samples.json'),
      S.samples(DOUGH + 'EmuSP12.json'),
      S.samples(DOUGH + 'vcsl.json'),
    ]),
  });
  ctx = S.getAudioContext();
  await ctx.resume();
  // Load superdough's effect worklets EXPLICITLY and verify. @strudel/web defers
  // them to the NEXT real mousedown after init (initAudioOnFirstClick) — in an
  // automated run that click never comes, and every `.shape`/`.coarse`/`.crush`
  // voice dies silently per-trigger (the 2026-08-09 "missing chords" incident:
  // m1's bass + guitar were .shape voices). Fail LOUDLY if they didn't load —
  // a silent degrade wastes a whole listening pass.
  await S.initAudio();
  try {
    new AudioWorkletNode(ctx, 'shape-processor');
  } catch {
    banner('engine effect worklets failed to load — renders would silently drop .shape/.coarse voices');
    throw new Error('audio worklets not loaded');
  }
  tap = tapFor(ctx);
  await ctx.audioWorklet.addModule('/recorder.worklet.js');
  const node = new AudioWorkletNode(ctx, 'extractor-recorder', {
    numberOfInputs: 1, numberOfOutputs: 1, channelCount: 2, channelCountMode: 'explicit',
  });
  origConnect.call(tap.input, node);
  origConnect.call(node, tap.mute); // zero-gain path to destination keeps the worklet pulled
  node.port.onmessage = (e) => { if (captureState) captureState.chunks.push(e.data); };
  tap.node = node;
  tap.monitor.gain.value = monitorOn ? 1 : 0;
  setPatternPlaying(window.strudel.silence); // start the session-long free-running clock
  if (ctx.sampleRate !== 48000) {
    banner(`AudioContext runs at ${ctx.sampleRate} Hz (48000 expected) — files will be written at ${ctx.sampleRate} Hz.`);
  }
  status('');
}

// NEVER stop or reset the scheduler. Restarting the clock between queue items
// left it in a bad state — the 2nd file in a batch played with missing notes and
// wrong timings (owner-heard, 2026-08-09). The clock free-runs on silence for the
// whole session (the strudel.cc live-coding model); takes swap patterns in,
// shifted onto a future whole cycle with .late(c0).
function hushToSilence() {
  try { window.strudel.hush?.(); } catch {}
}

function setPatternPlaying(pat) {
  if (repl.setPattern) repl.setPattern(pat, true);
  else if (repl.scheduler?.setPattern) repl.scheduler.setPattern(pat, true);
  else throw new Error('no setPattern on repl/scheduler');
}

async function evalPattern(code, autostart) {
  const fn = repl?.evaluate?.bind(repl) ?? window.strudel.evaluate;
  const res = await fn(code, autostart);
  return res?.pattern ?? res ?? repl?.scheduler?.pattern ?? null;
}

function getCps(code) {
  const c = repl?.scheduler?.cps;
  if (Number.isFinite(c) && c > 0) return c;
  const m = code.match(/setcpm\s*\(([^)]+)\)/);
  if (m && /^[\d\s+*/().-]+$/.test(m[1])) {
    try { const cpm = Function(`return (${m[1]})`)(); if (cpm > 0) return cpm / 60; } catch {}
  }
  return 0.5; // strudel default (30 cpm)
}

function parseCpmForEstimate(code) {
  const m = code.match(/setcpm\s*\(([^)]+)\)/);
  if (m && /^[\d\s+*/().-]+$/.test(m[1])) {
    try { const cpm = Function(`return (${m[1]})`)(); if (cpm > 0) return cpm; } catch {}
  }
  return 30;
}

// Median clock sample: the AudioContext time when absolute cycle `cycleAbs`
// happens. Extrapolates FORWARD from the current position with the current cps —
// valid across earlier cps changes (each file sets its own cpm on a shared
// free-running clock, so never extrapolate back to cycle 0).
async function estimateCycleTime(cycleAbs, cps) {
  const sched = repl.scheduler;
  const samples = [];
  for (let i = 0; i < 7; i++) {
    samples.push(ctx.currentTime + (cycleAbs - sched.now()) / cps);
    await sleep(30);
  }
  samples.sort((a, b) => a - b);
  return samples[3];
}

// Pre-trigger every distinct sound the pattern will use (gain ≈ 0) so lazy
// sample/soundfont fetches complete before the recorded take. Deterministic
// completeness: the set comes from the pattern's own event query over the full
// render window, not from playback timing.
async function warmSounds(pat, endCycle) {
  if (!pat?.queryArc) return 'no pattern object — warm-up skipped';
  let haps = [];
  try { haps = pat.queryArc(0, Math.max(endCycle, 1)); } catch (e) { return `queryArc failed: ${e.message}`; }
  const uniq = new Map();
  for (const h of haps) {
    const v = h.value;
    if (v && typeof v === 'object' && v.s) {
      const key = `${v.s}|${v.bank ?? ''}|${v.n ?? ''}|${v.note ?? ''}`;
      if (!uniq.has(key)) uniq.set(key, v);
    }
  }
  const sd = window.strudel.superdough;
  for (const v of uniq.values()) {
    try { sd({ ...v, gain: 1e-4 }, ctx.currentTime + 0.05, 0.05); } catch (e) { console.warn('[extractor] warm trigger', v.s, e); }
  }
  await sleep(300); // let triggers issue their fetches before we start watching for quiet
  const settled = await networkQuiet();
  return settled ? null : 'network never went quiet during warm-up (30s+ cap) — sounds may be missing';
}

// ---------------------------------------------------------------- 4. capture
let captureState = null;

function startCapture() {
  captureState = { chunks: [] };
  tap.node.port.postMessage('start');
}

async function stopCapture() {
  tap.node.port.postMessage('stop');
  await sleep(200); // final flush crosses the worklet port
  const chunks = captureState.chunks;
  captureState = null;
  if (!chunks.length) throw new Error('no audio captured (tap delivered nothing)');
  chunks.sort((a, b) => a.frame - b.frame);
  const firstFrame = chunks[0].frame;
  const last = chunks[chunks.length - 1];
  const total = last.frame + last.l.length - firstFrame;
  const L = new Float32Array(total);
  const R = new Float32Array(total);
  for (const c of chunks) { L.set(c.l, c.frame - firstFrame); R.set(c.r, c.frame - firstFrame); }
  return { L, R, firstFrame };
}

// ---------------------------------------------------------------- 5. slicing
// Loops cut exactly on the cycle boundary — seamlessness comes from the cycle math;
// tails wrap into the loop by design.
function sliceLoop(L, R, i0, i1) {
  return { L: L.subarray(i0, i1), R: R.subarray(i0, i1), warn: null };
}

// One-shots keep their tail: extend past the boundary until sustained silence
// (< −60 dBFS for 250 ms), then cut at the start of that silence.
function sliceOneShot(L, R, i0, i1) {
  const sr = ctx.sampleRate;
  const need = Math.round(SILENCE_RUN_SEC * sr);
  let runStart = -1;
  let run = 0;
  for (let i = i1; i < L.length; i++) {
    if (Math.abs(L[i]) < SILENCE_LIN && Math.abs(R[i]) < SILENCE_LIN) {
      if (run === 0) runStart = i;
      run += 1;
      if (run >= need) return { L: L.subarray(i0, runStart), R: R.subarray(i0, runStart), warn: null };
    } else {
      run = 0;
    }
  }
  return { L: L.subarray(i0), R: R.subarray(i0), warn: 'tail never reached silence — kept full 2 s tail' };
}

// ---------------------------------------------------------------- 6. encoders
function encodeWav(L, R, sr) {
  const frames = L.length;
  const buf = new ArrayBuffer(44 + frames * 4);
  const v = new DataView(buf);
  const str = (off, s) => { for (let i = 0; i < s.length; i++) v.setUint8(off + i, s.charCodeAt(i)); };
  str(0, 'RIFF'); v.setUint32(4, 36 + frames * 4, true); str(8, 'WAVE');
  str(12, 'fmt '); v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 2, true);
  v.setUint32(24, sr, true); v.setUint32(28, sr * 4, true); v.setUint16(32, 4, true); v.setUint16(34, 16, true);
  str(36, 'data'); v.setUint32(40, frames * 4, true);
  let off = 44;
  for (let i = 0; i < frames; i++) {
    v.setInt16(off, Math.max(-32768, Math.min(32767, Math.round(L[i] * 32767))), true);
    v.setInt16(off + 2, Math.max(-32768, Math.min(32767, Math.round(R[i] * 32767))), true);
    off += 4;
  }
  return new Uint8Array(buf);
}

let oggEncoder = null;
async function encodeOgg(L, R, sr) {
  if (!oggEncoder) {
    // UMD build + separate wasm binary (the package's ES build has unbundled
    // @swc/helpers imports — see IMPLEMENTATION-NOTES.md).
    const wasm = await (await fetch('/vendor/ogg-encoder/ogg.wasm')).arrayBuffer();
    oggEncoder = await window.WasmMediaEncoder.createEncoder('audio/ogg', wasm);
  }
  oggEncoder.configure({ channels: 2, sampleRate: sr, vbrQuality: 6 }); // ≈192 kbps
  const parts = [];
  const CHUNK = 128 * 1024;
  for (let off = 0; off < L.length; off += CHUNK) {
    // encode() returns a view into wasm memory invalidated by the next call — copy.
    const out = oggEncoder.encode([L.subarray(off, off + CHUNK), R.subarray(off, off + CHUNK)]);
    if (out.length) parts.push(out.slice());
  }
  parts.push(oggEncoder.finalize().slice());
  const total = parts.reduce((n, p) => n + p.length, 0);
  const all = new Uint8Array(total);
  let off = 0;
  for (const p of parts) { all.set(p, off); off += p.length; }
  return all;
}

async function save(name, bytes) {
  const res = await fetch(`/save?name=${encodeURIComponent(name)}`, { method: 'POST', body: bytes });
  if (!res.ok) throw new Error(`save failed: ${await res.text()}`);
}

// ---------------------------------------------------------------- 7. settings
const LS_KEY = 'strudelExtractor.settings.v1';
const store = (() => { try { return JSON.parse(localStorage.getItem(LS_KEY)) ?? {}; } catch { return {}; } })();
const settingsFor = (name) => store[name] ?? { a: 0, b: 1, wav: true, ogg: false };
function remember(name, s) { store[name] = s; localStorage.setItem(LS_KEY, JSON.stringify(store)); }

// ---------------------------------------------------------------- 8. rows UI
const $ = (id) => document.getElementById(id);
const rows = [];
let running = false;
let abortAfterCurrent = false;

function banner(msg) { const b = $('banner'); b.textContent = msg; b.style.display = 'block'; }

function fmtTime(sec) {
  sec = Math.max(0, Math.round(sec));
  return `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`;
}

function setStatus(row, cls, text) {
  row.statusEl.className = `status ${cls}`;
  row.statusEl.textContent = text;
}

function addRow(name, { adhoc = false, source = null } = {}) {
  const existing = rows.find((r) => r.file === name);
  if (existing) { if (source) existing.source = source; return existing; }
  const s = settingsFor(name);
  const row = { file: name, adhoc, source, ...s };
  const el = document.createElement('div');
  el.className = 'row';
  el.innerHTML = `
    <input type="checkbox" class="inc" checked>
    <span class="name">${name}${adhoc ? ' <span class="adhoc">(added)</span>' : ''}</span>
    cycles <input type="number" class="a" min="0" step="1" value="${s.a}">
    → <input type="number" class="b" min="0" step="1" value="${s.b}">
    <label><input type="checkbox" class="wav" ${s.wav ? 'checked' : ''}>wav</label>
    <label><input type="checkbox" class="ogg" ${s.ogg ? 'checked' : ''}>ogg</label>
    <span class="status">queued</span>`;
  $('rows').appendChild(el);
  row.el = el;
  row.statusEl = el.querySelector('.status');
  row.incEl = el.querySelector('.inc');
  const sync = () => {
    row.a = parseFloat(el.querySelector('.a').value) || 0;
    row.b = parseFloat(el.querySelector('.b').value) || 0;
    row.wav = el.querySelector('.wav').checked;
    row.ogg = el.querySelector('.ogg').checked;
    remember(name, { a: row.a, b: row.b, wav: row.wav, ogg: row.ogg });
    updateOverall();
  };
  el.querySelectorAll('.a,.b,.wav,.ogg').forEach((i) => i.addEventListener('change', sync));
  row.incEl.addEventListener('change', () => { el.classList.toggle('disabled', !row.incEl.checked); updateOverall(); });
  rows.push(row);
  return row;
}

function estimateRowSec(row) {
  const cpm = row.cpm ?? 30;
  return (row.b - row.a) * (60 / cpm) + TAIL_SEC + 6; // +6 s warm-up/encode overhead guess
}

function updateOverall(text) {
  if (text !== undefined) { $('overall').textContent = text; return; }
  const inc = rows.filter((r) => r.incEl.checked);
  const done = inc.filter((r) => r.done).length;
  const leftSec = inc.filter((r) => !r.done).reduce((n, r) => n + estimateRowSec(r), 0);
  $('overall').textContent = inc.length ? `overall: ${done}/${inc.length}${running ? ` · ~${fmtTime(leftSec)} left` : ''}` : '';
}

async function loadRows() {
  const cfg = await (await fetch('/config')).json();
  $('inDir').textContent = cfg.inDir;
  $('outDir').textContent = cfg.outDir;
  const files = await (await fetch('/files')).json();
  for (const f of files) addRow(f);
  // prefetch sources just for cpm-based time estimates
  for (const row of rows) {
    try { row.cpm = parseCpmForEstimate(await (await fetch(`/file/${encodeURIComponent(row.file)}`)).text()); } catch {}
  }
  updateOverall();
}

// ---------------------------------------------------------------- 9. render queue
async function renderRow(row) {
  const base = row.file.replace(/\.strudel$/, '');
  const code = row.source ?? await (await fetch(`/file/${encodeURIComponent(row.file)}`)).text();
  row.cpm = parseCpmForEstimate(code);
  if (!(row.b > row.a)) throw new Error(`bad cycle window ${row.a}→${row.b}`);
  if (!row.wav && !row.ogg) throw new Error('no format selected');

  // Warm-up: engine muted, pattern queried for its full sound inventory, all fetches settled.
  // The clock keeps running on silence throughout; the eval may sound for a moment
  // (muted, unrecorded) before hush swaps silence back in.
  setStatus(row, 'busy', 'warming up…');
  tap.monitor.gain.value = 0;
  const pat = await evalPattern(code, false);
  hushToSilence();
  const warmNote = await warmSounds(pat, row.b);
  if (warmNote) console.warn(`[extractor] ${row.file}: ${warmNote}`);

  // Recorded take: swap the pattern onto the free-running clock, shifted by
  // .late(c0) so pattern-cycle 0 lands on a known future whole clock cycle.
  // Events are filtered to the render window BEFORE playing — nothing past the
  // end cycle is ever scheduled, so the tail is pure ring-out.
  tap.monitor.gain.value = monitorOn ? 1 : 0;
  // begin >= 0 too: the pattern is audible a fraction of a cycle BEFORE c0
  // (clock approaching the scheduled start), and negative cycles wrap `<...>`
  // alternations to their LAST entries — the owner heard "a bit of the song from
  // the wrong spot" as pre-roll. Not captured (slice starts at c0), but audible.
  const limited = pat?.filterHaps
    ? pat.filterHaps((h) => {
        const begin = h.whole?.begin ?? h.part?.begin ?? 0;
        return begin >= 0 && begin < row.b;
      })
    : pat;
  if (!limited?.late) throw new Error('no pattern object to play');
  const cps = getCps(code);
  const spc = 1 / cps;
  startCapture();
  await sleep(150);
  const c0 = Math.ceil(repl.scheduler.now() + Math.max(0.25, 0.75 * cps)); // ≥0.75 s lead
  setPatternPlaying(limited.late(c0));
  const tStart = await estimateCycleTime(c0 + row.a, cps);
  const nowCycle = repl.scheduler.now();
  if (!(nowCycle < c0 + 0.5)) {
    hushToSilence(); await stopCapture().catch(() => {});
    throw new Error(`clock overran the scheduled start (now=${nowCycle.toFixed(2)}, c0=${c0})`);
  }
  const totalSec = (row.b - row.a) * spc + TAIL_SEC;
  const tEnd = tStart + (row.b - row.a) * spc + TAIL_SEC;
  while (ctx.currentTime < tEnd) {
    if (captureState) {
      const el = Math.min(totalSec, Math.max(0, ctx.currentTime - tStart));
      setStatus(row, 'busy', `recording… ${fmtTime(el)}/${fmtTime(totalSec)}`);
    }
    await sleep(200);
  }
  hushToSilence();
  const { L, R, firstFrame } = await stopCapture();

  // Slice + encode per format.
  const i0 = Math.max(0, Math.round(tStart * ctx.sampleRate) - firstFrame);
  const i1 = Math.min(L.length, Math.round((tStart + (row.b - row.a) * spc) * ctx.sampleRate) - firstFrame);
  if (i1 <= i0) throw new Error('slice window empty — clock/capture mismatch');
  const warns = [];
  if (row.wav) {
    setStatus(row, 'busy', 'encoding wav…');
    const cut = sliceOneShot(L, R, i0, i1);
    if (cut.warn) warns.push(cut.warn);
    await save(`${base}.wav`, encodeWav(cut.L, cut.R, ctx.sampleRate));
  }
  if (row.ogg) {
    setStatus(row, 'busy', 'encoding ogg…');
    const cut = sliceLoop(L, R, i0, i1);
    await save(`${base}.ogg`, await encodeOgg(cut.L, cut.R, ctx.sampleRate));
  }
  row.done = true;
  setStatus(row, 'ok', warns.length ? `done ✓ (${warns.join('; ')})` : 'done ✓');
}

async function processAll() {
  if (running) { abortAfterCurrent = true; $('process').textContent = 'stopping…'; return; }
  running = true;
  abortAfterCurrent = false;
  $('process').textContent = 'Stop after current';
  try {
    await ensureEngine((t) => updateOverall(t));
    const queue = rows.filter((r) => r.incEl.checked);
    for (const row of queue) row.done = false;
    for (const row of queue) {
      if (abortAfterCurrent) { setStatus(row, '', 'skipped (stopped)'); continue; }
      try {
        await renderRow(row);
      } catch (e) {
        console.error(`[extractor] ${row.file} failed`, e);
        setStatus(row, 'fail', `FAILED (${e.message})`);
      }
      updateOverall();
      hushToSilence();
      await sleep(500);
    }
  } finally {
    running = false;
    $('process').textContent = 'Process files';
    tap && (tap.monitor.gain.value = monitorOn ? 1 : 0);
    updateOverall();
  }
}

// ---------------------------------------------------------------- wiring
$('process').addEventListener('click', () => { processAll(); });
$('monitor').addEventListener('click', () => {
  monitorOn = !monitorOn;
  $('monitor').textContent = monitorOn ? '🔊 monitor: on' : '🔇 monitor: off';
  if (tap) tap.monitor.gain.value = monitorOn ? 1 : 0;
});
$('addFile').addEventListener('click', () => $('filePicker').click());
$('filePicker').addEventListener('change', async (e) => {
  for (const f of e.target.files) addRow(f.name, { adhoc: true, source: await f.text() });
  updateOverall();
});
document.body.addEventListener('dragover', (e) => { e.preventDefault(); document.body.classList.add('drop'); });
document.body.addEventListener('dragleave', () => document.body.classList.remove('drop'));
document.body.addEventListener('drop', async (e) => {
  e.preventDefault();
  document.body.classList.remove('drop');
  for (const f of e.dataTransfer.files) {
    if (f.name.endsWith('.strudel')) addRow(f.name, { adhoc: true, source: await f.text() });
  }
  updateOverall();
});

loadRows();
