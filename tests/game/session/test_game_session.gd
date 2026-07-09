class_name TestGameSession
extends GdUnitTestSuite
## Slice 3: the whole round loop, headless (TDD §11). GameSession is
## RefCounted with an injectable clock and signal outputs - no network, no
## scene tree, no UI. Deadlines are driven by calling on_phase_deadline().

const FIXTURE_DIR: String = "res://tests/fixtures/prompts/"


## Controllable clock injected as GameSession's now_ms callable.
class Clock extends RefCounted:
	var ms: int = 1_000_000

	func now() -> int:
		return ms

	func advance(delta_ms: int) -> void:
		ms += delta_ms


## One test rig: session + clock + captured phase_entered emissions.
class Rig extends RefCounted:
	var session: GameSession
	var clock: Clock = Clock.new()
	var phases: Array[Dictionary] = []   # [{"phase": int, "data": Dictionary}]
	var results: Dictionary = {}

	func phase_names() -> Array[int]:
		var out: Array[int] = []
		for entry: Dictionary in phases:
			out.append(int(entry["phase"]))
		return out

	func last_data(phase: NetIds.Phase) -> Dictionary:
		for i: int in range(phases.size() - 1, -1, -1):
			if int(phases[i]["phase"]) == phase:
				return phases[i]["data"]
		return {}


func _make_rig(player_count: int = 4, round_count: int = 2,
		pool_source: GameSettings.PoolSource = GameSettings.PoolSource.BUILT_IN,
		use_fixture_pools: bool = true) -> Rig:
	var roster := Roster.new()
	for i: int in range(player_count):
		roster.register(i + 1, "p%d" % i, "Player %d" % i)
	var settings := GameSettings.new()
	settings.round_count = round_count
	settings.pool_source = pool_source
	# GRID keeps this Slice 3 suite's phase-deadline driving exact (the
	# Slice 5 ONE_AT_A_TIME beat chain is covered by TestGameSessionReveal).
	settings.reveal_style = GameSettings.RevealStyle.GRID
	var rig := Rig.new()
	rig.session = GameSession.new(settings, roster, Callable(rig.clock, "now"))
	rig.session.rng.seed = 42
	if use_fixture_pools:
		var pools := PromptPools.new()
		pools.rng.seed = 7
		pools.load_from(FIXTURE_DIR)
		rig.session.use_pools(pools)
	rig.session.phase_entered.connect(func(p: NetIds.Phase, d: Dictionary) -> void:
		rig.phases.append({"phase": p, "data": d}))
	rig.session.session_finished.connect(func(r: Dictionary) -> void:
		rig.results = r)
	return rig


func _valid_payload(op_count: int = 0) -> Dictionary:
	var ops: Array = []
	for i: int in range(op_count):
		ops.append({"t": "clear"})
	return {"doc": {"v": 1, "orientation": "landscape", "ops": ops}}


func _oversized_payload() -> Dictionary:
	var pts: Array = []
	var ts: Array = []
	for i: int in range(4096):
		pts.append(float(i % 800))
		pts.append(float(i % 600))
		ts.append(float(i) * 0.01)
	var stroke: Dictionary = {"t": "stroke", "c": 0, "s": 0, "pts": pts, "ts": ts}
	return {"doc": {"v": 1, "orientation": "landscape", "ops": [stroke, stroke, stroke]}}


## start_game + intro deadline -> DRAWING.
func _to_drawing(rig: Rig) -> void:
	rig.session.start_game()
	rig.session.on_phase_deadline()


func _to_judging(rig: Rig) -> void:
	_to_drawing(rig)
	rig.session.on_phase_deadline()  # DRAWING -> REVEAL (blanks for everyone)
	rig.session.on_phase_deadline()  # REVEAL -> JUDGING


# --- start / rotation ---


func test_start_fixes_judge_order_from_joined_order() -> void:
	var rig: Rig = _make_rig()
	rig.session.start_game()
	assert_str(rig.session.current_judge_id()).is_equal("p0")
	var intro: Dictionary = rig.last_data(NetIds.Phase.ROUND_INTRO)
	assert_str(str(intro["judge_player_id"])).is_equal("p0")
	assert_int(int(intro["round_index"])).is_equal(0)
	assert_int(int(intro["round_count"])).is_equal(2)


func test_judge_rotation_wraps_after_last_player() -> void:
	var rig: Rig = _make_rig(4, 6)
	rig.session.start_game()
	var seen_judges: Array[String] = [rig.session.current_judge_id()]
	for round_n: int in range(5):
		for i: int in range(5):  # intro->draw->reveal->judge->resolution->next
			rig.session.on_phase_deadline()
		seen_judges.append(rig.session.current_judge_id())
	assert_array(seen_judges).contains_exactly(["p0", "p1", "p2", "p3", "p0", "p1"])


