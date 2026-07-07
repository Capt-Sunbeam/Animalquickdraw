class_name TestRevealDirector
extends GdUnitTestSuite
## Slice 5 beat plan math + sequencing (TDD §11), headless. Gate behavior
## across beats is covered in TestGameSessionReveal.


func _entry(id: String, stroke_secs: float = 0.0, caption: String = "") -> Dictionary:
	var ops: Array = []
	if stroke_secs > 0.0:
		ops = [{"t": "stroke", "c": 0, "s": 1,
				"pts": [10.0, 10.0, 400.0, 300.0], "ts": [0.0, stroke_secs]}]
	return {"drawing_id": id,
			"doc": {"v": 1, "orientation": "landscape", "ops": ops},
			"caption": caption}


func _settings(replay: GameSettings.ReplayMode) -> GameSettings:
	var s := GameSettings.new()
	s.replay_mode = replay
	return s


func test_settings_defaults_match_slice5_contract() -> void:
	var s := GameSettings.new()
	assert_int(s.reveal_style).is_equal(GameSettings.RevealStyle.ONE_AT_A_TIME)
	assert_int(s.replay_mode).is_equal(GameSettings.ReplayMode.WINNER_ONLY)
	assert_float(s.reveal_replay_secs).is_equal(5.0)
	assert_float(s.winner_replay_secs).is_equal(8.0)
	assert_bool(s.comments_enabled).is_true()
	# Round-trip preserves the Slice 5 keys (wire/mirror safety).
	var copy: GameSettings = GameSettings.from_dict(s.to_dict())
	assert_int(copy.reveal_style).is_equal(s.reveal_style)
	assert_float(copy.winner_replay_secs).is_equal(s.winner_replay_secs)


func test_beat_secs_full_replay_vs_off() -> void:
	var doc: Dictionary = _entry("d", 8.0)["doc"]
	# FULL: 8 s drawing at the default 5 s target -> content = 5 s replay.
	var full: float = RevealDirector.compute_beat_secs(doc, "",
			_settings(GameSettings.ReplayMode.FULL), 3)
	assert_float(full).is_equal_approx(GameConstants.REVEAL_CARD_IN_SECS + 5.0
			+ GameConstants.REVEAL_REACT_HOLD_SECS + GameConstants.REVEAL_TO_GRID_SECS, 0.001)
	# WINNER_ONLY/OFF: content = the short fade.
	var off: float = RevealDirector.compute_beat_secs(doc, "",
			_settings(GameSettings.ReplayMode.OFF), 3)
	assert_float(off).is_equal_approx(GameConstants.REVEAL_CARD_IN_SECS
			+ GameConstants.REVEAL_SHOW_FADE_SECS
			+ GameConstants.REVEAL_REACT_HOLD_SECS + GameConstants.REVEAL_TO_GRID_SECS, 0.001)


func test_caption_step_skipped_when_empty() -> void:
	var doc: Dictionary = _entry("d")["doc"]
	var with_caption: float = RevealDirector.compute_beat_secs(doc, "it's resting",
			_settings(GameSettings.ReplayMode.OFF), 3)
	var without: float = RevealDirector.compute_beat_secs(doc, "",
			_settings(GameSettings.ReplayMode.OFF), 3)
	assert_float(with_caption - without).is_equal_approx(GameConstants.REVEAL_CAPTION_SECS, 0.001)


func test_beat_sequence_covers_all_drawings_once_then_gathers() -> void:
	var entries: Array[Dictionary] = [_entry("a"), _entry("b"), _entry("c")]
	var director := RevealDirector.new(GameSettings.RevealStyle.ONE_AT_A_TIME,
			entries, _settings(GameSettings.ReplayMode.OFF), 3)
	assert_bool(director.has_beats()).is_true()
	var seen: Array[String] = []
	for i: int in 3:
		var action: Dictionary = director.next_action()
		assert_bool(action.has("beat")).is_true()
		var beat: Dictionary = action["beat"]
		assert_int(int(beat["index"])).is_equal(i)
		seen.append(str(beat["drawing_id"]))
	assert_array(seen).contains_exactly(["a", "b", "c"])
	var gather: Dictionary = director.next_action()
	assert_float(float(gather.get("gather", 0.0))).is_equal(GameConstants.REVEAL_TO_GRID_SECS)
	assert_bool(director.is_done()).is_false()
	assert_that(director.next_action()).is_equal({})
	assert_bool(director.is_done()).is_true()


func test_grid_style_skips_beats() -> void:
	var entries: Array[Dictionary] = [_entry("a"), _entry("b")]
	var director := RevealDirector.new(GameSettings.RevealStyle.GRID,
			entries, _settings(GameSettings.ReplayMode.FULL), 2)
	assert_bool(director.has_beats()).is_false()
	assert_float(director.total_secs()).is_equal(0.0)
	assert_that(director.next_action()).is_equal({})


func test_total_secs_is_beats_plus_gather() -> void:
	var entries: Array[Dictionary] = [_entry("a"), _entry("b", 0.0, "hi")]
	var settings: GameSettings = _settings(GameSettings.ReplayMode.OFF)
	var director := RevealDirector.new(GameSettings.RevealStyle.ONE_AT_A_TIME,
			entries, settings, 2)
	var expected: float = RevealDirector.compute_beat_secs(entries[0]["doc"], "", settings, 2) \
			+ RevealDirector.compute_beat_secs(entries[1]["doc"], "hi", settings, 2) \
			+ GameConstants.REVEAL_TO_GRID_SECS
	assert_float(director.total_secs()).is_equal_approx(expected, 0.001)
