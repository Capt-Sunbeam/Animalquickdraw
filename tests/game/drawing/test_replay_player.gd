class_name TestReplayPlayer
extends GdUnitTestSuite
## Replay schedule + determinism (Slice 1 §11). The replay end-state must be
## bit-identical to DocRasterizer.rasterize(doc).

const FRAME: float = 1.0 / 60.0


func _run_to_end(player: ReplayPlayer, step: float = FRAME, max_steps: int = 100000) -> float:
	var elapsed: float = 0.0
	var steps: int = 0
	while player.advance(step):
		elapsed += step
		steps += 1
		if steps > max_steps:
			fail("replay never finished")
			return elapsed
	return elapsed + step


func test_end_state_hash_matches_rasterize_for_every_golden() -> void:
	var docs: Dictionary = GoldenDocs.all()
	for doc_name: String in docs:
		var doc: DrawingDoc = docs[doc_name]
		var player := ReplayPlayer.new()
		player.load_doc(doc, 2.0)
		_run_to_end(player)
		assert_str(DocRasterizer.image_hash(player.get_image())) \
			.override_failure_message("replay end-state differs from rasterize for '%s'" % doc_name) \
			.is_equal(DocRasterizer.image_hash(DocRasterizer.rasterize(doc)))


func test_thirty_second_doc_finishes_within_cap_at_speed_one() -> void:
	var doc := DrawingDoc.new()
	var points: Array = []
	for i: int in 31:
		points.append(Vector2(50.0 + i * 20.0, 300.0))
	doc.ops.append(GoldenDocs.make_stroke(4, 1, points, 0.0, 1.0))  # 30 s natural
	var player := ReplayPlayer.new()
	player.load_doc(doc, 1.0)
	var wall: float = _run_to_end(player)
	assert_float(wall).is_less_equal(GameConstants.REPLAY_MAX_DURATION_SEC + FRAME * 2.0)


func test_idle_gap_compressed_to_max_gap() -> void:
	var doc := DrawingDoc.new()
	doc.ops.append(GoldenDocs.make_stroke(4, 0, [Vector2(10.0, 10.0), Vector2(20.0, 20.0)], 0.0, 1.0))
	doc.ops.append(GoldenDocs.make_stroke(4, 0, [Vector2(30.0, 30.0), Vector2(40.0, 40.0)], 21.0, 1.0))
	var player := ReplayPlayer.new()
	player.load_doc(doc, 1.0)
	# Natural: op1 spans 0-1, 20 s idle, op2 spans 21-22. Compressed: gap
	# clamps to REPLAY_MAX_OP_GAP_SEC -> total = 1 + 1 + 1 = 3 s.
	assert_float(player.get_total_duration()).is_equal_approx(3.0, 0.01)


func test_leading_dead_time_compressed() -> void:
	var doc := DrawingDoc.new()
	doc.ops.append(GoldenDocs.make_stroke(4, 0, [Vector2(10.0, 10.0), Vector2(20.0, 20.0)], 15.0, 1.0))
	var player := ReplayPlayer.new()
	player.load_doc(doc, 1.0)
	# 15 s of dead time before the first op clamps to the max gap (1 s).
	assert_float(player.get_total_duration()).is_equal_approx(2.0, 0.01)


func test_non_stroke_ops_consume_nominal_duration() -> void:
	var doc := DrawingDoc.new()
	doc.ops.append(GoldenDocs.make_fill(7, 10, 10))
	doc.ops.append(ClearOp.new())
	var player := ReplayPlayer.new()
	player.load_doc(doc, 1.0)
	assert_float(player.get_total_duration()) \
		.is_equal_approx(GameConstants.REPLAY_NON_STROKE_OP_SEC * 2.0, 0.001)


func test_op_started_fires_once_per_op_in_order() -> void:
	var doc: DrawingDoc = GoldenDocs.stroke_clear_stroke()
	var player := ReplayPlayer.new()
	var started: Array[int] = []
	player.op_started.connect(func(idx: int) -> void: started.append(idx))
	player.load_doc(doc, 4.0)
	_run_to_end(player)
	assert_array(started).is_equal([0, 1, 2])


func test_empty_doc_finishes_on_first_advance() -> void:
	var doc := DrawingDoc.new()
	var player := ReplayPlayer.new()
	var finished_count: Array[int] = [0]
	player.finished.connect(func() -> void: finished_count[0] += 1)
	player.load_doc(doc, 1.0)
	assert_bool(player.advance(FRAME)).is_false()
	assert_int(finished_count[0]).is_equal(1)
	assert_str(DocRasterizer.image_hash(player.get_image())) \
		.is_equal(DocRasterizer.image_hash(DocRasterizer.rasterize(doc)))


func test_skip_to_end_matches_final_raster_from_partway() -> void:
	var doc: DrawingDoc = GoldenDocs.multi_stroke()
	var player := ReplayPlayer.new()
	player.load_doc(doc, 1.0)
	# Advance partway (mid-first-stroke), then skip.
	player.advance(0.05)
	player.advance(0.05)
	player.skip_to_end()
	assert_str(DocRasterizer.image_hash(player.get_image())) \
		.is_equal(DocRasterizer.image_hash(DocRasterizer.rasterize(doc)))


func test_skip_to_end_emits_finished_once() -> void:
	var doc: DrawingDoc = GoldenDocs.dots()
	var player := ReplayPlayer.new()
	var finished_count: Array[int] = [0]
	player.finished.connect(func() -> void: finished_count[0] += 1)
	player.load_doc(doc, 1.0)
	player.skip_to_end()
	player.skip_to_end()
	assert_bool(player.advance(FRAME)).is_false()
	assert_int(finished_count[0]).is_equal(1)


func test_rate_respects_requested_speed_when_under_cap() -> void:
	var doc := DrawingDoc.new()
	doc.ops.append(GoldenDocs.make_stroke(4, 0, [Vector2(10.0, 10.0), Vector2(20.0, 20.0)], 0.0, 2.0))  # 2 s natural
	var player := ReplayPlayer.new()
	player.load_doc(doc, 4.0)
	# D = 2 s, cap rate = 2/10 = 0.2 -> requested 4.0 wins.
	assert_float(player.get_rate()).is_equal_approx(4.0, 0.001)
