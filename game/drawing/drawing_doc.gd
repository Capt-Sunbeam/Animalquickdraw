class_name DrawingDoc
extends RefCounted
## The op-list drawing model (Slice 1 §2) - "strokes, not pixels"
## (consistency guide principle 3). Serialized shape is the canonical wire /
## save format from consistency guide §6 - do not deviate.

const FORMAT_VERSION: int = 1

const ORIENTATION_LANDSCAPE: StringName = &"landscape"
const ORIENTATION_PORTRAIT: StringName = &"portrait"
const ORIENTATION_AVATAR: StringName = &"avatar"   # Slice 11: 512x512 circular
const KNOWN_ORIENTATIONS: Array[StringName] = [ORIENTATION_LANDSCAPE,
		ORIENTATION_PORTRAIT, ORIENTATION_AVATAR]

var orientation: StringName = ORIENTATION_LANDSCAPE
var ops: Array[DrawingOp] = []


func canvas_size() -> Vector2i:
	if orientation == ORIENTATION_PORTRAIT:
		return GameConstants.CANVAS_PORTRAIT
	if orientation == ORIENTATION_AVATAR:
		return GameConstants.CANVAS_AVATAR
	return GameConstants.CANVAS_LANDSCAPE


## Last stroke timestamp; 0.0 for empty or stroke-less docs (fill/clear ops
## carry no timestamps).
func natural_duration_sec() -> float:
	var last: float = 0.0
	for op: DrawingOp in ops:
		if op is Stroke:
			var stroke: Stroke = op
			if not stroke.timestamps.is_empty():
				last = maxf(last, stroke.timestamps[stroke.timestamps.size() - 1])
	return last


func to_dict() -> Dictionary:
	var out_ops: Array = []
	for op: DrawingOp in ops:
		match op.type:
			DrawingOp.Type.STROKE:
				var stroke: Stroke = op
				var pts: Array = []
				var ts: Array = []
				for i: int in stroke.points.size():
					var p: Vector2 = Stroke.quantize_point(stroke.points[i])
					pts.append(p.x)
					pts.append(p.y)
					ts.append(Stroke.quantize_time(stroke.timestamps[i]))
				out_ops.append({"t": "stroke", "c": stroke.color_index, "s": stroke.size_index, "pts": pts, "ts": ts})
			DrawingOp.Type.FILL:
				var fill: FillOp = op
				out_ops.append({"t": "fill", "c": fill.color_index, "x": fill.x, "y": fill.y})
			DrawingOp.Type.CLEAR:
				out_ops.append({"t": "clear"})
			DrawingOp.Type.TEXT:
				var text_op: TextOp = op
				out_ops.append({"t": "text", "c": text_op.color_index, "s": text_op.size_index,
						"x": text_op.x, "y": text_op.y, "str": text_op.text})
	return {"v": FORMAT_VERSION, "orientation": String(orientation), "ops": out_ops}


## Strict, silent-failing parser (Slice 1 §2): this format later arrives over
## the network (Slice 3), so any violation returns null with a warning and
## never crashes. Callers treat null as "no drawing".
static func from_dict(data: Variant) -> DrawingDoc:
	if not data is Dictionary:
		return _reject("not a dictionary")
	var dict: Dictionary = data
	var v: Variant = dict.get("v")
	if not _is_int_value(v):
		return _reject("missing/non-int v")
	if int(v) > FORMAT_VERSION or int(v) < 1:
		return _reject("unsupported version %s" % str(v))
	var orientation_raw: Variant = dict.get("orientation")
	if not (orientation_raw is String or orientation_raw is StringName):
		return _reject("missing orientation")
	var orient: StringName = StringName(orientation_raw)
	if not KNOWN_ORIENTATIONS.has(orient):
		return _reject("unknown orientation '%s'" % orient)
	var raw_ops: Variant = dict.get("ops")
	if not raw_ops is Array:
		return _reject("ops is not an array")
	var doc := DrawingDoc.new()
	doc.orientation = orient
	var size: Vector2i = doc.canvas_size()
	for raw_op: Variant in raw_ops:
		if not raw_op is Dictionary:
			return _reject("op is not a dictionary")
		var op_dict: Dictionary = raw_op
		var t: String = str(op_dict.get("t", ""))
		match t:
			"stroke":
				var stroke: Stroke = _parse_stroke(op_dict)
				if stroke == null:
					return null  # _parse_stroke already warned
				doc.ops.append(stroke)
			"fill":
				var fill: FillOp = _parse_fill(op_dict, size)
				if fill == null:
					return null
				doc.ops.append(fill)
			"clear":
				doc.ops.append(ClearOp.new())
			"text":
				var text_op: TextOp = _parse_text(op_dict, size)
				if text_op == null:
					return null
				doc.ops.append(text_op)
			_:
				return _reject("unknown op type '%s'" % t)
	return doc


