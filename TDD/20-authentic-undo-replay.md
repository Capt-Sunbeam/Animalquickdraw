# Slice 20 (mini): Authentic Undo in Replays

**Version:** 1.0
**Created:** 2026-07-12 (session 14) — owner-requested mini-slice (Slice 16/18/19 precedent)
**Dependencies:** Slice 1 (DrawingDoc/rasterizer/replay), Slice 5 (planner/beat schedule), Slice 10 (mark-count titles)

---

## 1. Overview

Owner request (2026-07-12): undo currently deletes history (`_press_undo` pops the op), so replays never show the stroke that was drawn and removed. Rework: **undo becomes a recorded op** — replays show the stroke drawn, a beat, then it vanishes ("authentically aligned to the user's drawing actions"; also comedy gold under full-replay reveals). Final images everywhere stay pixel-identical to today.

## 2. Design

- **`UndoOp`** (`game/drawing/undo_op.gd`, `DrawingOp.Type.UNDO` appended): wire shape `{"t": "undo"}`, no params. DrawingDoc v1 extended in place — pre-release, nothing shipped; logged in the decision log.
- **Effective resolution:** `DrawingDoc.resolve_effective(ops)` (static) + `effective_ops()` — walk the raw list; an undo cancels the previous effective op; undo on an empty effective list is a tolerated no-op (hostile-doc rule). This is the ONE place undo semantics live.
- **Final images:** `DocRasterizer.rasterize(doc)` iterates `effective_ops()` — judging cells, exports, collection thumbs, avatar resolver all unchanged by construction. New `rasterize_prefix(doc, count)` = effective raster of the first `count` RAW ops (the replay revert primitive). `apply_op` on an UndoOp is a programmer error (`push_error`, no-op) — undo needs doc context.
- **ReplayPlayer:** plays RAW ops. Schedule: UndoOp is a non-stroke op → `REPLAY_NON_STROKE_OP_SEC` beat (automatic in both player and planner — they share the generic non-stroke branch, so the drift guard keeps holding). On applying an UndoOp at index k: `_image = rasterize_prefix(doc, k + 1)` — one full re-raster per undo (same cost as the initial raster; imperceptible). `skip_to_end` gets the same branch; end state stays bit-identical to `rasterize(doc)`.
- **Canvas:** `_press_undo` appends `UndoOp` + full re-raster (which now reads effective ops); guard + `_refresh_undo_state` + `_press_rotate`'s nothing-to-lose check read **effective** emptiness; `op_undone` emits the effective remaining count. No redo (unchanged); undos never undo undos.
- **Mark counts (Slice 10 titles):** `WrapUpCalculator._op_count` counts NET effective ops from the dict (undo decrements, floored at 0) — undone strokes must not inflate Da Vinci / deflate Minimalist.
- **Deliberate raw reads (unchanged):** `natural_duration_sec` + Speed Demon's finish timestamp keep reading raw strokes — an undone stroke is still real drawing time (authenticity cuts both ways). Text censoring walks raw ops (censoring undone text is harmless). `AVATAR_MAX_OPS` counts raw ops (sanity cap; undo markers are tiny).

## 3. Edge cases

- Undo after clear → the pre-clear picture returns (ClearOp was already recorded; its docstring anticipated this).
- Consecutive undos peel multiple ops — matches live behavior.
- Hostile doc `[undo, undo]` → effective empty, renders blank, replays two beats of nothing; never crashes.
- Old saved collection docs have no undo ops → byte-identical behavior.
- Replay speed: undo beats add non-stroke time to the compressed duration → target-duration timescales absorb them exactly like fills/clears.

## 4. Testing

Doc round-trip + parser + effective semantics; rasterizer hash equalities (stroke+undo == blank; A+B+undo == A); player end-state == rasterize, mid-replay revert, skip_to_end; canvas append-marker/effective-count/disabled-at-effective-empty; calculator mark counts with undos; planner/player drift guard stays green; all 3 gates.

## 5. Checklist

- [x] UndoOp + Type.UNDO + to_dict/from_dict
- [x] resolve_effective/effective_ops + rasterize via effective + rasterize_prefix
- [x] ReplayPlayer undo branches (playhead + skip); planner needed ZERO changes (generic non-stroke branch)
- [x] Canvas undo rework (append, guards, signal)
- [x] _op_count net counting
- [x] Tests above; full suite (580) + gates green
- [x] Decision log; impl notes; WHERE_WE_ARE; qa-backlog batchable (replay feel with undos)

---

## COMPLETION STATUS (2026-07-12, session 14)

**COMPLETE — OWNER-CONFIRMED LIVE same session.** 581 tests green; 3 gates PASS. The `undo_history` golden pins the semantics by sharing `stroke_fill`'s baked hash. Owner confirmed undo replays + the D-key overlay fix ("both fixes landed well"), then requested and confirmed the D-DRAG extension ("it works now") — D outside the canvas is a held left button; the motion-mask re-issue was the missing piece (impl notes §D-key fixes). See `20-authentic-undo-replay-implementation-notes.md`.
