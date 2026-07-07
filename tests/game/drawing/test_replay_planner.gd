class_name TestReplayPlanner
extends GdUnitTestSuite
## Slice 5 replay math (TDD §11): caps, budget shares, gap compression,
## degenerate input, and the drift guard against ReplayPlayer's schedule.


## A doc with one stroke lasting `secs` (2 points) starting at t=0.
func _timed_doc(secs: float, start: float = 0.0) -> Dictionary:
	return {"v": 1, "orientation": "landscape", "ops": [
		{"t": "stroke", "c": 0, "s": 1, "pts": [10.0, 10.0, 400.0, 300.0],
			"ts": [start, start + secs]},
	]}


func _two_stroke_doc(gap_secs: float) -> Dictionary:
	return {"v": 1, "orientation": "landscape", "ops": [
		{"t": "stroke", "c": 0, "s": 1, "pts": [10.0, 10.0, 100.0, 100.0], "ts": [0.0, 2.0]},
		{"t": "stroke", "c": 1, "s": 1, "pts": [200.0, 200.0, 300.0, 300.0],
			"ts": [2.0 + gap_secs, 4.0 + gap_secs]},
	]}


func test_thirty_sec_drawing_fits_ten_sec_target() -> void:
	# Brief §7 example under the duration model (owner, 2026-07-06): a 30 s
	# drawing with a 10 s target replays at exactly 3x.
	var doc: Dictionary = _timed_doc(30.0)
	var ts: float = ReplayPlanner.winner_timescale(doc, 10.0)
	assert_float(ts).is_equal(3.0)
	assert_float(ReplayPlanner.replay_secs(doc, ts)).is_equal_approx(10.0, 0.001)


func test_target_equal_to_duration_is_realtime() -> void:
	# 30 s target for a 30 s drawing = realtime (owner example).
	var doc: Dictionary = _timed_doc(30.0)
	assert_float(ReplayPlanner.winner_timescale(doc, 30.0)).is_equal(1.0)
	# 5 s target = very fast.
	assert_float(ReplayPlanner.winner_timescale(doc, 5.0)).is_equal(6.0)


func test_short_drawing_never_replays_slower_than_realtime() -> void:
	var doc: Dictionary = _timed_doc(4.0)
	var ts: float = ReplayPlanner.winner_timescale(doc, 8.0)
	assert_float(ts).is_equal(1.0)   # 4 s drawing plays in 4 s, not stretched to 8
	assert_float(ReplayPlanner.replay_secs(doc, ts)).is_equal_approx(4.0, 0.001)


func test_budget_shrinks_target_with_seven_drawers() -> void:
	var doc: Dictionary = _timed_doc(60.0)
	var ts: float = ReplayPlanner.reveal_timescale(doc, 15.0, 7)
	# Effective target = min(15, 30/7 ~= 4.29 s) - the room stays snappy.
	assert_float(ReplayPlanner.replay_secs(doc, ts)).is_equal_approx(30.0 / 7.0, 0.001)


func test_reveal_target_respected_with_realtime_floor() -> void:
	# 8 s drawing, 5 s target, 3 drawers (budget share 10 s): fits the target.
	var doc: Dictionary = _timed_doc(8.0)
	var ts: float = ReplayPlanner.reveal_timescale(doc, 5.0, 3)
	assert_float(ts).is_equal_approx(1.6, 0.001)
	assert_float(ReplayPlanner.replay_secs(doc, ts)).is_equal_approx(5.0, 0.001)
	# 3 s drawing with the same target: realtime, not stretched.
	assert_float(ReplayPlanner.reveal_timescale(_timed_doc(3.0), 5.0, 3)).is_equal(1.0)


func test_idle_gaps_compressed() -> void:
	# 20 s thinking pause between strokes compresses to REPLAY_MAX_OP_GAP_SEC.
	var dur: float = ReplayPlanner.compressed_duration(_two_stroke_doc(20.0))
	assert_float(dur).is_equal_approx(2.0 + GameConstants.REPLAY_MAX_OP_GAP_SEC + 2.0, 0.001)
	# A short natural pause is kept as-is.
	var short: float = ReplayPlanner.compressed_duration(_two_stroke_doc(0.2))
	assert_float(short).is_equal_approx(4.2, 0.001)


func test_empty_doc_duration_zero() -> void:
	var doc: Dictionary = {"v": 1, "orientation": "landscape", "ops": []}
	assert_float(ReplayPlanner.compressed_duration(doc)).is_equal(0.0)
	assert_float(ReplayPlanner.reveal_timescale(doc, 4.0, 3)).is_equal(1.0)
	assert_float(ReplayPlanner.replay_secs(doc, 4.0)).is_equal(0.0)


func test_degenerate_timestamps_clamped() -> void:
	# Reversed timestamps: negative stroke duration clamps to 0 (hostile
	# client, §13); malformed docs are simply 0.
	var reversed_ts: Dictionary = {"v": 1, "orientation": "landscape", "ops": [
		{"t": "stroke", "c": 0, "s": 1, "pts": [10.0, 10.0, 20.0, 20.0], "ts": [5.0, 1.0]},
	]}
	assert_float(ReplayPlanner.compressed_duration(reversed_ts)).is_less_equal(
			GameConstants.REPLAY_MAX_OP_GAP_SEC)
	assert_float(ReplayPlanner.compressed_duration({"nope": true})).is_equal(0.0)


func test_planner_matches_player_schedule() -> void:
	# Drift guard: the host schedules beats with ReplayPlanner while clients
	# render with ReplayPlayer - their schedule math must agree exactly.
	var docs: Array[Dictionary] = [
		_timed_doc(30.0),
		_two_stroke_doc(20.0),
		_two_stroke_doc(0.2),
		{"v": 1, "orientation": "landscape", "ops": [{"t": "clear"},
			{"t": "fill", "c": 3, "x": 100, "y": 100}]},
	]
	for doc: Dictionary in docs:
		var player := ReplayPlayer.new()
		player.load_doc(DrawingDoc.from_dict(doc))
		assert_float(ReplayPlanner.compressed_duration(doc))\
				.is_equal_approx(player.get_total_duration(), 0.0001)
