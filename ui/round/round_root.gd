extends Control
## Persistent in-game container (Slice 3 TDD §7). Swaps one phase screen per
## EventBus.phase_changed (not full Nav navigations - cg §8), hosts the
## persistent ChatPanel whose prominence each phase screen declares, and
## hosts the SessionClient node (same node path on every peer = matching RPC
## paths).

const DRAW_SCREEN: String = "res://ui/round/draw_screen.tscn"
const JUDGE_WAIT_SCREEN: String = "res://ui/round/judge_wait_screen.tscn"
const PHASE_SCREENS: Dictionary = {
	NetIds.Phase.POOL_SETUP: "res://ui/round/pool_setup_screen.tscn",
	NetIds.Phase.ROUND_INTRO: "res://ui/round/round_intro_screen.tscn",
	NetIds.Phase.REVEAL: "res://ui/round/reveal_judging_screen.tscn",
	NetIds.Phase.JUDGING: "res://ui/round/reveal_judging_screen.tscn",
	NetIds.Phase.RESOLUTION: "res://ui/round/resolution_screen.tscn",
	NetIds.Phase.WRAP_UP: "res://ui/wrapup/wrap_up_screen.tscn",  # Slice 10
}

const TOAST_COALESCE_MSEC: int = 3000   # Slice 9: identical toasts within this window collapse

var _current_screen: Control = null
var _current_phase: NetIds.Phase = NetIds.Phase.LOBBY
var _last_toast: String = ""
var _last_toast_ms: int = 0

@onready var _body: HBoxContainer = %Body
@onready var _main: VBoxContainer = %Main
@onready var _phase_area: Control = %PhaseArea
@onready var _chat: ChatPanel = %Chat
@onready var _session_client: SessionClient = %SessionClient
@onready var _waiting_label: Label = %WaitingLabel
@onready var _menu: GameMenu = %Menu
@onready var _toast: Toast = %Toast
@onready var _pause_overlay: PauseOverlay = %PauseOverlay
@onready var _late_join_wait: LateJoinWaitBanner = %LateJoinWait


func _ready() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)
	_chat.message_submitted.connect(Session.submit_chat)
	_chat.prominence = ChatPanel.Prominence.NORMAL
	_menu.setup(_session_client)
	# Slice 17: the chat header hosts the JUDGING ready-up strip; RoundRoot
	# forwards its button to the client (ChatPanel stays Session-free).
	_chat.ready_toggled.connect(func(ready: bool) -> void:
		_session_client.request_set_ready(ready))
	EventBus.ready_state_changed.connect(_on_ready_state_changed)
	EventBus.judge_pick_latched.connect(func() -> void:
		_chat.set_ready_button_enabled(true))
	# Slice 9: below-minimum pause overlay + join/drop/rejoin/forfeit toasts.
	_pause_overlay.setup(_session_client)
	EventBus.player_dropped.connect(func(_pid: String, display_name: String) -> void:
		_toast_coalesced("%s disconnected" % display_name))
	EventBus.player_rejoined.connect(func(_pid: String, display_name: String) -> void:
		_toast_coalesced("%s is back!" % display_name))
	EventBus.player_late_joined.connect(func(_pid: String, display_name: String) -> void:
		_toast_coalesced("%s joined the game!" % display_name))
	EventBus.judge_slot_forfeited.connect(func(_pid: String, display_name: String) -> void:
		_toast_coalesced("%s dodged judging: -1" % display_name))


## Slice 6: Esc toggles the in-game menu (forced open while paused).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_menu.toggle()
		get_viewport().set_input_as_handled()


