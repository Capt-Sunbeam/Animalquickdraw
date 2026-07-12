class_name TestDocRasterizer
extends GdUnitTestSuite
## Determinism suite (Slice 1 §11). EXPECTED_HASHES are baked with
## tools/bake_goldens.gd on the dev machine and committed; any raster-path
## change that shifts pixels fails here loudly.

## name -> SHA-256 of the rasterized golden doc (see GoldenDocs).
## Baked 2026-07-06 on macOS arm64, Godot 4.6.stable (text_mixed added
## 2026-07-07, Slice 16). To re-bake after an
## INTENTIONAL raster change: temporarily print DocRasterizer.image_hash for
## each GoldenDocs fixture inside a test, run this suite, paste, remove.
const EXPECTED_HASHES: Dictionary = {
	"dots": "4b9be37c19db4171119e1465f2be105873afe2f669f45fd3b869cb204fab15c7",
	"multi_stroke": "61027f4eb86808655cf904381b51a844a2c0104421e8eb1d47d502091d84641b",
	"stroke_clear_stroke": "3cef65a4e540fb8d12d45b842199f95bce56cfc3530e0a6ee23ca27b1c69a9fb",
	"stroke_fill": "cae9fae5eb6632e8b3f8f77ddaf7f7598ef3f2a9a4d2bdd5b983cc74c8a03912",
	# Slice 20: deliberately IDENTICAL to stroke_fill - the doc carries a
	# drawn-and-undone detour that must not touch the final raster.
	"undo_history": "cae9fae5eb6632e8b3f8f77ddaf7f7598ef3f2a9a4d2bdd5b983cc74c8a03912",
	"fill_blank": "6bc2807ef8b81927860987f7b608cad235a48966a359081e769f3a279819b9ee",
	"portrait_stroke": "18fe47fd01c0355506b1ea0ae38a833245d0e206ca56905d93fc8cc325506914",
	"text_mixed": "9abe1b3d36b82723aca253c340846412fece9fc1b5f60a8a2b8b740c2fd2add1",
}


func test_golden_hashes_match_baked_values() -> void:
	var docs: Dictionary = GoldenDocs.all()
	for doc_name: String in docs:
		var img: Image = DocRasterizer.rasterize(docs[doc_name])
		assert_str(DocRasterizer.image_hash(img)) \
			.override_failure_message("golden mismatch for '%s'" % doc_name) \
			.is_equal(str(EXPECTED_HASHES[doc_name]))


func test_rasterize_is_deterministic_across_runs() -> void:
	var docs: Dictionary = GoldenDocs.all()
	for doc_name: String in docs:
		var h1: String = DocRasterizer.image_hash(DocRasterizer.rasterize(docs[doc_name]))
		var h2: String = DocRasterizer.image_hash(DocRasterizer.rasterize(docs[doc_name]))
		assert_str(h1).is_equal(h2)


func test_serialize_parse_raster_hash_stability() -> void:
	# Determinism must survive the wire: hash(live) == hash(parse(json(doc))).
	var docs: Dictionary = GoldenDocs.all()
	for doc_name: String in docs:
		var doc: DrawingDoc = docs[doc_name]
		var live_hash: String = DocRasterizer.image_hash(DocRasterizer.rasterize(doc))
		var json_text: String = JSON.stringify(doc.to_dict())
		var parsed: DrawingDoc = DrawingDoc.from_dict(JSON.parse_string(json_text))
		assert_object(parsed).is_not_null()
		var parsed_hash: String = DocRasterizer.image_hash(DocRasterizer.rasterize(parsed))
		assert_str(parsed_hash) \
			.override_failure_message("wire round-trip changed raster for '%s'" % doc_name) \
			.is_equal(live_hash)


func test_incremental_stamping_equals_full_raster() -> void:
	var stroke: Stroke = GoldenDocs.make_stroke(Palette.base_index(4), 1,
		[Vector2(50.0, 50.0), Vector2(200.0, 120.0), Vector2(340.0, 90.0), Vector2(500.0, 400.0)], 0.0, 0.05)
	var doc := DrawingDoc.new()
	doc.ops.append(stroke)
	var full: Image = DocRasterizer.rasterize(doc)
	# Incremental: stamp point-by-point the way live drawing does.
	var inc: Image = DocRasterizer.new_canvas_image(doc.canvas_size())
	DocRasterizer.stamp_stroke_range(inc, stroke, 0, 0)
	for i: int in range(1, stroke.points.size()):
		DocRasterizer.stamp_stroke_range(inc, stroke, i - 1, i)
	assert_str(DocRasterizer.image_hash(inc)).is_equal(DocRasterizer.image_hash(full))


