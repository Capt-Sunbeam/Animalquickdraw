extends Control
## Anonymous grid for REVEAL + JUDGING - one screen, two phases (Slice 3
## TDD §7). Each entry's DrawingDoc is rasterized client-side once to a
## cached ImageTexture (cg §12); the grid shows textures, never live
## canvases, in the broadcast (already shuffled) order with orientation
## preserved. No names anywhere. Judge gets a pick affordance at JUDGING.
## Extension points: Slice 4 hangs reactions/kudos off cells by drawing_id;
## Slice 5 swaps the entry animation per settings.reveal_style.

const CELL_MIN_SIZE: Vector2 = Vector2(340, 310)   # roomy social row (owner feedback)
const SOCIAL_HINT_WIDTH: float = 64.0              # "🔒 yours" slot, reserved in every cell
const KUDOS_BUTTON_SIZE: Vector2 = Vector2(116, 36)
const SELECTED_COLOR: Color = Color(1.0, 0.85, 0.3)
const REACTION_BAR_SCENE: PackedScene = preload("res://ui/round/reaction_bar.tscn")
const KUDOS_BUTTON_SCENE: PackedScene = preload("res://ui/round/kudos_button.tscn")

var _client: SessionClient = null
var _judging: bool = false
var _selected_id: String = ""
var _cells: Dictionary = {}          # drawing_id -> Button
var _reaction_bars: Dictionary = {}  # drawing_id -> ReactionBar (Slice 4)
var _kudos_buttons: Dictionary = {}  # drawing_id -> KudosButton (Slice 4)

# Slice 5 one-at-a-time stage state. The stage is an overlay INSIDE this
# screen so beats settle into the REAL judging cells - the REVEAL->JUDGING
# transition is seamless by construction (no screen swap, no layout jump).
var _style: int = GameSettings.RevealStyle.GRID
var _staged_id: String = ""
var _replay: ReplayPlayer = null
var _replay_texture: ImageTexture = null
var _beat_tween: Tween = null
var _stage: CenterContainer = null
var _stage_rect: TextureRect = null
var _stage_social: HBoxContainer = null

@onready var _header_label: Label = %HeaderLabel
@onready var _timer: PhaseTimer = %Timer
@onready var _grid: GridContainer = %Grid
@onready var _toast: Toast = %Toast


func _ready() -> void:
	# Slice 4: local save feedback (kudos-save from SessionClient, self-save
	# from the retiring draw screen - both land while this screen is up).
	EventBus.collection_item_added.connect(_on_collection_item_added)
	EventBus.collection_save_failed.connect(_on_collection_save_failed)
	# Slice 5: host-clocked reveal beats.
	EventBus.reveal_beat_started.connect(_on_reveal_beat)
	EventBus.reveal_gathered.connect(_on_reveal_gathered)
	_build_stage()


func setup(data: Dictionary, client: SessionClient) -> void:
	_client = client
	_style = int(data.get("reveal_style", GameSettings.RevealStyle.GRID))
	_header_label.text = "Behold!"
	if data.has("deadline_ms"):
		_timer.start(int(data["deadline_ms"]))
	_build_grid(client.reveal_entries())
	if _style == GameSettings.RevealStyle.ONE_AT_A_TIME:
		# Cards appear one per beat; slots stay reserved (transparent).
		for cell: Button in _cells.values():
			cell.modulate.a = 0.0
	else:
		# GRID style: everything pops in with a single short fade.
		_grid.modulate.a = 0.0
		create_tween().tween_property(_grid, "modulate:a", 1.0,
				GameConstants.REVEAL_GRID_FADE_SECS)


func enter_judging(data: Dictionary) -> void:
	_judging = true
	_finish_stage(true)   # Slice 5: hard-snap any straggling beat/gather
	if data.has("deadline_ms"):
		_timer.start(int(data["deadline_ms"]))
	_set_social_open(true)   # Slice 4: gate opens with JUDGING (§5)
	if _client != null and _client.is_local_player_judge():
		_header_label.text = "♛ Click a drawing to crown it!"
		for cell: Button in _cells.values():
			cell.disabled = false
	else:
		var judge: Roster.PlayerState = Session.roster.get_by_platform_id(
				_client.judge_player_id() if _client != null else "")
		var judge_name: String = judge.display_name if judge != null else "The judge"
		_header_label.text = "%s is deciding..." % judge_name


func chat_prominence() -> ChatPanel.Prominence:
	return ChatPanel.Prominence.PROMINENT  # riffing window (§5)


## Slice 6 pause: fresh deadline after a host resume; grid/stage state stays.
func refresh_deadline(data: Dictionary) -> void:
	if data.has("deadline_ms"):
		_timer.start(int(data["deadline_ms"]))


