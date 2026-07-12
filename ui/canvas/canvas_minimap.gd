class_name CanvasMinimap
extends Control
## Slice 18 rework (owner, 2026-07-10): "you are here" inset shown while
## the canvas is zoomed. Renders the whole drawing plus the current view
## rectangle; click-drag OR hold-D-and-move over it centers the view at
## the pointer - trackpad-native panning with no click-dragging needed.
## Display-only: it never touches the doc, and the owning DrawingCanvas
## does all pan clamping.

signal view_center_requested(frac: Vector2)

var _texture: Texture2D = null
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _view_size: Vector2 = Vector2.ONE
var _dragging: bool = false


## The visible window as a fraction of the whole canvas (origin + size in
## 0..1 space): origin = -pan / (view * zoom), size = 1/zoom per axis.
static func view_rect_frac(zoom: float, pan: Vector2, view_size: Vector2) -> Rect2:
	if zoom <= 0.0 or view_size.x <= 0.0 or view_size.y <= 0.0:
		return Rect2(Vector2.ZERO, Vector2.ONE)
	return Rect2(-pan / (view_size * zoom), Vector2.ONE / zoom)


## The live canvas texture (re-bound after every full re-raster; content
## updates on the same texture propagate without a re-bind).
func setup(texture: Texture2D) -> void:
	_texture = texture
	queue_redraw()


func set_view(zoom: float, pan: Vector2, view_size: Vector2) -> void:
	_zoom = zoom
	_pan = pan
	_view_size = view_size
	visible = zoom > 1.001   # fit = nothing to navigate
	queue_redraw()


const FRAME_COLOR := Color(0.13, 0.13, 0.13)   # solid - a translucent frame
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.25)  # vanished into blank drawings


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	# Lift the inset off the canvas (owner 2026-07-10: it blended into a
	# blank drawing): offset shadow + solid dark frame.
	draw_rect(Rect2(Vector2(3.0, 3.0), size), SHADOW_COLOR, true)
	draw_rect(full, Color(0.0, 0.0, 0.0, 0.4), true)
	if _texture != null:
		draw_texture_rect(_texture, full, false)
	# Two-tone view rectangle: dark under white, readable on any drawing.
	var frac: Rect2 = view_rect_frac(_zoom, _pan, _view_size)
	var view_rect := Rect2(frac.position * size, frac.size * size)
	draw_rect(view_rect, Color(1.0, 1.0, 1.0, 0.2), true)
	draw_rect(view_rect, FRAME_COLOR, false, 4.0)
	draw_rect(view_rect, Color.WHITE, false, 2.0)
	draw_rect(full.grow(1.0), FRAME_COLOR, false, 3.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				_request_center(mb.position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_request_center((event as InputEventMouseMotion).position)
		accept_event()


func _process(_delta: float) -> void:
	if not visible:
		return
	if _dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dragging = false   # release outside the inset
	# Hold-D panning: the pointer over the inset with draw_hold held drives
	# the view directly (the owning canvas excludes this rect from inking).
	if Input.is_action_pressed("draw_hold") \
			and get_global_rect().has_point(get_global_mouse_position()):
		_request_center(get_local_mouse_position())


func _request_center(local: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	view_center_requested.emit((local / size).clamp(Vector2.ZERO, Vector2.ONE))
