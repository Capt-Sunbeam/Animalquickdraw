# Slice 18 (mini): Canvas Ergonomics & Display Scaling
## The window scales sanely at any size; the canvas zooms for detail work; trackpad players draw by holding a key

**Version:** 1.0
**Last Updated:** 2026-07-10
**Dependencies:** Slice 1 (DrawingCanvas/toolbar/input mapping), Slice 16 (text-chip drag + eraser cursor display scaling)
**Provides:** project-wide window stretch scaling; display-only canvas zoom/pan; `draw_hold` input action (hold **D** = pen down)

> **Scheduling note:** owner-inserted mini-slice (2026-07-10, after the Slice 10+11 batched checks cleared). Runs between Chunk 14 (Slices 10+11) and Chunk 15 (Slice 12: Steam). Numbered 18 as the next free TDD number — the overview's chunk plan stays authoritative for order.

---

## 1. Overview

Three ergonomics problems from owner playtests, one slice:

1. **The window doesn't scale.** No stretch mode is configured, so the UI renders 1:1 pixels: small windows clip labels; fullscreen on a big monitor leaves everything tiny. Fix: `canvas_items` stretch + `expand` aspect + a minimum window size — the whole UI scales proportionally on every screen.
2. **No detail work on the canvas.** The drawing is displayed fit-to-frame only. Fix: display-only zoom (1×–8×) + pan on the canvas view. The internal raster resolution is untouched — determinism (consistency guide principle 4) is not in play.
3. **Trackpads are hostile to click-drag drawing.** Fix: a `draw_hold` input action (default: **D**) — holding it acts as press-and-hold at the pointer, so trackpad players move the pointer freely and "ink" by holding the key.

### Scope

**In Scope:**
- `project.godot`: `window/stretch/mode = canvas_items`, `aspect = expand`; runtime minimum window size (960×540) set at boot in `Nav`
- `DrawingCanvas` zoom state (`_zoom`, `_pan`) applied to the **RasterView inside the SubViewport** (render target stays container-sized — no VRAM blowup); all pointer mapping through a zoom/pan-aware `_display_to_internal`
- Zoom input: Ctrl/Cmd+wheel and trackpad pinch (`InputEventMagnifyGesture`), zoomed at the cursor; toolbar − / % / + cluster (% label click = reset to fit)
- Pan input: trackpad two-finger scroll (`InputEventPanGesture`), plain wheel (Shift = horizontal), middle-mouse drag (new `PANNING` input state)
- `draw_hold` InputMap action (physical D): begins/extends/ends a stroke (brush/eraser) or stamps a fill at the pointer; stroke-source tracking so key strokes and mouse strokes release independently
- View resets to fit on new drawing / doc load / rotate

**Out of Scope (later / never):**
- Per-screen responsive fine-tuning beyond what stretch gives (extreme-aspect polish rides the art pass, which restyles every screen)
- Space-drag panning (conflicts with LMB stroke state; middle-drag + gestures + wheel cover mouse and trackpad)
- Key rebinding UI (the action is InputMap-defined; a settings surface is a future nicety)
- Zooming reveal/judging/spotlight views (drawing-time feature only)
- Touchscreen gestures

### User Flow

1. Player resizes the window / goes fullscreen → every screen scales proportionally; nothing clips at or above the minimum window size.
2. While drawing: pinch (or Ctrl+wheel, or **+**) → canvas zooms toward the cursor; two-finger scroll / wheel / middle-drag pans; the % label (or drawing anew) resets to fit. Strokes land exactly under the cursor at any zoom.
3. Trackpad player rests the cursor on the canvas, holds **D**, moves the pointer to draw, releases **D** to lift the pen. With Fill selected, a **D** press stamps a fill. Typing "d" in chat or the text row never draws (focused text fields consume the key first).

---

## 2. Data Models

No new persisted data, ops, or wire payloads. New view-state on `DrawingCanvas` (never serialized):

