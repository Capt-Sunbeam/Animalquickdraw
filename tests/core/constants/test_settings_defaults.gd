class_name TestSettingsDefaults
extends GdUnitTestSuite
## Slice 6 presets (TDD §2/§11): every preset key must be a real
## GameSettings key with an in-range value (guards the literal-int
## convention - core can't reference game/ enums), presets must omit the
## always-tunable round_count/pool_source, and each preset's identity is
## pinned so playtest tuning can't silently break what a mode MEANS.


func _applied(mode: int) -> GameSettings:
	var s := GameSettings.new()
	s.apply_preset(mode)
	return s


func test_every_preset_key_is_known_and_in_range() -> void:
	for mode: int in SettingsDefaults.PRESETS.keys():
		var preset: Dictionary = SettingsDefaults.PRESETS[mode]
		var s: GameSettings = _applied(mode)
		var serialized: Dictionary = s.to_dict()
		for key: Variant in preset.keys():
			assert_bool(serialized.has(str(key)))\
					.override_failure_message("preset %d key '%s' unknown to GameSettings"
							% [mode, str(key)]).is_true()
			# apply_preset clamps afterwards; equality proves in-range values.
			assert_that(serialized[str(key)])\
					.override_failure_message("preset %d key '%s' was clamped - out of range"
							% [mode, str(key)]).is_equal(preset[key])


func test_presets_omit_round_count_and_pool_source() -> void:
	for mode: int in SettingsDefaults.PRESETS.keys():
		var preset: Dictionary = SettingsDefaults.PRESETS[mode]
		assert_bool(preset.has("round_count")).is_false()
		assert_bool(preset.has("pool_source")).is_false()


func test_streamlined_identity_grid_off_quick() -> void:
	var s: GameSettings = _applied(SettingsDefaults.Mode.STREAMLINED)
	assert_int(s.reveal_style).is_equal(GameSettings.RevealStyle.GRID)
	assert_int(s.replay_mode).is_equal(GameSettings.ReplayMode.OFF)
	assert_bool(s.comments_enabled).is_false()
	assert_bool(s.judging_window_sec <= 20.0).is_true()
	assert_bool(s.draw_time_sec <= 25.0).is_true()


func test_social_identity_one_at_a_time_full_long() -> void:
	var s: GameSettings = _applied(SettingsDefaults.Mode.SOCIAL)
	assert_int(s.reveal_style).is_equal(GameSettings.RevealStyle.ONE_AT_A_TIME)
	assert_int(s.replay_mode).is_equal(GameSettings.ReplayMode.FULL)
	assert_bool(s.comments_enabled).is_true()
	assert_bool(s.judging_window_sec >= 35.0).is_true()
	assert_bool(s.draw_time_sec >= 40.0).is_true()


func test_default_identity_one_at_a_time_winner_only() -> void:
	var s: GameSettings = _applied(SettingsDefaults.Mode.DEFAULT)
	assert_int(s.reveal_style).is_equal(GameSettings.RevealStyle.ONE_AT_A_TIME)
	assert_int(s.replay_mode).is_equal(GameSettings.ReplayMode.WINNER_ONLY)
	assert_bool(s.comments_enabled).is_true()
	assert_int(s.kudos_allotment).is_equal(GameSettings.KUDOS_AUTO)
