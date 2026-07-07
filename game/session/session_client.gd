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

# Slice 4 round cache: the kudos-save needs doc bytes + prompt text on the
# giver's machine; own-drawing detection is purely local (nothing on the
# wire marks authorship - anonymity). All reset each ROUND_INTRO.
var _prompt_text: String = ""
var _my_submitted_doc: Dictionary = {}
var _ready_ids_cache: PackedStringArray = PackedStringArray()  # Slice 17 replica

# Slice 7 replica: POOL_SETUP phase data + the latest progress broadcast.
var _pool_setup: Dictionary = {}

var _phase_timer: Timer = null             # host-only authoritative deadline
var _beat_timer: Timer = null              # host-only Slice 5 reveal metronome


func _ready() -> void:
	if multiplayer.is_server():
		_phase_timer = Timer.new()
		_phase_timer.one_shot = true
		_phase_timer.timeout.connect(_on_host_deadline)
		add_child(_phase_timer)
		_beat_timer = Timer.new()
		_beat_timer.one_shot = true
		_beat_timer.timeout.connect(_on_beat_deadline)
		add_child(_beat_timer)
		# Slice 6: the simulation reads the frozen start-payload snapshot,
		# never lobby state.
		_session = GameSession.new(Session.game_settings.duplicate_settings(), Session.roster)
		_session.phase_entered.connect(_on_phase_entered)
		_session.reaction_counts_changed.connect(_on_reaction_counts_changed)
		_session.kudos_total_changed.connect(_on_kudos_total_changed)
		_session.kudos_confirmed.connect(_on_kudos_confirmed)
		_session.reveal_beat_started.connect(_on_reveal_beat_started)
		_session.reveal_gather_started.connect(_on_reveal_gather_started)
		_session.pool_setup_progress_changed.connect(_on_pool_setup_progress_changed)
		_session.pool_words_rejected.connect(_on_pool_words_rejected)
		_session.ready_state_changed.connect(_on_ready_state_changed)
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


## Slice 17: the current phase's ready-up set (player ids). Cleared on
## every phase change.
func ready_ids() -> PackedStringArray:
	return _ready_ids_cache


func round_count() -> int:
	return _round_count


func is_local_player_judge() -> bool:
	var me: Roster.PlayerState = Session.local_player()
	return me != null and not _judge_player_id.is_empty() \
			and me.platform_id == _judge_player_id


## Slice 4: the round's prompt display text (cached from the DRAWING
## broadcast - every peer receives it, judge included).
func prompt_text() -> String:
	return _prompt_text


## Slice 4: doc bytes for a revealed drawing ({} if unknown). Every peer
## holds the full reveal set - this is the kudos-save source.
func get_drawing_doc(drawing_id: String) -> Dictionary:
	for entry: Dictionary in _reveal_entries:
		if str(entry.get("drawing_id", "")) == drawing_id:
			var doc: Variant = entry.get("doc")
			if doc is Dictionary:
				return doc
	return {}


## Slice 4: local-only authorship check - compares the reveal entry against
## the doc this peer last submitted. Nothing on the wire marks authorship;
## a drawer who never submitted (synthesized blank) matches nothing, which
## is safe: the host rejects self-reactions regardless (UI hint only).
func is_own_drawing(drawing_id: String) -> bool:
	if _my_submitted_doc.is_empty():
		return false
	return get_drawing_doc(drawing_id) == _my_submitted_doc


# --- Public intents (UI calls; host path skips RPC, same validation) ---


func request_submit_drawing(payload: Dictionary) -> void:
	var doc: Variant = payload.get("doc")
	if doc is Dictionary:
		_my_submitted_doc = doc   # local authorship memory (Slice 4)
	if multiplayer.is_server():
		var me: Roster.PlayerState = Session.local_player()
		if _session != null and me != null:
			_session.submit_drawing(me.platform_id, payload)
	else:
		rpc_request_submit_drawing.rpc_id(1, payload)


## Slice 4: toggle a reaction on a revealed drawing.
func request_react(drawing_id: String, reaction: NetIds.Reaction, active: bool) -> void:
	if multiplayer.is_server():
		var me: Roster.PlayerState = Session.local_player()
		if _session != null and me != null:
			_session.react(me.platform_id, drawing_id, reaction, active)
	else:
		rpc_request_react.rpc_id(1, drawing_id, int(reaction), active)


