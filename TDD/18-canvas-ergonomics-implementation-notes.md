# Slice 18 Implementation Notes: Canvas Ergonomics & Display Scaling

**Completed:** 2026-07-10 (session 9)
**TDD:** `TDD/18-canvas-ergonomics.md` (owner-inserted mini-slice)
**Status:** COMPLETE (core-confirmed) — owner confirmed the trackpad flow (hold-D, D-as-click, minimap, pan) through the same-session rework iterations; batchables in qa-backlog Slice 18

---

## What Was Built

Exactly the TDD's three pieces; no scope drift:

1. **Window scaling:** `canvas_items` stretch + `expand` aspect in `project.godot`; `Nav._ready()` sets the 960×540 minimum window size (`GameConstants.WINDOW_MIN_SIZE`). Every screen now scales proportionally with the window.
2. **Canvas zoom/pan (display-only):** zoom 1×–8× applied by resizing the **RasterView inside the SubViewport** — the render target never grows (the TDD's VRAM rationale). All pointer mapping funnels through the now zoom/pan-aware static `DrawingCanvas.map_display_to_internal`; at zoom 1 it is the Slice 1 letterbox map exactly (regression-pinned). Inputs: Ctrl/Cmd+wheel + pinch gesture (zoom at cursor), two-finger scroll gesture / wheel / Shift+wheel / middle-drag (`PANNING` input state) for pan; toolbar − / % / + cluster, % label = reset-to-fit; view resets on new drawing / doc load / rotate.
3. **Hold-to-draw:** `draw_hold` InputMap action (physical D). `_unhandled_key_input` begins a stroke (brush/eraser) or stamps a fill at the pointer when it's over the canvas; focused `LineEdit`s consume typed keys first, so chat/text-row typing structurally can't ink. `_stroke_from_key` makes the release fallbacks source-aware: a key stroke ignores mouse releases and vice versa.

## Files Touched

- `project.godot` — stretch mode/aspect; `[input] draw_hold`
- `core/constants/game_constants.gd` — Slice 18 banner (6 constants)
- `core/nav/scene_manager.gd` — min window size at boot
- `ui/canvas/drawing_canvas.gd` — zoom state + static math + `PANNING` + hold-to-draw + source-aware releases; eraser cursor & chip drag preview scale gain `* _zoom`
- `ui/canvas/drawing_canvas.tscn` — RasterView to manual layout (anchors removed)
- `ui/canvas/canvas_toolbar.gd/.tscn` — zoom cluster (3 signals, `set_zoom_display`, `set_all_enabled` coverage)
- Tests: `test_drawing_canvas.gd` (+10), `test_canvas_scenes.gd` (+1 + extended signals test), plus two harness fixes below

## Deviations & Incidents

- **Stretch mode broke the simulated-input drag test** (`test_text_drag_drop.gd`): with `canvas_items` stretch, the root Window transforms OS-level input by the content-scale factor, and under headless window geometry that factor makes simulated global positions miss where `get_global_rect` points. Scaling is display-only, so the suite now parks `content_scale_mode = DISABLED` in `before_test` and restores it after. **Rule of thumb for future suites: OS-level input simulation (GdUnitSceneRunner `simulate_mouse_*`) needs content scaling disabled; seam-driven tests don't care.**
- **Latent f32/f64 exact-compare exposed** (`test_lobby_scenes.gd` chat prominence): `custom_minimum_size` is a `Vector2` (32-bit) but the test recomputed the expected height in 64-bit and compared exactly. Pre-stretch, the headless viewport never hit the ratio path so the floor constant masked it; the stretch base size (720) engaged the ratio and surfaced the mismatch. Fixed with `is_equal_approx(…, 0.001)` — panel behavior was always correct.
- Pre-existing (left alone): `_apply_orientation_to_surface` sets `_viewport.size`, which `SubViewportContainer.stretch = true` overrides with a warning in test logs. Harmless noise that predates this slice; removing the line is a Slice 1 cleanup question, not an ergonomics one.

## Key Implementation Details

- **Zoom lives inside the viewport.** `ViewportBox` (stretch = true) forces render-target size to container size; scaling the container instead would have ballooned the render target ~O(zoom²) (≈150 MB at 8× fullscreen). RasterView manual layout keeps VRAM flat and — because gui_input positions are container-local — leaves stroke/drop input mapping changes confined to the one static function.
- **Pan state is the RasterView position** (≤ 0 per axis); `clamp_pan` collapses the range to (0,0) at fit, so "can't pan while unzoomed" is arithmetic, not a special case.
- **Zoom-at-cursor** = `pan' = cursor − (cursor − pan) · z₂/z₁`, then the layout pass clamps — pinned by a round-trip test through `map_display_to_internal`.
- **Source-aware release**: the `_process` fallback checks `Input.is_action_pressed("draw_hold")` for key strokes and the LMB for mouse strokes; the `_input` LMB-release path is gated on `not _stroke_from_key`. Focus-loss handling reuses the existing notification path unchanged.
- The avatar editor and sandbox inherit everything (same scene); rim clamping already handles out-of-circle pointers at any zoom.

## Same-Session Rework (owner-directed, 2026-07-10)

First playtest verdicts: hold-D good, but D should also click buttons; zoom disorienting (no sense of position, and trackpad panning never worked). Fix-don't-scrap decided (owner picked the full kit):

- **D-as-click** (`_key_click_at`): outside the canvas, a `draw_hold` press pushes a synthesized LMB press+release pair at the pointer via `get_viewport().push_input(ev, true)` — `in_local_coords = true` keeps the stretch transform away from the coordinates (the same trap the drag-test fix documented). A full pair means no stuck held-button state; a real held LMB suppresses synthesis. Headless-tested end-to-end (a click pair at the Clear button's rect commits a ClearOp through the ordinary button path).
- **`CanvasMinimap`** (`ui/canvas/canvas_minimap.gd`, programmatic child of the ViewportBox like EraserCursor, node name `CanvasMinimapInset` per the find_child lesson): visible only when zoomed; draws the live raster texture + view rectangle (`view_rect_frac` static, unit-tested); click-drag or hold-D-and-move centers the view via `view_center_requested(frac)` → `DrawingCanvas._center_view_on_fraction` (pan = view/2 − frac·view·zoom, clamped by the layout pass). The canvas excludes the minimap rect from inking; `mouse_filter = STOP` keeps real clicks off the canvas beneath.
- **Gesture routing**: magnify/pan gestures moved from `gui_input` to `_input` with an explicit ViewportBox hit-test + `set_input_as_handled()` — Control delivery of gestures proved platform-flaky (the owner's two-finger pan never arrived through gui_input on macOS). Wheel pan/zoom now scales by `InputEventMouseButton.factor` (precise trackpad scrolling; 0 → 1.0 for plain wheels). `CANVAS_GESTURE_PAN_FACTOR` bumped 8 → 20 (still a feel item).
- **Border polish** (owner, same day): the inset blended into a blank drawing — now a solid dark frame + offset shadow, and the view rectangle is two-tone (dark under white) so it reads on any drawing content.

## Testing Summary

- **Unit/scene:** +14 first build, +4 rework (minimap math, center-on-fraction, visibility, D-click end-to-end); full suite **505/505 green, 0 orphans**.
- **Automated gates (guarded wrapper):** `verify_lobby.sh` PASS, `verify_round.sh` PASS, `verify_resilience.sh` PASS — CI drivers drive internal seams, so display-side changes were invisible to them, as predicted in TDD §10.
- **User confirmation:** trackpad session confirmed 2026-07-10 (hold-D draw, D-as-click, minimap navigation + border polish, pan — "that's great"); no scaling issues reported across the session's windowed playtests. Explicit min-size/extreme-aspect checks + feel tuning → qa-backlog Slice 18.

## Known Limitations

- Text-chip drag still needs a real click-drag (D-hold drag semantics have stuck-state risks near focusable text fields) — batchable; revisit if trackpad text placement hurts.
- Pan/zoom feel constants (`CANVAS_WHEEL_PAN_PX`, `CANVAS_GESTURE_PAN_FACTOR`, wheel zoom factor, minimap size fraction) are untuned first guesses — owner feel pass will calibrate.
- Zoomed replay in the sandbox plays inside the zoomed view (accepted in TDD; round-flow replays live on other screens).
- No key-rebinding UI; `draw_hold` is InputMap-editable only.
- RasterView keeps linear filtering at high zoom (slightly soft pixels); switching to nearest at zoom > 1 is an art-pass question.
