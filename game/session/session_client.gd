class_name SessionClient
extends Node
## RPC endpoint present at the same path on every peer (child of RoundRoot -
## Slice 3 TDD §8). Deliberately thin: the host side owns the GameSession
## simulation and the authoritative phase Timer; the client side is a dumb
## replica store + EventBus signal relay. It never mutates game state on
## its own. UI never touches GameSession (cg §3) - it calls the request_*
## methods here.

var _session: GameSession = null           # non-null on host only
var _phase: NetIds.Phase = NetIds.Phase.LOBBY
var _phase_data: Dictionary = {}
var _reveal_entries: Array[Dictionary] = []
var _scores: Dictionary = {}
var _judge_player_id: String = ""
var _round_index: int = 0
var _round_count: int = 0
var _ready_peers: Dictionary = {}          # host: peer_id -> true (start handshake)
var _sim_started: bool = false

var _phase_timer: Timer = null             # host-only authoritative deadline


func _ready() -> void:
	if multiplayer.is_server():
		_phase_timer = Timer.new()
		_phase_timer.one_shot = true
		_phase_timer.timeout.connect(_on_host_deadline)
		add_child(_phase_timer)
		_session = GameSession.new(Session.settings.duplicate_settings(), Session.roster)
		_session.phase_entered.connect(_on_phase_entered)
		_ready_peers[1] = true
		# Clients navigate into RoundRoot a beat after the host; start when
		# every connected peer reports ready, or on the failsafe - a broken
		# client must never stall the game (favor flow, brief §1).
		get_tree().create_timer(GameConstants.ROUND_START_FAILSAFE_SEC)\
				.timeout.connect(_on_start_failsafe)
		# Deferred: children _ready before parents, so an immediate start
		# would broadcast ROUND_INTRO before RoundRoot has connected.
		_maybe_start_simulation.call_deferred()
	else:
		rpc_request_round_ready.rpc_id(1)


# --- Public replica accessors (phase screens read these) ---


func phase() -> NetIds.Phase:
	return _phase


func phase_data() -> Dictionary:
	return _phase_data


func reveal_entries() -> Array[Dictionary]:
	return _reveal_entries


func scores() -> Dictionary:
	return _scores


func judge_player_id() -> String:
	return _judge_player_id


func round_index() -> int:
	return _round_index


func round_count() -> int:
	return _round_count


func is_local_player_judge() -> bool:
	var me: Roster.PlayerState = Session.local_player()
	return me != null and not _judge_player_id.is_empty() \
			and me.platform_id == _judge_player_id


# --- Public intents (UI calls; host path skips RPC, same validation) ---


func request_submit_drawing(payload: Dictionary) -> void:
	if multiplayer.is_server():
		var me: Roster.PlayerState = Session.local_player()
		if _session != null and me != null:
			_session.submit_drawing(me.platform_id, payload)
	else:
		rpc_request_submit_drawing.rpc_id(1, payload)


func request_pick_winner(drawing_id: String) -> void:
	if multiplayer.is_server():
		var me: Roster.PlayerState = Session.local_player()
		if _session != null and me != null:
			_session.pick_winner(me.platform_id, drawing_id)
	else:
		rpc_request_pick_winner.rpc_id(1, drawing_id)


# --- Host side: simulation start + authoritative timer ---


func _maybe_start_simulation(force: bool = false) -> void:
	if _sim_started or _session == null:
		return
	if Session.roster.size() == 0:
		return  # never start an empty simulation (also keeps tests inert)
	if force or _all_roster_peers_ready():
		_sim_started = true
		_session.start_game()


func _all_roster_peers_ready() -> bool:
	for p: Roster.PlayerState in Session.roster.players_in_join_order():
		if p.is_connected and not _ready_peers.has(p.peer_id):
			return false
	return true


func _on_start_failsafe() -> void:
	_maybe_start_simulation(true)


func _on_phase_entered(phase_value: NetIds.Phase, data: Dictionary) -> void:
	rpc_sync_phase.rpc(int(phase_value), data)
	_arm_host_timer(phase_value, data)


## One authoritative expiry per phase. The broadcast deadline is what
## clients render; the host's DRAWING timer additionally waits out the
## submission grace window before collecting (Slice 3 TDD §6).
func _arm_host_timer(phase_value: NetIds.Phase, data: Dictionary) -> void:
	_phase_timer.stop()
	if not data.has("deadline_ms"):
		return  # terminal phase (WRAP_UP)
	var wait_ms: int = int(data["deadline_ms"]) - _local_now_ms()
	if phase_value == NetIds.Phase.DRAWING:
		wait_ms += GameConstants.SUBMIT_GRACE_MS
	_phase_timer.start(maxf(0.05, wait_ms / 1000.0))


func _on_host_deadline() -> void:
	if _session != null:
		_session.on_phase_deadline()


static func _local_now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


# --- RPC methods (grouped last per consistency guide §3) ---


## client -> host: this peer's RoundRoot is live; used for the start
## handshake so the first ROUND_INTRO broadcast is never missed.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_round_ready() -> void:
	if not multiplayer.is_server():
		return                                             # 1. authority
	var sender: int = multiplayer.get_remote_sender_id()
	if Session.roster.get_by_peer(sender) == null:
		return                                             # 2. unknown peer - drop
	_ready_peers[sender] = true                            # 3-4. record
	_maybe_start_simulation()                              # 5. start when all ready


## host -> all: the one replication channel for round state.
@rpc("authority", "call_local", "reliable")
func rpc_sync_phase(phase_value: int, data: Dictionary) -> void:
	if phase_value < 0 or phase_value >= NetIds.Phase.size():
		push_warning("SessionClient: unknown phase %d dropped" % phase_value)
		return
	_phase = phase_value as NetIds.Phase
	_phase_data = data
	match _phase:
		NetIds.Phase.ROUND_INTRO:
			_reveal_entries = []
			_round_index = int(data.get("round_index", 0))
			_round_count = int(data.get("round_count", 0))
			_judge_player_id = str(data.get("judge_player_id", ""))
			EventBus.round_started.emit(_round_index, _round_count, _judge_player_id)
		NetIds.Phase.REVEAL:
			_reveal_entries = []
			for raw: Variant in data.get("entries", []):
				if raw is Dictionary:
					_reveal_entries.append(raw)
			EventBus.reveal_entries_received.emit(_reveal_entries)
		NetIds.Phase.RESOLUTION:
			_scores = data.get("scores", {})
			EventBus.round_resolved.emit(data)
			EventBus.scores_updated.emit(_scores)
		NetIds.Phase.WRAP_UP:
			EventBus.session_results_ready.emit(data.get("results", {}))
	EventBus.phase_changed.emit(_phase, data)


## drawer client -> host. Steps 3-5 live in GameSession.submit_drawing
## (shared with the host's own request path - unit-testable, no network).
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_submit_drawing(payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return                                             # 1. authority
	var sender: int = multiplayer.get_remote_sender_id()
	var player: Roster.PlayerState = Session.roster.get_by_peer(sender)
	if player == null or _session == null:
		return                                             # 2. resolve sender
	_session.submit_drawing(player.platform_id, payload)   # 3-5. shared path


## judge client -> host. Steps 3-5 live in GameSession.pick_winner.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_pick_winner(drawing_id: String) -> void:
	if not multiplayer.is_server():
		return                                             # 1. authority
	var sender: int = multiplayer.get_remote_sender_id()
	var player: Roster.PlayerState = Session.roster.get_by_peer(sender)
	if player == null or _session == null:
		return                                             # 2. resolve sender
	_session.pick_winner(player.platform_id, drawing_id)   # 3-5. shared path
