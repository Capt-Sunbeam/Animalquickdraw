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


# --- Slice 6: lock rule, presets, freeze/snapshot, versioning ---


func test_lock_rule_preset_allows_only_always_three() -> void:
	var s := GameSettings.new()   # mode DEFAULT (a preset)
	assert_bool(s.set_value(&"draw_time_sec", 60.0)).is_true()
	assert_bool(s.set_value(&"round_count", 10)).is_true()
	assert_bool(s.set_value(&"pool_source", GameSettings.PoolSource.BUILT_IN)).is_true()
	assert_bool(s.set_value(&"judging_window_sec", 40.0)).is_false()
	assert_bool(s.set_value(&"replay_mode", GameSettings.ReplayMode.FULL)).is_false()
	assert_bool(s.set_value(&"title_points_enabled", false)).is_false()
	assert_float(s.judging_window_sec).is_equal(25.0)   # untouched


func test_custom_unlocks_full_surface_incl_title_points() -> void:
	var s := GameSettings.new()
	s.apply_preset(SettingsDefaults.Mode.CUSTOM)
	assert_bool(s.set_value(&"judging_window_sec", 40.0)).is_true()
	assert_bool(s.set_value(&"title_points_enabled", false)).is_true()
	assert_bool(s.set_value(&"kudos_allotment", 5)).is_true()
	assert_float(s.judging_window_sec).is_equal(40.0)
	assert_bool(s.title_points_enabled).is_false()
	assert_bool(s.is_locked(&"reveal_style")).is_false()


func test_title_points_locked_in_all_presets() -> void:
	for mode: int in [SettingsDefaults.Mode.DEFAULT, SettingsDefaults.Mode.STREAMLINED,
			SettingsDefaults.Mode.SOCIAL]:
		var s := GameSettings.new()
		s.apply_preset(mode)
		assert_bool(s.is_locked(&"title_points_enabled")).is_true()


func test_apply_preset_preserves_always_three_except_draw_time() -> void:
	var s := GameSettings.new()
	s.set_value(&"round_count", 12)
	s.set_value(&"draw_time_sec", 90.0)
	s.apply_preset(SettingsDefaults.Mode.STREAMLINED)
	assert_int(s.round_count).is_equal(12)              # survives
	assert_bool(s.rounds_overridden).is_true()          # survives
	assert_float(s.draw_time_sec).is_equal(20.0)        # per-mode reset (§10)
	assert_int(s.reveal_style).is_equal(GameSettings.RevealStyle.GRID)
	assert_int(s.replay_mode).is_equal(GameSettings.ReplayMode.OFF)
	# Custom seeds from the applied (Streamlined) values, changes nothing.
	s.apply_preset(SettingsDefaults.Mode.CUSTOM)
	assert_int(s.reveal_style).is_equal(GameSettings.RevealStyle.GRID)
	assert_float(s.draw_time_sec).is_equal(20.0)


func test_snapshot_frozen_resolves_kudos_auto_and_rejects_edits() -> void:
	var s := GameSettings.new()
	s.set_value(&"round_count", 10)
	var snap: GameSettings = s.snapshot()
	assert_bool(snap.is_frozen()).is_true()
	assert_int(snap.kudos_allotment).is_equal(3)        # AUTO resolved (10 rounds)
	assert_bool(snap.set_value(&"draw_time_sec", 15.0)).is_false()
	assert_float(snap.draw_time_sec).is_equal(s.draw_time_sec)
	# Explicit allotments pass through untouched.
	var explicit := GameSettings.new()
	explicit.apply_preset(SettingsDefaults.Mode.CUSTOM)
	explicit.set_value(&"kudos_allotment", 0)
	assert_int(explicit.snapshot().kudos_allotment).is_equal(0)
	# The live object is unaffected by snapshotting.
	assert_bool(s.is_frozen()).is_false()
	assert_int(s.kudos_allotment).is_equal(GameSettings.KUDOS_AUTO)


func test_from_dict_rejects_newer_version_with_defaults() -> void:
	var d: Dictionary = GameSettings.new().to_dict()
	d["v"] = GameSettings.SETTINGS_VERSION + 1
	d["round_count"] = 19
	var s: GameSettings = GameSettings.from_dict(d)
	assert_int(s.round_count).is_equal(6)   # defaults, not the alien payload


