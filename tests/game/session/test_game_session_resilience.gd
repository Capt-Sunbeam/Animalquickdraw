class_name TestGameSessionResilience
extends GdUnitTestSuite
## Slice 9 on the state machine: late join (allotment, rotation insert,
## activation round), rejoin (memory restore, original slot, mid-DRAWING
## sit-out), departure handling (ready-set re-evaluation, POOL_SETUP
## completion, card-hidden rule), dodge guard + forfeit, the absent-judge
## penalty matrix, below-minimum pause/resume, and end-game-early with the
## wrap-up input contract. Headless via the Slice 3/4/17 rig pattern.

const FIXTURE_DIR: String = "res://tests/fixtures/prompts/"


class Clock extends RefCounted:
	var ms: int = 1_000_000

	func now() -> int:
		return ms

	func advance(delta_ms: int) -> void:
		ms += delta_ms


class Rig extends RefCounted:
	var session: GameSession
	var roster: Roster
	var settings: GameSettings
	var clock: Clock = Clock.new()
	var phases: Array[Dictionary] = []   # {"phase": int, "data": Dictionary}
	var ready_syncs: Array[PackedStringArray] = []
	var progress_syncs: Array = []
	var results: Dictionary = {}

	func last_data(phase: NetIds.Phase) -> Dictionary:
		for i: int in range(phases.size() - 1, -1, -1):
			if int(phases[i]["phase"]) == phase:
				return phases[i]["data"]
		return {}


func _make_rig(player_count: int = 4, round_count: int = 4,
		pool_source: GameSettings.PoolSource = GameSettings.PoolSource.BUILT_IN) -> Rig:
	var rig := Rig.new()
	rig.roster = Roster.new()
	for i: int in range(player_count):
		rig.roster.register(i + 1, "p%d" % i, "Player %d" % i)
	rig.settings = GameSettings.new()
	rig.settings.round_count = round_count
	rig.settings.pool_source = pool_source
	rig.settings.reveal_style = GameSettings.RevealStyle.GRID
	var pools := PromptPools.new()
	pools.rng.seed = 7
	pools.load_from(FIXTURE_DIR)
	rig.session = GameSession.new(rig.settings, rig.roster, Callable(rig.clock, "now"))
	rig.session.rng.seed = 42
	rig.session.use_pools(pools)
	rig.session.phase_entered.connect(func(p: NetIds.Phase, d: Dictionary) -> void:
		rig.phases.append({"phase": int(p), "data": d}))
	rig.session.ready_state_changed.connect(func(ids: PackedStringArray) -> void:
		rig.ready_syncs.append(ids))
	rig.session.pool_setup_progress_changed.connect(func(progress: Array) -> void:
		rig.progress_syncs.append(progress))
	rig.session.session_finished.connect(func(r: Dictionary) -> void:
		rig.results = r)
	return rig


func _payload() -> Dictionary:
	return {"doc": {"v": 1, "orientation": "landscape", "ops": []}}


func _to_drawing(rig: Rig) -> void:
	rig.session.start_game()
	rig.session.on_phase_deadline()   # ROUND_INTRO -> DRAWING


func _to_judging(rig: Rig) -> void:
	_to_drawing(rig)
	rig.session.on_phase_deadline()   # blanks -> REVEAL (grid)
	rig.session.on_phase_deadline()   # -> JUDGING


## Finishes the current round from JUDGING (no pick) through RESOLUTION into
## the next ROUND_INTRO (or WRAP_UP on the final round).
func _finish_round_from_judging(rig: Rig) -> void:
	rig.session.on_phase_deadline()   # JUDGING -> RESOLUTION
	rig.session.on_phase_deadline()   # RESOLUTION -> next round / WRAP_UP


## The host's universal drop steps, as Session._on_peer_disconnected runs
## them: roster mark + GameSession.handle_departure.
func _drop(rig: Rig, player_id: String) -> void:
	var p: Roster.PlayerState = rig.roster.get_by_platform_id(player_id)
	rig.roster.mark_disconnected(p.peer_id, rig.clock.now())
	rig.session.handle_departure(p)


