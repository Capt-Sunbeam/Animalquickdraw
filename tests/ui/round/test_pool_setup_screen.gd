class_name TestPoolSetupScreen
extends GdUnitTestSuite
## Slice 7 UI smoke tests (TDD §11): columns are generated from phase data
## (2-pool and 1-pool fixtures prove the data-driven layout), the submit
## button gates on locally-valid input, rejections unlock the column, and
## the waiting panel renders progress. Multiplayer behavior is covered by
## the headless GameSession suite + the round gate + owner playtests.

const SCREEN: PackedScene = preload("res://ui/round/pool_setup_screen.tscn")


func before_test() -> void:
	TextFilter.configure(PackedStringArray(["badword"]))


func after_test() -> void:
	TextFilter.configure(PackedStringArray())


func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _setup_screen(pool_ids: Array, share: int) -> Control:
	var screen: Control = auto_free(SCREEN.instantiate())
	add_child(screen)
	var names: Dictionary = {}
	for id: String in pool_ids:
		names[id] = id.capitalize()
	screen.setup({
		"share_per_player": share,
		"pool_ids": PackedStringArray(pool_ids),
		"pool_display_names": names,
		"force_available_at_ms": _now_ms() + 120_000,
	}, null)
	return screen


func _column_edits(screen: Control, pool_id: String) -> Array[LineEdit]:
	var out: Array[LineEdit] = []
	var col: Node = screen.find_child("Col_%s" % pool_id, true, false)
	for child: Node in col.get_children():
		if child is LineEdit:
			out.append(child)
	return out


func _fill(screen: Control, pool_id: String, words: Array) -> void:
	var edits: Array[LineEdit] = _column_edits(screen, pool_id)
	for i: int in range(words.size()):
		edits[i].text = str(words[i])
		edits[i].text_changed.emit(edits[i].text)


func test_columns_generated_from_two_pool_phase_data() -> void:
	var screen: Control = _setup_screen(["animals", "adjectives"], 2)
	var columns: HBoxContainer = screen.find_child("Columns", true, false)
	assert_int(columns.get_child_count()).is_equal(2)
	assert_int(_column_edits(screen, "animals").size()).is_equal(2)
	assert_int(_column_edits(screen, "adjectives").size()).is_equal(2)
	var submit: Button = screen.find_child("Col_animals", true, false)\
			.find_child("Submit", true, false)
	assert_bool(submit.disabled).is_true()   # empty column - nothing to send
	# Headless test env is the "host": the escape hatch row is visible but
	# time-locked until force_available_at_ms.
	var host_row: HBoxContainer = screen.find_child("HostRow", true, false)
	assert_bool(host_row.visible).is_true()
	assert_bool((screen.find_child("ForceButton", true, false) as Button).disabled).is_true()


func test_single_pool_fixture_proves_data_driven_layout() -> void:
	var screen: Control = _setup_screen(["animals"], 3)
	var columns: HBoxContainer = screen.find_child("Columns", true, false)
	assert_int(columns.get_child_count()).is_equal(1)
	assert_int(_column_edits(screen, "animals").size()).is_equal(3)


func test_submit_enables_only_when_full_and_locally_clean() -> void:
	var screen: Control = _setup_screen(["animals"], 2)
	var col: Node = screen.find_child("Col_animals", true, false)
	var submit: Button = col.find_child("Submit", true, false)
	var error: Label = col.find_child("Error", true, false)
	_fill(screen, "animals", ["aardvark"])
	assert_bool(submit.disabled).is_true()    # one box still empty
	_fill(screen, "animals", ["aardvark", "badword"])
	assert_bool(submit.disabled).is_true()    # local TextFilter pre-check
	assert_bool(error.visible).is_true()
	_fill(screen, "animals", ["aardvark", "heron"])
	assert_bool(submit.disabled).is_false()
	assert_bool(error.visible).is_false()


func test_rejection_unlocks_column_with_inline_reason() -> void:
	var screen: Control = _setup_screen(["animals"], 1)
	_fill(screen, "animals", ["aardvark"])
	screen._on_submit_pressed("animals")      # client is null: local lock only
	var edits: Array[LineEdit] = _column_edits(screen, "animals")
	assert_bool(edits[0].editable).is_false() # locked pending host verdict
	EventBus.pool_words_rejected.emit("animals", NetIds.WordRejectReason.NOT_CLEAN)
	assert_bool(edits[0].editable).is_true()  # unlocked to fix and resend
	var error: Label = screen.find_child("Col_animals", true, false)\
			.find_child("Error", true, false)
	assert_bool(error.visible).is_true()
	assert_str(error.text).contains("isn't allowed")


func test_waiting_panel_renders_progress_names_and_checkmarks() -> void:
	var screen: Control = _setup_screen(["animals", "adjectives"], 2)
	EventBus.pool_setup_progress_changed.emit([
		{"player_id": "p0", "display_name": "Sam", "pools_done": 1, "pools_total": 2},
		{"player_id": "p1", "display_name": "Riley", "pools_done": 2, "pools_total": 2},
	])
	var waiting: Label = screen.find_child("WaitingLabel", true, false)
	assert_str(waiting.text).contains("Waiting on: Sam (1/2)")
	assert_str(waiting.text).contains("Riley ✓")
