class_name SuperlativeCard
extends VBoxContainer
## One superlative award card (Slice 10 TDD §7): award banner, the winning
## drawing with a short stroke-replay flourish (hard-capped at
## WRAPUP_EVIDENCE_REPLAY_MAX_SECONDS), reaction emoji + count, prompt, and
## the author's name small - the wrap-up is the one place authorship is
## celebrated. "+1" chip only when points were actually applied.

var _player: ReplayPlayer = null
var _texture: ImageTexture = null
var _replay_secs: float = 0.0

@onready var _award_label: Label = %AwardLabel
@onready var _drawing_rect: TextureRect = %DrawingRect
@onready var _reaction_label: Label = %ReactionLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _author_label: Label = %AuthorLabel
@onready var _points_chip: Label = %PointsChip


## entry: a bundle superlatives element; drawing: the bundle drawings entry
## ({"doc", "prompt"}); author_name resolved by the caller from standings.
func present(entry: Dictionary, drawing: Dictionary, author_name: String) -> void:
	var reaction: int = clampi(int(entry.get("reaction", 0)), 0,
			TitleIds.SUPERLATIVE_NAMES.size() - 1)
	_award_label.text = "🏆 %s" % TitleIds.SUPERLATIVE_NAMES[reaction]
	_reaction_label.text = "%s ×%d" % [ReactionBar.EMOJI[reaction], int(entry.get("count", 0))]
	_prompt_label.text = "“%s”" % str(entry.get("prompt", ""))
	_author_label.text = "drawn by %s" % author_name
	_points_chip.visible = int(entry.get("points", 0)) > 0
	var parsed: DrawingDoc = DrawingDoc.from_dict(drawing.get("doc"))
	if parsed == null:
		parsed = DrawingDoc.new()
	if parsed.ops.is_empty():
		_drawing_rect.texture = ImageTexture.create_from_image(DocRasterizer.rasterize(parsed))
		return
	var duration: float = ReplayPlanner.compressed_duration(parsed.to_dict())
	var timescale: float = maxf(1.0,
			duration / GameConstants.WRAPUP_EVIDENCE_REPLAY_MAX_SECONDS)
	_replay_secs = ReplayPlanner.replay_secs(parsed.to_dict(), timescale)
	_player = ReplayPlayer.new()
	_player.load_doc(parsed, timescale, false)
	_player.finished.connect(func() -> void: _player = null)
	_texture = ImageTexture.create_from_image(_player.get_image())
	_drawing_rect.texture = _texture


## Total on-screen time the sequence should give this card.
func display_secs() -> float:
	return _replay_secs + GameConstants.WRAPUP_SUPERLATIVE_CARD_SECONDS


func is_animating() -> bool:
	return _player != null


## First Skip press: complete the flourish instantly (TDD §5 skip semantics).
func finish_now() -> void:
	if _player == null:
		return
	var player: ReplayPlayer = _player   # finished-signal handler nulls the field
	player.skip_to_end()
	if _texture != null:
		_texture.update(player.get_image())


func _process(delta: float) -> void:
	if _player == null:
		return
	var player: ReplayPlayer = _player   # the finishing advance nulls the field
	player.advance(delta)                # (finished -> handler) mid-call
	_texture.update(player.get_image())
