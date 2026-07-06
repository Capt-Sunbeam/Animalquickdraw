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
