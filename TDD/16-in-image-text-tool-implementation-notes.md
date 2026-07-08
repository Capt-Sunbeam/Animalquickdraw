# Implementation Notes: Slice 16 (mini) — In-Image Text Tool

**Completed:** 2026-07-07 (implementation + automated gates; owner blocking checks pending — see Testing Summary)
**TDD Document:** `TDD/16-in-image-text-tool.md` (owner-approved before build, same session)

## Implementation Summary

Text is now a first-class drawing op. `TextOp` (`{"t":"text","c","s","x","y","str"}`) joined stroke/fill/clear in the v1 DrawingDoc format with strict `from_dict` validation (ASCII 32–126, 1–50 chars, in-canvas anchor, scale 0–2). `PixelFont` embeds the public-domain `font8x8_basic` table (fetched from the canonical repo — 95 glyphs, 760 bytes, append-only like the palette); `DocRasterizer._blit_text` renders it CPU-side as per-row bit-runs → `fill_rect` spans at integer scales [2,3,4], with a per-pixel masked path for Slice 11. Replay treats text as a non-stroke beat (applies at op start, `REPLAY_NON_STROKE_OP_SEC`) — `ReplayPlayer` and `ReplayPlanner` needed **zero changes** (their non-stroke branches are generic; the drift-guard test now includes text docs).

The canvas grew a **T** tool: click → floating `LineEdit` + live preview blitted by the *same* rasterizer path that commits (censored live — WYSIWYG down to the censor stars), Enter/click-away commits, Esc cancels, undo removes the op. Pending text auto-commits on `get_doc()`/tool lockout so the deadline auto-submit captures typed-but-unplaced text.

The caption pipeline is fully deleted: input UI, `Submission.caption`, reveal-entry `caption` key, `RevealDirector` caption term, stage/cell/spotlight labels, `comments_enabled` (field + presets + Custom checkbox), `CAPTION_MAX_CHARS`/`REVEAL_CAPTION_SECS`. Host-side moderation moved into the doc: `GameSession._censor_text_ops` censors TEXT-op content at submission (censor → re-truncate; never rejects).

## Deviations from Original Design

None of substance — the build followed the mini-TDD as approved. Two notes:

### Round CI driver hardening (beyond TDD scope)
**What happened:** the first `verify_round.sh` run timed out with the game parked in POOL_SETUP. Root cause was environmental, not the slice: the host's restored profile (`last_lobby_settings`) carried `pool_source: PLAYER_SUBMITTED` from the owner's Slice 7 playtest, and POOL_SETUP is deadline-less.
**Fix:** the driver now pins `pool_source = BUILT_IN` alongside its `round_count` pin. Rule recorded in the decision log: CI drivers pin every setting their script's flow depends on.

### Grid-cell caption slot became a spacer, not a removal
The Slice 5 fixed-shape social row (owner alignment fix, 2026-07-06) keeps its center slot as an expanding spacer so cell layouts are pixel-identical with captions gone.

## Files Created/Modified

**Created:** `core/constants/pixel_font.gd`, `game/drawing/text_op.gd`, `TDD/16-in-image-text-tool.md`, `tests/core/constants/test_pixel_font.gd`
**Deleted:** `ui/round/caption_input.gd/.tscn`
**Modified (production):** `game/drawing/drawing_op.gd` (Type.TEXT), `drawing_doc.gd` (text serialize/parse), `doc_rasterizer.gd` (`_blit_text` + masked fill_rect), `core/constants/game_constants.gd` (TEXT_* added; CAPTION_* removed), `game/session/game_session.gd` (`_censor_text_ops` replaces `_clean_caption`; entries drop caption), `submission.gd`, `reveal_director.gd` (signature), `settings.gd` + `core/constants/settings_defaults.gd` + `ui/lobby/mode_settings_panel.gd` (comments_enabled gone), `ui/canvas/canvas_toolbar.gd/.tscn` (Text tool), `ui/canvas/drawing_canvas.gd` (TEXT_EDITING state, entry box, preview layer), `ui/round/draw_screen.gd/.tscn`, `reveal_judging_screen.gd`, `winner_spotlight.gd/.tscn`, `resolution_screen.gd` (caption purge), `core/util/text_filter.gd` + `game/session/session_client.gd` (comments), `tools/ci/round_ci_driver.gd` (text-op assertions + pool_source pin)
**Modified (tests):** `golden_docs.gd` (make_text + text_mixed fixture), `test_doc_rasterizer.gd` (new golden + 3 blit tests), `test_drawing_doc.gd` (round-trip/shape/rejection matrix), `test_replay_player.gd`/`test_replay_planner.gd` (text beats + drift guard), `test_game_session.gd`/`test_game_session_reveal.gd` (censor tests; caption tests removed), `test_reveal_director.gd`, `test_settings_defaults.gd`, `test_mode_settings_panel.gd`, `test_reveal_components.gd`, `test_drawing_canvas.gd` (8 text-tool tests), `test_canvas_scenes.gd`

## Key Implementation Details

