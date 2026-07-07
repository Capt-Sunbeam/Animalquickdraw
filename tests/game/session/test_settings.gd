class_name TestSettings
extends GdUnitTestSuite
## Slice 2: GameSettings suggestion math, clamping, serialization (TDD §11).


func test_suggested_rounds_is_two_times_players() -> void:
	assert_int(GameSettings.suggested_rounds(3)).is_equal(6)
	assert_int(GameSettings.suggested_rounds(5)).is_equal(10)
	assert_int(GameSettings.suggested_rounds(8)).is_equal(16)


func test_suggested_rounds_clamps_to_bounds() -> void:
	assert_int(GameSettings.suggested_rounds(0)).is_equal(GameConstants.ROUNDS_MIN)
	assert_int(GameSettings.suggested_rounds(1000)).is_equal(GameConstants.ROUNDS_MAX)


func test_from_dict_defaults_missing_fields() -> void:
	var s: GameSettings = GameSettings.from_dict({})
	assert_int(s.mode).is_equal(SettingsDefaults.Mode.DEFAULT)
	assert_int(s.round_count).is_equal(6)
	assert_float(s.draw_time_sec).is_equal(SettingsDefaults.DEFAULT_DRAW_TIME_SEC)
	assert_int(s.pool_source).is_equal(GameSettings.PoolSource.BUILT_IN)
	assert_str(s.pool_type_id).is_equal(SettingsDefaults.DEFAULT_POOL_TYPE_ID)
	assert_bool(s.rounds_overridden).is_false()


func test_to_dict_from_dict_round_trip() -> void:
	var s := GameSettings.new()
	s.round_count = 12
	s.draw_time_sec = 60.0
	s.pool_source = GameSettings.PoolSource.PLAYER_CREATED
	s.rounds_overridden = true
	var back: GameSettings = GameSettings.from_dict(s.to_dict())
	assert_int(back.round_count).is_equal(12)
	assert_float(back.draw_time_sec).is_equal(60.0)
	assert_int(back.pool_source).is_equal(GameSettings.PoolSource.PLAYER_CREATED)
	assert_bool(back.rounds_overridden).is_true()


func test_draw_time_clamped_to_min_max() -> void:
	var s := GameSettings.new()
	s.draw_time_sec = 1.0
	s.clamp_to_limits()
	assert_float(s.draw_time_sec).is_equal(GameConstants.DRAW_TIME_MIN_SEC)
	s.draw_time_sec = 9999.0
	s.clamp_to_limits()
	assert_float(s.draw_time_sec).is_equal(GameConstants.DRAW_TIME_MAX_SEC)


func test_round_count_clamped_to_min_max() -> void:
	var s := GameSettings.new()
	s.round_count = 0
	s.clamp_to_limits()
	assert_int(s.round_count).is_equal(GameConstants.ROUNDS_MIN)
	s.round_count = 999
	s.clamp_to_limits()
	assert_int(s.round_count).is_equal(GameConstants.ROUNDS_MAX)


func test_default_draw_time_is_thirty_seconds() -> void:
	# Decision log 2026-07-04: DRAW_TIME_DEFAULT_SEC = 30 supersedes the
	# Slice 2 TDD draft's 45.
	assert_float(GameSettings.new().draw_time_sec).is_equal(30.0)
