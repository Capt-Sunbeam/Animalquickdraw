class_name TestLaunchArgs
extends GdUnitTestSuite
## Slice 12: cold-launch "+connect_lobby <id>" parsing (TDD 12 §11).


func test_connect_lobby_arg_parsed() -> void:
	var args := PackedStringArray(["+connect_lobby", "109775241"])
	assert_int(LaunchArgs.connect_lobby(args)).is_equal(109775241)


func test_arg_found_among_other_args() -> void:
	var args := PackedStringArray(
			["--path", ".", "+connect_lobby", "109775241", "--", "--name=P1"])
	assert_int(LaunchArgs.connect_lobby(args)).is_equal(109775241)


func test_absent_or_malformed_arg_returns_zero() -> void:
	assert_int(LaunchArgs.connect_lobby(PackedStringArray([]))).is_equal(0)
	assert_int(LaunchArgs.connect_lobby(PackedStringArray(["--name=P1"]))).is_equal(0)
	# Trailing key with no value
	assert_int(LaunchArgs.connect_lobby(PackedStringArray(["+connect_lobby"]))).is_equal(0)
	# Non-numeric id
	assert_int(LaunchArgs.connect_lobby(
			PackedStringArray(["+connect_lobby", "PYGMY"]))).is_equal(0)
	# Negative / zero ids are not lobbies
	assert_int(LaunchArgs.connect_lobby(
			PackedStringArray(["+connect_lobby", "-5"]))).is_equal(0)
	assert_int(LaunchArgs.connect_lobby(
			PackedStringArray(["+connect_lobby", "0"]))).is_equal(0)
