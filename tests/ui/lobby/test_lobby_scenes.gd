class_name TestLobbyScenes
extends GdUnitTestSuite
## Slice 2 scene smoke tests (TDD §11): every new scene instantiates without
## errors, and the ChatPanel prominence setter applies all three layouts.
## Deep UI automation is not required in v1 (cg §9) - behavior is covered by
## the owner playtest checkpoints.

const CHAT_PANEL: PackedScene = preload("res://ui/shared/chat_panel.tscn")
const PLAYER_LIST: PackedScene = preload("res://ui/shared/player_list.tscn")
const LOBBY_SCREEN: PackedScene = preload("res://ui/lobby/lobby_screen.tscn")
const JOIN_DIALOG: PackedScene = preload("res://ui/menu/join_dialog.tscn")
const MAIN_MENU: PackedScene = preload("res://ui/menu/main_menu_screen.tscn")


func _instantiate(scene: PackedScene) -> Node:
	var node: Node = auto_free(scene.instantiate())
	add_child(node)
	return node


func test_lobby_screen_smoke_instantiates_as_client_view() -> void:
	var screen: Control = _instantiate(LOBBY_SCREEN)
	assert_object(screen).is_not_null()
	# No active peer in the test env -> client view: Start hidden, spinners
	# swapped for read-only labels.
	var start_button: Button = screen.find_child("StartButton", true, false)
	assert_bool(start_button.visible).is_false()
	var rounds_spin: SpinBox = screen.find_child("RoundsSpin", true, false)
	assert_bool(rounds_spin.visible).is_false()
	var rounds_value: Label = screen.find_child("RoundsValue", true, false)
	assert_bool(rounds_value.visible).is_true()


func test_player_list_rebuild_renders_rows_and_count() -> void:
	var list: PanelContainer = _instantiate(PLAYER_LIST)
	list.rebuild([
		{"peer_id": 1, "display_name": "Alice", "joined_order": 0},
		{"peer_id": 2, "display_name": "Bob", "joined_order": 1, "is_connected": false},
	])
	var count_label: Label = list.find_child("CountLabel", true, false)
	assert_str(count_label.text).is_equal("Players (2/%d)" % GameConstants.MAX_PLAYERS)
	var rows: VBoxContainer = list.find_child("Rows", true, false)
	assert_int(rows.get_child_count()).is_equal(2)
	# Host row carries the crown glyph AND the "(host)" text label (cg §13:
	# never color alone).
	var host_label: Label = rows.get_child(0).get_child(1)
	assert_str(host_label.text).contains("♛")
	assert_str(host_label.text).contains("(host)")
	assert_str(host_label.text).contains("Alice")


func test_chat_panel_prominence_setter_applies_all_three_states() -> void:
	var chat: ChatPanel = _instantiate(CHAT_PANEL)
	var history: RichTextLabel = chat.find_child("History", true, false)
	var input_row: HBoxContainer = chat.find_child("InputRow", true, false)
	var strip: Label = chat.find_child("CollapsedStrip", true, false)

	chat.prominence = ChatPanel.Prominence.NORMAL
	assert_bool(history.visible).is_true()
	assert_bool(input_row.visible).is_true()
	assert_bool(strip.visible).is_false()
	assert_float(history.custom_minimum_size.y).is_equal(ChatPanel.HISTORY_HEIGHT_NORMAL)

	chat.prominence = ChatPanel.Prominence.COLLAPSED
	assert_bool(history.visible).is_false()
	assert_bool(input_row.visible).is_false()
	assert_bool(strip.visible).is_true()

	# PROMINENT height adapts to the viewport (owner, 2026-07-06): the
	# expanded chat must never crowd the grid's social rows.
	chat.prominence = ChatPanel.Prominence.PROMINENT
	assert_bool(history.visible).is_true()
	# f32 tolerance: custom_minimum_size is a Vector2 (32-bit), the reference
	# math is 64-bit. Slice 18's stretch mode made the headless viewport hit
	# the ratio path (base 720) and exposed the exact-compare mismatch.
	assert_float(history.custom_minimum_size.y).is_equal_approx(
			ChatPanel.prominent_history_height(chat.get_viewport_rect().size.y), 0.001)
	assert_int(history.get_theme_font_size("normal_font_size"))\
			.is_equal(ChatPanel.PROMINENT_FONT_SIZE)


func test_chat_panel_prominent_height_clamps_to_viewport() -> void:
	# The sizing rule itself, pinned across window extremes.
	assert_float(ChatPanel.prominent_history_height(400.0))\
			.is_equal(ChatPanel.HISTORY_HEIGHT_MIN)           # tiny window -> floor
	assert_float(ChatPanel.prominent_history_height(720.0))\
			.is_equal(720.0 * ChatPanel.PROMINENT_HEIGHT_RATIO)  # ~158 px at 720p
	assert_float(ChatPanel.prominent_history_height(2160.0))\
			.is_equal(ChatPanel.HISTORY_HEIGHT_PROMINENT_MAX)  # huge window -> cap


func test_chat_panel_toggle_button_expands_and_collapses_never_hover() -> void:
	var chat: ChatPanel = _instantiate(CHAT_PANEL)
	var history: RichTextLabel = chat.find_child("History", true, false)
	var toggle: Button = chat.find_child("ToggleButton", true, false)
	chat.prominence = ChatPanel.Prominence.COLLAPSED
	assert_bool(history.visible).is_false()
	# Hover must NOT expand (owner, 2026-07-06: it kept firing mid-stroke).
	chat.mouse_entered.emit()
	assert_bool(history.visible).is_false()
	# The explicit button does.
	toggle.pressed.emit()
	assert_bool(history.visible).is_true()
	assert_bool(chat.is_expanded()).is_true()
	toggle.pressed.emit()
	assert_bool(history.visible).is_false()


