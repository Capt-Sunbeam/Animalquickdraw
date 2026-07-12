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


# --- Slice 16: drag-to-place text (driven via the _commit_text_at seam) ---


func test_text_commit_appends_op_and_stamps_raster() -> void:
	var committed: Array[int] = []
	_canvas.op_committed.connect(func(idx: int) -> void: committed.append(idx))
	_canvas._text_input.text = "MOO"
	_canvas._commit_text_at(Vector2i(100, 200))
	var ops: Array[DrawingOp] = _canvas.get_doc().ops
	assert_int(ops.size()).is_equal(1)
	var op: TextOp = ops[0]
	assert_str(op.text).is_equal("MOO")
	assert_int(op.x).is_equal(100)
	assert_int(op.y).is_equal(200)
	assert_array(committed).is_equal([0])
	# The raster matches a from-scratch rasterize of the doc (same blit path).
	assert_str(DocRasterizer.image_hash(_canvas._raster)) \
		.is_equal(DocRasterizer.image_hash(DocRasterizer.rasterize(_canvas.get_doc())))


func test_text_commit_censors_like_the_host() -> void:
	TextFilter.configure(PackedStringArray(["sock"]))
	_canvas._text_input.text = "nice sock"
	_canvas._commit_text_at(Vector2i(50, 50))
	TextFilter.configure(PackedStringArray())
	var op: TextOp = _canvas.get_doc().ops[0]
	assert_str(op.text).is_equal("nice %s" % TextFilter.CENSOR_TEXT)


func test_text_unsupported_chars_filtered_at_commit() -> void:
	_canvas._text_input.text = "café ok"
	_canvas._commit_text_at(Vector2i(50, 50))
	var op: TextOp = _canvas.get_doc().ops[0]
	assert_str(op.text).is_equal("caf ok")


func test_empty_text_commit_is_a_noop() -> void:
	_canvas._text_input.text = ""
	_canvas._commit_text_at(Vector2i(50, 50))
	assert_int(_canvas.get_doc().ops.size()).is_equal(0)


func test_repeat_stamps_keep_text_in_box() -> void:
	_canvas._text_input.text = "HA"
	_canvas._commit_text_at(Vector2i(50, 50))
	_canvas._commit_text_at(Vector2i(150, 50))
	_canvas._commit_text_at(Vector2i(250, 50))
	assert_int(_canvas.get_doc().ops.size()).is_equal(3)
	assert_str(_canvas._text_input.text).is_equal("HA")


func test_drop_anchor_centers_text_on_cursor_and_clamps() -> void:
	# Internal-coordinate seam (display mapping needs a laid-out viewport).
	var anchor: Vector2i = _canvas._anchor_for_internal(Vector2(400.0, 300.0), "HI")
	var scale: int = GameConstants.TEXT_SCALES[_canvas._current_size_index]
	@warning_ignore("integer_division")
	var half_w: int = 2 * GameConstants.TEXT_GLYPH_PX * scale / 2
	@warning_ignore("integer_division")
	var half_h: int = GameConstants.TEXT_GLYPH_PX * scale / 2
	assert_int(anchor.x).is_equal(400 - half_w)
	assert_int(anchor.y).is_equal(300 - half_h)
	# A corner drop clamps into canvas.
	var corner: Vector2i = _canvas._anchor_for_internal(Vector2.ZERO, "HI")
	assert_int(corner.x).is_equal(0)
	assert_int(corner.y).is_equal(0)


func test_undo_removes_committed_text_op() -> void:
	var blank_hash: String = DocRasterizer.image_hash(_canvas._raster)
	_canvas._text_input.text = "oops"
	_canvas._commit_text_at(Vector2i(50, 50))
	_canvas._press_undo()
	assert_int(_canvas.get_doc().ops.size()).is_equal(0)
	assert_str(DocRasterizer.image_hash(_canvas._raster)).is_equal(blank_hash)


func test_text_round_trips_through_wire_format() -> void:
	_canvas._text_input.text = "wire safe!"
	_canvas._commit_text_at(Vector2i(300, 400))
	var json_text: String = JSON.stringify(_canvas.get_doc().to_dict())
	var parsed: DrawingDoc = DrawingDoc.from_dict(JSON.parse_string(json_text))
	assert_object(parsed).is_not_null()
	assert_str((parsed.ops[0] as TextOp).text).is_equal("wire safe!")


func test_chip_appears_with_text_and_hides_when_locked() -> void:
	assert_bool(_canvas._text_chip.visible).is_false()
	_canvas._text_input.text = "chip"
	_canvas._refresh_text_chip()
	assert_bool(_canvas._text_chip.visible).is_true()
	_canvas.set_tools_enabled(false)
	assert_bool(_canvas._text_chip.visible).is_false()
	assert_bool(_canvas._text_input.editable).is_false()


# --- Slice 16: eraser (a background-color stroke) ---


