class_name TestGameSessionSocial
extends GdUnitTestSuite
## Slice 4 on the Slice 3 state machine: give_kudos validators (steps 3-4 of
## the 5-step pattern), the kudos economy, gate lifecycle across phases,
## score-deferral, and the results-bundle aggregates (Slice 19: emoji
## reactions retired; kudos is the remaining social currency). Headless via
## the same rig pattern as TestGameSession. Anonymity note: entries never
## carry authors, so tests find "someone else's drawing" by giving kudos as
## the JUDGE (never an author) or by counting rejections (exactly one entry
## is the giver's own).

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
	var phases: Array[Dictionary] = []
	var kudos_syncs: Array[Dictionary] = []      # {"drawing_id", "total"}
	var confirms: Array[Dictionary] = []         # {"player_id", "drawing_id", "remaining"}
	var results: Dictionary = {}

	func last_data(phase: NetIds.Phase) -> Dictionary:
		for i: int in range(phases.size() - 1, -1, -1):
			if int(phases[i]["phase"]) == phase:
				return phases[i]["data"]
		return {}

	func entries() -> Array:
		return last_data(NetIds.Phase.REVEAL).get("entries", [])

	func entry_ids() -> Array[String]:
		var ids: Array[String] = []
		for entry: Dictionary in entries():
			ids.append(str(entry["drawing_id"]))
		return ids


func _make_rig(player_count: int = 4, round_count: int = 2,
		kudos_allotment: int = GameSettings.KUDOS_AUTO) -> Rig:
	var rig := Rig.new()
	rig.roster = Roster.new()
	for i: int in range(player_count):
		rig.roster.register(i + 1, "p%d" % i, "Player %d" % i)
	var settings := GameSettings.new()
	settings.round_count = round_count
	settings.kudos_allotment = kudos_allotment
	# GRID: this suite tests the Slice 4 gate semantics (closed during
	# REVEAL, open-all at JUDGING); Slice 5's per-beat opening is covered by
	# TestGameSessionReveal.
	settings.reveal_style = GameSettings.RevealStyle.GRID
	var pools := PromptPools.new()
	pools.rng.seed = 7
	pools.load_from(FIXTURE_DIR)
	rig.session = GameSession.new(settings, rig.roster, Callable(rig.clock, "now"))
	rig.session.rng.seed = 42
	rig.session.use_pools(pools)
	rig.session.phase_entered.connect(func(p: NetIds.Phase, d: Dictionary) -> void:
		rig.phases.append({"phase": p, "data": d}))
	rig.session.kudos_total_changed.connect(func(id: String, total: int) -> void:
		rig.kudos_syncs.append({"drawing_id": id, "total": total}))
	rig.session.kudos_confirmed.connect(func(pid: String, id: String, remaining: int) -> void:
		rig.confirms.append({"player_id": pid, "drawing_id": id, "remaining": remaining}))
	rig.session.session_finished.connect(func(r: Dictionary) -> void:
		rig.results = r)
	return rig


## start -> lapse everyone to JUDGING (blank submissions for all drawers).
func _to_judging(rig: Rig) -> void:
	rig.session.start_game()
	rig.session.on_phase_deadline()  # INTRO -> DRAWING
	rig.session.on_phase_deadline()  # DRAWING -> REVEAL (blanks)
	rig.session.on_phase_deadline()  # REVEAL -> JUDGING (gate opens)


# --- allotment / economy at start ---


func test_allotment_granted_to_all_players_at_start() -> void:
	var rig: Rig = _make_rig(4, 10)   # AUTO: 10 rounds -> 3 kudos
	rig.session.start_game()
	for player: Roster.PlayerState in rig.roster.players_in_join_order():
		assert_int(player.kudos_granted).is_equal(3)
		assert_int(player.kudos_spent).is_equal(0)


func test_explicit_allotment_setting_overrides_auto() -> void:
	var rig := Rig.new()
	rig.roster = Roster.new()
	for i: int in range(3):
		rig.roster.register(i + 1, "p%d" % i, "Player %d" % i)
	var settings := GameSettings.new()
	settings.round_count = 10
	settings.kudos_allotment = 5
	rig.session = GameSession.new(settings, rig.roster, Callable(rig.clock, "now"))
	var pools := PromptPools.new()
	pools.load_from(FIXTURE_DIR)
	rig.session.use_pools(pools)
	rig.session.start_game()
	for player: Roster.PlayerState in rig.roster.players_in_join_order():
		assert_int(player.kudos_granted).is_equal(5)


