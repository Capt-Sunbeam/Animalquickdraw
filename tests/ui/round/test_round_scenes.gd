class_name TestRoundScenes
extends GdUnitTestSuite
## Slice 3 scene smoke tests (TDD §11): every ui/round scene instantiates
## without errors given representative phase data - including negative
## scores and a blank entry. Behavior is covered by the headless
## GameSession suite + the automated round gate + owner playtests.

const ROUND_ROOT: PackedScene = preload("res://ui/round/round_root.tscn")
const INTRO: PackedScene = preload("res://ui/round/round_intro_screen.tscn")
const DRAW: PackedScene = preload("res://ui/round/draw_screen.tscn")
const JUDGE_WAIT: PackedScene = preload("res://ui/round/judge_wait_screen.tscn")
const REVEAL: PackedScene = preload("res://ui/round/reveal_judging_screen.tscn")
const RESOLUTION: PackedScene = preload("res://ui/round/resolution_screen.tscn")
const STANDINGS: PackedScene = preload("res://ui/round/standings_screen.tscn")
const PHASE_TIMER: PackedScene = preload("res://ui/shared/phase_timer.tscn")

const SESSION_CLIENT_SCRIPT: GDScript = preload("res://game/session/session_client.gd")


func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _instantiate(scene: PackedScene) -> Node:
	var node: Node = auto_free(scene.instantiate())
	add_child(node)
	return node


func _make_client_with_entries(entries: Array) -> SessionClient:
	var client: SessionClient = auto_free(SESSION_CLIENT_SCRIPT.new())
	add_child(client)
	# Direct method call (not .rpc) fills the replica exactly like a
	# received broadcast would.
	client.rpc_sync_phase(NetIds.Phase.REVEAL,
			{"entries": entries, "deadline_ms": _now_ms() + 5000})
	return client


func _blank_entry(id: String) -> Dictionary:
	return {"drawing_id": id, "doc": {"v": 1, "orientation": "landscape", "ops": []}}


func _portrait_entry(id: String) -> Dictionary:
	return {"drawing_id": id,
			"doc": {"v": 1, "orientation": "portrait", "ops": [{"t": "clear"}]}}


func test_phase_timer_clamps_to_zero_for_past_deadlines() -> void:
	var timer: PhaseTimer = _instantiate(PHASE_TIMER)
	timer.start(_now_ms() - 5000)
	assert_int(timer.remaining_sec()).is_equal(0)
	assert_str(timer.text).is_equal("0:00")


func test_phase_timer_freezes_while_paused_and_rearms_on_start() -> void:
	# Owner 2026-07-07: pausing must freeze the visible countdown, not just
	# the host's phase progression.
	var timer: PhaseTimer = _instantiate(PHASE_TIMER)
	timer.start(_now_ms() + 30_000)
	EventBus.phase_changed.emit(NetIds.Phase.PAUSED, {})
	timer.text = "frozen-sentinel"
	timer._process(0.016)
	assert_str(timer.text).is_equal("frozen-sentinel")   # no refresh while paused
	# Resume path: refresh_deadline -> start() with a fresh deadline re-arms.
	timer.start(_now_ms() + 5_000)
	timer._process(0.016)
	assert_str(timer.text).is_equal("0:05")


func test_draw_screen_never_auto_submits_while_paused() -> void:
	# Owner 2026-07-07: the local deadline passing DURING a pause must not
	# fire the auto-submit and lock the canvas out from under the drawer.
	var screen: Control = _instantiate(DRAW)
	screen.setup({"prompt_text": "sleepy aardvark",
			"deadline_ms": _now_ms() + 30_000}, null)
	EventBus.phase_changed.emit(NetIds.Phase.PAUSED, {})
	screen._deadline_ms = _now_ms() - 1_000   # deadline lapses mid-pause
	screen._process(0.016)
	assert_bool(screen._locked).is_false()
	# Resume with the host's refreshed deadline: countdown live again, and
	# a genuinely lapsed deadline locks as designed.
	EventBus.phase_changed.emit(NetIds.Phase.DRAWING, {})
	screen.refresh_deadline({"deadline_ms": _now_ms() - 1})
	screen._process(0.016)
	assert_bool(screen._locked).is_true()


func test_round_intro_screen_smoke() -> void:
	var screen: Control = _instantiate(INTRO)
	screen.setup({"round_index": 0, "round_count": 8, "judge_player_id": "nobody",
			"deadline_ms": _now_ms() + 4000}, null)
	var round_label: Label = screen.find_child("RoundLabel", true, false)
	assert_str(round_label.text).is_equal("Round 1 of 8")
	var judge_label: Label = screen.find_child("JudgeLabel", true, false)
	assert_str(judge_label.text).contains("♛")
	assert_str(judge_label.text).contains("is judging")


