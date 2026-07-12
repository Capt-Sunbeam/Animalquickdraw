# Implementation Notes: Slice 12 - Steam Platform Integration

**Implemented:** 2026-07-11 (owner confirmation PENDING - two-account blocking protocol not yet run)
**TDD Document:** [12-steam-integration.md](12-steam-integration.md)

## Implementation Summary

Filled the `SteamBackend` seam with GodotSteam GDExtension 4.20 (Steamworks
SDK 1.64, pinned in the decision log): Steam identity (persona name /
SteamID64) flows into the existing roster, `SteamMultiplayerPeer` carries the
existing RPC set over Valve's SDR relay (no IPs visible), Steam lobbies carry
the generated 5-char room codes + the Slice 13 metadata schema, and invites
work via the overlay, the running-game `join_requested` callback, and the
cold-launch `+connect_lobby` command line. ENet remains the default for
editor/dev/tests (exported builds default to steam); no gameplay RPC changed.

Single-instance smoke against the real Steam client PASSED (init, lobby
create, metadata write/read-back byte-exact, relay host peer, teardown).
The two-account blocking checkpoints (§7) are the remaining gate.

## Deviations from Original Design

### Stats init: requestCurrentStats no longer exists
**Original Plan:** `requestCurrentStats()` at init + `is_stats_ready` flag set on the `current_stats_received` callback.
**Actual Implementation:** Steamworks SDK 1.61+ removed `RequestCurrentStats` (verified absent from the 4.20 GDExtension via ClassDB probe) - the current user's stats are live immediately after init. `is_stats_ready()` simply returns init success.
**Reason for Deviation:** API removed upstream.
**Impact:** Slice 14's gate is trivially true after successful init; its TDD should not wait on a callback that will never fire.

### Awaitable backend contract was already in the skeleton
**Original Plan:** This slice converts `create_*_peer` to awaitable coroutines and adds `await` to `Net.host/join` ("the slice's one cross-cutting refactor").
**Actual Implementation:** The skeleton already shipped the coroutine contract (`platform_backend.gd` documented it; `Net` already awaited). This slice only ADDED contract surface: `initialize()`, `run_frame()`, `get_room_code()`, `open_invite_overlay()`, `update_lobby_metadata()`, `leave_cleanup()`, `create_client_peer_for_lobby()`, `is_stats_ready()`, `get_last_failure_reason()`.
**Impact:** No refactor risk materialized; the ENet suite never wobbled.

### Invite routing centralized in Session (TDD said "Session unchanged")
**Original Plan:** §8 declared Session unchanged except metadata hooks; §6 had the menu handling `invite_join_requested`.
**Actual Implementation:** `Session` owns the whole invite flow (`_on_invite_join_requested`, confirm `ConfirmationDialog` child, `join_session_by_lobby()`, `check_launch_lobby()` once-guard; `Net.join_lobby()` added). The menu only renders the cold-launch "Joining friend's game..." state.
**Reason for Deviation:** an invite accept can arrive on ANY screen, and the confirm dialog must survive scene swaps - only an autoload can own that. A per-screen handler would miss accepts mid-game.
**Impact:** Slice 13's browser join should reuse `Session.join_session_by_lobby()` directly.

### Code-collision tiebreak: Steam result order, not "newest"
**Original Plan:** among filter survivors pick highest member count, then newest.
**Actual Implementation:** `SteamBackend.choose_lobby()` picks highest `getNumLobbyMembers`, ties broken by Steam's own result ordering (first hit wins).
**Reason for Deviation:** lobby creation time is not on the wire; Steam already orders results by relevance.
**Impact:** None at real scale (collisions need the same 5-char code + same proto under our own App ID).

### platform_ready emitted from Platform, not the backend
**Original Plan:** `SteamBackend.initialize()` emits `EventBus.platform_ready`.
**Actual Implementation:** `Platform._ready()` emits once after `backend.initialize()` (single emission site, both backends); screens that load later read `Platform.platform_ok` instead of racing the boot-time signal.
**Impact:** None functional; cleaner contract.

### Unconnected no-op callbacks
`lobby_chat_update`, `lobby_data_update`, `persona_state_change` are NOT connected (TDD table listed them as housekeeping/no-op). Zombie-lobby prevention is covered structurally: every teardown path funnels through `Net.leave()` → `backend.leave_cleanup()` → `leaveLobby` + `clearRichPresence` (including `server_disconnected`).

## Files Created/Modified

