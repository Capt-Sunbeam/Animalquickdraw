class_name TestGameSessionReveal
extends GdUnitTestSuite
## Slice 5 on the state machine: beat chain drives REVEAL -> JUDGING, the
## gate follows the staged drawing (with cross-beat grace), captions are
## validated in the submit path, and the failsafe deadline can never
## double-advance. Headless via the Slice 3/4 rig pattern.

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
	var beats: Array[Dictionary] = []    # {"index", "drawing_id", "secs"}
	var gathers: int = 0

	func last_data(phase: NetIds.Phase) -> Dictionary:
		for i: int in range(phases.size() - 1, -1, -1):
			if int(phases[i]["phase"]) == phase:
				return phases[i]["data"]
		return {}

	func entries() -> Array:
		return last_data(NetIds.Phase.REVEAL).get("entries", [])


func _make_rig(style: GameSettings.RevealStyle = GameSettings.RevealStyle.ONE_AT_A_TIME,
		comments: bool = true) -> Rig:
	var rig := Rig.new()
	rig.roster = Roster.new()
	for i: int in 4:
		rig.roster.register(i + 1, "p%d" % i, "Player %d" % i)
	var settings := GameSettings.new()
	settings.round_count = 2
	settings.reveal_style = style
	settings.comments_enabled = comments
	var pools := PromptPools.new()
	pools.rng.seed = 7
	pools.load_from(FIXTURE_DIR)
	rig.session = GameSession.new(settings, rig.roster, Callable(rig.clock, "now"))
	rig.session.rng.seed = 42
	rig.session.use_pools(pools)
	rig.session.phase_entered.connect(func(p: NetIds.Phase, d: Dictionary) -> void:
		rig.phases.append({"phase": p, "data": d}))
	rig.session.reveal_beat_started.connect(func(i: int, id: String, secs: float) -> void:
		rig.beats.append({"index": i, "drawing_id": id, "secs": secs}))
	rig.session.reveal_gather_started.connect(func(_secs: float) -> void:
		rig.gathers += 1)
	return rig


func _submit_all(rig: Rig, captions: Dictionary = {}) -> void:
	for pid: String in ["p1", "p2", "p3"]:
		rig.session.submit_drawing(pid, {
			"doc": {"v": 1, "orientation": "landscape", "ops": []},
			"caption": str(captions.get(pid, "")),
		})


func test_beat_chain_covers_entries_then_gathers_then_judging() -> void:
	var rig: Rig = _make_rig()
	rig.session.start_game()
	rig.session.on_phase_deadline()   # -> DRAWING
	_submit_all(rig)                  # early end -> REVEAL + first beat
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.REVEAL)
	assert_int(rig.beats.size()).is_equal(1)
	rig.session.on_reveal_beat_deadline()   # beat 1
	rig.session.on_reveal_beat_deadline()   # beat 2
	assert_int(rig.beats.size()).is_equal(3)
	assert_int(rig.gathers).is_equal(0)
	rig.session.on_reveal_beat_deadline()   # -> gather
	assert_int(rig.gathers).is_equal(1)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.REVEAL)
	rig.session.on_reveal_beat_deadline()   # gather elapsed -> JUDGING
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.JUDGING)
	# Beats hit every entry exactly once, in the broadcast order.
	var expected_ids: Array[String] = []
	for entry: Dictionary in rig.entries():
		expected_ids.append(str(entry["drawing_id"]))
	var beat_ids: Array[String] = []
	for beat: Dictionary in rig.beats:
		beat_ids.append(str(beat["drawing_id"]))
	assert_array(beat_ids).contains_exactly(expected_ids)


func test_reveal_deadline_is_schedule_plus_failsafe() -> void:
	var rig: Rig = _make_rig()
	rig.session.start_game()
	rig.session.on_phase_deadline()
	_submit_all(rig)
	var data: Dictionary = rig.last_data(NetIds.Phase.REVEAL)
	assert_int(int(data["reveal_style"])).is_equal(GameSettings.RevealStyle.ONE_AT_A_TIME)
	var total: float = 0.0
	for beat: Dictionary in rig.beats:
		total += float(beat["secs"])
	# 3 identical blank beats: total = 3 x beat + gather + failsafe.
	var expected_ms: int = rig.clock.ms + int((total * 3.0 / 1.0
			+ GameConstants.REVEAL_TO_GRID_SECS
			+ GameConstants.REVEAL_BEAT_FAILSAFE_SECS) * 1000.0)
	# beats list only has beat 0 so far; all 3 are identical (blank docs).
	assert_int(int(data["deadline_ms"])).is_equal(expected_ms)


