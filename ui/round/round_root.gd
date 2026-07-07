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
var _current_phase: NetIds.Phase = NetIds.Phase.LOBBY

@onready var _body: HBoxContainer = %Body
@onready var _main: VBoxContainer = %Main
@onready var _phase_area: Control = %PhaseArea
@onready var _chat: ChatPanel = %Chat
@onready var _session_client: SessionClient = %SessionClient
@onready var _waiting_label: Label = %WaitingLabel
@onready var _menu: GameMenu = %Menu


func _ready() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)
	_chat.message_submitted.connect(Session.submit_chat)
	_chat.prominence = ChatPanel.Prominence.NORMAL
	_menu.setup(_session_client)


## Slice 6: Esc toggles the in-game menu (forced open while paused).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_menu.toggle()
		get_viewport().set_input_as_handled()


func _on_phase_changed(phase: NetIds.Phase, data: Dictionary) -> void:
	_waiting_label.visible = false
	# Slice 6 pause: keep the live screen (canvas strokes, staged reveals)
	# under the overlay; nothing is rebuilt.
	if phase == NetIds.Phase.PAUSED:
		_menu.show_paused()
		return
	_menu.hide_paused()
	# Resume re-enters the SAME phase with a fresh deadline: refresh in
	# place - a rebuild would wipe the canvas mid-drawing.
	if phase == _current_phase and _current_screen != null \
			and _current_screen.has_method("refresh_deadline"):
		_current_screen.refresh_deadline(data)
		_apply_chat_layout(_current_screen)
		return
	# REVEAL -> JUDGING keeps the same screen alive (one grid, two phases).
	if phase == NetIds.Phase.JUDGING and _current_screen != null \
			and _current_screen.has_method("enter_judging"):
		_current_phase = phase
		_current_screen.enter_judging(data)
		_apply_chat_layout(_current_screen)
		return
	_current_phase = phase
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
	_apply_chat_layout(screen)


func _screen_path_for(phase: NetIds.Phase) -> String:
	if phase == NetIds.Phase.DRAWING:
		# Role views (§5): the judge never sees a canvas or live strokes.
		return JUDGE_WAIT_SCREEN if _session_client.is_local_player_judge() else DRAW_SCREEN
	return str(PHASE_SCREENS.get(phase, ""))


## Prominence AND placement are properties of the phase screen, never a
## global toggle (cg §8). BOTTOM chat lives under the phase area (Main);
## SIDE chat is reparented beside it (Body) - the drawer's drawing view puts
## chat to the right of the canvas (owner feedback 2026-07-06).
func _apply_chat_layout(screen: Control) -> void:
	var placement: ChatPanel.Placement = ChatPanel.Placement.BOTTOM
	if screen != null and screen.has_method("chat_placement"):
		placement = screen.chat_placement()
	var target: Container = _body if placement == ChatPanel.Placement.SIDE else _main
	if _chat.get_parent() != target:
		_chat.reparent(target, false)
	_chat.placement = placement
	if screen != null and screen.has_method("chat_prominence"):
		_chat.prominence = screen.chat_prominence()
	else:
		_chat.prominence = ChatPanel.Prominence.NORMAL
