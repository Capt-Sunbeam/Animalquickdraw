class_name CanvasDropTarget
extends SubViewportContainer
## The canvas ViewportBox's drop target for the Slice 16 text chip. Uses the
## virtual _can_drop_data/_drop_data overrides (reliable across Godot
## versions, unlike runtime set_drag_forwarding with partial callables) and
## forwards to the owning DrawingCanvas, which owns all placement logic.

var canvas: DrawingCanvas = null


func _ready() -> void:
	# THE load-bearing line (root cause of the 2026-07-07 "drop never lands"
	# bug): since Godot 4.5, gui.target_control - the only control the drag
	# system offers drops to - is set to a SubViewportContainer ONLY when
	# mouse_target is enabled (viewport.cpp _update_mouse_over). The default
	# is false, which makes this container structurally invisible to every
	# drop, regardless of how the handlers are wired.
	mouse_target = true


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return canvas != null and canvas._can_drop_text(at_position, data)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if canvas != null:
		canvas._drop_text(at_position, data)
