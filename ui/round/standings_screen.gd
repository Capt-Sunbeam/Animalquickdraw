extends Control
## Minimal WRAP_UP standings (Slice 3 TDD §7) - deliberately bare: Slice 10
## replaces it with the real wrap-up sequence consuming the same
## SessionResults bundle. Rank, avatar chip placeholder, name, score.

const AVATAR_PLACEHOLDER_SIZE: Vector2 = Vector2(24, 24)

@onready var _rows: VBoxContainer = %Rows
@onready var _back_button: Button = %BackButton
@onready var _waiting_label: Label = %WaitingLabel


func _ready() -> void:
	_back_button.pressed.connect(Session.return_to_lobby)


func setup(data: Dictionary, _client: SessionClient) -> void:
	var results: Dictionary = data.get("results", {})
	var is_host: bool = Session.is_host()
	_back_button.visible = is_host
	_waiting_label.visible = not is_host
	for child: Node in _rows.get_children():
		child.queue_free()
	for raw: Variant in results.get("standings", []):
		if raw is Dictionary:
			_rows.add_child(_build_row(raw))


func chat_prominence() -> ChatPanel.Prominence:
	return ChatPanel.Prominence.NORMAL


func _build_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var rank_label := Label.new()
	rank_label.text = "#%d" % int(entry.get("rank", 0))
	rank_label.custom_minimum_size = Vector2(48, 0)
	rank_label.add_theme_font_size_override("font_size", 22)
	row.add_child(rank_label)
	var avatar := TextureRect.new()   # placeholder chip slot until Slice 11
	avatar.custom_minimum_size = AVATAR_PLACEHOLDER_SIZE
	row.add_child(avatar)
	var player: Roster.PlayerState = Session.roster.get_by_platform_id(
			str(entry.get("player_id", "")))
	var name_label := Label.new()
	name_label.text = player.display_name if player != null else str(entry.get("player_id", "?"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 22)
	row.add_child(name_label)
	var score_label := Label.new()
	score_label.text = str(int(entry.get("score", 0)))  # negatives keep their minus
	score_label.add_theme_font_size_override("font_size", 22)
	row.add_child(score_label)
	return row
