class_name ReadyStatusStrip
extends BoxContainer
## Ready-up display (Slice 17): one AvatarChip per player (real avatars
## since Slice 11) plus an empty square that becomes a checkmark when that
## player readies. Optionally hosts the Ready button itself (the chat-header
## surface). Player data is pushed in by the owning screen; the chip itself
## does the avatar lookup (shared-component coupling, cg §8).

signal ready_toggled(ready: bool)

const AVATAR_CHIP: PackedScene = preload("res://ui/shared/avatar_chip.tscn")

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
		var chip: AvatarChip = AVATAR_CHIP.instantiate()
		chip.chip_size = int(CHIP_PX)
		chip.show_name_label = false
		row.add_child(chip)
		chip.bind_platform_id(pid, pname)   # live: refreshes if an avatar lands
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