## The host's rejoin steps, as Session._handle_ingame_register runs them.
func _rejoin(rig: Rig, player_id: String, new_peer: int) -> void:
	rig.roster.rebind_peer(player_id, new_peer)
	rig.session.admit_rejoiner(rig.roster.get_by_platform_id(player_id))


## The host's late-join steps.
func _late_join(rig: Rig, player_id: String, new_peer: int) -> Roster.PlayerState:
	var p: Roster.PlayerState = rig.roster.register(new_peer, player_id, player_id)
	rig.session.admit_late_joiner(p)
	return p


# --- late join ---


func test_late_joiner_inserted_immediately_behind_current_judge() -> void:
	var rig: Rig = _make_rig(3, 6)
	_to_drawing(rig)                        # round 0, judge p0
	_late_join(rig, "x", 9)
	var seen: Array[String] = []
	for i: int in range(4):
		rig.session.on_phase_deadline()     # -> REVEAL
		rig.session.on_phase_deadline()     # -> JUDGING
		_finish_round_from_judging(rig)     # -> next ROUND_INTRO
		seen.append(rig.session.current_judge_id())
		rig.session.on_phase_deadline()     # -> DRAWING
	# x judges only when the rotation comes all the way back around (§9).
	assert_array(seen).contains_exactly(["p1", "p2", "x", "p0"])


func test_late_joiner_starts_at_zero_score_flagged_full_kudos() -> void:
	# Full standard allotment (owner decision 2026-07-07, supersedes the
	# brief's half rule): kudos are gifting power, not personal score.
	var rig: Rig = _make_rig(4, 8)          # standard allotment: 8/4 = 2
	_to_drawing(rig)
	var p: Roster.PlayerState = _late_join(rig, "x", 9)
	assert_bool(p.joined_late).is_true()
	assert_int(p.kudos_granted).is_equal(2)   # same figure everyone got
	assert_int(p.kudos_spent).is_equal(0)
	assert_int(int(rig.session.scores().get("x", -99))).is_equal(0)
	# A kudos-off game (explicit allotment 0) stays off for late joiners.
	var rig2: Rig = _make_rig(4, 8)
	rig2.settings.kudos_allotment = 0
	_to_drawing(rig2)
	assert_int(_late_join(rig2, "y", 9).kudos_granted).is_equal(0)


func test_late_joiner_active_from_next_round_and_never_this_rounds_drawer() -> void:
	var rig: Rig = _make_rig(4, 4)
	_to_drawing(rig)                        # round 0: drawers p1 p2 p3
	_late_join(rig, "x", 9)
	assert_bool(rig.session.submit_drawing("x", _payload())).is_false()
	rig.session.on_phase_deadline()         # -> REVEAL
	# Only the three original drawers have cards (blanks); x has none.
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL).get("entries", [])
	assert_int(entries.size()).is_equal(3)
	rig.session.on_phase_deadline()         # -> JUDGING
	_finish_round_from_judging(rig)         # -> round 1
	rig.session.on_phase_deadline()         # -> DRAWING
	assert_bool(rig.session.submit_drawing("x", _payload())).is_true()


func test_late_join_during_pool_setup_is_active_from_round_zero() -> void:
	var rig: Rig = _make_rig(3, 2, GameSettings.PoolSource.PLAYER_CREATED)
	rig.session.start_game()                # POOL_SETUP
	_late_join(rig, "x", 9)
	var data: Dictionary = rig.last_data(NetIds.Phase.POOL_SETUP)
	var share: int = int(data["share_per_player"])
	for pid: String in ["p0", "p1", "p2"]:  # eligible set snapshotted at start
		for pool_id: String in data["pool_ids"]:
			var words := PackedStringArray()
			for i: int in range(share):
				words.append("%s %s %d" % [pid, pool_id, i])
			assert_int(rig.session.submit_pool_words(pid, pool_id, words))\
					.is_equal(NetIds.WordRejectReason.NONE)
	# Completion started round 0; x (active_from_round 0) is a drawer.
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.ROUND_INTRO)
	rig.session.on_phase_deadline()         # -> DRAWING
	assert_bool(rig.session.submit_drawing("x", _payload())).is_true()


# --- rejoin ---


