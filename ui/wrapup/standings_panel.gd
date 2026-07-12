class_name StandingsPanel
extends VBoxContainer
## Final-standings act (Slice 10 TDD §7): rows reveal 3rd -> 2nd -> 1st as
## podium steps, then the rest as a list. Each row shows rank, name, and the
## final score (title-point breakdown in the tooltip); tied ranks repeat the
## rank number; negatives keep a true minus sign. The winner row gets a mild
## scale pulse - fast and silly, not an award show (§1). Replaces Slice 3's
## placeholder standings screen.

signal finished()

const WINNER_PULSE_SCALE: Vector2 = Vector2(1.06, 1.06)

var _rows: Array[Control] = []
var _reveal_queue: Array[int] = []       # child indices in reveal order
var _step_timer: Timer = null
var _done: bool = false

@onready var _rows_box: VBoxContainer = %Rows


func _ready() -> void:
	_step_timer = Timer.new()
	_step_timer.one_shot = true
	_step_timer.timeout.connect(_reveal_next)
	add_child(_step_timer)


## standings: the bundle standings array (rank order, ties already ordered).
func present(standings: Array) -> void:
	for raw: Variant in standings:
		if not raw is Dictionary:
			continue
		var row: Control = _build_row(raw)
		row.visible = false
		_rows.append(row)
		_rows_box.add_child(row)
	# Podium reveal order: 3rd, 2nd, 1st (those that exist), then the rest.
	for i: int in [2, 1, 0]:
		if i < _rows.size():
			_reveal_queue.append(i)
	for i: int in range(3, _rows.size()):
		_reveal_queue.append(i)
	if _reveal_queue.is_empty():
		_finish()
	else:
		_reveal_next()


func is_animating() -> bool:
	return not _done


## Skip: reveal everything instantly (TDD §5 Standings -> Done on skip).
func finish_now() -> void:
	if _done:
		return
	_step_timer.stop()
	while not _reveal_queue.is_empty():
		_rows[_reveal_queue.pop_front()].visible = true
	_finish()


func _reveal_next() -> void:
	if _reveal_queue.is_empty():
		_finish()
		return
	var index: int = _reveal_queue.pop_front()
	_rows[index].visible = true
	if index == 0:
		_pulse_winner(_rows[index])
	if _reveal_queue.is_empty():
		_finish()
	else:
		_step_timer.start(GameConstants.WRAPUP_STANDINGS_STEP_SECONDS)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func _pulse_winner(row: Control) -> void:
	row.pivot_offset = row.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(row, "scale", WINNER_PULSE_SCALE, 0.15)
	tween.tween_property(row, "scale", Vector2.ONE, 0.25)


func _build_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var rank_label := Label.new()
	rank_label.text = "#%d" % int(entry.get("rank", 0))
	rank_label.custom_minimum_size = Vector2(48, 0)
	rank_label.add_theme_font_size_override("font_size", 22)
	row.add_child(rank_label)
	# Slice 11: standings chips at 48 (§7). Roster still holds every entry.
	var pid: String = str(entry.get("player_id", ""))
	var player: Roster.PlayerState = Session.roster.get_by_platform_id(pid)
	var chip: AvatarChip = preload("res://ui/shared/avatar_chip.tscn").instantiate()
	chip.chip_size = 48
	chip.show_name_label = false
	row.add_child(chip)
	chip.set_player(str(entry.get("display_name", pid)), pid,
			player.avatar_doc if player != null else {})
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = str(entry.get("display_name", entry.get("player_id", "?")))
	if not bool(entry.get("connected", true)):
		name_label.text += " (left early)"
		name_label.modulate = Color(1.0, 1.0, 1.0, 0.55)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 22)
	row.add_child(name_label)
	var score_label := Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = str(int(entry.get("final_score", 0)))   # negatives keep their minus
	score_label.add_theme_font_size_override("font_size", 22)
	var title_points: int = int(entry.get("title_points", 0))
	if title_points != 0:
		score_label.tooltip_text = "%d base + %d title points" \
				% [int(entry.get("base_score", 0)), title_points]
		score_label.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(score_label)
	return row
