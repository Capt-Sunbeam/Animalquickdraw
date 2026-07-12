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
enum InputState { IDLE, STROKING, CONFIRMING_ROTATE, REPLAYING, PANNING }

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
# Slice 16 text tool (drag-to-place rework, owner 2026-07-07): type in the
# TextRow, a rendered chip appears, drag it onto the canvas; the drop point
# commits a TextOp (centered on the cursor). Chip and drag preview are both
# blitted by the same DocRasterizer path that commits, and the text is
# censored live - what you hold is exactly what lands. ONE preview only:
# the cursor-following drag preview (owner, 2026-07-07 - a second on-canvas
# hover copy read as a duplicate).
var _chip_texture: ImageTexture = null
var _eraser_cursor: EraserCursor = null   # display-only erase footprint
# Slice 18 view state (display-only; the doc and every internal coordinate
# are untouched - determinism is not in play).
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO          # RasterView position; <= 0 per axis
var _stroke_from_key: bool = false        # live stroke started by draw_hold
var _pan_grab_mouse: Vector2 = Vector2.ZERO
var _minimap: CanvasMinimap = null        # "you are here" inset while zoomed

@onready var _toolbar: CanvasToolbar = %Toolbar
@onready var _palette: PalettePicker = %PalettePickerBox
@onready var _frame: AspectRatioContainer = %CanvasFrame
@onready var _viewport_box: SubViewportContainer = %ViewportBox
@onready var _viewport: SubViewport = %CanvasViewport
@onready var _raster_view: TextureRect = %RasterView
@onready var _save_toggle: CheckButton = %SaveToggle
@onready var _rotate_confirm: ConfirmDialog = %RotateConfirm
@onready var _text_row: HBoxContainer = %TextRow
@onready var _text_input: LineEdit = %TextInput
@onready var _text_chip: TextureRect = %TextChip


func _ready() -> void:
	_toolbar.size_selected.connect(func(idx: int) -> void:
		_current_size_index = idx
		_refresh_text_chip())
	_toolbar.tool_selected.connect(func(tool: CanvasToolbar.Tool) -> void: _current_tool = tool)
	_toolbar.undo_pressed.connect(_press_undo)
	_toolbar.clear_pressed.connect(_press_clear)
	_toolbar.rotate_pressed.connect(_press_rotate)
	_toolbar.set_rotate_visible(show_rotate)
	_palette.color_selected.connect(func(idx: int) -> void:
		_current_color_index = idx
		_refresh_text_chip())
	_save_toggle.visible = show_save_toggle
	_save_toggle.button_pressed = false  # off by default (brief §6)
	_save_toggle.toggled.connect(_on_save_toggled)
	_rotate_confirm.confirmed.connect(_confirm_rotate)
	_rotate_confirm.cancelled.connect(func() -> void: _input_state = InputState.IDLE)
	_viewport_box.gui_input.connect(_on_canvas_gui_input)
	_viewport_box.resized.connect(_apply_zoom_layout)
	_toolbar.zoom_in_pressed.connect(func() -> void: _step_zoom(1))
	_toolbar.zoom_out_pressed.connect(func() -> void: _step_zoom(-1))
	_toolbar.zoom_reset_pressed.connect(_reset_view)
	_text_input.max_length = GameConstants.TEXT_MAX_CHARS
	_text_input.text_changed.connect(func(_t: String) -> void: _refresh_text_chip())
	# Drag & drop via scripted virtuals on the chip/viewport-box nodes
	# (runtime set_drag_forwarding with partial callables proved unreliable
	# in the 2026-07-07 playtest - drops never registered).
	(_text_chip as TextChipDrag).canvas = self
	(_viewport_box as CanvasDropTarget).canvas = self
	_eraser_cursor = EraserCursor.new()
	_eraser_cursor.set_anchors_preset(Control.PRESET_FULL_RECT)
	_eraser_cursor.visible = false
	_viewport_box.add_child(_eraser_cursor)
	# Slice 18 rework: zoom navigation inset (namespaced node name - the
	# recursive-find_child lesson).
	_minimap = CanvasMinimap.new()
	_minimap.name = "CanvasMinimapInset"
	_minimap.visible = false
	_minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport_box.add_child(_minimap)
	_minimap.view_center_requested.connect(_center_view_on_fraction)
	# Slice 11: circular mode activates the Slice 1 mask hook - the doc IS an
	# avatar doc (fixed 512x512 orientation) and every raster path masks.
	if mask_mode == MaskMode.CIRCLE:
		_doc.orientation = DrawingDoc.ORIENTATION_AVATAR
		_mask = CircleMask.image()
	_rebuild_surface()
	_refresh_text_chip()
	begin_drawing()


