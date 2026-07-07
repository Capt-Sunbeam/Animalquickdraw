class_name RoundCiDriver
extends Node
## Automated Slice 3+4 gate driver (debug builds; tools/verify_round.sh) -
## the scripted equivalent of the Chunk 6/7 blocking playtests: a full
## 3-player 2-round game over ENet. Round 1 the judge picks (winner +2) and
## the Slice 4 social layer runs live: judge reacts/un-reacts/re-reacts and
## spends a kudos (collection write + wallet verified on the judge peer);
## drawers cross-react. Round 2 the judge deliberately lets the window lapse
## (judge -1). Verifies per-peer phase sequences, role views, converged
## reaction counts/kudos totals, and the results bundle. Owner playtests
## remain the formal gate.

const TIMEOUT_SEC: float = 150.0
const EXPECT_PLAYERS: int = 3
const ROUNDS: int = 2
const HOST_LINGER_SEC: float = 2.5
const CLIENT_LINGER_SEC: float = 1.0
const JUDGE_PICK_DELAY_SEC: float = 2.0   # lets every peer's reactions land first

var role: String = "join"   # "host" | "join"
var room_code: String = "LOCAL"

var _started: bool = false
var _finished: bool = false
var _phase_log: Array[int] = []
var _entries: Array = []
var _results: Dictionary = {}
# Slice 4 observations (every peer):
var _r0_entry_ids: Array[String] = []     # round 0 reveal order (broadcast order)
var _reaction_counts: Dictionary = {}     # drawing_id -> last synced counts
var _kudos_totals: Dictionary = {}        # drawing_id -> last synced total
var _saw_laugh_removed: bool = false      # un-react decrement observed
var _kudos_remaining: int = -1            # judge peer: from the private confirm
var _kudos_saved_id: String = ""          # judge peer: collection item id
# Slice 5 observations:
var _beats: Array[Dictionary] = []        # {"index", "drawing_id"} in arrival order
var _gathers: int = 0


func _ready() -> void:
	get_tree().create_timer(TIMEOUT_SEC).timeout.connect(_fail.bind("timeout"))
	# Sandbox the collection: instances share user://, and CI must never
	# touch a real player collection.
	CollectionStore.root_dir = "ci_collection_%d" % OS.get_process_id()
	EventBus.roster_updated.connect(_on_roster_updated)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.reveal_entries_received.connect(_on_entries)
	EventBus.session_results_ready.connect(_on_results)
	EventBus.session_closed.connect(_on_session_closed)
	EventBus.reaction_counts_changed.connect(_on_reaction_counts)
	EventBus.kudos_total_changed.connect(_on_kudos_total)
	EventBus.kudos_given.connect(_on_kudos_given)
	EventBus.reveal_beat_started.connect(func(index: int, id: String, _secs: float) -> void:
		_beats.append({"index": index, "drawing_id": id}))
	EventBus.reveal_gathered.connect(func() -> void: _gathers += 1)
	if role == "host":
		var err: Error = await Session.host_session(room_code)
		if err != OK:
			_fail("host_session error %s" % error_string(err))
			return
		# 2 rounds keeps the wall-clock inside CI bounds.
		var s: GameSettings = Session.settings.duplicate_settings()
		s.round_count = ROUNDS
		s.rounds_overridden = true
		# Pin every setting this script's flow depends on: a restored host
		# profile (last_lobby_settings) must never reroute CI - e.g. a saved
		# pool_source=PLAYER_SUBMITTED parks the game in deadline-less
		# POOL_SETUP and the gate times out (found 2026-07-07, Slice 16 run).
		s.pool_source = GameSettings.PoolSource.BUILT_IN
		Session.set_settings(s)
	else:
		var err: Error = await Session.join_session(room_code)
		if err != OK:
			_fail("join_session error %s" % error_string(err))


func _on_roster_updated(players: Array) -> void:
	if role != "host" or _started:
		return
	if players.size() >= EXPECT_PLAYERS and Session.can_start():
		_started = true
		Session.start_game()


func _on_phase_changed(phase: NetIds.Phase, _data: Dictionary) -> void:
	_phase_log.append(int(phase))
	match phase:
		NetIds.Phase.DRAWING:
			# Deferred: RoundRoot's screen swap runs after this handler.
			_check_role_view.call_deferred()
			_maybe_submit.call_deferred()
		NetIds.Phase.JUDGING:
			_maybe_social.call_deferred()
			_maybe_pick.call_deferred()
		_:
			pass


