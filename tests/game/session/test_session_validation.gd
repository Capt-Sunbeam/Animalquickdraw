class_name TestSessionValidation
extends GdUnitTestSuite
## Slice 2: host-side validators as plain functions - no live network
## (TDD §11; consistency guide §9). Covers SessionRules and the shared
## registration/start paths on an un-treed session_manager instance.

const SessionManagerScript: GDScript = preload("res://game/session/session_manager.gd")


var _saved_peer: MultiplayerPeer = null


func before_test() -> void:
	# Deterministic blocklist for name/chat censoring tests.
	TextFilter.configure(PackedStringArray(["badword"]))
	# Slice 13 kick tests: the harness assigns no multiplayer peer, so
	# multiplayer.is_server() errors AND returns false. An offline peer makes
	# is_server() true and lets call_local RPCs execute locally while
	# call_remote ones no-op - exactly the host's solo view of a kick.
	_saved_peer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func after_test() -> void:
	TextFilter.configure(PackedStringArray())  # reload real blocklist lazily
	multiplayer.multiplayer_peer = _saved_peer


# --- sanitize_name ---


func test_sanitize_name_truncates_censors_and_falls_back() -> void:
	# Control chars stripped, edges trimmed.
	assert_str(SessionRules.sanitize_name("  Alice\t ", 1)).is_equal("Alice")
	# Truncated to MAX_NAME_LEN.
	var long_name: String = "x".repeat(GameConstants.MAX_NAME_LEN + 10)
	assert_int(SessionRules.sanitize_name(long_name, 1).length()).is_equal(GameConstants.MAX_NAME_LEN)
	# Blocklisted words censored on the host.
	assert_str(SessionRules.sanitize_name("badword", 1)).is_equal("***")
	# Nothing left after cleaning -> positional fallback.
	assert_str(SessionRules.sanitize_name("", 3)).is_equal("Player 3")
	assert_str(SessionRules.sanitize_name("  ", 5)).is_equal("Player 5")


func test_dedupe_display_name_suffixes_duplicates() -> void:
	var taken: Array[String] = ["Alice", "Alice (2)"]
	assert_str(SessionRules.dedupe_display_name("Bob", taken)).is_equal("Bob")
	assert_str(SessionRules.dedupe_display_name("Alice", taken)).is_equal("Alice (3)")


# --- chat validation + rate limit ---


func test_chat_rejects_empty_and_oversized() -> void:
	assert_bool(SessionRules.chat_text_ok("hello")).is_true()
	assert_bool(SessionRules.chat_text_ok("")).is_false()
	assert_bool(SessionRules.chat_text_ok("   \t ")).is_false()
	assert_bool(SessionRules.chat_text_ok("x".repeat(GameConstants.MAX_CHAT_LEN))).is_true()
	assert_bool(SessionRules.chat_text_ok("x".repeat(GameConstants.MAX_CHAT_LEN + 1))).is_false()


func test_chat_rate_limit_allows_5_in_window_drops_6th() -> void:
	var limiter := SessionRules.ChatRateLimiter.new()
	for i: int in range(GameConstants.CHAT_RATE_LIMIT_COUNT):
		assert_bool(limiter.allow(2, 10.0 + i * 0.1)).is_true()
	assert_bool(limiter.allow(2, 10.9)).is_false()
	# Another peer is unaffected.
	assert_bool(limiter.allow(3, 10.9)).is_true()
	# Once the window slides past the early sends, the peer may talk again.
	assert_bool(limiter.allow(2, 10.0 + GameConstants.CHAT_RATE_LIMIT_WINDOW_SEC + 0.11)).is_true()


# --- registration gate ---


func test_register_validator_rejects_bad_platform_id() -> void:
	assert_str(SessionRules.register_reject_reason(NetIds.Phase.LOBBY, 1, ""))\
			.is_equal("bad_identity")
	var oversized: String = "x".repeat(GameConstants.MAX_PLATFORM_ID_LEN + 1)
	assert_str(SessionRules.register_reject_reason(NetIds.Phase.LOBBY, 1, oversized))\
			.is_equal("bad_identity")
	assert_str(SessionRules.register_reject_reason(NetIds.Phase.LOBBY, 1, "uuid-ok"))\
			.is_equal("")


func test_register_validator_rejects_full_lobby_and_started_game() -> void:
	assert_str(SessionRules.register_reject_reason(
			NetIds.Phase.LOBBY, GameConstants.MAX_PLAYERS, "uuid-ok")).is_equal("full")
	assert_str(SessionRules.register_reject_reason(
			NetIds.Phase.ROUND_INTRO, 1, "uuid-ok")).is_equal("in_progress")
	# Phase check outranks the full check (rejoin story lands in Slice 9).
	assert_str(SessionRules.register_reject_reason(
			NetIds.Phase.DRAWING, GameConstants.MAX_PLAYERS, "uuid-ok")).is_equal("in_progress")