func test_draw_screen_smoke_embeds_canvas() -> void:
	var screen: Control = _instantiate(DRAW)
	screen.setup({"prompt_text": "sleepy aardvark",
			"deadline_ms": _now_ms() + 30_000}, null)
	var prompt: Label = screen.find_child("PromptLabel", true, false)
	assert_str(prompt.text).is_equal("sleepy aardvark")
	assert_object(screen.find_child("Canvas", true, false)).is_not_null()
	# Side chat, expanded by default (owner 2026-07-07); 💬 toggle collapses.
	assert_int(screen.chat_prominence()).is_equal(ChatPanel.Prominence.NORMAL)
	assert_int(screen.chat_placement()).is_equal(ChatPanel.Placement.SIDE)


func test_judge_wait_screen_smoke_has_no_canvas() -> void:
	var screen: Control = _instantiate(JUDGE_WAIT)
	screen.setup({"prompt_text": "sleepy aardvark",
			"deadline_ms": _now_ms() + 30_000}, null)
	var prompt: Label = screen.find_child("PromptLabel", true, false)
	assert_str(prompt.text).is_equal("SLEEPY AARDVARK")
	# §5: the judge never gets a drawing surface.
	assert_object(screen.find_child("Canvas", true, false)).is_null()
	assert_int(screen.chat_prominence()).is_equal(ChatPanel.Prominence.PROMINENT)


func test_reveal_judging_screen_renders_grid_with_blank_and_portrait_entries() -> void:
	var entries: Array = [_blank_entry("id-blank"), _portrait_entry("id-portrait")]
	var client: SessionClient = _make_client_with_entries(entries)
	var screen: Control = _instantiate(REVEAL)
	screen.setup({"entries": entries, "deadline_ms": _now_ms() + 5000}, client)
	var grid: GridContainer = screen.find_child("Grid", true, false)
	assert_int(grid.get_child_count()).is_equal(2)
	# Non-judge at JUDGING: cells stay unpickable (click-to-pick is
	# judge-only; the crown button is gone - latched-pick, 2026-07-06).
	screen.enter_judging({"deadline_ms": _now_ms() + 30_000})
	for cell: Node in grid.get_children():
		assert_bool((cell as Button).disabled).is_true()


func test_resolution_screen_smoke_picked_and_no_pick_variants() -> void:
	var entries: Array = [_blank_entry("id-a"), _portrait_entry("id-b")]
	var client: SessionClient = _make_client_with_entries(entries)
	var picked: Control = _instantiate(RESOLUTION)
	picked.setup({"picked": true, "winner_drawing_id": "id-b",
			"winner_player_id": "p1", "winner_display_name": "Alice",
			"scores": {"p1": 2, "p0": -1}, "deadline_ms": _now_ms() + 6000}, client)
	var headline: Label = picked.find_child("HeadlineLabel", true, false)
	assert_str(headline.text).contains("Alice")
	assert_str(headline.text).contains("+2")
	var no_pick: Control = _instantiate(RESOLUTION)
	no_pick.setup({"picked": false, "winner_drawing_id": "",
			"winner_player_id": "", "winner_display_name": "",
			"scores": {"p0": -1}, "deadline_ms": _now_ms() + 6000}, client)
	headline = no_pick.find_child("HeadlineLabel", true, false)
	assert_str(headline.text).contains("couldn't decide")
	assert_str(headline.text).contains("-1")


func test_standings_screen_renders_negative_scores_with_minus() -> void:
	var screen: Control = _instantiate(STANDINGS)
	screen.setup({"results": {"standings": [
		{"player_id": "a", "score": 5, "rank": 1},
		{"player_id": "b", "score": -1, "rank": 2},
	]}}, null)
	var rows: VBoxContainer = screen.find_child("Rows", true, false)
	assert_int(rows.get_child_count()).is_equal(2)
	var loser_score: Label = rows.get_child(1).get_child(3)
	assert_str(loser_score.text).is_equal("-1")
	# Not the host in the test env: back button hidden, waiting shown.
	var back: Button = screen.find_child("BackButton", true, false)
	assert_bool(back.visible).is_false()


func test_round_root_swaps_screens_on_phase_changed() -> void:
	var root: Control = _instantiate(ROUND_ROOT)
	var area: Control = root.find_child("PhaseArea", true, false)
	EventBus.phase_changed.emit(NetIds.Phase.ROUND_INTRO, {
		"round_index": 0, "round_count": 6, "judge_player_id": "x",
		"deadline_ms": _now_ms() + 4000,
	})
	assert_object(root.find_child("RoundIntroScreen", true, false)).is_not_null()
	EventBus.phase_changed.emit(NetIds.Phase.WRAP_UP, {"results": {"standings": []}})
	await get_tree().process_frame  # queue_free of the old screen settles
	assert_object(root.find_child("StandingsScreen", true, false)).is_not_null()
	assert_object(area).is_not_null()