## Slice 6: host-only game pause/resume (the Esc menu calls these; clients
## have no pause path - there is nothing to validate inbound).
func request_pause() -> void:
	if multiplayer.is_server() and _session != null:
		_session.pause(0)


func request_resume() -> void:
	if multiplayer.is_server() and _session != null:
		_session.resume()


## Slice 4: spend a kudos on a revealed drawing.
func request_give_kudos(drawing_id: String) -> void:
	if multiplayer.is_server():
		var me: Roster.PlayerState = Session.local_player()
		if _session != null and me != null:
			_session.give_kudos(me.platform_id, drawing_id)
	else:
		rpc_request_give_kudos.rpc_id(1, drawing_id)


func request_pick_winner(drawing_id: String) -> void:
	if multiplayer.is_server():
		var me: Roster.PlayerState = Session.local_player()
		if _session != null and me != null:
			_session.pick_winner(me.platform_id, drawing_id)
	else:
		rpc_request_pick_winner.rpc_id(1, drawing_id)
	# Slice 17: local-only - the judge's Ready button unlocks once a pick
	# has been latched (the host still validates the ready itself).
	EventBus.judge_pick_latched.emit()


## Slice 17: toggle this player's ready-up flag for the current phase.
func request_set_ready(ready: bool) -> void:
	if multiplayer.is_server():
		var me: Roster.PlayerState = Session.local_player()
		if _session != null and me != null:
			_session.set_ready(me.platform_id, ready)
	else:
		rpc_request_set_ready.rpc_id(1, ready)


## Slice 7: submit one pool's complete share of words.
func request_submit_pool_words(pool_id: String, words: PackedStringArray) -> void:
	if multiplayer.is_server():
		var me: Roster.PlayerState = Session.local_player()
		if _session != null and me != null:
			_session.submit_pool_words(me.platform_id, pool_id, words)
	else:
		rpc_request_submit_words.rpc_id(1, pool_id, words)


## Slice 7: host force-continue. NOT an RPC - only the host can do it and
## the host IS the server (TDD §3); the time gate lives in GameSession.
func force_continue_pool_setup() -> void:
	if multiplayer.is_server() and _session != null:
		_session.force_lock_pools()


## Slice 7: POOL_SETUP replica for the setup screen (phase data + progress).
func pool_setup_state() -> Dictionary:
	return _pool_setup


# --- Host side: simulation start + authoritative timer ---


func _maybe_start_simulation(force: bool = false) -> void:
	if _sim_started or _session == null:
		return
	if Session.roster.size() == 0:
		return  # never start an empty simulation (also keeps tests inert)
	if force or _all_roster_peers_ready():
		_sim_started = true
		_session.start_game()
		# start_game() just reset every player's kudos economy on the HOST
		# roster objects. Re-broadcast, or client wallets keep the previous
		# game's granted/spent and their kudos buttons wrongly disable
		# (rematch staleness, owner-reported 2026-07-07).
		Session.broadcast_roster()


func _all_roster_peers_ready() -> bool:
	for p: Roster.PlayerState in Session.roster.players_in_join_order():
		if p.is_connected and not _ready_peers.has(p.peer_id):
			return false
	return true


func _on_start_failsafe() -> void:
	_maybe_start_simulation(true)


func _on_phase_entered(phase_value: NetIds.Phase, data: Dictionary) -> void:
	rpc_sync_phase.rpc(int(phase_value), data)
	# Slice 6 pause: freeze/unfreeze the reveal beat metronome with the
	# phase clock (the phase timer stops itself - PAUSED has no deadline).
	if _beat_timer != null:
		_beat_timer.paused = phase_value == NetIds.Phase.PAUSED
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


# --- Host side: Slice 5 reveal metronome ---


func _on_reveal_beat_started(index: int, drawing_id: String, beat_secs: float) -> void:
	rpc_sync_reveal_beat.rpc(index, drawing_id, beat_secs)
	_beat_timer.start(maxf(0.05, beat_secs))