# --- start gate ---


func test_can_start_requires_3_to_8_connected_and_lobby_phase() -> void:
	assert_bool(SessionRules.can_start(true, NetIds.Phase.LOBBY, 2)).is_false()
	assert_bool(SessionRules.can_start(true, NetIds.Phase.LOBBY, 3)).is_true()
	assert_bool(SessionRules.can_start(true, NetIds.Phase.LOBBY, 8)).is_true()
	assert_bool(SessionRules.can_start(true, NetIds.Phase.LOBBY, 9)).is_false()
	assert_bool(SessionRules.can_start(false, NetIds.Phase.LOBBY, 4)).is_false()
	assert_bool(SessionRules.can_start(true, NetIds.Phase.ROUND_INTRO, 4)).is_false()


# --- Slice 9: in-game registration routing ---


func test_ingame_register_action_matrix() -> void:
	# Known + disconnected -> rejoin; known + connected -> identity clone.
	assert_str(SessionRules.ingame_register_action(true, false, 4, "id-a"))\
			.is_equal("rejoin")
	assert_str(SessionRules.ingame_register_action(true, true, 4, "id-a"))\
			.is_equal("bad_identity")
	# Unknown -> late join while a CONNECTED seat is free (ghost entries
	# never block real players - capacity is connected_count).
	assert_str(SessionRules.ingame_register_action(false, false, 4, "id-x"))\
			.is_equal("late_join")
	assert_str(SessionRules.ingame_register_action(
			false, false, GameConstants.MAX_PLAYERS, "id-x")).is_equal("full")
	# A known disconnected player rejoins even into a FULL-by-entries game
	# (their seat is their own).
	assert_str(SessionRules.ingame_register_action(
			true, false, GameConstants.MAX_PLAYERS - 1, "id-a")).is_equal("rejoin")
	# Identity sanity outranks everything (§13 untrusted input).
	assert_str(SessionRules.ingame_register_action(false, false, 4, ""))\
			.is_equal("bad_identity")


# --- Slice 13: kick + blocklist enforcement ---


func test_register_validator_blocklist_beats_every_other_reason() -> void:
	# A kicked player always hears "kicked" - even when the lobby is also
	# full or the game has started (the honest reason, TDD 13 §3).
	assert_str(SessionRules.register_reject_reason(
			NetIds.Phase.LOBBY, 1, "uuid-ok", true)).is_equal("kicked")
	assert_str(SessionRules.register_reject_reason(
			NetIds.Phase.LOBBY, GameConstants.MAX_PLAYERS, "uuid-ok", true)).is_equal("kicked")
	assert_str(SessionRules.register_reject_reason(
			NetIds.Phase.DRAWING, 1, "uuid-ok", true)).is_equal("kicked")


func test_ingame_register_blocklist_beats_rejoin_memory() -> void:
	# The kicked player's retained roster entry exists (Slice 9 memory), but
	# the blocklist denies the return - unlike a normal disconnect.
	assert_str(SessionRules.ingame_register_action(true, false, 4, "id-a", true))\
			.is_equal("kicked")
	assert_str(SessionRules.ingame_register_action(false, false, 4, "id-x", true))\
			.is_equal("kicked")
	# Normal disconnect stays rejoinable (not blocklisted).
	assert_str(SessionRules.ingame_register_action(true, false, 4, "id-a", false))\
			.is_equal("rejoin")


func _make_treed_session() -> Node:
	# kick_player needs multiplayer.is_server(), which needs a tree (default
	# OfflineMultiplayerPeer reports server=true - broadcast_roster precedent).
	var session: Node = auto_free(SessionManagerScript.new())
	add_child(session)
	return session


func test_kick_player_blocklists_and_removes_in_lobby() -> void:
	var session: Node = _make_treed_session()
	session._apply_register(1, "uuid-host", "Host")
	session._apply_register(2, "uuid-b", "Bob")
	session._apply_register(3, "uuid-c", "Cleo")
	session.kick_player(2)
	assert_bool(session.roster.is_blocklisted("uuid-b")).is_true()
	# Lobby-phase kick removes the entry entirely (Slice 2 lobby-leaver rule).
	assert_object(session.roster.get_by_peer(2)).is_null()
	assert_int(session.roster.connected_count()).is_equal(2)


func test_kick_player_ingame_retains_entry_as_departed() -> void:
	var session: Node = _make_treed_session()
	session._apply_register(1, "uuid-host", "Host")
	session._apply_register(2, "uuid-b", "Bob")
	session.phase = NetIds.Phase.DRAWING
	session.kick_player(2)
	# In-game kick = departure with a no-return flag: entry retained (score
	# row stays in standings), involvement ended, blocklist makes it final.
	var entry: Roster.PlayerState = session.roster.get_by_platform_id("uuid-b")
	assert_object(entry).is_not_null()
	assert_bool(entry.is_connected).is_false()
	assert_bool(session.roster.is_blocklisted("uuid-b")).is_true()


