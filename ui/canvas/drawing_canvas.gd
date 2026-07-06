class_name DrawingCanvas
extends VBoxContainer
## The complete, embeddable drawing surface (Slice 1 §6/§7): canvas view +
## toolbar + palette. Round screens (Slice 3) and the avatar editor
## (Slice 11) instantiate this one scene. The doc is the single source of
## truth; the raster Image is a derived cache; the GPU only displays the
## finished texture (determinism - consistency guide principle 4).
##
## Input flows: stroke/fill starts arrive via the viewport container's
## gui_input; while stroking, motion/release are tracked in _input so
## dragging off-canvas keeps drawing at the clamped edge.

signal op_committed(op_index: int)
signal op_undone(remaining_count: int)
signal doc_changed()
signal orientation_changed(orientation: StringName)
signal save_toggle_changed(enabled: bool)
signal replay_finished()

enum MaskMode { NONE, CIRCLE }  # CIRCLE implemented in Slice 11
enum InputState { IDLE, STROKING, CONFIRMING_ROTATE, REPLAYING }

@export var show_rotate: bool = true
@export var show_save_toggle: bool = true
@export var mask_mode: MaskMode = MaskMode.NONE

## Read at submission time (Slice 4 performs the actual collection write).
var save_to_collection: bool = false

var _doc: DrawingDoc = DrawingDoc.new()
var _raster: Image
var _texture: ImageTexture
var _texture_dirty: bool = false
var _current_color_index: int = Palette.DEFAULT_COLOR_INDEX
var _current_size_index: int = 1
var _current_tool: CanvasToolbar.Tool = CanvasToolbar.Tool.BRUSH
var _input_state: InputState = InputState.IDLE
var _clock_start_ms: int = 0
var _live_stroke: Stroke = null
var _tools_enabled: bool = true
var _replay: ReplayPlayer = null
var _mask: Image = null  # Slice 11 populates for MaskMode.CIRCLE

@onready var _toolbar: CanvasToolbar = %Toolbar
@onready var _palette: PalettePicker = %PalettePickerBox
@onready var _frame: AspectRatioContainer = %CanvasFrame
@onready var _viewport_box: SubViewportContainer = %ViewportBox
@onready var _viewport: SubViewport = %CanvasViewport
@onready var _raster_view: TextureRect = %RasterView
@onready var _save_toggle: CheckButton = %SaveToggle
@onready var _rotate_confirm: ConfirmDialog = %RotateConfirm


func _ready() -> void:
	_toolbar.size_selected.connect(func(idx: int) -> void: _current_size_index = idx)
	_toolbar.tool_selected.connect(func(tool: CanvasToolbar.Tool) -> void: _current_tool = tool)
	_toolbar.undo_pressed.connect(_press_undo)
	_toolbar.clear_pressed.connect(_press_clear)
	_toolbar.rotate_pressed.connect(_press_rotate)
	_toolbar.set_rotate_visible(show_rotate)
	_palette.color_selected.connect(func(idx: int) -> void: _current_color_index = idx)
	_save_toggle.visible = show_save_toggle
	_save_toggle.button_pressed = false  # off by default (brief §6)
	_save_toggle.toggled.connect(_on_save_toggled)
	_rotate_confirm.confirmed.connect(_confirm_rotate)
	_rotate_confirm.cancelled.connect(func() -> void: _input_state = InputState.IDLE)
	_viewport_box.gui_input.connect(_on_canvas_gui_input)
	_rebuild_surface()
	begin_drawing()


# --- Public API (Slice 3/11 consumers) ---


## Resets doc + clock, keeps orientation. Round screens call this when the
## drawing phase starts.
func begin_drawing() -> void:
	_commit_live_stroke()
	var kept_orientation: StringName = _doc.orientation
	_doc = DrawingDoc.new()
	_doc.orientation = kept_orientation
	_clock_start_ms = Time.get_ticks_msec()
	_full_reraster()
	_refresh_undo_state()
	doc_changed.emit()


func get_doc() -> DrawingDoc:
	_commit_live_stroke()
	return _doc


## Displays an existing doc (viewer/editor reuse).
func load_doc(doc: DrawingDoc) -> void:
	_commit_live_stroke()
	_doc = doc
	_apply_orientation_to_surface()
	_full_reraster()
	_refresh_undo_state()
	doc_changed.emit()


