class_name PaletteSlot
extends PaletteSwatch
## Custom quick-slot (owner playtest QOL, 2026-07-06): drag any color from
## the expanded grid (or the base row) onto a blank slot to pin it for fast
## reuse. Click a filled slot to select its color; right-click clears it.
## Session-only - slots reset on app launch (decision log).

signal slot_filled(color_index: int)
signal clear_requested()


func _init(swatch_size: Vector2 = Vector2(34, 34)) -> void:
	super._init(-1, swatch_size)
	draggable = false
	tooltip_text = "Drag a color here to pin it.\nClick to use - right-click to clear."
	_refresh_empty_look()


func is_empty() -> bool:
	return color_index < 0


func fill(idx: int) -> void:
	set_color_index(idx)
	draggable = true
	_refresh_empty_look()


func clear() -> void:
	set_color_index(-1)
	draggable = false
	set_selected_visual(false)
	_refresh_empty_look()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return not disabled and data is Dictionary and data.has(DRAG_KEY)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	slot_filled.emit(int(data[DRAG_KEY]))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and not is_empty():
			clear_requested.emit()
			accept_event()


func _refresh_empty_look() -> void:
	text = "+" if is_empty() else ""
