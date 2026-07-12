class_name TestGameConstants
extends GdUnitTestSuite
## Constants sanity (skeleton guide §5 Verification) - values pinned to the
## design brief so accidental edits fail loudly.


func test_player_bounds_match_brief_section_3() -> void:
	assert_int(GameConstants.MIN_PLAYERS).is_equal(3)
	assert_int(GameConstants.MAX_PLAYERS).is_equal(8)
	assert_bool(GameConstants.MIN_PLAYERS <= GameConstants.MAX_PLAYERS).is_true()


func test_canvas_resolutions_are_transposes() -> void:
	assert_int(GameConstants.CANVAS_LANDSCAPE.x).is_equal(800)
	assert_int(GameConstants.CANVAS_LANDSCAPE.y).is_equal(600)
	assert_int(GameConstants.CANVAS_PORTRAIT.x).is_equal(GameConstants.CANVAS_LANDSCAPE.y)
	assert_int(GameConstants.CANVAS_PORTRAIT.y).is_equal(GameConstants.CANVAS_LANDSCAPE.x)


func test_scoring_values_match_brief_section_11() -> void:
	assert_int(GameConstants.WINNER_POINTS).is_equal(2)
	assert_int(GameConstants.KUDOS_POINTS).is_equal(1)
	assert_int(GameConstants.JUDGE_NO_PICK_POINTS).is_equal(-1)
	assert_int(GameConstants.TITLE_POINTS_VALUE).is_equal(1)


func test_kudos_formula_constants() -> void:
	assert_int(GameConstants.KUDOS_PER_ROUNDS).is_equal(4)
	assert_int(GameConstants.KUDOS_MIN_ALLOTMENT).is_equal(1)


func test_replay_cap_matches_brief_section_7() -> void:
	assert_float(GameConstants.REPLAY_MAX_DURATION_SEC).is_equal_approx(10.0, 0.001)


func test_phase_enum_has_all_nine_values() -> void:
	assert_int(NetIds.Phase.size()).is_equal(9)
	assert_int(NetIds.Phase.LOBBY).is_equal(0)
	assert_int(NetIds.Phase.PAUSED).is_equal(8)
