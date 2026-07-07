class_name ChatPanel
extends PanelContainer
## Reusable chat component with per-phase prominence + placement (Slice 2
## TDD §7; expansion/placement reworked from owner feedback 2026-07-06).
## Renders from EventBus.chat_message_received; no direct Session coupling -
## the owning screen forwards message_submitted to Session.submit_chat.
## Prominence is set by the owning phase screen, never globally (cg §8):
## COLLAPSED = starts collapsed (drawer during drawing), NORMAL = lobby,
## PROMINENT = judge heckling view / reveal riffing window.
## Expanding/collapsing is an explicit toggle button - NEVER hover (owner:
## hover-expand kept firing mid-stroke while drawing).
## Placement is set by the owning screen via RoundRoot: BOTTOM = full-width
## strip under the phase area; SIDE = vertical column to its right.

enum Prominence { COLLAPSED, NORMAL, PROMINENT }
enum Placement { BOTTOM, SIDE }

const MAX_MESSAGES: int = 100
const HISTORY_HEIGHT_NORMAL: float = 160.0
## PROMINENT height adapts to the window so the expanded chat never crowds
## the reveal grid's social rows (owner, 2026-07-06).
const PROMINENT_HEIGHT_RATIO: float = 0.22
const HISTORY_HEIGHT_MIN: float = 120.0
const HISTORY_HEIGHT_PROMINENT_MAX: float = 300.0
const PROMINENT_FONT_SIZE: int = 20
const COLLAPSED_GHOST_ALPHA: float = 0.6
const SIDE_WIDTH: float = 260.0

signal message_submitted(text: String)
## Slice 17: the header's Ready button was pressed (owning screen forwards
## to SessionClient - same decoupling as message_submitted).
signal ready_toggled(ready: bool)

@export var prominence: Prominence = Prominence.NORMAL: set = _set_prominence
@export var placement: Placement = Placement.BOTTOM: set = _set_placement

var _messages: Array[Dictionary] = []  # {"name": String, "text": String}
var _expanded: bool = true             # explicit toggle; defaulted by prominence
var _unread: int = 0                   # messages arrived while collapsed
var _ready_strip: ReadyStatusStrip = null  # Slice 17: judging ready-up (lazy)

@onready var _title: Label = %ChatTitle
@onready var _toggle_button: Button = %ToggleButton
@onready var _collapsed_strip: Label = %CollapsedStrip
@onready var _history: RichTextLabel = %History
@onready var _input_row: HBoxContainer = %InputRow
@onready var _input: LineEdit = %MessageInput
@onready var _send_button: Button = %SendButton


func _ready() -> void:
	_input.max_length = GameConstants.MAX_CHAT_LEN
	_input.text_submitted.connect(_on_text_submitted)
	_send_button.pressed.connect(_submit_current_text)
	_toggle_button.pressed.connect(_on_toggle_pressed)
	_collapsed_strip.gui_input.connect(_on_strip_gui_input)
	EventBus.chat_message_received.connect(_on_chat_message_received)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_expanded = prominence != Prominence.COLLAPSED
	_apply_layout()


func clear_history() -> void:
	_messages.clear()
	_unread = 0
	_rebuild_history()


# --- Slice 17: judging ready-up strip (header: Chat | Ready | chips) ---


## Shows (and lazily builds) the ready strip: Ready button + one chip per
## player, inline right of the "Chat" title (owner spec 2026-07-07).
func show_ready_strip(players: Array[Dictionary]) -> void:
	if _ready_strip == null:
		_ready_strip = ReadyStatusStrip.new()
		_ready_strip.setup(true, false, false)   # button, no names, horizontal
		_ready_strip.ready_toggled.connect(func(ready: bool) -> void:
			ready_toggled.emit(ready))
		var header: HBoxContainer = _title.get_parent() as HBoxContainer
		header.add_child(_ready_strip)
		header.move_child(_ready_strip, _title.get_index() + 1)
	_ready_strip.set_players(players)
	_ready_strip.set_ready_ids(PackedStringArray())
	_ready_strip.set_local_ready(false)
	_ready_strip.visible = true


func hide_ready_strip() -> void:
	if _ready_strip != null:
		_ready_strip.visible = false