func test_undo_marker_equals_raster_without_last_op() -> void:
	# Slice 20: undo is a recorded marker, not a pop - the raster must match
	# a doc that never contained the undone op.
	var without_last := DrawingDoc.new()
	without_last.ops.append(GoldenDocs.stroke_fill().ops[0])
	var undone: DrawingDoc = GoldenDocs.stroke_fill()
	undone.ops.append(UndoOp.new())   # cancels the fill
	assert_str(DocRasterizer.image_hash(DocRasterizer.rasterize(undone))) \
		.is_equal(DocRasterizer.image_hash(DocRasterizer.rasterize(without_last)))


func test_undo_of_clear_restores_pre_clear_picture() -> void:
	var doc: DrawingDoc = GoldenDocs.stroke_clear_stroke()
	doc.ops.append(UndoOp.new())  # cancels second stroke
	doc.ops.append(UndoOp.new())  # cancels the clear
	var first_only := DrawingDoc.new()
	first_only.ops.append(GoldenDocs.stroke_clear_stroke().ops[0])
	assert_str(DocRasterizer.image_hash(DocRasterizer.rasterize(doc))) \
		.is_equal(DocRasterizer.image_hash(DocRasterizer.rasterize(first_only)))


func test_rasterize_prefix_reverts_at_each_marker() -> void:
	# undo_history = [rect stroke, mistake stroke, undo, fill]. The prefix
	# raster at the undo (count 3) must equal the rect stroke alone.
	var doc: DrawingDoc = GoldenDocs.undo_history()
	var rect_only := DrawingDoc.new()
	rect_only.ops.append(GoldenDocs.undo_history().ops[0])
	assert_str(DocRasterizer.image_hash(DocRasterizer.rasterize_prefix(doc, 3))) \
		.is_equal(DocRasterizer.image_hash(DocRasterizer.rasterize(rect_only)))
	# Prefix BEFORE the undo still shows the mistake.
	assert_str(DocRasterizer.image_hash(DocRasterizer.rasterize_prefix(doc, 2))) \
		.is_not_equal(DocRasterizer.image_hash(DocRasterizer.rasterize(rect_only)))


func test_same_color_fill_is_visual_noop() -> void:
	var doc := DrawingDoc.new()
	var blank_hash: String = DocRasterizer.image_hash(DocRasterizer.rasterize(doc))
	doc.ops.append(GoldenDocs.make_fill(0, 100, 100))  # white on white background
	assert_str(DocRasterizer.image_hash(DocRasterizer.rasterize(doc))).is_equal(blank_hash)


func test_fill_stays_inside_closed_outline() -> void:
	var img: Image = DocRasterizer.rasterize(GoldenDocs.stroke_fill())
	var yellow: Color = Palette.COLORS[Palette.base_index(3)]
	# Inside the rectangle outline: filled.
	assert_str(img.get_pixel(400, 300).to_html()).is_equal(yellow.to_html())
	# Outside the outline: still background.
	assert_str(img.get_pixel(50, 50).to_html()).is_equal(Palette.CANVAS_BACKGROUND.to_html())


func test_fill_on_blank_floods_whole_canvas() -> void:
	var img: Image = DocRasterizer.rasterize(GoldenDocs.fill_blank())
	var teal: Color = Palette.COLORS[Palette.base_index(5)]
	assert_str(img.get_pixel(0, 0).to_html()).is_equal(teal.to_html())
	assert_str(img.get_pixel(799, 599).to_html()).is_equal(teal.to_html())
	assert_str(img.get_pixel(400, 300).to_html()).is_equal(teal.to_html())