# --- Public API (Slice 3/11 consumers) ---


## Resets doc + clock, keeps orientation. Round screens call this when the
## drawing phase starts.
func begin_drawing() -> void:
	if _text_input != null:
		_text_input.clear()   # stale text never carries into a fresh drawing
		_refresh_text_chip()
	_commit_live_stroke()
	var kept_orientation: StringName = _doc.orientation
	_doc = DrawingDoc.new()
	_doc.orientation = kept_orientation
	_clock_start_ms = Time.get_ticks_msec()
	_reset_view()
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
	_reset_view()
	_full_reraster()
	_refresh_undo_state()
	doc_changed.emit()


## Slice 3 disables at timer end.
func set_tools_enabled(enabled: bool) -> void:
	_commit_live_stroke()
	_tools_enabled = enabled
	_toolbar.set_all_enabled(enabled)
	_palette.set_enabled(enabled)
	_text_input.editable = enabled
	_refresh_text_chip()   # chip hides while tools are locked
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
	if _input_state == InputState.STROKING:
		# Release fallback (released outside the window, focus games) - checks
		# the source that started the stroke (Slice 18: draw_hold strokes).
		var still_held: bool = Input.is_action_pressed("draw_hold") if _stroke_from_key \
				else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if not still_held:
			_end_stroke_at_last_point()
	if _input_state == InputState.PANNING and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_input_state = InputState.IDLE
	if _texture_dirty:
		_texture_dirty = false
		_texture.update(_raster)
	_update_eraser_cursor()


func _input(event: InputEvent) -> void:
	# Trackpad gestures are handled here, NOT in gui_input - their delivery
	# to Controls varies by platform (the owner's two-finger pan never
	# arrived through gui_input on macOS). Hit-test the canvas ourselves.
	if event is InputEventMagnifyGesture or event is InputEventPanGesture:
		if _gesture_over_canvas():
			if event is InputEventMagnifyGesture:
				var mg: InputEventMagnifyGesture = event
				_set_zoom(_zoom * mg.factor, _viewport_box.get_local_mouse_position())
			else:
				var pg: InputEventPanGesture = event
				_move_pan(-pg.delta * GameConstants.CANVAS_GESTURE_PAN_FACTOR)
			get_viewport().set_input_as_handled()
		return
	if _input_state == InputState.PANNING:
		if event is InputEventMouseMotion:
			var cur: Vector2 = _viewport_box.get_local_mouse_position()
			_move_pan(cur - _pan_grab_mouse)
			_pan_grab_mouse = cur
		elif event is InputEventMouseButton:
			var pan_mb: InputEventMouseButton = event
			if pan_mb.button_index == MOUSE_BUTTON_MIDDLE and not pan_mb.pressed:
				_input_state = InputState.IDLE
		return
	if _input_state != InputState.STROKING:
		return
	if event is InputEventMouseMotion:
		_stroke_extend(_display_to_internal(_viewport_box.get_local_mouse_position()))
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and not _stroke_from_key:
			# A draw_hold stroke ignores mouse releases (source rule, Slice 18).
			_stroke_end(_display_to_internal(_viewport_box.get_local_mouse_position()))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if _input_state == InputState.STROKING:
			_end_stroke_at_last_point()
		if _input_state == InputState.PANNING:
			_input_state = InputState.IDLE


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_undo"):
		_press_undo()
	elif event.is_action_pressed("draw_hold") and not event.is_echo():
		_begin_key_draw()
	elif event.is_action_released("draw_hold") \
			and _input_state == InputState.STROKING and _stroke_from_key:
		_stroke_end(_display_to_internal(_viewport_box.get_local_mouse_position()))


# --- Internal: input handling ---