func _build_grid(entries: Array[Dictionary]) -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	_cells.clear()
	_reaction_bars.clear()
	_kudos_buttons.clear()
	_grid.columns = clampi(ceili(sqrt(float(entries.size()))), 1, 4)
	for entry: Dictionary in entries:
		var drawing_id: String = str(entry.get("drawing_id", ""))
		var cell: Button = _build_cell(drawing_id, entry.get("doc"))
		_grid.add_child(cell)
		_cells[drawing_id] = cell


func _build_cell(drawing_id: String, doc_dict: Variant) -> Button:
	var cell := Button.new()
	cell.theme_type_variation = &"CardButton"
	cell.custom_minimum_size = CELL_MIN_SIZE
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.disabled = true   # pickable only for the judge at JUDGING
	cell.pressed.connect(_on_cell_pressed.bind(drawing_id))
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 8.0
	layout.offset_top = 8.0
	layout.offset_right = -8.0
	layout.offset_bottom = -8.0
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(layout)
	var rect := TextureRect.new()
	rect.texture = _rasterize(doc_dict)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(rect)
	# Slice 4 social block. FIXED shape in every cell so the grid lines up
	# (owner feedback 2026-07-06: rows aligned terribly): row 1 = centered
	# reactions, row 2 = yours-hint | spacer | kudos (center slot was the
	# caption until Slice 16; the spacer keeps alignment). Empty slots keep
	# their space - ownership never reflows a cell. Own-cell state is LOCAL
	# knowledge only - nothing on the wire marks authorship.
	var own: bool = _client != null and _client.is_own_drawing(drawing_id)
	var bar: ReactionBar = REACTION_BAR_SCENE.instantiate()
	bar.drawing_id = drawing_id
	bar.interactive = false   # gate opens with JUDGING
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.reaction_toggled.connect(_on_reaction_toggled.bind(drawing_id))
	layout.add_child(bar)
	var info_row := HBoxContainer.new()
	info_row.custom_minimum_size = Vector2(0, KUDOS_BUTTON_SIZE.y)
	layout.add_child(info_row)
	var yours := Label.new()
	yours.text = "🔒 yours" if own else ""
	yours.custom_minimum_size = Vector2(SOCIAL_HINT_WIDTH, 0)
	yours.add_theme_font_size_override("font_size", 12)
	yours.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(yours)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(spacer)
	var kudos: KudosButton = KUDOS_BUTTON_SCENE.instantiate()
	kudos.drawing_id = drawing_id
	kudos.own_drawing = own
	kudos.gate_open = false
	kudos.custom_minimum_size = KUDOS_BUTTON_SIZE
	kudos.kudos_requested.connect(_on_kudos_requested.bind(drawing_id))
	info_row.add_child(kudos)
	_reaction_bars[drawing_id] = bar
	_kudos_buttons[drawing_id] = kudos
	return cell


# --- Slice 5: one-at-a-time stage ---


## Programmer-art stage overlay: big card + fresh social row.
func _build_stage() -> void:
	_stage = CenterContainer.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.visible = false
	add_child(_stage)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)
	_stage.add_child(card)
	_stage_rect = TextureRect.new()
	_stage_rect.custom_minimum_size = Vector2(520, 390)
	_stage_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stage_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.add_child(_stage_rect)
	_stage_social = HBoxContainer.new()
	_stage_social.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(_stage_social)


## A beat: hard-snap the previous card into its cell, stage this drawing
## (replaying strokes when replay_mode == FULL), open its social row, and
## schedule the shrink-to-grid for the tail of the beat.
func _on_reveal_beat(index: int, drawing_id: String, beat_secs: float) -> void:
	if _client == null or not _cells.has(drawing_id):
		return
	_finish_stage(false)
	_staged_id = drawing_id
	var entry_count: int = _cells.size()
	_header_label.text = "Behold!  (%d / %d)" % [index + 1, entry_count]
	var doc: Dictionary = _client.get_drawing_doc(drawing_id)
	var parsed: DrawingDoc = DrawingDoc.from_dict(doc)
	if parsed == null:
		parsed = DrawingDoc.new()
	_replay = null
	if Session.game_settings.replay_mode == GameSettings.ReplayMode.FULL \
			and not parsed.ops.is_empty():
		_replay = ReplayPlayer.new()
		# false: the planner timescale IS the plan (host-set target duration).
		_replay.load_doc(parsed, ReplayPlanner.reveal_timescale(
				doc, Session.game_settings.reveal_replay_secs, entry_count), false)
		_replay_texture = ImageTexture.create_from_image(_replay.get_image())
		_stage_rect.texture = _replay_texture
	else:
		_stage_rect.texture = _rasterize(doc)
	_build_stage_social(drawing_id)
	_stage.visible = true
	_stage.modulate.a = 0.0
	_beat_tween = create_tween()
	_beat_tween.tween_property(_stage, "modulate:a", 1.0, GameConstants.REVEAL_CARD_IN_SECS)
	_beat_tween.tween_interval(maxf(0.0, beat_secs
			- GameConstants.REVEAL_CARD_IN_SECS - GameConstants.REVEAL_TO_GRID_SECS))
	_beat_tween.tween_property(_stage, "modulate:a", 0.0, GameConstants.REVEAL_TO_GRID_SECS)
	_beat_tween.tween_callback(_finish_stage.bind(false))