func test_allotment_zero_disables_kudos() -> void:
	var rig := Rig.new()
	rig.roster = Roster.new()
	for i: int in range(3):
		rig.roster.register(i + 1, "p%d" % i, "Player %d" % i)
	var settings := GameSettings.new()
	settings.round_count = 4
	settings.kudos_allotment = 0
	rig.session = GameSession.new(settings, rig.roster, Callable(rig.clock, "now"))
	var pools := PromptPools.new()
	pools.load_from(FIXTURE_DIR)
	rig.session.use_pools(pools)
	rig.session.phase_entered.connect(func(p: NetIds.Phase, d: Dictionary) -> void:
		rig.phases.append({"phase": p, "data": d}))
	rig.session.start_game()
	rig.session.on_phase_deadline()
	rig.session.on_phase_deadline()
	rig.session.on_phase_deadline()  # JUDGING
	for id: String in rig.entry_ids():
		assert_bool(rig.session.give_kudos("p0", id)).is_false()


# --- kudos validators / economy ---


func test_kudos_grace_window_accepts_then_drops() -> void:
	var rig: Rig = _make_rig(4, 6)   # AUTO: 6 rounds -> 2 kudos
	_to_judging(rig)
	var ids: Array[String] = rig.entry_ids()
	rig.session.on_phase_deadline()  # JUDGING lapses -> RESOLUTION, gate closes
	# Racing request inside the grace window still counts (§10)...
	assert_bool(rig.session.give_kudos("p0", ids[0])).is_true()
	# ...but past the grace it drops (budget still has 1 left - it is the
	# gate, not the wallet, doing the rejecting).
	rig.clock.advance(GameConstants.SOCIAL_CLOSE_GRACE_MSEC + 1)
	assert_bool(rig.session.give_kudos("p0", ids[1])).is_false()


func test_judge_kudos_allowed_and_confirms_with_remaining() -> void:
	var rig: Rig = _make_rig(4, 6)   # AUTO: 6 rounds -> 2 kudos
	_to_judging(rig)
	var target: String = rig.entry_ids()[0]
	assert_bool(rig.session.give_kudos("p0", target)).is_true()
	assert_int(rig.kudos_syncs.size()).is_equal(1)
	assert_int(int(rig.kudos_syncs[0]["total"])).is_equal(1)
	assert_int(rig.confirms.size()).is_equal(1)
	assert_str(str(rig.confirms[0]["player_id"])).is_equal("p0")
	assert_int(int(rig.confirms[0]["remaining"])).is_equal(1)
	assert_int(rig.roster.get_by_platform_id("p0").kudos_spent).is_equal(1)


func test_self_kudos_rejected() -> void:
	var rig: Rig = _make_rig(4, 32)  # plenty of budget
	_to_judging(rig)
	var rejected: int = 0
	for id: String in rig.entry_ids():
		if not rig.session.give_kudos("p1", id):
			rejected += 1
	assert_int(rejected).is_equal(1)   # exactly the own drawing


func test_second_kudos_same_drawing_rejected() -> void:
	var rig: Rig = _make_rig(4, 6)   # 2 kudos budget
	_to_judging(rig)
	var target: String = rig.entry_ids()[0]
	assert_bool(rig.session.give_kudos("p0", target)).is_true()
	assert_bool(rig.session.give_kudos("p0", target)).is_false()
	assert_int(rig.roster.get_by_platform_id("p0").kudos_spent).is_equal(1)


func test_kudos_over_budget_rejected_host_order() -> void:
	var rig: Rig = _make_rig(4, 2)   # AUTO: 2 rounds -> 1 kudos
	_to_judging(rig)
	var ids: Array[String] = rig.entry_ids()
	assert_bool(rig.session.give_kudos("p0", ids[0])).is_true()    # host order wins
	assert_bool(rig.session.give_kudos("p0", ids[1])).is_false()   # budget exhausted
	assert_int(rig.roster.get_by_platform_id("p0").kudos_spent).is_equal(1)
	assert_int(rig.confirms.size()).is_equal(1)


func test_kudos_gate_closed_rejected() -> void:
	var rig: Rig = _make_rig()
	rig.session.start_game()
	rig.session.on_phase_deadline()
	rig.session.on_phase_deadline()  # REVEAL - gate closed in v1
	assert_bool(rig.session.give_kudos("p0", rig.entry_ids()[0])).is_false()


func test_kudos_to_disconnected_author_scores() -> void:
	var rig: Rig = _make_rig()
	rig.session.start_game()
	rig.session.on_phase_deadline()  # DRAWING
	# Distinguishable docs so the test can identify p2's entry afterwards.
	rig.session.submit_drawing("p1", {"doc": {"v": 1, "orientation": "landscape", "ops": [{"t": "clear"}]}})
	rig.session.submit_drawing("p2", {"doc": {"v": 1, "orientation": "landscape", "ops": [{"t": "clear"}, {"t": "clear"}]}})
	rig.session.submit_drawing("p3", {"doc": {"v": 1, "orientation": "landscape", "ops": [{"t": "clear"}, {"t": "clear"}, {"t": "clear"}]}})
	for ready_pid: String in ["p1", "p2", "p3"]:
		rig.session.set_ready(ready_pid, true)   # Slice 17: ready ends DRAWING
	rig.session.on_phase_deadline()  # REVEAL -> JUDGING
	var p2_drawing: String = ""
	for entry: Dictionary in rig.entries():
		if ((entry["doc"] as Dictionary)["ops"] as Array).size() == 2:
			p2_drawing = str(entry["drawing_id"])
	rig.roster.get_by_platform_id("p2").is_connected = false   # drawer quit mid-judging
	assert_bool(rig.session.give_kudos("p0", p2_drawing)).is_true()
	assert_int(int(rig.session.scores()["p2"])).is_equal(GameConstants.KUDOS_POINTS)