func test_rejoin_restores_score_and_kudos_and_never_regrants() -> void:
	var rig: Rig = _make_rig(4, 4)          # standard allotment: 4/4 = 1
	_to_judging(rig)
	# p0 (judge) never picks -> -1: negative scores restore too (§11 no floor).
	_finish_round_from_judging(rig)
	var p0: Roster.PlayerState = rig.roster.get_by_platform_id("p0")
	p0.kudos_spent = 1                      # spent 1 of 1
	_drop(rig, "p0")
	_rejoin(rig, "p0", 9)
	assert_int(int(rig.session.scores().get("p0", 0))).is_equal(-1)
	assert_int(p0.kudos_granted).is_equal(1)   # never re-granted (§11)
	assert_int(p0.kudos_spent).is_equal(1)
	assert_bool(p0.is_connected).is_true()
	assert_int(p0.peer_id).is_equal(9)


func test_rejoin_keeps_original_rotation_slot() -> void:
	var rig: Rig = _make_rig(4, 4)
	_to_drawing(rig)                        # round 0, judge p0
	_drop(rig, "p2")
	_rejoin(rig, "p2", 9)
	_drop(rig, "p2")
	_rejoin(rig, "p2", 10)                  # leave/rejoin cycles change nothing
	var seen: Array[String] = []
	for i: int in range(3):
		rig.session.on_phase_deadline()     # -> REVEAL
		rig.session.on_phase_deadline()     # -> JUDGING
		_finish_round_from_judging(rig)
		seen.append(rig.session.current_judge_id())
		rig.session.on_phase_deadline()     # -> DRAWING
	assert_array(seen).contains_exactly(["p1", "p2", "p3"])


func test_rejoiner_mid_drawing_sits_out_but_prior_submission_stays() -> void:
	var rig: Rig = _make_rig(4, 4)
	_to_drawing(rig)
	# p1 submits then drops: the drawing must survive (§9).
	assert_bool(rig.session.submit_drawing("p1", _payload())).is_true()
	_drop(rig, "p1")
	_rejoin(rig, "p1", 9)
	# Sitting out: resubmission is rejected (protects the earlier drawing).
	assert_bool(rig.session.submit_drawing("p1", _payload())).is_false()
	# p2 drops with nothing in and rejoins: no card for them this round.
	_drop(rig, "p2")
	_rejoin(rig, "p2", 10)
	rig.session.on_phase_deadline()         # -> REVEAL
	# Cards: p1's kept submission + p3's blank. p2 has none (card hidden).
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL).get("entries", [])
	assert_int(entries.size()).is_equal(2)


func test_dropped_drawer_without_submission_yields_no_card() -> void:
	var rig: Rig = _make_rig(4, 4)
	_to_drawing(rig)
	_drop(rig, "p1")                        # never submitted, stays away
	rig.session.on_phase_deadline()         # -> REVEAL
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL).get("entries", [])
	assert_int(entries.size()).is_equal(2)  # blanks for connected p2/p3 only


func test_submitted_drawing_of_dropped_author_stays_and_can_win() -> void:
	var rig: Rig = _make_rig(4, 4)
	_to_drawing(rig)
	# p1's doc carries one op so it is distinguishable from the two blanks.
	var payload: Dictionary = {"doc": {"v": 1, "orientation": "landscape",
			"ops": [{"t": "clear"}]}}
	assert_bool(rig.session.submit_drawing("p1", payload)).is_true()
	_drop(rig, "p1")
	rig.session.on_phase_deadline()         # -> REVEAL (p1's card + 2 blanks)
	rig.session.on_phase_deadline()         # -> JUDGING
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL).get("entries", [])
	assert_int(entries.size()).is_equal(3)  # the dropped author's card stayed
	var p1_drawing_id: String = ""
	for entry: Variant in entries:
		var doc: Dictionary = (entry as Dictionary).get("doc", {})
		if not (doc.get("ops", []) as Array).is_empty():
			p1_drawing_id = str((entry as Dictionary)["drawing_id"])
	assert_str(p1_drawing_id).is_not_empty()
	assert_bool(rig.session.pick_winner("p0", p1_drawing_id)).is_true()
	rig.session.on_phase_deadline()         # JUDGING -> RESOLUTION
	var res: Dictionary = rig.last_data(NetIds.Phase.RESOLUTION)
	assert_bool(bool(res["picked"])).is_true()
	assert_str(str(res["winner_player_id"])).is_equal("p1")   # remembered score +2
	assert_int(int(rig.session.scores()["p1"])).is_equal(GameConstants.WINNER_POINTS)


