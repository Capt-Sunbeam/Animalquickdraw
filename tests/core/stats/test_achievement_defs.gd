class_name TestAchievementDefs
extends GdUnitTestSuite
## Slice 14: the frozen 27-id table + condition evaluation at exact
## thresholds. The id list test is a FREEZE PIN - these are Steamworks API
## names (decision log 2026-07-12); a failure here means someone renamed a
## shipped id, which is forbidden.

const FROZEN_IDS: Array[String] = [
	"first_hotshot", "hotshot_x10",
	"first_judges_darling", "judges_darling_x10",
	"first_peoples_champion", "peoples_champion_x10",
	"first_generous_soul", "generous_soul_x10",
	"first_speed_demon", "speed_demon_x10",
	"first_da_vinci", "da_vinci_x10",
	"first_minimalist", "minimalist_x10",
	"first_game", "first_win", "games_10", "games_100",
	"rounds_100", "round_wins_25",
	"save_10", "save_50", "save_100", "all_kudos_spent",
	"title_collector", "full_lobby", "clean_sweep",
]


func _stats_with(key: String, value: int) -> Dictionary:
	return {key: value, "titles_earned": {}}


func _stats_with_title(title_id: String, count: int) -> Dictionary:
	return {"titles_earned": {title_id: count}}


func test_table_carries_exactly_the_27_frozen_ids() -> void:
	var ids: Array[String] = []
	for def: AchievementDefs.Def in AchievementDefs.all():
		ids.append(def.id)
	assert_array(ids).contains_exactly(FROZEN_IDS)


func test_every_def_has_a_working_display_name() -> void:
	for def: AchievementDefs.Def in AchievementDefs.all():
		assert_bool(def.display_name.is_empty()).is_false()


func test_counter_defs_met_exactly_at_threshold() -> void:
	for def: AchievementDefs.Def in AchievementDefs.all():
		if def.stat_key.is_empty():
			continue
		assert_bool(AchievementDefs.is_met(def,
				_stats_with(def.stat_key, def.threshold - 1)))\
				.override_failure_message("%s met below threshold" % def.id).is_false()
		assert_bool(AchievementDefs.is_met(def,
				_stats_with(def.stat_key, def.threshold)))\
				.override_failure_message("%s not met at threshold" % def.id).is_true()


func test_title_defs_met_exactly_at_threshold() -> void:
	for def: AchievementDefs.Def in AchievementDefs.all():
		if def.title_id.is_empty():
			continue
		assert_bool(AchievementDefs.is_met(def,
				_stats_with_title(def.title_id, def.threshold - 1)))\
				.override_failure_message("%s met below threshold" % def.id).is_false()
		assert_bool(AchievementDefs.is_met(def,
				_stats_with_title(def.title_id, def.threshold)))\
				.override_failure_message("%s not met at threshold" % def.id).is_true()


func test_title_collector_requires_all_seven_titles() -> void:
	var collector: AchievementDefs.Def = null
	for def: AchievementDefs.Def in AchievementDefs.all():
		if def.id == "title_collector":
			collector = def
	var earned: Dictionary = {}
	for title_id: String in TitleIds.PRIORITY:
		earned[title_id] = 1
	assert_bool(AchievementDefs.is_met(collector, {"titles_earned": earned})).is_true()
	earned.erase(TitleIds.MINIMALIST)   # any missing title blocks it
	assert_bool(AchievementDefs.is_met(collector, {"titles_earned": earned})).is_false()
	assert_bool(AchievementDefs.is_met(collector, {})).is_false()


func test_missing_counters_read_as_zero() -> void:
	for def: AchievementDefs.Def in AchievementDefs.all():
		assert_bool(AchievementDefs.is_met(def, {}))\
				.override_failure_message("%s met on empty stats" % def.id).is_false()
