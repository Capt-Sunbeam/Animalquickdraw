class_name TestScoring
extends GdUnitTestSuite
## Slice 3: score ledger + standings (TDD §11). Negative scores are legal
## everywhere - no floor (brief §11).


func test_winner_plus_two() -> void:
	var scoring := Scoring.new()
	scoring.apply_winner("alice")
	assert_int(scoring.get_score("alice")).is_equal(2)


func test_judge_no_pick_applies_minus_one() -> void:
	var scoring := Scoring.new()
	scoring.apply_no_pick_penalty("judge_id")
	assert_int(scoring.get_score("judge_id")).is_equal(-1)


func test_scores_go_negative_without_floor() -> void:
	var scoring := Scoring.new()
	for i: int in range(5):
		scoring.apply_no_pick_penalty("bob")
	assert_int(scoring.get_score("bob")).is_equal(-5)
	scoring.add_points("bob", -95)
	assert_int(scoring.get_score("bob")).is_equal(-100)


func test_unknown_player_reads_zero_and_snapshot_copies() -> void:
	var scoring := Scoring.new()
	assert_int(scoring.get_score("ghost")).is_equal(0)
	scoring.add_points("alice", 3)
	var snap: Dictionary = scoring.snapshot()
	scoring.add_points("alice", 1)
	assert_int(int(snap["alice"])).is_equal(3)  # snapshot is frozen


func test_standings_sort_desc_with_negative_scores_and_shared_rank_ties() -> void:
	var scores: Dictionary = {"a": 5, "b": 5, "c": -1, "d": 2}
	var order: Array[String] = ["a", "b", "c", "d"]  # joined_order tiebreak
	var standings: Array[Dictionary] = Scoring.standings(scores, order)
	assert_int(standings.size()).is_equal(4)
	assert_str(str(standings[0]["player_id"])).is_equal("a")
	assert_int(int(standings[0]["rank"])).is_equal(1)
	assert_str(str(standings[1]["player_id"])).is_equal("b")
	assert_int(int(standings[1]["rank"])).is_equal(1)   # tie shares rank 1
	assert_str(str(standings[2]["player_id"])).is_equal("d")
	assert_int(int(standings[2]["rank"])).is_equal(3)   # next rank skips
	assert_str(str(standings[3]["player_id"])).is_equal("c")
	assert_int(int(standings[3]["rank"])).is_equal(4)
	assert_int(int(standings[3]["score"])).is_equal(-1)  # negative, unclamped


func test_standings_tie_order_is_stable_by_tiebreak_list() -> void:
	var scores: Dictionary = {"late": 0, "early": 0}
	var order: Array[String] = ["early", "late"]
	var standings: Array[Dictionary] = Scoring.standings(scores, order)
	assert_str(str(standings[0]["player_id"])).is_equal("early")
	assert_str(str(standings[1]["player_id"])).is_equal("late")
	assert_int(int(standings[1]["rank"])).is_equal(1)
