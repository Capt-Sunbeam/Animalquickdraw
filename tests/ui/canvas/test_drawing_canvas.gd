class_name TestDrawingCanvas
extends GdUnitTestSuite
## Headless drive of the DrawingCanvas component (Slice 1 §11 integration):
## strokes/fill/undo/clear/rotate mutate doc + raster consistently. Input
## mapping itself (mouse -> internal coords) is covered by owner playtest;
## these tests drive the internal seams with internal coordinates directly.

const CANVAS_SCENE: PackedScene = preload("res://ui/canvas/drawing_canvas.tscn")

var _canvas: DrawingCanvas


func before_test() -> void:
	_canvas = auto_free(CANVAS_SCENE.instantiate())
	add_child(_canvas)


func test_stroke_flow_commits_one_op_with_decimation() -> void:
	var committed: Array[int] = []
	_canvas.op_committed.connect(func(idx: int) -> void: committed.append(idx))
	_canvas._stroke_begin(Vector2(100.0, 100.0))
	_canvas._stroke_extend(Vector2(150.0, 150.0))
	_canvas._stroke_extend(Vector2(151.0, 151.0))  # < 2 px from last -> decimated
	_canvas._stroke_end(Vector2(200.0, 200.0))
	assert_int(_canvas.get_doc().ops.size()).is_equal(1)
	var stroke: Stroke = _canvas.get_doc().ops[0]
	assert_int(stroke.points.size()).is_equal(3)
	assert_array(committed).is_equal([0])


func test_click_without_drag_is_a_one_point_dot() -> void:
	_canvas._stroke_begin(Vector2(400.0, 300.0))
	_canvas._stroke_end(Vector2(400.0, 300.0))
	var stroke: Stroke = _canvas.get_doc().ops[0]
	assert_int(stroke.points.size()).is_equal(1)


func test_fill_commits_fill_op_at_clicked_pixel() -> void:
	_canvas._fill_at(Vector2(123.7, 88.2))
	var ops: Array[DrawingOp] = _canvas.get_doc().ops
	assert_int(ops.size()).is_equal(1)
	var fill: FillOp = ops[0]
	assert_int(fill.x).is_equal(123)
	assert_int(fill.y).is_equal(88)


func test_clear_is_recorded_as_an_op() -> void:
	_canvas._press_clear()
	assert_int(_canvas.get_doc().ops.size()).is_equal(1)
	assert_int(_canvas.get_doc().ops[0].type).is_equal(DrawingOp.Type.CLEAR)


func test_undo_pops_any_op_type_and_rerasters() -> void:
	var blank_hash: String = DocRasterizer.image_hash(_canvas._raster)
	_canvas._stroke_begin(Vector2(100.0, 100.0))
	_canvas._stroke_end(Vector2(300.0, 300.0))
	_canvas._fill_at(Vector2(50.0, 50.0))
	var undone: Array[int] = []
	_canvas.op_undone.connect(func(remaining: int) -> void: undone.append(remaining))
	_canvas._press_undo()  # pops the fill
	assert_int(_canvas.get_doc().ops.size()).is_equal(1)
	_canvas._press_undo()  # pops the stroke
	assert_int(_canvas.get_doc().ops.size()).is_equal(0)
	assert_array(undone).is_equal([1, 0])
	assert_str(DocRasterizer.image_hash(_canvas._raster)).is_equal(blank_hash)


func test_undo_on_empty_doc_is_silent_noop() -> void:
	_canvas._press_undo()
	assert_int(_canvas.get_doc().ops.size()).is_equal(0)


func test_rotate_with_empty_canvas_flips_instantly() -> void:
	var orientations: Array[StringName] = []
	_canvas.orientation_changed.connect(func(o: StringName) -> void: orientations.append(o))
	_canvas._press_rotate()
	assert_that(_canvas.current_orientation()).is_equal(DrawingDoc.ORIENTATION_PORTRAIT)
	assert_array(orientations).is_equal([DrawingDoc.ORIENTATION_PORTRAIT])
	assert_that(_canvas.get_doc().canvas_size()).is_equal(GameConstants.CANVAS_PORTRAIT)


