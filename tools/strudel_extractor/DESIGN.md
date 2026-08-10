# Strudel Extractor — Design Spec & Build Plan

**Status:** Owner-approved design (2026-07-19); revised at build-session start (2026-08-09) — see Revisions. Built 2026-08-09.

**Revisions (2026-08-09, owner decisions at build session):**
- **Named the Strudel Extractor**; lives in `tools/strudel_extractor/` (self-contained, copy-paste portable to other projects).
- **No `// render:` headers — the 25 `.strudel` sources are never touched.** Render settings (start cycle, end cycle, format) are edited in the app UI and remembered in browser localStorage keyed by filename. No sidecar file either (owner: cycle timings are authored knowledge, not hard-won data — retyping a handful of exceptions on a new machine is cheaper than managing a settings file). Baked fallback default: `0..1 wav`.
- **Drag-and-drop / file-picker queue additions:** individual `.strudel` files can be added to the list one at a time in addition to the `--in` folder scan; their settings are remembered the same way.
**Why this exists:** Strudel's native export (strudel.cc AND warm.strudel.cc, checked 2026-07-19) renders through an offline path that **drops the global effects bus** — every sound with `room` (reverb) or `delay` exports without its space. All 25 Animal Quickdraw sources (`TDD/sound/`) except the chat pop use `room`, so hand-exports are unusable. Live playback is correct; therefore this tool **captures live playback programmatically** instead of using the exporter.

**Product in one sentence:** a local web page (served by a zero-dependency Node script) that lists a folder of `.strudel` files, each row with cycle-window and WAV/OGG settings, and a Process button that plays each file through Strudel's real engine while tapping the master output, then writes finished audio files to an output folder.

---

## 1. Principles

- **No AI, no automation framework, no cloud.** A deterministic local tool: one Node script + one page + vendored libraries. The owner presses the button. Playwright explicitly rejected (owner risk requirement) — the human is the automation.
- **Correct by construction:** the capture taps the same live audio graph the strudel.cc site plays through (engine: `@strudel/web` / superdough). Reverb/delay busses included because we record what the engine actually outputs.
- **Sample-accurate by arithmetic:** slice points come from the engine clock's cycle→time mapping, never from human timing or silence detection.
- **Project-agnostic:** input and output folders are parameters. Defaults point at this repo, but the tool must work pointed at any folder of `.strudel` files (owner: reusable for other projects).
- **The `.strudel` sources are read-only inputs** — the tool never edits them; render settings live in the app (see §4, revised 2026-08-09).

## 2. Architecture

```
tools/strudel_extractor/
  DESIGN.md            (this file)
  README.md            usage + vendoring provenance (Milestone E)
  IMPLEMENTATION-NOTES.md  what was actually built + deviations (Milestone E)
  server.mjs           zero-dependency Node server (node:http + node:fs only)
  ui/
    index.html         the tool page
    app.js             UI + render queue + capture + slicing + encoding
    recorder.worklet.js  AudioWorklet: Float32 PCM tap
  vendor/
    strudel-web.js     vendored @strudel/web bundle (one-time download, committed)
    ogg-encoder/       vendored wasm OGG Vorbis encoder (e.g. wasm-media-encoders, MIT)
```

- **server.mjs** — `node server.mjs --in <dir> --out <dir> [--port 8123]`
  - Defaults: `--in TDD/sound` `--out assets/audio` (resolved from repo root).
  - Serves `ui/` + `vendor/`; API: `GET /files` (list `.strudel` file names), `GET /file/<name>` (source text), `POST /save` (body: file bytes + name → writes into `--out`, refuses paths outside it).
  - No npm dependencies. Node ≥ 20 (host has v25).
- **The page** — runs Strudel via the vendored bundle. Internet needed on first run per instrument (superdough fetches `gm_*` soundfonts from its CDN and caches them in the browser); after that, offline.
- **Vendoring note for the build session:** grab the `@strudel/web` browser bundle (jsDelivr/unpkg, pin the version in a comment) and a wasm Vorbis encoder; commit both. Licenses: Strudel is AGPL — fine, the tool is internal and ships nothing into the game but the owner's rendered audio.

## 3. UI spec

