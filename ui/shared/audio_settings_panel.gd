class_name AudioSettingsPanel
extends VBoxContainer
## Slice 21: Master/Music/SFX volume sliders - the shared surface mounted in
## the Esc menu (GameMenu) and the main-menu Options dialog. Applies live
## through Audio.set_volume; persistence is debounced so a slider drag
## doesn't hammer profile.json with atomic writes.

const KINDS: Array[StringName] = [&"master", &"music", &"sfx"]
const LABELS: Dictionary = {&"master": "Master", &"music": "Music", &"sfx": "SFX"}
const SAVE_DEBOUNCE_SEC: float = 0.5

var _save_timer: Timer = null


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE_SEC
	_save_timer.timeout.connect(func() -> void: Audio.save_volumes())
	add_child(_save_timer)
	for kind: StringName in KINDS:
		add_child(_build_row(kind))


func _build_row(kind: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = LABELS[kind]
	label.custom_minimum_size = Vector2(64, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Audio.get_volume(kind)
	slider.custom_minimum_size = Vector2(150, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_value_changed.bind(kind))
	row.add_child(slider)
	return row


func _on_value_changed(value: float, kind: StringName) -> void:
	Audio.set_volume(kind, value)
	_save_timer.start()
