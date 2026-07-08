class_name TestTextDragDrop
extends GdUnitTestSuite
## Slice 16 text-chip drag & drop. Root cause of the 2026-07-07 "drop never
## lands" bug: the engine only offers drops to gui.target_control, and since
## Godot 4.5 a SubViewportContainer becomes target_control ONLY with
## mouse_target enabled (viewport.cpp _update_mouse_over) - default false.
## Headless can't drive the WM mouse-over pipeline (windowmanager_window_over
## is null), so end-to-end drop delivery is owner-verified windowed; this
## suite pins the load-bearing property and exercises the exact handler
## chain the engine invokes on a real drop.


func _laid_out_canvas(runner: GdUnitSceneRunner) -> DrawingCanvas:
	var canvas: DrawingCanvas = runner.scene()
	canvas.position = Vector2.ZERO
	canvas.size = Vector2(1000, 760)   # headless default layout is 0x0
	return canvas


func test_viewport_box_is_a_mouse_target() -> void:
	# THE regression guard: without this property the drag system never
	# offers a drop to the canvas, with zero errors anywhere.
	var runner: GdUnitSceneRunner = scene_runner("res://ui/canvas/drawing_canvas.tscn")
	var canvas: DrawingCanvas = _laid_out_canvas(runner)
	await runner.simulate_frames(1)
	assert_bool((canvas._viewport_box as SubViewportContainer).is_mouse_target_enabled()) \
		.override_failure_message("ViewportBox.mouse_target must stay true or text drops die silently") \
		.is_true()


func test_real_mouse_drag_engages_with_chip_data() -> void:
	# The drag-source half via REAL simulated input: press on the chip and
	# move - the viewport must enter drag state carrying our payload.
	var runner: GdUnitSceneRunner = scene_runner("res://ui/canvas/drawing_canvas.tscn")
	var canvas: DrawingCanvas = _laid_out_canvas(runner)
	await runner.simulate_frames(3)
	canvas._text_input.text = "MOO"
	canvas._refresh_text_chip()
	await runner.simulate_frames(2)
	var start: Vector2 = canvas._text_chip.get_global_rect().get_center()
	var target: Vector2 = canvas._viewport_box.get_global_rect().get_center()
	runner.simulate_mouse_move(start)
	await runner.await_input_processed()
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	for i: int in range(1, 11):
		runner.simulate_mouse_move(start.lerp(target, float(i) / 10.0))
		await runner.await_input_processed()
	assert_bool(canvas.get_viewport().gui_is_dragging()).is_true()
	var data: Variant = canvas.get_viewport().gui_get_drag_data()
	assert_bool(data is Dictionary and (data as Dictionary).has("aq_text_drop")).is_true()
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()


func test_drop_handler_chain_commits_text_op() -> void:
	# The drop-target half: invoke exactly what the engine calls on a real
	# drop (_can_drop_data hover query, then _drop_data) at a canvas-local
	# position, and assert the op commits where expected.
	var runner: GdUnitSceneRunner = scene_runner("res://ui/canvas/drawing_canvas.tscn")
	var canvas: DrawingCanvas = _laid_out_canvas(runner)
	await runner.simulate_frames(3)
	canvas._text_input.text = "MOO"
	canvas._refresh_text_chip()
	var box: CanvasDropTarget = canvas._viewport_box
	var local: Vector2 = box.size / 2.0
	var data: Dictionary = {"aq_text_drop": true}
	assert_bool(box._can_drop_data(local, data)).is_true()   # hover query (can-drop cursor)
	box._drop_data(local, data)
	var ops: Array[DrawingOp] = canvas.get_doc().ops
	assert_int(ops.size()).is_equal(1)
	var op: TextOp = ops[0]
	assert_str(op.text).is_equal("MOO")
	# Centered on the drop point: anchor = internal center - half text size.
	var expected: Vector2i = canvas._anchor_for_internal(Vector2(400.0, 300.0), "MOO")
	assert_int(op.x).is_equal(expected.x)
	assert_int(op.y).is_equal(expected.y)


func test_drop_rejected_when_tools_locked_or_foreign_data() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://ui/canvas/drawing_canvas.tscn")
	var canvas: DrawingCanvas = _laid_out_canvas(runner)
	await runner.simulate_frames(3)
	canvas._text_input.text = "MOO"
	var box: CanvasDropTarget = canvas._viewport_box
	assert_bool(box._can_drop_data(box.size / 2.0, {"other": 1})).is_false()
	canvas.set_tools_enabled(false)
	assert_bool(box._can_drop_data(box.size / 2.0, {"aq_text_drop": true})).is_false()
	box._drop_data(box.size / 2.0, {"aq_text_drop": true})
	assert_int(canvas.get_doc().ops.size()).is_equal(0)