func update_ready_ids(ids: PackedStringArray) -> void:
	if _ready_strip != null:
		_ready_strip.set_ready_ids(ids)


func set_ready_local(ready: bool) -> void:
	if _ready_strip != null:
		_ready_strip.set_local_ready(ready)


func set_ready_button_enabled(enabled: bool) -> void:
	if _ready_strip != null:
		_ready_strip.set_button_enabled(enabled)


func is_expanded() -> bool:
	return _expanded


func _on_chat_message_received(_sender_peer_id: int, sender_name: String, text: String) -> void:
	_messages.append({"name": sender_name, "text": text})
	while _messages.size() > MAX_MESSAGES:
		_messages.pop_front()
	if not _expanded:
		_unread += 1
	_rebuild_history()
	_refresh_collapsed_labels()


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
	if prominence != value:
		# Per-phase default; a user toggle survives same-phase re-applies
		# (e.g. pause/resume refreshes the same prominence).
		_expanded = value != Prominence.COLLAPSED
		if _expanded:
			_unread = 0
	prominence = value
	if is_node_ready():
		_apply_layout()


func _set_placement(value: Placement) -> void:
	placement = value
	if is_node_ready():
		_apply_layout()


# --- explicit expand/collapse (owner feedback 2026-07-06: never hover) ---


func _on_toggle_pressed() -> void:
	_expanded = not _expanded
	if _expanded:
		_unread = 0
	_apply_layout()


## Clicking the collapsed preview strip also expands - it's a deliberate
## click, not a hover.
func _on_strip_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _expanded:
		_on_toggle_pressed()
		_input.grab_focus()


func _on_viewport_resized() -> void:
	if prominence == Prominence.PROMINENT and _expanded:
		_apply_layout()


# --- layout ---


func _apply_layout() -> void:
	var side: bool = placement == Placement.SIDE
	_history.visible = _expanded
	_input_row.visible = _expanded
	# The preview strip only fits the wide bottom slot; the side column
	# collapses down to just the 💬 toggle.
	_collapsed_strip.visible = not _expanded and not side
	_collapsed_strip.modulate.a = COLLAPSED_GHOST_ALPHA
	_title.visible = _expanded or not side
	_toggle_button.text = _toggle_label()
	size_flags_vertical = Control.SIZE_EXPAND_FILL if side else Control.SIZE_FILL
	custom_minimum_size.x = SIDE_WIDTH if side and _expanded else 0.0
	_history.custom_minimum_size.y = _history_height()
	_refresh_collapsed_labels()
	match prominence:
		Prominence.PROMINENT:
			_history.add_theme_font_size_override("normal_font_size", PROMINENT_FONT_SIZE)
			_history.add_theme_font_size_override("bold_font_size", PROMINENT_FONT_SIZE)
			_input.add_theme_font_size_override("font_size", PROMINENT_FONT_SIZE)
			if visible and _expanded and not side:
				_input.grab_focus()  # heckling is the judge's main verb (§1)
		_:
			_history.remove_theme_font_size_override("normal_font_size")
			_history.remove_theme_font_size_override("bold_font_size")
			_input.remove_theme_font_size_override("font_size")


func _history_height() -> float:
	if placement == Placement.SIDE:
		return HISTORY_HEIGHT_MIN   # the side column stretches; this is a floor
	if prominence == Prominence.PROMINENT:
		return prominent_history_height(get_viewport_rect().size.y)
	return HISTORY_HEIGHT_NORMAL


## Static so tests pin the sizing rule without a viewport.
static func prominent_history_height(viewport_height: float) -> float:
	return clampf(viewport_height * PROMINENT_HEIGHT_RATIO,
			HISTORY_HEIGHT_MIN, HISTORY_HEIGHT_PROMINENT_MAX)


func _toggle_label() -> String:
	if _expanded:
		return "Hide"
	if placement == Placement.SIDE:
		return "💬 %d" % _unread if _unread > 0 else "💬"
	return "Show (%d)" % _unread if _unread > 0 else "Show"


func _refresh_collapsed_labels() -> void:
	_toggle_button.text = _toggle_label()
	var preview: String = _last_message_preview()
	_collapsed_strip.text = ("(%d) %s" % [_unread, preview]) if _unread > 0 else preview
