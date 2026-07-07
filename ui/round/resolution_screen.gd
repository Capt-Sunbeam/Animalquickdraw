extends Control
## Round resolution (Slice 3 TDD §7): winner's drawing large with author
## name + points, the rest dimmed small below, live score list alongside.
## Negative scores render with an explicit minus, same styling - no special
## casing (§11). No-pick variant swaps the spotlight for the penalty note.
## Extension point (Slice 5): the enlarged view mounts the victory-lap replay.

const DIMMED_ALPHA: float = 0.5
const THUMB_SIZE: Vector2 = Vector2(120, 95)
const WINNER_SPOTLIGHT_SCENE: PackedScene = preload("res://ui/round/winner_spotlight.tscn")

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
		_mount_spotlight(data, winner_id, client)   # Slice 5 victory lap
	else:
		_headline_label.text = "The judge couldn't decide... (Judge %d)" \
				% GameConstants.JUDGE_NO_PICK_POINTS
	_build_drawings(client.reveal_entries(), winner_id, picked)
	_build_scores(data.get("scores", {}))


## Slice 5 victory lap: winner large, author revealed, caption attributed,
## strokes replayed unless replay_mode == OFF. No-pick rounds never get here.
func _mount_spotlight(data: Dictionary, winner_id: String, client: SessionClient) -> void:
	_winner_rect.visible = false
	var doc: Dictionary = client.get_drawing_doc(winner_id)
	var caption: String = ""
	for entry: Dictionary in client.reveal_entries():
		if str(entry.get("drawing_id", "")) == winner_id:
			caption = str(entry.get("caption", ""))
	var spotlight: WinnerSpotlight = WINNER_SPOTLIGHT_SCENE.instantiate()
	spotlight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spotlight.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var main: Node = _winner_rect.get_parent()
	main.add_child(spotlight)
	main.move_child(spotlight, _winner_rect.get_index())
	var animate: bool = Session.game_settings.replay_mode != GameSettings.ReplayMode.OFF
	spotlight.present(winner_id, doc, str(data.get("winner_display_name", "???")),
			caption, ReplayPlanner.winner_timescale(doc, Session.game_settings.winner_replay_secs),
			animate)


func chat_prominence() -> ChatPanel.Prominence:
	return ChatPanel.Prominence.NORMAL


## Slice 6 pause: fresh deadline after a host resume.
func refresh_deadline(data: Dictionary) -> void:
	if data.has("deadline_ms"):
		_timer.start(int(data["deadline_ms"]))


func _build_drawings(entries: Array[Dictionary], winner_id: String, picked: bool) -> void:
	if not picked:
		_winner_rect.visible = false   # spotlight mounts only on picked rounds
	for child: Node in _others_row.get_children():
		child.queue_free()
	for entry: Dictionary in entries:
		var drawing_id: String = str(entry.get("drawing_id", ""))
		if picked and drawing_id == winner_id:
			continue   # the winner lives in the Slice 5 spotlight
		else:
			var texture: ImageTexture = _rasterize(entry.get("doc"))
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
