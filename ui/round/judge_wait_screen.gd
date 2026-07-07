extends Control
## Judge view during DRAWING (Slice 3 TDD §7): prompt rendered large, no
## canvas, no live strokes ever (§5), prominent chat - heckling is the
## judge's main verb (§1). The chat itself is RoundRoot's persistent panel;
## this screen only declares its PROMINENT state.

const DOT_INTERVAL_SEC: float = 0.5

var _dots: int = 0

@onready var _prompt_label: Label = %PromptLabel
@onready var _waiting_label: Label = %WaitingLabel
@onready var _timer: PhaseTimer = %Timer


func _ready() -> void:
	var dot_timer := Timer.new()
	dot_timer.wait_time = DOT_INTERVAL_SEC
	dot_timer.autostart = true
	dot_timer.timeout.connect(_animate_dots)
	add_child(dot_timer)


func setup(data: Dictionary, _client: SessionClient) -> void:
	_prompt_label.text = str(data.get("prompt_text", "")).to_upper()
	if data.has("deadline_ms"):
		_timer.start(int(data["deadline_ms"]))


func chat_prominence() -> ChatPanel.Prominence:
	return ChatPanel.Prominence.PROMINENT


func _animate_dots() -> void:
	_dots = (_dots + 1) % 4
	_waiting_label.text = "players are drawing" + ".".repeat(_dots)
