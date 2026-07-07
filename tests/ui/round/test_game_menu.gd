class_name TestGameMenu
extends GdUnitTestSuite
## Slice 6 Esc menu + pause overlay smoke tests: menu toggles, the PAUSED
## broadcast forces the overlay, and a resume refreshes the live screen
## in place instead of rebuilding it (canvas state survives).

const GAME_MENU: PackedScene = preload("res://ui/round/game_menu.tscn")
const ROUND_ROOT: PackedScene = preload("res://ui/round/round_root.tscn")


func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func test_menu_toggle_and_forced_pause_state() -> void:
	var menu: GameMenu = auto_free(GAME_MENU.instantiate())
	add_child(menu)
	assert_bool(menu.visible).is_false()
	menu.toggle()
	assert_bool(menu.visible).is_true()
	menu.toggle()
	assert_bool(menu.visible).is_false()
	# Paused: forced visible; Esc/close cannot dismiss it.
	menu.show_paused()
	assert_bool(menu.visible).is_true()
	menu.toggle()
	menu.close()
	assert_bool(menu.visible).is_true()
	menu.hide_paused()
	assert_bool(menu.visible).is_false()


func test_leave_requires_two_clicks() -> void:
	var menu: GameMenu = auto_free(GAME_MENU.instantiate())
	add_child(menu)
	var leave: Button = menu.find_child("LeaveButton", true, false)
	var before: String = leave.text
	leave.pressed.emit()   # first click arms the confirm, never leaves
	assert_str(leave.text).is_not_equal(before)
	assert_str(leave.text.to_lower()).contains("really")


func test_round_root_pause_keeps_screen_and_resume_refreshes_in_place() -> void:
	var root: Control = auto_free(ROUND_ROOT.instantiate())
	add_child(root)
	EventBus.phase_changed.emit(NetIds.Phase.ROUND_INTRO, {
		"round_index": 0, "round_count": 6, "judge_player_id": "x",
		"deadline_ms": _now_ms() + 4000,
	})
	var screen: Node = root.find_child("RoundIntroScreen", true, false)
	assert_object(screen).is_not_null()
	var menu: GameMenu = root.find_child("Menu", false, false)
	# PAUSED: overlay forced on, the live screen is NOT rebuilt or removed.
	EventBus.phase_changed.emit(NetIds.Phase.PAUSED, {"resume_phase": NetIds.Phase.ROUND_INTRO})
	assert_bool(menu.visible).is_true()
	assert_object(root.find_child("RoundIntroScreen", true, false)).is_same(screen)
	# Resume re-enters the same phase: overlay off, same screen instance.
	EventBus.phase_changed.emit(NetIds.Phase.ROUND_INTRO, {
		"round_index": 0, "round_count": 6, "judge_player_id": "x",
		"deadline_ms": _now_ms() + 2000,
	})
	assert_bool(menu.visible).is_false()
	assert_object(root.find_child("RoundIntroScreen", true, false)).is_same(screen)
