extends Control
## Lobby screen (Slice 2 TDD §7). Hosts see editable settings and the Start
## gate; clients see live read-only settings. UI never mutates
## Session.roster/settings directly - it calls Session actions and
## re-renders on EventBus signals (TDD §8 rule).

var _updating_ui: bool = false  # guards value_changed while applying syncs

@onready var _room_code_label: Label = %RoomCodeLabel
@onready var _leave_button: Button = %LeaveButton
@onready var _settings_note: Label = %SettingsNote
@onready var _rounds_spin: SpinBox = %RoundsSpin
@onready var _rounds_value: Label = %RoundsValue
@onready var _suggested_tag: Label = %SuggestedTag
@onready var _draw_time_spin: SpinBox = %DrawTimeSpin
@onready var _draw_time_value: Label = %DrawTimeValue
@onready var _pool_option: OptionButton = %PoolOption
@onready var _mode_option: OptionButton = %ModeOption
@onready var _chat: ChatPanel = %Chat
@onready var _start_button: Button = %StartButton
@onready var _start_hint: Label = %StartHint
@onready var _starting_overlay: PanelContainer = %StartingOverlay
@onready var _toast: Toast = %Toast


func _ready() -> void:
	EventBus.roster_updated.connect(_on_roster_updated)
	EventBus.lobby_settings_changed.connect(_on_settings_changed)
	EventBus.game_started.connect(_on_game_started)
	_room_code_label.text = "Room code: %s" % Session.room_code
	_leave_button.pressed.connect(Session.leave)
	_chat.prominence = ChatPanel.Prominence.NORMAL
	_chat.message_submitted.connect(Session.submit_chat)
	_setup_settings_controls()
	_start_button.pressed.connect(Session.start_game)
	_start_button.visible = Session.is_host()
	_starting_overlay.visible = false
	_apply_settings_dict(Session.settings.to_dict())
	_refresh_start_gate()


func _setup_settings_controls() -> void:
	var host: bool = Session.is_host()
	_settings_note.text = "(you set these)" if host else "(host controls these)"
	_rounds_spin.visible = host
	_draw_time_spin.visible = host
	_rounds_value.visible = not host
	_draw_time_value.visible = not host
	if host:
		_rounds_spin.min_value = GameConstants.ROUNDS_MIN
		_rounds_spin.max_value = GameConstants.ROUNDS_MAX
		_rounds_spin.value_changed.connect(_on_rounds_edited)
		_draw_time_spin.min_value = GameConstants.DRAW_TIME_MIN_SEC
		_draw_time_spin.max_value = GameConstants.DRAW_TIME_MAX_SEC
		_draw_time_spin.step = 5.0
		_draw_time_spin.value_changed.connect(_on_draw_time_edited)
	# Placeholder selectors: only Built-in / Default selectable until
	# Slices 7 / 6 - the rest render greyed with a "(coming soon)" hint.
	_pool_option.clear()
	_pool_option.add_item("Built-in", GameSettings.PoolSource.BUILT_IN)
	_pool_option.add_item("Player-created (coming soon)", GameSettings.PoolSource.PLAYER_CREATED)
	_pool_option.set_item_disabled(1, true)
	_pool_option.disabled = not host
	_pool_option.tooltip_text = "More prompt pools coming soon"
	_mode_option.clear()
	_mode_option.add_item("Default", SettingsDefaults.Mode.DEFAULT)
	_mode_option.add_item("Streamlined (coming soon)", SettingsDefaults.Mode.STREAMLINED)
	_mode_option.add_item("Social (coming soon)", SettingsDefaults.Mode.SOCIAL)
	_mode_option.add_item("Custom (coming soon)", SettingsDefaults.Mode.CUSTOM)
	for i: int in range(1, _mode_option.item_count):
		_mode_option.set_item_disabled(i, true)
	_mode_option.disabled = not host
	_mode_option.tooltip_text = "More modes coming soon"


func _on_rounds_edited(value: float) -> void:
	if _updating_ui:
		return
	var s: GameSettings = Session.settings.duplicate_settings()
	s.round_count = int(value)
	s.rounds_overridden = true  # host touched the spinner; stop auto-suggesting
	Session.set_settings(s)


func _on_draw_time_edited(value: float) -> void:
	if _updating_ui:
		return
	var s: GameSettings = Session.settings.duplicate_settings()
	s.draw_time_sec = value
	Session.set_settings(s)


func _on_settings_changed(settings_dict: Dictionary) -> void:
	_apply_settings_dict(settings_dict)


func _apply_settings_dict(d: Dictionary) -> void:
	_updating_ui = true
	var s: GameSettings = GameSettings.from_dict(d)
	_rounds_spin.value = s.round_count
	_rounds_value.text = str(s.round_count)
	_suggested_tag.visible = not s.rounds_overridden
	_draw_time_spin.value = s.draw_time_sec
	_draw_time_value.text = "%d s" % int(s.draw_time_sec)
	_pool_option.select(_pool_option.get_item_index(s.pool_source))
	_mode_option.select(_mode_option.get_item_index(s.mode))
	_updating_ui = false


func _on_roster_updated(_players: Array) -> void:
	_refresh_start_gate()


func _refresh_start_gate() -> void:
	var count: int = Session.roster.connected_count()
	if not Session.is_host():
		_start_hint.text = "Waiting for the host to start..." \
				if count >= GameConstants.MIN_PLAYERS \
				else "Waiting for players (%d/%d minimum)..." % [count, GameConstants.MIN_PLAYERS]
		return
	_start_button.disabled = not Session.can_start()
	var missing: int = GameConstants.MIN_PLAYERS - count
	if missing > 0:
		_start_hint.text = "Need %d more player%s" % [missing, "" if missing == 1 else "s"]
	else:
		_start_hint.text = ""


func _on_game_started(_start_data: Dictionary) -> void:
	# Freeze the lobby; Slice 3 replaces this placeholder with the round
	# handoff (Nav to RoundRoot).
	_starting_overlay.visible = true
	_start_button.disabled = true
	_leave_button.disabled = true
	_rounds_spin.editable = false
	_draw_time_spin.editable = false
	_pool_option.disabled = true
	_mode_option.disabled = true
