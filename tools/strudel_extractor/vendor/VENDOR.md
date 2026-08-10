# Vendored libraries — provenance

Committed one-time downloads (2026-08-09). The tool has zero npm dependencies; these two files are the whole third-party surface.

| File | Package | Version | Source URL | License |
|------|---------|---------|------------|---------|
| `strudel-web.js` | `@strudel/web` | **1.3.0** (pinned) | `https://unpkg.com/@strudel/web@1.3.0/dist/index.js` | AGPL-3.0-or-later |
| `ogg-encoder/WasmMediaEncoder.min.js` + `ogg-encoder/ogg.wasm` (+ `.d.mts`) | `wasm-media-encoders` | **0.7.0** (pinned) | `https://unpkg.com/wasm-media-encoders@0.7.0/dist/umd/WasmMediaEncoder.min.js` + `/wasm/ogg.wasm` | MIT |
| `soundfonts/index.mjs` | `@strudel/soundfonts` | **1.3.0** (pinned) | `https://unpkg.com/@strudel/soundfonts@1.3.0/dist/index.mjs` | AGPL-3.0-or-later |
| `soundfonts/sfumato.mjs` | `sfumato` | **0.1.2** (pinned — the version @strudel/soundfonts@1.3.0 declares; latest 0.3.0 has a different API) | `https://unpkg.com/sfumato@0.1.2/dist/sfumato.js` | ISC |
| `soundfonts/soundfont2.mjs` | `soundfont2` | **0.4.0** (pinned — sfumato@0.1.2's declared range) | `https://unpkg.com/soundfont2@0.4.0/lib/SoundFont2.js` | MIT |
| `soundfonts/strudel-shim.mjs` | (ours) | — | hand-written | — |

**Why the extra three:** the `@strudel/web` bundle does NOT include soundfont support (verified 2026-08-09: zero `gm_`/`soundfont` hits in the 1.3.0 bundle), but the strudel.cc site does — and the game's sources lean on `gm_*` instruments throughout. `@strudel/soundfonts` is an ESM package importing bare `@strudel/core`/`@strudel/webaudio`/`sfumato`/`soundfont2`; the import map in `ui/index.html` resolves the two strudel specifiers to `strudel-shim.mjs` (re-exports from the vendored IIFE — every needed name verified present), so the `gm_*` registry lands in the same engine instance the extractor plays through. A second bundled engine copy (e.g. esm.sh `?bundle`) would silently register sounds into an engine nobody uses. `gm_*` instrument data still streams from `https://felixroos.github.io/webaudiofontdata/` on first play per instrument (browser-cached after).

Notes:

- `strudel-web.js` is the IIFE browser bundle (`var strudel = …`); it bundles @strudel/core/mini/webaudio + superdough (the same engine strudel.cc plays through). Loaded via plain `<script>` tag.
- **⚠ `strudel-web.js` is NOT a pristine download:** it carries one marked local patch (search `EXTRACTOR PATCH`) fixing 1.3.0's refusal of bare-scalar arithmetic on control patterns (`.add(-12)` on note patterns silently no-opped; strudel.cc transposes — this made m1/m2's octave-down echo play at original pitch). Re-apply (or re-verify it's obsolete) when upgrading the bundle — details in IMPLEMENTATION-NOTES.md.
- `ogg-encoder/` uses the package's **UMD build + separate `ogg.wasm` binary** (classic `<script>` tag → `window.WasmMediaEncoder`; the page fetches the wasm from `/vendor/` — local, offline-safe). The package's ES build was tried first and rejected: it imports `@swc/helpers/*` as bare specifiers, which fail at runtime in a browser without extra import-map shims.
- License stance (from DESIGN.md §2): Strudel's AGPL is fine here — this is an internal dev tool; nothing from it ships into the game except the owner's own rendered audio.
- To upgrade: re-download from the same URL shape at a new pinned version, update this table, and re-run the Milestone A owner A/B (the vendored bundle drifting from strudel.cc sound is a known risk — DESIGN.md §8).
