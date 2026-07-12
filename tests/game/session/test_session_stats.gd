class_name TestSessionStats
extends GdUnitTestSuite
## The Slice 10 integration contract (Slice 4 TDD §2): aggregates + event
## log agree, queries are keyed by stable uid, and the dump is v-tagged.

var _fake_now_ms: int = 100000


func _now_ms() -> int:
	return _fake_now_ms


func _make_stats() -> SessionStats:
	var stats := SessionStats.new(Callable(self, "_now_ms"))
	stats.register_drawing("d1", 0, "alice", "sleepy aardvark")
	stats.register_drawing("d2", 0, "bob", "sleepy aardvark")
	stats.register_drawing("d3", 1, "alice", "angry beaver")
	return stats


func test_events_and_aggregates_agree_after_toggles() -> void:
	var stats: SessionStats = _make_stats()
	stats.record_reaction(0, "d1", NetIds.Reaction.LAUGH, "bob", true)
	stats.record_reaction(0, "d1", NetIds.Reaction.LAUGH, "carol", true)
	stats.record_reaction(0, "d1", NetIds.Reaction.LAUGH, "bob", false)
	var d1: SessionStats.DrawingStats = stats.drawings["d1"]
	assert_that(d1.reaction_counts).is_equal({NetIds.Reaction.LAUGH: 1})
	assert_int(stats.reaction_events.size()).is_equal(3)  # removes are logged too
	assert_bool(bool(stats.reaction_events[2]["added"])).is_false()


func test_removed_reaction_drops_to_nonzero_only_aggregate() -> void:
	var stats: SessionStats = _make_stats()
	stats.record_reaction(0, "d2", NetIds.Reaction.WOW, "alice", true)
	stats.record_reaction(0, "d2", NetIds.Reaction.WOW, "alice", false)
	var d2: SessionStats.DrawingStats = stats.drawings["d2"]
	assert_that(d2.reaction_counts).is_equal({})


func test_top_drawing_by_reaction_and_tie_returns_first_registered() -> void:
	var stats: SessionStats = _make_stats()
	stats.record_reaction(0, "d2", NetIds.Reaction.FIRE, "alice", true)
	stats.record_reaction(1, "d3", NetIds.Reaction.FIRE, "bob", true)
	# d2 and d3 tie at 1 - first registered (d2) wins.
	assert_str(stats.top_drawing_by_reaction(NetIds.Reaction.FIRE)).is_equal("d2")
	assert_str(stats.top_drawing_by_reaction(NetIds.Reaction.CRY)).is_equal("")
	stats.record_reaction(1, "d3", NetIds.Reaction.FIRE, "carol", true)
	assert_str(stats.top_drawing_by_reaction(NetIds.Reaction.FIRE)).is_equal("d3")


func test_queries_keyed_by_uid_not_peer() -> void:
	var stats: SessionStats = _make_stats()
	stats.record_reaction(0, "d1", NetIds.Reaction.LOVE, "bob", true)
	stats.record_reaction(1, "d3", NetIds.Reaction.LOVE, "bob", true)
	stats.record_kudos(0, "d1", "bob")
	stats.record_kudos(1, "d3", "bob")
	stats.record_kudos(0, "d2", "alice")
	var reaction_totals: Dictionary = stats.reaction_totals_by_author()
	assert_that(reaction_totals["alice"]).is_equal({NetIds.Reaction.LOVE: 2})  # d1 + d3
	assert_bool(reaction_totals.has("bob")).is_false()  # authored d2, no reactions on it
	assert_that(stats.kudos_received_by_author()).is_equal({"alice": 2, "bob": 1})


func test_reactions_given_by_counts_net_adds() -> void:
	var stats: SessionStats = _make_stats()
	stats.record_reaction(0, "d1", NetIds.Reaction.LAUGH, "bob", true)
	stats.record_reaction(0, "d2", NetIds.Reaction.WOW, "bob", true)
	stats.record_reaction(0, "d2", NetIds.Reaction.WOW, "bob", false)
	assert_int(stats.reactions_given_by("bob")).is_equal(1)
	assert_int(stats.reactions_given_by("nobody")).is_equal(0)


func test_record_winner_marks_drawing() -> void:
	var stats: SessionStats = _make_stats()
	stats.record_winner("d2")
	assert_bool((stats.drawings["d2"] as SessionStats.DrawingStats).won_round).is_true()
	assert_bool((stats.drawings["d1"] as SessionStats.DrawingStats).won_round).is_false()


func test_to_dict_round_trip() -> void:
	var stats: SessionStats = _make_stats()
	stats.record_reaction(0, "d1", NetIds.Reaction.LAUGH, "bob", true)
	stats.record_kudos(0, "d1", "carol")
	stats.record_winner("d1")
	var dump: Dictionary = stats.to_dict()
	assert_int(int(dump["v"])).is_equal(1)
	assert_int((dump["drawings"] as Array).size()).is_equal(3)
	assert_int((dump["reaction_events"] as Array).size()).is_equal(1)
	assert_int((dump["kudos_events"] as Array).size()).is_equal(1)
	var first: Dictionary = (dump["drawings"] as Array)[0]
	assert_str(str(first["drawing_id"])).is_equal("d1")
	assert_str(str(first["prompt_text"])).is_equal("sleepy aardvark")
	assert_bool(bool(first["won_round"])).is_true()
	assert_int(int((dump["reaction_events"] as Array)[0]["t_ms"])).is_equal(100000)
