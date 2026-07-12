class_name TestStatsService
extends GdUnitTestSuite
## Slice 14 (TDD §11): stats accumulation from EventBus signals,
## persistence rules, and the idempotent unlock/reconcile logic with a
## recording mock backend. Drives the LIVE Stats autoload through its test
## seams (path + platform_id_override) - the real file is never touched
## (the autoload additionally self-sandboxes under the GdUnit harness).

const ME: String = "me-platform-id"
const TEST_PATH: String = "test_stats_service.json"


## Recording Steam double: stats-ready, remembers every call.
class RecordingBackend extends PlatformBackend:
	var set_calls: Array[String] = []
	var store_calls: int = 0
	var already_set: Dictionary = {}

	func is_stats_ready() -> bool:
		return true

	func steam_achievement_is_set(achievement_id: String) -> bool:
		return already_set.has(achievement_id)

	func steam_set_achievement(achievement_id: String) -> void:
		set_calls.append(achievement_id)
		already_set[achievement_id] = true

	func steam_store_stats() -> void:
		store_calls += 1


var _saved_backend: PlatformBackend = null
var _unlocks: Array[String] = []


func before_test() -> void:
	_saved_backend = Platform.backend
	Save.delete(TEST_PATH)
	Stats.path = TEST_PATH
	Stats.platform_id_override = ME
	Stats.reset_for_test()
	_unlocks.clear()
	EventBus.achievement_unlocked.connect(_capture_unlock)


func after_test() -> void:
	EventBus.achievement_unlocked.disconnect(_capture_unlock)
	Platform.backend = _saved_backend
	Save.delete(TEST_PATH)
	Stats.path = "ci_stats_gdunit.json"   # the harness sandbox default
	Stats.platform_id_override = ""
	Stats.reset_for_test()


func _capture_unlock(id: String) -> void:
	_unlocks.append(id)


func _standings(rank_by_pid: Dictionary) -> Array:
	var out: Array = []
	for pid: Variant in rank_by_pid.keys():
		out.append({"player_id": str(pid), "rank": int(rank_by_pid[pid])})
	return out


func _bundle(granted: int = 0, spent: int = 0) -> Dictionary:
	return {"kudos": {ME: {"granted": granted, "spent": spent}}}


func _end_game(rank: int = 2, granted: int = 0, spent: int = 0,
		player_count: int = 3) -> void:
	var ranks: Dictionary = {ME: rank}
	for i: int in player_count - 1:
		ranks["other%d" % i] = i + 2
	EventBus.game_ended.emit(_standings(ranks), _bundle(granted, spent))


func _resolve_round(winner: String) -> void:
	EventBus.phase_changed.emit(NetIds.Phase.RESOLUTION, {"winner_player_id": winner})


# --- accumulation ---


func test_game_ended_increments_games_played_and_win_on_rank_one() -> void:
	_end_game(1)
	assert_int(Stats.get_stat("games_played")).is_equal(1)
	assert_int(Stats.get_stat("wins")).is_equal(1)
	_end_game(2)
	assert_int(Stats.get_stat("games_played")).is_equal(2)
	assert_int(Stats.get_stat("wins")).is_equal(1)


func test_shared_rank_one_counts_as_win() -> void:
	EventBus.game_ended.emit(_standings({ME: 1, "other": 1}), _bundle())
	assert_int(Stats.get_stat("wins")).is_equal(1)


func test_titles_awarded_increments_only_local_player_titles() -> void:
	EventBus.titles_awarded.emit({
		ME: [TitleIds.HOTSHOT, TitleIds.SPEED_DEMON],   # stacked (Slice 19)
		"other": [TitleIds.MINIMALIST],
	})
	assert_int(Stats.get_title_count(TitleIds.HOTSHOT)).is_equal(1)
	assert_int(Stats.get_title_count(TitleIds.SPEED_DEMON)).is_equal(1)
	assert_int(Stats.get_title_count(TitleIds.MINIMALIST)).is_equal(0)


func test_resolution_increments_rounds_and_round_wins_for_local_winner() -> void:
	_resolve_round(ME)
	_resolve_round("other")
	assert_int(Stats.get_stat("rounds_played")).is_equal(2)
	assert_int(Stats.get_stat("round_wins")).is_equal(1)


func test_kudos_given_increments_spent_total() -> void:
	EventBus.kudos_given.emit("d1", 0)
	assert_int(Stats.get_stat("kudos_spent_total")).is_equal(1)


func test_collection_item_added_increments_drawings_saved() -> void:
	EventBus.collection_item_added.emit("item1")
	assert_int(Stats.get_stat("drawings_saved")).is_equal(1)


func test_all_kudos_spent_detected_from_bundle_granted_equals_spent() -> void:
	_end_game(2, 2, 2)
	assert_int(Stats.get_stat("kudos_games_all_spent")).is_equal(1)
	_end_game(2, 2, 1)
	assert_int(Stats.get_stat("kudos_games_all_spent")).is_equal(1)


func test_all_kudos_spent_not_credited_when_granted_zero() -> void:
	_end_game(2, 0, 0)
	assert_int(Stats.get_stat("kudos_games_all_spent")).is_equal(0)


