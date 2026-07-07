class_name TestSessionValidation
extends GdUnitTestSuite
## Slice 2: host-side validators as plain functions - no live network
## (TDD §11; consistency guide §9). Covers SessionRules and the shared
## registration/start paths on an un-treed session_manager instance.

const SessionManagerScript: GDScript = preload("res://game/session/session_manager.gd")


func before_test() -> void:
	# Deterministic blocklist for name/chat censoring tests.
	TextFilter.configure(PackedStringArray(["badword"]))


func after_test() -> void:
	TextFilter.configure(PackedStringArray())  # reload real blocklist lazily


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
