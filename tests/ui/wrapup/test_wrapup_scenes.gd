class_name TestWrapupScenes
extends GdUnitTestSuite
## Slice 10 UI/relay tests (TDD §11): the EventBus signal order contract on
## WRAP_UP, bundle validation at the relay, scene smokes for all four wrap-up
## components, skip semantics, and the empty-bundle fast-forward.

const WRAP_UP_SCREEN: PackedScene = preload("res://ui/wrapup/wrap_up_screen.tscn")
const SUPERLATIVE_CARD: PackedScene = preload("res://ui/wrapup/superlative_card.tscn")
const TITLE_CARD: PackedScene = preload("res://ui/wrapup/title_card.tscn")
const STANDINGS_PANEL: PackedScene = preload("res://ui/wrapup/standings_panel.tscn")
const SESSION_CLIENT_SCRIPT: GDScript = preload("res://game/session/session_client.gd")


func _stroke_doc() -> Dictionary:
	return {"v": 1, "orientation": "landscape", "ops": [
		{"t": "stroke", "c": 0, "s": 0, "pts": [10.0, 10.0, 60.0, 60.0], "ts": [0.0, 1.0]},
	]}


func _valid_bundle() -> Dictionary:
	return {
		"v": 1, "early_end": false, "rounds_completed": 2,
		"superlatives": [{"id": "funniest", "reaction": 0, "drawing_id": "d0",
				"author_id": "p1", "count": 3, "round": 0, "prompt": "sleepy aardvark",
				"points": 1}],
		"titles": [{"id": TitleIds.HOTSHOT, "player_id": "p0", "stat_value": 2,
				"stat_label": "2 kudos received", "evidence_drawing_ids": ["d0"],
				"points": 1}],
		"standings": [
			{"player_id": "p0", "display_name": "Alice", "rank": 1, "base_score": 3,
					"title_points": 1, "final_score": 4, "connected": true},
			{"player_id": "p1", "display_name": "Bob", "rank": 2, "base_score": -1,
					"title_points": 1, "final_score": 0, "connected": false},
		],
		"kudos": {"p0": {"granted": 2, "spent": 2}},
		"drawings": {"d0": {"doc": _stroke_doc(), "prompt": "sleepy aardvark"}},
	}


func _instantiate_screen() -> Control:
	var screen: Control = auto_free(WRAP_UP_SCREEN.instantiate())
	add_child(screen)
	return screen


# --- SessionClient relay: signal order + validation ---


func test_wrap_up_signals_fire_in_documented_order_before_phase_changed() -> void:
	var client: SessionClient = auto_free(SESSION_CLIENT_SCRIPT.new())
	add_child(client)
	var order: Array[String] = []
	var titles_map: Dictionary = {}
	var ended_standings: Array = []
	var on_results: Callable = func(_r: Dictionary) -> void: order.append("results")
	var on_started: Callable = func(_b: Dictionary) -> void: order.append("started")
	var on_titles: Callable = func(map: Dictionary) -> void:
		order.append("titles")
		titles_map.merge(map)   # mutate - lambda captures are by-value
	var on_ended: Callable = func(standings: Array, _b: Dictionary) -> void:
		order.append("ended")
		ended_standings.append_array(standings)
	var on_phase: Callable = func(p: NetIds.Phase, _d: Dictionary) -> void:
		if p == NetIds.Phase.WRAP_UP:
			order.append("phase")
	EventBus.session_results_ready.connect(on_results)
	EventBus.wrap_up_started.connect(on_started)
	EventBus.titles_awarded.connect(on_titles)
	EventBus.game_ended.connect(on_ended)
	EventBus.phase_changed.connect(on_phase)
	client.rpc_sync_phase(NetIds.Phase.WRAP_UP, {"results": {
		"standings": [], "wrap_up": _valid_bundle()}})
	EventBus.session_results_ready.disconnect(on_results)
	EventBus.wrap_up_started.disconnect(on_started)
	EventBus.titles_awarded.disconnect(on_titles)
	EventBus.game_ended.disconnect(on_ended)
	EventBus.phase_changed.disconnect(on_phase)
	assert_array(order).contains_exactly(["results", "started", "titles", "ended", "phase"])
	assert_dict(titles_map).is_equal({"p0": TitleIds.HOTSHOT})
	assert_int(ended_standings.size()).is_equal(2)


