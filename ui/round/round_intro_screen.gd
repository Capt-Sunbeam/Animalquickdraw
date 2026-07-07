extends Control
## Round header card (Slice 3 TDD §7): "Round n of N", judge marked with
## icon + label, never color alone (cg §13).

@onready var _round_label: Label = %RoundLabel
@onready var _judge_label: Label = %JudgeLabel
@onready var _timer: PhaseTimer = %Timer


func setup(data: Dictionary, _client: SessionClient) -> void:
	var round_index: int = int(data.get("round_index", 0))
	var round_count: int = int(data.get("round_count", 0))
	_round_label.text = "Round %d of %d" % [round_index + 1, round_count]
	var judge_id: String = str(data.get("judge_player_id", ""))
	var judge: Roster.PlayerState = Session.roster.get_by_platform_id(judge_id)
	var judge_name: String = judge.display_name if judge != null else "???"
	_judge_label.text = "♛ %s is judging" % judge_name
	if data.has("deadline_ms"):
		_timer.start(int(data["deadline_ms"]))


func chat_prominence() -> ChatPanel.Prominence:
	return ChatPanel.Prominence.NORMAL


## Slice 6 pause: fresh deadline after a host resume.
func refresh_deadline(data: Dictionary) -> void:
	if data.has("deadline_ms"):
		_timer.start(int(data["deadline_ms"]))
