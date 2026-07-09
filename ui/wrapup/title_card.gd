class_name TitleCard
extends VBoxContainer
## One per-player title card (Slice 10 TDD §7): title name, player name (a
## chip once Slice 11 lands), stat line, and the evidence drawings fanned
## side by side as STATIC renders - only superlatives get the replay
## flourish, keeping title cards snappy. Disconnected players render dimmed
## with a "(left early)" tag.

const EVIDENCE_SIZE: Vector2 = Vector2(220, 165)
const DIMMED: Color = Color(1.0, 1.0, 1.0, 0.55)

@onready var _title_label: Label = %TitleLabel
@onready var _name_label: Label = %NameLabel
@onready var _stat_label: Label = %StatLabel
@onready var _points_chip: Label = %PointsChip
@onready var _evidence_row: HBoxContainer = %EvidenceRow
@onready var _chip_slot: CenterContainer = %ChipSlot


## entry: a bundle titles element; evidence: bundle drawings entries
## ({"doc", "prompt"}) in evidence order, already capped by the calculator.
func present(entry: Dictionary, display_name: String, connected: bool,
		evidence: Array[Dictionary]) -> void:
	_title_label.text = TitleIds.display_name(str(entry.get("id", "")))
	_name_label.text = display_name if connected else "%s (left early)" % display_name
	if not connected:
		_name_label.modulate = DIMMED
	# Slice 11: the titled player's face, large (§7: 96 px on title cards).
	# End-of-game snapshot data - the roster still holds every entry here.
	var pid: String = str(entry.get("player_id", ""))
	var player: Roster.PlayerState = Session.roster.get_by_platform_id(pid)
	var chip: AvatarChip = preload("res://ui/shared/avatar_chip.tscn").instantiate()
	chip.chip_size = 96
	chip.show_name_label = false
	if not connected:
		chip.modulate = DIMMED
	_chip_slot.add_child(chip)
	chip.set_player(display_name, pid, player.avatar_doc if player != null else {})
	_stat_label.text = str(entry.get("stat_label", ""))
	_points_chip.visible = int(entry.get("points", 0)) > 0
	for drawing: Dictionary in evidence:
		var parsed: DrawingDoc = DrawingDoc.from_dict(drawing.get("doc"))
		if parsed == null:
			continue
		var rect := TextureRect.new()
		rect.custom_minimum_size = EVIDENCE_SIZE
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture = ImageTexture.create_from_image(DocRasterizer.rasterize(parsed))
		rect.tooltip_text = str(drawing.get("prompt", ""))
		_evidence_row.add_child(rect)


func display_secs() -> float:
	return GameConstants.WRAPUP_TITLE_CARD_SECONDS


func is_animating() -> bool:
	return false


func finish_now() -> void:
	pass   # static card - nothing to complete
