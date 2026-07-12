class_name TestSessionStats
extends GdUnitTestSuite
## The Slice 10 integration contract (Slice 4 TDD §2): aggregates + event
## log agree, queries are keyed by stable uid, and the dump is v-tagged.
## Slice 19: emoji reaction tracking removed with the reaction system;
## kudos is the remaining social currency.

var _fake_now_ms: int = 100000


func _now_ms() -> int:
	return _fake_now_ms


func _make_stats() -> SessionStats:
	var stats := SessionStats.new(Callable(self, "_now_ms"))
	stats.register_drawing("d1", 0, "alice", "sleepy aardvark")
	stats.register_drawing("d2", 0, "bob", "sleepy aardvark")
	stats.register_drawing("d3", 1, "alice", "angry beaver")
	return stats


func test_queries_keyed_by_uid_not_peer() -> void:
	var stats: SessionStats = _make_stats()
	stats.record_kudos(0, "d1", "bob")
	stats.record_kudos(1, "d3", "bob")
	stats.record_kudos(0, "d2", "alice")
	assert_that(stats.kudos_received_by_author()).is_equal({"alice": 2, "bob": 1})


func test_record_winner_marks_drawing() -> void:
	var stats: SessionStats = _make_stats()
	stats.record_winner("d2")
	assert_bool((stats.drawings["d2"] as SessionStats.DrawingStats).won_round).is_true()
	assert_bool((stats.drawings["d1"] as SessionStats.DrawingStats).won_round).is_false()


func test_to_dict_round_trip() -> void:
	var stats: SessionStats = _make_stats()
	stats.record_kudos(0, "d1", "carol")
	stats.record_winner("d1")
	var dump: Dictionary = stats.to_dict()
	assert_int(int(dump["v"])).is_equal(1)
	assert_int((dump["drawings"] as Array).size()).is_equal(3)
	assert_int((dump["kudos_events"] as Array).size()).is_equal(1)
	var first: Dictionary = (dump["drawings"] as Array)[0]
	assert_str(str(first["drawing_id"])).is_equal("d1")
	assert_str(str(first["prompt_text"])).is_equal("sleepy aardvark")
	assert_bool(bool(first["won_round"])).is_true()
	assert_int(int((dump["kudos_events"] as Array)[0]["t_ms"])).is_equal(100000)
