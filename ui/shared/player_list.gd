class_name PlayerList
extends PanelContainer
## Shared roster display (Slice 2 TDD §7) - reused by in-round and wrap-up
## screens later. Name-only rows with a host crown icon + "(host)" label
## (never color alone - cg §13) and an avatar chip placeholder until
## Slice 11. Rebuilds on EventBus.roster_updated.

const HOST_MARK: String = "♛"  # ♛ glyph; paired with the "(host)" text label
const AVATAR_PLACEHOLDER_SIZE: Vector2 = Vector2(24, 24)
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
	var avatar := TextureRect.new()  # placeholder chip slot until Slice 11
	avatar.custom_minimum_size = AVATAR_PLACEHOLDER_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(avatar)
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
	if not state.is_connected:
		row.modulate.a = DISCONNECTED_ALPHA
	return row
