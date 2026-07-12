class_name SteamBackend
extends PlatformBackend
## Slice 12: GodotSteam identity + SDR relay transport. Steam lobbies carry
## the 5-char room codes (metadata aq_code) and invites; SteamMultiplayerPeer
## relays all existing RPCs through Valve's SDR - no IPs visible to peers
## (design brief §13). ENet remains the dev/test transport; this backend is
## selected via --platform=steam or by default in exported builds.
##
## API surface verified against the vendored GodotSteam GDExtension 4.20
## (Steamworks SDK 1.64) - see decision log 2026-07-11. Notable vs the TDD
## draft: requestCurrentStats/current_stats_received no longer exist (SDK
## 1.61+ removed them; the current user's stats are live right after init),
## so is_stats_ready() is simply init success.

const APP_ID: int = 480  # Spacewar (dev). Real App ID swap: Slice 15 (TDD 12 §9).

var _lobby_id: int = 0
var _room_code: String = ""
var _init_ok: bool = false
var _last_failure_reason: String = ""

# Async callback results; [] / null = pending. Reset before each request,
# filled by the _on_* handlers, awaited via _await_flag (Platform._process
# keeps run_frame pumping while we wait).
var _created_result: Array = []    # [result, lobby_id]
var _joined_result: Array = []     # [lobby_id, permissions, locked, response]
var _match_lobbies: Variant = null # Array[int] once arrived


func initialize() -> bool:
	var res: Dictionary = Steam.steamInitEx(APP_ID, false)
	_init_ok = int(res.get("status", 1)) == 0
	if _init_ok:
		Steam.lobby_created.connect(_on_lobby_created)
		Steam.lobby_joined.connect(_on_lobby_joined)
		Steam.lobby_match_list.connect(_on_lobby_match_list)
		Steam.join_requested.connect(_on_join_requested)
	else:
		push_warning("SteamBackend: steamInitEx failed (%s)" % str(res.get("verbal", "")))
	return _init_ok


func run_frame() -> void:
	if _init_ok:
		Steam.run_callbacks()


func get_display_name() -> String:
	# Roster still TextFilter-censors on the host like any typed text (§13).
	return Steam.getPersonaName()


func get_platform_id() -> String:
	# SteamID64 - stable per account; Slice 9's rejoin memory key.
	return str(Steam.getSteamID())


## Coroutine. Steam ignores the code hint - the real code is generated here
## after the lobby exists. All lobbies are Steam-PUBLIC so code searches can
## find them; our privacy bar is aq_public + the obscure code (TDD 12 §2).
func create_host_peer(_room_code_hint: String) -> MultiplayerPeer:
	if not _init_ok:
		return null
	_last_failure_reason = ""
	_created_result = []
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, GameConstants.MAX_PLAYERS)
	if not await _await_flag(func() -> bool: return not _created_result.is_empty()):
		_last_failure_reason = "timeout"
		return null
	if int(_created_result[0]) != Steam.RESULT_OK:
		push_warning("SteamBackend: createLobby failed (%d)" % int(_created_result[0]))
		return null
	_lobby_id = int(_created_result[1])
	_room_code = RoomCode.generate()
	Steam.setRichPresence("connect", "+connect_lobby %d" % _lobby_id)
	var peer := SteamMultiplayerPeer.new()
	if peer.create_host(0) != OK:
		leave_cleanup()
		return null
	return peer


## Coroutine. Join by 5-char code: lobby search filtered on aq_code +
## aq_proto -> joinLobby -> relay-connect to the lobby owner.
func create_client_peer(room_code: String) -> MultiplayerPeer:
	if not _init_ok:
		return null
	_last_failure_reason = ""
	var code: String = RoomCode.normalize(room_code)
	var lobby_id: int = await _resolve_code(code)
	EventBus.lobby_resolved.emit(code, lobby_id)
	if lobby_id == 0:
		_last_failure_reason = "not_found"
		return null
	return await _join_lobby_and_connect(lobby_id)