func test_full_phase_sequence_intro_to_wrapup() -> void:
	var rig: Rig = _make_rig(3, 2)
	rig.session.start_game()
	for i: int in range(10):  # 2 rounds x 5 deadlines
		rig.session.on_phase_deadline()
	assert_array(rig.phase_names()).contains_exactly([
		NetIds.Phase.ROUND_INTRO, NetIds.Phase.DRAWING, NetIds.Phase.REVEAL,
		NetIds.Phase.JUDGING, NetIds.Phase.RESOLUTION,
		NetIds.Phase.ROUND_INTRO, NetIds.Phase.DRAWING, NetIds.Phase.REVEAL,
		NetIds.Phase.JUDGING, NetIds.Phase.RESOLUTION,
		NetIds.Phase.WRAP_UP,
	])
	assert_bool(rig.results.is_empty()).is_false()


# --- Slice 7: POOL_SETUP ---


## Submits one full share to every pool for one player (all-valid words).
func _submit_pool_share(rig: Rig, player_id: String) -> void:
	var data: Dictionary = rig.last_data(NetIds.Phase.POOL_SETUP)
	var share: int = int(data["share_per_player"])
	for pool_id: String in data["pool_ids"]:
		var words := PackedStringArray()
		for i: int in range(share):
			words.append("%s %s %d" % [player_id, pool_id, i])
		assert_int(rig.session.submit_pool_words(player_id, pool_id, words))\
				.is_equal(NetIds.WordRejectReason.NONE)


func test_pool_setup_entered_with_player_created_source_and_no_deadline_timer() -> void:
	var rig: Rig = _make_rig(4, 2, GameSettings.PoolSource.PLAYER_CREATED)
	rig.session.start_game()
	assert_bool(rig.session.pool_setup_entered).is_true()
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.POOL_SETUP)
	# The phase has NO deadline - it ends by completion or host action only.
	assert_int(rig.session.get_deadline_ms()).is_equal(0)
	var data: Dictionary = rig.last_data(NetIds.Phase.POOL_SETUP)
	assert_bool(data.has("deadline_ms")).is_false()
	assert_int(int(data["share_per_player"])).is_equal(1)   # ceil(2/4)
	assert_array(Array(data["pool_ids"]))\
			.contains_exactly(["adjectives", "animals"])    # PoolType draw order
	assert_that((data["pool_display_names"] as Dictionary)["animals"]).is_equal("Animals")
	assert_int(int(data["force_available_at_ms"])).is_equal(
			rig.clock.ms + int(GameConstants.POOL_SETUP_FORCE_AVAILABLE_SEC * 1000.0))


func test_all_submitted_locks_and_begins_round_zero() -> void:
	var rig: Rig = _make_rig(4, 2, GameSettings.PoolSource.PLAYER_CREATED)
	rig.session.start_game()
	var progress_events: Array = []
	rig.session.pool_setup_progress_changed.connect(
			func(p: Array) -> void: progress_events.append(p))
	for pid: String in ["p0", "p1", "p2"]:
		_submit_pool_share(rig, pid)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.POOL_SETUP)
	_submit_pool_share(rig, "p3")   # last share completes the phase
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.ROUND_INTRO)
	assert_int(int(rig.last_data(NetIds.Phase.ROUND_INTRO)["round_index"])).is_equal(0)
	# Progress broadcast fired per accepted submission (2 pools x 4 players),
	# with display names resolved for the waiting panel.
	assert_int(progress_events.size()).is_equal(8)
	assert_str(str(((progress_events[0] as Array)[0] as Dictionary)["display_name"]))\
			.is_equal("Player 0")
	# Post-lock submissions are dropped (LOCKED tier - no rejection signal).
	assert_int(rig.session.submit_pool_words("p0", "animals",
			PackedStringArray(["late"]))).is_equal(NetIds.WordRejectReason.LOCKED)


func test_rejection_signal_only_for_eligible_honest_failures() -> void:
	var rig: Rig = _make_rig(4, 2, GameSettings.PoolSource.PLAYER_CREATED)
	rig.session.start_game()
	var rejections: Array = []
	rig.session.pool_words_rejected.connect(
			func(pid: String, pool: String, reason: int) -> void:
				rejections.append({"pid": pid, "pool": pool, "reason": reason}))
	# Honest failure from an eligible player: wrong word count -> signal.
	rig.session.submit_pool_words("p0", "animals", PackedStringArray(["a", "b"]))
	assert_int(rejections.size()).is_equal(1)
	assert_that(rejections[0]).is_equal({"pid": "p0", "pool": "animals",
			"reason": NetIds.WordRejectReason.WRONG_COUNT})
	# Drop-tier: unknown sender and unknown pool emit nothing.
	rig.session.submit_pool_words("stranger", "animals", PackedStringArray(["a"]))
	rig.session.submit_pool_words("p0", "verbs", PackedStringArray(["a"]))
	assert_int(rejections.size()).is_equal(1)


func test_force_lock_rejected_before_unlock_time() -> void:
	var rig: Rig = _make_rig(4, 2, GameSettings.PoolSource.PLAYER_CREATED)
	rig.session.start_game()
	rig.clock.advance(int(GameConstants.POOL_SETUP_FORCE_AVAILABLE_SEC * 1000.0) - 1)
	assert_bool(rig.session.force_lock_pools()).is_false()
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.POOL_SETUP)


