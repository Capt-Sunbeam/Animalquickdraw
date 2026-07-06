class_name TestEnetBackend
extends GdUnitTestSuite
## Skeleton gate: dev room-code -> localhost port mapping (skeleton §3.2).


func test_local_maps_to_base_port() -> void:
	assert_int(EnetBackend.port_for_code("LOCAL")).is_equal(24515)


func test_numbered_codes_map_to_successive_ports() -> void:
	assert_int(EnetBackend.port_for_code("LOCAL2")).is_equal(24516)
	assert_int(EnetBackend.port_for_code("LOCAL3")).is_equal(24517)
	assert_int(EnetBackend.port_for_code("LOCAL9")).is_equal(24523)


func test_codes_are_case_insensitive_and_trimmed() -> void:
	assert_int(EnetBackend.port_for_code("local")).is_equal(24515)
	assert_int(EnetBackend.port_for_code("  Local2  ")).is_equal(24516)


func test_invalid_codes_return_minus_one() -> void:
	assert_int(EnetBackend.port_for_code("")).is_equal(-1)
	assert_int(EnetBackend.port_for_code("NOPE")).is_equal(-1)
	assert_int(EnetBackend.port_for_code("LOCAL0")).is_equal(-1)
	assert_int(EnetBackend.port_for_code("LOCAL1")).is_equal(-1)
	assert_int(EnetBackend.port_for_code("LOCALx")).is_equal(-1)


func test_arg_value_extracts_named_args() -> void:
	var args: PackedStringArray = PackedStringArray(["--platform=enet", "--name=Alice", "--ci-host"])
	assert_str(EnetBackend.arg_value(args, "platform")).is_equal("enet")
	assert_str(EnetBackend.arg_value(args, "name")).is_equal("Alice")


func test_arg_value_returns_default_when_absent() -> void:
	var args: PackedStringArray = PackedStringArray(["--ci-host"])
	assert_str(EnetBackend.arg_value(args, "code", "LOCAL")).is_equal("LOCAL")
	assert_str(EnetBackend.arg_value(args, "name")).is_equal("")
