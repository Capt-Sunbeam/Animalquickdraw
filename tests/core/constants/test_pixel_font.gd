class_name TestPixelFont
extends GdUnitTestSuite
## PixelFont table integrity (Slice 16 §11). The glyph bitmaps are part of
## the deterministic raster contract - the golden test pins the rendered
## pixels; this suite pins the table's shape and basic sanity.


func test_table_covers_exactly_ascii_32_to_126() -> void:
	assert_int(PixelFont.GLYPH_COUNT).is_equal(95)
	assert_int(PixelFont.GLYPH_ROWS.size()) \
		.is_equal(PixelFont.GLYPH_COUNT * PixelFont.ROWS_PER_GLYPH)
	assert_bool(PixelFont.is_supported(31)).is_false()
	assert_bool(PixelFont.is_supported(32)).is_true()
	assert_bool(PixelFont.is_supported(126)).is_true()
	assert_bool(PixelFont.is_supported(127)).is_false()


func test_every_printable_glyph_has_set_pixels_space_is_blank() -> void:
	for code: int in range(PixelFont.FIRST_CODE, PixelFont.LAST_CODE + 1):
		var rows: PackedByteArray = PixelFont.glyph_rows(code)
		assert_int(rows.size()).is_equal(PixelFont.ROWS_PER_GLYPH)
		var set_bits: int = 0
		for b: int in rows:
			set_bits += b
		if code == 32:
			assert_int(set_bits).override_failure_message("space must be blank").is_equal(0)
		else:
			assert_int(set_bits) \
				.override_failure_message("glyph U+%04X has no pixels" % code) \
				.is_greater(0)


func test_unsupported_codes_return_empty_rows() -> void:
	assert_int(PixelFont.glyph_rows(31).size()).is_equal(0)
	assert_int(PixelFont.glyph_rows(0x00E9).size()).is_equal(0)  # é
	assert_int(PixelFont.glyph_rows(0x1F600).size()).is_equal(0)  # emoji


func test_is_supported_text() -> void:
	assert_bool(PixelFont.is_supported_text("MOO! 123 ~[]{}")).is_true()
	assert_bool(PixelFont.is_supported_text("")).is_true()  # length rules live in from_dict
	assert_bool(PixelFont.is_supported_text("café")).is_false()
	assert_bool(PixelFont.is_supported_text("line\nbreak")).is_false()
	assert_bool(PixelFont.is_supported_text("tab\there")).is_false()
