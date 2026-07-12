extends Control
## Dev-only canvas playtest surface (Slice 1 §7): hosts a DrawingCanvas plus
## replay controls and doc-JSON dump/load via the clipboard. This is the
## playtest surface for the Slice 1 gates until Slice 3's round screens
## exist. Reached from the main menu in debug builds only.

@onready var _canvas: DrawingCanvas = %Canvas
@onready var _replay_button: Button = %ReplayButton
@onready var _speed_slider: HSlider = %SpeedSlider
@onready var _speed_label: Label = %SpeedLabel
@onready var _dump_button: Button = %DumpButton
@onready var _load_button: Button = %LoadButton
@onready var _back_button: Button = %BackButton
@onready var _toast: Toast = %Toast


func _ready() -> void:
	_replay_button.pressed.connect(_on_replay_pressed)
	_speed_slider.value_changed.connect(_on_speed_changed)
	_dump_button.pressed.connect(_on_dump_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_back_button.pressed.connect(func() -> void: Nav.goto(Routes.MENU))
	_canvas.replay_finished.connect(func() -> void: _replay_button.disabled = false)
	_on_speed_changed(_speed_slider.value)


func _on_replay_pressed() -> void:
	if _canvas.is_replaying():
		return
	_replay_button.disabled = true
	_canvas.play_replay(_speed_slider.value)


func _on_speed_changed(value: float) -> void:
	_speed_label.text = "%.1fx" % value


func _on_dump_pressed() -> void:
	DisplayServer.clipboard_set(JSON.stringify(_canvas.get_doc().to_dict()))
	_toast.show_message("Drawing JSON copied to clipboard.")


func _on_load_pressed() -> void:
	var parsed: Variant = JSON.parse_string(DisplayServer.clipboard_get())
	var doc: DrawingDoc = DrawingDoc.from_dict(parsed)
	if doc == null:
		_toast.show_error("Clipboard doesn't contain a valid drawing.")
		return
	_canvas.load_doc(doc)
	_toast.show_message("Drawing loaded.")
