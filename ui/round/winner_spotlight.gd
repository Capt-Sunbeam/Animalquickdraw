class_name WinnerSpotlight
extends VBoxContainer
## Victory-lap presentation (Slice 5 TDD §7; caption removed by Slice 16 -
## text lives inside the drawing now): the winner's drawing large, author
## revealed (authorship is public at resolution), and an optional stroke
## replay at the winner timescale. Emits lap_finished +
## EventBus.winner_lap_finished when the presentation settles (immediately
## for static presentations).

signal lap_finished()

var _drawing_id: String = ""
var _player: ReplayPlayer = null
var _texture: ImageTexture = null

@onready var _rect: TextureRect = %SpotlightRect
@onready var _author_label: Label = %AuthorLabel


func present(drawing_id: String, doc: Dictionary, author_name: String,
		timescale: float, animate: bool) -> void:
	_drawing_id = drawing_id
	_author_label.text = "by %s" % author_name
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
	var player: ReplayPlayer = _player   # the finishing advance nulls the field
	player.advance(delta)                # via _on_lap_done mid-call (2026-07-07)
	_texture.update(player.get_image())


func _on_lap_done() -> void:
	_player = null
	lap_finished.emit()
	EventBus.winner_lap_finished.emit(_drawing_id)
