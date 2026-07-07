class_name TestCustomPoolCollector
extends GdUnitTestSuite
## Slice 7: share math (§8 examples pinned), the atomic validation chain,
## completion gating, and the Slice 9 departure extension point. All
## host-side RefCounted logic - fully headless.


func before_test() -> void:
	TextFilter.configure(PackedStringArray(["badword", "worse phrase"]))


func after_test() -> void:
	TextFilter.configure(PackedStringArray())   # reload real blocklist lazily


func _collector(share: int = 2,
		pools: PackedStringArray = PackedStringArray(["animals", "adjectives"]),
		players: PackedStringArray = PackedStringArray(["p0", "p1"])) -> CustomPoolCollector:
	var c := CustomPoolCollector.new()
	c.share_per_player = share
	c.pool_ids = pools
	c.eligible_player_ids = players
	return c


func _words(list: Array) -> PackedStringArray:
	return PackedStringArray(list)


# --- share math (§8 examples are the contract) ---


func test_share_4_players_16_rounds_is_4() -> void:
	assert_int(CustomPoolCollector.compute_share(16, 4)).is_equal(4)


func test_share_4_players_8_rounds_is_2() -> void:
	assert_int(CustomPoolCollector.compute_share(8, 4)).is_equal(2)


func test_share_4_players_14_rounds_is_4() -> void:
	assert_int(CustomPoolCollector.compute_share(14, 4)).is_equal(4)   # 3.5 -> 4


func test_share_more_cases() -> void:
	assert_int(CustomPoolCollector.compute_share(7, 3)).is_equal(3)
	assert_int(CustomPoolCollector.compute_share(8, 8)).is_equal(1)
	assert_int(CustomPoolCollector.compute_share(1, 5)).is_equal(1)
	assert_int(CustomPoolCollector.compute_share(3, 3)).is_equal(1)


# --- submission validation ---


func test_submit_ok_stores_words_and_reports_progress() -> void:
	var c: CustomPoolCollector = _collector()
	assert_int(c.submit("p0", "animals", _words(["aardvark", "heron"])))\
			.is_equal(NetIds.WordRejectReason.NONE)
	assert_array(c.collected_words("animals")).contains_exactly(["aardvark", "heron"])
	var progress: Array = c.progress()
	assert_int(progress.size()).is_equal(2)
	assert_that(progress[0]).is_equal(
			{"player_id": "p0", "pools_done": 1, "pools_total": 2})
	assert_that(progress[1]).is_equal(
			{"player_id": "p1", "pools_done": 0, "pools_total": 2})


func test_submit_trims_whitespace_before_storing() -> void:
	var c: CustomPoolCollector = _collector()
	c.submit("p0", "animals", _words(["  aardvark ", "heron"]))
	assert_array(c.collected_words("animals")).contains_exactly(["aardvark", "heron"])


func test_submit_rejected_validation_matrix() -> void:
	var c: CustomPoolCollector = _collector()
	# Wrong count (atomic - nothing stored).
	assert_int(c.submit("p0", "animals", _words(["one"])))\
			.is_equal(NetIds.WordRejectReason.WRONG_COUNT)
	# Dirty word poisons the whole submission.
	assert_int(c.submit("p0", "animals", _words(["aardvark", "badword"])))\
			.is_equal(NetIds.WordRejectReason.NOT_CLEAN)
	# Empty after trim.
	assert_int(c.submit("p0", "animals", _words(["   ", "heron"])))\
			.is_equal(NetIds.WordRejectReason.BAD_LENGTH)
	# Overlong.
	assert_int(c.submit("p0", "animals", _words(["a".repeat(25), "heron"])))\
			.is_equal(NetIds.WordRejectReason.BAD_LENGTH)
	# Multiline.
	assert_int(c.submit("p0", "animals", _words(["aard\nvark", "heron"])))\
			.is_equal(NetIds.WordRejectReason.BAD_LENGTH)
	# Nothing leaked through any failed attempt.
	assert_array(c.collected_words("animals")).is_empty()


func test_submit_rejected_already_submitted_keeps_first() -> void:
	var c: CustomPoolCollector = _collector()
	c.submit("p0", "animals", _words(["aardvark", "heron"]))
	assert_int(c.submit("p0", "animals", _words(["newt", "crab"])))\
			.is_equal(NetIds.WordRejectReason.ALREADY_SUBMITTED)
	assert_array(c.collected_words("animals")).contains_exactly(["aardvark", "heron"])


func test_submit_after_lock_rejected() -> void:
	var c: CustomPoolCollector = _collector()
	c.locked = true
	assert_int(c.submit("p0", "animals", _words(["aardvark", "heron"])))\
			.is_equal(NetIds.WordRejectReason.LOCKED)


func test_non_eligible_player_and_unknown_pool_rejected() -> void:
	var c: CustomPoolCollector = _collector()
	# Late joiner is never in eligible_player_ids (§8 pool lock).
	assert_int(c.submit("late-joiner", "animals", _words(["aardvark", "heron"])))\
			.is_equal(NetIds.WordRejectReason.WRONG_COUNT)
	assert_int(c.submit("p0", "verbs", _words(["zoom", "dash"])))\
			.is_equal(NetIds.WordRejectReason.WRONG_COUNT)


func test_duplicate_words_within_and_across_players_accepted() -> void:
	var c: CustomPoolCollector = _collector()
	assert_int(c.submit("p0", "adjectives", _words(["sleepy", "sleepy"])))\
			.is_equal(NetIds.WordRejectReason.NONE)
	assert_int(c.submit("p1", "adjectives", _words(["sleepy", "angry"])))\
			.is_equal(NetIds.WordRejectReason.NONE)
	assert_array(c.collected_words("adjectives"))\
			.contains_exactly(["sleepy", "sleepy", "sleepy", "angry"])


# --- completion gating ---


func test_is_complete_only_when_all_players_all_pools() -> void:
	var c: CustomPoolCollector = _collector()
	assert_bool(c.is_complete()).is_false()
	c.submit("p0", "animals", _words(["aardvark", "heron"]))
	c.submit("p0", "adjectives", _words(["sleepy", "angry"]))
	assert_bool(c.is_complete()).is_false()   # p1 still owes both pools
	c.submit("p1", "animals", _words(["newt", "crab"]))
	assert_bool(c.is_complete()).is_false()   # p1 still owes adjectives
	c.submit("p1", "adjectives", _words(["shiny", "bored"]))
	assert_bool(c.is_complete()).is_true()


func test_mark_departed_ungates_completion() -> void:
	var c: CustomPoolCollector = _collector()
	c.submit("p0", "animals", _words(["aardvark", "heron"]))
	c.submit("p0", "adjectives", _words(["sleepy", "angry"]))
	assert_bool(c.is_complete()).is_false()
	c.mark_departed("p1")   # Slice 9: leaver no longer gates the phase
	assert_bool(c.is_complete()).is_true()


func test_collected_words_joined_order_then_entry_order() -> void:
	var c: CustomPoolCollector = _collector()
	c.submit("p1", "animals", _words(["newt", "crab"]))      # p1 submits FIRST
	c.submit("p0", "animals", _words(["aardvark", "heron"]))
	# Order follows eligible_player_ids (joined order), not arrival order.
	assert_array(c.collected_words("animals"))\
			.contains_exactly(["aardvark", "heron", "newt", "crab"])
