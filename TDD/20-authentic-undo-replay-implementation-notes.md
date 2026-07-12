# Slice 20 Implementation Notes: Authentic Undo in Replays

**Implemented:** 2026-07-12 (session 14, same session as Slices 19 + 14) | **TDD:** `20-authentic-undo-replay.md`
**Machine state:** 580 tests green; all 3 gates PASS
**Same batch:** owner-found D-key bug fixed (see below)

---

## Built exactly per the mini-TDD

- `UndoOp` (`game/drawing/undo_op.gd`), `DrawingOp.Type.UNDO` appended, wire shape `{"t": "undo"}` in to_dict/from_dict.
- `DrawingDoc.resolve_effective()` / `effective_ops()` — the single home of undo semantics (undo cancels the previous effective op; undo-on-empty tolerated).
- `DocRasterizer.rasterize` reads effective ops; new `rasterize_prefix(doc, count)` is the replay revert primitive; `apply_op` on an UndoOp is a push_error no-op (needs doc context).
- `ReplayPlayer`: undo branches in `_apply_up_to_playhead` (revert at op start, then the standard non-stroke pacing beat) and `skip_to_end`. The planner needed **zero changes** — its generic non-stroke branch already schedules the marker identically, so the planner/player drift guard held untouched.
- Canvas: `_press_undo` appends the marker; undo guard, toolbar undo-enabled state, and rotate's nothing-to-lose check all read **effective** emptiness; `op_undone` emits the effective remaining count.
- `WrapUpCalculator._op_count` counts NET ops (undo decrements, floored at 0) — Da Vinci/Minimalist marks stay honest.

## Notes & lessons

1. **Golden trick:** the new `undo_history` golden is constructed so its effective result equals the existing `stroke_fill` golden — its baked hash is deliberately the SAME constant. The hash equality IS the semantic pin, and no re-bake was needed. The golden also rides `GoldenDocs.all()`, so the replay end-state-equals-rasterize sweep covers undo automatically.
2. **Lambda by-value strikes again** (session-8 rule): the first draft of the mid-replay revert test reassigned a captured String inside an `op_started` lambda — silently never propagated. Container-append pattern fixed it.
3. Raw-vs-effective reads are deliberate and documented in the TDD: Speed Demon finish time + `natural_duration_sec` stay RAW (undone strokes are real drawing time); text censoring walks raw ops (censoring undone text is harmless); `AVATAR_MAX_OPS` counts raw (sanity cap).
4. Old saved collection docs carry no markers → byte-identical behavior; DrawingDoc v1 extended in place (pre-release, decision log 2026-07-12).

## D-key fixes (same batch, owner-found + owner-requested)

1. **Overlay hit-testing:** `_begin_key_draw`'s geometric canvas-rect test inked under the expanded palette overlay instead of clicking its swatches (the overlay floats over the canvas). Now cross-checks `Viewport.gui_get_hovered_control()` via `_pointer_over_canvas`/`_hover_allows_canvas` — any control genuinely hovered above the canvas wins; a null hover (headless) trusts the rect.
2. **D is a HELD button, not an instant click** (owner tweak after live-testing): D-down outside the canvas synthesizes a left-button PRESS (`_key_button_down`, `_key_press_active`), D-up synthesizes the RELEASE at the pointer's CURRENT position — tap = click (unchanged), hold+move = full drag-and-drop through Godot's own drag pipeline. **Root cause of the first attempt failing (owner live-test):** the engine's drag detection reads the button mask **on the motion events** (the GdUnit drag recipe stamps it — that's the tell), and real OS motions carry no mask while only D is held. Fix: while the synthetic press is active, the canvas `_input` consumes each real motion and re-issues a copy carrying `MOUSE_BUTTON_MASK_LEFT` (meta-tagged against recursion; relative computed viewport-locally so the stretch transform never skews the drag threshold). Text chip and expanded-palette favorites drag with D with zero changes to them; a D-drag drops onto the canvas (chip placement). Stuck-state guard: focus loss releases the synthetic button. The interim `_key_click_at` instant-pair helper did not survive review — removed with its redundant test (owner rule: leave no non-contributing changes). Tests: held-state machine + overlay yield in `test_drawing_canvas.gd`; **D-drag ENGAGEMENT is headless-proven** (`test_key_hold_drag_engages_with_chip_data`: maskless runner motions → drag state + chip payload + clean end on D-up); final drop delivery is owner-verified live (headless can't deliver drops — Slice 16 lesson).

## Owner checks (batchable, qa-backlog Slice 20 section)

Replay feel with undos (full-replay reveal + victory lap + collection viewer); D-click on expanded palette swatches confirmed live.
