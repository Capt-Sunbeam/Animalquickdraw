extends Node
## Autoload "Session" - lobby-phase session lifecycle (Slice 2 TDD §6/§8).
## Owns the authoritative Roster + GameSettings on the host (peer 1); clients
## hold read-only mirrors updated exclusively by rpc_sync_* handlers here.
## The host's own player registers/chats through the same internal methods
## the RPC handlers call (no self-RPC), so host text is filtered identically.
##
## File is session_manager.gd, not the TDD draft's game_session.gd: that
## name is reserved for Slice 3's host-only RefCounted simulation per the
## consistency guide §4 SessionClient/GameSession split (decision log
## 2026-07-06). Slice 3 hangs the round loop off game_started; this autoload
## stays the lobby-phase owner.

enum LocalState { MENU, HOST_CREATING, JOIN_CONNECTING, REGISTERING, IN_LOBBY, STARTING }

## Coarse game-phase marker. Stays LOBBY for this whole slice except the
## STARTING handoff; Slice 3's GameSession drives the real phase machine.
var phase: NetIds.Phase = NetIds.Phase.LOBBY
var roster: Roster = Roster.new()          # host: authoritative; client: mirror
var settings: GameSettings = GameSettings.new()
## Slice 6: the frozen settings snapshot every in-game system reads (set on
## every peer from the start payload; a fresh default outside a game so
## tests/smokes read sane values). The lobby `settings` object is never
## consulted after start.
var game_settings: GameSettings = GameSettings.new()
var room_code: String = ""                 # display value from welcome/host call

## Slice 9: the live SessionClient (host: owns the GameSession the in-game
## register/disconnect paths need; set/cleared by SessionClient itself).
var round_client: SessionClient = null

var _local_state: LocalState = LocalState.MENU
var _rate_limiter: SessionRules.ChatRateLimiter = SessionRules.ChatRateLimiter.new()
var _last_close_reason: String = ""        # menu consumes on _ready (survives scene swap)
var _epoch: int = 0                        # bumped every reset; invalidates stale watchdogs
var _pending_welcome: Dictionary = {}      # Slice 9: mid-game welcome, consumed by SessionClient


func _ready() -> void:
	EventBus.peer_connected.connect(_on_peer_connected)
	EventBus.peer_disconnected.connect(_on_peer_disconnected)
	EventBus.connection_failed.connect(_on_connection_failed)
	EventBus.server_disconnected.connect(_on_server_disconnected)


# --- Public actions (UI calls these; never mutates roster/settings directly) ---


## Coroutine - await it. Creates the session and self-registers the host.
func host_session(code: String) -> Error:
	if _local_state != LocalState.MENU:
		return ERR_BUSY
	_local_state = LocalState.HOST_CREATING
	var err: Error = await Net.host(code)
	if err != OK:
		_local_state = LocalState.MENU
		return err
	_reset_session_state()
	room_code = code.strip_edges().to_upper()
	_apply_register(1, Platform.get_platform_id(), Platform.get_display_name())
	# Slice 6 host convenience: restore the last-hosted lobby's settings
	# (round count re-seeds from the current suggestion by design).
	var profile: Dictionary = Save.read_json("profile.json", {})
	if profile.get("last_lobby_settings") is Dictionary:
		settings = GameSettings.restore_for_lobby(
				profile["last_lobby_settings"], roster.connected_count())
	_local_state = LocalState.IN_LOBBY
	Nav.goto(Routes.LOBBY)
	return OK


## Coroutine - await it. Connects to a host; registration is sent when the
## transport reports the server connection (see _on_peer_connected).
func join_session(code: String) -> Error:
	if _local_state != LocalState.MENU:
		return ERR_BUSY
	_reset_session_state()
	room_code = code.strip_edges().to_upper()
	_local_state = LocalState.JOIN_CONNECTING
	var err: Error = await Net.join(room_code)
	if err != OK:
		_local_state = LocalState.MENU
		room_code = ""
		return err
	_arm_state_watchdog(LocalState.JOIN_CONNECTING)
	return OK


func leave() -> void:
	if _local_state == LocalState.MENU:
		return
	Net.leave()
	_close_to_menu("left")


## Host: direct filtered path. Client: request RPC to the host.
func submit_chat(text: String) -> void:
	if Net.is_host():
		_handle_chat(1, text)
	elif _local_state == LocalState.IN_LOBBY or _local_state == LocalState.STARTING:
		rpc_request_send_chat.rpc_id(1, text)