func test_gate_open_only_for_staged_drawing_with_cross_beat_grace() -> void:
	var rig: Rig = _make_rig()
	rig.session.start_game()
	rig.session.on_phase_deadline()
	_submit_all(rig)
	var staged: String = str(rig.beats[0]["drawing_id"])
	var other: String = ""
	for entry: Dictionary in rig.entries():
		if str(entry["drawing_id"]) != staged:
			other = str(entry["drawing_id"])
	# Judge (p0) can react to the staged drawing only.
	assert_bool(rig.session.react("p0", staged, NetIds.Reaction.LAUGH, true)).is_true()
	assert_bool(rig.session.react("p0", other, NetIds.Reaction.LAUGH, true)).is_false()
	# Next beat: previous drawing still accepted inside the close grace...
	rig.session.on_reveal_beat_deadline()
	assert_bool(rig.session.react("p0", staged, NetIds.Reaction.WOW, true)).is_true()
	# ...but not once the grace has elapsed.
	rig.clock.advance(GameConstants.REACTION_CLOSE_GRACE_MSEC + 1)
	assert_bool(rig.session.react("p0", staged, NetIds.Reaction.FIRE, true)).is_false()
	# The newly staged drawing is live.
	var now_staged: String = str(rig.beats[1]["drawing_id"])
	assert_bool(rig.session.react("p0", now_staged, NetIds.Reaction.LAUGH, true)).is_true()


func test_kudos_during_beat_allowed() -> void:
	var rig: Rig = _make_rig()
	rig.session.start_game()
	rig.session.on_phase_deadline()
	_submit_all(rig)
	var staged: String = str(rig.beats[0]["drawing_id"])
	assert_bool(rig.session.give_kudos("p0", staged)).is_true()


func test_captions_cleaned_and_delivered_in_entries() -> void:
	var rig: Rig = _make_rig()
	rig.session.start_game()
	rig.session.on_phase_deadline()
	var raw: String = "  it's\nresting,  honest  "
	var expected: String = TextFilter.censor("it's resting,  honest")
	_submit_all(rig, {"p1": raw, "p2": "x".repeat(200)})
	var captions: Dictionary = {}
	for entry: Dictionary in rig.entries():
		captions[str(entry.get("caption", "missing"))] = true
	assert_bool(captions.has(expected)).is_true()
	assert_bool(captions.has("x".repeat(GameConstants.CAPTION_MAX_CHARS))).is_true()
	assert_bool(captions.has("")).is_true()   # p3 sent none


func test_captions_stripped_when_comments_disabled() -> void:
	var rig: Rig = _make_rig(GameSettings.RevealStyle.ONE_AT_A_TIME, false)
	rig.session.start_game()
	rig.session.on_phase_deadline()
	_submit_all(rig, {"p1": "should vanish", "p2": "me too"})
	for entry: Dictionary in rig.entries():
		assert_str(str(entry.get("caption", "missing"))).is_equal("")


func test_failsafe_deadline_never_double_advances() -> void:
	var rig: Rig = _make_rig()
	rig.session.start_game()
	rig.session.on_phase_deadline()
	_submit_all(rig)
	# Beat chain "stalls"; the main REVEAL deadline fires the failsafe.
	rig.session.on_phase_deadline()
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.JUDGING)
	# A stale beat timer firing afterwards is dropped harmlessly.
	var judging_count_before: int = rig.phases.size()
	rig.session.on_reveal_beat_deadline()
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.JUDGING)
	assert_int(rig.phases.size()).is_equal(judging_count_before)


func test_resolution_sized_to_fit_winner_replay_plus_still_hold() -> void:
	# Owner feedback 2026-07-06: the lap must show every stroke then hold
	# the still for REPLAY_STILL_HOLD_SECS - the phase can't cut it off.
	var rig: Rig = _make_rig(GameSettings.RevealStyle.GRID)
	rig.session.start_game()
	rig.session.on_phase_deadline()   # DRAWING
	# p1 draws for 30 s; default winner target 8 s -> replay takes 8 s.
	rig.session.submit_drawing("p1", {"doc": {"v": 1, "orientation": "landscape",
			"ops": [{"t": "stroke", "c": 0, "s": 1,
			"pts": [10.0, 10.0, 400.0, 300.0], "ts": [0.0, 30.0]}]}})
	rig.session.submit_drawing("p2", {"doc": {"v": 1, "orientation": "landscape", "ops": []}})
	rig.session.submit_drawing("p3", {"doc": {"v": 1, "orientation": "landscape", "ops": []}})
	rig.session.on_phase_deadline()   # REVEAL -> JUDGING
	var long_drawing: String = ""
	for entry: Dictionary in rig.entries():
		if not ((entry["doc"] as Dictionary)["ops"] as Array).is_empty():
			long_drawing = str(entry["drawing_id"])
	assert_bool(rig.session.pick_winner("p0", long_drawing)).is_true()
	rig.session.on_phase_deadline()   # latched pick crowns at deadline
	var data: Dictionary = rig.last_data(NetIds.Phase.RESOLUTION)
	# duration = replay (8 s) + still hold (2 s) + 1 s margin = 11 s > base 6 s.
	assert_int(int(data["deadline_ms"])).is_equal(rig.clock.ms + 11_000)


