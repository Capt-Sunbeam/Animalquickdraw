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


# --- Slice 8: read / delete / export surface ---


func _seed(prompt: String, session_id: String, doc: Dictionary = {}) -> String:
	var doc_dict: Dictionary = doc if not doc.is_empty() else _stroke_doc()
	return CollectionStore.save_drawing(doc_dict, prompt, session_id, CollectionStore.SOURCE_KUDOS)


func test_list_entries_newest_first_skipping_malformed_rows() -> void:
	var a: String = _seed("first drawing", "s-a")
	var b: String = _seed("second drawing", "s-b")
	# Inject a malformed row between valid ones.
	var index: Dictionary = Save.read_json(TEST_ROOT + "/index.json", {})
	(index["items"] as Array).append({"prompt": "row with no id"})
	Save.write_json(TEST_ROOT + "/index.json", index)
	var c: String = _seed("third drawing", "s-c")
	var entries: Array[CollectionIndexEntry] = CollectionStore.list_entries()
	assert_int(entries.size()).is_equal(3)   # malformed row skipped
	assert_str(entries[0].id).is_equal(c)    # newest first
	assert_str(entries[1].id).is_equal(b)
	assert_str(entries[2].id).is_equal(a)
	assert_str(entries[0].prompt).is_equal("third drawing")
	assert_str(entries[0].saved_date().substr(0, 2)).is_equal("20")   # ISO date prefix


func test_list_entries_empty_and_missing_index() -> void:
	assert_int(CollectionStore.list_entries().size()).is_equal(0)


func test_list_entries_rejects_newer_index_version() -> void:
	_seed("p", "s-v")
	var index: Dictionary = Save.read_json(TEST_ROOT + "/index.json", {})
	index["v"] = 99
	Save.write_json(TEST_ROOT + "/index.json", index)
	assert_int(CollectionStore.list_entries().size()).is_equal(0)


func test_read_doc_null_for_missing_corrupt_and_invalid() -> void:
	assert_object(CollectionStore.read_doc("no-such-id")).is_null()
	Save.write_json(TEST_ROOT + "/bad-doc.json", {"v": 99, "nope": true})
	assert_object(CollectionStore.read_doc("bad-doc")).is_null()   # invalid doc
	assert_object(CollectionStore.read_doc("../../etc/passwd")).is_null()  # hostile id
	var id: String = _seed("real", "s-real")
	assert_object(CollectionStore.read_doc(id)).is_not_null()


func test_delete_removes_index_row_first_then_files_and_is_idempotent() -> void:
	var id: String = _seed("goner", "s-del")
	assert_int(CollectionStore.delete(id)).is_equal(OK)
	assert_int(CollectionStore.list_entries().size()).is_equal(0)
	assert_bool(Save.file_exists("%s/%s.json" % [TEST_ROOT, id])).is_false()
	assert_bool(Save.file_exists("%s/thumbs/%s.png" % [TEST_ROOT, id])).is_false()
	assert_int(CollectionStore.delete(id)).is_equal(OK)             # idempotent
	assert_int(CollectionStore.delete("never-existed")).is_equal(OK)


func test_get_thumb_cache_hit_regeneration_and_missing_doc() -> void:
	var id: String = _seed("thumby", "s-thumb")
	var expected: Vector2i = CollectionStore.thumb_size_for(DrawingDoc.ORIENTATION_LANDSCAPE)
	# Cache hit: correct dimensions straight from disk.
	var hit: Image = CollectionStore.get_thumb(id, DrawingDoc.ORIENTATION_LANDSCAPE)
	assert_object(hit).is_not_null()
	assert_int(hit.get_width()).is_equal(expected.x)
	assert_int(hit.get_height()).is_equal(expected.y)
	# Wrong-size cached PNG (constants changed) triggers regeneration.
	var wrong := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	Save.write_png("%s/thumbs/%s.png" % [TEST_ROOT, id], wrong)
	var regen: Image = CollectionStore.get_thumb(id, DrawingDoc.ORIENTATION_LANDSCAPE)
	assert_int(regen.get_width()).is_equal(expected.x)
	var rewritten: Image = Save.read_png("%s/thumbs/%s.png" % [TEST_ROOT, id])
	assert_int(rewritten.get_width()).is_equal(expected.x)   # cache healed
	# Wiped thumbs dir regenerates too.
	Save.delete("%s/thumbs/%s.png" % [TEST_ROOT, id])
	assert_object(CollectionStore.get_thumb(id, DrawingDoc.ORIENTATION_LANDSCAPE)).is_not_null()
	# Missing doc: no thumb, no crash.
	Save.delete("%s/%s.json" % [TEST_ROOT, id])
	Save.delete("%s/thumbs/%s.png" % [TEST_ROOT, id])
	assert_object(CollectionStore.get_thumb(id, DrawingDoc.ORIENTATION_LANDSCAPE)).is_null()