func test_force_lock_after_unlock_starts_with_shortfall() -> void:
	var rig: Rig = _make_rig(4, 2, GameSettings.PoolSource.PLAYER_CREATED)
	rig.session.start_game()
	_submit_pool_share(rig, "p0")   # only one player ever submits
	rig.clock.advance(int(GameConstants.POOL_SETUP_FORCE_AVAILABLE_SEC * 1000.0) + 1)
	assert_bool(rig.session.force_lock_pools()).is_true()
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.ROUND_INTRO)


func test_lock_idempotent_under_submission_force_race() -> void:
	var rig: Rig = _make_rig(4, 2, GameSettings.PoolSource.PLAYER_CREATED)
	rig.session.start_game()
	for pid: String in ["p0", "p1", "p2", "p3"]:
		_submit_pool_share(rig, pid)   # completion locks + begins round 0
	rig.clock.advance(int(GameConstants.POOL_SETUP_FORCE_AVAILABLE_SEC * 1000.0) + 1)
	assert_bool(rig.session.force_lock_pools()).is_false()   # race loser drops
	var intro_count: int = 0
	for entry: Dictionary in rig.phases:
		if int(entry["phase"]) == NetIds.Phase.ROUND_INTRO:
			intro_count += 1
	assert_int(intro_count).is_equal(1)   # _begin_round(0) ran exactly once


func test_round_count_and_share_unchanged_by_roster_changes_during_setup() -> void:
	# §8 pool lock: the declared round count and shares are snapshotted at
	# Start; roster churn during POOL_SETUP (Slice 9 departures) never
	# changes them.
	var roster := Roster.new()
	for i: int in range(4):
		roster.register(i + 1, "p%d" % i, "Player %d" % i)
	var settings := GameSettings.new()
	settings.round_count = 14
	settings.pool_source = GameSettings.PoolSource.PLAYER_CREATED
	settings.reveal_style = GameSettings.RevealStyle.GRID
	var rig := Rig.new()
	rig.session = GameSession.new(settings, roster, Callable(rig.clock, "now"))
	rig.session.rng.seed = 42
	var pools := PromptPools.new()
	pools.rng.seed = 7
	pools.load_from(FIXTURE_DIR)
	rig.session.use_pools(pools)
	rig.session.phase_entered.connect(func(p: NetIds.Phase, d: Dictionary) -> void:
		rig.phases.append({"phase": p, "data": d}))
	rig.session.start_game()
	assert_int(int(rig.last_data(NetIds.Phase.POOL_SETUP)["share_per_player"]))\
			.is_equal(4)   # ceil(14/4)
	roster.remove_by_peer(4)   # a player leaves mid-setup
	for pid: String in ["p0", "p1", "p2"]:
		_submit_pool_share(rig, pid)
	rig.clock.advance(int(GameConstants.POOL_SETUP_FORCE_AVAILABLE_SEC * 1000.0) + 1)
	assert_bool(rig.session.force_lock_pools()).is_true()
	# Round count locked at Start - 14 despite the departure.
	assert_int(int(rig.last_data(NetIds.Phase.ROUND_INTRO)["round_count"])).is_equal(14)


# --- submissions ---


func test_drawing_ends_early_when_all_drawers_ready_not_on_submit() -> void:
	# Slice 17: submitting alone never ends the phase; the ready-up set does.
	var rig: Rig = _make_rig()
	_to_drawing(rig)
	assert_bool(rig.session.submit_drawing("p1", _valid_payload())).is_true()
	assert_bool(rig.session.submit_drawing("p2", _valid_payload())).is_true()
	assert_bool(rig.session.submit_drawing("p3", _valid_payload())).is_true()
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.DRAWING)
	assert_bool(rig.session.set_ready("p1", true)).is_true()
	assert_bool(rig.session.set_ready("p2", true)).is_true()
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.DRAWING)
	assert_bool(rig.session.set_ready("p3", true)).is_true()
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.REVEAL)


func test_missing_drawer_gets_blank_submission_that_appears_in_entries() -> void:
	var rig: Rig = _make_rig()
	_to_drawing(rig)
	rig.session.submit_drawing("p1", _valid_payload(2))
	rig.session.on_phase_deadline()  # deadline: p2/p3 get blanks
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL)["entries"]
	assert_int(entries.size()).is_equal(3)
	var blank_count: int = 0
	for entry: Dictionary in entries:
		var ops: Array = (entry["doc"] as Dictionary)["ops"]
		if ops.is_empty():
			blank_count += 1
	assert_int(blank_count).is_equal(2)


func test_submission_within_grace_accepted_after_deadline() -> void:
	var rig: Rig = _make_rig()
	_to_drawing(rig)
	rig.clock.advance(30 * 1000 + GameConstants.SUBMIT_GRACE_MS - 100)
	assert_bool(rig.session.submit_drawing("p1", _valid_payload())).is_true()


