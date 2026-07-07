# Slice 16 (mini): In-Image Text Tool
## Players place text directly into their drawings, paint-editor style; the caption pipeline is removed

**Version:** 1.0
**Last Updated:** 2026-07-07
**Dependencies:** Slice 1 (DrawingDoc/DocRasterizer/ReplayPlayer/DrawingCanvas), Slice 3 (submission validation), Slice 5 (caption pipeline — being removed), Slice 6 (settings surface — captions row removed)
**Provides:** TEXT op in the DrawingDoc format; deterministic pixel-font raster; canvas text-placement UI; caption-free reveal/spotlight pipeline

> **Scheduling note:** owner-inserted mini-slice (decision log 2026-07-07, "captions retired"). Runs between Chunk 11 (Slice 8) and Chunk 12 (Slice 9). Numbered 16 as the next free TDD number — the overview's chunk plan stays authoritative for order.

---

## 1. Overview

Captions (Slice 5) are retired: players found text-under-the-drawing less fun than text **in** the drawing. This slice adds a Text tool to the drawing canvas: pick the tool, click the canvas, type, press Enter — the text is rasterized into the image as pixels, in the current palette color, at one of three sizes. Because text becomes ops in the doc, it rides every existing pipeline for free: submission, reveal, judging, replay, collection saves, export.

### Scope

**In Scope:**
- `TextOp` — a new DrawingDoc op type (`"t": "text"`), serialized in the existing v1 format
- `PixelFont` — an embedded 8×8 bitmap glyph table (ASCII 32–126), CPU-blitted by `DocRasterizer` (deterministic: integer math, no OS font rasterization, no AA)
- Canvas UI: Text tool button, click-to-place inline entry box, live preview, Enter commits / Esc cancels; existing size buttons pick text size, palette picks color
- Host-side `TextFilter.censor` on text-op content at submission (and the same censor locally at commit, so the drawer sees what everyone sees)
- **Complete removal of the caption pipeline**: caption input UI, submission payload field, host caption validation, reveal-entry field, beat timing term, grid-cell/stage/spotlight caption labels, `comments_enabled` setting + presets row + Custom checkbox (this also permanently fixes the qa-backlog "caption box leftover from pre-2026-07-07 host profiles" — the restored key is simply ignored once the field is gone)

**Out of Scope (later / never):**
- Moving/editing committed text (undo removes it; retype to change) — party-game speed over editor features
- Multi-line text, rotation, outlines/shadows, freeform fonts or sizes
- Persisting quick-slot-style text presets
- Slice 11 avatar editor implications beyond mask-correct blitting (the hook is honored like every op)

### User Flow

1. Drawer clicks the **T** (Text) tool → cursor over canvas indicates placement mode.
2. Click on the canvas → a small entry box appears at the click point; typing shows a live pixel-font preview at the placement position, in the current color/size (already censored, so no surprises at reveal).
3. **Enter** (or clicking elsewhere) commits: the text becomes a `TextOp` in the doc and is stamped into the raster. **Esc** cancels. Empty text commits nothing.
4. Undo removes the whole text op, like any op. Replays show text popping in as a beat, like fills.

---

## 2. Data Models

### TextOp

**File: `game/drawing/text_op.gd`** (`class_name TextOp extends DrawingOp`, `Type.TEXT` added to the enum)

| Field | Type | Description |
|-------|------|-------------|
| color_index | int | Palette index (same rules as stroke/fill) |
| size_index | int | 0/1/2 → `GameConstants.TEXT_SCALES` integer scale factors |
| x, y | int | Top-left of the first glyph cell, internal canvas coords, in-canvas (clip handles overflow right/bottom) |
| text | String | 1–`TEXT_MAX_CHARS` chars, ASCII 32–126 only |

**Serialized form (canonical wire/save format):**

```json
{"t": "text", "c": 4, "s": 1, "x": 120, "y": 88, "str": "MOO"}
```

**Format version stays 1.** Adding an op type is additive: every existing v1 doc remains valid; no shipped build exists that would need to read new docs. `from_dict`'s strict parser gains a `"text"` branch with full validation (see §10). Recorded in the decision log; consistency guide §6 format example updated.

### PixelFont

**File: `core/constants/pixel_font.gd`** — 95 glyphs (ASCII 32–126), 8×8 px each, stored as 8 bytes per glyph (one byte per row, top-to-bottom; bit *n* of a row = pixel at x = *n*, LSB leftmost). Data authored from the public-domain `font8x8_basic` table. Append-only, like the palette: committed glyph bitmaps are part of the deterministic raster contract and must never change silently (golden tests pin them).

