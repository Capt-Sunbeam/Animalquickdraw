class_name ChatPanel
extends PanelContainer
## Reusable chat component with per-phase prominence (Slice 2 TDD §7).
## Renders from EventBus.chat_message_received; no direct Session coupling -
## the owning screen forwards message_submitted to Session.submit_chat.
## Prominence is set by the owning phase screen, never globally (cg §8):
## COLLAPSED = thin strip (drawer during drawing, Slice 3), NORMAL = lobby,
## PROMINENT = judge heckling view (Slice 3).

enum Prominence { COLLAPSED, NORMAL, PROMINENT }

const MAX_MESSAGES: int = 100
const HISTORY_HEIGHT_NORMAL: float = 160.0
const HISTORY_HEIGHT_PROMINENT: float = 300.0
const PROMINENT_FONT_SIZE: int = 20
const COLLAPSED_GHOST_ALPHA: float = 0.6

signal message_submitted(text: String)

@export var prominence: Prominence = Prominence.NORMAL: set = _set_prominence

var _messages: Array[Dictionary] = []  # {"name": String, "text": String}
var _collapsed_expanded: bool = false  # hover/click expansion while COLLAPSED

@onready var _collapsed_strip: Label = %CollapsedStrip
@onready var _history: RichTextLabel = %History
@onready var _input_row: HBoxContainer = %InputRow
@onready var _input: LineEdit = %MessageInput
@onready var _send_button: Button = %SendButton


func _ready() -> void:
	_input.max_length = GameConstants.MAX_CHAT_LEN
	_input.text_submitted.connect(_on_text_submitted)
	_send_button.pressed.connect(_submit_current_text)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_collapsed_strip.gui_input.connect(_on_strip_gui_input)
	EventBus.chat_message_received.connect(_on_chat_message_received)
	_apply_prominence()


func clear_history() -> void:
	_messages.clear()
	_rebuild_history()


func _on_chat_message_received(_sender_peer_id: int, sender_name: String, text: String) -> void:
	_messages.append({"name": sender_name, "text": text})
	while _messages.size() > MAX_MESSAGES:
		_messages.pop_front()
	_rebuild_history()


## Rebuild via the push_* API - user text is never parsed as BBCode.
func _rebuild_history() -> void:
	_history.clear()
	for i: int in range(_messages.size()):
		var msg: Dictionary = _messages[i]
		if i > 0:
			_history.newline()
		_history.push_bold()
		_history.add_text("%s: " % str(msg["name"]))
		_history.pop()
		_history.add_text(str(msg["text"]))
	_collapsed_strip.text = _last_message_preview()


func _last_message_preview() -> String:
	if _messages.is_empty():
		return "Chat"
	var last: Dictionary = _messages[-1]
	return "%s: %s" % [str(last["name"]), str(last["text"])]


func _on_text_submitted(_text: String) -> void:
	_submit_current_text()


func _submit_current_text() -> void:
	var text: String = _input.text.strip_edges()
	_input.clear()
	if text.is_empty():
		return
	message_submitted.emit(text)
	_input.grab_focus()


func _set_prominence(value: Prominence) -> void:
	prominence = value
	_collapsed_expanded = false
	if is_node_ready():
		_apply_prominence()


func _apply_prominence() -> void:
	var show_full: bool = prominence != Prominence.COLLAPSED or _collapsed_expanded
	_collapsed_strip.visible = not show_full
	_collapsed_strip.modulate.a = COLLAPSED_GHOST_ALPHA
	_history.visible = show_full
	_input_row.visible = show_full
	match prominence:
		Prominence.PROMINENT:
			_history.custom_minimum_size.y = HISTORY_HEIGHT_PROMINENT
			_history.add_theme_font_size_override("normal_font_size", PROMINENT_FONT_SIZE)
			_history.add_theme_font_size_override("bold_font_size", PROMINENT_FONT_SIZE)
			_input.add_theme_font_size_override("font_size", PROMINENT_FONT_SIZE)
			if visible:
				_input.grab_focus()  # heckling is the judge's main verb (§1)
		_:
			_history.custom_minimum_size.y = HISTORY_HEIGHT_NORMAL
			_history.remove_theme_font_size_override("normal_font_size")
			_history.remove_theme_font_size_override("bold_font_size")
			_input.remove_theme_font_size_override("font_size")


# --- COLLAPSED-mode hover/click expansion (Slice 2 TDD §7) ---


func _on_mouse_entered() -> void:
	if prominence == Prominence.COLLAPSED and not _collapsed_expanded:
		_collapsed_expanded = true
		_apply_prominence()


func _on_mouse_exited() -> void:
	if prominence == Prominence.COLLAPSED and _collapsed_expanded and not _input.has_focus():
		_collapsed_expanded = false
		_apply_prominence()


func _on_strip_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_collapsed_expanded = true
		_apply_prominence()
		_input.grab_focus()
