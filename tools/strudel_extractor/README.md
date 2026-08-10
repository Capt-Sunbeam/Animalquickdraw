# Strudel Extractor

Records Strudel patterns **through the real live engine** and writes finished WAV/OGG files. Built because Strudel's native export renders through an offline path that drops the global effects bus (reverb/delay) — see [DESIGN.md](DESIGN.md) for the full story and architecture.

Self-contained and project-agnostic: copy this whole folder into any repo (or nowhere), point it at a folder of `.strudel` files, done. Zero npm dependencies.

## Usage

```
node tools/strudel_extractor/server.mjs [--in <dir>] [--out <dir>] [--port 8123]
```

- Defaults: `--in TDD/sound`, `--out assets/audio` (resolved from the repo root, i.e. two levels above this folder).
- Open the printed URL (http://localhost:8123). Every `.strudel` file in the input folder appears as a row.
- Per row: **include checkbox · start cycle → end cycle · wav / ogg** (both allowed). Settings are remembered automatically in the browser (localStorage, keyed by filename) — no save button, and the `.strudel` sources are never touched. Unknown files default to `0..1 wav`.
- **+ add file** or drag-and-drop queues individual `.strudel` files from anywhere on disk; they render to the same output folder and their settings are remembered too.
- **Process files** runs the checked rows top to bottom, strictly sequential (capture is real time). Click again to stop after the current file.
  - **Caution (2026-08-10):** the 25-file Animal Quickdraw bank was rendered **one file per page session** (reload between files, owner's call) after multi-file queues produced bad takes. The underlying bugs (worklet init, scheduler restart) are fixed and a 2-file queue machine-verified clean afterwards, but a long batch hasn't been re-validated end-to-end — for critical renders, prefer one file per session and reload between.
- **monitor** toggles whether you hear the take. The capture taps inside the audio graph, so monitor state and system volume never affect the recording.

### What a take does

1. **Warm-up** — evaluates the pattern silently, queries every sound event in the render window, pre-triggers each distinct instrument/sample at zero gain, and waits for the resulting network fetches to go quiet (soundfonts + samples are fetched lazily by the engine and cached by the browser; first run per instrument needs internet).
2. **Record** — plays from cycle 0 with the recorder rolling. Events past the end cycle are filtered out of the pattern *before* playback, so the tail is pure ring-out.
3. **Slice** — cut points come from the engine clock's cycle→time mapping (sample-accurate arithmetic, never human timing).
   - **OGG (loops):** cut exactly on the cycle boundary — seamlessness comes from the cycle math.
   - **WAV (one-shots):** the cut extends past the boundary until sustained silence (< −60 dBFS for 250 ms), keeping the full reverb tail; up to 4 s of tail is captured.
4. **Encode & save** — WAV 16-bit PCM stereo; OGG Vorbis quality 6 (≈192 kbps). Files land in the output folder as `<name>.wav` / `<name>.ogg`.

### Notes

- Keep the tab visible during long batches (background-tab throttling caution; the progress display encourages this anyway).
- Recordings are made at the AudioContext rate (expected 48 000 Hz; a banner warns if the OS gives something else).
- First-ever run needs internet for the engine's sample maps + instruments; after the browser has cached them, it works offline.

## Vendored libraries

See [vendor/VENDOR.md](vendor/VENDOR.md) for exact pinned versions, source URLs, licenses, and the reason the soundfont stack is vendored separately (the `@strudel/web` bundle ships without `gm_*` soundfont support).

## Design & implementation

- [DESIGN.md](DESIGN.md) — owner-approved spec: principles, architecture, capture/slicing design, milestones, risks.
- [IMPLEMENTATION-NOTES.md](IMPLEMENTATION-NOTES.md) — what was actually built, deviations from the spec, and the load-bearing tricks (read this before modifying the tool).
