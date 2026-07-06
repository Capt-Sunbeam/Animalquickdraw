class_name TestTextFilter
extends GdUnitTestSuite
## Skeleton gate: TextFilter filters against the blocklist with
## case-insensitive word-boundary matching (skeleton guide §3.8).


func after_test() -> void:
	TextFilter.configure(PackedStringArray())  # restore the disk blocklist


func test_clean_text_passes() -> void:
	TextFilter.configure(PackedStringArray(["badword"]))
	assert_bool(TextFilter.is_clean("a perfectly sleepy aardvark")).is_true()


func test_blocked_word_detected() -> void:
	TextFilter.configure(PackedStringArray(["badword"]))
	assert_bool(TextFilter.is_clean("you badword you")).is_false()


func test_matching_is_case_insensitive() -> void:
	TextFilter.configure(PackedStringArray(["badword"]))
	assert_bool(TextFilter.is_clean("BadWord")).is_false()
	assert_str(TextFilter.censor("BADWORD!")).is_equal("***!")


func test_word_boundaries_prevent_substring_false_positives() -> void:
	TextFilter.configure(PackedStringArray(["ass"]))
	assert_bool(TextFilter.is_clean("my drawing class")).is_true()
	assert_bool(TextFilter.is_clean("an assassin heron")).is_true()
	assert_bool(TextFilter.is_clean("what an ass")).is_false()


func test_censor_replaces_every_occurrence() -> void:
	TextFilter.configure(PackedStringArray(["badword", "worse"]))
	assert_str(TextFilter.censor("badword and worse and badword")).is_equal("*** and *** and ***")


func test_censor_leaves_clean_text_untouched() -> void:
	TextFilter.configure(PackedStringArray(["badword"]))
	var text: String = "sleepy aardvark draws fast"
	assert_str(TextFilter.censor(text)).is_equal(text)


func test_regex_special_characters_in_words_are_escaped() -> void:
	TextFilter.configure(PackedStringArray(["a.b"]))
	assert_bool(TextFilter.is_clean("acb")).is_true()
	assert_bool(TextFilter.is_clean("a.b")).is_false()


func test_disk_blocklist_loads_and_filters() -> void:
	TextFilter.configure(PackedStringArray())  # force disk reload
	assert_bool(TextFilter.is_clean("what the fuck")).is_false()
	assert_str(TextFilter.censor("oh SHIT")).is_equal("oh ***")
	assert_bool(TextFilter.is_clean("a wholesome walrus")).is_true()