- **Golden baked:** `text_mixed` (stroke + text at all 3 scales + punctuation + edge-clipped line) = `9abe1b3d…`; the six Slice 1 goldens came out byte-identical, proving the raster path for old op types is untouched.
- **Own-drawing detection constraint:** `SessionClient.is_own_drawing` compares the local submitted doc to the reveal entry by equality — so the canvas MUST pre-censor at commit with the exact host sequence (charset filter → `TextFilter.censor` → truncate). Both sides share one blocklist file; `_pending_text()` in the canvas and `_censor_text_ops()` on the host are the two ends of that contract.
- The preview is a transparent canvas-resolution `TextureRect` layered over the raster view inside the SubViewport, rebuilt on orientation flips; the entry box is a `top_level` LineEdit clamped to the canvas frame.
- Hostile-input cost: max-length text ops blit fewer pixels per payload byte than the existing flood-fill worst case — no new cap needed (TDD §10).

## Testing Summary

- **Full suite: 365/365 green, 0 orphans** (350 → 365: +23 new/extended, −8 caption tests).
- **Gates (guarded wrapper, RSS+wall-clock watchdog): `verify_lobby.sh` PASS; `verify_round.sh` PASS** — every peer's reveal entries now carry the submitted TEXT op intact with no `caption` key (new CI assertions).
- **User confirmation: PENDING (blocking):** (1) font legibility — type the alphabet/digits at all 3 sizes in the Canvas Sandbox (the glyph table is data; the owner eyeball is the garble check); (2) full-round flow — place text, submit, see it in reveal/judging/replay on other instances. Batchable items → qa-backlog Slice 16 section.

## Lessons Learned

- Fetching canonical public-domain data (font table) beats hand-transcription: zero glyph bugs, and the golden pinned it in one bake.
- A new op type that mimics an existing op's lifecycle (fill) rides every downstream system — replay, reveal, export, collection — with no changes; the planner/player generic non-stroke branch paid off exactly as designed in Slice 1.
- CI that inherits host-profile state is CI that changes behavior when the owner playtests; pin what the script assumes.

## Known Limitations

- No outline/shadow on text — low-contrast color-on-fill combos are on the owner to judge (qa-backlog).
- Entry box doesn't track window resizes mid-edit (cosmetic; batchable).
- Unsupported characters are silently dropped rather than hinted at in the box (batchable UX call).
- The LineEdit shows the raw typed string; only the preview shows the censored/filtered committal text (they converge at commit).

## Update (2026-07-07, same session): drag-to-place rework + Eraser

Owner confirmed both blocking checks on the first build (font legible in the sandbox; in-round flow worked as implemented), then directed a UX rework (decision log "Slice 16 rework"):

- **Placement is now drag-and-drop (Option B):** persistent Text row under the toolbar (`%TextInput` + `%TextChip`); the chip, the drag preview (scaled to the canvas display factor, held by its center), and the drop-hover preview all render through the committal `DocRasterizer` path with live censoring — WYSIWYG end to end. Drop anchor = cursor-centered, clamped in-canvas (`_anchor_for_internal` is the headless-test seam). Text persists in the box for repeat stamps. Removed: floating LineEdit, `TEXT_EDITING` state, `Tool.TEXT`, and all auto-commit-pending-text hooks (typed-but-undragged text is deliberately NOT submitted).
- **Eraser:** `Tool.ERASER` strokes in `Palette.ERASE_COLOR_INDEX` (0 = white = background) — deterministic, undoable, replays visibly; palette selection untouched. Circle-stamp/fill/format all unchanged.
- Godot detail: chip drag via `set_drag_forwarding` on the chip (drag source) and the SubViewportContainer (drop target); `_can_drop_data` doubles as the hover-preview painter; `NOTIFICATION_DRAG_END` clears it.
- Tests rewritten to the new seams (drop anchor math, repeat stamps, chip visibility, eraser color + pixel restore); 376/376 green, both gates PASS. Owner re-check of the drag feel + eraser is the remaining blocking item.

## Final update (2026-07-07, session close): drop delivery root cause + single preview

The rework's drag initially didn't land in the owner's windowed test. True root cause (found via a headless repro + reading Godot 4.6 `viewport.cpp`): **since Godot 4.5 the drag system only offers drops to `gui.target_control`, and a `SubViewportContainer` becomes `target_control` ONLY when its `mouse_target` property is true — default false.** `CanvasDropTarget._ready()` now sets it, and `tests/ui/canvas/test_text_drag_drop.gd` pins the property (unsetting it would break drops with zero other test failures) plus exercises the real drag-source path and the exact drop handler chain. Headless cannot verify final delivery (the WM mouse-over pipeline needs `windowmanager_window_over`) — owner-verified windowed. A duplicate-preview report followed (floating drag preview + on-canvas hover preview showed the word twice); the on-canvas hover layer was removed — the cursor-following preview is the single representation. Owner confirmed everything 2026-07-07; **Slice 16 COMPLETE** (380/380 tests; both gates PASS).