Constants added to `GameConstants` (Slice 16 banner):

```gdscript
const TEXT_MAX_CHARS: int = 50                      # one full-width line at smallest size
const TEXT_SCALES: PackedInt32Array = [2, 3, 4]     # size indices 0/1/2 -> 16/24/32 px glyphs
const TEXT_GLYPH_PX: int = 8                        # PixelFont cell size (advance = 8 * scale)
```

---

## 3. Event/Action Definitions

No new RPCs, signals, or phases. Changes to existing payload shapes:

| Payload | Change |
|---------|--------|
| Drawer submission (`request_submit_drawing`) | `{"doc": ...}` only — the `"caption"` key is gone |
| REVEAL wire entries | `{drawing_id, doc}` — the `"caption"` key is gone |

Docs containing text ops flow through every existing channel unchanged (submission, reveal sync, collection save, export).

---

## 4. Storage Schema Extensions

None. Docs with text ops serialize/save through the existing v1 envelope. Existing collection items are unaffected.

---

## 5. State Machines

`DrawingCanvas.InputState` gains `TEXT_EDITING`:

| Current | Trigger | New | Notes |
|---------|---------|-----|-------|
| IDLE | canvas click with Text tool active | TEXT_EDITING | Entry box + preview appear at the clamped click point |
| TEXT_EDITING | Enter / click outside the entry box | IDLE | Commit if non-empty (censored), else no-op |
| TEXT_EDITING | Esc | IDLE | Cancel, preview cleared |
| TEXT_EDITING | `set_tools_enabled(false)` or `get_doc()` | IDLE | **Auto-commit** pending non-empty text — the deadline auto-submit must capture what the drawer typed |

Color/size changes while editing update the live preview. Toolbar/undo are gated to IDLE exactly as today.

---

## 6. Business Logic

### DocRasterizer TEXT branch

`apply_op` gains a `_blit_text(img, op, mask)` case:

- For each character: look up the 8-byte glyph; skip unknown chars defensively (parser guarantees the charset — belt and suspenders).
- For each glyph row, walk the 8 bits into **runs of consecutive set bits**; each run becomes one `fill_rect(Rect2i(x0, y0, run_len * scale, scale))` in the palette color — the same native-clipped, hard-edged approach as circle-stamp spans. Integer math only; no AA; deterministic on all targets.
- Masked path (Slice 11 hook): per-pixel writes under `mask.get_pixel(...).a >= 0.5`, mirroring `_stamp_circle`.
- Advance per char = `TEXT_GLYPH_PX * scale`. Pixels beyond the right/bottom edge clip naturally (`fill_rect` clips; per-pixel path bounds-checks).

### Replay

`TextOp` is a non-stroke op: `ReplayPlayer` and `ReplayPlanner` both already route non-`Stroke` ops to the `REPLAY_NON_STROKE_OP_SEC` beat (apply-at-start, pacing duration) — text pops in like a fill. The planner/player drift-guard test gains text-op cases to pin this.

### Host-side text censoring (submission)

In `GameSession.submit_drawing`, after the existing `from_dict` validation passes: walk `doc.ops`; for each text op, `TextFilter.censor(str)` then re-truncate to `TEXT_MAX_CHARS` (censoring can lengthen). If anything changed, the censored dict is what gets stored/broadcast — the host is the referee; clients render the censored doc identically everywhere. Replaces `_clean_caption` (deleted).

The canvas applies the **same censor at commit time** so the drawer's local view matches what the table will see (chat precedent: censored text is normal, not an error).

### Caption pipeline removal