func _on_phase_changed(phase: NetIds.Phase, data: Dictionary) -> void:
	_waiting_label.visible = false
	# Pause keeps the live screen (canvas strokes, staged reveals) under the
	# overlay; nothing is rebuilt. Slice 9 picks the surface by reason: the
	# host's menu pause shows GameMenu, a below-minimum freeze shows the
	# waiting overlay (chat stays usable beside it).
	if phase == NetIds.Phase.PAUSED:
		if int(data.get("reason", NetIds.PauseReason.HOST_MENU)) \
				== NetIds.PauseReason.BELOW_MINIMUM:
			_pause_overlay.open(int(data.get("connected_count", 0)))
		else:
			_menu.show_paused()
		return
	_menu.hide_paused()
	_pause_overlay.close()
	_refresh_spectator_banner(phase)
	# Slice 17: the judging ready strip lives in the chat header. The judge's
	# button unlocks once they latch a pick (EventBus.judge_pick_latched).
	if phase == NetIds.Phase.JUDGING:
		_chat.show_ready_strip(_connected_players_view())
		_chat.set_ready_button_enabled(not _session_client.is_local_player_judge())
	else:
		_chat.hide_ready_strip()
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
	# Slice 9: a welcomed late joiner / rejoiner can be born straight into
	# JUDGING (no REVEAL came first) - enter judging mode on the fresh screen.
	if phase == NetIds.Phase.JUDGING and _current_screen != null \
			and _current_screen.has_method("enter_judging"):
		_current_screen.enter_judging(data)


func _swap_screen(phase: NetIds.Phase, data: Dictionary) -> void:
	if _current_screen != null:
		# The chat may live inside the retiring screen's side slot (Slice 17
		# fix batch) - rescue it BEFORE the free or it dies with the screen.
		if _current_screen.is_ancestor_of(_chat):
			_chat.reparent(_main, false)
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
		# Slice 9: spectators (late joiner pre-activation / mid-DRAWING
		# rejoiner) get the judge-wait view too - prompt + chat, no canvas.
		if _session_client.is_local_player_judge() \
				or _session_client.is_spectating_current_round():
			return JUDGE_WAIT_SCREEN
		return DRAW_SCREEN
	return str(PHASE_SCREENS.get(phase, ""))


## Slice 9: the spectator banner rides over every in-round phase screen
## while this peer waits for its first (or next) drawing round.
func _refresh_spectator_banner(phase: NetIds.Phase) -> void:
	var in_round: bool = phase in [NetIds.Phase.ROUND_INTRO, NetIds.Phase.DRAWING,
			NetIds.Phase.REVEAL, NetIds.Phase.JUDGING, NetIds.Phase.RESOLUTION]
	if in_round and _session_client.is_spectating_current_round():
		_late_join_wait.show_waiting("You're in! You'll draw starting next round."
				if _session_client.is_waiting_for_activation()
				else "You're back in! You'll draw again next round.")
	else:
		_late_join_wait.hide_waiting()


func _toast_coalesced(message: String) -> void:
	var now: int = Time.get_ticks_msec()
	if message == _last_toast and now - _last_toast_ms < TOAST_COALESCE_MSEC:
		return   # connection flapping stays calm (§10)
	_last_toast = message
	_last_toast_ms = now
	_toast.show_message(message)


func _on_ready_state_changed(ready_ids: PackedStringArray) -> void:
	_chat.update_ready_ids(ready_ids)
	var me: Roster.PlayerState = Session.local_player()
	if me != null:
		_chat.set_ready_local(ready_ids.has(me.platform_id))


## All connected players (drawers + judge) - the JUDGING ready-up roster.
func _connected_players_view() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Roster.PlayerState in Session.roster.players_in_join_order():
		if p.is_connected:
			out.append({"id": p.platform_id, "name": p.display_name})
	return out


## Prominence AND placement are properties of the phase screen, never a
## global toggle (cg §8). BOTTOM chat lives under the phase area (Main);
## SIDE chat is reparented beside it (Body) - the drawer's drawing view puts
## chat to the right of the canvas (owner feedback 2026-07-06).
func _apply_chat_layout(screen: Control) -> void:
	var placement: ChatPanel.Placement = ChatPanel.Placement.BOTTOM
	if screen != null and screen.has_method("chat_placement"):
		placement = screen.chat_placement()
	var target: Container = _main
	if placement == ChatPanel.Placement.SIDE:
		# Screens may host the side chat in their own slot so its bottom
		# aligns with the canvas, not the window (owner, 2026-07-07);
		# otherwise it sits beside the whole phase area.
		target = _body
		if screen != null and screen.has_method("chat_side_slot"):
			var slot: Container = screen.chat_side_slot()
			if slot != null:
				target = slot
	if _chat.get_parent() != target:
		_chat.reparent(target, false)
	_chat.placement = placement
	if screen != null and screen.has_method("chat_prominence"):
		_chat.prominence = screen.chat_prominence()
	else:
		_chat.prominence = ChatPanel.Prominence.NORMAL