# --- departures x ready-up (Slice 17 integration) ---


func test_leaver_erased_from_ready_set() -> void:
	var rig: Rig = _make_rig(4, 4)
	_to_drawing(rig)
	rig.session.submit_drawing("p1", _payload())
	rig.session.set_ready("p1", true)
	assert_bool(rig.session.ready_snapshot().has("p1")).is_true()
	_drop(rig, "p1")
	assert_bool(rig.session.ready_snapshot().has("p1")).is_false()


func test_departure_reevaluates_all_ready_in_drawing() -> void:
	var rig: Rig = _make_rig(4, 4)
	_to_drawing(rig)
	for pid: String in ["p1", "p2"]:
		rig.session.submit_drawing(pid, _payload())
		rig.session.set_ready(pid, true)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.DRAWING)
	_drop(rig, "p3")                        # the only un-ready drawer leaves
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.REVEAL)


func test_departure_reevaluates_all_ready_in_judging_with_gated_pick() -> void:
	var rig: Rig = _make_rig(4, 4)
	_to_judging(rig)
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL).get("entries", [])
	rig.session.pick_winner("p0", str((entries[0] as Dictionary)["drawing_id"]))
	rig.session.set_ready("p0", true)       # judge ready (pick latched)
	rig.session.set_ready("p1", true)
	rig.session.set_ready("p2", true)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.JUDGING)
	_drop(rig, "p3")                        # last holdout leaves -> unanimous
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.RESOLUTION)
	assert_bool(bool(rig.last_data(NetIds.Phase.RESOLUTION)["picked"])).is_true()


func test_judge_seat_holds_no_early_end_while_judge_absent() -> void:
	var rig: Rig = _make_rig(4, 4)
	_to_judging(rig)
	_drop(rig, "p0")                        # the judge vanishes (3 connected)
	for pid: String in ["p1", "p2", "p3"]:
		rig.session.set_ready(pid, true)
	# Unanimous drawers can NOT end judging early - the seat holds (§5).
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.JUDGING)
	rig.session.on_phase_deadline()         # window runs to its normal end
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.RESOLUTION)
	assert_bool(bool(rig.last_data(NetIds.Phase.RESOLUTION)["picked"])).is_false()
	# Fluid ON (default): the absent judge is forgiven - no -1 (§5 matrix).
	assert_int(int(rig.session.scores().get("p0", -99))).is_equal(0)


func test_absent_judge_penalty_matrix_off_suspect_penalized_once() -> void:
	var rig: Rig = _make_rig(4, 4)
	rig.settings.fluid_rejoin = false
	_to_judging(rig)
	_drop(rig, "p0")                        # current judge leaves -> suspect
	assert_bool(rig.roster.get_by_platform_id("p0").dodge_suspect).is_true()
	rig.session.on_phase_deadline()         # window lapses, no pick
	assert_int(int(rig.session.scores().get("p0", 0))).is_equal(-1)
	# The penalty consumed the flag: no second forfeit when their slot comes.
	assert_bool(rig.roster.get_by_platform_id("p0").dodge_suspect).is_false()
	rig.session.on_phase_deadline()         # RESOLUTION -> round 1
	assert_int(int(rig.session.scores().get("p0", 0))).is_equal(-1)   # still just -1
	assert_str(rig.session.current_judge_id()).is_equal("p1")


func test_below_minimum_pause_wins_over_departure_all_ready() -> void:
	var rig: Rig = _make_rig(3, 4)          # drawers p1 p2 (judge p0)
	_to_drawing(rig)
	rig.session.submit_drawing("p1", _payload())
	rig.session.set_ready("p1", true)
	_drop(rig, "p2")                        # 2 connected: freeze, do NOT advance
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.PAUSED)
	_rejoin(rig, "p2", 9)                   # recovery resumes DRAWING (sit-out p2)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.DRAWING)


# --- POOL_SETUP departures (Slice 7 integration) ---


