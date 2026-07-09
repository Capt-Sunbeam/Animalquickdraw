class_name TestCircleMask
extends GdUnitTestSuite
## Slice 11 circular-mask goldens (TDD §11): the one canonical equation for
## stamping, fill boundary, input clamping, and display alpha. Property
## assertions + relative hash goldens (the existing rasterizer suite style).

const SIZE: Vector2i = Vector2i(512, 512)


func _avatar_doc(ops: Array) -> DrawingDoc:
	return DrawingDoc.from_dict({"v": 1, "orientation": "avatar", "ops": ops})


func _corner_is_background(img: Image) -> bool:
	var bg: String = Palette.CANVAS_BACKGROUND.to_html()
	return img.get_pixel(0, 0).to_html() == bg \
			and img.get_pixel(511, 0).to_html() == bg \
			and img.get_pixel(0, 511).to_html() == bg \
			and img.get_pixel(511, 511).to_html() == bg


func test_mask_equation_and_helpers_agree() -> void:
	var mask: Image = CircleMask.image()
	assert_int(mask.get_width()).is_equal(SIZE.x)
	# Same equation: image pixel state == contains() for a pixel-center probe.
	for p: Vector2i in [Vector2i(0, 0), Vector2i(256, 256), Vector2i(0, 256),
			Vector2i(511, 256), Vector2i(64, 64), Vector2i(450, 450)]:
		assert_bool(mask.get_pixel(p.x, p.y).a >= 0.5)\
				.is_equal(CircleMask.contains(Vector2(p)))
	# Clamp: inside points unchanged; outside points land inside the circle.
	var inside := Vector2(300.0, 300.0)
	assert_that(CircleMask.clamp_to_circle(inside)).is_equal(inside)
	var clamped: Vector2 = CircleMask.clamp_to_circle(Vector2(0.0, 0.0))
	assert_bool(CircleMask.contains(clamped)).is_true()


func test_stroke_crossing_rim_is_clipped_exactly() -> void:
	# A horizontal stroke through the vertical center, wall to wall: with the
	# mask, corners stay background; the center is painted.
	var doc: DrawingDoc = _avatar_doc([{"t": "stroke", "c": 4, "s": 2,
			"pts": [0.0, 20.0, 511.0, 20.0], "ts": [0.0, 0.5]}])   # near the top edge
	var img: Image = DocRasterizer.rasterize(doc, CircleMask.image())
	assert_bool(_corner_is_background(img)).is_true()
	# y=20 at x=256 IS inside the circle (top of the disc) - painted...
	assert_str(img.get_pixel(256, 20).to_html()).is_equal(Palette.COLORS[4].to_html())
	# ...but x=20 y=20 is outside the disc - background survives the stamp.
	assert_str(img.get_pixel(20, 20).to_html()).is_equal(Palette.CANVAS_BACKGROUND.to_html())


func test_center_fill_floods_exactly_the_disc() -> void:
	var teal: int = Palette.base_index(5)
	var doc: DrawingDoc = _avatar_doc([{"t": "fill", "c": teal, "x": 256, "y": 256}])
	var img: Image = DocRasterizer.rasterize(doc, CircleMask.image())
	var teal_html: String = Palette.COLORS[teal].to_html()
	assert_str(img.get_pixel(256, 256).to_html()).is_equal(teal_html)
	assert_str(img.get_pixel(256, 5).to_html()).is_equal(teal_html)      # top of disc
	assert_bool(_corner_is_background(img)).is_true()                    # no leak
	# The whole raster == a synthetic "perfect masked disc" built pixel-wise
	# from the same equation (the §11 full-canvas-fill golden).
	var expected: Image = DocRasterizer.new_canvas_image(SIZE)
	var mask: Image = CircleMask.image()
	for y: int in SIZE.y:
		for x: int in SIZE.x:
			if mask.get_pixel(x, y).a >= 0.5:
				expected.set_pixel(x, y, Palette.COLORS[teal])
	assert_str(DocRasterizer.image_hash(img)).is_equal(DocRasterizer.image_hash(expected))


func test_fill_seeded_near_rim_does_not_leak() -> void:
	# Seed just inside the leftmost point of the disc.
	var doc: DrawingDoc = _avatar_doc([{"t": "fill", "c": 7, "x": 4, "y": 256}])
	var img: Image = DocRasterizer.rasterize(doc, CircleMask.image())
	assert_str(img.get_pixel(4, 256).to_html()).is_equal(Palette.COLORS[7].to_html())
	assert_bool(_corner_is_background(img)).is_true()
	assert_str(img.get_pixel(1, 1).to_html()).is_equal(Palette.CANVAS_BACKGROUND.to_html())


func test_fill_seeded_outside_mask_is_a_noop() -> void:
	var doc: DrawingDoc = _avatar_doc([{"t": "fill", "c": 7, "x": 2, "y": 2}])
	var img: Image = DocRasterizer.rasterize(doc, CircleMask.image())
	var blank: Image = DocRasterizer.new_canvas_image(SIZE)
	assert_str(DocRasterizer.image_hash(img)).is_equal(DocRasterizer.image_hash(blank))


func test_masked_raster_round_trips_serialization_deterministically() -> void:
	var doc: DrawingDoc = _avatar_doc([
		{"t": "fill", "c": 17, "x": 256, "y": 256},
		{"t": "stroke", "c": 4, "s": 1, "pts": [100.0, 480.0, 411.0, 480.0],
				"ts": [0.0, 0.4]},   # crosses the lower rim region
	])
	var live: String = DocRasterizer.image_hash(
			DocRasterizer.rasterize(doc, CircleMask.image()))
	var parsed: DrawingDoc = DrawingDoc.from_dict(
			JSON.parse_string(JSON.stringify(doc.to_dict())))
	var reparsed: String = DocRasterizer.image_hash(
			DocRasterizer.rasterize(parsed, CircleMask.image()))
	assert_str(reparsed).is_equal(live)


func test_display_alpha_zeroes_exactly_the_outside() -> void:
	var doc: DrawingDoc = _avatar_doc([{"t": "fill", "c": 22, "x": 256, "y": 256}])
	var img: Image = DocRasterizer.rasterize(doc, CircleMask.image())
	CircleMask.apply_display_alpha(img)
	assert_float(img.get_pixel(0, 0).a).is_equal(0.0)
	assert_float(img.get_pixel(511, 511).a).is_equal(0.0)
	assert_float(img.get_pixel(256, 256).a).is_equal(1.0)