func _on_canvas_gui_input(event: InputEvent) -> void:
	if not _tools_enabled or _input_state != InputState.IDLE:
		return
	if _handle_view_input(event):
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var pos: Vector2 = _display_to_internal(mb.position)
			if _current_tool == CanvasToolbar.Tool.FILL:
				_fill_at(pos)
			else:
				_stroke_from_key = false
				_stroke_begin(pos)   # BRUSH and ERASER both stroke (§6)


## Display -> internal coordinate mapping through the letterbox transform
## and the Slice 18 zoom/pan view transform. The AspectRatioContainer keeps
## the container at the canvas aspect, so the map is uniform; positions
## clamp to the canvas rect (Slice 1 §6).
func _display_to_internal(container_local: Vector2) -> Vector2:
	return map_display_to_internal(container_local, _viewport_box.size,
			Vector2(_doc.canvas_size()), _zoom, _pan)


# --- Slice 18: display zoom/pan. View-only - the doc, raster, and every
# --- internal coordinate are untouched. Pure math is static for headless
# --- tests; the zoom is applied by resizing the RasterView INSIDE the
# --- SubViewport, so the render target never grows with zoom.


static func clamp_zoom(zoom: float) -> float:
	return clampf(zoom, 1.0, GameConstants.CANVAS_ZOOM_MAX)


## Pan is the RasterView position within the view: at zoom z the view shows
## a 1/z window of the canvas, so valid pan is [view * (1 - z), 0] per
## axis - collapsing to (0,0) at fit (panning is impossible unzoomed).
static func clamp_pan(pan: Vector2, view_size: Vector2, zoom: float) -> Vector2:
	var min_pan: Vector2 = view_size * (1.0 - zoom)
	return Vector2(clampf(pan.x, min_pan.x, 0.0), clampf(pan.y, min_pan.y, 0.0))


## New pan keeping the canvas point under `cursor` (display coords) fixed
## across a zoom change. Unclamped - the layout pass clamps.
static func pan_after_zoom(cursor: Vector2, pan: Vector2, old_zoom: float, new_zoom: float) -> Vector2:
	if old_zoom <= 0.0:
		return pan
	return cursor - (cursor - pan) * (new_zoom / old_zoom)


## THE display->internal map - every input path funnels through here. At
## zoom 1 / pan 0 this is exactly the Slice 1 letterbox map (pinned).
static func map_display_to_internal(container_local: Vector2, container_size: Vector2,
		internal: Vector2, zoom: float, pan: Vector2) -> Vector2:
	var p: Vector2 = container_local
	if container_size.x > 0.0 and container_size.y > 0.0 and zoom > 0.0:
		p = ((container_local - pan) / zoom) * (internal / container_size)
	return p.clamp(Vector2.ZERO, internal - Vector2(0.1, 0.1))


func _apply_zoom_layout() -> void:
	if _raster_view == null or _viewport_box == null:
		return
	_pan = clamp_pan(_pan, _viewport_box.size, _zoom)
	_raster_view.position = _pan
	_raster_view.size = _viewport_box.size * _zoom
	_toolbar.set_zoom_display(_zoom)
	_layout_minimap()


func _set_zoom(new_zoom: float, anchor_display: Vector2) -> void:
	var clamped: float = clamp_zoom(new_zoom)
	if is_equal_approx(clamped, _zoom):
		return
	_pan = pan_after_zoom(anchor_display, _pan, _zoom, clamped)
	_zoom = clamped
	_apply_zoom_layout()


## Toolbar +/-: next/previous rung on the CANVAS_ZOOM_STEPS ladder,
## anchored at the view center.
func _step_zoom(direction: int) -> void:
	var steps: PackedFloat32Array = GameConstants.CANVAS_ZOOM_STEPS
	var target: float = _zoom
	if direction > 0:
		for i: int in steps.size():
			if steps[i] > _zoom * 1.001:
				target = steps[i]
				break
	else:
		for i: int in range(steps.size() - 1, -1, -1):
			if steps[i] < _zoom * 0.999:
				target = steps[i]
				break
	_set_zoom(target, _viewport_box.size / 2.0)


func _reset_view() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	_apply_zoom_layout()


func _move_pan(delta_display: Vector2) -> void:
	_pan += delta_display
	_apply_zoom_layout()


