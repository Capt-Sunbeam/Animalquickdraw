class_name TestRevealComponents
extends GdUnitTestSuite
## Slice 5 UI smoke tests (TDD §11): CaptionInput / WinnerSpotlight
## instantiate and behave; the reveal screen's stage mode responds to beat
## events and settles into the judging cells. Choreography feel is owner
## territory; the beat schedule itself is covered headless.

const CAPTION_INPUT: PackedScene = preload("res://ui/round/caption_input.tscn")
const WINNER_SPOTLIGHT: PackedScene = preload("res://ui/round/winner_spotlight.tscn")
const REVEAL: PackedScene = preload("res://ui/round/reveal_judging_screen.tscn")
const DRAW: PackedScene = preload("res://ui/round/draw_screen.tscn")
const SESSION_CLIENT_SCRIPT: GDScript = preload("res://game/session/session_client.gd")


func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _instantiate(scene: PackedScene) -> Node:
	var node: Node = auto_free(scene.instantiate())
	add_child(node)
	return node


func _entries() -> Array:
	return [
		{"drawing_id": "id-a", "doc": {"v": 1, "orientation": "landscape", "ops": []},
			"caption": "it's resting"},
		{"drawing_id": "id-b", "doc": {"v": 1, "orientation": "portrait", "ops": [{"t": "clear"}]},
			"caption": ""},
	]


func _client_with_entries(entries: Array) -> SessionClient:
	var client: SessionClient = auto_free(SESSION_CLIENT_SCRIPT.new())
	add_child(client)
	client.rpc_sync_phase(NetIds.Phase.REVEAL,
			{"entries": entries, "deadline_ms": _now_ms() + 20000,
			"reveal_style": GameSettings.RevealStyle.ONE_AT_A_TIME})
	return client


func test_caption_input_expands_and_pre_censors() -> void:
	var input: CaptionInput = _instantiate(CAPTION_INPUT)
	var edit: LineEdit = input.find_child("CaptionEdit", true, false)
	assert_bool(edit.visible).is_false()
	(input.find_child("CaptionChip", true, false) as Button).pressed.emit()
	assert_bool(edit.visible).is_true()
	assert_int(edit.max_length).is_equal(GameConstants.CAPTION_MAX_CHARS)
	edit.text = "  hello there  "
	assert_str(input.caption_text()).is_equal(TextFilter.censor("hello there"))


func test_winner_spotlight_static_presentation_finishes() -> void:
	var spotlight: WinnerSpotlight = _instantiate(WINNER_SPOTLIGHT)
	var finished: Array = []
	spotlight.lap_finished.connect(func() -> void: finished.append(true))
	var lapped: Array = []
	var handler: Callable = func(id: String) -> void: lapped.append(id)
	EventBus.winner_lap_finished.connect(handler)
	spotlight.present("id-w", {"v": 1, "orientation": "landscape", "ops": []},
			"Alice", "a masterpiece", 3.0, false)
	await get_tree().process_frame   # static path completes deferred
	EventBus.winner_lap_finished.disconnect(handler)
	assert_int(finished.size()).is_equal(1)
	assert_array(lapped).contains_exactly(["id-w"])
	var author: Label = spotlight.find_child("AuthorLabel", true, false)
	assert_str(author.text).contains("Alice")
	var caption: Label = spotlight.find_child("CaptionLabel", true, false)
	assert_str(caption.text).contains("a masterpiece")


func test_stage_mode_hides_cells_then_beats_reveal_them() -> void:
	var client: SessionClient = _client_with_entries(_entries())
	var screen: Control = _instantiate(REVEAL)
	screen.setup({"entries": _entries(), "deadline_ms": _now_ms() + 20000,
			"reveal_style": GameSettings.RevealStyle.ONE_AT_A_TIME}, client)
	# Slots reserved but invisible until each drawing's beat settles.
	for cell: Button in screen._cells.values():
		assert_float(cell.modulate.a).is_equal(0.0)
	EventBus.reveal_beat_started.emit(0, "id-a", 5.0)
	assert_bool(screen._stage.visible).is_true()
	assert_str(screen._header_label.text).contains("1 / 2")
	# Next beat hard-snaps the previous card into its cell.
	EventBus.reveal_beat_started.emit(1, "id-b", 5.0)
	assert_float((screen._cells["id-a"] as Button).modulate.a).is_equal(1.0)
	EventBus.reveal_gathered.emit()
	assert_bool(screen._stage.visible).is_false()
	for cell: Button in screen._cells.values():
		assert_float(cell.modulate.a).is_equal(1.0)
	# JUDGING proceeds exactly as before (same screen, no swap).
	screen.enter_judging({"deadline_ms": _now_ms() + 30000})
	for bar: ReactionBar in screen._reaction_bars.values():
		assert_bool(bar.interactive).is_true()


func test_grid_cells_show_caption_line_with_tooltip() -> void:
	var client: SessionClient = _client_with_entries(_entries())
	var screen: Control = _instantiate(REVEAL)
	screen.setup({"entries": _entries(), "deadline_ms": _now_ms() + 20000,
			"reveal_style": GameSettings.RevealStyle.GRID}, client)
	var captioned: Button = screen._cells["id-a"]
	var found: bool = false
	for label: Node in captioned.find_children("*", "Label", true, false):
		if (label as Label).tooltip_text == "it's resting":
			found = true
	assert_bool(found).is_true()


func test_draw_screen_caption_rides_submission_payload() -> void:
	var client: SessionClient = auto_free(SESSION_CLIENT_SCRIPT.new())
	add_child(client)
	var screen: Control = _instantiate(DRAW)
	screen.setup({"prompt_text": "sleepy aardvark", "deadline_ms": _now_ms() + 30000}, client)
	var caption_input: CaptionInput = screen.find_child("Caption", true, false)
	assert_bool(caption_input.visible).is_true()   # comments_enabled default
	(caption_input.find_child("CaptionEdit", true, false) as LineEdit).text = "wow"
	screen._send_current_doc()
	# The client cached the doc; the caption went out beside it (host strips
	# or censors authoritatively - covered headless).
	assert_bool(screen._last_submitted_doc.has("ops")).is_true()
	assert_bool(screen._last_submitted_doc.has("caption")).is_false()   # never inside the doc
