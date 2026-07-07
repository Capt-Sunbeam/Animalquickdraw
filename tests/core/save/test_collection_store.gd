class_name TestCollectionStore
extends GdUnitTestSuite
## Collection write path (Slice 4 TDD §4/§6): index + doc + thumb layout,
## idempotency per session_drawing_id, corrupt-index recovery. Runs against
## a sandbox root so a real player collection is never touched.

const TEST_ROOT: String = "tests_tmp_collection"


func before_test() -> void:
	CollectionStore.root_dir = TEST_ROOT
	_wipe_test_root()


func after_test() -> void:
	_wipe_test_root()
	CollectionStore.root_dir = "collection"


func _wipe_test_root() -> void:
	for file: String in Save.list_dir(TEST_ROOT + "/thumbs"):
		Save.delete(TEST_ROOT + "/thumbs/" + file)
	for file: String in Save.list_dir(TEST_ROOT):
		Save.delete(TEST_ROOT + "/" + file)


func _blank_doc() -> Dictionary:
	return DrawingDoc.new().to_dict()


func _stroke_doc() -> Dictionary:
	return {"v": 1, "orientation": "landscape", "ops": [
		{"t": "stroke", "c": 4, "s": 1, "pts": [100.0, 100.0, 200.0, 150.0], "ts": [0.0, 0.1]},
	]}


func test_save_writes_index_doc_and_thumb() -> void:
	var item_id: String = CollectionStore.save_drawing(
			_stroke_doc(), "sleepy aardvark", "session-d1", CollectionStore.SOURCE_KUDOS)
	assert_str(item_id).is_not_empty()
	var index: Dictionary = Save.read_json(TEST_ROOT + "/index.json", {})
	var items: Array = index.get("items", [])
	assert_int(int(index.get("v", 0))).is_equal(1)
	assert_int(items.size()).is_equal(1)
	var item: Dictionary = items[0]
	assert_str(str(item["id"])).is_equal(item_id)
	assert_str(str(item["prompt"])).is_equal("sleepy aardvark")
	assert_str(str(item["orientation"])).is_equal("landscape")
	assert_str(str(item["source"])).is_equal("kudos")
	assert_str(str(item["session_drawing_id"])).is_equal("session-d1")
	assert_str(str(item["saved_at"])).is_not_empty()
	# Doc round-trips through the canonical parser.
	var doc: Dictionary = Save.read_json("%s/%s.json" % [TEST_ROOT, item_id], {})
	assert_object(DrawingDoc.from_dict(doc)).is_not_null()
	# Thumb cache exists.
	assert_bool(Save.list_dir(TEST_ROOT + "/thumbs").has(item_id + ".png")).is_true()


func test_duplicate_session_drawing_id_is_idempotent() -> void:
	var first: String = CollectionStore.save_drawing(
			_blank_doc(), "p", "session-dup", CollectionStore.SOURCE_KUDOS)
	var second: String = CollectionStore.save_drawing(
			_blank_doc(), "p", "session-dup", CollectionStore.SOURCE_KUDOS)
	assert_str(second).is_equal(first)
	var index: Dictionary = Save.read_json(TEST_ROOT + "/index.json", {})
	assert_int((index.get("items", []) as Array).size()).is_equal(1)
	assert_bool(CollectionStore.has_session_drawing("session-dup")).is_true()
	assert_bool(CollectionStore.has_session_drawing("session-other")).is_false()


func test_empty_session_ids_never_dedupe_against_each_other() -> void:
	var first: String = CollectionStore.save_drawing(_blank_doc(), "a", "", CollectionStore.SOURCE_SELF)
	var second: String = CollectionStore.save_drawing(_blank_doc(), "b", "", CollectionStore.SOURCE_SELF)
	assert_str(second).is_not_equal(first)
	var index: Dictionary = Save.read_json(TEST_ROOT + "/index.json", {})
	assert_int((index.get("items", []) as Array).size()).is_equal(2)


func test_corrupt_index_recovers_to_empty() -> void:
	DirAccess.make_dir_recursive_absolute("user://" + TEST_ROOT)
	var file: FileAccess = FileAccess.open("user://" + TEST_ROOT + "/index.json", FileAccess.WRITE)
	file.store_string("{{{ definitely not json")
	file.close()
	var item_id: String = CollectionStore.save_drawing(
			_blank_doc(), "p", "session-x", CollectionStore.SOURCE_KUDOS)
	assert_str(item_id).is_not_empty()
	var index: Dictionary = Save.read_json(TEST_ROOT + "/index.json", {})
	assert_int((index.get("items", []) as Array).size()).is_equal(1)


func test_source_field_kudos_vs_self() -> void:
	CollectionStore.save_drawing(_blank_doc(), "p", "s1", CollectionStore.SOURCE_KUDOS)
	CollectionStore.save_drawing(_blank_doc(), "p", "s2", CollectionStore.SOURCE_SELF)
	var index: Dictionary = Save.read_json(TEST_ROOT + "/index.json", {})
	var items: Array = index.get("items", [])
	assert_str(str((items[0] as Dictionary)["source"])).is_equal("kudos")
	assert_str(str((items[1] as Dictionary)["source"])).is_equal("self")


func test_malformed_doc_saves_nothing() -> void:
	var item_id: String = CollectionStore.save_drawing(
			{"v": 99, "nope": true}, "p", "s-bad", CollectionStore.SOURCE_KUDOS)
	assert_str(item_id).is_empty()
	var index: Dictionary = Save.read_json(TEST_ROOT + "/index.json", {})
	assert_int((index.get("items", []) as Array).size()).is_equal(0)


func test_portrait_orientation_recorded() -> void:
	var doc: Dictionary = {"v": 1, "orientation": "portrait", "ops": []}
	CollectionStore.save_drawing(doc, "p", "s-portrait", CollectionStore.SOURCE_KUDOS)
	var index: Dictionary = Save.read_json(TEST_ROOT + "/index.json", {})
	var item: Dictionary = (index.get("items", []) as Array)[0]
	assert_str(str(item["orientation"])).is_equal("portrait")