| Location | Change |
|----------|--------|
| `ui/round/caption_input.gd/.tscn` | **Deleted**; `%Caption` node removed from `draw_screen.tscn` |
| `ui/round/draw_screen.gd` | Caption wiring + `comments_enabled` read removed; submission payload is `{"doc": ...}` |
| `game/session/submission.gd` | `caption` field removed |
| `game/session/game_session.gd` | `_clean_caption` removed; reveal entries lose `"caption"`; gains the text-op censor pass |
| `game/session/reveal_director.gd` | `compute_beat_secs(doc, settings, drawer_count)` — caption param + `REVEAL_CAPTION_SECS` term removed |
| `ui/round/reveal_judging_screen.gd` | Stage caption label + cell caption labels removed; the fixed-shape social row keeps its center slot as a spacer so cell alignment is unchanged |
| `ui/round/winner_spotlight.gd`, `resolution_screen.gd` | Caption label / pass-through removed |
| `game/session/settings.gd` | `comments_enabled` field removed from the class, `apply`, `to_dict`, `from_dict` (stale profile keys become ignored — the qa-backlog profile-leftover fix) |
| `core/constants/settings_defaults.gd` | `comments_enabled` rows removed from all three presets |
| `ui/lobby/mode_settings_panel.gd` | Captions checkbox + summary term removed |
| `core/constants/game_constants.gd` | `CAPTION_MAX_CHARS`, `REVEAL_CAPTION_SECS` removed |
| `tools/ci/round_ci_driver.gd` | Caption submission/assertions replaced by text-op assertions (see §11) |

---

## 7. UI Components

### CanvasToolbar

New **T** toggle button in the tool group (`Tool.TEXT`), after Fill. Same 32×32 minimum target, disabled with the rest by `set_all_enabled`.

### DrawingCanvas text entry

- Click in TEXT tool → clamp click to internal coords → spawn a minimal single-line `LineEdit` overlay near the display-space click point (`max_length = TEXT_MAX_CHARS`, charset-filtered to ASCII 32–126 on input).
- Live preview: on every text change, blit the censored text into a transparent canvas-sized `Image` shown by a `PreviewView` TextureRect stacked over the raster view — the preview *is* the committal raster, same blitter, so what you see is exactly what commits.
- Commit path appends the op, stamps it into `_raster` via `DocRasterizer.apply_op`, emits `op_committed`/`doc_changed` — identical lifecycle to fill.
- Size buttons (S/M/L) map to text scale while the Text tool is active; palette color applies live.

### User Confirmation Checkpoints

- [ ] **Blocking:** glyph legibility/readability in the sandbox (type the full alphabet + digits at all 3 sizes) — the font table is hand-committed; the owner eyeball is the garble check
- [ ] **Blocking:** full round flow — place text, submit, see it in reveal/judging/replay on other instances
- [ ] Batchable (→ qa-backlog): entry-box ergonomics, preview positioning near canvas edges, text-tool feel under time pressure

---

## 8. State Management

None beyond the canvas input state (§5). No new autoloads, no new EventBus signals.

---

## 9. Integration Points

### Depends on

- Slice 1: op/rasterizer/replay architecture (this slice is a fourth op type done "the Slice 1 way")
- Slice 3: `submit_drawing` validation seam (censor pass slots in after `from_dict`)
- Slice 5/6: the caption/settings surfaces being removed

### Provides

- **Text in docs everywhere**: Slice 8 exports/thumbnails and Slice 10 wrap-up screens render text with zero changes (they all go through `DocRasterizer`)
- **`PixelFont`**: available to Slice 11 (avatar editor gets the text tool for free via `DrawingCanvas`) and any future deterministic text-on-image need
- Slice 13 (moderation) inherits host-side text censoring as the single choke point for in-image text

### Consistency-guide updates on completion

- §6 DrawingDoc format example gains the text op line
- §review checklist row "typed text passes through TextFilter" now includes in-image text

---

## 10. Edge Cases

- **Malformed text ops** (strict `from_dict` rejection rows): non-string `str`; empty `str`; length > `TEXT_MAX_CHARS`; any char outside ASCII 32–126; `c`/`s` out of range; `x`/`y` non-int or out of canvas bounds → doc rejected (null), same as every other malformed op.
- **Censor lengthening:** censor → truncate order guarantees the cap; host and client apply the identical sequence so rasters match.
- **Deadline during typing:** pending text auto-commits on `get_doc()`/`set_tools_enabled(false)` — the auto-submit at 0:00 captures typed-but-uncommitted text instead of dropping it.
- **Text at the right/bottom edge:** allowed; glyph pixels clip. UI keeps the entry box on-screen even when the anchor is near an edge.
- **Hostile raster cost:** a doc packed with max-length text ops is bounded by `MAX_DRAWING_BYTES`, and per-byte blit cost is far below the existing flood-fill worst case — no new cap needed (accepted, matching the current threat model).
- **Blank detection unaffected:** text ops are content like any op; `is_blank` remains host-synthesized-only.
- **Rotate:** clears the doc as today — text dies with everything else (existing confirm dialog covers it).
- **Old profiles with `comments_enabled: true`:** key is no longer read → ignored → qa-backlog leftover resolved permanently.

