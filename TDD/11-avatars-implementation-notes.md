# Implementation Notes: Slice 11 - Avatars

**Completed:** 2026-07-08 (session 8, second slice; machine-verified — owner checks batched to the end-of-session list per owner instruction)
**TDD Document:** [11-avatars.md](11-avatars.md)

## Implementation Summary

Players draw their own face on a circular 512×512 canvas that is the ordinary `DrawingCanvas` with `mask_mode = CIRCLE` — the Slice 1 mask hook, finally activated. The avatar is a normal DrawingDoc with the new `"avatar"` orientation, stored at `user://avatar.json` (`AvatarStore`, atomic, corrupt-tolerant, with a test path seam), and synced as roster metadata: the client sends `rpc_request_set_avatar` once its registration is confirmed (lobby welcome, in-game welcome, or host self-registration), the host validates (`SessionRules.avatar_doc_error` — size/shape/orientation/op caps, silent drop) and rebroadcasts `rpc_sync_avatar`; the roster snapshot carries an optional `"avatar"` key per player, so late joiners and every roster broadcast deliver avatars with zero extra machinery. Display goes through the one fallback chain (`AvatarResolver`: drawn → name circle → deterministic house doodle picked by platform-id hash) rendered by the one shared component (`AvatarChip`, 3 render kinds, static + live-bound modes, LRU-cached circle-masked textures) — retrofitted into the lobby player list (48 px), the Slice 17 ready panel/chat strip (26 px, replacing the initials placeholder chips), the wrap-up title cards (96 px) and standings rows (48 px), and the main menu's new Avatar button. Six generated house avatars ship as `res://data/house_avatars/`. Reveal/judging grids remain chip-free (anonymity, brief §4).

## Deviations from Original Design

### Avatar sync keyed by platform_id, not peer_id
**Original Plan:** §3 `rpc_sync_avatar(peer_id, avatar_doc)`, `avatar_updated(peer_id)`, chip `set_peer(peer_id)`.
**Actual Implementation:** `rpc_sync_avatar(platform_id, doc)`, `EventBus.avatar_updated(platform_id)`, `AvatarChip.bind_platform_id(pid, fallback_name)`. Peer ids reset to 0 on disconnect and travel only in the roster broadcast; platform_id is the stable identity every Slice 9 signal already uses.
**Impact:** None on the wire beyond the key type; chips survive rejoins for free.

### The RPCs live on Session (the autoload), send-trigger runs on THREE paths
The node owning `rpc_sync_roster` is the Session autoload, so the two avatar RPCs attach there. The TDD's single "after join accepted" trigger is really three: host self-registration in `host_session()` (the host is also a player and gets no welcome), the lobby `rpc_do_welcome`, and the Slice 9 `rpc_do_welcome_ingame` (late joiners/rejoiners sync their face too).

### `AvatarStore` centralizes the file (with a test seam)
**Original Plan:** §6 put load/save inline in the editor.
**Actual Implementation:** Three consumers need the file (editor, Session send-trigger, menu chip), and tests must never touch a real player's avatar — `AvatarStore.path` is the seam (the `CollectionStore.root_dir` pattern).

### Chip name-circle fallback carries a fallback name in live mode
`bind_platform_id(pid, fallback_name)` — surfaces that own their name data (the Session-free ready strip) stay honest when the roster lookup misses (tests, teardown races), instead of degrading to a house doodle for a player whose name is right there.