func _build_stage_social(drawing_id: String) -> void:
	for child: Node in _stage_social.get_children():
		child.queue_free()
	var own: bool = _client != null and _client.is_own_drawing(drawing_id)
	var bar: ReactionBar = REACTION_BAR_SCENE.instantiate()
	bar.drawing_id = drawing_id
	bar.reaction_toggled.connect(_on_reaction_toggled.bind(drawing_id))
	_stage_social.add_child(bar)
	bar.interactive = not own
	var kudos: KudosButton = KUDOS_BUTTON_SCENE.instantiate()
	kudos.drawing_id = drawing_id
	kudos.custom_minimum_size = KUDOS_BUTTON_SIZE
	kudos.kudos_requested.connect(_on_kudos_requested.bind(drawing_id))
	_stage_social.add_child(kudos)
	kudos.own_drawing = own
	kudos.gate_open = true   # host still validates (per-beat gate)


## Settles the current beat: card leaves the stage, its grid cell appears.
## everything=true also reveals every cell (gather / judging catch-all).
func _finish_stage(everything: bool) -> void:
	if _beat_tween != null and _beat_tween.is_valid():
		_beat_tween.kill()
	_beat_tween = null
	_replay = null
	if _stage != null:
		_stage.visible = false
	if not _staged_id.is_empty() and _cells.has(_staged_id):
		(_cells[_staged_id] as Button).modulate.a = 1.0
	_staged_id = ""
	if everything:
		for cell: Button in _cells.values():
			cell.modulate.a = 1.0


func _on_reveal_gathered() -> void:
	_finish_stage(true)
	_header_label.text = "Behold!"


func _process(delta: float) -> void:
	if _replay == null:
		return
	if not _replay.advance(delta):
		_replay = null
		return
	_replay_texture.update(_replay.get_image())


## Slice 4: flips the social controls when the reaction gate opens/closes
## (client-side mirror of the host gate - the host still validates).
func _set_social_open(open: bool) -> void:
	for id: String in _reaction_bars.keys():
		var own: bool = _client != null and _client.is_own_drawing(id)
		(_reaction_bars[id] as ReactionBar).interactive = open and not own
		(_kudos_buttons[id] as KudosButton).gate_open = open


func _on_reaction_toggled(reaction: NetIds.Reaction, active: bool, drawing_id: String) -> void:
	if _client != null:
		_client.request_react(drawing_id, reaction, active)


func _on_kudos_requested(drawing_id: String) -> void:
	if _client != null:
		_client.request_give_kudos(drawing_id)


func _on_collection_item_added(_item_id: String) -> void:
	_toast.show_message("Saved to your collection!")


func _on_collection_save_failed() -> void:
	_toast.show_error("Couldn't save to your collection")


## Client-side rasterization through the Slice 1 renderer - deterministic
## CPU raster, cached as a texture for the rest of the round.
static func _rasterize(doc_dict: Variant) -> ImageTexture:
	var doc: DrawingDoc = DrawingDoc.from_dict(doc_dict)
	if doc == null:
		doc = DrawingDoc.new()   # renders as a blank white canvas
	return ImageTexture.create_from_image(DocRasterizer.rasterize(doc))


## Click = pick (owner feedback 2026-07-06): the pick is sent immediately
## and latched host-side; the highlight persists and the judge may re-click
## another cell to change it any time before the timer crowns the winner.
func _on_cell_pressed(drawing_id: String) -> void:
	if not _judging or _client == null:
		return
	_selected_id = drawing_id
	_client.request_pick_winner(drawing_id)
	_header_label.text = "♛ Crowned when the timer ends — click another to change"
	for id: String in _cells.keys():
		var cell: Button = _cells[id]
		cell.modulate = SELECTED_COLOR if id == drawing_id else Color.WHITE