func test_kudos_score_applies_host_side_but_broadcast_defers_to_resolution() -> void:
	var rig: Rig = _make_rig()
	_to_judging(rig)
	var target: String = rig.entry_ids()[0]
	rig.session.give_kudos("p0", target)
	# No phase payload between JUDGING entry and now carried scores.
	assert_bool(rig.last_data(NetIds.Phase.JUDGING).has("scores")).is_false()
	rig.session.on_phase_deadline()  # window lapses -> RESOLUTION
	var scores: Dictionary = rig.last_data(NetIds.Phase.RESOLUTION)["scores"]
	# Author's +1 is in the resolution snapshot alongside the judge's -1.
	var total: int = 0
	for pid: Variant in scores:
		total += int(scores[pid])
	assert_int(total).is_equal(GameConstants.KUDOS_POINTS + GameConstants.JUDGE_NO_PICK_POINTS)


# --- gate lifecycle / stats / results ---


func test_gate_reopens_each_judging_and_closes_after() -> void:
	# Explicit allotment: the gate is what's under test, never the wallet.
	var rig: Rig = _make_rig(4, 2, 8)
	_to_judging(rig)
	var round0_target: String = rig.entry_ids()[0]
	assert_bool(rig.session.give_kudos("p0", round0_target)).is_true()
	rig.session.on_phase_deadline()  # -> RESOLUTION (closes gate)
	rig.clock.advance(GameConstants.SOCIAL_CLOSE_GRACE_MSEC + 1)
	assert_bool(rig.session.give_kudos("p0", rig.entry_ids()[1])).is_false()
	rig.session.on_phase_deadline()  # -> ROUND_INTRO (round 1)
	rig.session.on_phase_deadline()  # -> DRAWING
	rig.session.on_phase_deadline()  # -> REVEAL
	assert_bool(rig.session.give_kudos("p1", rig.entry_ids()[0])).is_false()
	rig.session.on_phase_deadline()  # -> JUDGING (gate reopens for round 1 set)
	var judge: String = rig.session.current_judge_id()   # p1 after rotation
	var accepted: int = 0
	for id: String in rig.entry_ids():
		if rig.session.give_kudos(judge, id):
			accepted += 1
	assert_int(accepted).is_equal(3)   # the judge kudos all of round 1's drawings
	# Round 0 ids are NOT part of the reopened set.
	assert_bool(rig.session.give_kudos(judge, round0_target)).is_false()


func test_stats_register_drawings_and_winner() -> void:
	var rig: Rig = _make_rig()
	_to_judging(rig)
	var stats: SessionStats = rig.session.session_stats()
	assert_int(stats.drawings.size()).is_equal(3)   # blanks registered too
	var target: String = rig.entry_ids()[0]
	rig.session.pick_winner("p0", target)
	rig.session.on_phase_deadline()   # latched pick crowns at deadline
	assert_bool((stats.drawings[target] as SessionStats.DrawingStats).won_round).is_true()
	for stat: SessionStats.DrawingStats in stats.drawings.values():
		assert_str(stat.prompt_text).is_not_empty()


func test_results_bundle_carries_social_aggregates() -> void:
	var rig: Rig = _make_rig(4, 1)
	_to_judging(rig)
	var target: String = rig.entry_ids()[0]
	rig.session.give_kudos("p0", target)
	rig.session.on_phase_deadline()  # -> RESOLUTION (no pick)
	rig.session.on_phase_deadline()  # -> WRAP_UP (1-round game)
	var author: String = ""          # resolve the target's author from kudos stats
	for uid: Variant in rig.results["kudos_stats"]["received_by_author"]:
		author = str(uid)
	assert_str(author).is_not_empty()
	assert_that(rig.results["kudos_stats"]["received_by_author"]).is_equal({author: 1})
	assert_that(rig.results["kudos_stats"]["drawing_totals"]).is_equal({target: 1})
	# Kudos +1 and judge -1 both present in the final scores.
	assert_int(int((rig.results["final_scores"] as Dictionary)[author])).is_equal(1)
	assert_int(int((rig.results["final_scores"] as Dictionary)["p0"])).is_equal(-1)