- `addons/godotsteam/` - vendored GDExtension 4.20, unmodified upstream; editor plugin left disabled (it is only an update-checker)
- `steam_appid.txt` - `480` at project root; **exclude from shipped depot (Slice 15)**
- `core/constants/net_ids.gd` - `PROTOCOL_VERSION`
- `core/constants/game_constants.gd` - room-code + search-timeout constants
- `core/events/event_bus.gd` - `platform_ready`, `invite_join_requested`, `lobby_resolved`
- `core/util/room_code.gd` - NEW: generate/normalize/is_valid
- `core/platform/lobby_metadata.gd` - NEW: pure schema builder/parser (Slice 13 reuses `parse()`)
- `core/platform/launch_args.gd` - NEW: `+connect_lobby` parsing
- `core/platform/platform_backend.gd` - contract additions (above)
- `core/platform/enet_backend.gd` - stores/reports the dev code; `leave_cleanup` clears it
- `core/platform/steam_backend.gd` - the slice's core (stub → full implementation)
- `core/platform/platform_service.gd` - backend default flip (editor→enet, export→steam), `is_steam`/`platform_ok`, callback pump, forwards
- `core/network/network_manager.gd` - `join_lobby()`; `leave()` runs backend cleanup
- `game/session/session_manager.gd` - room code from backend; `_push_lobby_metadata` hooks (host/settings/roster/state); invite flow + `join_session_by_lobby`
- `ui/menu/main_menu_screen.gd` - offline mode, cold-launch state, Steam failure-reason toasts
- `ui/lobby/lobby_screen.tscn/.gd` - Invite button (visible only with invite support)
- Tests: `test_room_code.gd`, `test_lobby_metadata.gd`, `test_launch_args.gd`, `test_steam_backend_logic.gd`, `test_net_backend_await.gd` (all NEW), `test_lobby_scenes.gd` (+3 UI cases)

## Key Implementation Details

- **Exact GodotSteam 4.20 API used:** `steamInitEx(app_id, embed_callbacks=false)` → `{status:0=OK}`; `createLobby(LOBBY_TYPE_PUBLIC, max)` → `lobby_created(result, lobby_id)`; `joinLobby` → `lobby_joined(lobby, perms, locked, response)` with `CHAT_ROOM_ENTER_RESPONSE_SUCCESS=1`; `addRequestLobbyListStringFilter(key, value, LOBBY_COMPARISON_EQUAL)` + `requestLobbyList` → `lobby_match_list(lobbies)`; `join_requested(lobby_id, steam_id)`; `SteamMultiplayerPeer.create_host(virtual_port)` / `create_client(steam_id, virtual_port)` (virtual port 0).
- **Async waits:** flag-variable + `_await_flag(is_done)` polling `process_frame` with the shared `LOBBY_SEARCH_TIMEOUT_SEC` deadline - no signal-vararg tricks; `Platform._process` keeps `Steam.run_callbacks()` pumping during every await.
- **Proto gate runs twice by design:** search filters enforce `aq_proto` for code joins; `_join_lobby_and_connect` re-checks it explicitly because the invite path bypasses search ("update Animal Quickdraw" dialog instead of a handshake crash).
- **Failure surface:** `get_last_failure_reason()` ("not_found" / "full" / "version_mismatch" / "timeout" / "connection_failed") - menu maps to specific toasts; invite-path failures reload the menu with the close-reason toast.
- **All lobbies are Steam-PUBLIC** so code search works; privacy = `aq_public` flag + obscure code (TDD §2 note; user-facing wording lands with Slice 13).
- Export presets need no manual binary lists - the `.gdextension` manifest drives per-platform inclusion at export time (re-verify at Slice 15 alongside the App ID swap).

## Testing Summary

- Unit/scene tests: **532 cases, 0 failures, 0 orphans** (505 → 532; +27)
- Gates via guarded wrapper: `verify_lobby.sh` PASS, `verify_round.sh` PASS, `verify_resilience.sh` PASS (ENet default untouched - the owner's local-testing requirement)
- Steam smoke (single instance, real client, headless): PASS - init/identity, lobby create, full metadata schema write + byte-exact read-back, SDR host peer, clean teardown
- **User confirmation: PENDING** - two-account blocking protocol (§7): join-by-code over relay + full round, invite accept while running, cold-launch join (simulated via manual `+connect_lobby` under Spacewar - see qa-backlog), Steam-quit offline boot

## Lessons Learned

- Probing the vendored extension via `ClassDB` (`class_has_method` / `class_get_method_list`) before writing backend code caught the removed stats API and pinned exact signatures - cheaper than trusting docs for a version-drifting binding.
- The platform seam held: zero gameplay-code changes, and the whole existing suite + gates stayed green throughout.

## Known Limitations

- Cold-launch "Join Game" under App ID 480 launches Valve's Spacewar, not our exe - our parsing/join path is testable via manual `+connect_lobby <id>`, but "Steam launches the right binary" is only verifiable under the real App ID (Slice 15 re-verification, owner-earmarked in qa-backlog).
- `aq_name` is written once at lobby creation (host rename mid-lobby not re-synced - browser cosmetic, revisit in Slice 13 if it matters).
- Invite-while-in-session leaves the current game before knowing the new join succeeds (accepted: rejoin memory covers the way back).
