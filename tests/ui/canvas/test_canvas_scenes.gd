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
	toolbar._size_buttons[2].pressed.emit()
	toolbar._fill_button.pressed.emit()
	toolbar._undo_button.pressed.emit()
	toolbar._clear_button.pressed.emit()
	toolbar._rotate_button.pressed.emit()
	assert_array(sizes).is_equal([2])
	assert_array(tools).is_equal([CanvasToolbar.Tool.FILL])
	assert_array(clicks).is_equal(["undo", "clear", "rotate"])


func test_palette_selection_emits_index() -> void:
	var picker: PalettePicker = auto_free(load("res://ui/canvas/palette_picker.tscn").instantiate())
	add_child(picker)
	await await_idle_frame()
	var selected: Array[int] = []
	picker.color_selected.connect(func(idx: int) -> void: selected.append(idx))
	picker.select_index(Palette.base_index(6))  # blue family base
	assert_array(selected).is_equal([Palette.base_index(6)])
	assert_int(picker.get_current_index()).is_equal(Palette.base_index(6))
