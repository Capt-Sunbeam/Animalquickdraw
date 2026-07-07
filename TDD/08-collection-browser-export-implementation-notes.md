# Implementation Notes: Slice 8 - Collection Browser & Export

**Completed:** 2026-07-07 (blocking export check owner-confirmed; batchable items deferred to qa-backlog per owner QA process)
**TDD Document:** [08-collection-browser-export.md](08-collection-browser-export.md)

## Implementation Summary

The collection's read side: a `Collection` button on the main menu opens a newest-first grid of saved drawings (lazy thumbnail pump, `THUMB_LOADS_PER_FRAME = 2`), with a viewer overlay offering stroke Replay (Slice 1 `ReplayPlayer`, duration cap ON, 1×/2× speed applied next press), **Export PNG** (internal-resolution raster upscaled `EXPORT_SCALE = 2`× nearest-neighbor → `user://exports/<slug>_<id8>.png`), **Share** (= export + `OS.shell_show_in_file_manager`, Linux fallback opens the folder), and **Delete** (confirm dialog; index-first removal). Thumbs are treated as a disposable cache: missing/corrupt/wrong-size regenerates from the doc and heals the cache. Everything is local-first; no RPCs, no EventBus additions.

## Deviations from Original Design

### Adapted to Slice 4's shipped store, not the TDD's assumed contract
**Original Plan:** instance-based `CollectionStore` at `game/collection/` with `add()`; index rows `{id, prompt, saved_at:int, orientation}`; thumbs 256×192.
**Actual Implementation:** Slice 4 shipped a **static** `CollectionStore` at `core/save/collection_store.gd` with `save_drawing(doc, prompt, session_drawing_id, source)`, a `root_dir` test seam, index rows that also carry `source` + `session_drawing_id`, **`saved_at` as an ISO 8601 local-datetime string**, and thumbs capped by `COLLECTION_THUMB_MAX_PX = 200` (200×150 / 150×200). The read surface was appended to the same class; `CollectionIndexEntry` lives beside it in `core/save/`.
**Reason:** reality wins; migrating the shipped format bought nothing.
**Impact:** newest-first ordering uses **array reverse** (append order is chronological and stable for same-second ISO ties) instead of sorting a numeric timestamp; the viewer date header is `saved_at.substr(0, 10)`.

### `Save.write_png` upgraded to atomic
Slice 4 shipped it non-atomic ("caches are regenerable"); exports are player deliverables, so it now writes temp + rename (a failed export never leaves a partial file). Covered by a new atomicity test; thumbs benefit for free.

### Export toast has no "Show in folder" action
The shared `Toast` component has no action-button support; the export toast is plain text and **Share** is the reveal path. Owner noted Share ≈ Export ("fine for now") — logged in the backlog as a future differentiation candidate.

### Screen state is visibility-driven, not an explicit enum
The TDD's §5 LOADING/EMPTY/GRID/VIEWER/CONFIRM_DELETE machine maps to node visibility + the modal dialog; index loads are synchronous (small JSON), so LOADING never renders. Same observable behavior, less machinery.

## Files Created/Modified

**Created:**
- `core/save/collection_index_entry.gd` — binding read contract for index rows
- `ui/collection/collection_screen.tscn/.gd`, `collection_card.tscn/.gd`, `collection_viewer.tscn/.gd`
- `tests/ui/collection/test_collection_scenes.gd` (6 tests)

**Modified:**
- `core/constants/game_constants.gd` — `EXPORT_SCALE`, `THUMB_LOADS_PER_FRAME`
- `core/constants/routes.gd` — `Routes.COLLECTION`
- `core/save/save_service.gd` — atomic `write_png`, `read_png`, `file_exists`, `globalize`
- `core/save/collection_store.gd` — `list_entries`, `read_doc`, `get_thumb`, `delete`, `export_png`, `slugify`, `thumb_size_for`; `_write_thumb` refactored through `_make_thumb`
- `ui/menu/main_menu_screen.tscn/.gd` — Collection button
- `TDD/consistency-guide.md` — §6 tree: `exports/` + real index row shape
- `tests/core/save/test_save_service.gd` (+5), `tests/core/save/test_collection_store.gd` (+10)

## Key Implementation Details

- **Delete ordering:** index row first (the only user-visible record), then best-effort doc/thumb deletion — a crash mid-delete can only orphan invisible files. Idempotent; hostile path-shaped ids rejected (`_id_ok`).
- **Version gate:** an index with `v` newer than the build lists nothing (+ warning) per cg §6.
- **Export fidelity is test-pinned:** every 2×2 block of the export equals its source pixel (nearest-neighbor invariant), both orientations' dimensions asserted, slug sanitizer covered (unicode → "drawing", 40-char cap).

## Testing Summary

- **+21 tests this slice; full suite 350/350 green.** No new gates needed (offline feature); `verify_lobby`/`verify_round` unaffected and passing from the Slice 7 run.
- **User confirmation (2026-07-07):** blocking export check PASS — "works great"; PNG opens externally with correct dimensions and in-game look; Share's reveal-in-Finder also observed working.

## Lessons Learned

- Writing the "reality check vs TDD read contract" step into WHERE_WE_ARE at the previous slice boundary paid off — every §9 mismatch was known before coding started.

## Known Limitations

- Share is Export + reveal (per brief §14); differentiating them (clipboard copy, native share sheet) is post-v1 polish — backlog note.
- No pagination; 300-item collections are fine, thousands untested (kudos-gating bounds growth by design).
- Batchable human checks deferred — see qa-backlog Slice 8 section.
