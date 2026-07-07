class_name TestGameSessionReady
extends GdUnitTestSuite
## Slice 17 ready-up on the state machine: eligibility matrix, judge pick
## gating, lock-in semantics, all-ready early advance in DRAWING and
## JUDGING, un-ready, phase-change reset, and leaver tolerance. Headless
## via the Slice 3/4 rig pattern.

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
	var clock: Clock = Clock.new()
	var phases: Array[Dictionary] = []   # {"phase": int, "data": Dictionary}
	var ready_syncs: Array[PackedStringArray] = []

	func last_data(phase: NetIds.Phase) -> Dictionary:
		for i: int in range(phases.size() - 1, -1, -1):
			if int(phases[i]["phase"]) == phase:
				return phases[i]["data"]
		return {}


func _make_rig() -> Rig:
	var rig := Rig.new()
	rig.roster = Roster.new()
	for i: int in 4:
		rig.roster.register(i + 1, "p%d" % i, "Player %d" % i)
	var settings := GameSettings.new()
	settings.round_count = 2
	settings.reveal_style = GameSettings.RevealStyle.GRID
	var pools := PromptPools.new()
	pools.rng.seed = 7
	pools.load_from(FIXTURE_DIR)
	rig.session = GameSession.new(settings, rig.roster, Callable(rig.clock, "now"))
	rig.session.rng.seed = 42
	rig.session.use_pools(pools)
	rig.session.phase_entered.connect(func(p: NetIds.Phase, d: Dictionary) -> void:
		rig.phases.append({"phase": int(p), "data": d}))
	rig.session.ready_state_changed.connect(func(ids: PackedStringArray) -> void:
		rig.ready_syncs.append(ids))
	return rig


func _blank_payload() -> Dictionary:
	return {"doc": {"v": 1, "orientation": "landscape", "ops": []}}


func _to_drawing(rig: Rig) -> void:
	rig.session.start_game()
	rig.session.on_phase_deadline()   # ROUND_INTRO -> DRAWING


func _to_judging(rig: Rig) -> void:
	_to_drawing(rig)
	rig.session.on_phase_deadline()   # blanks -> REVEAL (grid)
	rig.session.on_phase_deadline()   # -> JUDGING


func test_drawing_ready_requires_submission_and_drawer_role() -> void:
	var rig: Rig = _make_rig()
	_to_drawing(rig)
	assert_bool(rig.session.set_ready("p1", true)).is_false()   # nothing submitted
	rig.session.submit_drawing("p1", _blank_payload())
	assert_bool(rig.session.set_ready("p1", true)).is_true()
	assert_bool(rig.session.set_ready("p0", true)).is_false()   # judge has no ready here
	assert_bool(rig.session.set_ready("ghost", true)).is_false()


func test_ready_locks_resubmission_until_unready() -> void:
	var rig: Rig = _make_rig()
	_to_drawing(rig)
	rig.session.submit_drawing("p1", _blank_payload())
	rig.session.set_ready("p1", true)
	assert_bool(rig.session.submit_drawing("p1", _blank_payload())).is_false()  # locked in
	assert_bool(rig.session.set_ready("p1", false)).is_true()                   # escape hatch
	assert_bool(rig.session.submit_drawing("p1", _blank_payload())).is_true()


func test_judge_ready_requires_latched_pick_and_locks_it() -> void:
	var rig: Rig = _make_rig()
	_to_judging(rig)
	assert_bool(rig.session.set_ready("p0", true)).is_false()   # no pick latched
	# Latch any drawing: blanks are pickable (all three synthesized).
	var target: String = _any_drawing_id(rig)
	assert_bool(rig.session.pick_winner("p0", target)).is_true()
	assert_bool(rig.session.set_ready("p0", true)).is_true()
	# Ready locks the pick: re-picks are dropped until un-ready.
	assert_bool(rig.session.pick_winner("p0", target)).is_false()
	assert_bool(rig.session.set_ready("p0", false)).is_true()
	assert_bool(rig.session.pick_winner("p0", target)).is_true()


func test_all_ready_in_judging_crowns_latched_pick_early() -> void:
	var rig: Rig = _make_rig()
	_to_judging(rig)
	var target: String = _any_drawing_id(rig)
	rig.session.pick_winner("p0", target)
	for pid: String in ["p1", "p2", "p3"]:
		assert_bool(rig.session.set_ready(pid, true)).is_true()
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.JUDGING)  # judge not ready yet
	assert_bool(rig.session.set_ready("p0", true)).is_true()
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.RESOLUTION)
	# The latched pick was crowned (+2 to some drawer), never a no-pick -1.
	var scores: Dictionary = rig.session.scores()
	var winners: int = 0
	for pid: String in scores:
		if int(scores[pid]) == GameConstants.WINNER_POINTS:
			winners += 1
	assert_int(winners).is_equal(1)
	assert_int(int(scores.get("p0", 0))).is_equal(0)


func test_ready_set_resets_on_phase_change() -> void:
	var rig: Rig = _make_rig()
	_to_drawing(rig)
	rig.session.submit_drawing("p1", _blank_payload())
	rig.session.set_ready("p1", true)
	assert_int(rig.session.ready_snapshot().size()).is_equal(1)
	rig.session.on_phase_deadline()   # -> REVEAL
	assert_int(rig.session.ready_snapshot().size()).is_equal(0)


func test_disconnected_drawer_never_blocks_all_ready() -> void:
	var rig: Rig = _make_rig()
	_to_drawing(rig)
	rig.roster.get_by_platform_id("p3").is_connected = false   # mid-phase leaver
	for pid: String in ["p1", "p2"]:
		rig.session.submit_drawing(pid, _blank_payload())
	rig.session.set_ready("p1", true)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.DRAWING)
	rig.session.set_ready("p2", true)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.REVEAL)   # p3 not required


func test_ready_state_changed_broadcasts_each_toggle() -> void:
	var rig: Rig = _make_rig()
	_to_drawing(rig)
	rig.session.submit_drawing("p1", _blank_payload())
	rig.session.set_ready("p1", true)
	rig.session.set_ready("p1", false)
	assert_int(rig.ready_syncs.size()).is_equal(2)
	assert_bool(rig.ready_syncs[0].has("p1")).is_true()
	assert_int(rig.ready_syncs[1].size()).is_equal(0)


func test_ready_rejected_outside_ready_phases() -> void:
	var rig: Rig = _make_rig()
	rig.session.start_game()   # ROUND_INTRO
	assert_bool(rig.session.set_ready("p1", true)).is_false()
	var rig2: Rig = _make_rig()
	_to_drawing(rig2)
	rig2.session.on_phase_deadline()   # REVEAL
	assert_bool(rig2.session.set_ready("p1", true)).is_false()


func _any_drawing_id(rig: Rig) -> String:
	var entries: Array = rig.last_data(NetIds.Phase.REVEAL).get("entries", [])
	if entries.is_empty():
		return ""
	return str((entries[0] as Dictionary).get("drawing_id", ""))
