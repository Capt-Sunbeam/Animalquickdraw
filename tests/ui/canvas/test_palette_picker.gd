class_name TestPalettePicker
extends GdUnitTestSuite
## Redesigned palette picker (2026-07-06 owner playtest change): all-colors
## overlay + 3 drag-to-pin quick-slots, explicit selection outline.

const PICKER_SCENE: PackedScene = preload("res://ui/canvas/palette_picker.tscn")

var _picker: PalettePicker


func before_test() -> void:
	_picker = auto_free(PICKER_SCENE.instantiate())
	add_child(_picker)
	await await_idle_frame()


func test_default_selection_is_black() -> void:
	assert_int(_picker.get_current_index()).is_equal(Palette.DEFAULT_COLOR_INDEX)


func test_select_index_persists_until_next_pick() -> void:
	var shade_index: int = 6 * Palette.SHADES_PER_FAMILY + 0  # lightest blue
	_picker.select_index(shade_index)
	assert_int(_picker.get_current_index()).is_equal(shade_index)
	_picker.select_index(Palette.base_index(2))
	assert_int(_picker.get_current_index()).is_equal(Palette.base_index(2))


func test_select_index_rejects_out_of_range() -> void:
	var before: int = _picker.get_current_index()
	_picker.select_index(-1)
	_picker.select_index(Palette.COLORS.size())
	assert_int(_picker.get_current_index()).is_equal(before)


func test_base_swatch_press_selects_family_base() -> void:
	var selected: Array[int] = []
	_picker.color_selected.connect(func(idx: int) -> void: selected.append(idx))
	_picker._base_swatches[4].pressed.emit()
	assert_array(selected).is_equal([Palette.base_index(4)])


func test_slots_start_empty() -> void:
	for i: int in PalettePicker.SLOT_COUNT:
		assert_int(_picker.get_slot(i)).is_equal(-1)


func test_set_slot_fill_click_select_and_clear() -> void:
	var pinned: int = 9 * Palette.SHADES_PER_FAMILY + 4  # darkest pink
	_picker.set_slot(1, pinned)
	assert_int(_picker.get_slot(1)).is_equal(pinned)
	_picker._on_slot_pressed(1)
	assert_int(_picker.get_current_index()).is_equal(pinned)
	_picker.clear_slot(1)
	assert_int(_picker.get_slot(1)).is_equal(-1)


func test_empty_slot_click_is_noop() -> void:
	var before: int = _picker.get_current_index()
	_picker._on_slot_pressed(0)
	assert_int(_picker.get_current_index()).is_equal(before)


func test_drop_onto_slot_fills_it() -> void:
	var slot: PaletteSlot = _picker._slots[2]
	assert_bool(slot._can_drop_data(Vector2.ZERO, {PaletteSwatch.DRAG_KEY: 17})).is_true()
	assert_bool(slot._can_drop_data(Vector2.ZERO, {"something_else": 1})).is_false()
	slot._drop_data(Vector2.ZERO, {PaletteSwatch.DRAG_KEY: 17})
	assert_int(_picker.get_slot(2)).is_equal(17)


func test_expand_collapse_overlay() -> void:
	assert_bool(_picker.is_expanded()).is_false()
	_picker.set_expanded(true)
	assert_bool(_picker.is_expanded()).is_true()
	_picker.set_expanded(false)
	assert_bool(_picker.is_expanded()).is_false()


func test_overlay_grid_has_all_sixty_swatches() -> void:
	assert_int(_picker._grid_swatches.size()).is_equal(Palette.COLORS.size())
	var seen: Dictionary = {}
	for swatch: PaletteSwatch in _picker._grid_swatches:
		seen[swatch.color_index] = true
	assert_int(seen.size()).is_equal(Palette.COLORS.size())


func test_grid_swatch_press_selects_exact_shade() -> void:
	var swatch: PaletteSwatch = _picker._grid_swatches[13]
	var idx: int = swatch.color_index
	swatch.pressed.emit()
	assert_int(_picker.get_current_index()).is_equal(idx)


func test_selection_outline_has_single_owner() -> void:
	var shade_index: int = 3 * Palette.SHADES_PER_FAMILY + 1
	_picker.set_slot(0, shade_index)
	_picker.select_index(shade_index)
	var outlined: int = 0
	for swatch: PaletteSwatch in _picker._base_swatches:
		if swatch._selected_visual:
			outlined += 1
	for swatch: PaletteSwatch in _picker._grid_swatches:
		if swatch._selected_visual:
			outlined += 1
	for slot: PaletteSlot in _picker._slots:
		if slot._selected_visual:
			outlined += 1
	# The exact shade appears once in the grid and once in the pinned slot.
	assert_int(outlined).is_equal(2)
	_picker.select_index(Palette.base_index(7))
	for swatch: PaletteSwatch in _picker._grid_swatches:
		if swatch.color_index == shade_index:
			assert_bool(swatch._selected_visual).is_false()


func test_disabled_picker_blocks_expand_and_selection() -> void:
	_picker.set_enabled(false)
	_picker.set_expanded(true)
	assert_bool(_picker.is_expanded()).is_false()
	var before: int = _picker.get_current_index()
	_picker._on_swatch_pressed(_picker._base_swatches[3])
	assert_int(_picker.get_current_index()).is_equal(before)
	_picker.set_enabled(true)
	_picker.set_expanded(true)
	assert_bool(_picker.is_expanded()).is_true()