func _on_entries(entries: Array) -> void:
	_entries = entries
	# Capture round 0's ids HERE: the REVEAL broadcast is strictly ordered
	# before any reaction sync on the reliable channel, while a deferred
	# capture at JUDGING can run after the judge's first toggles arrive.
	var client: SessionClient = _session_client()
	if _r0_entry_ids.is_empty() and client != null and client.round_index() == 0:
		for entry: Dictionary in entries:
			_r0_entry_ids.append(str(entry["drawing_id"]))


func _session_client() -> SessionClient:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("SessionClient", true, false) as SessionClient


func _is_local_judge() -> bool:
	var client: SessionClient = _session_client()
	return client != null and client.is_local_player_judge()


## §5 structural check: judge gets JudgeWaitScreen and never a canvas;
## drawers get DrawScreen.
func _check_role_view() -> void:
	if _finished:
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		_fail("no scene at DRAWING")
		return
	var has_judge_view: bool = scene.find_child("JudgeWaitScreen", true, false) != null
	var has_draw_view: bool = scene.find_child("DrawScreen", true, false) != null
	if _is_local_judge():
		if not has_judge_view or has_draw_view:
			_fail("judge got the wrong DRAWING view")
	elif not has_draw_view:
		_fail("drawer is missing the DrawScreen")


func _maybe_submit() -> void:
	if _finished or _is_local_judge():
		return
	var client: SessionClient = _session_client()
	if client == null:
		_fail("no SessionClient at DRAWING")
		return
	# Per-peer-unique op count: local own-drawing detection (Slice 4)
	# compares submitted docs, so identical docs would confuse every drawer.
	# Derived from joined_order (0..7, unique per player) - NEVER from peer
	# id: ENet client peer ids are random 32-bit ints, and using one as a
	# loop bound froze the machine allocating ~1e9 ops (2026-07-06). The
	# clamp is a permanent backstop.
	var me: Roster.PlayerState = Session.local_player()
	var op_count: int = clampi(1 + (me.joined_order if me != null else 0), 1, 9)
	var ops: Array = []
	for i: int in op_count - 1:
		ops.append({"t": "clear"})
	# Slice 16 pipeline check: every doc carries a TEXT op; it must survive
	# to every peer's reveal entries (per-peer-unique via op_count).
	ops.append({"t": "text", "c": 4, "s": 1, "x": 100, "y": 100,
			"str": "ci text %d" % op_count})
	client.request_submit_drawing(
			{"doc": {"v": 1, "orientation": "landscape", "ops": ops}})
	# Slice 17: submitting no longer ends DRAWING - readying up does. The
	# ready RPC follows the submit on the same reliable channel (ordered).
	client.request_set_ready(true)


## Slice 4 social script, round 0 JUDGING only. Judge: LAUGH on -> off -> on
## (net 1; the off must sync a decrement) + one kudos on entry 0. Drawers:
## FIRE on every non-own entry (each entry ends with exactly 1 FIRE).
func _maybe_social() -> void:
	if _finished:
		return
	var client: SessionClient = _session_client()
	if client == null or client.round_index() != 0:
		return
	if _r0_entry_ids.size() != EXPECT_PLAYERS - 1:
		_fail("round 0 entry count %d != %d" % [_r0_entry_ids.size(), EXPECT_PLAYERS - 1])
		return
	if _is_local_judge():
		var target: String = _r0_entry_ids[0]
		client.request_react(target, NetIds.Reaction.LAUGH, true)
		client.request_react(target, NetIds.Reaction.LAUGH, false)
		client.request_react(target, NetIds.Reaction.LAUGH, true)
		client.request_give_kudos(target)
	else:
		for id: String in _r0_entry_ids:
			if not client.is_own_drawing(id):
				client.request_react(id, NetIds.Reaction.FIRE, true)
		# Slice 17: drawers ready up after their reactions (ordered channel:
		# every FIRE lands before this peer counts toward the early end).
		client.request_set_ready(true)


func _maybe_pick() -> void:
	if _finished or not _is_local_judge():
		return
	var client: SessionClient = _session_client()
	if client == null:
		return
	if client.round_index() == 0:
		if _entries.is_empty():
			_fail("judge has no reveal entries")
			return
		# Delay the pick so every peer's reactions/kudos land inside the
		# window (the gate closes at RESOLUTION).
		await get_tree().create_timer(JUDGE_PICK_DELAY_SEC).timeout
		if _finished:
			return
		client.request_pick_winner(str((_entries[0] as Dictionary)["drawing_id"]))
		# Slice 17: judge readies after latching - with the drawers already
		# ready this ends JUDGING early and crowns the latched pick.
		client.request_set_ready(true)
	# Round 1: stay silent - the window must lapse into the -1 penalty
	# (drawers' readies alone never end JUDGING; the judge is required).