### Chip internal label renamed `ChipNameLabel`
The chip's internal `NameLabel` node collided with host screens' own `NameLabel` under recursive `find_child` (caught by the wrap-up title-card test — the assertion found the chip's label). Chips must never shadow their host's node names.

### Text/eraser tools remain available in the avatar editor
The TDD sketch predates Slice 16; "the exact same tools" now includes text and eraser. Both are mask-correct by construction (the blitter honors the mask; the eraser is a background-color stroke). Zero tool code either way.

### House avatars are generated, not hand-drawn in the editor
Six simple faces (smiley/sleepy/surprised/cat/grumpy/winker on distinct palette fills) generated as canonical stroke/fill docs by a scratchpad script. The content-parse test pins all six load as valid avatar docs. Replace with hand-drawn ones any time — the format is the ordinary doc format.

## Files Created/Modified

**Created:**
- `game/drawing/circle_mask.gd` — canonical mask equation: image, contains, clamp-to-rim, display alpha
- `game/avatars/avatar_store.gd` — `user://avatar.json` load/save/clear (path seam)
- `game/avatars/avatar_resolver.gd` — fallback chain + deterministic house pick + house-doc loader
- `ui/shared/avatar_texture_cache.gd` — SHA-keyed 16-entry LRU of circle-masked textures
- `ui/shared/avatar_chip.gd/.tscn` — the shared identity component (defers rendering until tree entry)
- `ui/avatars/avatar_editor_screen.gd/.tscn` — masked canvas, Save/Clear + confirms, load-existing, unsaved-changes prompt, complexity toast
- `data/house_avatars/house_00.json` … `house_05.json`
- Tests: `tests/game/avatars/test_avatar_resolver.gd` (6), `test_avatar_store.gd` (6), `tests/game/drawing/test_circle_mask.gd` (7), `tests/game/session/test_avatar_validation.gd` (5), `tests/ui/avatars/test_avatar_scenes.gd` (7)

**Modified:**
- `core/constants/game_constants.gd` (CANVAS_AVATAR + caps + house set), `routes.gd` (AVATAR_EDITOR), `event_bus.gd` (avatar_updated, local_avatar_changed)
- `game/drawing/drawing_doc.gd` — `"avatar"` orientation + 512×512 mapping
- `ui/canvas/drawing_canvas.gd` — CIRCLE mode: mask population, rim clamping, outside-fill ignore, rotate guard, display alpha
- `game/session/roster.gd` — `PlayerState.avatar_doc` (+optional `"avatar"` snapshot key)
- `game/session/session_rules.gd` — `avatar_doc_error`
- `game/session/session_manager.gd` — 2 RPCs + `_send_local_avatar` on three trigger paths
- `ui/shared/player_list.gd` (48 px chips), `ui/shared/ready_status_strip.gd` (initials chips → AvatarChips)
- `ui/wrapup/title_card.gd/.tscn` (96 px chip slot), `ui/wrapup/standings_panel.gd` (48 px row chips)
- `ui/menu/main_menu_screen.gd/.tscn` — Avatar button + live local chip
- Tests extended: `test_drawing_doc.gd` (+2), `test_roster.gd` (+1)

## Key Implementation Details

- **One equation everywhere:** stamping/fill/text write through the `DocRasterizer` mask parameter (shipped in Slice 1, now populated); input clamps via `CircleMask.clamp_to_circle`; display corners go transparent via `apply_display_alpha` AFTER authoritative rasterization — golden hashes are taken on the unmodified raster, so avatar docs stay deterministic like every other doc.
- **Roster broadcasts carry avatar docs** (each ≤ 32 KB cap, typically ≤ 10 KB). A kudos-heavy 8-player game re-sends them on each roster broadcast — accepted for v1 (reliable channel, tiny in absolute terms); noted for revisit if Steam relay profiling ever flags it.
- **Defense in depth:** the host validates before storing; every renderer re-runs `DrawingDoc.from_dict` via `AvatarResolver` before rasterizing — an invalid doc from anywhere is identical to no doc.
- **Chips defer rendering until `_ready`** (`_pending_render`) so list-row builders can configure detached rows — the crash class the first suite run caught.
- Downgrades (Drawn → NameCircle) never occur mid-session: there is no clear-avatar request in v1; clearing applies at next join (§10).

## Testing Summary

- **Unit/scene:** +34 this slice; full suite **487/487 green, 0 orphans**.
- **Automated gates (guarded wrapper):** `verify_lobby.sh` PASS, `verify_round.sh` PASS, `verify_resilience.sh` PASS (lobby/round surfaces now instantiate real chips in all three).
- **User confirmation:** BATCHED per owner instruction — including the TDD's blocking two-instance avatar sync check. See the end-of-session test list / qa-backlog Slice 11 section.

## Lessons Learned

- Threading an optional parameter (the rasterizer's `mask`) through every write path at Slice 1 time made this slice's core feature a two-line activation — the hook pattern earned its keep.
- Shared components must namespace their internal node names (`ChipNameLabel`) — recursive `find_child` in host screens and tests sees right through component boundaries.

## Post-Slice Fixes

- **Dev instances shared one avatar (2026-07-10, owner's batched check):** all `dev_run.sh` instances share `user://`, so after saving an avatar on P1, P2/P3 loaded the same `avatar.json` and honestly broadcast it as their own — every player showed P1's face. Not a sync bug (three distinct platform_id-keyed broadcasts, all rendered), but it made the blocking two-instance check unrunnable locally. Cure mirrors `EnetBackend.disambiguate_platform_id`: `AvatarStore.default_path_for_args` namespaces the file by the `--name=` user arg (`avatar_P2.json`) on the enet platform only; the name tag is whitelist-sanitized because `Save._path_ok` rejects `..` wholesale. Steam builds launch without user args → plain `avatar.json`, zero ship impact. +4 tests (491 total).

## Known Limitations

- Mid-session avatar edits don't propagate (editor is menu-only; applies at next join — §10, forward-compatible).
- The name-circle font sizing is a heuristic (`chip_size / 4.5`), untuned below 26 px.
- House avatars are programmer art (deliberately replaceable).
- The avatar editor's canvas letterboxes like the round canvas; the circle backing behind the transparent corners is the UI background, not a dedicated theme circle (cosmetic, backlogged).
