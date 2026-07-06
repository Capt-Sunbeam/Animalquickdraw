class_name TestDrawingDoc
extends GdUnitTestSuite
## Serialization + strict validation for the canonical DrawingDoc format
## (Slice 1 §2 / consistency guide §6).


func _valid_doc() -> DrawingDoc:
	var doc := DrawingDoc.new()
	doc.ops.append(GoldenDocs.make_stroke(4, 1, [Vector2(10.0, 20.0), Vector2(30.5, 40.1)], 0.0, 0.016))
	doc.ops.append(GoldenDocs.make_fill(7, 120, 88))
	doc.ops.append(ClearOp.new())
	return doc


func test_round_trip_preserves_all_ops() -> void:
	var doc: DrawingDoc = _valid_doc()
	var parsed: DrawingDoc = DrawingDoc.from_dict(doc.to_dict())
	assert_object(parsed).is_not_null()
	assert_int(parsed.ops.size()).is_equal(3)
	var stroke: Stroke = parsed.ops[0]
	assert_int(stroke.color_index).is_equal(4)
	assert_int(stroke.size_index).is_equal(1)
	assert_int(stroke.points.size()).is_equal(2)
	assert_float(stroke.points[1].x).is_equal_approx(30.5, 0.001)
	assert_float(stroke.timestamps[1]).is_equal_approx(0.016, 0.0001)
	var fill: FillOp = parsed.ops[1]
	assert_int(fill.color_index).is_equal(7)
	assert_int(fill.x).is_equal(120)
	assert_int(fill.y).is_equal(88)
	assert_int(parsed.ops[2].type).is_equal(DrawingOp.Type.CLEAR)


func test_round_trip_through_actual_json_text() -> void:
	var doc: DrawingDoc = _valid_doc()
	var json_text: String = JSON.stringify(doc.to_dict())
	var parsed: DrawingDoc = DrawingDoc.from_dict(JSON.parse_string(json_text))
	assert_object(parsed).is_not_null()
	assert_int(parsed.ops.size()).is_equal(3)
	# Raster equality after a real JSON round trip is covered in the
	# rasterizer suite (hash stability test).


func test_serialized_shape_matches_consistency_guide() -> void:
	var dict: Dictionary = _valid_doc().to_dict()
	assert_array(dict.keys()).contains_exactly_in_any_order(["v", "orientation", "ops"])
	assert_int(int(dict["v"])).is_equal(1)
	assert_str(str(dict["orientation"])).is_equal("landscape")
	var ops: Array = dict["ops"]
	assert_array(ops[0].keys()).contains_exactly_in_any_order(["t", "c", "s", "pts", "ts"])
	assert_array(ops[1].keys()).contains_exactly_in_any_order(["t", "c", "x", "y"])
	assert_array(ops[2].keys()).contains_exactly_in_any_order(["t"])
	var pts: Array = ops[0]["pts"]
	var ts: Array = ops[0]["ts"]
	assert_int(pts.size()).is_equal(4)  # flattened pairs
	@warning_ignore("integer_division")
	assert_int(ts.size()).is_equal(pts.size() / 2)