func _on_reaction_counts(drawing_id: String, counts: Dictionary) -> void:
	_reaction_counts[drawing_id] = counts
	# The judge's un-react must arrive as a sync where LAUGH dropped out.
	if not _r0_entry_ids.is_empty() and drawing_id == _r0_entry_ids[0] \
			and int(counts.get(int(NetIds.Reaction.LAUGH), 0)) == 0:
		_saw_laugh_removed = true


func _on_kudos_total(drawing_id: String, total: int) -> void:
	_kudos_totals[drawing_id] = total


## Judge peer only: private confirm -> the local collection write happened.
func _on_kudos_given(drawing_id: String, remaining: int) -> void:
	_kudos_remaining = remaining
	if not CollectionStore.has_session_drawing(drawing_id):
		_fail("kudos confirm but drawing missing from collection index")
		return
	var index: Dictionary = Save.read_json(CollectionStore.root_dir + "/index.json", {})
	var items: Array = index.get("items", [])
	if items.size() != 1:
		_fail("collection index has %d items, want 1" % items.size())
		return
	var item: Dictionary = items[0]
	_kudos_saved_id = str(item.get("id", ""))
	if str(item.get("source", "")) != "kudos" or str(item.get("prompt", "")).is_empty():
		_fail("collection item malformed: %s" % str(item))
		return
	var doc: Dictionary = Save.read_json("%s/%s.json" % [CollectionStore.root_dir, _kudos_saved_id], {})
	if DrawingDoc.from_dict(doc) == null:
		_fail("saved collection doc does not parse")


func _on_results(results: Dictionary) -> void:
	_results = results
	# Deferred: session_results_ready fires before phase_changed(WRAP_UP)
	# (SessionClient emits the specific signal first), so the phase log
	# completes one signal later.
	_verify.call_deferred()


func _verify() -> void:
	var rounds: Array = _results.get("rounds", [])
	if rounds.size() != ROUNDS:
		_fail("rounds size %d != %d" % [rounds.size(), ROUNDS])
		return
	if not bool((rounds[0] as Dictionary).get("picked", false)):
		_fail("round 1 was not picked")
		return
	if bool((rounds[1] as Dictionary).get("picked", true)):
		_fail("round 2 was unexpectedly picked")
		return
	var standings: Array = _results.get("standings", [])
	if standings.size() != EXPECT_PLAYERS:
		_fail("standings size %d != %d" % [standings.size(), EXPECT_PLAYERS])
		return
	var scores: Dictionary = _results.get("final_scores", {})
	var total: int = 0
	for pid: Variant in scores:
		total += int(scores[pid])
	# Slice 4: the judge's kudos adds +1 to round 0's winner (same drawing).
	var expected_total: int = GameConstants.WINNER_POINTS + GameConstants.KUDOS_POINTS \
			+ GameConstants.JUDGE_NO_PICK_POINTS
	if total != expected_total:
		_fail("final scores sum %d != %d" % [total, expected_total])
		return
	# The no-pick judge's exact score is deterministic given round 1's winner.
	var winner: String = str((rounds[0] as Dictionary).get("winner_player_id", ""))
	var lapsed_judge: String = str((rounds[1] as Dictionary).get("judge_player_id", ""))
	var expected: int = GameConstants.JUDGE_NO_PICK_POINTS \
			+ (GameConstants.WINNER_POINTS + GameConstants.KUDOS_POINTS \
			if winner == lapsed_judge else 0)
	if int(scores.get(lapsed_judge, 9999)) != expected:
		_fail("no-pick -1 not applied to judge (got %s, want %d)"
				% [str(scores.get(lapsed_judge)), expected])
		return
	if not _verify_social():
		return
	if not _verify_reveal_choreography():
		return
	var expected_phases: Array[int] = []
	for i: int in range(ROUNDS):
		expected_phases.append_array([NetIds.Phase.ROUND_INTRO, NetIds.Phase.DRAWING,
				NetIds.Phase.REVEAL, NetIds.Phase.JUDGING, NetIds.Phase.RESOLUTION])
	expected_phases.append(NetIds.Phase.WRAP_UP)
	if _phase_log != expected_phases:
		_fail("phase sequence mismatch: %s" % str(_phase_log))
		return
	_pass("2 rounds, pick + no-pick, reactions/kudos converged, scores consistent")