## Host-only (silently ignored on clients). Clamps and broadcasts.
func set_settings(new_settings: GameSettings) -> void:
	if not Net.is_host() or phase != NetIds.Phase.LOBBY:
		return
	settings = new_settings.duplicate_settings()  # defensive copy - UI keeps no handle
	settings.clamp_to_limits()
	rpc_sync_settings.rpc(settings.to_dict())
	rpc_sync_round_suggestion.rpc(
			GameSettings.suggested_rounds(roster.connected_count()),
			settings.rounds_overridden)


func can_start() -> bool:
	return SessionRules.can_start(Net.is_host(), phase, roster.connected_count())


## Host-only. Re-validates at execution time - the roster may have changed
## since the button was clicked (Slice 2 TDD §10).
func start_game() -> void:
	if not can_start():
		return
	if not settings.validate_for_start(roster.connected_count()).is_empty():
		return   # Slice 7 fills real blockers; unreachable today (clamped edits)
	# Slice 6: persist the host's lobby setup (pre-snapshot - keeps AUTO
	# sentinels), then freeze the snapshot the whole game reads.
	var profile: Dictionary = Save.read_json("profile.json", {})
	profile["last_lobby_settings"] = settings.to_dict()
	Save.write_json("profile.json", profile)
	rpc_sync_game_started.rpc(_build_start_data())


## Host-only (standings screen, Slice 3): returns the whole session to the
## lobby with roster and settings intact for another game.
func return_to_lobby() -> void:
	if not Net.is_host() or phase == NetIds.Phase.LOBBY:
		return
	rpc_sync_return_to_lobby.rpc()


func is_host() -> bool:
	return Net.is_host()


## Host-only (Slice 4): mid-game roster re-broadcast after PlayerState
## economy fields (kudos_granted/kudos_spent) change on the host.
## Guarded by multiplayer authority (not Net.is_host) so headless tests -
## which have no active ENet peer - exercise the same broadcast path.
func broadcast_roster() -> void:
	if not multiplayer.is_server():
		return
	rpc_sync_roster.rpc(roster.to_dicts())


func local_player() -> Roster.PlayerState:
	return roster.get_by_peer(Net.local_peer_id())


## Menu screens call this on _ready to learn why they were returned to the
## menu (the value survives the scene swap). Empty string = nothing to show.
func consume_close_reason() -> String:
	var reason: String = _last_close_reason
	_last_close_reason = ""
	return reason


## Slice 9: the mid-game welcome payload survives the Nav swap the same way
## the close reason does; the client-side SessionClient consumes it in
## _ready to reconstruct the round state.
func consume_pending_welcome() -> Dictionary:
	var welcome: Dictionary = _pending_welcome
	_pending_welcome = {}
	return welcome


# --- Internal session logic (host-side unless noted) ---


## Shared registration path: host self-registration and the RPC handler both
## land here, so both get identical sanitation. No broadcasts (testable).
func _apply_register(peer_id: int, platform_id: String, raw_name: String) -> Roster.PlayerState:
	var clean_name: String = SessionRules.sanitize_name(raw_name, roster.size() + 1)
	var taken: Array[String] = []
	for p: Roster.PlayerState in roster.players_in_join_order():
		taken.append(p.display_name)
	clean_name = SessionRules.dedupe_display_name(clean_name, taken)
	if roster.get_by_platform_id(platform_id) != null:
		push_warning("Session: duplicate platform_id '%s' registered (peer %d)." % [platform_id, peer_id])
	var player: Roster.PlayerState = roster.register(peer_id, platform_id, clean_name)
	_refresh_suggested_rounds()
	return player


## Chat steps 2-5 of the 5-step pattern (step 1 lives in the RPC handler).
func _handle_chat(sender_peer_id: int, text: String) -> void:
	var player: Roster.PlayerState = roster.get_by_peer(sender_peer_id)
	if player == null:
		return                                        # 2. unknown peer - drop
	if not SessionRules.chat_text_ok(text):
		return                                        # 3a. content validation
	if not _rate_limiter.allow(sender_peer_id, Time.get_ticks_msec() / 1000.0):
		return                                        # 3b. rate limit - drop silently
	var clean: String = TextFilter.censor(text.strip_edges())  # 4. filter on host (brief §13)
	rpc_sync_chat_message.rpc(sender_peer_id, player.display_name, clean)  # 5. broadcast