```
STRUDEL EXTRACTOR               in: TDD/sound   out: assets/audio
──────────────────────────────────────────────────────────────────
☑ cue-timer-warning   cycles [0  ]→[6  ]   ☑wav ☐ogg    done ✓
☑ m1-main-menu        cycles [0  ]→[104]   ☐wav ☑ogg    recording… 1:12/3:32
☑ m2-lobby            cycles [8  ]→[40 ]   ☐wav ☑ogg    queued
   … one row per file …
──────────────────────────────────────────────────────────────────
[ + add file ]  [ Process files ]  [🔊 monitor: on/off]  overall: 3/25 · ~11 min left
```

- Rows auto-populate from `GET /files`, alphabetical. Checkbox = include in this run (all on by default).
- Cycle boxes + format checkboxes prefill from localStorage (keyed by filename); unknown files default `0..1 wav`. Any edit is auto-remembered — no save button, no file writes, sources never touched (2026-08-09 revision).
- **+ add file** (and drag-and-drop onto the page): queue an individual `.strudel` file from anywhere on disk; it becomes a normal row (settings remembered by filename) and renders to the same output folder.
- Both formats checkable → file renders to both.
- Status per row: `queued → warming up → recording (mm:ss/mm:ss) → encoding → done ✓ / FAILED (reason)`.
- Monitor toggle: capture is inside the graph, so system/page volume never affects the recording; the toggle only mutes what the owner hears.
- Overall progress with time-remaining computed from cycle windows (durations are known exactly: `(end−start)×60/cpm`).

## 4. Render settings (in-app; REVISED 2026-08-09 — no file headers)

Three values per file: **start cycle, end cycle, format** (`wav|ogg|wav+ogg`). Set in the UI, auto-remembered in browser localStorage keyed by filename. Baked fallback for unknown files: `0..1 wav`. The `.strudel` sources are never edited and no settings file exists — timings are authored knowledge (the owner knows each song's cycle count); retyping a few exceptions on a fresh machine/browser is the accepted cost.

**Reference table for the 25 Animal Quickdraw files** (from `TDD/sound/README.md` "Render settings", 2026-07-19 — cycles chosen so loops close on identical mask state + modulation phase, one-shots keep tails). Most files are the default; the owner types only the exceptions:

| File | settings |
|------|-------------|
| cue-timer-warning | `0..6 wav` |
| m1-main-menu | `0..104 ogg` |
| m2-lobby | `0..40 ogg` |
| m3-drawing-ambient | `0..80 ogg` |
| m3-drawing-oompa | `0..64 ogg` |
| s1-race-start | `0..1 wav` |
| s2-prompt-reveal | `0..1 wav` |
| s4-winner | `0..1 wav` |
| s6-title-awarded | `0..1 wav` |
| s7-final-podium | `0..1 wav` |
| all 15 `sfx-*` | `0..1 wav` |

**As-rendered values (2026-08-10, owner-approved):** (a) tail capture works — s4/s7 shrank from the mask-era `0..2` to `0..1` + native tail capture, no source edits, mask trick fully retired; (b) **all music loops render from cycle 0** (owner decision at build session — intro cycles belong in the loop files; the old phase-chosen start offsets 8/24/16 are retired).

## 5. Capture & slicing design

1. **Tap installation (before engine init):** wrap `AudioNode.prototype.connect` so any connect targeting `ctx.destination` is rerouted through `[tap GainNode] → recorder worklet → destination`. This catches superdough's master output including orbit effect returns (reverb/delay). *This is the one load-bearing trick — validate first (Milestone A).* Fallback if interception misbehaves: patch superdough's `getDestination`/output node directly in the vendored bundle, or a `MediaStreamAudioDestinationNode` + `MediaRecorder` (lossy webm — last resort only).
2. **Recorder worklet:** copies input Float32 frames (stereo, 48 000 Hz — assert `ctx.sampleRate === 48000`, warn otherwise) into transferable buffers posted to the page; page accumulates.
3. **Warm-up pass (soundfont race):** before the recorded take, evaluate + play the pattern muted for ~1 cycle, then `hush()`. First-ever play of a `gm_*` instrument triggers its network fetch; recording without warm-up yields missing layers (the S6/S7 failures of 2026-07-19). Warm-up guarantees samples are cached before the real take.
4. **Recorded take:** start recording, start playback, note the engine's time origin `t0` (the AudioContext time of cycle 0 — from the scheduler; worst case wrap `Cyclist`'s start). Record until `t0 + end×cyc + TAIL` where `cyc = 60/cpm` and `TAIL = 2 s` (covers release + reverb ring-out).
5. **Slice:** `startSample = round((t0 + start×cyc − recStart)×sr)`, `endSample` likewise. **Loops (any file where a music-style seamless wrap is wanted, i.e. the OGG files): cut exactly at `end×cyc`** — seamlessness comes from the cycle math, tails wrap into the loop by design. **One-shots (WAV): extend `endSample` past the boundary until sustained silence (< −60 dBFS for 250 ms) so tails survive**, then trim trailing silence to that point.
6. **Encode:** WAV = 16-bit PCM stereo. OGG = vendored Vorbis encoder, quality ~0.6 (~192 kbps). `POST /save` per format.
7. **Queue:** strictly sequential; `hush()` + 500 ms gap between files; per-file failure marks the row FAILED and continues the queue.
8. **cpm detection:** parse `setcpm(...)` from source (arithmetic expressions like `118/4` — evaluate the number) for duration estimates; the *slicing* uses the engine clock, so cpm parsing only affects progress display.

