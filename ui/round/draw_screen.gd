extends Control
## Drawer view during DRAWING (Slice 3 TDD §7; Slice 17 ready-up rework):
## prompt banner + timer + ready panel (who's done) + Slice 1 canvas + a
## prominent Done! button. Done = submit current canvas + ready-up + lock;
## Unready backs out to keep drawing. The phase ends early when every
## connected drawer is ready (host-side); at local countdown zero the screen
## auto-submits unconditionally and locks input (§4.4).

var _client: SessionClient = null
var _deadline_ms: int = 0
var _locked: bool = false
var _paused: bool = false                  # host pause freezes the local deadline
var _ready_local: bool = false             # Slice 17: this drawer pressed Done
var _prompt_text: String = ""
var _last_submitted_doc: Dictionary = {}   # Slice 4 self-save source
var _ready_strip: ReadyStatusStrip = null

@onready var _prompt_label: Label = %PromptLabel
@onready var _timer: PhaseTimer = %Timer
@onready var _canvas: DrawingCanvas = %Canvas
@onready var _done_button: Button = %DoneButton
@onready var _status_label: Label = %StatusLabel
@onready var _ready_panel: VBoxContainer = %ReadyPanel


func _ready() -> void:
	_done_button.pressed.connect(_on_done_pressed)
	_canvas.begin_drawing()
	_ready_strip = ReadyStatusStrip.new()
	_ready_strip.setup(false, true, true)   # no button (Done! is it), names, vertical
	_ready_panel.add_child(_ready_strip)
	EventBus.ready_state_changed.connect(_on_ready_state_changed)
	# Slice 4 self-save: when this screen retires (phase swap, session end),
	# the toggle saves the last SUBMITTED doc - exactly what reveal shows,
	# not unsent tweaks. Local only, never networked, never points (§6).
	tree_exiting.connect(_on_retire)
	# Host pause must freeze the LOCAL deadline too, or the auto-submit
	# fires mid-pause and locks the canvas out from under the drawer
	# (owner, 2026-07-07). Resume refreshes _deadline_ms in place.
	EventBus.phase_changed.connect(func(phase: NetIds.Phase, _data: Dictionary) -> void:
		_paused = phase == NetIds.Phase.PAUSED)


func setup(data: Dictionary, client: SessionClient) -> void:
	_client = client
	_prompt_text = str(data.get("prompt_text", ""))
	_prompt_label.text = _prompt_text
	_deadline_ms = int(data.get("deadline_ms", 0))
	if _deadline_ms > 0:
		_timer.start(_deadline_ms)
	_ready_strip.set_players(_drawers_view())


## NORMAL = the side column starts expanded (owner, 2026-07-07); the 💬
## toggle still collapses it to a thin strip on demand.
func chat_prominence() -> ChatPanel.Prominence:
	return ChatPanel.Prominence.NORMAL


## Chat sits beside the canvas while drawing, never under it (owner,
## 2026-07-06) - expanding it must not cover or reflow the drawing surface.
func chat_placement() -> ChatPanel.Placement:
	return ChatPanel.Placement.SIDE


## The side chat lives INSIDE this screen's canvas row so its bottom aligns
## with the canvas, not the window - it must never run down over the Done
## button row (owner, 2026-07-07).
func chat_side_slot() -> Container:
	return %ChatSlot


## Slice 6 pause: fresh deadline after a host resume - same screen, canvas
## and strokes untouched. Ready-up cleared host-side on resume; the synced
## empty set (via ready_state_changed) unlocks this screen again.
func refresh_deadline(data: Dictionary) -> void:
	_deadline_ms = int(data.get("deadline_ms", 0))
	if _deadline_ms > 0:
		_timer.start(_deadline_ms)


func _process(_delta: float) -> void:
	if _locked or _paused or _deadline_ms <= 0:
		return
	if PhaseTimer._local_now_ms() >= _deadline_ms:
		_auto_submit()


## Done = submit what's on the canvas + ready-up + lock the tools; pressing
## again un-readies and unlocks (owner 2026-07-07: ready locks you in, with
## the button as the one escape hatch).
func _on_done_pressed() -> void:
	if _locked:
		return
	if not _ready_local:
		_send_current_doc()
		_client.request_set_ready(true)
		_set_ready_local(true)
	else:
		_client.request_set_ready(false)
		_set_ready_local(false)


func _set_ready_local(ready: bool) -> void:
	_ready_local = ready
	_canvas.set_tools_enabled(not ready)
	_done_button.text = "Unready" if ready else "Done!"
	_status_label.text = "Waiting for the others..." if ready \
			else "Sent! Keep tweaking until the timer ends..."


func _on_ready_state_changed(ready_ids: PackedStringArray) -> void:
	_ready_strip.set_ready_ids(ready_ids)
	# Host-authoritative echo: if our ready was cleared (phase resume) or
	# rejected, follow the truth on the wire.
	var me: Roster.PlayerState = Session.local_player()
	if me != null and not _locked and _ready_local != ready_ids.has(me.platform_id):
		_set_ready_local(ready_ids.has(me.platform_id))


func _auto_submit() -> void:
	_locked = true
	_send_current_doc()
	_canvas.set_tools_enabled(false)
	_done_button.disabled = true
	_status_label.text = "Time! Your drawing is in."


func _send_current_doc() -> void:
	if _client == null:
		return
	_last_submitted_doc = _canvas.get_doc().to_dict()
	_client.request_submit_drawing({"doc": _last_submitted_doc})


## Connected drawers this round (everyone but the judge) for the panel.
func _drawers_view() -> Array[Dictionary]:
	var judge: String = _client.judge_player_id() if _client != null else ""
	var out: Array[Dictionary] = []
	for p: Roster.PlayerState in Session.roster.players_in_join_order():
		if p.is_connected and p.platform_id != judge:
			out.append({"id": p.platform_id, "name": p.display_name})
	return out


func _on_retire() -> void:
	if not _canvas.save_to_collection or _last_submitted_doc.is_empty():
		return
	CollectionStore.save_drawing(_last_submitted_doc, _prompt_text,
			UuidV4.generate(), CollectionStore.SOURCE_SELF)