func test_from_dict_rejects_invalid_input() -> void:
	var base: Dictionary = _valid_doc().to_dict()
	# Higher version
	var d: Dictionary = base.duplicate(true)
	d["v"] = 99
	assert_object(DrawingDoc.from_dict(d)).is_null()
	# Missing v
	d = base.duplicate(true)
	d.erase("v")
	assert_object(DrawingDoc.from_dict(d)).is_null()
	# Unknown orientation
	d = base.duplicate(true)
	d["orientation"] = "diagonal"
	assert_object(DrawingDoc.from_dict(d)).is_null()
	# Unknown op type
	d = base.duplicate(true)
	d["ops"][0] = {"t": "sparkle"}
	assert_object(DrawingDoc.from_dict(d)).is_null()
	# Color index out of range
	d = base.duplicate(true)
	d["ops"][0]["c"] = Palette.COLORS.size()
	assert_object(DrawingDoc.from_dict(d)).is_null()
	d = base.duplicate(true)
	d["ops"][0]["c"] = -1
	assert_object(DrawingDoc.from_dict(d)).is_null()
	# Size index out of range
	d = base.duplicate(true)
	d["ops"][0]["s"] = 3
	assert_object(DrawingDoc.from_dict(d)).is_null()
	# Odd pts length
	d = base.duplicate(true)
	d["ops"][0]["pts"] = [1.0, 2.0, 3.0]
	assert_object(DrawingDoc.from_dict(d)).is_null()
	# ts / pts mismatch
	d = base.duplicate(true)
	d["ops"][0]["ts"] = [0.0]
	assert_object(DrawingDoc.from_dict(d)).is_null()
	# Decreasing ts
	d = base.duplicate(true)
	d["ops"][0]["ts"] = [0.5, 0.1]
	assert_object(DrawingDoc.from_dict(d)).is_null()
	# Fill seed out of bounds
	d = base.duplicate(true)
	d["ops"][1]["x"] = GameConstants.CANVAS_LANDSCAPE.x
	assert_object(DrawingDoc.from_dict(d)).is_null()
	# ops not an array
	d = base.duplicate(true)
	d["ops"] = "nope"
	assert_object(DrawingDoc.from_dict(d)).is_null()
	# Non-dictionary input
	assert_object(DrawingDoc.from_dict(42)).is_null()
	assert_object(DrawingDoc.from_dict("[]")).is_null()
	assert_object(DrawingDoc.from_dict(null)).is_null()


func test_from_dict_accepts_json_float_ints() -> void:
	# JSON.parse_string turns every number into a float; int-valued floats
	# must be accepted for v/c/s/x/y.
	var d: Dictionary = {
		"v": 1.0, "orientation": "landscape",
		"ops": [{"t": "fill", "c": 7.0, "x": 120.0, "y": 88.0}],
	}
	assert_object(DrawingDoc.from_dict(d)).is_not_null()


func test_quantization_grids() -> void:
	var p: Vector2 = Stroke.quantize_point(Vector2(1.234567, 2.7189))
	assert_float(p.x).is_equal_approx(1.2, 0.0001)
	assert_float(p.y).is_equal_approx(2.7, 0.0001)
	assert_float(Stroke.quantize_time(0.123456)).is_equal_approx(0.123, 0.00001)


func test_natural_duration_empty_and_strokeless_docs_are_zero() -> void:
	var doc := DrawingDoc.new()
	assert_float(doc.natural_duration_sec()).is_equal_approx(0.0, 0.0001)
	doc.ops.append(GoldenDocs.make_fill(3, 5, 5))
	doc.ops.append(ClearOp.new())
	assert_float(doc.natural_duration_sec()).is_equal_approx(0.0, 0.0001)


func test_natural_duration_is_last_stroke_timestamp() -> void:
	var doc := DrawingDoc.new()
	doc.ops.append(GoldenDocs.make_stroke(4, 0, [Vector2(1.0, 1.0), Vector2(2.0, 2.0)], 0.0, 0.5))
	doc.ops.append(GoldenDocs.make_stroke(4, 0, [Vector2(3.0, 3.0), Vector2(4.0, 4.0)], 2.0, 0.5))
	assert_float(doc.natural_duration_sec()).is_equal_approx(2.5, 0.001)


func test_canvas_size_follows_orientation() -> void:
	var doc := DrawingDoc.new()
	assert_that(doc.canvas_size()).is_equal(GameConstants.CANVAS_LANDSCAPE)
	doc.orientation = DrawingDoc.ORIENTATION_PORTRAIT
	assert_that(doc.canvas_size()).is_equal(GameConstants.CANVAS_PORTRAIT)