## 6. Milestones (build in this order — each has an owner checkpoint)

- **A. Tap proof:** page plays `s7-final-podium` live with the tap installed; captured WAV (any slicing) contains the e-piano chord WITH reverb tail. **Owner A/Bs against strudel.cc playback. Gate: does it sound identical?** If A fails after the fallbacks, stop and reconvene (manual loopback recording becomes plan B — see WHERE_WE_ARE).
- **B. Sample-accurate one-shot:** s7 sliced by the clock with tail-capture; s4 too. Owner listens for clipped tails.
- **C. Loop seam:** m2-lobby 8..40 OGG; owner loops it (any looping player / quick Godot import) and listens to the wrap. Also validates OGG encoding.
- **D. Full UI + batch:** rows, headers parsed, checkboxes, progress, monitor toggle, error rows. Render all 25; owner spot-checks a handful.
- **E. Polish + docs:** `--in/--out` args verified against a scratch folder (project-agnostic check); README section in `tools/sound_pipeline/` (usage, vendoring provenance + versions, license notes); update `TDD/sound/README.md` render table (s4/s7 to 0..1, point at the tool); WHERE_WE_ARE.

## 7. Out of scope (v1)

- Editing `.strudel` sources from the UI (headers are hand-maintained)
- Loudness normalization / mastering; leading-silence trimming beyond §5
- Embedding loop metadata in files (Godot import flags handle looping — wiring session)
- Non-48 kHz output; mono; mp3
- Parallel rendering (real-time capture is inherently serial; full bank ≈ 15 min — acceptable)

## 8. Risks

| Risk | Mitigation |
|------|------------|
| connect-interception misses superdough's routing | §5.1 fallbacks; Milestone A gates everything |
| Engine clock origin hard to read from @strudel/web's API | pad recording, locate cycle 0 via the scheduler's reported phase; worst case onset-detect the first event of a warm-up click-track pattern prepended by the tool |
| Vendored bundle drifts from strudel.cc sound | pin + commit the version; the sources were composed against the live site — owner A/B in Milestone A is the arbiter |
| Browser throttles timers in background tabs | AudioContext rendering is not throttled while playing; keep the tab visible during batches as a precaution (progress UI encourages this anyway) |
| OGG wasm encoder quality/licensing surprises | MIT-licensed encoder, owner listens in Milestone C; ffmpeg CLI conversion is a trivial fallback (`ffmpeg -i in.wav -c:a libvorbis -q:a 6 out.ogg`) |

## 9. Build-session bootstrap

Read this file, then: (1) vendor the two libraries, (2) Milestone A. The 25 sources are owner-approved and **frozen** — do not modify them at all (2026-08-09: header step deleted). Owner runs the tool via:

```
node tools/strudel_extractor/server.mjs
```

then opens the printed localhost URL.