## Coroutine. Invite / cold-launch path: known lobby id, no code search.
func create_client_peer_for_lobby(lobby_id: int) -> MultiplayerPeer:
	if not _init_ok or lobby_id == 0:
		return null
	_last_failure_reason = ""
	return await _join_lobby_and_connect(lobby_id)


func get_room_code() -> String:
	return _room_code


func open_invite_overlay() -> void:
	if _lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(_lobby_id)


## Host-only (lobby owner); Steam silently rejects writes from non-owners,
## and ENet peers never call this (Platform no-ops there).
func update_lobby_metadata(data: Dictionary) -> void:
	if _lobby_id == 0:
		return
	for key: String in data:
		Steam.setLobbyData(_lobby_id, key, str(data[key]))


## Every teardown path lands here via Net.leave(). Leaving promptly matters:
## Steam migrates lobby ownership when the owner quits, and an abandoned
## lobby would keep matching future code searches (TDD 12 §10).
func leave_cleanup() -> void:
	if _lobby_id != 0:
		Steam.leaveLobby(_lobby_id)
		Steam.clearRichPresence()
	_lobby_id = 0
	_room_code = ""


func is_stats_ready() -> bool:
	# SDK 1.64: current-user stats are live once init succeeds (see header).
	return _init_ok


# --- Slice 14: achievement mirror. All three verified against the vendored
# GodotSteam 4.20 binary via ClassDB probe (session 14): setAchievement /
# getAchievement / storeStats are synchronous; requestCurrentStats is GONE
# (SDK 1.64), so callers gate on is_stats_ready() = init success. ---


func steam_achievement_is_set(achievement_id: String) -> bool:
	if not _init_ok:
		return false
	# getAchievement returns {"ret": bool, "achieved": bool}.
	var result: Dictionary = Steam.getAchievement(achievement_id)
	return bool(result.get("ret", false)) and bool(result.get("achieved", false))


func steam_set_achievement(achievement_id: String) -> void:
	if _init_ok:
		Steam.setAchievement(achievement_id)


func steam_store_stats() -> void:
	if _init_ok:
		Steam.storeStats()


func get_last_failure_reason() -> String:
	return _last_failure_reason


func supports_invites() -> bool:
	return _init_ok


func supports_lobby_browser() -> bool:
	return _init_ok


