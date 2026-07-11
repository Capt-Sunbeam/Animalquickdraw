class_name TestAvatarStore
extends GdUnitTestSuite
## Slice 11 (TDD §11): editor persistence logic, headless. Uses the path
## seam so the suite never touches a real player's avatar.

const TEST_PATH: String = "tests_tmp/avatar_store_test.json"

var _original_path: String


func before_test() -> void:
	_original_path = AvatarStore.path
	AvatarStore.path = TEST_PATH
	Save.delete(TEST_PATH)


func after_test() -> void:
	Save.delete(TEST_PATH)
	AvatarStore.path = _original_path


func _avatar_doc(op_count: int = 1) -> DrawingDoc:
	var ops: Array = []
	for i: int in range(op_count):
		ops.append({"t": "fill", "c": 17, "x": 100 + i, "y": 100})
	return DrawingDoc.from_dict({"v": 1, "orientation": "avatar", "ops": ops})


func test_save_load_round_trip() -> void:
	assert_int(AvatarStore.save_doc(_avatar_doc(3))).is_equal(OK)
	var loaded: DrawingDoc = AvatarStore.load_doc()
	assert_object(loaded).is_not_null()
	assert_int(loaded.ops.size()).is_equal(3)
	assert_that(loaded.orientation).is_equal(DrawingDoc.ORIENTATION_AVATAR)


func test_missing_file_loads_as_no_avatar() -> void:
	assert_object(AvatarStore.load_doc()).is_null()


func test_empty_doc_is_never_written() -> void:
	var empty := DrawingDoc.new()
	empty.orientation = DrawingDoc.ORIENTATION_AVATAR
	assert_int(AvatarStore.save_doc(empty)).is_not_equal(OK)
	assert_bool(Save.file_exists(TEST_PATH)).is_false()


func test_corrupt_file_loads_as_none_and_is_left_untouched() -> void:
	Save.write_json(TEST_PATH, {"v": 999, "future": true})
	assert_object(AvatarStore.load_doc()).is_null()
	assert_bool(Save.file_exists(TEST_PATH)).is_true()   # never destroy on read failure


func test_wrong_orientation_file_loads_as_none() -> void:
	Save.write_json(TEST_PATH, {"v": 1, "orientation": "landscape",
			"ops": [{"t": "clear"}]})
	assert_object(AvatarStore.load_doc()).is_null()


func test_clear_deletes_the_file() -> void:
	AvatarStore.save_doc(_avatar_doc())
	assert_int(AvatarStore.clear()).is_equal(OK)
	assert_bool(Save.file_exists(TEST_PATH)).is_false()
	assert_int(AvatarStore.clear()).is_equal(OK)   # clearing nothing is fine


# --- default_path_for_args: dev instances share user://, so a --name= arg
# --- namespaces the avatar file (mirrors EnetBackend.disambiguate_platform_id)

func test_default_path_namespaced_by_dev_name_arg() -> void:
	var args := PackedStringArray(["--platform=enet", "--name=P2"])
	assert_that(AvatarStore.default_path_for_args(args)).is_equal("avatar_P2.json")


func test_default_path_plain_without_name_arg() -> void:
	assert_that(AvatarStore.default_path_for_args(PackedStringArray())).is_equal("avatar.json")


func test_default_path_plain_on_non_enet_platform() -> void:
	var args := PackedStringArray(["--platform=steam", "--name=P2"])
	assert_that(AvatarStore.default_path_for_args(args)).is_equal("avatar.json")


func test_default_path_sanitizes_hostile_name_arg() -> void:
	# ".." anywhere in a Save path is rejected wholesale, so the tag is a
	# whitelist; a name with no safe characters falls back to the plain file.
	var traversal := PackedStringArray(["--name=../ev il/p"])
	assert_that(AvatarStore.default_path_for_args(traversal)).is_equal("avatar_evilp.json")
	var hostile := PackedStringArray(["--name=#!?."])
	assert_that(AvatarStore.default_path_for_args(hostile)).is_equal("avatar.json")
