class_name TestCanvasScenes
extends GdUnitTestSuite
## Scene smoke tests (consistency guide §9): every Slice 1 scene
## instantiates into the tree without errors.


func test_drawing_canvas_scene_smokes() -> void:
	var canvas: DrawingCanvas = auto_free(load("res://ui/canvas/drawing_canvas.tscn").instantiate())
	add_child(canvas)
	await await_idle_frame()
	assert_object(canvas.get_doc()).is_not_null()


func test_canvas_toolbar_scene_smokes() -> void:
	var toolbar: CanvasToolbar = auto_free(load("res://ui/canvas/canvas_toolbar.tscn").instantiate())
	add_child(toolbar)
	await await_idle_frame()
	assert_object(toolbar).is_not_null()


func test_palette_picker_scene_smokes() -> void:
	var picker: PalettePicker = auto_free(load("res://ui/canvas/palette_picker.tscn").instantiate())
	add_child(picker)
	await await_idle_frame()
	assert_int(picker.get_current_index()).is_equal(Palette.DEFAULT_COLOR_INDEX)


func test_confirm_dialog_scene_smokes() -> void:
	var dialog: ConfirmDialog = auto_free(load("res://ui/shared/confirm_dialog.tscn").instantiate())
	add_child(dialog)
	await await_idle_frame()
	assert_object(dialog).is_not_null()


func test_canvas_sandbox_screen_smokes() -> void:
	var screen: Control = auto_free(load("res://ui/canvas/canvas_sandbox_screen.tscn").instantiate())
	add_child(screen)
	await await_idle_frame()
	assert_object(screen).is_not_null()


func test_toolbar_signals_fire_with_payloads() -> void:
	var toolbar: CanvasToolbar = auto_free(load("res://ui/canvas/canvas_toolbar.tscn").instantiate())
	add_child(toolbar)
	await await_idle_frame()
	var sizes: Array[int] = []
	var tools: Array[int] = []
	var clicks: Array[String] = []
	toolbar.size_selected.connect(func(idx: int) -> void: sizes.append(idx))
	toolbar.tool_selected.connect(func(tool: CanvasToolbar.Tool) -> void: tools.append(tool))
	toolbar.undo_pressed.connect(func() -> void: clicks.append("undo"))
	toolbar.clear_pressed.connect(func() -> void: clicks.append("clear"))
	toolbar.rotate_pressed.connect(func() -> void: clicks.append("rotate"))
	toolbar.zoom_in_pressed.connect(func() -> void: clicks.append("zoom_in"))
	toolbar.zoom_out_pressed.connect(func() -> void: clicks.append("zoom_out"))
	toolbar.zoom_reset_pressed.connect(func() -> void: clicks.append("zoom_reset"))
	toolbar._size_buttons[2].pressed.emit()
	toolbar._fill_button.pressed.emit()
	toolbar._eraser_button.pressed.emit()   # Slice 16
	toolbar._undo_button.pressed.emit()
	toolbar._clear_button.pressed.emit()
	toolbar._rotate_button.pressed.emit()
	toolbar._zoom_in_button.pressed.emit()   # Slice 18
	toolbar._zoom_out_button.pressed.emit()
	toolbar._zoom_label_button.pressed.emit()
	assert_array(sizes).is_equal([2])
	assert_array(tools).is_equal([CanvasToolbar.Tool.FILL, CanvasToolbar.Tool.ERASER])
	assert_array(clicks).is_equal(["undo", "clear", "rotate", "zoom_in", "zoom_out", "zoom_reset"])


func test_palette_selection_emits_index() -> void:
	var picker: PalettePicker = auto_free(load("res://ui/canvas/palette_picker.tscn").instantiate())
	add_child(picker)
	await await_idle_frame()
	var selected: Array[int] = []
	picker.color_selected.connect(func(idx: int) -> void: selected.append(idx))
	picker.select_index(Palette.base_index(6))  # blue family base
	assert_array(selected).is_equal([Palette.base_index(6)])
	assert_int(picker.get_current_index()).is_equal(Palette.base_index(6))


func test_toolbar_zoom_display_formats_percent() -> void:
	var toolbar: CanvasToolbar = auto_free(load("res://ui/canvas/canvas_toolbar.tscn").instantiate())
	add_child(toolbar)
	await await_idle_frame()
	toolbar.set_zoom_display(1.5)
	assert_str(toolbar._zoom_label_button.text).is_equal("150%")
	toolbar.set_zoom_display(8.0)
	assert_str(toolbar._zoom_label_button.text).is_equal("800%")