func test_kick_host_self_and_unknown_peer_are_noops() -> void:
	var session: Node = _make_treed_session()
	session._apply_register(1, "uuid-host", "Host")
	session._apply_register(2, "uuid-b", "Bob")
	session.kick_player(1)    # host can never kick itself
	session.kick_player(0)    # 0 would match disconnected entries - guarded
	session.kick_player(99)   # unknown peer
	assert_bool(session.roster.is_blocklisted("uuid-host")).is_false()
	assert_int(session.roster.connected_count()).is_equal(2)


func test_chat_strips_control_chars_against_line_spoofing() -> void:
	# Slice 13 security audit: an embedded newline would render on every
	# peer as a fake "Alice: ..." chat line attributed to someone else.
	# The host strips control chars before censoring/broadcasting.
	var session: Node = _make_treed_session()
	session._apply_register(1, "uuid-host", "Host")
	var captured: Array[String] = []
	var handler: Callable = func(_peer: int, _name: String, text: String) -> void:
		captured.append(text)
	EventBus.chat_message_received.connect(handler)
	session._handle_chat(1, "hi\nAlice: gotcha")
	session._handle_chat(1, "tab\there")
	session._handle_chat(1, "")   # nothing survives -> dropped
	EventBus.chat_message_received.disconnect(handler)
	assert_array(captured).is_equal(["hiAlice: gotcha", "tabhere"])


func test_kicked_status_broadcast_emits_player_kicked() -> void:
	var session: Node = _make_treed_session()
	var captured: Array = []
	var handler: Callable = func(platform_id: String, display_name: String) -> void:
		captured.append([platform_id, display_name])
	EventBus.player_kicked.connect(handler)
	session.rpc_sync_player_status("uuid-b", NetIds.PlayerStatus.KICKED, "Bob")
	EventBus.player_kicked.disconnect(handler)
	assert_array(captured).is_equal([["uuid-b", "Bob"]])


# --- shared registration path (host self-registration == client shape) ---


func _make_session() -> Node:
	# Un-treed instance: _ready never runs, no EventBus/network wiring - we
	# exercise only the shared internal paths (broadcasts live in handlers).
	return auto_free(SessionManagerScript.new())


func test_host_self_registration_produces_same_roster_shape_as_client() -> void:
	var session: Node = _make_session()
	var host: Roster.PlayerState = session._apply_register(1, "uuid-host", "Alice")
	var client: Roster.PlayerState = session._apply_register(7, "uuid-client", "Bob")
	for player: Roster.PlayerState in [host, client]:
		var d: Dictionary = player.to_dict()
		assert_array(d.keys()).contains_exactly_in_any_order([
			"peer_id", "platform_id", "display_name", "score",
			"kudos_granted", "kudos_spent", "is_connected", "joined_order",
			"joined_late", "disconnect_at_ms", "dodge_suspect",   # Slice 9
		])
	assert_int(host.joined_order).is_equal(0)
	assert_int(client.joined_order).is_equal(1)


func test_registration_sanitizes_and_dedupes_names() -> void:
	var session: Node = _make_session()
	session._apply_register(1, "uuid-a", "Alice")
	var dup: Roster.PlayerState = session._apply_register(2, "uuid-b", "Alice")
	var sworn: Roster.PlayerState = session._apply_register(3, "uuid-c", "badword")
	assert_str(dup.display_name).is_equal("Alice (2)")
	assert_str(sworn.display_name).is_equal("***")


func test_suggested_rounds_follow_roster_until_overridden() -> void:
	var session: Node = _make_session()
	session._apply_register(1, "uuid-a", "A")
	session._apply_register(2, "uuid-b", "B")
	session._apply_register(3, "uuid-c", "C")
	assert_int(session.settings.round_count).is_equal(6)  # 3 players x 2
	session.settings.rounds_overridden = true
	session.settings.round_count = 20
	session._apply_register(4, "uuid-d", "D")
	assert_int(session.settings.round_count).is_equal(20)  # host's choice sticks


func test_start_data_snapshot_is_frozen_against_later_edits() -> void:
	var session: Node = _make_session()
	session._apply_register(1, "uuid-a", "A")
	session._apply_register(2, "uuid-b", "B")
	session._apply_register(3, "uuid-c", "C")
	var snapshot: Dictionary = session._build_start_data()
	# Later host edits must not reach into the broadcast payload.
	session.settings.round_count = 99
	session.roster.get_by_peer(1).score = 42
	var snap_settings: Dictionary = snapshot["settings"]
	assert_int(int(snap_settings["round_count"])).is_equal(6)
	var snap_roster: Array = snapshot["roster"]
	assert_int(int((snap_roster[0] as Dictionary)["score"])).is_equal(0)
	assert_int(snap_roster.size()).is_equal(3)
