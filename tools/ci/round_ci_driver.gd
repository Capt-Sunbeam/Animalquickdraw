class_name RoundCiDriver
extends Node
## Automated Slice 3 gate driver (debug builds; tools/verify_round.sh) - the
## scripted equivalent of the Chunk 6 blocking playtests: a full 3-player
## 2-round game over ENet. Round 1 the judge picks (winner +2); round 2 the
## judge deliberately lets the window lapse (judge -1). Verifies the phase
## sequence on every peer, role views during DRAWING (judge never gets a
## canvas), and the final results bundle. Owner playtests remain the formal
## gate.

const TIMEOUT_SEC: float = 150.0
const EXPECT_PLAYERS: int = 3
const ROUNDS: int = 2
const HOST_LINGER_SEC: float = 2.5
const CLIENT_LINGER_SEC: float = 1.0

var role: String = "join"   # "host" | "join"
var room_code: String = "LOCAL"

var _started: bool = false
var _finished: bool = false
var _phase_log: Array[int] = []
var _entries: Array = []
var _results: Dictionary = {}


func _ready() -> void:
	get_tree().create_timer(TIMEOUT_SEC).timeout.connect(_fail.bind("timeout"))
	EventBus.roster_updated.connect(_on_roster_updated)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.reveal_entries_received.connect(_on_entries)
	EventBus.session_results_ready.connect(_on_results)
	EventBus.session_closed.connect(_on_session_closed)
	if role == "host":
		var err: Error = await Session.host_session(room_code)
		if err != OK:
			_fail("host_session error %s" % error_string(err))
			return
		# 2 rounds keeps the wall-clock inside CI bounds.
		var s: GameSettings = Session.settings.duplicate_settings()
		s.round_count = ROUNDS
		s.rounds_overridden = true
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
			_maybe_pick.call_deferred()
		_:
			pass


func _on_entries(entries: Array) -> void:
	_entries = entries


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
	client.request_submit_drawing(
			{"doc": {"v": 1, "orientation": "landscape", "ops": [{"t": "clear"}]}})


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
		client.request_pick_winner(str((_entries[0] as Dictionary)["drawing_id"]))
	# Round 1: stay silent - the window must lapse into the -1 penalty.


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
	if total != GameConstants.WINNER_POINTS + GameConstants.JUDGE_NO_PICK_POINTS:
		_fail("final scores sum %d != %d" % [total,
				GameConstants.WINNER_POINTS + GameConstants.JUDGE_NO_PICK_POINTS])
		return
	# The no-pick judge's exact score is deterministic given round 1's winner.
	var winner: String = str((rounds[0] as Dictionary).get("winner_player_id", ""))
	var lapsed_judge: String = str((rounds[1] as Dictionary).get("judge_player_id", ""))
	var expected: int = GameConstants.JUDGE_NO_PICK_POINTS \
			+ (GameConstants.WINNER_POINTS if winner == lapsed_judge else 0)
	if int(scores.get(lapsed_judge, 9999)) != expected:
		_fail("no-pick -1 not applied to judge (got %s, want %d)"
				% [str(scores.get(lapsed_judge)), expected])
		return
	var expected_phases: Array[int] = []
	for i: int in range(ROUNDS):
		expected_phases.append_array([NetIds.Phase.ROUND_INTRO, NetIds.Phase.DRAWING,
				NetIds.Phase.REVEAL, NetIds.Phase.JUDGING, NetIds.Phase.RESOLUTION])
	expected_phases.append(NetIds.Phase.WRAP_UP)
	if _phase_log != expected_phases:
		_fail("phase sequence mismatch: %s" % str(_phase_log))
		return
	_pass("2 rounds, pick + no-pick verified, scores consistent")


func _on_session_closed(reason: String) -> void:
	_fail("session closed unexpectedly: %s" % reason)


func _pass(detail: String) -> void:
	if _finished:
		return
	_finished = true
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