## Suggested rounds recompute on every roster change unless the host has
## touched the spinner (Slice 2 TDD §6 business rule 2).
func _refresh_suggested_rounds() -> void:
	if settings.rounds_overridden or phase != NetIds.Phase.LOBBY:
		return
	settings.round_count = GameSettings.suggested_rounds(roster.connected_count())


func _build_start_data() -> Dictionary:
	# Slice 6: the payload carries the frozen snapshot (kudos AUTO resolved
	# to a concrete count); later host edits mutate the live lobby object,
	# never this payload.
	return {"settings": settings.snapshot().to_dict(), "roster": roster.to_dicts()}


func _broadcast_lobby_state() -> void:
	rpc_sync_roster.rpc(roster.to_dicts())
	rpc_sync_settings.rpc(settings.to_dict())
	rpc_sync_round_suggestion.rpc(
			GameSettings.suggested_rounds(roster.connected_count()),
			settings.rounds_overridden)


func _reset_session_state() -> void:
	roster = Roster.new()
	settings = GameSettings.new()
	game_settings = GameSettings.new()
	room_code = ""
	phase = NetIds.Phase.LOBBY
	_rate_limiter.reset()
	_pending_welcome = {}
	_epoch += 1


func _close_to_menu(reason: String) -> void:
	_reset_session_state()
	_local_state = LocalState.MENU
	_last_close_reason = reason
	EventBus.session_closed.emit(reason)
	Nav.goto(Routes.MENU)


## Drops this peer back to the menu if it is still stuck in `state` after
## REGISTER_TIMEOUT_SEC (e.g. host never answers the register request).
func _arm_state_watchdog(state: LocalState) -> void:
	var epoch: int = _epoch
	get_tree().create_timer(GameConstants.REGISTER_TIMEOUT_SEC).timeout.connect(
		func() -> void:
			if _epoch == epoch and _local_state == state:
				Net.leave()
				_close_to_menu("timeout"))


## Host: a peer that connects but never registers is dropped after the
## timeout (Slice 2 TDD §10 - no ghost slots; unknown peers' RPCs are
## already dropped by step 2 of every handler).
func _arm_register_timeout(peer_id: int) -> void:
	get_tree().create_timer(GameConstants.REGISTER_TIMEOUT_SEC).timeout.connect(
		func() -> void:
			if not Net.is_host():
				return
			if roster.get_by_peer(peer_id) != null:
				return
			if not multiplayer.get_peers().has(peer_id):
				return
			push_warning("Session: peer %d never registered; disconnecting." % peer_id)
			multiplayer.multiplayer_peer.disconnect_peer(peer_id))


## Gives the reject RPC time to flush before closing a hostile/full peer's
## connection (the polite client already left on rpc_do_reject_join).
func _disconnect_peer_later(peer_id: int) -> void:
	await get_tree().create_timer(GameConstants.REJECT_DISCONNECT_DELAY_SEC).timeout
	if Net.is_host() and multiplayer.get_peers().has(peer_id):
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


# --- EventBus/transport handlers ---


func _on_peer_connected(peer_id: int) -> void:
	if Net.is_host():
		if _local_state != LocalState.MENU:
			_arm_register_timeout(peer_id)
	elif peer_id == 1 and _local_state == LocalState.JOIN_CONNECTING:
		_local_state = LocalState.REGISTERING
		_arm_state_watchdog(LocalState.REGISTERING)
		rpc_request_register.rpc_id(1, Platform.get_platform_id(), Platform.get_display_name())


func _on_peer_disconnected(peer_id: int) -> void:
	if not Net.is_host() or _local_state == LocalState.MENU:
		return
	_rate_limiter.forget(peer_id)
	var player: Roster.PlayerState = roster.get_by_peer(peer_id)
	if player == null:
		return  # never registered - nothing to clean up
	if phase == NetIds.Phase.LOBBY:
		roster.remove_by_peer(peer_id)  # lobby-phase removal (Slice 2 scope)
		_refresh_suggested_rounds()
		_broadcast_lobby_state()
		return
	# Slice 9 in-game drop (§9 - quit and connection loss are identical):
	# entry retained as the rejoin memory, involvement paused.
	roster.mark_disconnected(peer_id, _unix_now_ms())
	broadcast_roster()
	rpc_sync_player_status.rpc(player.platform_id,
			NetIds.PlayerStatus.DROPPED, player.display_name)
	if round_client != null and round_client.game_session() != null:
		round_client.game_session().handle_departure(player)


func _on_connection_failed() -> void:
	if _local_state == LocalState.JOIN_CONNECTING or _local_state == LocalState.REGISTERING:
		_close_to_menu("connection_failed")


