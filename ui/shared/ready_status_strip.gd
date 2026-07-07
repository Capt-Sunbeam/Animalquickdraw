class_name ReadyStatusStrip
extends BoxContainer
## Ready-up display (Slice 17): one chip per player - an initials circle
## (programmer-art avatar placeholder; Slice 11 swaps in real avatars) plus
## an empty square that becomes a checkmark when that player readies.
## Optionally hosts the Ready button itself (the chat-header surface).
## Data is pushed in by the owning screen - no Session coupling (cg §8).

signal ready_toggled(ready: bool)

const CHIP_PX: float = 26.0

var _players: Array[Dictionary] = []   # {"id": String, "name": String}
var _ready_ids: PackedStringArray = PackedStringArray()
var _local_ready: bool = false
var _show_names: bool = false
var _button: Button = null
var _rows: Control = null


## show_button: hosts its own Ready/Unready button (chat header surface).
## show_names: name label next to each chip (the draw screen's side panel);
## the compact header variant shows names as tooltips only.
func setup(show_button: bool, show_names: bool, vertical_layout: bool) -> void:
	vertical = vertical_layout
	_show_names = show_names
	add_theme_constant_override("separation", 6)
	if show_button and _button == null:
		_button = Button.new()
		_button.custom_minimum_size = Vector2(72, 32)
		_button.pressed.connect(_on_button_pressed)
		add_child(_button)
	_rows = VBoxContainer.new() if vertical_layout else HBoxContainer.new()
	(_rows as BoxContainer).add_theme_constant_override("separation", 6)
	add_child(_rows)
	_refresh_button()
	_rebuild()


func set_players(players: Array[Dictionary]) -> void:
	_players = players
	_rebuild()


func set_ready_ids(ids: PackedStringArray) -> void:
	_ready_ids = ids
	_rebuild()


## Drives the button label; the owning surface tracks its own player id.
func set_local_ready(ready: bool) -> void:
	_local_ready = ready
	_refresh_button()


func set_button_enabled(enabled: bool) -> void:
	if _button != null:
		_button.disabled = not enabled
		_button.tooltip_text = "" if enabled else "Pick a winner first"


func _on_button_pressed() -> void:
	ready_toggled.emit(not _local_ready)


func _refresh_button() -> void:
	if _button != null:
		_button.text = "Unready" if _local_ready else "Ready"


func _rebuild() -> void:
	if _rows == null:
		return
	for child: Node in _rows.get_children():
		child.queue_free()
	for player: Dictionary in _players:
		var pid: String = str(player.get("id", ""))
		var pname: String = str(player.get("name", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.tooltip_text = pname
		row.add_child(_make_initials_chip(pname))
		if _show_names:
			var name_label := Label.new()
			name_label.text = pname
			name_label.clip_text = true
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
		var state := Label.new()
		state.text = "✅" if _ready_ids.has(pid) else "☐"
		state.add_theme_font_size_override("font_size", 16)
		row.add_child(state)
		_rows.add_child(row)


## Initials circle in a per-name color - the Slice 11 avatar stand-in.
func _make_initials_chip(pname: String) -> Control:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.from_hsv(float(hash(pname) % 360) / 360.0, 0.45, 0.75)
	style.set_corner_radius_all(int(CHIP_PX / 2.0))
	chip.add_theme_stylebox_override("panel", style)
	chip.custom_minimum_size = Vector2(CHIP_PX, CHIP_PX)
	var initial := Label.new()
	initial.text = pname.left(1).to_upper() if not pname.is_empty() else "?"
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.add_theme_color_override("font_color", Color.WHITE)
	chip.add_child(initial)
	return chip
