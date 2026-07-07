extends Control
## Persistent in-game container (Slice 3 TDD §7). Swaps one phase screen per
## EventBus.phase_changed (not full Nav navigations - cg §8), hosts the
## persistent ChatPanel whose prominence each phase screen declares, and
## hosts the SessionClient node (same node path on every peer = matching RPC
## paths).

const DRAW_SCREEN: String = "res://ui/round/draw_screen.tscn"
const JUDGE_WAIT_SCREEN: String = "res://ui/round/judge_wait_screen.tscn"
const PHASE_SCREENS: Dictionary = {
	NetIds.Phase.ROUND_INTRO: "res://ui/round/round_intro_screen.tscn",
	NetIds.Phase.REVEAL: "res://ui/round/reveal_judging_screen.tscn",
	NetIds.Phase.JUDGING: "res://ui/round/reveal_judging_screen.tscn",
	NetIds.Phase.RESOLUTION: "res://ui/round/resolution_screen.tscn",
	NetIds.Phase.WRAP_UP: "res://ui/round/standings_screen.tscn",
}

var _current_screen: Control = null

@onready var _phase_area: Control = %PhaseArea
@onready var _chat: ChatPanel = %Chat
@onready var _session_client: SessionClient = %SessionClient
@onready var _waiting_label: Label = %WaitingLabel


func _ready() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)
	_chat.message_submitted.connect(Session.submit_chat)
	_chat.prominence = ChatPanel.Prominence.NORMAL


func _on_phase_changed(phase: NetIds.Phase, data: Dictionary) -> void:
	_waiting_label.visible = false
	# REVEAL -> JUDGING keeps the same screen alive (one grid, two phases).
	if phase == NetIds.Phase.JUDGING and _current_screen != null \
			and _current_screen.has_method("enter_judging"):
		_current_screen.enter_judging(data)
		_apply_chat_prominence(_current_screen)
		return
	_swap_screen(phase, data)


func _swap_screen(phase: NetIds.Phase, data: Dictionary) -> void:
	if _current_screen != null:
		_current_screen.queue_free()
		_current_screen = null
	var path: String = _screen_path_for(phase)
	if path.is_empty():
		push_warning("RoundRoot: no screen mapped for phase %d" % phase)
		return
	var screen: Control = (load(path) as PackedScene).instantiate()
	_phase_area.add_child(screen)
	_current_screen = screen
	if screen.has_method("setup"):
		screen.setup(data, _session_client)
	_apply_chat_prominence(screen)


func _screen_path_for(phase: NetIds.Phase) -> String:
	if phase == NetIds.Phase.DRAWING:
		# Role views (§5): the judge never sees a canvas or live strokes.
		return JUDGE_WAIT_SCREEN if _session_client.is_local_player_judge() else DRAW_SCREEN
	return str(PHASE_SCREENS.get(phase, ""))


## Prominence is a property of the phase screen, never a global toggle (cg §8).
func _apply_chat_prominence(screen: Control) -> void:
	if screen != null and screen.has_method("chat_prominence"):
		_chat.prominence = screen.chat_prominence()
	else:
		_chat.prominence = ChatPanel.Prominence.NORMAL
