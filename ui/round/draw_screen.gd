extends Control
## Drawer view during DRAWING (Slice 3 TDD §7): prompt banner + timer +
## Slice 1 canvas with full tools + collapsed chat (§5) + early Submit.
## Early submit keeps the canvas editable; the resubmission at deadline
## replaces it (latest-wins on the host). At local countdown zero the
## screen auto-submits unconditionally and locks input (§4.4).

var _client: SessionClient = null
var _deadline_ms: int = 0
var _locked: bool = false
var _prompt_text: String = ""
var _last_submitted_doc: Dictionary = {}   # Slice 4 self-save source

@onready var _prompt_label: Label = %PromptLabel
@onready var _timer: PhaseTimer = %Timer
@onready var _canvas: DrawingCanvas = %Canvas
@onready var _submit_button: Button = %SubmitButton
@onready var _status_label: Label = %StatusLabel
@onready var _caption: CaptionInput = %Caption


func _ready() -> void:
	_submit_button.pressed.connect(_on_submit_pressed)
	# Slice 5: captions ride the submission; hidden when disabled (§10).
	# Slice 6: in-game reads use the frozen snapshot, never lobby state.
	_caption.visible = Session.game_settings.comments_enabled
	_canvas.begin_drawing()
	# Slice 4 self-save: when this screen retires (phase swap, session end),
	# the toggle saves the last SUBMITTED doc - exactly what reveal shows,
	# not unsent tweaks. Local only, never networked, never points (§6).
	tree_exiting.connect(_on_retire)


func setup(data: Dictionary, client: SessionClient) -> void:
	_client = client
	_prompt_text = str(data.get("prompt_text", ""))
	_prompt_label.text = _prompt_text
	_deadline_ms = int(data.get("deadline_ms", 0))
	if _deadline_ms > 0:
		_timer.start(_deadline_ms)


func chat_prominence() -> ChatPanel.Prominence:
	return ChatPanel.Prominence.COLLAPSED


## Slice 6 pause: fresh deadline after a host resume - same screen, canvas
## and strokes untouched.
func refresh_deadline(data: Dictionary) -> void:
	_deadline_ms = int(data.get("deadline_ms", 0))
	if _deadline_ms > 0:
		_timer.start(_deadline_ms)


func _process(_delta: float) -> void:
	if _locked or _deadline_ms <= 0:
		return
	if PhaseTimer._local_now_ms() >= _deadline_ms:
		_auto_submit()


func _on_submit_pressed() -> void:
	_send_current_doc()
	_status_label.text = "Sent! Keep tweaking until the timer ends..."


func _auto_submit() -> void:
	_locked = true
	_send_current_doc()
	_canvas.set_tools_enabled(false)
	_submit_button.disabled = true
	_status_label.text = "Time! Your drawing is in."


func _send_current_doc() -> void:
	if _client == null:
		return
	_last_submitted_doc = _canvas.get_doc().to_dict()
	var caption: String = _caption.caption_text() if _caption.visible else ""
	_client.request_submit_drawing({"doc": _last_submitted_doc, "caption": caption})


func _on_retire() -> void:
	if not _canvas.save_to_collection or _last_submitted_doc.is_empty():
		return
	CollectionStore.save_drawing(_last_submitted_doc, _prompt_text,
			UuidV4.generate(), CollectionStore.SOURCE_SELF)