func _on_server_disconnected() -> void:
	if _local_state == LocalState.MENU:
		return
	_close_to_menu("host_quit")


# --- RPC methods (grouped last per consistency guide §3) ---


## client -> host. 5-step validation per consistency guide §4. Slice 9
## replaced the flat "in_progress" reject: phase != LOBBY now routes through
## the rejoin/late-join branches.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_register(platform_id: String, display_name: String) -> void:
	if not multiplayer.is_server():
		return                                             # 1. authority
	var sender: int = multiplayer.get_remote_sender_id()
	if roster.get_by_peer(sender) != null:
		return                                             # 2. sender must be NEW
	if phase != NetIds.Phase.LOBBY:
		_handle_ingame_register(sender, platform_id, display_name)
		return
	var reject: String = SessionRules.register_reject_reason(
			phase, roster.connected_count(), platform_id)  # 3. validate vs phase/state
	if not reject.is_empty():
		rpc_do_reject_join.rpc_id(sender, reject)
		_disconnect_peer_later(sender)
		return
	_apply_register(sender, platform_id, display_name)     # 4. apply on host
	rpc_do_welcome.rpc_id(sender, {                        # 5. respond + broadcast
		"roster": roster.to_dicts(),
		"settings": settings.to_dict(),
		"room_code": room_code,
	})
	_broadcast_lobby_state()


## Slice 9 (§6): steps 3-5 of registration once the game is running. A known
## disconnected platform_id rebinds to its retained entry (rejoin); an
## unknown one is admitted mid-game (late join) while a connected seat is
## free. Both get the full mid-game welcome snapshot; everyone else gets the
## roster and a status broadcast. Either admission may end a pause.
func _handle_ingame_register(sender: int, platform_id: String, display_name: String) -> void:
	var game: GameSession = round_client.game_session() if round_client != null else null
	if game == null:
		# STARTING gap / teardown: not joinable yet - the Slice 2 reject.
		rpc_do_reject_join.rpc_id(sender, "in_progress")
		_disconnect_peer_later(sender)
		return
	var existing: Roster.PlayerState = roster.get_by_platform_id(platform_id)
	var action: String = SessionRules.ingame_register_action(
			existing != null, existing != null and existing.is_connected,
			roster.connected_count(), platform_id)
	match action:
		"rejoin":
			roster.rebind_peer(platform_id, sender)
			game.admit_rejoiner(existing)   # may resume a below-minimum pause
			rpc_do_welcome_ingame.rpc_id(sender, _build_ingame_welcome(game, existing))
			broadcast_roster()
			rpc_sync_player_status.rpc(platform_id,
					NetIds.PlayerStatus.REJOINED, existing.display_name)
		"late_join":
			var p: Roster.PlayerState = _apply_register(sender, platform_id, display_name)
			game.admit_late_joiner(p)
			rpc_do_welcome_ingame.rpc_id(sender, _build_ingame_welcome(game, p))
			broadcast_roster()
			rpc_sync_player_status.rpc(platform_id,
					NetIds.PlayerStatus.LATE_JOINED, p.display_name)
		_:
			rpc_do_reject_join.rpc_id(sender, action)
			_disconnect_peer_later(sender)


func _build_ingame_welcome(game: GameSession, p: Roster.PlayerState) -> Dictionary:
	return {
		"roster": roster.to_dicts(),
		"settings": game_settings.to_dict(),   # the frozen in-game snapshot
		"room_code": room_code,
		"game": game.build_welcome_snapshot(p),
	}


static func _unix_now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


## host -> new peer: full state for the freshly registered client.
@rpc("authority", "call_remote", "reliable")
func rpc_do_welcome(state: Dictionary) -> void:
	if _local_state != LocalState.REGISTERING:
		return  # stale/duplicate welcome - ignore
	roster.apply_dicts(state.get("roster", []))
	settings = GameSettings.from_dict(state.get("settings", {}))
	room_code = str(state.get("room_code", ""))
	phase = NetIds.Phase.LOBBY
	_local_state = LocalState.IN_LOBBY
	Nav.goto(Routes.LOBBY)


## host -> peer: registration refused ("full", "in_progress", "bad_identity").
@rpc("authority", "call_remote", "reliable")
func rpc_do_reject_join(reason: String) -> void:
	if _local_state != LocalState.REGISTERING:
		return
	Net.leave()
	_close_to_menu(reason)