func test_chat_panel_unread_badge_counts_while_collapsed_and_clears() -> void:
	var chat: ChatPanel = _instantiate(CHAT_PANEL)
	var toggle: Button = chat.find_child("ToggleButton", true, false)
	chat.prominence = ChatPanel.Prominence.COLLAPSED
	EventBus.chat_message_received.emit(2, "Alice", "one")
	EventBus.chat_message_received.emit(3, "Bob", "two")
	assert_str(toggle.text).contains("2")
	toggle.pressed.emit()   # expanding clears the badge
	assert_str(toggle.text).is_equal("Hide")
	toggle.pressed.emit()
	assert_str(toggle.text).is_equal("Show")   # re-collapse, nothing new


func test_chat_panel_side_placement_sizes_column() -> void:
	var chat: ChatPanel = _instantiate(CHAT_PANEL)
	var strip: Label = chat.find_child("CollapsedStrip", true, false)
	chat.placement = ChatPanel.Placement.SIDE
	chat.prominence = ChatPanel.Prominence.COLLAPSED
	# Collapsed side column shrinks to the toggle; no preview strip.
	assert_bool(strip.visible).is_false()
	assert_float(chat.custom_minimum_size.x).is_equal(0.0)
	var toggle: Button = chat.find_child("ToggleButton", true, false)
	toggle.pressed.emit()
	assert_float(chat.custom_minimum_size.x).is_equal(ChatPanel.SIDE_WIDTH)
	assert_int(chat.size_flags_vertical).is_equal(Control.SIZE_EXPAND_FILL)


func test_chat_panel_renders_messages_from_event_bus() -> void:
	var chat: ChatPanel = _instantiate(CHAT_PANEL)
	var history: RichTextLabel = chat.find_child("History", true, false)
	EventBus.chat_message_received.emit(2, "Alice", "hello there")
	EventBus.chat_message_received.emit(3, "Bob", "[b]not bbcode[/b]")
	var text: String = history.get_parsed_text()
	assert_str(text).contains("Alice: hello there")
	# User text must never be parsed as BBCode markup.
	assert_str(text).contains("[b]not bbcode[/b]")


func test_join_dialog_uppercases_and_trims_code() -> void:
	var dialog: ConfirmationDialog = _instantiate(JOIN_DIALOG)
	var received: Array[String] = []
	dialog.join_requested.connect(func(code: String) -> void: received.append(code))
	var code_edit: LineEdit = dialog.find_child("CodeEdit", true, false)
	code_edit.text = "  local2 "
	dialog.confirmed.emit()
	assert_array(received).contains_exactly(["LOCAL2"])


func test_join_dialog_ignores_empty_code() -> void:
	var dialog: ConfirmationDialog = _instantiate(JOIN_DIALOG)
	var received: Array[String] = []
	dialog.join_requested.connect(func(code: String) -> void: received.append(code))
	var code_edit: LineEdit = dialog.find_child("CodeEdit", true, false)
	code_edit.text = "   "
	dialog.confirmed.emit()
	assert_array(received).is_empty()


func test_main_menu_still_smoke_instantiates_with_join_dialog() -> void:
	var menu: Control = _instantiate(MAIN_MENU)
	assert_object(menu.find_child("JoinDialog", true, false)).is_not_null()


# --- Slice 12: Steam affordances (TDD 12 §11 UI tests) ---


class InviteStubBackend:
	extends PlatformBackend
	func supports_invites() -> bool:
		return true


func test_lobby_invite_button_hidden_without_invite_support() -> void:
	# Test env runs the ENet backend -> no invite affordance, no dead UI.
	var screen: Control = _instantiate(LOBBY_SCREEN)
	var invite: Button = screen.find_child("InviteButton", true, false)
	assert_object(invite).is_not_null()
	assert_bool(invite.visible).is_false()


func test_lobby_invite_button_visible_with_invite_support() -> void:
	var original: PlatformBackend = Platform.backend
	Platform.backend = InviteStubBackend.new()
	var screen: Control = _instantiate(LOBBY_SCREEN)
	Platform.backend = original
	var invite: Button = screen.find_child("InviteButton", true, false)
	assert_bool(invite.visible).is_true()


func test_menu_offline_mode_disables_multiplayer_buttons() -> void:
	var menu_script: GDScript = load("res://ui/menu/main_menu_screen.gd")
	var dialog_shown_before: bool = menu_script._offline_dialog_shown
	menu_script._offline_dialog_shown = true   # skip the one-time popup
	Platform.platform_ok = false
	var menu: Control = _instantiate(MAIN_MENU)
	Platform.platform_ok = true
	menu_script._offline_dialog_shown = dialog_shown_before
	var host_button: Button = menu.find_child("HostButton", true, false)
	var join_button: Button = menu.find_child("JoinButton", true, false)
	assert_bool(host_button.disabled).is_true()
	assert_bool(join_button.disabled).is_true()
	assert_str(host_button.tooltip_text).is_not_empty()
	# Local features stay available (design brief §14 local-first).
	var collection_button: Button = menu.find_child("CollectionButton", true, false)
	assert_bool(collection_button.disabled).is_false()
