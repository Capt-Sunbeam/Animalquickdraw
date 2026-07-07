class_name TestKudosLedger
extends GdUnitTestSuite
## Kudos math + per-drawing bookkeeping (Slice 4 TDD §6/§11). The allotment
## examples are the design-brief table (§11) encoded as a test.


func test_kudos_allotment_rounds_half_up() -> void:
	var expected: Dictionary = {3: 1, 4: 1, 5: 1, 6: 2, 7: 2, 8: 2, 10: 3, 12: 3, 14: 4}
	for rounds: int in expected.keys():
		assert_int(KudosLedger.compute_allotment(rounds))\
				.override_failure_message("round_count %d" % rounds)\
				.is_equal(int(expected[rounds]))


func test_allotment_minimum_is_one() -> void:
	assert_int(KudosLedger.compute_allotment(1)).is_equal(1)
	assert_int(KudosLedger.compute_allotment(2)).is_equal(1)


func test_resolve_allotment_auto_derives_from_rounds() -> void:
	assert_int(KudosLedger.resolve_allotment(GameSettings.KUDOS_AUTO, 10)).is_equal(3)


func test_resolve_allotment_explicit_value_used_verbatim() -> void:
	# The min-1 clamp applies only in AUTO mode; 0 = kudos off (§10).
	assert_int(KudosLedger.resolve_allotment(0, 10)).is_equal(0)
	assert_int(KudosLedger.resolve_allotment(5, 4)).is_equal(5)
	assert_int(KudosLedger.resolve_allotment(-3, 10)).is_equal(0)  # garbage clamps to off


func test_add_kudos_accumulates_totals() -> void:
	var ledger := KudosLedger.new()
	ledger.add_kudos("d1", "alice")
	ledger.add_kudos("d1", "bob")
	ledger.add_kudos("d2", "alice")
	assert_int(ledger.total_for("d1")).is_equal(2)
	assert_int(ledger.total_for("d2")).is_equal(1)
	assert_int(ledger.total_for("unknown")).is_equal(0)
	assert_that(ledger.totals()).is_equal({"d1": 2, "d2": 1})


func test_has_given_tracks_giver_per_drawing() -> void:
	var ledger := KudosLedger.new()
	ledger.add_kudos("d1", "alice")
	assert_bool(ledger.has_given("d1", "alice")).is_true()
	assert_bool(ledger.has_given("d2", "alice")).is_false()
	assert_bool(ledger.has_given("d1", "bob")).is_false()
