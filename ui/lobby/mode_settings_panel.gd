class_name ModeSettingsPanel
extends VBoxContainer
## Slice 6 (TDD §7): the mode-dependent settings area. Preset modes render
## a read-only summary of what the preset means; Custom renders the full
## surface. Hosts edit; clients see identical controls disabled ("players
## should know the rules of the game they're in"). Edits emit setting_edited
## and the lobby screen routes them through GameSettings.set_value ->
## Session.set_settings (clients have no edit path at all).

signal setting_edited(key: StringName, value: Variant)

var _updating: bool = false
var _host: bool = false

var _summary: Label
var _custom_grid: GridContainer
var _reveal_option: OptionButton
var _replay_option: OptionButton
var _reveal_secs: SpinBox
var _winner_secs: SpinBox
var _judging_spin: SpinBox
var _title_points_check: CheckBox
var _kudos_option: OptionButton
var _kudos_hint: Label


func _ready() -> void:
	_host = Session.is_host()
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_theme_font_size_override("font_size", 14)
	add_child(_summary)
	_build_custom_grid()


func render(s: GameSettings) -> void:
	_updating = true
	var custom: bool = s.mode == SettingsDefaults.Mode.CUSTOM
	_summary.visible = not custom
	_custom_grid.visible = custom
	if custom:
		_reveal_option.select(_reveal_option.get_item_index(s.reveal_style))
		_replay_option.select(_replay_option.get_item_index(s.replay_mode))
		_reveal_secs.value = s.reveal_replay_secs
		_winner_secs.value = s.winner_replay_secs
		_judging_spin.value = s.judging_window_sec
		_title_points_check.button_pressed = s.title_points_enabled
		_kudos_option.select(_kudos_option.get_item_index(s.kudos_allotment + 1))
		_kudos_hint.text = "Auto = %d for %d rounds" \
				% [KudosLedger.compute_allotment(s.round_count), s.round_count]
		# Combo hints (Slice 5 contract): grid ignores reveal replay; OFF
		# ignores both durations. Editing stays host-only.
		var replays_off: bool = s.replay_mode == GameSettings.ReplayMode.OFF
		_reveal_secs.editable = _host and not replays_off \
				and s.reveal_style != GameSettings.RevealStyle.GRID \
				and s.replay_mode == GameSettings.ReplayMode.FULL
		_winner_secs.editable = _host and not replays_off
	else:
		_summary.text = _summary_text(s)
	_updating = false


func _summary_text(s: GameSettings) -> String:
	var reveal: String = "one-at-a-time" if s.reveal_style == GameSettings.RevealStyle.ONE_AT_A_TIME else "grid"
	var replay: String = ["off", "winner (%ds)" % int(s.winner_replay_secs),
			"full (%ds each, winner %ds)" % [int(s.reveal_replay_secs), int(s.winner_replay_secs)]][s.replay_mode]
	var kudos: String = "auto (%d)" % KudosLedger.compute_allotment(s.round_count) \
			if s.kudos_allotment == GameSettings.KUDOS_AUTO else str(s.kudos_allotment)
	return "Reveal: %s  ·  Replay: %s\nJudging: %d s  ·  Kudos: %s  ·  Title points: %s" % [
		reveal, replay, int(s.judging_window_sec), kudos,
		"on" if s.title_points_enabled else "off",
	]


func _build_custom_grid() -> void:
	_custom_grid = GridContainer.new()
	_custom_grid.columns = 2
	_custom_grid.add_theme_constant_override("h_separation", 10)
	_custom_grid.add_theme_constant_override("v_separation", 8)
	add_child(_custom_grid)

	_reveal_option = _add_option("Reveal style:", [["Grid", GameSettings.RevealStyle.GRID],
			["One-at-a-time", GameSettings.RevealStyle.ONE_AT_A_TIME]], &"reveal_style")
	_replay_option = _add_option("Stroke replay:", [["Off", GameSettings.ReplayMode.OFF],
			["Winner only", GameSettings.ReplayMode.WINNER_ONLY],
			["Full (watch them draw)", GameSettings.ReplayMode.FULL]], &"replay_mode")
	_reveal_secs = _add_spin("Reveal replay time:", GameSettings.REPLAY_SECS_MIN,
			GameSettings.REVEAL_REPLAY_SECS_MAX, 1.0, "s", &"reveal_replay_secs")
	_winner_secs = _add_spin("Winner replay time:", GameSettings.REPLAY_SECS_MIN,
			GameSettings.WINNER_REPLAY_SECS_MAX, 1.0, "s", &"winner_replay_secs")
	_judging_spin = _add_spin("Judging window:", GameConstants.JUDGING_WINDOW_MIN_SEC,
			GameConstants.JUDGING_WINDOW_MAX_SEC, GameConstants.SETTING_STEP_SEC, "s",
			&"judging_window_sec")
	_title_points_check = _add_check("Title points:", &"title_points_enabled")
	# Kudos: item id = value + 1 so AUTO (-1) is a valid id (0).
	var kudos_pairs: Array = [["Auto", GameSettings.KUDOS_AUTO]]
	for i: int in GameConstants.KUDOS_ALLOTMENT_MAX + 1:
		kudos_pairs.append([("%d (off)" % i) if i == 0 else str(i), i])
	_kudos_option = OptionButton.new()
	for pair: Array in kudos_pairs:
		_kudos_option.add_item(str(pair[0]), int(pair[1]) + 1)
	_kudos_option.item_selected.connect(func(index: int) -> void:
		if not _updating:
			setting_edited.emit(&"kudos_allotment", _kudos_option.get_item_id(index) - 1))
	_kudos_option.disabled = not _host
	_add_row("Kudos each:", _kudos_option)
	_kudos_hint = Label.new()
	_kudos_hint.add_theme_font_size_override("font_size", 12)
	_add_row("", _kudos_hint)


func _add_row(label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_custom_grid.add_child(label)
	_custom_grid.add_child(control)


func _add_option(label_text: String, items: Array, key: StringName) -> OptionButton:
	var option := OptionButton.new()
	for pair: Array in items:
		option.add_item(str(pair[0]), int(pair[1]))
	option.item_selected.connect(func(index: int) -> void:
		if not _updating:
			setting_edited.emit(key, option.get_item_id(index)))
	option.disabled = not _host
	_add_row(label_text, option)
	return option


func _add_spin(label_text: String, min_value: float, max_value: float, step: float,
		suffix: String, key: StringName) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.suffix = suffix
	spin.value_changed.connect(func(value: float) -> void:
		if not _updating:
			setting_edited.emit(key, value))
	spin.editable = _host
	_add_row(label_text, spin)
	return spin


func _add_check(label_text: String, key: StringName) -> CheckBox:
	var check := CheckBox.new()
	check.toggled.connect(func(pressed: bool) -> void:
		if not _updating:
			setting_edited.emit(key, pressed))
	check.disabled = not _host
	_add_row(label_text, check)
	return check