func test_malformed_bundle_drops_wrap_up_signals_but_keeps_results() -> void:
	var client: SessionClient = auto_free(SESSION_CLIENT_SCRIPT.new())
	add_child(client)
	var seen: Dictionary = {"results": false, "started": false}
	var on_results: Callable = func(_r: Dictionary) -> void: seen["results"] = true
	var on_started: Callable = func(_b: Dictionary) -> void: seen["started"] = true
	EventBus.session_results_ready.connect(on_results)
	EventBus.wrap_up_started.connect(on_started)
	var bad: Dictionary = _valid_bundle()
	bad["v"] = 2   # future version - drop with a warning, never crash
	client.rpc_sync_phase(NetIds.Phase.WRAP_UP, {"results": {"wrap_up": bad}})
	EventBus.session_results_ready.disconnect(on_results)
	EventBus.wrap_up_started.disconnect(on_started)
	assert_bool(bool(seen["results"])).is_true()
	assert_bool(bool(seen["started"])).is_false()


func test_bundle_validator_rejects_shape_violations() -> void:
	assert_bool(SessionClient.is_valid_wrap_up_bundle(_valid_bundle())).is_true()
	assert_bool(SessionClient.is_valid_wrap_up_bundle(null)).is_false()
	assert_bool(SessionClient.is_valid_wrap_up_bundle("nope")).is_false()
	var missing: Dictionary = _valid_bundle()
	missing.erase("standings")
	assert_bool(SessionClient.is_valid_wrap_up_bundle(missing)).is_false()
	var wrong_type: Dictionary = _valid_bundle()
	wrong_type["drawings"] = []
	assert_bool(SessionClient.is_valid_wrap_up_bundle(wrong_type)).is_false()


# --- wrap-up screen sequence ---


func test_screen_with_empty_results_fast_forwards_to_post_game() -> void:
	var screen: Control = _instantiate_screen()
	var seen: Dictionary = {"finished": false}
	var on_finished: Callable = func() -> void: seen["finished"] = true
	EventBus.wrap_up_sequence_finished.connect(on_finished)
	screen.setup({"results": {"standings": []}}, null)
	EventBus.wrap_up_sequence_finished.disconnect(on_finished)
	assert_bool(bool(seen["finished"])).is_true()   # empty acts pass through instantly (§5)
	var post_game: Control = screen.find_child("PostGame", true, false)
	assert_bool(post_game.visible).is_true()
	var skip: Button = screen.find_child("SkipButton", true, false)
	assert_bool(skip.visible).is_false()
	# Not the host in the test env: back hidden, waiting shown.
	var back: Button = screen.find_child("BackButton", true, false)
	assert_bool(back.visible).is_false()


func test_screen_skip_semantics_finish_then_advance_through_all_acts() -> void:
	var screen: Control = _instantiate_screen()
	screen.setup({"results": {"wrap_up": _valid_bundle()}}, null)
	# Act 1: superlative card, replay flourish running.
	var card: Control = screen._card
	assert_object(card).is_instanceof(SuperlativeCard)
	assert_bool(card.is_animating()).is_true()
	screen._on_skip_pressed()                       # 1st press: finish the flourish
	assert_bool(card.is_animating()).is_false()
	assert_object(screen._card).is_same(card)       # still the same card
	screen._on_skip_pressed()                       # 2nd press: advance
	assert_object(screen._card).is_instanceof(TitleCard)
	var name_label: Label = screen._card.find_child("NameLabel", true, false)
	assert_str(name_label.text).is_equal("Alice")   # resolved from standings
	screen._on_skip_pressed()                       # static card: advance directly
	assert_object(screen._card).is_instanceof(StandingsPanel)
	assert_bool((screen._card as StandingsPanel).is_animating()).is_true()
	var seen: Dictionary = {"finished": false}
	var on_finished: Callable = func() -> void: seen["finished"] = true
	EventBus.wrap_up_sequence_finished.connect(on_finished)
	screen._on_skip_pressed()                       # reveal all -> sequence done
	EventBus.wrap_up_sequence_finished.disconnect(on_finished)
	assert_bool(bool(seen["finished"])).is_true()
	assert_bool((screen.find_child("PostGame", true, false) as Control).visible).is_true()