## Slice 3 disables at timer end.
func set_tools_enabled(enabled: bool) -> void:
	_commit_live_stroke()
	_tools_enabled = enabled
	_toolbar.set_all_enabled(enabled)
	_palette.set_enabled(enabled)
	_refresh_undo_state()


## Dev/sandbox replay through the canvas; Slice 5 drives ReplayPlayer
## directly on its own screens.
func play_replay(speed_multiplier: float) -> void:
	if _input_state != InputState.IDLE:
		return
	_commit_live_stroke()
	_input_state = InputState.REPLAYING
	_replay = ReplayPlayer.new()
	_replay.load_doc(_doc, speed_multiplier)


func is_replaying() -> bool:
	return _input_state == InputState.REPLAYING


func current_orientation() -> StringName:
	return _doc.orientation


# --- Internal: frame loop ---


func _process(_delta: float) -> void:
	if _input_state == InputState.REPLAYING:
		var still_going: bool = _replay.advance(_delta)
		_texture.update(_replay.get_image())
		if not still_going:
			_replay = null
			_input_state = InputState.IDLE
			_texture.update(_raster)
			replay_finished.emit()
		return
	if _input_state == InputState.STROKING and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Release fallback (mouse released outside the window, focus games).
		_end_stroke_at_last_point()
	if _texture_dirty:
		_texture_dirty = false
		_texture.update(_raster)


func _input(event: InputEvent) -> void:
	if _input_state != InputState.STROKING:
		return
	if event is InputEventMouseMotion:
		_stroke_extend(_display_to_internal(_viewport_box.get_local_mouse_position()))
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_stroke_end(_display_to_internal(_viewport_box.get_local_mouse_position()))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if _input_state == InputState.STROKING:
			_end_stroke_at_last_point()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_undo"):
		_press_undo()


# --- Internal: input handling ---


func _on_canvas_gui_input(event: InputEvent) -> void:
	if not _tools_enabled or _input_state != InputState.IDLE:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var pos: Vector2 = _display_to_internal(mb.position)
			if _current_tool == CanvasToolbar.Tool.BRUSH:
				_stroke_begin(pos)
			else:
				_fill_at(pos)


## Display -> internal coordinate mapping through the letterbox transform.
## The AspectRatioContainer keeps the container at the canvas aspect, so the
## map is uniform; positions clamp to the canvas rect (Slice 1 §6).
func _display_to_internal(container_local: Vector2) -> Vector2:
	var container_size: Vector2 = _viewport_box.size
	var internal: Vector2 = Vector2(_doc.canvas_size())
	var p: Vector2 = container_local
	if container_size.x > 0.0 and container_size.y > 0.0:
		p = container_local * (internal / container_size)
	return p.clamp(Vector2.ZERO, internal - Vector2(0.1, 0.1))


# --- Internal: stroke lifecycle (also the headless-test seam) ---


func _stroke_begin(internal_pos: Vector2) -> void:
	_live_stroke = Stroke.new()
	_live_stroke.color_index = _current_color_index
	_live_stroke.size_index = _current_size_index
	_append_point(internal_pos, true)
	_input_state = InputState.STROKING
	_toolbar.set_undo_enabled(false)  # toolbar disabled while stroking (§5)


func _stroke_extend(internal_pos: Vector2) -> void:
	if _live_stroke == null:
		return
	_append_point(internal_pos, false)
	if _live_stroke.points.size() >= GameConstants.STROKE_MAX_POINTS:
		# Point-flood cap: force-commit and continue in a fresh stroke.
		var resume_at: Vector2 = _live_stroke.points[_live_stroke.points.size() - 1]
		_commit_live_stroke()
		_stroke_begin(resume_at)


func _stroke_end(internal_pos: Vector2) -> void:
	if _live_stroke == null:
		return
	_append_point(internal_pos, true)  # final point always kept
	_commit_live_stroke()
	_input_state = InputState.IDLE


func _end_stroke_at_last_point() -> void:
	_commit_live_stroke()
	_input_state = InputState.IDLE