## Wheel/middle-drag view input over the canvas (IDLE only - a mid-stroke
## zoom would bend the mapping under a live stroke). Trackpad gestures are
## handled in _input (delivery to gui_input is platform-flaky). Returns
## true when consumed. Wheel events carry `factor` for precise trackpad
## scrolling (0 on plain wheels) - scale by it so trackpads glide and
## wheels step.
func _handle_view_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if not mb.pressed:
			return false
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				var up: bool = mb.button_index == MOUSE_BUTTON_WHEEL_UP
				var notch: float = mb.factor if mb.factor > 0.0 else 1.0
				if mb.ctrl_pressed or mb.meta_pressed:
					var step: float = pow(GameConstants.CANVAS_WHEEL_ZOOM_FACTOR, notch)
					_set_zoom(_zoom * (step if up else 1.0 / step), mb.position)
				elif mb.shift_pressed:
					var dx: float = GameConstants.CANVAS_WHEEL_PAN_PX * notch
					_move_pan(Vector2(dx if up else -dx, 0.0))
				else:
					var dy: float = GameConstants.CANVAS_WHEEL_PAN_PX * notch
					_move_pan(Vector2(0.0, dy if up else -dy))
				return true
			MOUSE_BUTTON_MIDDLE:
				_input_state = InputState.PANNING
				_pan_grab_mouse = _viewport_box.get_local_mouse_position()
				return true
	return false


func _gesture_over_canvas() -> bool:
	return _tools_enabled and _input_state == InputState.IDLE \
			and is_visible_in_tree() \
			and _viewport_box.get_global_rect().has_point(_viewport_box.get_global_mouse_position())


## Minimap request: put the canvas point at fraction `frac` (0..1 of the
## whole drawing) at the view center. Clamped by the layout pass.
func _center_view_on_fraction(frac: Vector2) -> void:
	_pan = _viewport_box.size * 0.5 - frac * _viewport_box.size * _zoom
	_apply_zoom_layout()


func _layout_minimap() -> void:
	if _minimap == null:
		return
	var view: Vector2 = _viewport_box.size
	var internal: Vector2 = Vector2(_doc.canvas_size())
	var w: float = view.x * GameConstants.CANVAS_MINIMAP_WIDTH_FRAC
	var h: float = w * (internal.y / maxf(internal.x, 1.0))
	_minimap.size = Vector2(w, h)
	_minimap.position = view - _minimap.size - Vector2(8.0, 8.0)
	_minimap.set_view(_zoom, _pan, view)


## Hold-to-draw + key-click (Slice 18; rework 2026-07-10): while
## `draw_hold` (default D) is held over the canvas, the pointer is the
## pen; over the minimap, the minimap pans; anywhere else, a D press is a
## synthesized left-click at the pointer (toolbar/palette/toggles/chat
## focus - one rule, no per-widget wiring). Focused text fields consume
## the key before _unhandled_key_input, so typing "d" can never ink OR
## click.
func _begin_key_draw() -> void:
	if not is_visible_in_tree():
		return
	if _minimap != null and _minimap.visible \
			and _minimap.get_global_rect().has_point(get_global_mouse_position()):
		return   # the minimap's hold-D pan owns this pointer
	if _pointer_over_canvas(get_viewport().gui_get_hovered_control()):
		if not _tools_enabled or _input_state != InputState.IDLE:
			return
		var pos: Vector2 = _display_to_internal(_viewport_box.get_local_mouse_position())
		if _current_tool == CanvasToolbar.Tool.FILL:
			_fill_at(pos)
		else:
			_stroke_from_key = true
			_stroke_begin(pos)
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return   # a real press is in flight - don't double-click
	_key_click_at(get_viewport().get_mouse_position())


## The canvas-rect test alone lies when another control floats OVER the
## canvas - the expanded palette overlay does exactly that (owner D-click
## find, 2026-07-12): the pointer sits inside the canvas rect but the
## overlay swatch should win the click. Cross-check the ACTUAL hovered
## control.
func _pointer_over_canvas(hovered: Control) -> bool:
	if not _viewport_box.get_global_rect().has_point(_viewport_box.get_global_mouse_position()):
		return false
	return _hover_allows_canvas(hovered)


