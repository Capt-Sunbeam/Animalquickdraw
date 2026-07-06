class_name TestUuidV4
extends GdUnitTestSuite


func test_format_is_rfc4122_v4() -> void:
	var regex := RegEx.new()
	regex.compile("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	for i: int in 25:
		var id: String = UuidV4.generate()
		assert_object(regex.search(id)).is_not_null()


func test_generated_ids_are_unique() -> void:
	var seen: Dictionary = {}
	for i: int in 200:
		var id: String = UuidV4.generate()
		assert_bool(seen.has(id)).is_false()
		seen[id] = true
