extends Control
## The avatar editor (Slice 11 §7): the exact same drawing tools as the game
## canvas on a circular 512x512 surface - zero new tool code. Save writes
## user://avatar.json (via AvatarStore); Clear-avatar deletes it; Back
## prompts when the doc differs from the last save. Rotate and
## save-to-collection are hidden (fixed orientation; collection saving is a
## round concept).

const COMPLEXITY_WARN_FRACTION: float = 0.8

var _saved_dict: Dictionary = {}      # last-saved doc dict; {} = no file
var _complexity_warned: bool = false

@onready var _canvas: DrawingCanvas = %Canvas
@onready var _save_button: Button = %SaveButton
@onready var _clear_button: Button = %ClearButton
@onready var _back_button: Button = %BackButton
@onready var _clear_confirm: ConfirmDialog = %ClearConfirm
@onready var _back_confirm: ConfirmDialog = %BackConfirm
@onready var _toast: Toast = %Toast


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_clear_button.pressed.connect(func() -> void:
		_clear_confirm.ask("Remove avatar",
				"Remove your avatar? You'll show as your name instead.", "Remove"))
	_clear_confirm.confirmed.connect(_on_clear_confirmed)
	_back_confirm.confirmed.connect(func() -> void: Nav.goto(Routes.MENU))
	_canvas.doc_changed.connect(_on_doc_changed)
	var existing: DrawingDoc = AvatarStore.load_doc()
	if existing != null:
		# Edit on top of the current avatar; ops append after the loaded ones.
		_canvas.load_doc(existing)
		_saved_dict = existing.to_dict()
	_refresh_save_state()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _on_doc_changed() -> void:
	_refresh_save_state()
	var ops: int = _canvas.get_doc().ops.size()
	if not _complexity_warned \
			and ops >= int(GameConstants.AVATAR_MAX_OPS * COMPLEXITY_WARN_FRACTION):
		_complexity_warned = true
		_toast.show_message("Your avatar is getting complex - consider simplifying.")


func _refresh_save_state() -> void:
	_save_button.disabled = _canvas.get_doc().ops.is_empty()


func _is_dirty() -> bool:
	var current: Dictionary = _canvas.get_doc().to_dict()
	if _saved_dict.is_empty():
		return not _canvas.get_doc().ops.is_empty()   # unsaved strokes on a fresh circle
	return current != _saved_dict


func _on_back_pressed() -> void:
	if _is_dirty():
		_back_confirm.ask("Unsaved changes",
				"Leave without saving your avatar changes?", "Leave")
		return
	Nav.goto(Routes.MENU)


func _on_save_pressed() -> void:
	var doc: DrawingDoc = _canvas.get_doc()
	if doc.ops.is_empty():
		return   # button is disabled anyway; belt-and-braces
	if AvatarStore.save_doc(doc) == OK:
		_saved_dict = doc.to_dict()
		EventBus.local_avatar_changed.emit()
		_toast.show_message("Avatar saved")
	else:
		_toast.show_error("Couldn't save your avatar.")


func _on_clear_confirmed() -> void:
	AvatarStore.clear()
	_saved_dict = {}
	_complexity_warned = false
	_canvas.begin_drawing()   # fresh circle
	EventBus.local_avatar_changed.emit()
	_toast.show_message("Avatar removed")