func _append_point(internal_pos: Vector2, force: bool) -> void:
	var q: Vector2 = Stroke.quantize_point(internal_pos)
	var count: int = _live_stroke.points.size()
	if count > 0:
		var last: Vector2 = _live_stroke.points[count - 1]
		if not force and q.distance_to(last) < GameConstants.STROKE_MIN_POINT_DIST_PX:
			return  # decimation
		if force and q == last:
			return  # duplicate final point adds nothing
	_live_stroke.points.append(q)
	_live_stroke.timestamps.append(Stroke.quantize_time(_clock_sec()))
	var new_count: int = _live_stroke.points.size()
	DocRasterizer.stamp_stroke_range(_raster, _live_stroke, maxi(new_count - 2, 0), new_count - 1, _mask)
	_texture_dirty = true


func _commit_live_stroke() -> void:
	if _live_stroke == null:
		return
	var stroke: Stroke = _live_stroke
	_live_stroke = null
	if stroke.points.is_empty():
		return
	_doc.ops.append(stroke)
	_refresh_undo_state()
	op_committed.emit(_doc.ops.size() - 1)
	doc_changed.emit()


func _fill_at(internal_pos: Vector2) -> void:
	var size: Vector2i = _doc.canvas_size()
	var fill := FillOp.new()
	fill.color_index = _current_color_index
	fill.x = clampi(int(internal_pos.x), 0, size.x - 1)
	fill.y = clampi(int(internal_pos.y), 0, size.y - 1)
	_doc.ops.append(fill)
	DocRasterizer.apply_op(_raster, fill, _mask)
	_texture_dirty = true
	_refresh_undo_state()
	op_committed.emit(_doc.ops.size() - 1)
	doc_changed.emit()


# --- Internal: toolbar actions ---


func _press_undo() -> void:
	if not _tools_enabled or _input_state != InputState.IDLE or _doc.ops.is_empty():
		return  # stray Ctrl+Z on empty doc / mid-stroke is a silent no-op
	_doc.ops.pop_back()
	_full_reraster()
	_refresh_undo_state()
	op_undone.emit(_doc.ops.size())
	doc_changed.emit()


func _press_clear() -> void:
	if not _tools_enabled or _input_state != InputState.IDLE:
		return
	var clear := ClearOp.new()
	_doc.ops.append(clear)
	DocRasterizer.apply_op(_raster, clear, _mask)
	_texture_dirty = true
	_refresh_undo_state()
	op_committed.emit(_doc.ops.size() - 1)
	doc_changed.emit()


func _press_rotate() -> void:
	if not _tools_enabled or _input_state != InputState.IDLE:
		return
	if _doc.ops.is_empty():
		_flip_orientation()  # nothing to lose - no dialog (§5)
		return
	_input_state = InputState.CONFIRMING_ROTATE
	_rotate_confirm.ask("Rotate canvas", "Rotating clears your drawing. Rotate anyway?", "Rotate")


func _confirm_rotate() -> void:
	_input_state = InputState.IDLE
	_flip_orientation()


func _flip_orientation() -> void:
	if _doc.orientation == DrawingDoc.ORIENTATION_LANDSCAPE:
		_doc.orientation = DrawingDoc.ORIENTATION_PORTRAIT
	else:
		_doc.orientation = DrawingDoc.ORIENTATION_LANDSCAPE
	_doc.ops.clear()
	_apply_orientation_to_surface()
	_full_reraster()
	_refresh_undo_state()
	orientation_changed.emit(_doc.orientation)
	doc_changed.emit()


func _on_save_toggled(pressed: bool) -> void:
	save_to_collection = pressed
	save_toggle_changed.emit(pressed)


# --- Internal: surface management ---


func _rebuild_surface() -> void:
	_apply_orientation_to_surface()
	_full_reraster()
	_refresh_undo_state()


func _apply_orientation_to_surface() -> void:
	var size: Vector2i = _doc.canvas_size()
	_viewport.size = size
	_frame.ratio = float(size.x) / float(size.y)


func _full_reraster() -> void:
	_raster = DocRasterizer.rasterize(_doc, _mask)
	_texture = ImageTexture.create_from_image(_raster)
	_raster_view.texture = _texture
	_texture_dirty = false


func _refresh_undo_state() -> void:
	_toolbar.set_undo_enabled(_tools_enabled and not _doc.ops.is_empty())


func _clock_sec() -> float:
	return float(Time.get_ticks_msec() - _clock_start_ms) / 1000.0
