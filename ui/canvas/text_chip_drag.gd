class_name TextChipDrag
extends TextureRect
## The Slice 16 text chip's drag source - virtual _get_drag_data override
## forwarding to the owning DrawingCanvas (see CanvasDropTarget for why
## virtuals over set_drag_forwarding).

var canvas: DrawingCanvas = null


func _get_drag_data(at_position: Vector2) -> Variant:
	if canvas == null:
		return null
	return canvas._chip_get_drag_data(at_position)
