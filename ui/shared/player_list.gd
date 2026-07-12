class_name PlayerList
extends PanelContainer
## Shared roster display (Slice 2 TDD §7) - rows with a real AvatarChip
## (Slice 11), name, and a host crown icon + "(host)" label (never color
## alone - cg §13). Rebuilds on EventBus.roster_updated.
## Slice 13: with allow_kick the HOST additionally sees a Kick button on
## every other connected row. The list only emits kick_requested; the
## owning screen confirms and calls Session.kick_player (same decoupling
## as ChatPanel.message_submitted).

## Slice 13: the owning screen confirmed nothing yet - this is the raw click.
signal kick_requested(peer_id: int, display_name: String)

const AVATAR_CHIP: PackedScene = preload("res://ui/shared/avatar_chip.tscn")

## Set by the owning scene (lobby screen sets true). Non-hosts never see
## the control regardless.
@export var allow_kick: bool = false

const HOST_MARK: String = "♛"  # ♛ glyph; paired with the "(host)" text label
const CHIP_PX: int = 48        # TDD 11 §7: lobby chips at 48
const DISCONNECTED_ALPHA: float = 0.45

@onready var _count_label: Label = %CountLabel
@onready var _rows: VBoxContainer = %Rows


func _ready() -> void:
	EventBus.roster_updated.connect(rebuild)
	rebuild(Session.roster.to_dicts())


## players: Array of PlayerState dicts (the roster_updated payload shape).
func rebuild(players: Array) -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	var states: Array[Roster.PlayerState] = []
	for raw: Variant in players:
		if raw is Dictionary:
			states.append(Roster.PlayerState.from_dict(raw))
	states.sort_custom(func(a: Roster.PlayerState, b: Roster.PlayerState) -> bool:
		return a.joined_order < b.joined_order)
	_count_label.text = "Players (%d/%d)" % [states.size(), GameConstants.MAX_PLAYERS]
	for state: Roster.PlayerState in states:
		_rows.add_child(_build_row(state))


func _build_row(state: Roster.PlayerState) -> HBoxContainer:
	var row := HBoxContainer.new()
	var chip: AvatarChip = AVATAR_CHIP.instantiate()
	chip.chip_size = CHIP_PX
	chip.show_name_label = false   # this row renders its own crown/host label
	row.add_child(chip)
	chip.set_player(state.display_name, state.platform_id, state.avatar_doc)
	var name_label := Label.new()
	var is_host_player: bool = state.peer_id == 1
	name_label.text = "%s%s%s" % [
		HOST_MARK + " " if is_host_player else "",
		state.display_name,
		" (host)" if is_host_player else "",
	]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	if allow_kick and Session.is_host() and not is_host_player and state.is_connected:
		var kick := Button.new()
		kick.text = "Kick"
		kick.tooltip_text = "Remove this player - they can't rejoin this game"
		kick.pressed.connect(func() -> void:
			kick_requested.emit(state.peer_id, state.display_name))
		row.add_child(kick)
	if not state.is_connected:
		row.modulate.a = DISCONNECTED_ALPHA
	return row
