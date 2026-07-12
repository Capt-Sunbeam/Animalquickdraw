class_name TestAvatarScenes
extends GdUnitTestSuite
## Slice 11 UI tests (TDD §11): editor smoke + persistence flow (headless,
## via the AvatarStore path seam), AvatarChip render kinds/sizes, and the
## live-refresh contract.

const EDITOR: PackedScene = preload("res://ui/avatars/avatar_editor_screen.tscn")
const CHIP: PackedScene = preload("res://ui/shared/avatar_chip.tscn")

const TEST_PATH: String = "tests_tmp/avatar_scene_test.json"

var _original_path: String


func before_test() -> void:
	_original_path = AvatarStore.path
	AvatarStore.path = TEST_PATH
	Save.delete(TEST_PATH)


func after_test() -> void:
	Save.delete(TEST_PATH)
	AvatarStore.path = _original_path


func _avatar_doc_dict() -> Dictionary:
	return {"v": 1, "orientation": "avatar", "ops": [
		{"t": "fill", "c": 17, "x": 256, "y": 256},
		{"t": "stroke", "c": 4, "s": 1, "pts": [200.0, 200.0, 300.0, 200.0],
				"ts": [0.0, 0.2]},
	]}


# --- editor ---


func test_editor_smoke_blank_start_save_disabled_circle_mode() -> void:
	var editor: Control = auto_free(EDITOR.instantiate())
	add_child(editor)
	var canvas: DrawingCanvas = editor.find_child("Canvas", true, false)
	assert_int(canvas.mask_mode).is_equal(DrawingCanvas.MaskMode.CIRCLE)
	assert_that(canvas.get_doc().orientation).is_equal(DrawingDoc.ORIENTATION_AVATAR)
	var save: Button = editor.find_child("SaveButton", true, false)
	assert_bool(save.disabled).is_true()   # empty doc - nothing to save
	# Rotate and save-toggle are hidden (fixed orientation; round concept).
	assert_bool((canvas.find_child("SaveToggle", true, false) as Control).visible).is_false()


func test_editor_loads_existing_avatar_and_save_reenables() -> void:
	Save.write_json(TEST_PATH, _avatar_doc_dict())
	var editor: Control = auto_free(EDITOR.instantiate())
	add_child(editor)
	var canvas: DrawingCanvas = editor.find_child("Canvas", true, false)
	assert_int(canvas.get_doc().ops.size()).is_equal(2)   # edits on top of current
	var save: Button = editor.find_child("SaveButton", true, false)
	assert_bool(save.disabled).is_false()
	assert_bool(editor._is_dirty()).is_false()   # freshly loaded == saved state


func test_editor_save_writes_file_and_clear_deletes_it() -> void:
	var editor: Control = auto_free(EDITOR.instantiate())
	add_child(editor)
	var canvas: DrawingCanvas = editor.find_child("Canvas", true, false)
	canvas._fill_at(Vector2(256.0, 256.0))   # one op via the canvas seam
	assert_bool(editor._is_dirty()).is_true()
	editor._on_save_pressed()
	assert_bool(Save.file_exists(TEST_PATH)).is_true()
	assert_bool(editor._is_dirty()).is_false()
	editor._on_clear_confirmed()
	assert_bool(Save.file_exists(TEST_PATH)).is_false()
	assert_int(canvas.get_doc().ops.size()).is_equal(0)   # fresh circle


func test_editor_circle_input_rules() -> void:
	var editor: Control = auto_free(EDITOR.instantiate())
	add_child(editor)
	var canvas: DrawingCanvas = editor.find_child("Canvas", true, false)
	# A fill click outside the circle is ignored entirely (no op recorded).
	canvas._fill_at(Vector2(2.0, 2.0))
	assert_int(canvas.get_doc().ops.size()).is_equal(0)
	# Stroke points outside the circle clamp to the rim.
	canvas._stroke_begin(Vector2(0.0, 0.0))
	canvas._stroke_end(Vector2(256.0, 256.0))
	var doc: DrawingDoc = canvas.get_doc()
	assert_int(doc.ops.size()).is_equal(1)
	var stroke: Stroke = doc.ops[0]
	assert_bool(CircleMask.contains(stroke.points[0])).is_true()


# --- chip ---


func test_chip_renders_all_three_kinds_without_error() -> void:
	for size: int in [26, 48, 96]:
		var drawn: AvatarChip = auto_free(CHIP.instantiate())
		drawn.chip_size = size
		add_child(drawn)
		drawn.set_player("Alice", "pid-a", _avatar_doc_dict())
		assert_int((drawn.find_child("FaceSlot", true, false) as Control)
				.get_child_count()).is_equal(1)
		assert_str(drawn.tooltip_text).is_equal("Alice")
		var named: AvatarChip = auto_free(CHIP.instantiate())
		named.chip_size = size
		add_child(named)
		named.set_player("Bob", "pid-b", {})
		assert_int((named.find_child("FaceSlot", true, false) as Control)
				.get_child_count()).is_equal(1)
		var house: AvatarChip = auto_free(CHIP.instantiate())
		house.chip_size = size
		add_child(house)
		house.set_player("", "pid-c", {})
		assert_int((house.find_child("FaceSlot", true, false) as Control)
				.get_child_count()).is_equal(1)


func test_chip_configured_before_tree_entry_renders_on_ready() -> void:
	# List-row builders configure detached chips; rendering defers to _ready.
	var chip: AvatarChip = auto_free(CHIP.instantiate())
	chip.chip_size = 48
	chip.set_player("Carol", "pid-d", {})   # before add_child - must not crash
	add_child(chip)
	assert_int((chip.find_child("FaceSlot", true, false) as Control)
			.get_child_count()).is_equal(1)
	assert_str(chip.tooltip_text).is_equal("Carol")


func test_bound_chip_refreshes_on_avatar_updated_for_its_player_only() -> void:
	var chip: AvatarChip = auto_free(CHIP.instantiate())
	add_child(chip)
	chip.bind_platform_id("pid-nobody", "Fallback")
	assert_str(chip.tooltip_text).is_equal("Fallback")   # roster miss - name circle
	# An update for a DIFFERENT player must not disturb this chip.
	EventBus.avatar_updated.emit("pid-someone-else")
	assert_str(chip.tooltip_text).is_equal("Fallback")
