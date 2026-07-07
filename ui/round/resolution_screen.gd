extends Control
## Round resolution (Slice 3 TDD §7): winner's drawing large with author
## name + points, the rest dimmed small below, live score list alongside.
## Negative scores render with an explicit minus, same styling - no special
## casing (§11). No-pick variant swaps the spotlight for the penalty note.
## Extension point (Slice 5): the enlarged view mounts the victory-lap replay.

const DIMMED_ALPHA: float = 0.5
const THUMB_SIZE: Vector2 = Vector2(120, 95)

@onready var _headline_label: Label = %HeadlineLabel
@onready var _winner_rect: TextureRect = %WinnerRect
@onready var _others_row: HBoxContainer = %OthersRow
@onready var _scores_box: VBoxContainer = %ScoresBox
@onready var _timer: PhaseTimer = %Timer


func setup(data: Dictionary, client: SessionClient) -> void:
	if data.has("deadline_ms"):
		_timer.start(int(data["deadline_ms"]))
	var picked: bool = bool(data.get("picked", false))
	var winner_id: String = str(data.get("winner_drawing_id", ""))
	if picked:
		_headline_label.text = "%s wins the round!  +%d" % [
			str(data.get("winner_display_name", "???")), GameConstants.WINNER_POINTS]
	else:
		_headline_label.text = "The judge couldn't decide... (Judge %d)" \
				% GameConstants.JUDGE_NO_PICK_POINTS
	_build_drawings(client.reveal_entries(), winner_id, picked)
	_build_scores(data.get("scores", {}))


func chat_prominence() -> ChatPanel.Prominence:
	return ChatPanel.Prominence.NORMAL


func _build_drawings(entries: Array[Dictionary], winner_id: String, picked: bool) -> void:
	_winner_rect.visible = false
	for child: Node in _others_row.get_children():
		child.queue_free()
	for entry: Dictionary in entries:
		var drawing_id: String = str(entry.get("drawing_id", ""))
		var texture: ImageTexture = _rasterize(entry.get("doc"))
		if picked and drawing_id == winner_id:
			_winner_rect.texture = texture
			_winner_rect.visible = true
		else:
			var thumb := TextureRect.new()
			thumb.texture = texture
			thumb.custom_minimum_size = THUMB_SIZE
			thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumb.modulate.a = DIMMED_ALPHA
			_others_row.add_child(thumb)


func _build_scores(scores: Dictionary) -> void:
	for child: Node in _scores_box.get_children():
		child.queue_free()
	var header := Label.new()
	header.text = "Scores"
	header.add_theme_font_size_override("font_size", 20)
	_scores_box.add_child(header)
	for player: Roster.PlayerState in Session.roster.players_in_join_order():
		var row := Label.new()
		row.text = "%s: %d" % [player.display_name, int(scores.get(player.platform_id, 0))]
		_scores_box.add_child(row)


static func _rasterize(doc_dict: Variant) -> ImageTexture:
	var doc: DrawingDoc = DrawingDoc.from_dict(doc_dict)
	if doc == null:
		doc = DrawingDoc.new()
	return ImageTexture.create_from_image(DocRasterizer.rasterize(doc))
