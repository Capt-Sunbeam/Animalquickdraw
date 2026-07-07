class_name GoldenDocs
extends RefCounted
## Shared fixture docs for the Slice 1 golden determinism tests. Built from
## fixed, pre-quantized values so every machine produces identical rasters.
## tools/bake_goldens.gd prints the expected hashes committed in
## test_doc_rasterizer.gd.


static func make_stroke(color_index: int, size_index: int, raw_points: Array, start_t: float, dt: float) -> Stroke:
	var stroke := Stroke.new()
	stroke.color_index = color_index
	stroke.size_index = size_index
	var t: float = start_t
	for raw: Variant in raw_points:
		var p: Vector2 = raw
		stroke.points.append(Stroke.quantize_point(p))
		stroke.timestamps.append(Stroke.quantize_time(t))
		t += dt
	return stroke


static func make_fill(color_index: int, x: int, y: int) -> FillOp:
	var fill := FillOp.new()
	fill.color_index = color_index
	fill.x = x
	fill.y = y
	return fill


static func make_text(color_index: int, size_index: int, x: int, y: int, text: String) -> TextOp:
	var op := TextOp.new()
	op.color_index = color_index
	op.size_index = size_index
	op.x = x
	op.y = y
	op.text = text
	return op


## Three dots, one per brush size, different colors.
static func dots() -> DrawingDoc:
	var doc := DrawingDoc.new()
	doc.ops.append(make_stroke(4, 0, [Vector2(100.0, 100.0)], 0.0, 0.05))
	doc.ops.append(make_stroke(Palette.base_index(1), 1, [Vector2(400.0, 300.0)], 0.5, 0.05))
	doc.ops.append(make_stroke(Palette.base_index(6), 2, [Vector2(700.0, 500.0)], 1.0, 0.05))
	return doc


## Two crossing multi-point strokes.
static func multi_stroke() -> DrawingDoc:
	var doc := DrawingDoc.new()
	doc.ops.append(make_stroke(Palette.base_index(4), 1,
		[Vector2(100.0, 100.0), Vector2(300.0, 250.0), Vector2(500.0, 200.0), Vector2(700.0, 480.0)], 0.0, 0.1))
	doc.ops.append(make_stroke(Palette.base_index(9), 2,
		[Vector2(650.0, 80.0), Vector2(400.0, 350.0), Vector2(120.0, 500.0)], 1.0, 0.1))
	return doc


## Stroke, full clear, second stroke (undo-of-clear coverage).
static func stroke_clear_stroke() -> DrawingDoc:
	var doc := DrawingDoc.new()
	doc.ops.append(make_stroke(Palette.base_index(2), 1,
		[Vector2(200.0, 200.0), Vector2(600.0, 400.0)], 0.0, 0.2))
	doc.ops.append(ClearOp.new())
	doc.ops.append(make_stroke(Palette.base_index(8), 0,
		[Vector2(300.0, 100.0), Vector2(350.0, 450.0)], 1.0, 0.2))
	return doc


## Closed rectangle outline + bucket fill seeded inside it.
static func stroke_fill() -> DrawingDoc:
	var doc := DrawingDoc.new()
	doc.ops.append(make_stroke(4, 1, [
		Vector2(200.0, 150.0), Vector2(600.0, 150.0), Vector2(600.0, 450.0),
		Vector2(200.0, 450.0), Vector2(200.0, 150.0),
	], 0.0, 0.2))
	doc.ops.append(make_fill(Palette.base_index(3), 400, 300))
	return doc


## Fill on an untouched canvas (floods everything).
static func fill_blank() -> DrawingDoc:
	var doc := DrawingDoc.new()
	doc.ops.append(make_fill(Palette.base_index(5), 10, 10))
	return doc


## One stroke on a portrait-orientation canvas.
static func portrait_stroke() -> DrawingDoc:
	var doc := DrawingDoc.new()
	doc.orientation = DrawingDoc.ORIENTATION_PORTRAIT
	doc.ops.append(make_stroke(Palette.base_index(7), 2,
		[Vector2(100.0, 100.0), Vector2(500.0, 700.0)], 0.0, 0.3))
	return doc


## Stroke + text at all three scales, punctuation, and an edge-clipped line
## (Slice 16 §11): pins the PixelFont bitmaps and the blit math.
static func text_mixed() -> DrawingDoc:
	var doc := DrawingDoc.new()
	doc.ops.append(make_stroke(Palette.base_index(4), 1,
		[Vector2(80.0, 480.0), Vector2(720.0, 480.0)], 0.0, 0.2))
	doc.ops.append(make_text(4, 2, 60, 60, "MOO 123 !?"))
	doc.ops.append(make_text(Palette.base_index(1), 1, 120, 200, "Hello, World"))
	doc.ops.append(make_text(Palette.base_index(6), 0, 760, 580, "edge"))  # clips right+bottom
	return doc


## name -> DrawingDoc, for iterating in tests and the bake script.
static func all() -> Dictionary:
	return {
		"dots": dots(),
		"multi_stroke": multi_stroke(),
		"stroke_clear_stroke": stroke_clear_stroke(),
		"stroke_fill": stroke_fill(),
		"fill_blank": fill_blank(),
		"portrait_stroke": portrait_stroke(),
		"text_mixed": text_mixed(),
	}