func test_full_lobby_counted_at_eight_standings() -> void:
	_end_game(2, 0, 0, 7)
	assert_int(Stats.get_stat("games_full_lobby")).is_equal(0)
	_end_game(2, 0, 0, 8)
	assert_int(Stats.get_stat("games_full_lobby")).is_equal(1)


func test_clean_sweep_requires_min_three_rounds_all_won() -> void:
	# 3 rounds, all mine -> sweep.
	for i: int in 3:
		_resolve_round(ME)
	_end_game(1)
	assert_int(Stats.get_stat("clean_sweeps")).is_equal(1)
	# 2 rounds all won: under the minimum -> no sweep.
	for i: int in 2:
		_resolve_round(ME)
	_end_game(1)
	assert_int(Stats.get_stat("clean_sweeps")).is_equal(1)
	# 3 rounds, one lost -> no sweep.
	_resolve_round(ME)
	_resolve_round("other")
	_resolve_round(ME)
	_end_game(1)
	assert_int(Stats.get_stat("clean_sweeps")).is_equal(1)


func test_clean_sweep_transient_resets_at_lobby() -> void:
	_resolve_round(ME)
	_resolve_round(ME)
	EventBus.phase_changed.emit(NetIds.Phase.LOBBY, {})   # rematch reset
	_resolve_round(ME)
	_end_game(1)
	assert_int(Stats.get_stat("clean_sweeps")).is_equal(0)   # only 1 round seen


# --- persistence ---


func test_stats_round_trip_through_save() -> void:
	EventBus.kudos_given.emit("d1", 0)
	EventBus.collection_item_added.emit("item1")
	Stats.reset_for_test()   # reload from disk
	assert_int(Stats.get_stat("kudos_spent_total")).is_equal(1)
	assert_int(Stats.get_stat("drawings_saved")).is_equal(1)


func test_corrupt_stats_file_yields_defaults_without_crash() -> void:
	var file: FileAccess = FileAccess.open("user://" + TEST_PATH, FileAccess.WRITE)
	file.store_string("{ not json !!")
	file.close()
	Stats.reset_for_test()
	assert_int(Stats.get_stat("games_played")).is_equal(0)


func test_unknown_future_keys_preserved_on_write() -> void:
	Save.write_json(TEST_PATH, {"v": 1, "games_played": 3, "future_thing": 42})
	Stats.reset_for_test()
	EventBus.kudos_given.emit("d1", 0)   # forces a persist
	var on_disk: Dictionary = Save.read_json(TEST_PATH, {})
	assert_int(int(on_disk.get("future_thing", 0))).is_equal(42)
	assert_int(int(on_disk.get("games_played", 0))).is_equal(3)


func test_higher_version_rejected_with_defaults() -> void:
	Save.write_json(TEST_PATH, {"v": 99, "games_played": 50})
	Stats.reset_for_test()
	assert_int(Stats.get_stat("games_played")).is_equal(0)


# --- unlocks ---


func test_unlock_emits_signal_once_then_never_again() -> void:
	_end_game(2)   # games_played 1 -> first_game
	assert_array(_unlocks).contains_exactly(["first_game"])
	assert_bool(Stats.is_achievement_unlocked("first_game")).is_true()
	_end_game(2)   # further persists must not re-emit
	assert_array(_unlocks).contains_exactly(["first_game"])


func test_reconcile_noop_when_nothing_newly_met() -> void:
	EventBus.kudos_given.emit("d1", 0)   # no achievement reads this at 1
	assert_array(_unlocks).is_empty()


func test_reconcile_pushes_met_achievements_to_steam_once_per_id() -> void:
	# Accrue offline first (default backend = no Steam).
	_end_game(1)   # first_game + first_win
	assert_array(_unlocks).contains_exactly(["first_game", "first_win"])
	# Steam comes alive: the next reconcile pushes BOTH in one batch.
	var backend := RecordingBackend.new()
	Platform.backend = backend
	Stats._reconcile_achievements()
	assert_array(backend.set_calls).contains_exactly_in_any_order(
			["first_game", "first_win"])
	assert_int(backend.store_calls).is_equal(1)
	# Re-running is a no-op at the is-set guard - no new calls, no store.
	Stats._reconcile_achievements()
	assert_int(backend.set_calls.size()).is_equal(2)
	assert_int(backend.store_calls).is_equal(1)
	# And the local signal never re-fired.
	assert_array(_unlocks).contains_exactly(["first_game", "first_win"])


func test_steam_calls_skipped_entirely_on_default_backend() -> void:
	# The ENet/default backend is stats-not-ready: unlocks stay local-only
	# and nothing crashes (silent no-op contract).
	_end_game(1)
	assert_bool(Stats.is_achievement_unlocked("first_game")).is_true()
	assert_bool(Stats.is_achievement_unlocked("first_win")).is_true()


func test_title_achievements_unlock_from_awarded_titles() -> void:
	EventBus.titles_awarded.emit({ME: [TitleIds.HOTSHOT]})
	assert_array(_unlocks).contains_exactly(["first_hotshot"])
	for i: int in 9:
		EventBus.titles_awarded.emit({ME: [TitleIds.HOTSHOT]})
	assert_bool(Stats.is_achievement_unlocked("hotshot_x10")).is_true()
