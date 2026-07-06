class_name TestPalette
extends GdUnitTestSuite


func test_palette_has_sixty_distinct_entries() -> void:
	assert_int(Palette.COLORS.size()).is_equal(Palette.FAMILY_COUNT * Palette.SHADES_PER_FAMILY)
	assert_int(Palette.COLORS.size()).is_equal(60)
	var seen: Dictionary = {}
	for color: Color in Palette.COLORS:
		var key: String = color.to_html()
		assert_bool(seen.has(key)).override_failure_message("duplicate palette color %s" % key).is_false()
		seen[key] = true


func test_first_entry_is_canvas_background() -> void:
	assert_that(Palette.COLORS[0]).is_equal(Palette.CANVAS_BACKGROUND)
	assert_that(Palette.CANVAS_BACKGROUND).is_equal(Color.WHITE)


func test_base_index_and_family_of_are_inverse() -> void:
	for family: int in Palette.FAMILY_COUNT:
		var base: int = Palette.base_index(family)
		assert_int(Palette.family_of(base)).is_equal(family)
		for shade: int in Palette.SHADES_PER_FAMILY:
			assert_int(Palette.family_of(family * Palette.SHADES_PER_FAMILY + shade)).is_equal(family)


func test_default_color_is_black() -> void:
	assert_that(Palette.COLORS[Palette.DEFAULT_COLOR_INDEX]).is_equal(Color.BLACK)


func test_brush_radii_strictly_increasing_three_entries() -> void:
	assert_int(GameConstants.BRUSH_RADII_PX.size()).is_equal(3)
	assert_bool(GameConstants.BRUSH_RADII_PX[0] < GameConstants.BRUSH_RADII_PX[1]).is_true()
	assert_bool(GameConstants.BRUSH_RADII_PX[1] < GameConstants.BRUSH_RADII_PX[2]).is_true()
