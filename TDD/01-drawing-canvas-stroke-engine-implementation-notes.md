# Implementation Notes: Slice 1 — Drawing Canvas & Stroke Engine

**Completed:** 2026-07-06 (implementation complete; owner playtest confirmation pending — see Testing Summary)
**TDD Document:** `TDD/01-drawing-canvas-stroke-engine.md`

## Implementation Summary

The full slice — both TDD parts in one pass (this session runs continuously, so the Chunk 2/3 split served no purpose): `DrawingDoc` op model with strict silent-failing validation, the versioned 60-color palette, `DocRasterizer` (deterministic CPU stamping + scanline flood fill + SHA-256 golden hashing), `ReplayPlayer` (gap compression, non-stroke beats, duration cap), and the embeddable `DrawingCanvas` component with toolbar, palette picker, save-toggle stub, rotate-with-confirm, and a debug-only sandbox screen. 57 new tests; 89 total green; six golden raster hashes baked and committed.

## Deviations from Original Design

### Parts 1 and 2 built together
**Original Plan:** Two chunks: strokes/canvas first (with fill/rotate buttons disabled behind "Part 2" tooltips), then fill/rotate/replay.
**Actual Implementation:** One pass; all tools live from the start. The intermediate disabled-button state was never shipped.
**Reason:** Both chunks belong to this continuous session — building the interim state would have been throwaway work.
**Impact:** None on contracts. The Chunk 2 "drawing feel" and Chunk 3 "fill + replay" playtest gates are both queued on the batched checklist.

### Golden baking runs inside GdUnit, not a standalone script
**Original Plan:** (unspecified mechanics) golden hash values committed with the tests.
**Actual Implementation:** Standalone `-s` bake scripts can't resolve project `class_name`s (Godot loads the global class cache only for full app/SceneTree-tool runs), so baking = temporarily printing hashes from inside the rasterizer test suite, then pasting into `EXPECTED_HASHES`. Procedure documented in the test file header.
**Impact:** Re-baking after an intentional raster change is a 2-minute manual step.

### Flood fill runs on a PackedInt32Array view of the pixels
**Original Plan:** "Fill operates on an `Image` snapshot — O(pixels)."
**Actual Implementation:** Pixels are pulled once via `get_data().to_int32_array()`, the scanline fill runs on flat int32 comparisons, and the buffer is written back with `set_data` — two native Image calls total instead of per-pixel `get_pixel/set_pixel` (which measured far over the 50 ms budget in GDScript). Worst-case full-canvas fill passes the soft budget on the dev machine.
**Impact:** None on determinism (same exact-match rule); byte order is explicitly little-endian on all three target platforms.

### Circle stamps use per-row spans + `fill_rect`
**Original Plan:** per-pixel `dx*dx + dy*dy <= r*r` test.
**Actual Implementation:** Mathematically identical row spans (`|dx| <= floor(sqrt(r² − dy²))`) filled with native `fill_rect` calls — ~29 native calls per large stamp instead of ~841 pixel writes. The per-pixel path is retained verbatim for the masked (Slice 11) branch.
**Impact:** None — pixel-identical, verified by the golden tests.

### Stale class cache after adding new `class_name` scripts
**Not a design deviation — a workflow gotcha:** after creating new `class_name` scripts, `godot --headless --path . --import` must run before the test CLI, or every new class fails to resolve. Now part of the session's standard test loop.

## Files Created/Modified

- `core/constants/palette.gd` — 60-color append-only table (12 families × 5 shades), hex values chosen this session (family 0 greyscale; red, orange, yellow, green, teal, blue, navy, purple, pink, brown, tan)
- `core/constants/game_constants.gd` — Slice 1 block appended (brush radii, decimation, point cap, replay gap/non-stroke/budget constants)
- `core/constants/routes.gd` — `CANVAS_SANDBOX`
- `game/drawing/` — `drawing_op.gd`, `stroke.gd` (capture quantization helpers), `fill_op.gd`, `clear_op.gd`, `drawing_doc.gd` (canonical serialization + strict `from_dict`), `doc_rasterizer.gd`, `replay_player.gd`
- `ui/shared/confirm_dialog.tscn/.gd` — generic modal (native `confirmed`, wrapped `cancelled`)
- `ui/canvas/` — `drawing_canvas.tscn/.gd` (component + input state machine), `canvas_toolbar.tscn/.gd`, `palette_picker.tscn/.gd` (shade popup via right-click or long-press), `canvas_sandbox_screen.tscn/.gd` (replay slider 1–8×, clipboard JSON dump/load)
- `ui/menu/main_menu_screen.*` — debug-only Canvas Sandbox button
- `tests/` — `test_palette.gd`, `test_drawing_doc.gd`, `test_doc_rasterizer.gd` (goldens), `test_replay_player.gd`, `test_drawing_canvas.gd`, `test_canvas_scenes.gd`, shared fixture `golden_docs.gd`

## Key Implementation Details

- **Test seam for the canvas:** input handling is a thin layer over internal methods (`_stroke_begin/_stroke_extend/_stroke_end/_fill_at/_press_*`) that tests drive directly with internal coordinates — no fragile synthetic-mouse-event plumbing. Real input mapping is on the playtest checklist.
- The stroke-release fallback (`_process` checks `Input.is_mouse_button_pressed`) means headless tests must not `await` frames mid-stroke — documented in the test suite.
- `ReplayPlayer` resumes a partially-stamped stroke from `_stamped_points − 1` so the connecting segment is never skipped (both in `advance` and `skip_to_end`).
- Fill/clear ops apply their pixels at their *start* time during replay; their `REPLAY_NON_STROKE_OP_SEC` duration is purely a pacing beat.
- Rotate keeps orientation across `begin_drawing()` (a drawer who rotated keeps portrait for the round; Slice 3 relies on this).

## Testing Summary

- Unit + integration: 57 new tests (89 total), all green. Coverage includes the full `from_dict` rejection matrix, all six golden hashes, wire round-trip hash stability, incremental==full stamping, undo-of-clear, replay cap/gap/beat math, canvas op lifecycle, and the point-cap stroke split.
- Fill budget: full-canvas flood within the 50 ms soft budget (no warning emitted on the dev machine).
- Scene smoke: all five Slice 1 scenes instantiate clean; startup remains warning-free.
- **User confirmation: PENDING (batched)** — blocking gates: drawing feel (lag, brush sizes, palette expand); fill + replay correctness in the sandbox. Batchable: shade popup feel, letterboxing at odd window sizes, rotate confirm wording, undo disabled-state timing, save-toggle visibility.

## Lessons Learned

- GDScript per-pixel Image access is ~10× too slow for the fill budget; flat-array processing is the pattern for any future pixel pass (Slice 8 export/thumbnails should reuse it if needed).
- Baked goldens + self-consistency properties (round-trip, incremental, replay-end) together give strong determinism coverage cheaply.

## Known Limitations

- `MaskMode.CIRCLE` is hook-only (enum, mask params, disabled branch) — Slice 11 implements and golden-tests it.
- Save toggle persists nothing (Slice 4 wires the collection write).
- No redo (per brief §6).
- Long-press shade popup duration (0.45 s) untuned — playtest item.