func test_pool_setup_completion_ignores_departed_player() -> void:
	var rig: Rig = _make_rig(4, 2, GameSettings.PoolSource.PLAYER_CREATED)
	rig.session.start_game()
	var data: Dictionary = rig.last_data(NetIds.Phase.POOL_SETUP)
	var share: int = int(data["share_per_player"])
	for pid: String in ["p0", "p1", "p2"]:
		for pool_id: String in data["pool_ids"]:
			var words := PackedStringArray()
			for i: int in range(share):
				words.append("%s %s %d" % [pid, pool_id, i])
			rig.session.submit_pool_words(pid, pool_id, words)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.POOL_SETUP)  # p3 gates
	_drop(rig, "p3")                        # departed players stop gating (§6)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.ROUND_INTRO)


func test_pool_setup_rejoiner_gates_completion_again() -> void:
	var rig: Rig = _make_rig(4, 2, GameSettings.PoolSource.PLAYER_CREATED)
	rig.session.start_game()
	var data: Dictionary = rig.last_data(NetIds.Phase.POOL_SETUP)
	var share: int = int(data["share_per_player"])
	_drop(rig, "p3")                        # away: not gating (4 -> 3, no pause)
	_rejoin(rig, "p3", 9)                   # back: their share gates again
	for pid: String in ["p0", "p1", "p2"]:
		for pool_id: String in data["pool_ids"]:
			var words := PackedStringArray()
			for i: int in range(share):
				words.append("%s %s %d" % [pid, pool_id, i])
			rig.session.submit_pool_words(pid, pool_id, words)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.POOL_SETUP)  # p3 gates
	for pool_id: String in data["pool_ids"]:
		var words := PackedStringArray()
		for i: int in range(share):
			words.append("p3 %s %d" % [pool_id, i])
		rig.session.submit_pool_words("p3", pool_id, words)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.ROUND_INTRO)


func test_pool_setup_completion_settles_on_resume_after_gating_leaver() -> void:
	var rig: Rig = _make_rig(3, 2, GameSettings.PoolSource.PLAYER_CREATED)
	rig.session.start_game()
	var data: Dictionary = rig.last_data(NetIds.Phase.POOL_SETUP)
	var share: int = int(data["share_per_player"])
	for pid: String in ["p0", "p1"]:
		for pool_id: String in data["pool_ids"]:
			var words := PackedStringArray()
			for i: int in range(share):
				words.append("%s %s %d" % [pid, pool_id, i])
			rig.session.submit_pool_words(pid, pool_id, words)
	_drop(rig, "p2")                        # last gater leaves -> below minimum:
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.PAUSED)   # freeze wins
	_late_join(rig, "x", 9)                 # roster recovers -> resume settles it
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.ROUND_INTRO)


# --- dodge guard ---


func test_fluid_on_skips_disconnected_judge_without_penalty() -> void:
	var rig: Rig = _make_rig(4, 4)
	_to_drawing(rig)                        # round 0, judge p0; next is p1
	_drop(rig, "p1")
	assert_bool(rig.roster.get_by_platform_id("p1").dodge_suspect).is_false()
	rig.session.on_phase_deadline()         # -> REVEAL
	rig.session.on_phase_deadline()         # -> JUDGING
	_finish_round_from_judging(rig)         # -> round 1
	assert_str(rig.session.current_judge_id()).is_equal("p2")   # p1 skipped
	assert_int(int(rig.session.scores().get("p1", -99))).is_equal(0)
	var intro: Dictionary = rig.last_data(NetIds.Phase.ROUND_INTRO)
	assert_int((intro.get("forfeits", []) as Array).size()).is_equal(0)


func test_fluid_off_flags_next_judge_inside_window_only() -> void:
	var rig: Rig = _make_rig(4, 4)
	rig.settings.fluid_rejoin = false
	rig.settings.draw_time_sec = 60.0
	_to_drawing(rig)                        # deadline = now + 60 s; next judge p1
	_drop(rig, "p1")                        # 60 s left > 30 s window
	assert_bool(rig.roster.get_by_platform_id("p1").dodge_suspect).is_false()
	_rejoin(rig, "p1", 9)
	rig.clock.advance(35_000)               # 25 s left <= 30 s window
	_drop(rig, "p2")                        # inside window but NOT next judge
	assert_bool(rig.roster.get_by_platform_id("p2").dodge_suspect).is_false()
	_rejoin(rig, "p2", 10)
	_drop(rig, "p1")                        # next judge, inside window -> suspect
	assert_bool(rig.roster.get_by_platform_id("p1").dodge_suspect).is_true()


