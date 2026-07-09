class_name TestAvatarResolver
extends GdUnitTestSuite
## Slice 11 (TDD §11): the fallback chain, the deterministic house pick, and
## the shipped house-avatar content.


func _valid_avatar_doc() -> Dictionary:
	return {"v": 1, "orientation": "avatar",
			"ops": [{"t": "fill", "c": 17, "x": 256, "y": 256}]}


func test_valid_doc_resolves_drawn_with_parsed_doc() -> void:
	var resolved: AvatarResolver.Resolved = AvatarResolver.resolve(
			_valid_avatar_doc(), "Alice", "pid-a")
	assert_int(resolved.kind).is_equal(AvatarResolver.Kind.DRAWN)
	assert_object(resolved.doc).is_not_null()
	assert_str(resolved.display_name).is_equal("Alice")


func test_empty_and_invalid_docs_fall_to_name_circle() -> void:
	assert_int(AvatarResolver.resolve({}, "Alice", "pid-a").kind)\
			.is_equal(AvatarResolver.Kind.NAME_CIRCLE)
	assert_int(AvatarResolver.resolve({"v": 99, "junk": true}, "Alice", "pid-a").kind)\
			.is_equal(AvatarResolver.Kind.NAME_CIRCLE)
	# Wrong orientation is not an avatar either.
	assert_int(AvatarResolver.resolve({"v": 1, "orientation": "landscape",
			"ops": [{"t": "clear"}]}, "Alice", "pid-a").kind)\
			.is_equal(AvatarResolver.Kind.NAME_CIRCLE)


func test_zero_op_doc_is_treated_as_none() -> void:
	var resolved: AvatarResolver.Resolved = AvatarResolver.resolve(
			{"v": 1, "orientation": "avatar", "ops": []}, "Alice", "pid-a")
	assert_int(resolved.kind).is_equal(AvatarResolver.Kind.NAME_CIRCLE)


func test_no_doc_and_no_name_resolves_house_deterministically() -> void:
	var a: AvatarResolver.Resolved = AvatarResolver.resolve({}, "", "pid-a")
	var b: AvatarResolver.Resolved = AvatarResolver.resolve({}, "", "pid-a")
	assert_int(a.kind).is_equal(AvatarResolver.Kind.HOUSE)
	assert_object(a.doc).is_not_null()
	assert_int(a.house_index).is_equal(b.house_index)   # same player, same doodle
	assert_bool(a.house_index >= 0 and a.house_index < GameConstants.HOUSE_AVATAR_COUNT)\
			.is_true()


func test_house_index_distributes_and_falls_back_to_name_hash() -> void:
	var seen: Dictionary = {}
	for i: int in range(40):
		seen[AvatarResolver.house_index_for("player-%d" % i)] = true
	assert_bool(seen.size() > 1).is_true()   # not everyone gets the same face
	# Empty platform id: name hash; both empty: still a valid stable index.
	assert_int(AvatarResolver.house_index_for("", "Alice"))\
			.is_equal(AvatarResolver.house_index_for("", "Alice"))
	var both_empty: int = AvatarResolver.house_index_for("", "")
	assert_bool(both_empty >= 0 and both_empty < GameConstants.HOUSE_AVATAR_COUNT).is_true()


func test_all_shipped_house_docs_parse_as_avatar_docs() -> void:
	for i: int in GameConstants.HOUSE_AVATAR_COUNT:
		var doc: DrawingDoc = AvatarResolver.get_house_doc(i)
		assert_object(doc).is_not_null()
		assert_that(doc.orientation).is_equal(DrawingDoc.ORIENTATION_AVATAR)
		assert_bool(doc.ops.is_empty()).is_false()
	assert_int(AvatarResolver._loaded_house_count())\
			.is_equal(GameConstants.HOUSE_AVATAR_COUNT)