func test_eraser_strokes_paint_background_color_index() -> void:
	_canvas._current_tool = CanvasToolbar.Tool.ERASER
	_canvas._stroke_begin(Vector2(100.0, 100.0))
	_canvas._stroke_end(Vector2(200.0, 200.0))
	var stroke: Stroke = _canvas.get_doc().ops[0]
	assert_int(stroke.color_index).is_equal(Palette.ERASE_COLOR_INDEX)
	# The palette selection is untouched - switching back to brush paints
	# the previously selected color.
	_canvas._current_tool = CanvasToolbar.Tool.BRUSH
	_canvas._stroke_begin(Vector2(300.0, 300.0))
	_canvas._stroke_end(Vector2(310.0, 310.0))
	var brush_stroke: Stroke = _canvas.get_doc().ops[1]
	assert_int(brush_stroke.color_index).is_equal(Palette.DEFAULT_COLOR_INDEX)


func test_eraser_over_stroke_restores_background_pixels() -> void:
	_canvas._current_tool = CanvasToolbar.Tool.BRUSH
	_canvas._stroke_begin(Vector2(400.0, 300.0))
	_canvas._stroke_end(Vector2(400.0, 300.0))   # black dot
	assert_str(_canvas._raster.get_pixel(400, 300).to_html()).is_equal(Color.BLACK.to_html())
	_canvas._current_tool = CanvasToolbar.Tool.ERASER
	_canvas._current_size_index = 2   # big eraser covers the dot
	_canvas._stroke_begin(Vector2(400.0, 300.0))
	_canvas._stroke_end(Vector2(400.0, 300.0))
	assert_str(_canvas._raster.get_pixel(400, 300).to_html()) \
		.is_equal(Palette.CANVAS_BACKGROUND.to_html())


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


# --- Slice 18: display zoom/pan math + hold-to-draw source rules ---


func test_zoom_clamps_to_valid_range() -> void:
	assert_float(DrawingCanvas.clamp_zoom(0.25)).is_equal(1.0)
	assert_float(DrawingCanvas.clamp_zoom(3.0)).is_equal(3.0)
	assert_float(DrawingCanvas.clamp_zoom(99.0)).is_equal(GameConstants.CANVAS_ZOOM_MAX)


func test_pan_clamp_collapses_at_fit_and_ranges_when_zoomed() -> void:
	var view := Vector2(800.0, 600.0)
	# At fit the range collapses: panning is structurally impossible.
	assert_that(DrawingCanvas.clamp_pan(Vector2(-500.0, 37.0), view, 1.0)).is_equal(Vector2.ZERO)
	# At 2x the scaled view doubles: valid pan is [-view, 0] per axis.
	assert_that(DrawingCanvas.clamp_pan(Vector2(-9999.0, 10.0), view, 2.0)) \
		.is_equal(Vector2(-800.0, 0.0))
	assert_that(DrawingCanvas.clamp_pan(Vector2(-100.0, -550.0), view, 2.0)) \
		.is_equal(Vector2(-100.0, -550.0))


func test_map_at_fit_is_the_legacy_letterbox_map() -> void:
	# Zoom off = Slice 1 behavior, exactly (regression pin).
	var container := Vector2(900.0, 675.0)
	var internal := Vector2(800.0, 600.0)
	var p := Vector2(450.0, 337.5)
	var mapped: Vector2 = DrawingCanvas.map_display_to_internal(
			p, container, internal, 1.0, Vector2.ZERO)
	assert_that(mapped).is_equal(p * (internal / container))


func test_zoom_at_cursor_keeps_canvas_point_fixed() -> void:
	var container := Vector2(800.0, 600.0)
	var internal := Vector2(800.0, 600.0)
	var cursor := Vector2(200.0, 150.0)
	var before: Vector2 = DrawingCanvas.map_display_to_internal(
			cursor, container, internal, 1.0, Vector2.ZERO)
	var new_pan: Vector2 = DrawingCanvas.pan_after_zoom(cursor, Vector2.ZERO, 1.0, 2.0)
	new_pan = DrawingCanvas.clamp_pan(new_pan, container, 2.0)
	var after: Vector2 = DrawingCanvas.map_display_to_internal(
			cursor, container, internal, 2.0, new_pan)
	assert_that(after).is_equal(before)


func test_view_resets_on_begin_drawing_and_load_doc() -> void:
	_canvas._zoom = 3.0
	_canvas._pan = Vector2(-50.0, -40.0)
	_canvas.begin_drawing()
	assert_float(_canvas._zoom).is_equal(1.0)
	assert_that(_canvas._pan).is_equal(Vector2.ZERO)
	_canvas._zoom = 2.0
	_canvas.load_doc(DrawingDoc.new())
	assert_float(_canvas._zoom).is_equal(1.0)


func test_key_stroke_ignores_mouse_release() -> void:
	_canvas._stroke_from_key = true
	_canvas._stroke_begin(Vector2(100.0, 100.0))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	_canvas._input(release)
	assert_int(_canvas._input_state).is_equal(DrawingCanvas.InputState.STROKING)
	assert_object(_canvas._live_stroke).is_not_null()
	_canvas._end_stroke_at_last_point()  # clean up for the next test


