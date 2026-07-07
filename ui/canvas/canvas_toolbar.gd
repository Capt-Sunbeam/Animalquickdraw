class_name CanvasToolbar
extends HBoxContainer
## Canvas tool strip (Slice 1 §7; Slice 16 update 2026-07-07: Eraser tool
## added, Text moved to the drag-chip row on DrawingCanvas): 3 brush sizes
## (shared by brush radius and text scale), brush/fill/eraser tool toggle,
## undo, clear, rotate. Min click targets 32x32 (cg §13).

signal size_selected(size_index: int)
signal tool_selected(tool: Tool)
signal undo_pressed()
signal clear_pressed()
signal rotate_pressed()

enum Tool { BRUSH, FILL, ERASER }

@onready var _size_buttons: Array[Button] = [%SizeSmall, %SizeMedium, %SizeLarge]
@onready var _brush_button: Button = %BrushButton
@onready var _fill_button: Button = %FillButton
@onready var _eraser_button: Button = %EraserButton
@onready var _undo_button: Button = %UndoButton
@onready var _clear_button: Button = %ClearButton
@onready var _rotate_button: Button = %RotateButton

var _size_group := ButtonGroup.new()
var _tool_group := ButtonGroup.new()


func _ready() -> void:
	for i: int in _size_buttons.size():
		var btn: Button = _size_buttons[i]
		btn.toggle_mode = true
		btn.button_group = _size_group
		btn.pressed.connect(_on_size_pressed.bind(i))
	_brush_button.toggle_mode = true
	_fill_button.toggle_mode = true
	_eraser_button.toggle_mode = true
	_brush_button.button_group = _tool_group
	_fill_button.button_group = _tool_group
	_eraser_button.button_group = _tool_group
	_brush_button.pressed.connect(func() -> void: tool_selected.emit(Tool.BRUSH))
	_fill_button.pressed.connect(func() -> void: tool_selected.emit(Tool.FILL))
	_eraser_button.pressed.connect(func() -> void: tool_selected.emit(Tool.ERASER))
	_undo_button.pressed.connect(func() -> void: undo_pressed.emit())
	_clear_button.pressed.connect(func() -> void: clear_pressed.emit())
	_rotate_button.pressed.connect(func() -> void: rotate_pressed.emit())
	# Defaults: medium brush, brush tool.
	_size_buttons[1].button_pressed = true
	_brush_button.button_pressed = true


func _on_size_pressed(index: int) -> void:
	size_selected.emit(index)


func set_undo_enabled(enabled: bool) -> void:
	_undo_button.disabled = not enabled


func set_rotate_visible(visible_flag: bool) -> void:
	_rotate_button.visible = visible_flag


func set_all_enabled(enabled: bool) -> void:
	for btn: Button in _size_buttons:
		btn.disabled = not enabled
	_brush_button.disabled = not enabled
	_fill_button.disabled = not enabled
	_eraser_button.disabled = not enabled
	_undo_button.disabled = not enabled
	_clear_button.disabled = not enabled
	_rotate_button.disabled = not enabled