---

## 11. Testing Strategy

### Unit

- `tests/core/constants/test_pixel_font.gd` — every glyph exists, is 8 bytes, non-space glyphs have ≥1 set pixel; table size pinned (95)
- `tests/game/drawing/test_drawing_doc.gd` — text-op round-trip (serialize → parse → serialize identical); full rejection-matrix rows from §10
- `tests/game/drawing/test_doc_rasterizer.gd` — **new golden hash** for a doc mixing stroke + fill + text (bake per the documented procedure); masked-blit parity spot check; clip-at-edge determinism
- `tests/game/drawing/test_replay_player.gd` / `test_replay_planner.gd` — text op consumes `REPLAY_NON_STROKE_OP_SEC`, applies at op start; **drift-guard extended with text ops**; replay end-state == full raster
- `tests/game/session/test_game_session.gd` — host censors blocklisted text ops at submission (configure `TextFilter` seam); censored doc is what reveal entries carry; entries have no `caption` key
- Settings/presets — `comments_enabled` gone from `to_dict`/`from_dict`/preset identity tests; stale profile key ignored
- Reveal director — beat secs without the caption term

### Integration / gates

- `verify_round.sh` (guarded wrapper, per RAM-incident protocol): CI driver submits one doc containing a text op → asserts it survives to every peer's reveal entries with correct content and no `caption` key anywhere
- `verify_lobby.sh` unchanged — must stay green (settings field removal touches lobby sync)

### Scene smoke + manual

- Updated draw/reveal/spotlight scenes instantiate clean; sandbox smoke includes the Text tool
- Owner: §7 confirmation checkpoints (glyph legibility is **blocking** — hand-committed font data)

---

## 12. Implementation Checklist

### Data & raster core
- [ ] `Type.TEXT` in `drawing_op.gd`; `game/drawing/text_op.gd`
- [ ] `core/constants/pixel_font.gd` (95-glyph table + lookup)
- [ ] `GameConstants`: Slice 16 banner (TEXT_MAX_CHARS, TEXT_SCALES, TEXT_GLYPH_PX); remove CAPTION_MAX_CHARS, REVEAL_CAPTION_SECS
- [ ] `DrawingDoc`: to_dict/from_dict text branch + validation
- [ ] `DocRasterizer._blit_text` (runs → fill_rect; masked per-pixel path)
- [ ] Golden bake + unit suites (font, doc, rasterizer, replay/planner drift)

### Host pipeline
- [ ] `GameSession.submit_drawing` text-censor pass; delete `_clean_caption`; entries drop `caption`
- [ ] `Submission.caption` removed; `RevealDirector.compute_beat_secs` signature change

### Canvas UI
- [ ] `CanvasToolbar` Text button + `Tool.TEXT`
- [ ] `DrawingCanvas` TEXT_EDITING state: entry overlay, live censored preview, commit/cancel/auto-commit paths
- [ ] Size/color live-apply while editing

### Caption removal (UI + settings)
- [ ] Delete `caption_input.gd/.tscn`; purge draw_screen, reveal_judging_screen, winner_spotlight, resolution_screen
- [ ] `settings.gd`, `settings_defaults.gd`, `mode_settings_panel.gd` — `comments_enabled` gone everywhere
- [ ] Update affected tests (presets identity, session, reveal components)

### Gates & docs
- [ ] `--import` after new class_name scripts; full suite green
- [ ] `round_ci_driver.gd` text-op assertions; both gates PASS through the guarded wrapper
- [ ] Decision log entry (format stays v1; font choice; censor-not-reject)
- [ ] Consistency guide §6 format example updated
- [ ] qa-backlog: strike caption items with notes; append new batchable items
- [ ] Implementation notes + WHERE_WE_ARE on completion

---

**End of Slice 16 (mini): In-Image Text Tool**

---

> **Update (2026-07-07, same session):** §7's canvas placement UI was reworked owner-directed after the first playtest: the click-to-place floating entry box is replaced by a **Text row under the toolbar** (type → rendered chip → drag onto the canvas; drop commits centered on the cursor). `Tool.TEXT` and the `TEXT_EDITING` input state are gone; an **Eraser** tool (background-color strokes, `Palette.ERASE_COLOR_INDEX`) joined the toolbar. Data model, raster, validation, and censoring are unchanged. See decision log "Slice 16 rework: drag-to-place text (Option B) + Eraser tool".