func test_resolution_base_duration_when_no_pick_or_replay_off() -> void:
	var rig: Rig = _make_rig(GameSettings.RevealStyle.GRID)
	rig.session.start_game()
	rig.session.on_phase_deadline()
	_submit_all(rig)
	rig.session.on_phase_deadline()   # REVEAL -> JUDGING
	rig.session.on_phase_deadline()   # window lapses, no pick
	var data: Dictionary = rig.last_data(NetIds.Phase.RESOLUTION)
	assert_int(int(data["deadline_ms"])).is_equal(
			rig.clock.ms + int(GameConstants.RESOLUTION_SEC * 1000.0))


func test_judging_window_setting_drives_deadline() -> void:
	# Slice 6: the window is a host-tunable setting, not a constant.
	var rig: Rig = _make_rig(GameSettings.RevealStyle.GRID)
	rig.session = GameSession.new(_settings_with_window(40.0), rig.roster,
			Callable(rig.clock, "now"))
	var pools := PromptPools.new()
	pools.load_from(FIXTURE_DIR)
	rig.session.use_pools(pools)
	rig.session.phase_entered.connect(func(p: NetIds.Phase, d: Dictionary) -> void:
		rig.phases.append({"phase": p, "data": d}))
	rig.session.start_game()
	rig.session.on_phase_deadline()   # DRAWING
	rig.session.on_phase_deadline()   # REVEAL
	rig.session.on_phase_deadline()   # JUDGING
	var data: Dictionary = rig.last_data(NetIds.Phase.JUDGING)
	assert_int(int(data["deadline_ms"])).is_equal(rig.clock.ms + 40_000)


func _settings_with_window(window_sec: float) -> GameSettings:
	var settings := GameSettings.new()
	settings.round_count = 2
	settings.reveal_style = GameSettings.RevealStyle.GRID
	settings.judging_window_sec = window_sec
	return settings


func test_pause_broadcasts_and_resume_reenters_with_remaining_time() -> void:
	# Slice 6 Esc menu: pause emits a PAUSED phase (SessionClient broadcasts
	# it); resume re-enters the stored phase with the remaining deadline.
	var rig: Rig = _make_rig(GameSettings.RevealStyle.GRID)
	rig.session.start_game()
	rig.session.on_phase_deadline()   # DRAWING (default 30 s)
	rig.clock.advance(10_000)
	rig.session.pause(0)
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.PAUSED)
	var paused: Dictionary = rig.last_data(NetIds.Phase.PAUSED)
	assert_int(int(paused["resume_phase"])).is_equal(NetIds.Phase.DRAWING)
	rig.clock.advance(120_000)        # a long pause must not eat drawing time
	rig.session.resume()
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.DRAWING)
	var resumed: Dictionary = rig.last_data(NetIds.Phase.DRAWING)
	assert_int(int(resumed["deadline_ms"])).is_equal(rig.clock.ms + 20_000)
	assert_str(str(resumed["prompt_text"])).is_not_empty()   # data preserved


func test_grid_style_fixed_reveal_no_beats() -> void:
	var rig: Rig = _make_rig(GameSettings.RevealStyle.GRID)
	rig.session.start_game()
	rig.session.on_phase_deadline()
	_submit_all(rig)
	assert_int(rig.beats.size()).is_equal(0)
	var data: Dictionary = rig.last_data(NetIds.Phase.REVEAL)
	assert_int(int(data["reveal_style"])).is_equal(GameSettings.RevealStyle.GRID)
	assert_int(int(data["deadline_ms"])).is_equal(
			rig.clock.ms + int(GameConstants.REVEAL_GRID_SEC * 1000.0))
	rig.session.on_phase_deadline()
	assert_int(rig.session.get_phase()).is_equal(NetIds.Phase.JUDGING)