func _on_reveal_gather_started(gather_secs: float) -> void:
	rpc_sync_reveal_gather.rpc()
	_beat_timer.start(maxf(0.05, gather_secs))


func _on_beat_deadline() -> void:
	if _session != null:
		_session.on_reveal_beat_deadline()   # drops itself if phase moved on


# --- Host side: Slice 4 simulation-signal translators ---


func _on_reaction_counts_changed(drawing_id: String, counts: Dictionary) -> void:
	rpc_sync_reaction_counts.rpc(drawing_id, counts)


func _on_kudos_total_changed(drawing_id: String, total: int) -> void:
	rpc_sync_kudos_total.rpc(drawing_id, total)


## Slice 7 host translator: progress signal -> broadcast.
func _on_pool_setup_progress_changed(progress: Array) -> void:
	rpc_sync_pool_setup_progress.rpc(progress)


## Slice 17 host translator: ready-up set -> broadcast.
func _on_ready_state_changed(ready_ids: PackedStringArray) -> void:
	rpc_sync_ready_state.rpc(ready_ids)


## Slice 7 host translator: relays an honest rejection to the submitting
## peer alone. The host player's own rejection skips RPC (same-machine path).
func _on_pool_words_rejected(player_id: String, pool_id: String, reason: int) -> void:
	var player: Roster.PlayerState = Session.roster.get_by_platform_id(player_id)
	if player == null:
		return
	if player.peer_id == 1:
		EventBus.pool_words_rejected.emit(pool_id, reason)
	else:
		rpc_do_words_rejected.rpc_id(player.peer_id, pool_id, reason)


## Confirms privately to the giver and re-syncs the roster (spent changed).
## The host player's own confirm skips RPC (same-machine path).
func _on_kudos_confirmed(player_id: String, drawing_id: String, kudos_remaining: int) -> void:
	Session.broadcast_roster()
	var giver: Roster.PlayerState = Session.roster.get_by_platform_id(player_id)
	if giver == null:
		return
	if giver.peer_id == 1:
		_handle_kudos_confirmed(drawing_id, kudos_remaining)
	else:
		rpc_do_kudos_confirmed.rpc_id(giver.peer_id, drawing_id, kudos_remaining)


## Giver-side effect of an accepted kudos: write the drawing to the local
## collection (best-effort - a failed save never rolls back the kudos, §10)
## and update the wallet. CollectionStore emits collection_item_added /
## collection_save_failed itself.
func _handle_kudos_confirmed(drawing_id: String, kudos_remaining: int) -> void:
	var doc: Dictionary = get_drawing_doc(drawing_id)
	if doc.is_empty():
		push_warning("SessionClient: kudos confirm for unknown drawing '%s'" % drawing_id)
		EventBus.collection_save_failed.emit()
	else:
		CollectionStore.save_drawing(doc, _prompt_text, drawing_id, CollectionStore.SOURCE_KUDOS)
	EventBus.kudos_wallet_changed.emit(kudos_remaining)
	EventBus.kudos_given.emit(drawing_id, kudos_remaining)


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
	# Slice 17: ready-up never carries across phases (PAUSED excepted - the
	# stored phase resumes via a fresh _enter_phase, which also cleared it
	# host-side, so the empty cache stays truthful).
	_ready_ids_cache = PackedStringArray()
	match _phase:
		NetIds.Phase.POOL_SETUP:
			_pool_setup = data.duplicate()
			_pool_setup["progress"] = []
		NetIds.Phase.ROUND_INTRO:
			_reveal_entries = []
			_prompt_text = ""
			_my_submitted_doc = {}
			_round_index = int(data.get("round_index", 0))
			_round_count = int(data.get("round_count", 0))
			_judge_player_id = str(data.get("judge_player_id", ""))
			EventBus.round_started.emit(_round_index, _round_count, _judge_player_id)
		NetIds.Phase.DRAWING:
			_prompt_text = str(data.get("prompt_text", ""))
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


## any player -> host (Slice 17). Steps 3-5 live in GameSession.set_ready.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_set_ready(ready: bool) -> void:
	if not multiplayer.is_server():
		return                                             # 1. authority
	var sender: int = multiplayer.get_remote_sender_id()
	var player: Roster.PlayerState = Session.roster.get_by_peer(sender)
	if player == null or _session == null:
		return                                             # 2. resolve sender
	_session.set_ready(player.platform_id, ready)          # 3-5. shared path