## Coroutine (Slice 13). Steam-side string filters narrow the list to our
## protocol's PUBLIC, still-in-lobby games (filters apply to the next
## requestLobbyList only); rows come back as raw metadata for LobbyListing's
## strict parse - browser data is advisory, the join handshake re-validates
## everything (TDD 13 §10). Shares _match_lobbies with _resolve_code: fine,
## the UI serializes list requests and code joins (different screens).
func request_lobby_list() -> Dictionary:
	if not _init_ok:
		return {"ok": false, "lobbies": []}
	_match_lobbies = null
	Steam.addRequestLobbyListStringFilter(
			LobbyMetadata.KEY_PROTO, NetIds.PROTOCOL_VERSION, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListStringFilter(
			LobbyMetadata.KEY_PUBLIC, "1", Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListStringFilter(
			LobbyMetadata.KEY_STATE, LobbyMetadata.STATE_LOBBY, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()
	if not await _await_flag(func() -> bool: return _match_lobbies != null):
		return {"ok": false, "lobbies": []}
	var lobbies: Array[Dictionary] = []
	for lobby: Variant in _match_lobbies:
		var lobby_id: int = int(lobby)
		lobbies.append({"id": lobby_id, "meta": _read_lobby_meta(lobby_id)})
	return {"ok": true, "lobbies": lobbies}


## Full schema read for one listed lobby (list results carry their metadata;
## getLobbyData needs no extra round trip).
func _read_lobby_meta(lobby_id: int) -> Dictionary:
	var meta: Dictionary = {}
	for key: String in LobbyMetadata.ALL_KEYS:
		meta[key] = Steam.getLobbyData(lobby_id, key)
	return meta


## Maps a lobby_joined chat-room response to our short reason keys.
## Pure - unit-tested; values align with Slice 2's session_closed keys
## where they overlap ("full").
static func friendly_join_failure(response: int) -> String:
	match response:
		Steam.CHAT_ROOM_ENTER_RESPONSE_FULL:
			return "full"
		Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST:
			return "not_found"
		_:
			return "connection_failed"


## Picks the joinable lobby among code-search survivors: highest player
## count, ties broken by Steam's own result ordering (no creation time on
## the wire - deviation from the TDD's "then newest", see impl notes).
## candidates: [{"id": int, "players": int}] in Steam result order.
static func choose_lobby(candidates: Array) -> int:
	var best_id: int = 0
	var best_players: int = -1
	for entry: Dictionary in candidates:
		var players: int = int(entry.get("players", 0))
		if players > best_players:
			best_players = players
			best_id = int(entry.get("id", 0))
	return best_id


func _resolve_code(code: String) -> int:
	if not RoomCode.is_valid(code):
		return 0
	_match_lobbies = null
	Steam.addRequestLobbyListStringFilter(
			LobbyMetadata.KEY_CODE, code, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListStringFilter(
			LobbyMetadata.KEY_PROTO, NetIds.PROTOCOL_VERSION, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()
	if not await _await_flag(func() -> bool: return _match_lobbies != null):
		return 0
	var candidates: Array = []
	for lobby: Variant in _match_lobbies:
		var lobby_id: int = int(lobby)
		candidates.append({
			"id": lobby_id,
			"players": Steam.getNumLobbyMembers(lobby_id),
		})
	return choose_lobby(candidates)


func _join_lobby_and_connect(lobby_id: int) -> MultiplayerPeer:
	_joined_result = []
	Steam.joinLobby(lobby_id)
	if not await _await_flag(func() -> bool: return not _joined_result.is_empty()):
		_last_failure_reason = "timeout"
		return null
	var response: int = int(_joined_result[3])
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		_last_failure_reason = friendly_join_failure(response)
		return null
	# The invite path bypasses the search filters, so the proto gate runs
	# here explicitly - a mismatch must read as "update your game", never
	# a mid-handshake crash (TDD 12 §10).
	var meta: Dictionary = {
		LobbyMetadata.KEY_PROTO: Steam.getLobbyData(lobby_id, LobbyMetadata.KEY_PROTO),
	}
	if not LobbyMetadata.proto_matches(meta):
		Steam.leaveLobby(lobby_id)
		_last_failure_reason = "version_mismatch"
		return null
	_lobby_id = lobby_id
	_room_code = Steam.getLobbyData(lobby_id, LobbyMetadata.KEY_CODE)
	var owner: int = Steam.getLobbyOwner(lobby_id)
	var peer := SteamMultiplayerPeer.new()
	if peer.create_client(owner, 0) != OK:
		leave_cleanup()
		_last_failure_reason = "connection_failed"
		return null
	return peer


## Awaits is_done() with the shared lobby-op timeout, pumping frames.
## Returns false on timeout. Steam callbacks keep arriving because
## Platform._process calls run_frame() every frame regardless.
func _await_flag(is_done: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() \
			+ int(GameConstants.LOBBY_SEARCH_TIMEOUT_SEC * 1000.0)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	while not is_done.call() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	return is_done.call()


func _on_lobby_created(result: int, lobby_id: int) -> void:
	_created_result = [result, lobby_id]


func _on_lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int) -> void:
	_joined_result = [lobby_id, permissions, locked, response]


func _on_lobby_match_list(lobbies: Array) -> void:
	_match_lobbies = lobbies


func _on_join_requested(lobby_id: int, _friend_steam_id: int) -> void:
	# Overlay "Join Game" / accepted invite while the app is running. The
	# menu/Session decide (confirm-leave if in a session) and run the join.
	EventBus.invite_join_requested.emit(lobby_id)