func test_late_submission_after_grace_is_dropped() -> void:
	var rig: Rig = _make_rig()
	_to_drawing(rig)
	rig.clock.advance(30 * 1000 + GameConstants.SUBMIT_GRACE_MS + 100)
	assert_bool(rig.session.submit_drawing("p1", _valid_payload())).is_false()


func test_resubmission_replaces_earlier_submission() -> void:
	var rig: Rig = _make_rig()
	_to_drawing(rig)
	rig.session.submit_drawing("p1", _valid_payload(1))
	rig.session.submit_drawing("p1", _valid_payload(3))  # latest wins
	rig.session.on_phase_deadline()
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL)["entries"]
	var op_counts: Array[int] = []
	for entry: Dictionary in entries:
		op_counts.append(((entry["doc"] as Dictionary)["ops"] as Array).size())
	assert_array(op_counts).contains([3])
	assert_array(op_counts).not_contains([1])


func test_submission_rejected_wrong_phase_wrong_role_oversized_invalid_doc() -> void:
	var rig: Rig = _make_rig()
	rig.session.start_game()  # ROUND_INTRO - wrong phase
	assert_bool(rig.session.submit_drawing("p1", _valid_payload())).is_false()
	rig.session.on_phase_deadline()  # -> DRAWING
	assert_bool(rig.session.submit_drawing("p0", _valid_payload())).is_false()   # judge
	assert_bool(rig.session.submit_drawing("nope", _valid_payload())).is_false() # stranger
	assert_bool(rig.session.submit_drawing("p1", {})).is_false()                 # no doc
	assert_bool(rig.session.submit_drawing("p1", _oversized_payload())).is_false()
	assert_bool(rig.session.submit_drawing("p1",
			{"doc": {"v": 1, "orientation": "landscape", "ops": [{"t": "nope"}]}})).is_false()
	# Sanity: a valid one still lands after all the rejects.
	assert_bool(rig.session.submit_drawing("p1", _valid_payload())).is_true()


func test_reveal_entries_contain_no_author_info_and_are_shuffled() -> void:
	var rig: Rig = _make_rig(5)  # judge p0 + 4 drawers
	_to_drawing(rig)
	# Distinguishable docs: drawer pN submits N clear-ops.
	rig.session.submit_drawing("p1", _valid_payload(1))
	rig.session.submit_drawing("p2", _valid_payload(2))
	rig.session.submit_drawing("p3", _valid_payload(3))
	rig.session.submit_drawing("p4", _valid_payload(4))
	for pid: String in ["p1", "p2", "p3", "p4"]:
		rig.session.set_ready(pid, true)   # Slice 17: ready ends the phase
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL)["entries"]
	assert_int(entries.size()).is_equal(4)
	var ids: Dictionary = {}
	var op_counts: Array[int] = []
	for entry: Dictionary in entries:
		# caption key removed by Slice 16 - text lives inside the doc.
		assert_array(entry.keys()).contains_exactly_in_any_order(
				["drawing_id", "doc"])
		assert_str(str(entry["drawing_id"])).is_not_empty()
		ids[str(entry["drawing_id"])] = true
		op_counts.append(((entry["doc"] as Dictionary)["ops"] as Array).size())
	assert_int(ids.size()).is_equal(4)  # unique opaque ids
	assert_array(op_counts).contains_exactly_in_any_order([1, 2, 3, 4])
	# Seeded host RNG (42): shuffled order must differ from submission order.
	assert_array(op_counts).is_not_equal([1, 2, 3, 4])


# --- judging / scoring ---


## Latched-pick semantics (owner, 2026-07-06): a valid pick does NOT end the
## phase - the judging window runs out and the deadline crowns the latch.
func test_pick_winner_latches_and_deadline_applies_plus_two() -> void:
	var rig: Rig = _make_rig()
	_to_judging(rig)
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL)["entries"]
	var target: String = str((entries[0] as Dictionary)["drawing_id"])
	assert_bool(rig.session.pick_winner("p0", target)).is_true()
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.JUDGING)  # no early end
	rig.session.on_phase_deadline()   # the timer is what crowns
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.RESOLUTION)
	var data: Dictionary = rig.last_data(NetIds.Phase.RESOLUTION)
	assert_bool(bool(data["picked"])).is_true()
	assert_str(str(data["winner_drawing_id"])).is_equal(target)
	assert_str(str(data["winner_player_id"])).is_not_empty()
	assert_str(str(data["winner_display_name"])).is_not_empty()
	var scores: Dictionary = data["scores"]
	assert_int(int(scores[str(data["winner_player_id"])])).is_equal(GameConstants.WINNER_POINTS)


