class_name TestReactionLedger
extends GdUnitTestSuite
## Toggle semantics + spam bounds (Slice 4 TDD §6): at most one of each
## reaction type per player per drawing; no-op toggles report unchanged;
## the changed-toggle cap protects SessionStats.


func test_toggle_on_off_counts() -> void:
	var ledger := ReactionLedger.new()
	assert_bool(ledger.set_reaction("d1", NetIds.Reaction.LAUGH, "alice", true)).is_true()
	assert_bool(ledger.set_reaction("d1", NetIds.Reaction.LAUGH, "bob", true)).is_true()
	assert_that(ledger.counts_for("d1")).is_equal({NetIds.Reaction.LAUGH: 2})
	assert_bool(ledger.set_reaction("d1", NetIds.Reaction.LAUGH, "alice", false)).is_true()
	assert_that(ledger.counts_for("d1")).is_equal({NetIds.Reaction.LAUGH: 1})


func test_noop_toggle_reports_unchanged() -> void:
	var ledger := ReactionLedger.new()
	assert_bool(ledger.set_reaction("d1", NetIds.Reaction.FIRE, "alice", false)).is_false()
	ledger.set_reaction("d1", NetIds.Reaction.FIRE, "alice", true)
	assert_bool(ledger.set_reaction("d1", NetIds.Reaction.FIRE, "alice", true)).is_false()
	assert_that(ledger.counts_for("d1")).is_equal({NetIds.Reaction.FIRE: 1})


func test_counts_only_nonzero_keys() -> void:
	var ledger := ReactionLedger.new()
	ledger.set_reaction("d1", NetIds.Reaction.CRY, "alice", true)
	ledger.set_reaction("d1", NetIds.Reaction.CRY, "alice", false)
	assert_that(ledger.counts_for("d1")).is_equal({})
	assert_that(ledger.counts_for("never_touched")).is_equal({})


func test_reaction_types_are_independent() -> void:
	var ledger := ReactionLedger.new()
	ledger.set_reaction("d1", NetIds.Reaction.LAUGH, "alice", true)
	ledger.set_reaction("d1", NetIds.Reaction.LOVE, "alice", true)
	assert_that(ledger.counts_for("d1")).is_equal(
			{NetIds.Reaction.LAUGH: 1, NetIds.Reaction.LOVE: 1})
	assert_bool(ledger.is_active("d1", NetIds.Reaction.LAUGH, "alice")).is_true()
	assert_bool(ledger.is_active("d1", NetIds.Reaction.WOW, "alice")).is_false()


func test_event_cap_enforced() -> void:
	var ledger := ReactionLedger.new()
	# Burn the whole cap with alternating toggles (every one is a change).
	for i: int in GameConstants.REACTION_EVENT_CAP:
		assert_bool(ledger.set_reaction("d1", NetIds.Reaction.LAUGH, "masher", i % 2 == 0)).is_true()
	# Cap reached: further toggles for this (player, drawing) are dropped...
	assert_bool(ledger.set_reaction("d1", NetIds.Reaction.LAUGH, "masher", true)).is_false()
	assert_bool(ledger.set_reaction("d1", NetIds.Reaction.LOVE, "masher", true)).is_false()
	# ...but other players and other drawings are unaffected.
	assert_bool(ledger.set_reaction("d1", NetIds.Reaction.LAUGH, "calm", true)).is_true()
	assert_bool(ledger.set_reaction("d2", NetIds.Reaction.LAUGH, "masher", true)).is_true()