## host -> all (Slice 17): the current phase's ready-up set.
@rpc("authority", "call_local", "reliable")
func rpc_sync_ready_state(ready_ids: PackedStringArray) -> void:
	_ready_ids_cache = ready_ids
	EventBus.ready_state_changed.emit(ready_ids)


## reactor client -> host (Slice 4). Steps 3-5 live in GameSession.react.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_react(drawing_id: String, reaction_value: int, active: bool) -> void:
	if not multiplayer.is_server():
		return                                             # 1. authority
	var sender: int = multiplayer.get_remote_sender_id()
	var player: Roster.PlayerState = Session.roster.get_by_peer(sender)
	if player == null or _session == null:
		return                                             # 2. resolve sender
	_session.react(player.platform_id, drawing_id, reaction_value, active)


## giver client -> host (Slice 4). Steps 3-5 live in GameSession.give_kudos.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_give_kudos(drawing_id: String) -> void:
	if not multiplayer.is_server():
		return                                             # 1. authority
	var sender: int = multiplayer.get_remote_sender_id()
	var player: Roster.PlayerState = Session.roster.get_by_peer(sender)
	if player == null or _session == null:
		return                                             # 2. resolve sender
	_session.give_kudos(player.platform_id, drawing_id)


## host -> all (Slice 5): a one-at-a-time reveal beat starts. Clients play
## the beat locally (card-in -> content -> hold -> to-grid);
## slow clients hard-snap on the next beat - the host never waits.
@rpc("authority", "call_local", "reliable")
func rpc_sync_reveal_beat(index: int, drawing_id: String, beat_secs: float) -> void:
	EventBus.reveal_beat_started.emit(index, drawing_id, beat_secs)


## host -> all (Slice 5): all beats done; cards gather into the grid.
@rpc("authority", "call_local", "reliable")
func rpc_sync_reveal_gather() -> void:
	EventBus.reveal_gathered.emit()


## host -> all (Slice 4): one drawing's aggregate reaction counts
## (nonzero keys only - a key dropping out means it hit zero).
@rpc("authority", "call_local", "reliable")
func rpc_sync_reaction_counts(drawing_id: String, counts: Dictionary) -> void:
	EventBus.reaction_counts_changed.emit(drawing_id, counts)


## host -> all (Slice 4): one drawing's public kudos total.
@rpc("authority", "call_local", "reliable")
func rpc_sync_kudos_total(drawing_id: String, total: int) -> void:
	EventBus.kudos_total_changed.emit(drawing_id, total)


## host -> giver only (Slice 4): kudos accepted; write the local collection
## copy and update the wallet. The host player's own confirm arrives via the
## direct _handle_kudos_confirmed call instead (no self-RPC).
@rpc("authority", "call_remote", "reliable")
func rpc_do_kudos_confirmed(drawing_id: String, kudos_remaining: int) -> void:
	_handle_kudos_confirmed(drawing_id, kudos_remaining)


## submitting client -> host (Slice 7). Steps 3-5 live in
## GameSession.submit_pool_words (shared with the host's own request path).
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_submit_words(pool_id: String, words: PackedStringArray) -> void:
	if not multiplayer.is_server():
		return                                             # 1. authority
	var sender: int = multiplayer.get_remote_sender_id()
	var player: Roster.PlayerState = Session.roster.get_by_peer(sender)
	if player == null or _session == null:
		return                                             # 2. resolve sender
	_session.submit_pool_words(player.platform_id, pool_id, words)  # 3-5


## host -> submitting peer only (Slice 7): a pool submission failed host
## validation (client pre-check disagreed - tampered/outdated client).
@rpc("authority", "call_remote", "reliable")
func rpc_do_words_rejected(pool_id: String, reason: int) -> void:
	EventBus.pool_words_rejected.emit(pool_id, reason)


## host -> all (Slice 7): waiting-panel submission progress.
@rpc("authority", "call_local", "reliable")
func rpc_sync_pool_setup_progress(progress: Array) -> void:
	_pool_setup["progress"] = progress
	EventBus.pool_setup_progress_changed.emit(progress)
