extends Control
## Drawer view during DRAWING (Slice 3 TDD §7): prompt banner + timer +
## Slice 1 canvas with full tools + collapsed chat (§5) + early Submit.
## Early submit keeps the canvas editable; the resubmission at deadline
## replaces it (latest-wins on the host). At local countdown zero the
## screen auto-submits unconditionally and locks input (§4.4).

var _client: SessionClient = null
var _deadline_ms: int = 0
var _locked: bool = false

@onready var _prompt_label: Label = %PromptLabel
@onready var _timer: PhaseTimer = %Timer
@onready var _canvas: DrawingCanvas = %Canvas
@onready var _submit_button: Button = %SubmitButton
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_submit_button.pressed.connect(_on_submit_pressed)
	_canvas.begin_drawing()


func setup(data: Dictionary, client: SessionClient) -> void:
	_client = client
	_prompt_label.text = str(data.get("prompt_text", ""))
	_deadline_ms = int(data.get("deadline_ms", 0))
	if _deadline_ms > 0:
		_timer.start(_deadline_ms)


func chat_prominence() -> ChatPanel.Prominence:
	return ChatPanel.Prominence.COLLAPSED


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
	_client.request_submit_drawing({"doc": _canvas.get_doc().to_dict()})
