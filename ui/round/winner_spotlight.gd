class_name WinnerSpotlight
extends VBoxContainer
## Victory-lap presentation (Slice 5 TDD §7): the winner's drawing large,
## author revealed (authorship is public at resolution), caption WITH
## attribution, and an optional stroke replay at the winner timescale.
## Emits lap_finished + EventBus.winner_lap_finished when the presentation
## settles (immediately for static presentations).

signal lap_finished()

var _drawing_id: String = ""
var _player: ReplayPlayer = null
var _texture: ImageTexture = null

@onready var _rect: TextureRect = %SpotlightRect
@onready var _author_label: Label = %AuthorLabel
@onready var _caption_label: Label = %CaptionLabel


func present(drawing_id: String, doc: Dictionary, author_name: String,
		caption: String, timescale: float, animate: bool) -> void:
	_drawing_id = drawing_id
	_author_label.text = "by %s" % author_name
	_caption_label.text = "“%s”" % caption if not caption.is_empty() else ""
	_caption_label.visible = not caption.is_empty()
	var parsed: DrawingDoc = DrawingDoc.from_dict(doc)
	if parsed == null:
		parsed = DrawingDoc.new()
	if animate and not parsed.ops.is_empty():
		_player = ReplayPlayer.new()
		# false: the timescale already encodes the host-set target duration.
		_player.load_doc(parsed, timescale, false)
		_player.finished.connect(_on_lap_done)
		_texture = ImageTexture.create_from_image(_player.get_image())
		_rect.texture = _texture
	else:
		_rect.texture = ImageTexture.create_from_image(DocRasterizer.rasterize(parsed))
		_on_lap_done.call_deferred()


func _process(delta: float) -> void:
	if _player == null:
		return
	_player.advance(delta)
	_texture.update(_player.get_image())


func _on_lap_done() -> void:
	_player = null
	lap_finished.emit()
	EventBus.winner_lap_finished.emit(_drawing_id)