## A null hover (headless / no motion yet) trusts the rect, preserving the
## pre-fix behavior everywhere nothing floats on top.
func _hover_allows_canvas(hovered: Control) -> bool:
	if hovered == null:
		return true
	return hovered == _viewport_box or _viewport_box.is_ancestor_of(hovered)


## Synthesized full press+release pair (no held-button state to get
## stuck), pushed viewport-locally so the window stretch transform never
## touches the coordinates.
func _key_click_at(canvas_pos: Vector2) -> void:
	for is_press: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = is_press
		ev.position = canvas_pos
		ev.global_position = canvas_pos
		get_viewport().push_input(ev, true)


# --- Internal: stroke lifecycle (also the headless-test seam) ---


func _stroke_begin(internal_pos: Vector2) -> void:
	_live_stroke = Stroke.new()
	# Eraser = a stroke in the canvas-background color (Slice 16): fully
	# deterministic, replays visibly, and the palette selection is untouched.
	_live_stroke.color_index = Palette.ERASE_COLOR_INDEX \
			if _current_tool == CanvasToolbar.Tool.ERASER else _current_color_index
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
	if _mask != null:
		# Circular mode (Slice 11): pointer positions outside the circle clamp
		# to the nearest in-circle point while stroking.
		internal_pos = CircleMask.clamp_to_circle(internal_pos)
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
	if _mask != null and not CircleMask.contains(internal_pos):
		return   # circular mode: fill clicks outside the circle are ignored (§6)
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


# --- Internal: text tool, drag-to-place (Slice 16 rework, owner
# 2026-07-07; _commit_text_at is also the headless-test seam) ---


## The committal string: charset-filtered, censored, re-truncated - the
## exact sequence the host applies (Slice 16 §6), so the local doc equals
## the broadcast doc (own-drawing detection depends on this).
func _sanitized_text() -> String:
	var raw: String = _text_input.text
	var clean: String = ""
	for i: int in raw.length():
		if PixelFont.is_supported(raw.unicode_at(i)):
			clean += raw[i]
	return TextFilter.censor(clean).left(GameConstants.TEXT_MAX_CHARS)


## Renders the committal text through the committal blitter, at internal
## resolution, on transparency - the chip/drag/hover previews are all this.
func _render_text_image(text: String) -> Image:
	var scale: int = GameConstants.TEXT_SCALES[_current_size_index]
	var w: int = maxi(1, text.length() * GameConstants.TEXT_GLYPH_PX * scale)
	var h: int = GameConstants.TEXT_GLYPH_PX * scale
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var op := TextOp.new()
	op.color_index = _current_color_index
	op.size_index = _current_size_index
	op.x = 0
	op.y = 0
	op.text = text
	DocRasterizer.apply_op(img, op)
	return img


func _refresh_text_chip() -> void:
	if _text_chip == null:
		return
	var text: String = _sanitized_text()
	if text.is_empty() or not _tools_enabled:
		_text_chip.visible = false
		return
	var img: Image = _render_text_image(text)
	_chip_texture = ImageTexture.create_from_image(img)
	_text_chip.texture = _chip_texture
	var chip_h: float = 28.0
	var chip_w: float = minf(img.get_width() * (chip_h / float(img.get_height())), 320.0)
	_text_chip.custom_minimum_size = Vector2(chip_w, chip_h)
	_text_chip.visible = true


## Drag source (chip). The preview matches the on-canvas display scale so
## what you're holding is what will land.
func _chip_get_drag_data(_at_position: Vector2) -> Variant:
	var text: String = _sanitized_text()
	if text.is_empty() or not _tools_enabled or _input_state != InputState.IDLE:
		return null
	var img: Image = _render_text_image(text)
	var preview := TextureRect.new()
	preview.texture = ImageTexture.create_from_image(img)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var display_scale: float = 1.0
	var internal: Vector2 = Vector2(_doc.canvas_size())
	if internal.x > 0.0 and _viewport_box.size.x > 0.0:
		display_scale = _viewport_box.size.x * _zoom / internal.x
	preview.size = Vector2(img.get_width(), img.get_height()) * display_scale
	# Hold the text by its center - matches the drop anchoring. The preview
	# must be mouse-transparent or it hides the drop target under the cursor.
	preview.position = -preview.size / 2.0
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(preview)
	_text_chip.set_drag_preview(wrapper)
	return {"aq_text_drop": true}


