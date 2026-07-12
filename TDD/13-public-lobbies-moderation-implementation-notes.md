# Implementation Notes: Slice 13 - Public Lobbies & Moderation

**Implemented:** 2026-07-11 (owner confirmation PENDING - blocking checks below)
**TDD Document:** [13-public-lobbies-moderation.md](13-public-lobbies-moderation.md)

## Implementation Summary

Public lobby browser (strict-parsed rows over `Platform.request_lobby_list()`,
mode/has-space filters, 2 s refresh cooldown, empty/failed states), host kick
with a session-scoped platform_id blocklist enforced inside the existing join
handshake ("kicked" deny reason, blocklist beats rejoin memory), the
18+/unmoderated notice (banner + versioned accept-once-per-install dialog),
and the owner-expanded **text-input security audit** (record below) - one
real hole found and fixed (chat control-char line spoofing).

The Public/Private toggle already existed (Slice 9's `is_public` connectivity
tunable, wired to `aq_public` metadata by Slice 12, fluid-rejoin derivation
included) - this slice only gave it honest tooltips and the browser that
reads it. Kick is fully testable over ENet; only the browser's blocking
checks need the two-Steam-account setup (same protocol as Slice 12's).

## Deviations from Original Design

### Deny reasons are strings, not a NetIds enum
**Original Plan:** append `KICKED` to a `JoinDenyReason` enum in net_ids.gd.
**Actual:** no such enum exists - Slice 2/9 shipped string reason keys through
`rpc_do_reject_join` ("full", "in_progress", "bad_identity"...). Added
`"kicked"` to that vocabulary instead; `SessionRules.register_reject_reason`
and `ingame_register_action` gained an `is_blocklisted: bool = false` param
(checked FIRST - a kicked player always hears the honest reason).
**Impact:** none - same wire shape as every existing reject.

### Kick lives on Session, not GameSession
**Original Plan:** `GameSession.kick_player()`.
**Actual:** `Session.kick_player(target_peer_id)` (session_manager.gd). The
roster, the peers, and the join handshake all live on Session, and lobby-phase
kicks have no GameSession at all. `_apply_kick_departure` mirrors
`_on_peer_disconnected`'s two branches (lobby remove / in-game
mark_disconnected + `handle_departure`) but broadcasts the new
`PlayerStatus.KICKED` instead of DROPPED; the later transport disconnect finds
no roster entry and no-ops (no double toast). Mid-game GameSession involvement
rides the existing `handle_departure` path unchanged (judge handling, below-min
pause, kept drawings).

### rpc_do_kicked carries no payload; rpc_sync_player_kicked folded into player_status
**Original Plan:** `rpc_do_kicked(reason: int)` + a dedicated
`rpc_sync_player_kicked` RPC.
**Actual:** `rpc_do_kicked()` (the RPC IS the message; client closes to menu
with reason "kicked" → blocking dialog); the announcement reuses
`rpc_sync_player_status` with appended enum member `PlayerStatus.KICKED`
(append-only rule respected) which emits `EventBus.player_kicked`.
**Impact:** one fewer RPC; toast dedup for free.

### Lobby list is an awaitable coroutine, not EventBus signals
**Original Plan:** `EventBus.lobby_list_updated / lobby_list_failed`.
**Actual:** `Platform.request_lobby_list() -> {"ok": bool, "lobbies":
[{"id", "meta"}]}` - the Slice 12 awaitable-backend contract style; only the
browser consumes it, so signals added nothing. (TDD anticipated this
reconciliation.)

### Privacy = aq_public flag, not FRIENDS_ONLY lobby type
**Original Plan:** private lobbies use Steam type `FRIENDS_ONLY` + `listed`
metadata key; visibility fixed at creation.
**Actual:** ALL lobbies stay Steam-PUBLIC (Slice 12 decision - code search
requires it); the browser's Steam-side filters select `aq_public="1"` +
`aq_proto` + `aq_state="lobby"`, and `LobbyListing` re-checks all three
strictly. Visibility is the existing lobby settings toggle (host-only,
changeable in the lobby): the shipped metadata is dynamic anyway, the notice
gate is browser-side (flipping public mid-lobby bypasses nothing), and
`set_value(&"is_public")` already re-derives fluid_rejoin.

### In-game lobbies are hidden from the browser
`aq_state="ingame"` lobbies are filtered out Steam-side AND dropped by the
strict parse (owner-approved lean). Public mid-game late-join remains possible
by code/invite; the browser just doesn't advertise it in v1.

### Join rejects land on the menu, not back in the browser
A post-connect handshake reject (full/kicked raced the browser row) runs the
existing `rpc_do_reject_join` → close-to-menu flow, same as every join path.
Pre-connect failures (not_found/full/version at the Steam layer) DO return to
the Listed state with a toast. TDD's "always return to Listed" would need a
return-route concept in `_close_to_menu` for marginal UX - skipped.

### In-game kick surface is the Esc menu
No in-game roster/scoreboard component exists to hang a ⋮ menu on. The host's
Esc menu (GameMenu) gained a "Players" section - connected, non-host rows with
a two-click confirm Kick button (Leave-button precedent), whose armed label
warns "(pauses game)" when the kick drops the roster below minimum.

## Files Created/Modified

