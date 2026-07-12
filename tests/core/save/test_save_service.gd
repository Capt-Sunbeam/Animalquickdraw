class_name TestSaveService
extends GdUnitTestSuite
## Skeleton gate: Save round-trips JSON to user:// atomically and tolerates
## missing/corrupt files (skeleton guide §5 Verification).

const TMP_DIR: String = "tests_tmp"


func after_test() -> void:
	for file: String in Save.list_dir(TMP_DIR):
		Save.delete(TMP_DIR + "/" + file)
	for file: String in Save.list_dir(TMP_DIR + "/nested/deep"):
		Save.delete(TMP_DIR + "/nested/deep/" + file)


func test_write_then_read_round_trips() -> void:
	var data: Dictionary = {"v": 1, "name": "aardvark", "count": 3, "score": -2}
	assert_int(Save.write_json(TMP_DIR + "/round_trip.json", data)).is_equal(OK)
	var loaded: Dictionary = Save.read_json(TMP_DIR + "/round_trip.json", {})
	assert_str(str(loaded.get("name"))).is_equal("aardvark")
	assert_int(int(loaded.get("count"))).is_equal(3)
	assert_int(int(loaded.get("score"))).is_equal(-2)
	assert_int(int(loaded.get("v"))).is_equal(1)


func test_read_missing_file_returns_default() -> void:
	var default: Dictionary = {"fallback": true}
	var loaded: Dictionary = Save.read_json(TMP_DIR + "/does_not_exist.json", default)
	assert_bool(bool(loaded.get("fallback", false))).is_true()


func test_read_corrupt_file_returns_default_without_crash() -> void:
	var full: String = "user://" + TMP_DIR + "/corrupt.json"
	DirAccess.make_dir_recursive_absolute("user://" + TMP_DIR)
	var file: FileAccess = FileAccess.open(full, FileAccess.WRITE)
	file.store_string("this is {{{ not json")
	file.close()
	var loaded: Dictionary = Save.read_json(TMP_DIR + "/corrupt.json", {"ok": 1})
	assert_int(int(loaded.get("ok", 0))).is_equal(1)


func test_read_non_dictionary_json_returns_default() -> void:
	var full: String = "user://" + TMP_DIR + "/array.json"
	DirAccess.make_dir_recursive_absolute("user://" + TMP_DIR)
	var file: FileAccess = FileAccess.open(full, FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()
	var loaded: Dictionary = Save.read_json(TMP_DIR + "/array.json", {"ok": 1})
	assert_int(int(loaded.get("ok", 0))).is_equal(1)


func test_write_creates_nested_directories() -> void:
	assert_int(Save.write_json(TMP_DIR + "/nested/deep/file.json", {"v": 1})).is_equal(OK)
	var loaded: Dictionary = Save.read_json(TMP_DIR + "/nested/deep/file.json", {})
	assert_int(int(loaded.get("v", 0))).is_equal(1)


func test_write_leaves_no_tmp_file_behind() -> void:
	assert_int(Save.write_json(TMP_DIR + "/atomic.json", {"v": 1})).is_equal(OK)
	var files: PackedStringArray = Save.list_dir(TMP_DIR)
	for file: String in files:
		assert_bool(file.ends_with(".tmp")).is_false()


func test_delete_removes_file_and_is_idempotent() -> void:
	Save.write_json(TMP_DIR + "/victim.json", {"v": 1})
	assert_int(Save.delete(TMP_DIR + "/victim.json")).is_equal(OK)
	var loaded: Dictionary = Save.read_json(TMP_DIR + "/victim.json", {"gone": true})
	assert_bool(bool(loaded.get("gone", false))).is_true()
	assert_int(Save.delete(TMP_DIR + "/victim.json")).is_equal(OK)


func test_list_dir_lists_written_files() -> void:
	Save.write_json(TMP_DIR + "/list_a.json", {"v": 1})
	Save.write_json(TMP_DIR + "/list_b.json", {"v": 1})
	var files: PackedStringArray = Save.list_dir(TMP_DIR)
	assert_bool(files.has("list_a.json")).is_true()
	assert_bool(files.has("list_b.json")).is_true()


func test_list_dir_missing_directory_returns_empty() -> void:
	assert_int(Save.list_dir("no_such_dir_ever").size()).is_equal(0)


# --- Slice 8: PNG helpers ---


func test_png_write_read_round_trip() -> void:
	var img := Image.create(8, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.4, 0.6))
	assert_int(Save.write_png(TMP_DIR + "/pic.png", img)).is_equal(OK)
	var loaded: Image = Save.read_png(TMP_DIR + "/pic.png")
	assert_object(loaded).is_not_null()
	assert_int(loaded.get_width()).is_equal(8)
	assert_int(loaded.get_height()).is_equal(6)


func test_png_write_is_atomic_no_tmp_left_behind() -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	Save.write_png(TMP_DIR + "/atomic.png", img)
	assert_bool(Save.list_dir(TMP_DIR).has("atomic.png.tmp")).is_false()
	assert_bool(Save.file_exists(TMP_DIR + "/atomic.png")).is_true()


func test_read_png_missing_returns_null() -> void:
	assert_object(Save.read_png(TMP_DIR + "/nope.png")).is_null()


func test_read_png_corrupt_returns_null_with_warning() -> void:
	var file: FileAccess = FileAccess.open("user://" + TMP_DIR + "/garbage.png", FileAccess.WRITE)
	file.store_string("this is not a png")
	file.close()
	assert_object(Save.read_png(TMP_DIR + "/garbage.png")).is_null()


func test_file_exists_and_globalize() -> void:
	assert_bool(Save.file_exists(TMP_DIR + "/absent.json")).is_false()
	Save.write_json(TMP_DIR + "/present.json", {"v": 1})
	assert_bool(Save.file_exists(TMP_DIR + "/present.json")).is_true()
	var abs_path: String = Save.globalize(TMP_DIR + "/present.json")
	assert_bool(abs_path.begins_with("user://")).is_false()   # OS path, not virtual
	assert_bool(FileAccess.file_exists(abs_path)).is_true()
	assert_str(Save.globalize("../escape")).is_equal("")      # traversal rejected