func test_fluid_off_forfeit_applies_minus_one_and_next_connected_judges() -> void:
	var rig: Rig = _make_rig(4, 4)
	rig.settings.fluid_rejoin = false
	_to_judging(rig)                        # judging window 25 s <= dodge window
	_drop(rig, "p1")                        # next judge, inside window -> suspect
	assert_bool(rig.roster.get_by_platform_id("p1").dodge_suspect).is_true()
	_finish_round_from_judging(rig)         # judge p0 no-pick (-1 to p0); round 1
	assert_str(rig.session.current_judge_id()).is_equal("p2")   # slot forfeited
	assert_int(int(rig.session.scores().get("p1", 0))).is_equal(-1)
	var forfeits: Array = rig.last_data(NetIds.Phase.ROUND_INTRO).get("forfeits", [])
	assert_int(forfeits.size()).is_equal(1)
	assert_str(str((forfeits[0] as Dictionary)["player_id"])).is_equal("p1")
	assert_bool(rig.roster.get_by_platform_id("p1").dodge_suspect).is_false()


func test_rejoin_before_slot_clears_flag_and_judges_normally() -> void:
	var rig: Rig = _make_rig(4, 4)
	rig.settings.fluid_rejoin = false
	_to_judging(rig)
	_drop(rig, "p1")                        # suspect (next judge, window)
	_rejoin(rig, "p1", 9)                   # back before the slot arrives
	assert_bool(rig.roster.get_by_platform_id("p1").dodge_suspect).is_false()
	_finish_round_from_judging(rig)
	assert_str(rig.session.current_judge_id()).is_equal("p1")   # judges normally
	assert_int(int(rig.session.scores().get("p1", -99))).is_equal(0)


# --- pause / resume ---


func test_pause_below_three_and_resume_restores_exact_time_left() -> void:
	var rig: Rig = _make_rig(4, 4)
	_to_drawing(rig)                        # deadline = now + 30 s
	rig.clock.advance(5_000)
	_drop(rig, "p3")                        # 3 connected: no pause
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.DRAWING)
	_drop(rig, "p2")                        # 2 connected: pause
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.PAUSED)
	var pause_data: Dictionary = rig.last_data(NetIds.Phase.PAUSED)
	assert_int(int(pause_data["reason"])).is_equal(NetIds.PauseReason.BELOW_MINIMUM)
	assert_int(int(pause_data["connected_count"])).is_equal(2)
	assert_int(int(pause_data["time_left_ms"])).is_equal(25_000)
	rig.clock.advance(120_000)              # a long wait changes nothing
	_rejoin(rig, "p2", 9)                   # 3 connected: auto-resume
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.DRAWING)
	assert_int(rig.session.get_deadline_ms() - rig.clock.now()).is_equal(25_000)


func test_resume_blocked_while_still_below_minimum() -> void:
	var rig: Rig = _make_rig(4, 4)
	_to_drawing(rig)
	_drop(rig, "p3")
	_drop(rig, "p2")
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.PAUSED)
	rig.session.resume()                    # host menu resume must not unfreeze
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.PAUSED)


func test_late_join_during_pause_counts_toward_resume() -> void:
	var rig: Rig = _make_rig(4, 4)
	_to_drawing(rig)
	_drop(rig, "p3")
	_drop(rig, "p2")
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.PAUSED)
	_late_join(rig, "x", 9)                 # admitted while paused (§10)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.DRAWING)


func test_host_menu_pause_never_auto_resumes() -> void:
	var rig: Rig = _make_rig(4, 4)
	_to_drawing(rig)
	rig.session.pause(NetIds.PauseReason.HOST_MENU)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.PAUSED)
	_late_join(rig, "x", 9)                 # roster recovers/changes: irrelevant
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.PAUSED)
	rig.session.resume()                    # the host's own call resumes
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.DRAWING)


