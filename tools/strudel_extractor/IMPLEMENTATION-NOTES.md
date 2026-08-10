# Strudel Extractor — Implementation Notes

**Built:** 2026-08-09/10 (one session). **Status:** all milestones done — 25/25 Animal Quickdraw assets rendered to `assets/audio/` (4 music OGGs from cycle 0, 21 WAVs), every duration exact to the cycle math; owner A/B-approved s7/s4/m2 against strudel.cc, then **listened to all 25 rendered files and approved the full bank (2026-08-10)**. Final renders were done ONE FILE PER PAGE SESSION (see README caution).
What was actually built vs [DESIGN.md](DESIGN.md), and the tricks the tool stands on. Read before modifying.

## Deviations from the design spec

| Spec said | Built | Why |
|-----------|-------|-----|
| `// render:` headers in each `.strudel` file (§4 original) | **In-app settings, localStorage persistence, sources never touched** | Owner decision at build session start (recorded in DESIGN.md Revisions). Timings are authored knowledge; the UI is the editor and localStorage is its invisible save file |
| Record until `end + TAIL`, slice afterwards | **Pattern is event-filtered to the window before playback** (`pat.filterHaps(h => h.whole.begin < end)`) | First s7 capture proved the flaw: the pattern keeps re-triggering during the tail window (cycle 2 restated the fanfare). Filtering ahead of time is arithmetic — no race against the scheduler's lookahead, and the tail is pure ring-out |
| `TAIL = 2 s` | **`TAIL_SEC = 4`** | Measured: s7's reverb takes ~2.3 s to fall below −60 dBFS. The silence scan trims the excess, so a generous tail costs capture time only |
| Warm-up = play the pattern muted ~1 cycle | **Query-based warm-up:** `pat.queryArc(0, end)` → unique `{s, bank, n, note}` set → pre-trigger each via `superdough()` at gain 1e-4 → wait for network quiet (no in-flight `fetch` for 900 ms, 45 s cap) | A 1-cycle mute pass misses instruments that first enter later (m1's layers enter across 104 cycles). Querying the pattern's own events is deterministic and complete; wrapping `window.fetch` with an in-flight counter tells us exactly when the lazy sample/soundfont fetches settle |
| Vendor `@strudel/web` + OGG encoder (2 files) | **Also vendored the soundfont stack** (`@strudel/soundfonts` + `sfumato` + `soundfont2` + a hand-written shim) | The `@strudel/web` 1.3.0 bundle has **zero** soundfont support (verified by grep) but the game's sources lean on `gm_*` instruments throughout. See vendor/VENDOR.md for the import-map/shim mechanism that keeps the registry in the same engine instance |
| Loop windows per the 2026-07-19 README table (m2 `8..40` etc.) | **Music loops render from cycle 0** (owner, this session): m2 `0..40`, m3-ambient `0..80`, m3-oompa `0..64`, m1 `0..104` | Owner wants the intro cycles in the loop files. Seam quality at the 0-wrap is the owner's listening call (the old offsets were phase-chosen) |

## The phantom-note hunt (engine-fidelity bug, 2026-08-09)

The owner's ear caught it during the first m2-lobby monitor listen: an occasional extra-high note absent on strudel.cc. The trail, worth keeping for the next drift bug:

1. Owner suspected the marimba voice. Isolated diagnostic captures (dropped in via the tool's own drag-and-drop path) + pitch analysis: **marimba clean**, every onset within ±15 cents of the expected {F4, A4, D5, F5}.
2. A hap dump of the e-piano line found it: `.off(1/8, x => x.add(-12).gain(.15))` echoes played **untransposed** — an A5 echo an eighth after each high A5 instead of the intended octave-down A4.
3. Root cause in `@strudel/web` 1.3.0 (newest npm release, Jan 2026): bare-scalar arithmetic on control patterns is a deliberate no-op — `ZA()` (the value-union) warns `"Can't do arithmetic on control pattern."` and returns the value unchanged. Even textbook `note("c3").add(12)` no-ops. strudel.cc's deployed engine (newer than any npm release) transposes.
4. **Fix:** marked patch inside `vendor/strudel-web.js` (search `EXTRACTOR PATCH`): when a bare scalar meets a control object in an arithmetic union, remap the scalar onto the object's `note` (else `n`) key. Verified: `note("c3").add(12)` → 60; m2 echoes → 69/65/62 (octave down); other controls untouched. A page-level wrapper was impossible — `Pattern.prototype.add` is a **non-configurable getter**.
5. Only m1 + m2 use this idiom (`grep '\.add('` over the sources), but the patch fixes the whole class.

**Lesson:** npm releases of Strudel lag the live site by months (site deploys from codeberg main). The Milestone A owner A/B is not a formality — it is the only detector for this class of bug. When a future project's sources sound wrong: dump haps first (`pat.queryArc`), compare values against intent, then patch the bundle minimally with a marked comment.

## The missing-voices hunt (worklet-init bug, 2026-08-09 — the batch killer)

Batch renders came out with **missing voices and mangled arrangements** (m1 lost its bass and guitar chords — both `.shape` voices — leaving the intro layers looping "over and over"), while some solo renders were fine. The console showed the mechanism: `[getTrigger] error … 'shape-processor' is not defined in AudioWorkletGlobalScope`, repeated per event — each affected **trigger dies silently** and everything else keeps playing.

Root cause: `@strudel/web` loads superdough's effect worklets (shape/coarse/crush/…) via **`initAudioOnFirstClick` — a one-shot document `mousedown` listener registered during `initStrudel()`**. The extractor initializes the engine *inside* the Process-click handler, so the listener registers just *after* the only real click — and in an automated/single-click session, the next mousedown never comes. Whether a given render had working effects depended on whether a human happened to click the page again after init. Nightmare property: nondeterministic, silent, and per-voice.

Fixes (both in `ensureEngine`):
1. `await strudel.initAudio()` explicitly after `initStrudel()` (the bundle exports it) — never rely on the click listener.
2. **Verify** by constructing a probe `AudioWorkletNode(ctx, 'shape-processor')` — if it throws, the row run aborts loudly. A silent degrade costs a whole listening pass; fail fast.

Related pre-roll fix: the free-running-clock take made the pattern audible a fraction of a cycle **before** its scheduled start (clock at `c0 − ε` queries negative pattern cycles, which wrap `<...>` alternations to their *last* entries — heard as "a bit of the song from the wrong spot"). The window filter now requires `begin >= 0` as well as `begin < end`. The pre-roll was never captured (slices start at `c0`), only audible on the monitor.

**Lesson for future drift/glitch hunts:** when voices go missing, grep the console for `getTrigger` FIRST — superdough drops failing voices per-trigger without stopping playback, so structural-sounding bugs (arrangement "wrong") can actually be per-voice construction failures.

## Load-bearing tricks (don't break these)

1. **The tap** (`app.js` §1): `AudioNode.prototype.connect` is patched *at module top, before any engine node exists*. Any `connect()` aimed at `ctx.destination` is rerouted into a per-context tap gain → recorder worklet (+ monitor gain → real destination). superdough's orbit effect returns (reverb/delay busses) connect to destination like everything else, so the capture contains exactly what the live site plays. The patch must exclude the tap's own monitor/mute nodes or it loops on itself.
2. **Frame-stamped capture** (`recorder.worklet.js`): each posted batch carries the AudioWorklet-global `currentFrame` of its first sample. Slice indices are computed as `round(ctxTime × sampleRate) − firstFrame` — no wall-clock anywhere.
3. **t0 estimation** (`app.js` `estimateT0`): `t0 = ctx.currentTime − scheduler.now()/cps`, median of 7 samples 30 ms apart. Works because the Cyclist scheduler's `getTime` IS `ctx.currentTime` (same clock domain). If a future Strudel swaps in the shared-worker NeoCyclist (performance.now domain), re-verify this mapping first.
4. **Event filtering, not hush timing** (see deviations table): never try to stop playback "at the boundary" — the scheduler schedules haps ahead of time; you will leak boundary events into the tail. Filter the pattern.
5. **The worklet must stay pulled:** its output runs through a zero-gain node to the destination. Disconnect that and `process()` stops being called (browsers don't run unpulled graph branches).
6. **Encoder buffers are transient:** `wasm-media-encoders`' `encode()` returns a view into wasm memory invalidated by the next call — `.slice()` every chunk before accumulating.
7. **UMD-under-ESM wrapper** (`vendor/soundfonts/soundfont2.mjs`): soundfont2@0.4.0 only ships a webpack UMD. Imported for side effects under ESM, `module`/`exports`/`define` are all undefined, so it takes its global branch (`window.SoundFont2`); the wrapper re-exports the two names sfumato needs. Keep the classic `<script src="/vendor/strudel-web.js">` tag *before* the module scripts — the shim reads `window.strudel` at module-eval time.

## Verified behavior (machine checks, 2026-08-09)

- **Milestone A (s7, 0..1 wav):** 5.95 s file = 4.000 s of music + 1.95 s decaying reverb tail, trimmed at the −60 dBFS/250 ms point (final 0.5 s: RMS −65.7 dBFS). The live tail present in the capture is precisely what native export drops. First onset lands ~50 ms after the slice start — a small uniform engine-latency shift; harmless for one-shots, and for loops it cancels at the seam (loops close on identical state, so the shifted content matches at both boundaries).
- **Pattern-repeat bug caught:** pre-filter, a `0..2` s7 take showed identical 4 s RMS blocks repeating into the tail (cycles restating). Post-filter: clean single statement + ring-out.
- Full pipeline (list → settings → capture → slice → encode → `POST /save`) exercised end-to-end through the browser UI.

## Known limits / v1 scope

- Changing the in/out folders means restarting the server command (browsers can't browse the disk). The page shows both paths.
- Drag-dropped (ad-hoc) rows don't survive a page reload — the browser can't re-read a dropped file; settings for them DO persist by filename.
- localStorage settings are per-browser-per-machine. Fresh machine = retype the handful of non-default windows (owner-accepted cost; see DESIGN.md Revisions).
- No loudness normalization / mastering — the wiring session (Godot import + bus gains) owns levels.
- The extractor assumes `setcpm(...)` appears literally in the source for its progress estimates; the *slicing* uses the engine clock and doesn't care.