func test_thumb_sizes_match_shipped_long_edge_cap() -> void:
	# Slice 4 shipped COLLECTION_THUMB_MAX_PX (200) - NOT the TDD draft's 256.
	assert_that(CollectionStore.thumb_size_for(DrawingDoc.ORIENTATION_LANDSCAPE))\
			.is_equal(Vector2i(200, 150))
	assert_that(CollectionStore.thumb_size_for(DrawingDoc.ORIENTATION_PORTRAIT))\
			.is_equal(Vector2i(150, 200))


func test_export_png_dimensions_both_orientations() -> void:
	var id_l: String = _seed("wide boi", "s-exp-l")
	var path_l: String = CollectionStore.export_png(id_l)
	assert_str(path_l).is_not_empty()
	var exported: Image = Save.read_png(path_l)
	assert_int(exported.get_width()).is_equal(800 * GameConstants.EXPORT_SCALE)
	assert_int(exported.get_height()).is_equal(600 * GameConstants.EXPORT_SCALE)
	var id_p: String = _seed("tall boi", "s-exp-p",
			{"v": 1, "orientation": "portrait", "ops": []})
	var path_p: String = CollectionStore.export_png(id_p)
	var exported_p: Image = Save.read_png(path_p)
	assert_int(exported_p.get_width()).is_equal(600 * GameConstants.EXPORT_SCALE)
	assert_int(exported_p.get_height()).is_equal(800 * GameConstants.EXPORT_SCALE)
	Save.delete(path_l)
	Save.delete(path_p)


func test_export_png_nearest_neighbor_pixel_fidelity() -> void:
	var id: String = _seed("fidelity", "s-fid")
	var source: Image = DocRasterizer.rasterize(CollectionStore.read_doc(id))
	var path: String = CollectionStore.export_png(id)
	var exported: Image = Save.read_png(path)
	# Every 2x2 block equals its source pixel (spot-check a grid incl. the
	# stroke's path - full-image comparison is slow for no extra coverage).
	for sx: int in range(0, source.get_width(), 40):
		for sy: int in range(0, source.get_height(), 40):
			var expected: Color = source.get_pixel(sx, sy)
			for dx: int in range(2):
				for dy: int in range(2):
					assert_that(exported.get_pixel(sx * 2 + dx, sy * 2 + dy))\
							.is_equal(expected)
	Save.delete(path)


func test_export_filename_slug_and_missing_doc() -> void:
	assert_str(CollectionStore.slugify("Sleepy Aardvark")).is_equal("sleepy-aardvark")
	assert_str(CollectionStore.slugify("sl/eepy: aard*vark!")).is_equal("sl-eepy-aard-vark")
	assert_str(CollectionStore.slugify("  ")).is_equal("drawing")
	assert_str(CollectionStore.slugify("日本語だけ")).is_equal("drawing")
	assert_int(CollectionStore.slugify("a".repeat(80)).length()).is_equal(40)
	var id: String = _seed("shark week", "s-slug")
	var path: String = CollectionStore.export_png(id)
	assert_str(path).is_equal("exports/shark-week_%s.png" % id.substr(0, 8))
	Save.delete(path)
	# Export of a missing doc writes nothing and returns "".
	CollectionStore.delete(id)
	assert_str(CollectionStore.export_png(id)).is_equal("")