func test_pause_covers_pool_setup_and_reemits_progress_on_resume() -> void:
	var rig: Rig = _make_rig(3, 2, GameSettings.PoolSource.PLAYER_CREATED)
	rig.session.start_game()                # POOL_SETUP, no clock
	_drop(rig, "p2")                        # 2 connected: pause (deadline-less)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.PAUSED)
	var syncs_before: int = rig.progress_syncs.size()
	_rejoin(rig, "p2", 9)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.POOL_SETUP)
	assert_int(rig.session.get_deadline_ms()).is_equal(0)   # still untimed
	assert_int(rig.progress_syncs.size()).is_equal(syncs_before + 1)


func test_no_pause_during_wrap_up() -> void:
	var rig: Rig = _make_rig(3, 1)
	_to_judging(rig)
	_finish_round_from_judging(rig)         # single round -> WRAP_UP
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.WRAP_UP)
	_drop(rig, "p1")
	_drop(rig, "p2")
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.WRAP_UP)


# --- end game early + wrap-up input contract ---


func test_end_game_early_builds_results_so_far_and_discards_partial_round() -> void:
	var rig: Rig = _make_rig(4, 3)
	_to_judging(rig)
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL).get("entries", [])
	rig.session.pick_winner("p0", str((entries[0] as Dictionary)["drawing_id"]))
	_finish_round_from_judging(rig)         # round 0 complete (+2 somewhere)
	rig.session.on_phase_deadline()         # round 1 -> DRAWING (partial round)
	_drop(rig, "p3")
	_drop(rig, "p2")                        # -> below-minimum pause
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.PAUSED)
	rig.session.end_game_early()
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.WRAP_UP)
	var results: Dictionary = rig.results
	assert_bool(bool(results["ended_early"])).is_true()
	assert_int(int(results["rounds_played"])).is_equal(1)   # partial discarded
	assert_int(int(results["rounds_planned"])).is_equal(3)
	assert_int((results["rounds"] as Array).size()).is_equal(1)
	# Disconnected players appear with remembered scores (§6 contract).
	var players: Array = results["players"]
	assert_int(players.size()).is_equal(4)
	var disconnected: int = 0
	for entry: Variant in players:
		if not bool((entry as Dictionary)["is_connected"]):
			disconnected += 1
	assert_int(disconnected).is_equal(2)


func test_end_game_early_only_available_while_paused() -> void:
	var rig: Rig = _make_rig(4, 3)
	_to_drawing(rig)
	rig.session.end_game_early()            # not paused: refused
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.DRAWING)


func test_natural_end_results_carry_contract_keys() -> void:
	var rig: Rig = _make_rig(3, 1)
	_to_judging(rig)
	_finish_round_from_judging(rig)
	var results: Dictionary = rig.results
	assert_bool(bool(results["ended_early"])).is_false()
	assert_int(int(results["rounds_played"])).is_equal(1)
	assert_int(int(results["rounds_planned"])).is_equal(1)
	assert_int((results["players"] as Array).size()).is_equal(3)


# --- welcome snapshot ---


func test_welcome_snapshot_mid_judging_carries_entries_and_pause_state() -> void:
	var rig: Rig = _make_rig(4, 4)
	_to_judging(rig)
	var p1: Roster.PlayerState = rig.roster.get_by_platform_id("p1")
	var snap: Dictionary = rig.session.build_welcome_snapshot(p1)
	assert_int(int(snap["phase"])).is_equal(NetIds.Phase.JUDGING)
	assert_bool(bool(snap["paused"])).is_false()
	assert_int(((snap["phase_data"] as Dictionary)["entries"] as Array).size()).is_equal(3)
	assert_str(str(snap["current_judge_platform_id"])).is_equal("p0")
	assert_bool(int(snap["time_left_ms"]) > 0).is_true()
	# Pause wraps the same underlying phase.
	rig.session.pause(NetIds.PauseReason.BELOW_MINIMUM)
	var paused_snap: Dictionary = rig.session.build_welcome_snapshot(p1)
	assert_bool(bool(paused_snap["paused"])).is_true()
	assert_int(int(paused_snap["phase"])).is_equal(NetIds.Phase.JUDGING)
	assert_int(int(paused_snap["pause_reason"]))\
			.is_equal(NetIds.PauseReason.BELOW_MINIMUM)