## Drop target (canvas). Fires continuously during the drag (drives the
## can-drop cursor); the cursor-following drag preview is the sole visual.
func _can_drop_text(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and (data as Dictionary).has("aq_text_drop")):
		return false
	if not _tools_enabled or _input_state != InputState.IDLE:
		return false
	return not _sanitized_text().is_empty()


func _drop_text(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_text(at_position, data):
		return
	_commit_text_at(_drop_anchor(at_position, _sanitized_text()))


## Anchor so the text centers on the cursor, clamped in-canvas (the wire
## format requires an in-canvas anchor; overflow clips at raster time).
func _drop_anchor(display_pos: Vector2, text: String) -> Vector2i:
	return _anchor_for_internal(_display_to_internal(display_pos), text)


## Pure centering math on internal coordinates (headless-test seam - the
## display mapping needs a laid-out viewport box).
func _anchor_for_internal(internal: Vector2, text: String) -> Vector2i:
	var scale: int = GameConstants.TEXT_SCALES[_current_size_index]
	var w: float = float(text.length() * GameConstants.TEXT_GLYPH_PX * scale)
	var h: float = float(GameConstants.TEXT_GLYPH_PX * scale)
	var size: Vector2i = _doc.canvas_size()
	return Vector2i(clampi(roundi(internal.x - w / 2.0), 0, size.x - 1),
			clampi(roundi(internal.y - h / 2.0), 0, size.y - 1))


## Commits the TextRow's current text at anchor - the fill-op lifecycle
## exactly. No-op for empty/unsupported-only text.
func _commit_text_at(anchor: Vector2i) -> void:
	var text: String = _sanitized_text()
	if text.is_empty():
		return
	var op := TextOp.new()
	op.color_index = _current_color_index
	op.size_index = _current_size_index
	op.x = anchor.x
	op.y = anchor.y
	op.text = text
	_doc.ops.append(op)
	DocRasterizer.apply_op(_raster, op, _mask)
	_texture_dirty = true
	_refresh_undo_state()
	op_committed.emit(_doc.ops.size() - 1)
	doc_changed.emit()
	# Text stays in the box for repeat stamps ("HA HA HA"); the input's
	# clear button resets it.


## Eraser footprint circle at the mouse (owner request 2026-07-07): shown
## whenever the eraser is the active tool, sized to the brush radius at the
## current display scale. Display-only overlay - the raster never sees it.
func _update_eraser_cursor() -> void:
	if _eraser_cursor == null:
		return
	var active: bool = _tools_enabled \
			and _current_tool == CanvasToolbar.Tool.ERASER \
			and (_input_state == InputState.IDLE or _input_state == InputState.STROKING)
	_eraser_cursor.visible = active
	if not active:
		return
	var internal: Vector2 = Vector2(_doc.canvas_size())
	var display_scale: float = 1.0
	if internal.x > 0.0 and _viewport_box.size.x > 0.0:
		display_scale = _viewport_box.size.x * _zoom / internal.x
	_eraser_cursor.radius_px = float(GameConstants.BRUSH_RADII_PX[_current_size_index]) \
			* display_scale
	_eraser_cursor.queue_redraw()


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
	if mask_mode == MaskMode.CIRCLE:
		return   # avatar orientation is fixed (button hidden; belt-and-braces)
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
	_reset_view()
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
	if _mask != null:
		# Display clip (Slice 11): transparent corners so the square reads as
		# a circle. Masked ops never write outside, so incremental stamping
		# keeps the alpha intact until the next full re-raster.
		CircleMask.apply_display_alpha(_raster)
	_texture = ImageTexture.create_from_image(_raster)
	_raster_view.texture = _texture
	_texture_dirty = false
	if _minimap != null:
		_minimap.setup(_texture)


func _refresh_undo_state() -> void:
	_toolbar.set_undo_enabled(_tools_enabled and not _doc.ops.is_empty())


func _clock_sec() -> float:
	return float(Time.get_ticks_msec() - _clock_start_ms) / 1000.0