## Slice 4 convergence: every peer must have observed identical final
## reaction counts and kudos totals for round 0 (host truth, one sync each).
func _verify_social() -> bool:
	if _r0_entry_ids.size() != EXPECT_PLAYERS - 1:
		_fail("round 0 entry ids were never captured")
		return false
	var e0: String = _r0_entry_ids[0]
	var e1: String = _r0_entry_ids[1]
	var c0: Dictionary = _reaction_counts.get(e0, {})
	var c1: Dictionary = _reaction_counts.get(e1, {})
	if int(c0.get(int(NetIds.Reaction.LAUGH), 0)) != 1 \
			or int(c0.get(int(NetIds.Reaction.FIRE), 0)) != 1:
		_fail("entry0 final counts wrong: %s (want LAUGH 1, FIRE 1)" % str(c0))
		return false
	if int(c1.get(int(NetIds.Reaction.FIRE), 0)) != 1 \
			or c1.has(int(NetIds.Reaction.LAUGH)):
		_fail("entry1 final counts wrong: %s (want FIRE 1 only)" % str(c1))
		return false
	if not _saw_laugh_removed:
		_fail("un-react decrement was never observed")
		return false
	if int(_kudos_totals.get(e0, 0)) != 1 or int(_kudos_totals.get(e1, 0)) != 0:
		_fail("kudos totals wrong: %s (want entry0=1 only)" % str(_kudos_totals))
		return false
	var kudos_stats: Dictionary = _results.get("kudos_stats", {})
	var received: Dictionary = kudos_stats.get("received_by_author", {})
	if received.size() != 1:
		_fail("results kudos_stats.received_by_author wrong: %s" % str(received))
		return false
	if _is_local_judge_platform_round0():
		if _kudos_remaining != 0:
			_fail("judge wallet after kudos: %d, want 0 (allotment 1)" % _kudos_remaining)
			return false
		if _kudos_saved_id.is_empty():
			_fail("judge kudos confirm never arrived / collection not written")
			return false
	return true


## Round 0's judge is the first-joined player - the host in this script.
func _is_local_judge_platform_round0() -> bool:
	return role == "host"


## Slice 5: default settings run ONE_AT_A_TIME - every peer must see one
## beat per drawing per round (indices 0..n-1), a gather per round, and
## (Slice 16) the submitted TEXT ops delivered inside the entry docs with
## no caption key anywhere.
func _verify_reveal_choreography() -> bool:
	var per_round: int = EXPECT_PLAYERS - 1
	if _beats.size() != per_round * ROUNDS:
		_fail("beat count %d != %d" % [_beats.size(), per_round * ROUNDS])
		return false
	for round_n: int in ROUNDS:
		for i: int in per_round:
			if int(_beats[round_n * per_round + i]["index"]) != i:
				_fail("beat indices out of order: %s" % str(_beats))
				return false
	if _gathers != ROUNDS:
		_fail("gather count %d != %d" % [_gathers, ROUNDS])
		return false
	# Round 1's entries are still cached - every drawer's doc carried a TEXT
	# op (Slice 16); it must arrive intact, and the caption key must be gone.
	for entry: Dictionary in _entries:
		if entry.has("caption"):
			_fail("stale caption key in reveal entry: %s" % str(entry.keys()))
			return false
		var has_text_op: bool = false
		for op: Variant in (entry.get("doc", {}) as Dictionary).get("ops", []):
			if op is Dictionary and str((op as Dictionary).get("t", "")) == "text" \
					and str((op as Dictionary).get("str", "")).begins_with("ci text "):
				has_text_op = true
		if not has_text_op:
			_fail("text op missing from reveal entry doc: %s" % str(entry.keys()))
			return false
	return true


func _on_session_closed(reason: String) -> void:
	_fail("session closed unexpectedly: %s" % reason)


func _pass(detail: String) -> void:
	if _finished:
		return
	_finished = true
	_wipe_ci_collection()
	print("CI_ROUND_OK [%s]: %s" % [role, detail])
	var linger: float = HOST_LINGER_SEC if role == "host" else CLIENT_LINGER_SEC
	await get_tree().create_timer(linger).timeout
	get_tree().quit(0)


func _fail(reason: String) -> void:
	if _finished:
		return
	_finished = true
	print("CI_ROUND_FAIL [%s]: %s" % [role, reason])
	get_tree().quit(1)


func _wipe_ci_collection() -> void:
	for file: String in Save.list_dir(CollectionStore.root_dir + "/thumbs"):
		Save.delete(CollectionStore.root_dir + "/thumbs/" + file)
	for file: String in Save.list_dir(CollectionStore.root_dir):
		Save.delete(CollectionStore.root_dir + "/" + file)