func test_judging_window_and_kudos_clamped() -> void:
	var s := GameSettings.new()
	s.judging_window_sec = 500.0
	s.kudos_allotment = 99
	s.clamp_to_limits()
	assert_float(s.judging_window_sec).is_equal(GameConstants.JUDGING_WINDOW_MAX_SEC)
	assert_int(s.kudos_allotment).is_equal(GameConstants.KUDOS_ALLOTMENT_MAX)
	s.kudos_allotment = GameSettings.KUDOS_AUTO
	s.clamp_to_limits()
	assert_int(s.kudos_allotment).is_equal(GameSettings.KUDOS_AUTO)   # AUTO survives


func test_slice6_keys_round_trip() -> void:
	var s := GameSettings.new()
	s.apply_preset(SettingsDefaults.Mode.CUSTOM)
	s.set_value(&"judging_window_sec", 45.0)
	s.set_value(&"title_points_enabled", false)
	var back: GameSettings = GameSettings.from_dict(s.to_dict())
	assert_int(back.mode).is_equal(SettingsDefaults.Mode.CUSTOM)
	assert_float(back.judging_window_sec).is_equal(45.0)
	assert_bool(back.title_points_enabled).is_false()


func test_restore_for_lobby_reseeds_round_count() -> void:
	var old := GameSettings.new()
	old.apply_preset(SettingsDefaults.Mode.SOCIAL)
	old.set_value(&"round_count", 16)   # from an 8-player lobby
	var restored: GameSettings = GameSettings.restore_for_lobby(old.to_dict(), 3)
	assert_int(restored.mode).is_equal(SettingsDefaults.Mode.SOCIAL)   # setup kept
	assert_int(restored.round_count).is_equal(6)                       # re-seeded
	assert_bool(restored.rounds_overridden).is_false()
	assert_bool(GameSettings.restore_for_lobby({"nope": 1}, 3).round_count == 6).is_true()


func test_validate_for_start_passes_today() -> void:
	assert_int(GameSettings.new().validate_for_start(4).size()).is_equal(0)


# --- Slice 9: connectivity settings ---


func test_fluid_default_on_private_off_public_host_override_wins() -> void:
	var s := GameSettings.new()
	assert_bool(s.fluid_rejoin).is_true()            # private default: ON
	s.set_value(&"is_public", true)
	assert_bool(s.fluid_rejoin).is_false()           # public default: OFF (derived)
	s.set_value(&"is_public", false)
	assert_bool(s.fluid_rejoin).is_true()            # derivation follows the flag
	# Host touches the toggle: the derivation stops for good.
	s.set_value(&"fluid_rejoin", false)
	assert_bool(s.fluid_rejoin_overridden).is_true()
	s.set_value(&"is_public", true)
	s.set_value(&"is_public", false)
	assert_bool(s.fluid_rejoin).is_false()           # override wins over derivation


func test_connectivity_keys_never_preset_locked() -> void:
	for mode: int in [SettingsDefaults.Mode.DEFAULT, SettingsDefaults.Mode.STREAMLINED,
			SettingsDefaults.Mode.SOCIAL, SettingsDefaults.Mode.CUSTOM]:
		var s := GameSettings.new()
		s.apply_preset(mode)
		assert_bool(s.is_locked(&"is_public")).is_false()
		assert_bool(s.is_locked(&"fluid_rejoin")).is_false()
		assert_bool(s.set_value(&"is_public", true)).is_true()
		assert_bool(s.set_value(&"fluid_rejoin", true)).is_true()


func test_slice9_keys_round_trip_and_default() -> void:
	var s := GameSettings.new()
	s.set_value(&"is_public", true)
	s.set_value(&"fluid_rejoin", true)               # override while public
	var back: GameSettings = GameSettings.from_dict(s.to_dict())
	assert_bool(back.is_public).is_true()
	assert_bool(back.fluid_rejoin).is_true()
	assert_bool(back.fluid_rejoin_overridden).is_true()
	# A preset switch never resets connectivity (keys absent from presets).
	back.apply_preset(SettingsDefaults.Mode.SOCIAL)
	assert_bool(back.is_public).is_true()
	assert_bool(back.fluid_rejoin).is_true()
	# Pre-Slice-9 payloads default cleanly.
	var old: GameSettings = GameSettings.from_dict({})
	assert_bool(old.is_public).is_false()
	assert_bool(old.fluid_rejoin).is_true()
	assert_bool(old.fluid_rejoin_overridden).is_false()
