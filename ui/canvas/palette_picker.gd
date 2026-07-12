class_name PalettePicker
extends HBoxContainer
## Palette picker (Slice 1 §7, redesigned 2026-07-06 per owner playtest):
## - 12 base family swatches for one-click picks
## - 3 custom quick-slots: drag any color onto them to pin it (session-only)
## - "All colors" toggle opens an overlay grid of the full 60-color table
##   above the bar, so players sweep every preset at once instead of hunting
##   per-family popups. All colors remain presets - no mixing (brief §6).
## Selection is an explicit outlined-swatch state and persists until another
## color is picked.

signal color_selected(color_index: int)

const SLOT_COUNT: int = 3
const SWATCH_SIZE: Vector2 = Vector2(34, 34)
const GRID_SWATCH_SIZE: Vector2 = Vector2(30, 30)
const OVERLAY_MARGIN: float = 6.0

var _current_index: int = Palette.DEFAULT_COLOR_INDEX
var _enabled: bool = true
var _indicator: ColorRect
var _base_swatches: Array[PaletteSwatch] = []
var _grid_swatches: Array[PaletteSwatch] = []
var _slots: Array[PaletteSlot] = []
var _expand_button: Button
var _overlay: PanelContainer


func _ready() -> void:
	_indicator = ColorRect.new()
	_indicator.custom_minimum_size = SWATCH_SIZE * 1.15
	_indicator.color = Palette.COLORS[_current_index]
	_indicator.tooltip_text = "Current color"
	add_child(_indicator)
	add_child(VSeparator.new())
	for family: int in Palette.FAMILY_COUNT:
		var swatch := PaletteSwatch.new(Palette.base_index(family), SWATCH_SIZE)
		swatch.tooltip_text = "Click to use - open All colors for shades"
		swatch.pressed.connect(_on_swatch_pressed.bind(swatch))
		add_child(swatch)
		_base_swatches.append(swatch)
	add_child(VSeparator.new())
	for i: int in SLOT_COUNT:
		var slot := PaletteSlot.new(SWATCH_SIZE)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		slot.slot_filled.connect(_on_slot_filled.bind(i))
		slot.clear_requested.connect(clear_slot.bind(i))
		add_child(slot)
		_slots.append(slot)
	add_child(VSeparator.new())
	_expand_button = Button.new()
	_expand_button.toggle_mode = true
	_expand_button.theme_type_variation = &"EmojiButton"
	_expand_button.focus_mode = Control.FOCUS_NONE
	_expand_button.custom_minimum_size = Vector2(0, SWATCH_SIZE.y)
	_expand_button.tooltip_text = "Show every color at once - drag favorites onto the + slots"
	_expand_button.toggled.connect(func(pressed: bool) -> void: set_expanded(pressed))
	add_child(_expand_button)
	_build_overlay()
	_refresh_expand_button()
	_refresh_selection()


# --- Public API ---


func get_current_index() -> int:
	return _current_index


## Selects a palette color; stays selected until another pick.
func select_index(color_index: int) -> void:
	if color_index < 0 or color_index >= Palette.COLORS.size():
		return
	_current_index = color_index
	_indicator.color = Palette.COLORS[color_index]
	_refresh_selection()
	color_selected.emit(color_index)


func set_slot(slot_index: int, color_index: int) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return
	if color_index < 0 or color_index >= Palette.COLORS.size():
		return
	_slots[slot_index].fill(color_index)
	_refresh_selection()


func clear_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return
	_slots[slot_index].clear()


func get_slot(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return -1
	return _slots[slot_index].color_index


func set_expanded(expanded: bool) -> void:
	if expanded and _enabled:
		_overlay.visible = true
		_position_overlay()
	else:
		_overlay.visible = false
	_expand_button.set_pressed_no_signal(_overlay.visible)
	_refresh_expand_button()


func is_expanded() -> bool:
	return _overlay.visible


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		set_expanded(false)
	for swatch: PaletteSwatch in _base_swatches:
		swatch.disabled = not enabled
	for swatch: PaletteSwatch in _grid_swatches:
		swatch.disabled = not enabled
	for slot: PaletteSlot in _slots:
		slot.disabled = not enabled
	_expand_button.disabled = not enabled


# --- Internal ---


func _build_overlay() -> void:
	_overlay = PanelContainer.new()
	_overlay.top_level = true
	_overlay.visible = false
	var grid := GridContainer.new()
	grid.columns = Palette.FAMILY_COUNT
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	# Row-major fill: one row per shade, one column per family, so each
	# family reads as a light-to-dark column.
	for shade: int in Palette.SHADES_PER_FAMILY:
		for family: int in Palette.FAMILY_COUNT:
			var idx: int = family * Palette.SHADES_PER_FAMILY + shade
			var swatch := PaletteSwatch.new(idx, GRID_SWATCH_SIZE)
			swatch.pressed.connect(_on_swatch_pressed.bind(swatch))
			grid.add_child(swatch)
			_grid_swatches.append(swatch)
	_overlay.add_child(grid)
	add_child(_overlay)


func _position_overlay() -> void:
	var min_size: Vector2 = _overlay.get_combined_minimum_size()
	_overlay.size = min_size
	var pos := Vector2(global_position.x, global_position.y - min_size.y - OVERLAY_MARGIN)
	var viewport_rect: Rect2 = get_viewport_rect()
	pos.x = clampf(pos.x, 0.0, maxf(viewport_rect.size.x - min_size.x, 0.0))
	pos.y = maxf(pos.y, 0.0)
	_overlay.global_position = pos


func _on_swatch_pressed(swatch: PaletteSwatch) -> void:
	if _enabled:
		select_index(swatch.color_index)


func _on_slot_pressed(slot_index: int) -> void:
	if _enabled and not _slots[slot_index].is_empty():
		select_index(_slots[slot_index].color_index)


func _on_slot_filled(color_index: int, slot_index: int) -> void:
	set_slot(slot_index, color_index)


func _refresh_selection() -> void:
	for swatch: PaletteSwatch in _base_swatches:
		swatch.set_selected_visual(swatch.color_index == _current_index)
	for swatch: PaletteSwatch in _grid_swatches:
		swatch.set_selected_visual(swatch.color_index == _current_index)
	for slot: PaletteSlot in _slots:
		slot.set_selected_visual(not slot.is_empty() and slot.color_index == _current_index)


func _refresh_expand_button() -> void:
	_expand_button.text = "All colors " + ("^" if _overlay.visible else "v")
