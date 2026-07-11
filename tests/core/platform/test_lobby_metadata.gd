class_name TestLobbyMetadata
extends GdUnitTestSuite
## Slice 12: pure lobby-metadata builder/parser (TDD 12 §11). This schema
## is the contract Slice 13's browser consumes - keys are frozen here.

const ALL_KEYS: Array[String] = [
	LobbyMetadata.KEY_PROTO, LobbyMetadata.KEY_CODE, LobbyMetadata.KEY_NAME,
	LobbyMetadata.KEY_MODE, LobbyMetadata.KEY_PLAYERS, LobbyMetadata.KEY_MAX_PLAYERS,
	LobbyMetadata.KEY_ROUNDS, LobbyMetadata.KEY_DRAW_TIME, LobbyMetadata.KEY_POOL_TYPE,
	LobbyMetadata.KEY_PUBLIC, LobbyMetadata.KEY_STATE,
]


func after_test() -> void:
	# Restore the real blocklist after censor tests.
	TextFilter.configure(TextFilter._load_words())


func _settings() -> Dictionary:
	var s := GameSettings.new()
	s.round_count = 12
	s.draw_time_sec = 45.0
	s.pool_source = GameSettings.PoolSource.PLAYER_CREATED
	s.is_public = true
	return s.to_dict()


func test_build_full_contains_all_schema_keys() -> void:
	var meta: Dictionary = LobbyMetadata.build_full("PYGMY", "Alice", _settings(), 4, false)
	for key: String in ALL_KEYS:
		assert_bool(meta.has(key)).override_failure_message("missing key %s" % key).is_true()
	assert_int(meta.size()).is_equal(ALL_KEYS.size())


func test_metadata_values_are_all_strings() -> void:
	var meta: Dictionary = LobbyMetadata.build_full("PYGMY", "Alice", _settings(), 4, true)
	for key: String in meta:
		assert_bool(meta[key] is String) \
				.override_failure_message("%s is not a String" % key).is_true()


func test_build_full_values_match_inputs() -> void:
	var meta: Dictionary = LobbyMetadata.build_full("PYGMY", "Alice", _settings(), 4, false)
	assert_str(meta[LobbyMetadata.KEY_PROTO]).is_equal(NetIds.PROTOCOL_VERSION)
	assert_str(meta[LobbyMetadata.KEY_CODE]).is_equal("PYGMY")
	assert_str(meta[LobbyMetadata.KEY_NAME]).is_equal("Alice's game")
	assert_str(meta[LobbyMetadata.KEY_MODE]).is_equal("default")
	assert_str(meta[LobbyMetadata.KEY_PLAYERS]).is_equal("4")
	assert_str(meta[LobbyMetadata.KEY_MAX_PLAYERS]).is_equal(str(GameConstants.MAX_PLAYERS))
	assert_str(meta[LobbyMetadata.KEY_ROUNDS]).is_equal("12")
	assert_str(meta[LobbyMetadata.KEY_DRAW_TIME]).is_equal("45")
	assert_str(meta[LobbyMetadata.KEY_POOL_TYPE]).is_equal("player")
	assert_str(meta[LobbyMetadata.KEY_PUBLIC]).is_equal("1")
	assert_str(meta[LobbyMetadata.KEY_STATE]).is_equal(LobbyMetadata.STATE_LOBBY)


func test_host_name_is_censored_in_lobby_name() -> void:
	TextFilter.configure(PackedStringArray(["grubface"]))
	var meta: Dictionary = LobbyMetadata.build_full("PYGMY", "grubface", _settings(), 3, false)
	var lobby_name: String = meta[LobbyMetadata.KEY_NAME]
	assert_bool(lobby_name.to_lower().contains("grubface")).is_false()
	assert_bool(lobby_name.ends_with("'s game")).is_true()


func test_settings_change_updates_only_dynamic_keys() -> void:
	var keys: Dictionary = LobbyMetadata.settings_keys(_settings())
	var expected: Array[String] = [
		LobbyMetadata.KEY_MODE, LobbyMetadata.KEY_ROUNDS, LobbyMetadata.KEY_DRAW_TIME,
		LobbyMetadata.KEY_POOL_TYPE, LobbyMetadata.KEY_PUBLIC,
	]
	assert_int(keys.size()).is_equal(expected.size())
	for key: String in expected:
		assert_bool(keys.has(key)).override_failure_message("missing key %s" % key).is_true()
	# Identity keys (code, proto, name) must never ride a settings update.
	assert_bool(keys.has(LobbyMetadata.KEY_CODE)).is_false()
	assert_bool(keys.has(LobbyMetadata.KEY_PROTO)).is_false()


func test_players_and_state_keys() -> void:
	assert_str(LobbyMetadata.players_key(7)[LobbyMetadata.KEY_PLAYERS]).is_equal("7")
	assert_str(LobbyMetadata.state_key(true)[LobbyMetadata.KEY_STATE]) \
			.is_equal(LobbyMetadata.STATE_INGAME)
	assert_str(LobbyMetadata.state_key(false)[LobbyMetadata.KEY_STATE]) \
			.is_equal(LobbyMetadata.STATE_LOBBY)


func test_parse_tolerates_missing_keys_with_defaults() -> void:
	# A foreign App-ID-480 lobby (no aq_* keys) parses to harmless defaults.
	var parsed: Dictionary = LobbyMetadata.parse({})
	assert_str(parsed["proto"]).is_equal("")
	assert_str(parsed["code"]).is_equal("")
	assert_int(parsed["players"]).is_equal(0)
	assert_int(parsed["rounds"]).is_equal(0)
	assert_str(parsed["pool_type"]).is_equal("builtin")
	assert_bool(parsed["is_public"]).is_false()
	assert_str(parsed["state"]).is_equal(LobbyMetadata.STATE_LOBBY)


func test_parse_round_trips_built_metadata() -> void:
	var meta: Dictionary = LobbyMetadata.build_full("PYGMY", "Alice", _settings(), 4, true)
	var parsed: Dictionary = LobbyMetadata.parse(meta)
	assert_str(parsed["code"]).is_equal("PYGMY")
	assert_int(parsed["players"]).is_equal(4)
	assert_int(parsed["max_players"]).is_equal(GameConstants.MAX_PLAYERS)
	assert_int(parsed["rounds"]).is_equal(12)
	assert_int(parsed["draw_time"]).is_equal(45)
	assert_str(parsed["pool_type"]).is_equal("player")
	assert_bool(parsed["is_public"]).is_true()
	assert_str(parsed["state"]).is_equal(LobbyMetadata.STATE_INGAME)


func test_proto_mismatch_detected() -> void:
	var meta: Dictionary = LobbyMetadata.build_full("PYGMY", "Alice", _settings(), 4, false)
	assert_bool(LobbyMetadata.proto_matches(meta)).is_true()
	assert_bool(LobbyMetadata.proto_matches({})).is_false()
	assert_bool(LobbyMetadata.proto_matches({LobbyMetadata.KEY_PROTO: "999"})).is_false()
