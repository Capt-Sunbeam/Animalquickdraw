class_name PaletteSwatch
extends Button
## One palette color swatch (Slice 1 §7, redesigned 2026-07-06 per owner
## playtest). Click to select; drag onto a custom quick-slot to pin it.
## "Selected" is an explicit visual state driven by the picker - never the
## button's own hover/focus leftovers (fixes the stuck-outline bug).

const DRAG_KEY: String = "palette_color_index"

var color_index: int = -1
var draggable: bool = true

var _selected_visual: bool = false


func _init(idx: int = -1, swatch_size: Vector2 = Vector2(34, 34)) -> void:
	color_index = idx
	custom_minimum_size = swatch_size
	focus_mode = Control.FOCUS_NONE
	_refresh_styles()


func set_color_index(idx: int) -> void:
	color_index = idx
	_refresh_styles()


func set_selected_visual(selected: bool) -> void:
	if _selected_visual == selected:
		return
	_selected_visual = selected
	_refresh_styles()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not draggable or color_index < 0 or disabled:
		return null
	var preview := ColorRect.new()
	preview.color = Palette.COLORS[color_index]
	preview.custom_minimum_size = Vector2(28, 28)
	set_drag_preview(preview)
	return {DRAG_KEY: color_index}


func _refresh_styles() -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Palette.COLORS[color_index] if color_index >= 0 else Color(0.2, 0.2, 0.22)
	base.set_corner_radius_all(4)
	if _selected_visual:
		base.border_color = Color.WHITE
		base.set_border_width_all(3)
		# Dark inner keyline so the white ring reads on light colors too.
		base.shadow_color = Color(0, 0, 0, 0.55)
		base.shadow_size = 1
	var hover: StyleBoxFlat = base.duplicate()
	if not _selected_visual:
		hover.border_color = Color(1, 1, 1, 0.5)
		hover.set_border_width_all(1)
	add_theme_stylebox_override("normal", base)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	add_theme_stylebox_override("disabled", base)
