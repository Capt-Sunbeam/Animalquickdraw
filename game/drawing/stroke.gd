class_name Stroke
extends DrawingOp
## One continuous brush drag (Slice 1 §2). Points are in INTERNAL canvas
## coordinates, quantized to 0.1 px; timestamps are seconds since drawing
## start, quantized to 1 ms. Quantization happens at capture time so
## serialize -> parse -> rasterize is bit-identical to live rasterize.

var color_index: int = 0             # index into Palette.COLORS
var size_index: int = 0              # 0 | 1 | 2 -> GameConstants.BRUSH_RADII_PX
var points: PackedVector2Array = PackedVector2Array()      # >= 1 point (a dot is a 1-point stroke)
var timestamps: PackedFloat32Array = PackedFloat32Array()  # same length as points, non-decreasing


func _init() -> void:
	type = Type.STROKE


## Capture-time quantization: 0.1 px grid.
static func quantize_point(p: Vector2) -> Vector2:
	return Vector2(snappedf(p.x, 0.1), snappedf(p.y, 0.1))


## Capture-time quantization: 1 ms grid.
static func quantize_time(t: float) -> float:
	return snappedf(t, 0.001)