- `core/constants/game_constants.gd` - Slice 13 banner: cooldown, kick grace, `PUBLIC_NOTICE_VERSION`/`PUBLIC_NOTICE_TEXT`
- `core/constants/net_ids.gd` - `PlayerStatus.KICKED` (append-only)
- `core/constants/routes.gd` - `PUBLIC_BROWSER`
- `core/events/event_bus.gd` - `player_kicked`
- `core/util/text_filter.gd` - `strip_control_chars()` (audit fix, shared home)
- `core/platform/platform_backend.gd` / `platform_service.gd` - `request_lobby_list()` contract + forward
- `core/platform/steam_backend.gd` - `request_lobby_list()` (3 string filters + `_read_lobby_meta`), `supports_lobby_browser()` override
- `core/platform/lobby_metadata.gd` - `ALL_KEYS`
- `game/session/roster.gd` - `_kick_blocklist` + `add_to_blocklist`/`is_blocklisted` (never serialized)
- `game/session/session_rules.gd` - blocklist param on both gates; `sanitize_name` uses the shared strip
- `game/session/session_manager.gd` - `kick_player`, `_apply_kick_departure`, `rpc_do_kicked`, KICKED status branch, blocklist checks at both register paths, chat control-char strip
- `game/prompts/custom_pool_collector.gd` - any-control-char rejection (was `\n` only)
- `ui/lobby/lobby_listing.gd` - NEW: strict row parse over `LobbyMetadata.parse` (+ local re-censor)
- `ui/lobby/public_notice_gate.gd` - NEW: versioned acceptance over Save (static `path` test seam)
- `ui/lobby/public_notice_dialog.gd/.tscn` - NEW
- `ui/lobby/public_browser_screen.gd/.tscn` - NEW: state machine, filters, cooldown, notice gate, join handoff
- `ui/lobby/lobby_screen.gd/.tscn` - kick wiring + KickConfirm + kicked toast; PublicCheck tooltip made honest
- `ui/shared/player_list.gd` - `allow_kick` + `kick_requested` signal
- `ui/round/game_menu.gd/.tscn` - host Players/kick section
- `ui/round/round_root.gd` - "was kicked" toast
- `ui/menu/main_menu_screen.gd/.tscn` - Public Games button (platform-gated), kicked blocking dialog
- Tests: `test_public_browser.gd` (NEW), extensions to `test_roster.gd`, `test_session_validation.gd`, `test_custom_pool_collector.gd`

## Text-Input Security Audit (owner-expanded scope, 2026-07-11)

Rule verified per entry point: (a) host-side authority, (b) rendering never
interprets user text as markup, (c) user text never reaches file paths,
format strings, or executable sinks, (d) length caps host-side.

| Entry point | Host authority | Render | Caps | Verdict |
|---|---|---|---|---|
| Chat | `chat_text_ok` + rate limit + **strip_control_chars (NEW)** + `censor` before broadcast (`_handle_chat`) | RichTextLabel via `add_text`/`push_bold` only - BBCode never parsed (pinned: `test_chat_panel_renders_messages_from_event_bus`) | MAX_CHAT_LEN both sides | **HOLE FIXED**: embedded `\n` rendered a spoofed "Name: text" line; now stripped + pinned |
| In-image TEXT ops | `GameSession._censor_text_ops` censors + re-truncates every op before store/broadcast | PixelFont glyph map - no interpretation of any kind | TEXT_MAX_CHARS | Clean |
| Custom pool words | `is_clean` reject + length + **any control char rejected (NEW - was `\n` only)** | Labels only | WORD_MAX_CHARS | Hardened |
| Lobby name (`aq_name`) | censored at metadata build (host); browser **re-censors locally** + strict parse | `Label.text` only | Steam metadata cap | Clean (pinned: `test_listing_recensors_name_with_local_blocklist`) |
| Display names (incl. Steam personas) | `sanitize_name`: control-strip + trim + cap + censor + dedupe at registration | Labels everywhere | MAX_NAME_LEN | Clean |
| Room code input | `RoomCode.normalize`/`is_valid` (fixed alphabet) before any Steam filter use | Label | 5 chars | Clean |
| Avatar docs | size/op/orientation validation host-side; receivers re-validate before rasterize | rasterizer | AVATAR_DOC_MAX_BYTES | Clean (Slice 11) |

Sink sweep (whole codebase): **zero** `Expression`/`OS.execute`/eval;
`OS.shell_*` only opens Save-owned constant dirs; exactly ONE RichTextLabel
exists (chat history, push-API only), zero `append_text`/`parse_bbcode`/
`bbcode_enabled`; file names from user text only via `CollectionStore.slugify`
([a-z0-9-] whitelist) + `Save._path_ok` (absolute/`..` traversal rejected);
all JSON via `Save` (stringify escapes); captions are GONE (Slice 16).

## Testing Summary

- Suite: **532 → 556 cases, 0 failures, 0 orphans** (+24: roster blocklist ×3,
  rules/kick/chat-spoof ×7, pool control chars (extended case), listing parse ×5,
  notice gate/dialog ×3, browser screen ×5, menu gating ×1)
- Gates via guarded scratchpad wrapper: `verify_lobby.sh` PASS,
  `verify_round.sh` PASS, `verify_resilience.sh` PASS (expected resume-race
  log noise only)
- Harness note: Session-level kick tests need
  `multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()` in
  before_test - the bare test tree has NO peer, so `is_server()` errors AND
  returns false (restore the saved peer in after_test)
- **User confirmation: PENDING** - see WHERE_WE_ARE (kick end-to-end works
  over ENet locally; browser listing/private-unlisted need two Steam accounts,
  batched with the Slice 12 protocol)

## Known Limitations

- Browser rows don't live-update (refresh is manual + 2 s cooldown) - fine at
  v1 scale.
- `aq_name` is written once at creation (Slice 12 limitation) - a host who
  renames mid-lobby keeps the stale browser name; cosmetic.
- Kick targets connected players only (no preemptive block of a disconnected
  rejoin-memory entry) - kick them when they return.
- Notice acceptance is per-install (profile.json), not per-Steam-account -
  §12's "accept-once-per-install" wording, deliberate.