## The judge may change the latched pick any number of times before the
## deadline; the last latch wins and earlier ones leave no score trace.
func test_repick_overwrites_latch_last_pick_wins() -> void:
	var rig: Rig = _make_rig()
	_to_judging(rig)
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL)["entries"]
	var first: String = str((entries[0] as Dictionary)["drawing_id"])
	var second: String = str((entries[1] as Dictionary)["drawing_id"])
	assert_bool(rig.session.pick_winner("p0", first)).is_true()
	assert_bool(rig.session.pick_winner("p0", second)).is_true()
	rig.session.on_phase_deadline()
	var data: Dictionary = rig.last_data(NetIds.Phase.RESOLUTION)
	assert_str(str(data["winner_drawing_id"])).is_equal(second)
	var scores: Dictionary = data["scores"]
	var total: int = 0
	for pid: Variant in scores:
		total += int(scores[pid])
	assert_int(total).is_equal(GameConstants.WINNER_POINTS)  # exactly one award


func test_pick_winner_rejected_when_not_judge_or_wrong_phase_or_unknown_id() -> void:
	var rig: Rig = _make_rig()
	_to_drawing(rig)
	rig.session.on_phase_deadline()  # -> REVEAL
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL)["entries"]
	var target: String = str((entries[0] as Dictionary)["drawing_id"])
	assert_bool(rig.session.pick_winner("p0", target)).is_false()   # wrong phase (REVEAL)
	rig.session.on_phase_deadline()  # -> JUDGING
	assert_bool(rig.session.pick_winner("p1", target)).is_false()   # not the judge
	assert_bool(rig.session.pick_winner("p0", "bogus-id")).is_false()
	assert_bool(rig.session.pick_winner("p0", target)).is_true()


## A crowned latch must not leak into the next round: round 2's window
## lapsing with no pick is a no-pick, not a re-crown of round 1's winner.
func test_latch_resets_between_rounds() -> void:
	var rig: Rig = _make_rig()
	_to_judging(rig)
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL)["entries"]
	rig.session.pick_winner("p0", str((entries[0] as Dictionary)["drawing_id"]))
	rig.session.on_phase_deadline()  # JUDGING -> RESOLUTION (round 1 crowned)
	rig.session.on_phase_deadline()  # RESOLUTION -> ROUND_INTRO (round 2)
	rig.session.on_phase_deadline()  # -> DRAWING
	rig.session.on_phase_deadline()  # -> REVEAL
	rig.session.on_phase_deadline()  # -> JUDGING
	rig.session.on_phase_deadline()  # window lapses, judge p1 never picked
	var data: Dictionary = rig.last_data(NetIds.Phase.RESOLUTION)
	assert_bool(bool(data["picked"])).is_false()
	assert_int(int((data["scores"] as Dictionary)["p1"]))\
			.is_equal(GameConstants.JUDGE_NO_PICK_POINTS)


func test_no_pick_applies_minus_one_to_judge() -> void:
	var rig: Rig = _make_rig()
	_to_judging(rig)
	rig.session.on_phase_deadline()  # judging window lapses
	var data: Dictionary = rig.last_data(NetIds.Phase.RESOLUTION)
	assert_bool(bool(data["picked"])).is_false()
	assert_int(int((data["scores"] as Dictionary)["p0"]))\
			.is_equal(GameConstants.JUDGE_NO_PICK_POINTS)


func test_pick_after_deadline_race_is_dropped_and_scores_once() -> void:
	var rig: Rig = _make_rig()
	_to_judging(rig)
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL)["entries"]
	var target: String = str((entries[0] as Dictionary)["drawing_id"])
	rig.session.on_phase_deadline()  # deadline wins the race
	assert_bool(rig.session.pick_winner("p0", target)).is_false()
	var scores: Dictionary = rig.session.scores()
	var total: int = 0
	for pid: Variant in scores:
		total += int(scores[pid])
	assert_int(total).is_equal(GameConstants.JUDGE_NO_PICK_POINTS)  # scored exactly once


# --- clock / pause ---


func test_deadline_ms_uses_injected_clock_plus_duration() -> void:
	var rig: Rig = _make_rig()
	rig.clock.ms = 5_000_000
	rig.session.start_game()
	var intro: Dictionary = rig.last_data(NetIds.Phase.ROUND_INTRO)
	assert_int(int(intro["deadline_ms"]))\
			.is_equal(5_000_000 + int(GameConstants.ROUND_INTRO_SEC * 1000.0))


func test_pause_resume_reissues_remaining_deadline() -> void:
	var rig: Rig = _make_rig()
	_to_drawing(rig)
	var original_deadline: int = int(rig.last_data(NetIds.Phase.DRAWING)["deadline_ms"])
	rig.clock.advance(10_000)
	rig.session.pause(0)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.PAUSED)
	rig.clock.advance(60_000)  # a long pause must not eat the remaining time
	rig.session.resume()
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.DRAWING)
	var reissued: Dictionary = rig.last_data(NetIds.Phase.DRAWING)
	var expected: int = rig.clock.ms + (original_deadline - (original_deadline - 20_000))
	assert_int(int(reissued["deadline_ms"])).is_equal(rig.clock.ms + 20_000)
	assert_str(str(reissued["prompt_text"])).is_not_empty()  # data preserved
	assert_int(expected).is_greater(0)  # (clarity var - remaining was 20 s)


# --- results ---