func test_screen_early_end_badge_wording() -> void:
	var screen: Control = _instantiate_screen()
	var bundle: Dictionary = _valid_bundle()
	bundle["early_end"] = true
	bundle["rounds_completed"] = 1
	screen.setup({"results": {"wrap_up": bundle}}, null)
	var badge: Label = screen.find_child("RoundsBadge", true, false)
	assert_str(badge.text).is_equal("ended early • 1 round")


# --- component smokes ---


func test_superlative_card_presents_award_replay_and_author() -> void:
	var card: SuperlativeCard = auto_free(SUPERLATIVE_CARD.instantiate())
	add_child(card)
	var bundle: Dictionary = _valid_bundle()
	card.present(bundle["superlatives"][0], bundle["drawings"]["d0"], "Bob")
	assert_str((card.find_child("AwardLabel", true, false) as Label).text)\
			.is_equal("🏆 Funniest Drawing")
	assert_str((card.find_child("ReactionLabel", true, false) as Label).text)\
			.is_equal("😂 ×3")
	assert_str((card.find_child("AuthorLabel", true, false) as Label).text)\
			.is_equal("drawn by Bob")
	assert_bool((card.find_child("PointsChip", true, false) as Label).visible).is_true()
	assert_bool(card.is_animating()).is_true()
	assert_float(card.display_secs())\
			.is_greater(GameConstants.WRAPUP_SUPERLATIVE_CARD_SECONDS - 0.001)
	card.finish_now()
	assert_bool(card.is_animating()).is_false()


func test_title_card_marks_disconnected_players_and_fans_evidence() -> void:
	var card: TitleCard = auto_free(TITLE_CARD.instantiate())
	add_child(card)
	var bundle: Dictionary = _valid_bundle()
	var evidence: Array[Dictionary] = [bundle["drawings"]["d0"]]
	card.present(bundle["titles"][0], "Bob", false, evidence)
	assert_str((card.find_child("TitleLabel", true, false) as Label).text)\
			.is_equal("Hotshot")
	assert_str((card.find_child("NameLabel", true, false) as Label).text)\
			.is_equal("Bob (left early)")
	assert_str((card.find_child("StatLabel", true, false) as Label).text)\
			.is_equal("2 kudos received")
	assert_int((card.find_child("EvidenceRow", true, false) as HBoxContainer)\
			.get_child_count()).is_equal(1)


func test_standings_panel_renders_negatives_and_breakdown_tooltip() -> void:
	var panel: StandingsPanel = auto_free(STANDINGS_PANEL.instantiate())
	add_child(panel)
	panel.present([
		{"player_id": "a", "display_name": "Alice", "rank": 1, "base_score": 4,
				"title_points": 1, "final_score": 5, "connected": true},
		{"player_id": "b", "display_name": "Bob", "rank": 2, "base_score": -1,
				"title_points": 0, "final_score": -1, "connected": true},
	])
	panel.finish_now()
	var rows: VBoxContainer = panel.find_child("Rows", true, false)
	assert_int(rows.get_child_count()).is_equal(2)
	for row: Node in rows.get_children():
		assert_bool((row as Control).visible).is_true()
	var winner_score: Label = rows.get_child(0).find_child("ScoreLabel", false, false)
	assert_str(winner_score.text).is_equal("5")
	assert_str(winner_score.tooltip_text).is_equal("4 base + 1 title points")
	var loser_score: Label = rows.get_child(1).find_child("ScoreLabel", false, false)
	assert_str(loser_score.text).is_equal("-1")   # true minus, no clamping