func test_mouse_stroke_ignores_draw_hold_release() -> void:
	_canvas._stroke_from_key = false
	_canvas._stroke_begin(Vector2(100.0, 100.0))
	var key_release := InputEventKey.new()
	key_release.physical_keycode = KEY_D
	key_release.pressed = false
	_canvas._unhandled_key_input(key_release)
	assert_int(_canvas._input_state).is_equal(DrawingCanvas.InputState.STROKING)
	assert_object(_canvas._live_stroke).is_not_null()
	_canvas._end_stroke_at_last_point()


func test_draw_hold_release_ends_key_stroke() -> void:
	_canvas._stroke_from_key = true
	_canvas._stroke_begin(Vector2(100.0, 100.0))
	var key_release := InputEventKey.new()
	key_release.physical_keycode = KEY_D
	key_release.pressed = false
	_canvas._unhandled_key_input(key_release)
	assert_int(_canvas._input_state).is_equal(DrawingCanvas.InputState.IDLE)
	assert_int(_canvas.get_doc().ops.size()).is_equal(1)


func test_process_fallback_is_source_aware() -> void:
	# A key-held stroke survives frames with no mouse button down...
	_canvas._stroke_from_key = true
	_canvas._stroke_begin(Vector2(100.0, 100.0))
	Input.action_press("draw_hold")
	await await_idle_frame()
	assert_int(_canvas._input_state).is_equal(DrawingCanvas.InputState.STROKING)
	# ...and the fallback lifts the pen when the action goes slack.
	Input.action_release("draw_hold")
	await await_idle_frame()
	assert_int(_canvas._input_state).is_equal(DrawingCanvas.InputState.IDLE)
	assert_int(_canvas.get_doc().ops.size()).is_equal(1)


# --- Slice 18 rework (2026-07-10): minimap navigation + D-as-click ---


func test_minimap_view_rect_math() -> void:
	var view := Vector2(800.0, 600.0)
	# Fit: the whole canvas is the view.
	assert_that(CanvasMinimap.view_rect_frac(1.0, Vector2.ZERO, view)) \
		.is_equal(Rect2(0.0, 0.0, 1.0, 1.0))
	# 2x, panned to the exact middle: a half-size window starting at 25%.
	assert_that(CanvasMinimap.view_rect_frac(2.0, Vector2(-400.0, -300.0), view)) \
		.is_equal(Rect2(0.25, 0.25, 0.5, 0.5))


func test_center_view_on_fraction_moves_pan() -> void:
	_canvas._zoom = 2.0
	_canvas._center_view_on_fraction(Vector2(0.5, 0.5))
	# Center of the drawing at view center: pan = view/2 - 0.5 * view * 2
	# = -view/2 (then clamped by layout - in range at 2x).
	var view: Vector2 = _canvas._viewport_box.size
	assert_that(_canvas._pan).is_equal(
			DrawingCanvas.clamp_pan(-view * 0.5, view, 2.0))


func test_minimap_hidden_at_fit_visible_zoomed() -> void:
	_canvas._minimap.set_view(1.0, Vector2.ZERO, Vector2(800.0, 600.0))
	assert_bool(_canvas._minimap.visible).is_false()
	_canvas._minimap.set_view(2.0, Vector2.ZERO, Vector2(800.0, 600.0))
	assert_bool(_canvas._minimap.visible).is_true()


func test_key_click_presses_the_button_under_the_pointer() -> void:
	# The D-as-click synthesis: a click pair at the Clear button's center
	# must run the ordinary button path (ClearOp appended).
	_canvas.size = Vector2(1000.0, 760.0)
	await await_idle_frame()
	var clear_button: Button = _canvas._toolbar._clear_button
	_canvas._key_click_at(clear_button.get_global_rect().get_center())
	await await_idle_frame()
	assert_int(_canvas.get_doc().ops.size()).is_equal(1)
	assert_int(_canvas.get_doc().ops[0].type).is_equal(DrawingOp.Type.CLEAR)


func test_key_draw_yields_to_controls_floating_over_the_canvas() -> void:
	# Owner find (2026-07-12): the expanded palette overlay floats over the
	# canvas rect, so the geometric test alone inked under it instead of
	# clicking the hovered swatch. The hover cross-check must yield to any
	# control that isn't the canvas viewport box or one of its children.
	assert_bool(_canvas._hover_allows_canvas(null)).is_true()   # headless fallback
	assert_bool(_canvas._hover_allows_canvas(_canvas._viewport_box)).is_true()
	assert_bool(_canvas._hover_allows_canvas(_canvas._minimap)).is_true()   # canvas child
	var overlay := PanelContainer.new()   # stand-in for the palette overlay
	add_child(overlay)
	assert_bool(_canvas._hover_allows_canvas(overlay)).is_false()
	remove_child(overlay)
	overlay.free()