func test_fill_performance_full_canvas_within_budget() -> void:
	var doc: DrawingDoc = GoldenDocs.fill_blank()
	var img: Image = DocRasterizer.new_canvas_image(doc.canvas_size())
	var start_ms: int = Time.get_ticks_msec()
	DocRasterizer.apply_op(img, doc.ops[0])
	var elapsed: int = Time.get_ticks_msec() - start_ms
	# Soft budget (consistency guide §12): warn over budget, hard-fail only
	# at 10x (something is genuinely wrong at that point).
	if elapsed > GameConstants.FILL_BUDGET_MS:
		push_warning("Full-canvas fill took %d ms (budget %d ms)" % [elapsed, GameConstants.FILL_BUDGET_MS])
	assert_int(elapsed).is_less(GameConstants.FILL_BUDGET_MS * 10)


func test_dot_stroke_single_point_stamps() -> void:
	var doc := DrawingDoc.new()
	doc.ops.append(GoldenDocs.make_stroke(4, 2, [Vector2(400.0, 300.0)], 0.0, 0.05))
	var img: Image = DocRasterizer.rasterize(doc)
	assert_str(img.get_pixel(400, 300).to_html()).is_equal(Color.BLACK.to_html())
	# Radius 14: pixel at distance 14 straight right is inside (14^2 <= 14^2).
	assert_str(img.get_pixel(414, 300).to_html()).is_equal(Color.BLACK.to_html())
	assert_str(img.get_pixel(415, 300).to_html()).is_equal(Palette.CANVAS_BACKGROUND.to_html())


func test_text_blit_pixels_match_glyph_bitmap() -> void:
	# 'I' rows: 0x1E,0x0C,0x0C,0x0C,0x0C,0x0C,0x1E,0x00 - row 0 sets bits 1-4.
	var doc := DrawingDoc.new()
	doc.ops.append(GoldenDocs.make_text(4, 0, 100, 100, "I"))  # scale 2 (index 0)
	var img: Image = DocRasterizer.rasterize(doc)
	# Bit 0 unset -> background at x 100..101; bits 1-4 set -> black 102..109.
	assert_str(img.get_pixel(100, 100).to_html()).is_equal(Palette.CANVAS_BACKGROUND.to_html())
	assert_str(img.get_pixel(102, 100).to_html()).is_equal(Color.BLACK.to_html())
	assert_str(img.get_pixel(109, 101).to_html()).is_equal(Color.BLACK.to_html())
	# Bit 5 unset -> background at x 110; scaled row 1 (y 102) has bits 2-3.
	assert_str(img.get_pixel(110, 100).to_html()).is_equal(Palette.CANVAS_BACKGROUND.to_html())
	assert_str(img.get_pixel(104, 102).to_html()).is_equal(Color.BLACK.to_html())
	assert_str(img.get_pixel(102, 102).to_html()).is_equal(Palette.CANVAS_BACKGROUND.to_html())


func test_text_blit_clips_at_canvas_edges_without_error() -> void:
	var doc := DrawingDoc.new()
	doc.ops.append(GoldenDocs.make_text(4, 2, 780, 590, "WW"))  # far past both edges
	var h1: String = DocRasterizer.image_hash(DocRasterizer.rasterize(doc))
	var h2: String = DocRasterizer.image_hash(DocRasterizer.rasterize(doc))
	assert_str(h1).is_equal(h2)
	# Something landed on-canvas ('W' row 0 sets bit 0 at the anchor).
	var img: Image = DocRasterizer.rasterize(doc)
	assert_str(img.get_pixel(780, 590).to_html()).is_equal(Color.BLACK.to_html())


func test_text_space_blits_nothing() -> void:
	var doc := DrawingDoc.new()
	var blank_hash: String = DocRasterizer.image_hash(DocRasterizer.rasterize(doc))
	doc.ops.append(GoldenDocs.make_text(4, 1, 300, 300, " "))
	assert_str(DocRasterizer.image_hash(DocRasterizer.rasterize(doc))).is_equal(blank_hash)


func test_stamps_clip_at_canvas_edges_without_error() -> void:
	var doc := DrawingDoc.new()
	doc.ops.append(GoldenDocs.make_stroke(4, 2, [Vector2(0.0, 0.0), Vector2(799.9, 599.9)], 0.0, 0.05))
	var img: Image = DocRasterizer.rasterize(doc)
	assert_str(img.get_pixel(0, 0).to_html()).is_equal(Color.BLACK.to_html())