func test_rotate_with_ops_requires_confirmation_then_wipes() -> void:
	_canvas._stroke_begin(Vector2(100.0, 100.0))
	_canvas._stroke_end(Vector2(300.0, 300.0))
	_canvas._press_rotate()
	# Ops survive until confirmation.
	assert_int(_canvas.get_doc().ops.size()).is_equal(1)
	assert_that(_canvas.current_orientation()).is_equal(DrawingDoc.ORIENTATION_LANDSCAPE)
	_canvas._confirm_rotate()
	assert_int(_canvas.get_doc().ops.size()).is_equal(0)
	assert_that(_canvas.current_orientation()).is_equal(DrawingDoc.ORIENTATION_PORTRAIT)


func test_save_toggle_off_by_default_and_signals() -> void:
	assert_bool(_canvas.save_to_collection).is_false()
	var toggles: Array[bool] = []
	_canvas.save_toggle_changed.connect(func(enabled: bool) -> void: toggles.append(enabled))
	_canvas._save_toggle.button_pressed = true
	assert_bool(_canvas.save_to_collection).is_true()
	assert_array(toggles).is_equal([true])


func test_get_doc_commits_in_progress_stroke() -> void:
	_canvas._stroke_begin(Vector2(10.0, 10.0))
	_canvas._stroke_extend(Vector2(60.0, 60.0))
	var doc: DrawingDoc = _canvas.get_doc()
	assert_int(doc.ops.size()).is_equal(1)


func test_serialize_load_into_second_canvas_identical_raster() -> void:
	_canvas._stroke_begin(Vector2(100.0, 100.0))
	_canvas._stroke_extend(Vector2(300.0, 250.0))
	_canvas._stroke_end(Vector2(500.0, 120.0))
	_canvas._fill_at(Vector2(700.0, 500.0))
	var json_text: String = JSON.stringify(_canvas.get_doc().to_dict())
	var second: DrawingCanvas = auto_free(CANVAS_SCENE.instantiate())
	add_child(second)
	var parsed: DrawingDoc = DrawingDoc.from_dict(JSON.parse_string(json_text))
	assert_object(parsed).is_not_null()
	second.load_doc(parsed)
	assert_str(DocRasterizer.image_hash(second._raster)) \
		.is_equal(DocRasterizer.image_hash(_canvas._raster))


func test_begin_drawing_resets_doc_and_keeps_orientation() -> void:
	_canvas._press_rotate()  # empty -> portrait
	_canvas._stroke_begin(Vector2(10.0, 10.0))
	_canvas._stroke_end(Vector2(50.0, 50.0))
	_canvas.begin_drawing()
	assert_int(_canvas.get_doc().ops.size()).is_equal(0)
	assert_that(_canvas.current_orientation()).is_equal(DrawingDoc.ORIENTATION_PORTRAIT)


func test_set_tools_enabled_false_blocks_actions() -> void:
	_canvas.set_tools_enabled(false)
	_canvas._press_clear()
	assert_int(_canvas.get_doc().ops.size()).is_equal(0)


func test_max_points_cap_splits_stroke() -> void:
	_canvas._stroke_begin(Vector2(0.0, 0.0))
	# Feed points 3 px apart; wrap across rows so they stay in bounds.
	var needed: int = GameConstants.STROKE_MAX_POINTS + 10
	for i: int in needed:
		@warning_ignore("integer_division")
		var p := Vector2(float((i * 3) % 780) + 5.0, float(((i * 3) / 780) * 4 % 580) + 5.0)
		_canvas._stroke_extend(p)
	_canvas._stroke_end(Vector2(790.0, 590.0))
	# The cap forces at least one mid-drag commit -> more than one op.
	assert_bool(_canvas.get_doc().ops.size() >= 2).is_true()
	for op: DrawingOp in _canvas.get_doc().ops:
		var stroke: Stroke = op
		assert_bool(stroke.points.size() <= GameConstants.STROKE_MAX_POINTS).is_true()
