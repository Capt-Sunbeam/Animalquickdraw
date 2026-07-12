class_name TestRevealComponents
extends GdUnitTestSuite
## Slice 5 UI smoke tests (TDD §11; captions removed by Slice 16):
## WinnerSpotlight instantiates and behaves; the reveal screen's stage mode
## responds to beat events and settles into the judging cells. Choreography
## feel is owner territory; the beat schedule itself is covered headless.

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
		{"drawing_id": "id-a", "doc": {"v": 1, "orientation": "landscape", "ops": [
			{"t": "text", "c": 4, "s": 1, "x": 100, "y": 100, "str": "in-image text"}]}},
		{"drawing_id": "id-b", "doc": {"v": 1, "orientation": "portrait", "ops": [{"t": "clear"}]}},
	]


func _client_with_entries(entries: Array) -> SessionClient:
	var client: SessionClient = auto_free(SESSION_CLIENT_SCRIPT.new())
	add_child(client)
	client.rpc_sync_phase(NetIds.Phase.REVEAL,
			{"entries": entries, "deadline_ms": _now_ms() + 20000,
			"reveal_style": GameSettings.RevealStyle.ONE_AT_A_TIME})
	return client


func test_winner_spotlight_static_presentation_finishes() -> void:
	var spotlight: WinnerSpotlight = _instantiate(WINNER_SPOTLIGHT)
	var finished: Array = []
	spotlight.lap_finished.connect(func() -> void: finished.append(true))
	var lapped: Array = []
	var handler: Callable = func(id: String) -> void: lapped.append(id)
	EventBus.winner_lap_finished.connect(handler)
	spotlight.present("id-w", {"v": 1, "orientation": "landscape", "ops": []},
			"Alice", 3.0, false)
	await get_tree().process_frame   # static path completes deferred
	EventBus.winner_lap_finished.disconnect(handler)
	assert_int(finished.size()).is_equal(1)
	assert_array(lapped).contains_exactly(["id-w"])
	var author: Label = spotlight.find_child("AuthorLabel", true, false)
	assert_str(author.text).contains("Alice")


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
	for kudos: KudosButton in screen._kudos_buttons.values():
		assert_bool(kudos.gate_open).is_true()


func test_grid_cells_render_docs_with_text_ops() -> void:
	# Text is pixels inside the doc now - the cell needs no extra label, and
	# the fixed-shape social row keeps its spacer slot for alignment.
	var client: SessionClient = _client_with_entries(_entries())
	var screen: Control = _instantiate(REVEAL)
	screen.setup({"entries": _entries(), "deadline_ms": _now_ms() + 20000,
			"reveal_style": GameSettings.RevealStyle.GRID}, client)
	assert_int(screen._cells.size()).is_equal(2)
	for label: Node in (screen._cells["id-a"] as Button).find_children("*", "Label", true, false):
		assert_str((label as Label).tooltip_text).is_empty()


func test_draw_screen_submission_payload_is_doc_only() -> void:
	var client: SessionClient = auto_free(SESSION_CLIENT_SCRIPT.new())
	add_child(client)
	var screen: Control = _instantiate(DRAW)
	screen.setup({"prompt_text": "sleepy aardvark", "deadline_ms": _now_ms() + 30000}, client)
	assert_object(screen.find_child("Caption", true, false)).is_null()   # UI removed (Slice 16)
	screen._send_current_doc()
	assert_bool(screen._last_submitted_doc.has("ops")).is_true()
	assert_bool(screen._last_submitted_doc.has("caption")).is_false()   # never inside the doc