func test_results_bundle_shape_rounds_scores_standings_reserved_keys() -> void:
	var rig: Rig = _make_rig(4, 2)
	rig.session.start_game()
	for i: int in range(10):
		rig.session.on_phase_deadline()  # both rounds lapse with no picks
	var results: Dictionary = rig.results
	assert_int(int(results["v"])).is_equal(1)
	var rounds: Array = results["rounds"]
	assert_int(rounds.size()).is_equal(2)
	assert_array((rounds[0] as Dictionary).keys()).contains_exactly_in_any_order([
		"round_index", "judge_player_id", "prompt_text",
		"winner_player_id", "winner_drawing_id", "picked",
	])
	assert_bool(bool((rounds[0] as Dictionary)["picked"])).is_false()
	var final_scores: Dictionary = results["final_scores"]
	assert_int(final_scores.size()).is_equal(4)
	assert_int(int(final_scores["p0"])).is_equal(-1)  # judged round 0, no pick
	assert_int(int(final_scores["p1"])).is_equal(-1)  # judged round 1, no pick
	var standings: Array = results["standings"]
	assert_int(standings.size()).is_equal(4)
	assert_array((standings[0] as Dictionary).keys()).contains_exactly_in_any_order([
		"player_id", "score", "rank",
	])
	# p2/p3 tie at 0 (rank 1); p0/p1 tie at -1 (rank 3).
	assert_int(int((standings[0] as Dictionary)["rank"])).is_equal(1)
	assert_int(int((standings[2] as Dictionary)["rank"])).is_equal(3)
	# Slice 4 fills the formerly-reserved keys with uid-keyed aggregates;
	# a game with no reactions/kudos carries empty rollups.
	assert_dict(results["reaction_stats"]).is_equal({"totals_by_author": {}})
	assert_dict(results["kudos_stats"]).is_equal(
			{"received_by_author": {}, "drawing_totals": {}})


# --- Slice 10: wrap-up bundle rides the results (one replication channel) ---


func test_results_carry_valid_wrap_up_bundle_on_natural_end() -> void:
	var rig: Rig = _make_rig(4, 2)
	rig.session.start_game()
	for i: int in range(10):
		rig.session.on_phase_deadline()   # both rounds lapse: blanks, no picks
	var wrap: Dictionary = rig.results["wrap_up"]
	assert_int(int(wrap["v"])).is_equal(1)
	assert_bool(bool(wrap["early_end"])).is_false()
	assert_int(int(wrap["rounds_completed"])).is_equal(2)
	var standings: Array = wrap["standings"]
	assert_int(standings.size()).is_equal(4)
	for raw: Variant in standings:
		var row: Dictionary = raw
		assert_array(row.keys()).contains_exactly_in_any_order(["player_id",
				"display_name", "rank", "base_score", "title_points",
				"final_score", "connected"])
		assert_int(int(row["final_score"]))\
				.is_equal(int(row["base_score"]) + int(row["title_points"]))
	# All-blank game: no reactions -> zero superlatives; Worst Drawer still
	# lands (empty submissions count, §10) and its point shifts the standings.
	assert_array(wrap["superlatives"]).is_empty()
	var title_ids: Array[String] = []
	for t: Variant in wrap["titles"]:
		title_ids.append(str((t as Dictionary)["id"]))
	assert_array(title_ids).contains(["worst_drawer"])


func test_end_game_early_carries_early_bundle_and_is_idempotent() -> void:
	var roster := Roster.new()
	for i: int in range(3):
		roster.register(i + 1, "p%d" % i, "Player %d" % i)
	var settings := GameSettings.new()
	settings.round_count = 2
	settings.reveal_style = GameSettings.RevealStyle.GRID
	var clock := Clock.new()
	var session := GameSession.new(settings, roster, Callable(clock, "now"))
	session.rng.seed = 42
	var pools := PromptPools.new()
	pools.rng.seed = 7
	pools.load_from(FIXTURE_DIR)
	session.use_pools(pools)
	# Mutated (not reassigned) inside the lambdas - captures are by-value.
	var captured: Dictionary = {"wrap_up_entries": 0, "results": {}}
	session.phase_entered.connect(func(p: NetIds.Phase, _d: Dictionary) -> void:
		if p == NetIds.Phase.WRAP_UP:
			captured["wrap_up_entries"] = int(captured["wrap_up_entries"]) + 1)
	session.session_finished.connect(func(r: Dictionary) -> void:
		captured["results"] = r)
	session.start_game()
	session.on_phase_deadline()   # -> DRAWING (round 0, never completes)
	var leaver: Roster.PlayerState = roster.mark_disconnected(2, clock.now())
	session.handle_departure(leaver)   # 2 connected < MIN_PLAYERS -> pause
	assert_bool(session.is_paused()).is_true()
	session.end_game_early()
	var results: Dictionary = captured["results"]
	assert_bool(bool(results["ended_early"])).is_true()
	var wrap: Dictionary = results["wrap_up"]
	assert_bool(bool(wrap["early_end"])).is_true()
	assert_int(int(wrap["rounds_completed"])).is_equal(0)   # partial round = nothing
	var standings: Array = wrap["standings"]
	assert_int(standings.size()).is_equal(3)   # disconnected player appears
	var disconnected_seen: bool = false
	for raw: Variant in standings:
		if str((raw as Dictionary)["player_id"]) == "p1":
			disconnected_seen = true
			assert_bool(bool((raw as Dictionary)["connected"])).is_false()
	assert_bool(disconnected_seen).is_true()
	# Double entry (early-end raced with anything) is a no-op.
	session.end_game_early()
	assert_int(int(captured["wrap_up_entries"])).is_equal(1)