static func _parse_stroke(op_dict: Dictionary) -> Stroke:
	if not _color_index_ok(op_dict.get("c")):
		_reject("stroke c out of range")
		return null
	var s: Variant = op_dict.get("s")
	if not _is_int_value(s) or int(s) < 0 or int(s) >= GameConstants.BRUSH_RADII_PX.size():
		_reject("stroke s out of range")
		return null
	var pts: Variant = op_dict.get("pts")
	var ts: Variant = op_dict.get("ts")
	if not pts is Array or not ts is Array:
		_reject("stroke pts/ts missing")
		return null
	var pts_arr: Array = pts
	var ts_arr: Array = ts
	if pts_arr.size() < 2 or pts_arr.size() % 2 != 0:
		_reject("stroke pts length invalid")
		return null
	@warning_ignore("integer_division")
	if ts_arr.size() != pts_arr.size() / 2:
		_reject("stroke ts/pts length mismatch")
		return null
	var stroke := Stroke.new()
	stroke.color_index = int(op_dict.get("c"))
	stroke.size_index = int(s)
	var prev_t: float = -1.0
	for i: int in ts_arr.size():
		var px: Variant = pts_arr[i * 2]
		var py: Variant = pts_arr[i * 2 + 1]
		var pt: Variant = ts_arr[i]
		if not _is_number(px) or not _is_number(py) or not _is_number(pt):
			_reject("stroke pts/ts contain non-numbers")
			return null
		var t_val: float = float(pt)
		if t_val < 0.0 or t_val < prev_t:
			_reject("stroke ts decreasing or negative")
			return null
		prev_t = t_val
		stroke.points.append(Stroke.quantize_point(Vector2(float(px), float(py))))
		stroke.timestamps.append(Stroke.quantize_time(t_val))
	return stroke


static func _parse_fill(op_dict: Dictionary, canvas: Vector2i) -> FillOp:
	if not _color_index_ok(op_dict.get("c")):
		_reject("fill c out of range")
		return null
	var x: Variant = op_dict.get("x")
	var y: Variant = op_dict.get("y")
	if not _is_int_value(x) or not _is_int_value(y):
		_reject("fill x/y not ints")
		return null
	if int(x) < 0 or int(x) >= canvas.x or int(y) < 0 or int(y) >= canvas.y:
		_reject("fill seed out of bounds")
		return null
	var fill := FillOp.new()
	fill.color_index = int(op_dict.get("c"))
	fill.x = int(x)
	fill.y = int(y)
	return fill


## TEXT op (Slice 16 §2): anchor must be in-canvas (clip handles overflow
## right/bottom); content is 1..TEXT_MAX_CHARS chars, PixelFont charset only.
static func _parse_text(op_dict: Dictionary, canvas: Vector2i) -> TextOp:
	if not _color_index_ok(op_dict.get("c")):
		_reject("text c out of range")
		return null
	var s: Variant = op_dict.get("s")
	if not _is_int_value(s) or int(s) < 0 or int(s) >= GameConstants.TEXT_SCALES.size():
		_reject("text s out of range")
		return null
	var x: Variant = op_dict.get("x")
	var y: Variant = op_dict.get("y")
	if not _is_int_value(x) or not _is_int_value(y):
		_reject("text x/y not ints")
		return null
	if int(x) < 0 or int(x) >= canvas.x or int(y) < 0 or int(y) >= canvas.y:
		_reject("text anchor out of bounds")
		return null
	var raw_text: Variant = op_dict.get("str")
	if not raw_text is String:
		_reject("text str missing")
		return null
	var text: String = raw_text
	if text.is_empty() or text.length() > GameConstants.TEXT_MAX_CHARS:
		_reject("text length invalid")
		return null
	if not PixelFont.is_supported_text(text):
		_reject("text contains unsupported characters")
		return null
	var text_op := TextOp.new()
	text_op.color_index = int(op_dict.get("c"))
	text_op.size_index = int(s)
	text_op.x = int(x)
	text_op.y = int(y)
	text_op.text = text
	return text_op


static func _color_index_ok(c: Variant) -> bool:
	return _is_int_value(c) and int(c) >= 0 and int(c) < Palette.COLORS.size()


## JSON parses all numbers as floats; accept ints and int-valued floats.
static func _is_int_value(v: Variant) -> bool:
	if v is int:
		return true
	if v is float:
		return is_equal_approx(float(v), roundf(v))
	return false


static func _is_number(v: Variant) -> bool:
	return v is int or v is float


static func _reject(reason: String) -> DrawingDoc:
	push_warning("DrawingDoc.from_dict rejected: %s" % reason)
	return null
