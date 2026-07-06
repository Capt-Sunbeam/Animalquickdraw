class_name PalettePicker
extends HBoxContainer
## 12 base swatches, one per palette family (Slice 1 §7). Left-click selects
## the family's base shade; right-click or long-press opens the family's
## 5-shade popup. All colors are presets - no freeform mixing (brief §6).

signal color_selected(color_index: int)

const LONG_PRESS_SEC: float = 0.45
const SWATCH_SIZE: Vector2 = Vector2(34, 34)

var _current_index: int = Palette.DEFAULT_COLOR_INDEX
var _long_press_timer: Timer
var _long_press_family: int = -1
var _popup: PopupPanel
var _popup_row: HBoxContainer
var _indicator: ColorRect
var _family_buttons: Array[Button] = []
var _enabled: bool = true


func _ready() -> void:
	_indicator = ColorRect.new()
	_indicator.custom_minimum_size = SWATCH_SIZE * 1.15
	_indicator.color = Palette.COLORS[_current_index]
	_indicator.tooltip_text = "Current color"
	add_child(_indicator)
	add_child(VSeparator.new())
	for family: int in Palette.FAMILY_COUNT:
		var btn: Button = _make_swatch_button(Palette.COLORS[Palette.base_index(family)])
		btn.tooltip_text = "Right-click or hold for shades"
		btn.pressed.connect(_on_family_clicked.bind(family))
		btn.gui_input.connect(_on_family_gui_input.bind(family))
		btn.button_down.connect(_on_family_button_down.bind(family))
		btn.button_up.connect(_on_family_button_up)
		add_child(btn)
		_family_buttons.append(btn)
	_long_press_timer = Timer.new()
	_long_press_timer.one_shot = true
	_long_press_timer.wait_time = LONG_PRESS_SEC
	_long_press_timer.timeout.connect(_on_long_press_timeout)
	add_child(_long_press_timer)
	_popup = PopupPanel.new()
	_popup_row = HBoxContainer.new()
	_popup_row.add_theme_constant_override("separation", 6)
	_popup.add_child(_popup_row)
	add_child(_popup)


func get_current_index() -> int:
	return _current_index


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	for btn: Button in _family_buttons:
		btn.disabled = not enabled


func _make_swatch_button(color: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = SWATCH_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	var hover := style.duplicate()
	hover.border_color = Color.WHITE
	hover.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn


func _select(color_index: int) -> void:
	_current_index = color_index
	_indicator.color = Palette.COLORS[color_index]
	color_selected.emit(color_index)


func _on_family_clicked(family: int) -> void:
	if not _enabled:
		return
	_select(Palette.base_index(family))


func _on_family_gui_input(event: InputEvent, family: int) -> void:
	if not _enabled:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_open_shades(family)


func _on_family_button_down(family: int) -> void:
	_long_press_family = family
	_long_press_timer.start()


func _on_family_button_up() -> void:
	_long_press_timer.stop()


func _on_long_press_timeout() -> void:
	if _enabled and _long_press_family >= 0:
		_open_shades(_long_press_family)


func _open_shades(family: int) -> void:
	for child: Node in _popup_row.get_children():
		child.queue_free()
	for shade: int in Palette.SHADES_PER_FAMILY:
		var color_index: int = family * Palette.SHADES_PER_FAMILY + shade
		var btn: Button = _make_swatch_button(Palette.COLORS[color_index])
		btn.pressed.connect(func() -> void:
			_select(color_index)
			_popup.hide())
		_popup_row.add_child(btn)
	var anchor: Button = _family_buttons[family]
	var pos: Vector2 = anchor.get_screen_position() + Vector2(0, anchor.size.y + 2)
	_popup.popup(Rect2i(Vector2i(pos), Vector2i(0, 0)))