## host -> new/returning peer (Slice 9): the mid-game welcome. The payload
## is stashed for the SessionClient this peer is about to construct - the
## RoundRoot scene does not exist yet, so nothing can be applied here beyond
## the session-level mirrors.
@rpc("authority", "call_remote", "reliable")
func rpc_do_welcome_ingame(state: Dictionary) -> void:
	if _local_state != LocalState.REGISTERING:
		return  # stale/duplicate welcome - ignore
	roster.apply_dicts(state.get("roster", []))
	game_settings = GameSettings.from_dict(state.get("settings", {}))
	game_settings.freeze()
	room_code = str(state.get("room_code", ""))
	var game: Dictionary = state.get("game", {})
	phase = int(game.get("phase", NetIds.Phase.ROUND_INTRO)) as NetIds.Phase  # coarse marker
	_local_state = LocalState.STARTING
	_pending_welcome = state
	Nav.goto(Routes.ROUND)


## host -> all (Slice 9): a player dropped / rejoined / late-joined.
## kind: NetIds.PlayerStatus. Pure event vehicle (toasts + UI) - roster
## mirrors are updated by the rpc_sync_roster broadcast that precedes it.
@rpc("authority", "call_local", "reliable")
func rpc_sync_player_status(platform_id: String, kind: int, display_name: String) -> void:
	match kind:
		NetIds.PlayerStatus.DROPPED:
			EventBus.player_dropped.emit(platform_id, display_name)
		NetIds.PlayerStatus.REJOINED:
			EventBus.player_rejoined.emit(platform_id, display_name)
		NetIds.PlayerStatus.LATE_JOINED:
			EventBus.player_late_joined.emit(platform_id, display_name)


## host -> all: roster mirror replace.
@rpc("authority", "call_local", "reliable")
func rpc_sync_roster(players: Array) -> void:
	if not multiplayer.is_server():
		roster.apply_dicts(players)  # host keeps its authoritative objects
	EventBus.roster_updated.emit(players)


## host -> all: settings mirror replace.
@rpc("authority", "call_local", "reliable")
func rpc_sync_settings(settings_dict: Dictionary) -> void:
	if not multiplayer.is_server():
		settings = GameSettings.from_dict(settings_dict)
	EventBus.lobby_settings_changed.emit(settings_dict)


## client -> host. 5-step validation per consistency guide §4.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_send_chat(text: String) -> void:
	if not multiplayer.is_server():
		return                                             # 1. authority
	_handle_chat(multiplayer.get_remote_sender_id(), text) # 2-5 shared with host path


## host -> all: a chat message cleared host filtering.
@rpc("authority", "call_local", "reliable")
func rpc_sync_chat_message(sender_peer_id: int, sender_name: String, text: String) -> void:
	EventBus.chat_message_received.emit(sender_peer_id, sender_name, text)


## host -> all: settings mirror replace (also sent to fresh joiners).
@rpc("authority", "call_local", "reliable")
func rpc_sync_round_suggestion(suggested: int, overridden: bool) -> void:
	EventBus.round_suggestion_changed.emit(suggested, overridden)


## host -> all: settings/roster frozen; Slice 3 takes over from here.
@rpc("authority", "call_local", "reliable")
func rpc_sync_game_started(start_data: Dictionary) -> void:
	phase = NetIds.Phase.ROUND_INTRO  # coarse marker; GameSession drives the real machine
	_local_state = LocalState.STARTING
	# Slice 6: every peer constructs its immutable in-game snapshot from the
	# payload - nothing reads lobby settings after start.
	game_settings = GameSettings.from_dict(start_data.get("settings", {}))
	game_settings.freeze()
	EventBus.game_started.emit(start_data)
	# Slice 3 handoff: every peer enters RoundRoot (which hosts SessionClient;
	# the host side constructs the GameSession simulation there).
	Nav.goto(Routes.ROUND)


## host -> all (Slice 3): back to the lobby after WRAP_UP, same roster and
## settings, ready for another game.
@rpc("authority", "call_local", "reliable")
func rpc_sync_return_to_lobby() -> void:
	phase = NetIds.Phase.LOBBY
	_local_state = LocalState.IN_LOBBY
	if multiplayer.is_server():
		# Players who dropped mid-game are pruned now - lobby rules resume
		# (in-game entries were kept for Slice 9's rejoin story).
		for p: Roster.PlayerState in roster.players_in_join_order():
			if not p.is_connected:
				roster.remove_by_peer(p.peer_id)
		_refresh_suggested_rounds()
	Nav.goto(Routes.LOBBY)
	if multiplayer.is_server():
		_broadcast_lobby_state()
