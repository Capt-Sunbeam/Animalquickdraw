class_name TestRoomCode
extends GdUnitTestSuite
## Slice 12: room-code generator/normalizer (TDD 12 §11).


func test_generate_uses_only_allowed_alphabet_and_length_5() -> void:
	var code: String = RoomCode.generate()
	assert_int(code.length()).is_equal(GameConstants.ROOM_CODE_LENGTH)
	for ch: String in code:
		assert_bool(GameConstants.ROOM_CODE_ALPHABET.contains(ch)).is_true()


func test_generate_10k_samples_no_ambiguous_chars() -> void:
	var forbidden: String = "0O1IL"
	for i: int in 10_000:
		var code: String = RoomCode.generate()
		for ch: String in code:
			if forbidden.contains(ch):
				fail("ambiguous char '%s' in generated code '%s'" % [ch, code])
				return


func test_normalize_uppercases_and_trims_user_input() -> void:
	assert_str(RoomCode.normalize("  pygmy ")).is_equal("PYGMY")
	assert_str(RoomCode.normalize("PyGmY")).is_equal("PYGMY")
	assert_str(RoomCode.normalize("")).is_equal("")


func test_is_valid_accepts_generated_codes() -> void:
	for i: int in 100:
		assert_bool(RoomCode.is_valid(RoomCode.generate())).is_true()


func test_is_valid_rejects_bad_length_and_alphabet() -> void:
	assert_bool(RoomCode.is_valid("")).is_false()
	assert_bool(RoomCode.is_valid("ABCD")).is_false()      # too short
	assert_bool(RoomCode.is_valid("ABCDEF")).is_false()    # too long
	assert_bool(RoomCode.is_valid("ABC0D")).is_false()     # ambiguous 0
	assert_bool(RoomCode.is_valid("ABCIL")).is_false()     # ambiguous I/L
	assert_bool(RoomCode.is_valid("abcde")).is_false()     # pre-normalize lowercase
	assert_bool(RoomCode.is_valid("LOCAL")).is_false()     # dev codes are a separate namespace