func test_reveal_order_recorded_matches_broadcast_entry_order() -> void:
	var rig: Rig = _make_rig(4, 1)
	_to_drawing(rig)
	for pid: String in ["p1", "p2", "p3"]:
		assert_bool(rig.session.submit_drawing(pid, _valid_payload(1))).is_true()
	rig.session.on_phase_deadline()   # -> REVEAL (shuffled)
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL)["entries"]
	for i: int in range(10):
		rig.session.on_phase_deadline()
		if rig.session.get_phase() == NetIds.Phase.WRAP_UP:
			break
	var wrap: Dictionary = rig.results["wrap_up"]
	assert_int(int(wrap["rounds_completed"])).is_equal(1)
	# The recorded reveal order (superlative tie-break key) is exactly the
	# broadcast entry order.
	var broadcast_ids: Array[String] = []
	for entry: Variant in entries:
		broadcast_ids.append(str((entry as Dictionary)["drawing_id"]))
	# Reach the record through a fresh bundle build - infos are ordered by
	# reveal_index, so the first three info-ordered ids must match.
	var infos: Array[Dictionary] = WrapUpCalculator.drawing_infos(
			rig.session._records, rig.session._session_stats)
	var info_ids: Array[String] = []
	for info: Dictionary in infos:
		info_ids.append(str(info["drawing_id"]))
	assert_array(info_ids).is_equal(broadcast_ids)


# --- integration: full scripted game (sim harness) ---


func test_sim_harness_full_8_round_game_with_scripted_picks() -> void:
	# Real built-in pools: 8 rounds cannot exhaust the combo space.
	var rig: Rig = _make_rig(4, 8, GameSettings.PoolSource.BUILT_IN, false)
	rig.session.start_game()
	var judges: Array[String] = []
	var prompts: Dictionary = {}
	var picks: int = 0
	while rig.session.get_phase() != NetIds.Phase.WRAP_UP:
		match rig.session.get_phase():
			NetIds.Phase.ROUND_INTRO:
				judges.append(rig.session.current_judge_id())
				rig.session.on_phase_deadline()
			NetIds.Phase.DRAWING:
				var judge: String = rig.session.current_judge_id()
				for pid: String in ["p0", "p1", "p2", "p3"]:
					if pid != judge:
						assert_bool(rig.session.submit_drawing(pid, _valid_payload(1))).is_true()
				for pid: String in ["p0", "p1", "p2", "p3"]:
					if pid != judge:
						assert_bool(rig.session.set_ready(pid, true)).is_true()
				# All ready -> REVEAL entered automatically (Slice 17 early end).
				assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.REVEAL)
				prompts[str(rig.last_data(NetIds.Phase.DRAWING)["prompt_text"])] = true
			NetIds.Phase.REVEAL:
				rig.session.on_phase_deadline()
			NetIds.Phase.JUDGING:
				var entries: Array = rig.last_data(NetIds.Phase.REVEAL)["entries"]
				var target: String = str((entries[0] as Dictionary)["drawing_id"])
				assert_bool(rig.session.pick_winner(rig.session.current_judge_id(), target)).is_true()
				picks += 1
				rig.session.on_phase_deadline()  # latched pick crowns at deadline
			NetIds.Phase.RESOLUTION:
				rig.session.on_phase_deadline()
			_:
				fail("unexpected phase %d" % rig.session.get_phase())
				return
	# Every player judged exactly twice (8 rounds / 4 players).
	assert_int(judges.size()).is_equal(8)
	for pid: String in ["p0", "p1", "p2", "p3"]:
		assert_int(judges.count(pid)).is_equal(2)
	# No combo repeated within the session.
	assert_int(prompts.size()).is_equal(8)
	# Final scores are the sum of round results: 8 picks x +2, no penalties.
	var total: int = 0
	for pid: Variant in rig.results["final_scores"]:
		total += int((rig.results["final_scores"] as Dictionary)[pid])
	assert_int(total).is_equal(8 * GameConstants.WINNER_POINTS)
	assert_int(picks).is_equal(8)


# --- integration: Slice 7 player-created pools, end-to-end ---


