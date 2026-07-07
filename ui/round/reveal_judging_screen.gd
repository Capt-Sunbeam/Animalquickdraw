extends Control
## Anonymous grid for REVEAL + JUDGING - one screen, two phases (Slice 3
## TDD §7). Each entry's DrawingDoc is rasterized client-side once to a
## cached ImageTexture (cg §12); the grid shows textures, never live
## canvases, in the broadcast (already shuffled) order with orientation
## preserved. No names anywhere. Judge gets a pick affordance at JUDGING.
## Extension points: Slice 4 hangs reactions/kudos off cells by drawing_id;
## Slice 5 swaps the entry animation per settings.reveal_style.

const CELL_MIN_SIZE: Vector2 = Vector2(240, 190)
const SELECTED_COLOR: Color = Color(1.0, 0.85, 0.3)

var _client: SessionClient = null
var _judging: bool = false
var _selected_id: String = ""
var _pick_sent: bool = false
var _cells: Dictionary = {}   # drawing_id -> Button

@onready var _header_label: Label = %HeaderLabel
@onready var _timer: PhaseTimer = %Timer
@onready var _grid: GridContainer = %Grid
@onready var _pick_button: Button = %PickButton


func _ready() -> void:
	_pick_button.pressed.connect(_on_pick_confirmed)
	_pick_button.visible = false


func setup(data: Dictionary, client: SessionClient) -> void:
	_client = client
	_header_label.text = "Behold!"
	if data.has("deadline_ms"):
		_timer.start(int(data["deadline_ms"]))
	_build_grid(client.reveal_entries())


func enter_judging(data: Dictionary) -> void:
	_judging = true
	if data.has("deadline_ms"):
		_timer.start(int(data["deadline_ms"]))
	if _client != null and _client.is_local_player_judge():
		_header_label.text = "♛ Pick your favorite!"
		_pick_button.visible = true
		_pick_button.disabled = true
		for cell: Button in _cells.values():
			cell.disabled = false
	else:
		var judge: Roster.PlayerState = Session.roster.get_by_platform_id(
				_client.judge_player_id() if _client != null else "")
		var judge_name: String = judge.display_name if judge != null else "The judge"
		_header_label.text = "%s is deciding..." % judge_name


func chat_prominence() -> ChatPanel.Prominence:
	return ChatPanel.Prominence.PROMINENT  # riffing window (§5)


func _build_grid(entries: Array[Dictionary]) -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	_cells.clear()
	_grid.columns = clampi(ceili(sqrt(float(entries.size()))), 1, 4)
	for entry: Dictionary in entries:
		var drawing_id: String = str(entry.get("drawing_id", ""))
		var cell: Button = _build_cell(drawing_id, entry.get("doc"))
		_grid.add_child(cell)
		_cells[drawing_id] = cell


func _build_cell(drawing_id: String, doc_dict: Variant) -> Button:
	var cell := Button.new()
	cell.custom_minimum_size = CELL_MIN_SIZE
	cell.disabled = true   # pickable only for the judge at JUDGING
	cell.pressed.connect(_on_cell_pressed.bind(drawing_id))
	var rect := TextureRect.new()
	rect.texture = _rasterize(doc_dict)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.offset_left = 8.0
	rect.offset_top = 8.0
	rect.offset_right = -8.0
	rect.offset_bottom = -8.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(rect)
	return cell


## Client-side rasterization through the Slice 1 renderer - deterministic
## CPU raster, cached as a texture for the rest of the round.
static func _rasterize(doc_dict: Variant) -> ImageTexture:
	var doc: DrawingDoc = DrawingDoc.from_dict(doc_dict)
	if doc == null:
		doc = DrawingDoc.new()   # renders as a blank white canvas
	return ImageTexture.create_from_image(DocRasterizer.rasterize(doc))


func _on_cell_pressed(drawing_id: String) -> void:
	if not _judging or _pick_sent:
		return
	_selected_id = drawing_id
	_pick_button.disabled = false
	for id: String in _cells.keys():
		var cell: Button = _cells[id]
		cell.modulate = SELECTED_COLOR if id == drawing_id else Color.WHITE


func _on_pick_confirmed() -> void:
	if _selected_id.is_empty() or _pick_sent or _client == null:
		return
	_pick_sent = true   # one pick; the host drops duplicates anyway
	_pick_button.disabled = true
	_pick_button.text = "Crowned!"
	_client.request_pick_winner(_selected_id)
