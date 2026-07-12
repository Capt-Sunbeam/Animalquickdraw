class_name EraserCursor
extends Control
## Display-only eraser footprint (owner request 2026-07-07): a circle at the
## mouse showing exactly where the eraser will paint. Pure GPU display over
## the canvas view - never touches the deterministic raster path. The owner
## canvas drives radius_px (display-space) and visibility per frame.

var radius_px: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if radius_px <= 0.0:
		return
	var pos: Vector2 = get_local_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(pos):
		return
	draw_circle(pos, radius_px, Color(1.0, 1.0, 1.0, 0.35))
	draw_arc(pos, radius_px, 0.0, TAU, 48, Color(0.15, 0.15, 0.15, 0.9), 1.5, true)