## Rig with a handle on the PromptPools instance (leftover-word assertions).
func _make_pools_rig(round_count: int) -> Array:
	var roster := Roster.new()
	for i: int in range(4):
		roster.register(i + 1, "p%d" % i, "Player %d" % i)
	var settings := GameSettings.new()
	settings.round_count = round_count
	settings.pool_source = GameSettings.PoolSource.PLAYER_CREATED
	settings.reveal_style = GameSettings.RevealStyle.GRID
	var rig := Rig.new()
	rig.session = GameSession.new(settings, roster, Callable(rig.clock, "now"))
	rig.session.rng.seed = 42
	var pools := PromptPools.new()
	pools.rng.seed = 7
	pools.load_from(FIXTURE_DIR)
	rig.session.use_pools(pools)
	rig.session.phase_entered.connect(func(p: NetIds.Phase, d: Dictionary) -> void:
		rig.phases.append({"phase": p, "data": d}))
	rig.session.session_finished.connect(func(r: Dictionary) -> void:
		rig.results = r)
	return [rig, pools]


## Submits a full share for player_id, recording the words into `submitted`
## (pool_id -> Dictionary of words) for later prompt-membership checks.
func _submit_recorded_share(rig: Rig, player_id: String, submitted: Dictionary) -> void:
	var data: Dictionary = rig.last_data(NetIds.Phase.POOL_SETUP)
	for pool_id: String in data["pool_ids"]:
		var words := PackedStringArray()
		for i: int in range(int(data["share_per_player"])):
			var word: String = "%s %s %d" % [player_id, pool_id, i]
			words.append(word)
			(submitted.get_or_add(pool_id, {}) as Dictionary)[word] = true
		assert_int(rig.session.submit_pool_words(player_id, pool_id, words))\
				.is_equal(NetIds.WordRejectReason.NONE)


## Drives a whole game on deadlines (blanks + no-picks) and returns every
## DRAWING phase-data dict in round order.
func _drive_to_wrap_up(rig: Rig) -> Array[Dictionary]:
	var drawings: Array[Dictionary] = []
	var guard: int = 0
	while rig.session.get_phase() != NetIds.Phase.WRAP_UP:
		if rig.session.get_phase() == NetIds.Phase.DRAWING:
			drawings.append(rig.last_data(NetIds.Phase.DRAWING))
		rig.session.on_phase_deadline()
		guard += 1
		assert_bool(guard < 200).is_true()   # never loop forever on a bug
	return drawings


func test_pools_e2e_14_rounds_use_only_submitted_words_surplus_undrawn() -> void:
	var parts: Array = _make_pools_rig(14)
	var rig: Rig = parts[0]
	var pools: PromptPools = parts[1]
	rig.session.start_game()
	var submitted: Dictionary = {}
	for pid: String in ["p0", "p1", "p2", "p3"]:
		_submit_recorded_share(rig, pid, submitted)   # 4 each -> 16 per pool
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.ROUND_INTRO)
	var drawings: Array[Dictionary] = _drive_to_wrap_up(rig)
	assert_int(drawings.size()).is_equal(14)
	for data: Dictionary in drawings:
		var prompt_parts: PackedStringArray = data["prompt_parts"]
		# Fixture draw order: adjectives then animals. Every part must be a
		# submitted word - zero backfill with full participation (§8 ceil math).
		assert_bool((submitted["adjectives"] as Dictionary).has(prompt_parts[0])).is_true()
		assert_bool((submitted["animals"] as Dictionary).has(prompt_parts[1])).is_true()
	# 16 words per pool, 14 drawn -> exactly 2 remain, never drawn (§8).
	assert_int((pools._custom_sources["animals"] as Array).size()).is_equal(2)
	assert_int((pools._custom_sources["adjectives"] as Array).size()).is_equal(2)


func test_pools_e2e_force_continue_backfills_invisibly_and_completes() -> void:
	var parts: Array = _make_pools_rig(14)
	var rig: Rig = parts[0]
	rig.session.start_game()
	var submitted: Dictionary = {}
	for pid: String in ["p0", "p1", "p2"]:
		_submit_recorded_share(rig, pid, submitted)   # p3 never submits: 12/pool
	rig.clock.advance(int(GameConstants.POOL_SETUP_FORCE_AVAILABLE_SEC * 1000.0) + 1)
	assert_bool(rig.session.force_lock_pools()).is_true()
	var drawings: Array[Dictionary] = _drive_to_wrap_up(rig)
	assert_int(drawings.size()).is_equal(14)   # round count unchanged by shortfall
	var backfilled: int = 0
	for data: Dictionary in drawings:
		# Backfill is indistinguishable in the broadcast payload: exactly the
		# Slice 3 DRAWING keys, no source marker anywhere.
		assert_array(data.keys()).contains_exactly_in_any_order(
				["prompt_text", "prompt_parts", "deadline_ms"])
		var prompt_parts: PackedStringArray = data["prompt_parts"]
		if not (submitted["adjectives"] as Dictionary).has(prompt_parts[0]) \
				or not (submitted["animals"] as Dictionary).has(prompt_parts[1]):
			backfilled += 1
	# 12 custom pairs cover 12 rounds; the last 2 must have backfilled.
	assert_int(backfilled).is_equal(2)
	assert_int((rig.results["rounds"] as Array).size()).is_equal(14)