| Field | Type | Description |
|-------|------|-------------|
| `_zoom` | float | Display zoom, 1.0–`CANVAS_ZOOM_MAX`; 1.0 = fit (today's behavior) |
| `_pan` | Vector2 | RasterView position within the viewport; per-axis in `[view_size * (1 − zoom), 0]` |
| `_stroke_from_key` | bool | Live stroke was started by `draw_hold` (release semantics differ) |

Constants (`GameConstants`, Slice 18 banner):

```gdscript
const WINDOW_MIN_SIZE: Vector2i = Vector2i(960, 540)
const CANVAS_ZOOM_MAX: float = 8.0
const CANVAS_ZOOM_STEPS: PackedFloat32Array = [1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0]  # button ladder
const CANVAS_WHEEL_ZOOM_FACTOR: float = 1.15   # per wheel notch
const CANVAS_WHEEL_PAN_PX: float = 60.0        # per wheel notch, display px
```

---

## 3. Event/Action Definitions

No new RPCs or EventBus signals. New InputMap action in `project.godot`:

| Action | Default binding | Meaning |
|--------|-----------------|---------|
| `draw_hold` | physical **D** | While pressed over the canvas: pen down at the pointer |

New `CanvasToolbar` signals: `zoom_in_pressed`, `zoom_out_pressed`, `zoom_reset_pressed`; new method `set_zoom_display(zoom: float)`.

---

## 4. Storage Schema Extensions

None.

---

## 5. State Machines

`DrawingCanvas.InputState` gains `PANNING`:

| Current | Trigger | New | Notes |
|---------|---------|-----|-------|
| IDLE | middle-mouse press on canvas | PANNING | Pointer deltas move `_pan` (clamped) |
| PANNING | middle-mouse release / focus loss | IDLE | |
| IDLE | LMB press on canvas | STROKING | Unchanged; `_stroke_from_key = false` |
| IDLE | `draw_hold` pressed, pointer over canvas | STROKING | `_stroke_from_key = true`; Fill tool stamps instead (stays IDLE) |
| STROKING | source released (LMB **or** `draw_hold`, per `_stroke_from_key`) | IDLE | The `_process` release-fallback checks the **matching** source; the non-source's release is ignored |

Zoom/pan input (wheel/gestures/buttons) is stateless and allowed in IDLE only — mid-stroke zoom would retroactively bend the mapping under the pointer.

---

## 6. Business Logic

### Zoom is a view transform inside the SubViewport

`ViewportBox` (`stretch = true`) forces the render target to container size, so the canvas zooms by resizing the **RasterView** within the viewport: manual layout, `position = _pan`, `size = view_size * _zoom`. The SubViewport clips natively; at `_zoom = 1.0, _pan = (0,0)` this is pixel-identical to today's full-rect layout. VRAM cost: none (render target unchanged).

All zoom math is **pure static functions** on `DrawingCanvas` (headless-tested):

```gdscript
static func clamp_zoom(zoom: float) -> float                                   # 1.0..CANVAS_ZOOM_MAX
static func clamp_pan(pan: Vector2, view_size: Vector2, zoom: float) -> Vector2  # per-axis [view*(1-zoom), 0]
static func pan_after_zoom(cursor: Vector2, pan: Vector2, old_zoom: float, new_zoom: float) -> Vector2
        # keeps the canvas point under `cursor` fixed: cursor - (cursor - pan) * (new_zoom / old_zoom)
static func map_display_to_internal(container_local: Vector2, container_size: Vector2,
        internal: Vector2, zoom: float, pan: Vector2) -> Vector2
        # ((container_local - pan) / zoom) * (internal / container_size), clamped in-canvas
```

`_display_to_internal` delegates to `map_display_to_internal` with instance state — every existing consumer (stroke begin/extend/end, fill, text-drop anchor) inherits zoom-correct mapping through the single choke point. The two display-scale consumers (`_update_eraser_cursor`, `_chip_get_drag_data` preview) multiply by `_zoom`.

View resets (`_zoom = 1`, `_pan = 0`) on `begin_drawing()`, `load_doc()`, and orientation flip. During REPLAYING the zoomed view persists (sandbox-only path; accepted).

### Hold-to-draw

`_unhandled_key_input` (chat/text `LineEdit`s consume typed keys first — the no-draw-while-typing guard is structural, not a focus check):

- `draw_hold` **pressed** (not echo), `_tools_enabled`, IDLE, visible, pointer inside the ViewportBox global rect → Fill: `_fill_at(pointer)`; Brush/Eraser: `_stroke_begin(pointer)` + `_stroke_from_key = true`.
- `draw_hold` **released** while STROKING and `_stroke_from_key` → `_stroke_end(pointer)`.

Existing motion handling (`_input` while STROKING) extends key strokes unchanged. The two release fallbacks become source-aware:

- `_process` fallback: checks `Input.is_action_pressed("draw_hold")` when `_stroke_from_key`, else the LMB check (covers focus loss / release outside the window).
- `_input` LMB-release handler: ignored when `_stroke_from_key` (clicking mid-key-stroke must not lift the pen; the reverse is already impossible — LMB strokes ignore key events).

### Window scaling

`canvas_items` + `expand`: all Controls scale with the window; extra space at non-16:9 aspects flows into the anchored/container layouts every screen already uses. `Nav._ready()` sets `get_window().min_size = GameConstants.WINDOW_MIN_SIZE` — below ~960×540 proportional scaling alone can't keep dense screens (lobby, reveal grid) usable.

---

## 7. UI Components

### CanvasToolbar zoom cluster

Right-aligned after a spacer: `ZoomOut` ("−"), `ZoomLabel` (Button, shows "100%"…"800%", click = reset-to-fit, tooltip says so), `ZoomIn` ("+"). 32×32 minimum targets (cg §13); disabled with the rest via `set_all_enabled`. Buttons step along `CANVAS_ZOOM_STEPS` (next/previous from current zoom), anchored at the canvas center.

### DrawingCanvas

No new visible nodes: RasterView layout goes manual (managed by `_apply_zoom_layout()`, re-applied on `ViewportBox.resized`). Zoom/pan/hold-D all work identically in the round screen, sandbox, and avatar editor (same scene; circular mask clamping already handles out-of-circle pointer positions at any zoom).

### User Confirmation Checkpoints

- [x] **Blocking:** window-size sweep — no clipping/scaling issues reported across the 2026-07-10 windowed playtests; explicit 960×540-floor and extreme-aspect checks ride the qa-backlog batchables
- [x] **Blocking:** trackpad session — owner-confirmed 2026-07-10 after the rework (hold-D draw, D-as-click, minimap navigation, pan; "that's great")
- [ ] Batchable (→ qa-backlog): mouse-path zoom/pan feel (wheel, middle-drag), zoom-cluster button feel, D-key + Fill interaction, zoomed replay display in sandbox, extreme window aspects

---

## 8. State Management

None beyond the canvas view state (§2/§5). No new autoloads or EventBus signals.

---

## 9. Integration Points

### Depends on

- Slice 1: the single `_display_to_internal` mapping choke point and stroke lifecycle seams
- Slice 16: eraser-cursor / text-chip display scaling (gain the `_zoom` factor)

### Provides

- Every current and future screen inherits window scaling (including Slice 12's Steam playtests on varied machines)
- The art pass (after Slice 14) restyles screens on top of a sane scaling baseline instead of fighting 1:1 pixels
- `draw_hold` is the precedent for future input-accessibility actions

### Consistency-guide updates on completion

- §8 (UI/Scene Patterns): note the project-wide stretch mode + minimum window size; screens must stay container/anchor-driven (no absolute-pixel layouts)

---

## 10. Edge Cases

- **Zoom = 1 identity:** `map_display_to_internal(p, size, internal, 1.0, ZERO)` must equal today's mapping exactly (regression-pinned) — zoom off = Slice 1 behavior.
- **Stroke across a zoomed edge:** motion outside the ViewportBox keeps clamping to the canvas edge in *internal* space (existing behavior, inherited through the mapping).
- **D pressed while typing:** chat / text-row `LineEdit` consumes the key → `_unhandled_key_input` never fires. Pressing D over UI outside the canvas rect: ignored (pointer guard).
- **D pressed mid-mouse-stroke (or vice versa):** IDLE guard makes sources mutually exclusive; the non-source's release never ends the stroke (source flag).
- **Key held at deadline:** `set_tools_enabled(false)` → existing `_commit_live_stroke()` path commits the partial stroke, same as a held mouse button today; the `_process` fallback then idles the state.
- **Focus loss while key-drawing:** `NOTIFICATION_APPLICATION_FOCUS_OUT` handler already force-ends strokes; source-aware `_process` fallback covers missed releases.
- **Pan at zoom 1:** clamp range collapses to (0,0) — panning is structurally impossible when fit.
- **Window resize while zoomed:** `ViewportBox.resized` re-applies layout with re-clamped pan; zoom (a pure ratio) survives, no drift.
- **Wheel-zoom with pointer off-canvas:** gui_input only fires over the ViewportBox — no global wheel hijacking.
- **Gates/CI:** drivers call stroke seams with internal coordinates directly — zoom/pan/stretch are display-side and invisible to them.

---

## 11. Testing Strategy

### Unit (headless)

- `test_drawing_canvas.gd` additions:
  - zoom math: `clamp_zoom` bounds; `clamp_pan` range per zoom (collapses at 1×); `pan_after_zoom` keeps the cursor's canvas point fixed (round-trip through `map_display_to_internal`); zoom-1 identity vs the legacy mapping
  - stroke-source semantics: key-started stroke ignores an LMB release; mouse-started stroke ignores a `draw_hold` release; `Input.action_press("draw_hold")` / `action_release` drive the `_process` fallback (GdUnit scene runner frames)
  - view reset on `begin_drawing` / `load_doc` / rotate
- `test_canvas_scenes.gd`: toolbar zoom cluster exists, emits its three signals, `set_zoom_display` renders "150%" style labels; canvas scene instantiates with manual RasterView layout at fit

### Integration / gates

- All three gates (`verify_lobby.sh`, `verify_round.sh`, `verify_resilience.sh`) unchanged and must stay green — run through the guarded wrapper (kill `dev_run.sh` instances first; they hold the dev ENet port)

### Manual (owner)

- §7 confirmation checkpoints — the two blocking items are the point of the slice; input *feel* is untestable headless (established Slice 1/16 precedent)

---

## 12. Implementation Checklist

### Project scaling
- [ ] `project.godot`: stretch mode/aspect; `[input]` `draw_hold` (physical D)
- [ ] `GameConstants` Slice 18 banner (§2 constants)
- [ ] `Nav._ready()`: minimum window size

### Canvas zoom/pan
- [ ] `DrawingCanvas`: static zoom math (4 funcs); `_zoom`/`_pan` state; `_apply_zoom_layout()` + `ViewportBox.resized` hook; RasterView manual layout
- [ ] `_display_to_internal` delegates to `map_display_to_internal`; eraser cursor + chip preview gain `_zoom`
- [ ] Input: Ctrl/Cmd+wheel, `InputEventMagnifyGesture`, `InputEventPanGesture`, plain/Shift wheel, middle-drag `PANNING` state
- [ ] View reset on begin/load/rotate
- [ ] `CanvasToolbar`: zoom cluster (scene + signals + `set_zoom_display` + `set_all_enabled`)

### Hold-to-draw
- [ ] `_unhandled_key_input` press/release paths + pointer-over-canvas guard; `_stroke_from_key` flag
- [ ] Source-aware release fallbacks (`_process`, `_input`)

### Tests, gates & docs
- [ ] Unit additions (§11); full suite green; scene smokes updated
- [ ] All 3 gates PASS (guarded wrapper)
- [ ] Decision log entry (mini-slice insertion; stretch-mode choice; zoom-inside-viewport rationale)
- [ ] Consistency guide §8 stretch note
- [ ] qa-backlog Slice 18 section (batchables from §7)
- [ ] Implementation notes + WHERE_WE_ARE update

---

**End of Slice 18 (mini): Canvas Ergonomics & Display Scaling**


---

> **Update (2026-07-10, same session):** owner-directed rework after the first playtest. (1) **D doubles as a click**: outside the canvas a `draw_hold` press synthesizes a full left-click pair at the pointer (`Viewport.push_input`, viewport-local so the stretch transform can't skew it) — toolbar/palette/toggles/chat focus all work pointer+D, no per-widget wiring. (2) **Minimap navigation** (`CanvasMinimap`, corner inset while zoomed): whole-drawing thumbnail + view rectangle; click-drag or **hold-D-and-move** over it centers the view — the "where am I zoomed?" and "how do I move?" answers in one widget. (3) **Gesture routing fix**: trackpad magnify/pan gestures moved from `gui_input` to `_input` with an explicit canvas hit-test (gui delivery proved platform-flaky — the owner's two-finger pan never arrived); wheel events now scale by `factor` (precise trackpad scrolling glides, mouse wheels step). Known gap: text-chip drag still needs a real click-drag (D-hold drag has stuck-state risks near text fields) — batchable.

---

## Implementation Status

**Status:** COMPLETE (core-confirmed)
**Completed:** 2026-07-10 (session 9)
**Implementation Notes:** `TDD/18-canvas-ergonomics-implementation-notes.md`

### Summary of Deviations
- Same-session owner rework (see Update banner): D-as-click outside the canvas, `CanvasMinimap` navigation inset (+ solid frame/shadow polish), gestures rerouted from `gui_input` to `_input` (platform-flaky delivery — the original pan never arrived on the owner's trackpad), wheel `factor` scaling.
- Two test-harness fixes with root causes in the implementation notes: simulated-input suites must park `content_scale_mode` under the new stretch mode (`test_text_drag_drop.gd`), and a latent f32/f64 exact-compare in the chat-prominence test surfaced by the stretch base size (epsilon fix).
- 505/505 tests green (+18); all 3 gates PASS after both the first build and the rework. Owner confirmed the trackpad flow (hold-D, D-as-click, minimap navigation, pan) through the 2026-07-10 iterations ("that's great"); no scaling issues reported across the session's windowed playtests — explicit min-size/extreme-aspect checks remain as qa-backlog batchables.
