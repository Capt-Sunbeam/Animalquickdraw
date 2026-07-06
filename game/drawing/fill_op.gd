class_name FillOp
extends DrawingOp
## Bucket fill seeded at (x, y) in internal coordinates with a palette color
## (Slice 1 §2). Replayed against the rasterized state of all prior ops -
## this is what makes fill-in-replay deterministic.

var color_index: int = 0
var x: int = 0
var y: int = 0


func _init() -> void:
	type = Type.FILL
