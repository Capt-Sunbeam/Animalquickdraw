class_name CollectionViewer
extends PanelContainer
## Large single-item view (Slice 8 TDD §7): full raster immediately, stroke
## replay on demand (Slice 1 ReplayPlayer, duration cap ON), 1x/2x speed
## applied on the next Replay press, and the three per-item actions. An
## overlay INSIDE the collection screen - not a Nav route - so Back is
## instant and the grid scroll position survives. For missing-doc husks,
## Delete is the only enabled action (§10).

signal closed()
signal export_requested(item_id: String)
signal share_requested(item_id: String)
signal delete_requested(item_id: String)

const SPEEDS: Array[float] = [1.0, 2.0]

var _entry: CollectionIndexEntry = null
var _doc: DrawingDoc = null
var _still: ImageTexture = null
var _replay: ReplayPlayer = null
var _replay_texture: ImageTexture = null
var _speed_index: int = 0

@onready var _back_button: Button = %BackButton
@onready var _title: Label = %TitleLabel
@onready var _date: Label = %DateLabel
@onready var _rect: TextureRect = %DrawingRect
@onready var _missing: Label = %MissingLabel
@onready var _replay_button: Button = %ReplayButton
@onready var _speed_button: Button = %SpeedButton
@onready var _export_button: Button = %ExportButton
@onready var _share_button: Button = %ShareButton
@onready var _delete_button: Button = %DeleteButton


func _ready() -> void:
	_back_button.pressed.connect(func() -> void: closed.emit())
	_replay_button.pressed.connect(_on_replay_pressed)
	_speed_button.pressed.connect(_on_speed_pressed)
	_export_button.pressed.connect(func() -> void: export_requested.emit(_entry.id))
	_share_button.pressed.connect(func() -> void: share_requested.emit(_entry.id))
	_delete_button.pressed.connect(func() -> void: delete_requested.emit(_entry.id))


## doc may be null (index row whose file is gone/corrupt): placeholder +
## Delete-only.
func open(entry: CollectionIndexEntry, doc: DrawingDoc) -> void:
	_entry = entry
	_doc = doc
	_replay = null
	_title.text = "“%s”" % entry.prompt
	_date.text = "saved %s" % entry.saved_date()
	var has_doc: bool = doc != null
	_missing.visible = not has_doc
	_rect.visible = has_doc
	_replay_button.disabled = not has_doc
	_export_button.disabled = not has_doc
	_share_button.disabled = not has_doc
	_replay_button.text = "Replay"
	_speed_button.text = "Speed: %dx" % int(SPEEDS[_speed_index])
	if has_doc:
		_still = ImageTexture.create_from_image(DocRasterizer.rasterize(doc))
		_rect.texture = _still
	visible = true


func close() -> void:
	_replay = null
	visible = false


func item_id() -> String:
	return _entry.id if _entry != null else ""


## Same button plays and skips (§5 viewer sub-state).
func _on_replay_pressed() -> void:
	if _replay != null:
		_replay.skip_to_end()
		_replay_texture.update(_replay.get_image())
		_finish_replay()
		return
	_replay = ReplayPlayer.new()
	# Slice 1 duration cap stays ON here - the collection has no host plan.
	_replay.load_doc(_doc, SPEEDS[_speed_index])
	_replay_texture = ImageTexture.create_from_image(_replay.get_image())
	_rect.texture = _replay_texture
	_replay_button.text = "Skip"


func _finish_replay() -> void:
	_replay = null
	_rect.texture = _still
	_replay_button.text = "Replay"


func _on_speed_pressed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_speed_button.text = "Speed: %dx" % int(SPEEDS[_speed_index])
	# Applied on the next Replay press (v1-simple by design).


func _process(delta: float) -> void:
	if _replay == null:
		return
	if not _replay.advance(delta):
		_finish_replay()
		return
	_replay_texture.update(_replay.get_image())
