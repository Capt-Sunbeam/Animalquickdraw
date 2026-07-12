class_name ResilienceCiDriver
extends Node
## Automated Slice 9 gate driver (debug builds; tools/verify_resilience.sh) -
## the scripted equivalent of the Chunk 12 blocking playtests: host + 2
## clients start a 1-round game; the "leaver" client submits a marked
## drawing and quits mid-DRAWING (3 -> 2 connected: below-minimum pause on
## every remaining peer), then rejoins ~2.5 s later (auto-resume with the
## frozen time restored; rejoiner sits the round out). The leaver's kept
## submission must reach reveal and win (+2 to the remembered score). Owner
## playtests remain the formal gate (workflows/testing-protocol.md).

const TIMEOUT_SEC: float = 100.0
const EXPECT_PLAYERS: int = 3
const LEAVE_DELAY_SEC: float = 0.7      # submit flushes before the disconnect
const REJOIN_DELAY_SEC: float = 2.5     # everyone sees the pause first
const JUDGE_PICK_DELAY_SEC: float = 1.0
const TIMER_RESTORE_TOLERANCE_MS: int = 2500
const MARKER_TEXT: String = "leaver mark"
const HOST_LINGER_SEC: float = 2.5
const CLIENT_LINGER_SEC: float = 1.0

var role: String = "stay"   # "host" | "stay" | "leaver"
var room_code: String = "LOCAL"

var _started: bool = false
var _finished: bool = false
var _left_once: bool = false            # leaver: its own deliberate quit
var _rejoined: bool = false
var _phase_log: Array[int] = []
var _entries: Array = []
var _results: Dictionary = {}
var _dropped_seen: int = 0
var _rejoined_seen: int = 0
var _pause_reason: int = -1
var _pause_connected: int = -1
var _pause_time_left_ms: int = -1
var _resume_seen: int = 0
var _timer_restore_delta_ms: int = -1   # stay peer: |restored - frozen|
var _spectated_after_rejoin: bool = false


func _ready() -> void:
	get_tree().create_timer(TIMEOUT_SEC).timeout.connect(_fail.bind("timeout"))
	CollectionStore.root_dir = "ci_collection_%d" % OS.get_process_id()
	# Slice 14: sandbox lifetime stats too (never bump the real profile).
	Stats.path = "ci_stats_%d.json" % OS.get_process_id()
	Stats.reset_for_test()
	EventBus.roster_updated.connect(_on_roster_updated)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.reveal_entries_received.connect(func(entries: Array) -> void:
		_entries = entries)
	EventBus.session_results_ready.connect(_on_results)
	EventBus.session_closed.connect(_on_session_closed)
	EventBus.player_dropped.connect(func(_pid: String, _dn: String) -> void:
		_dropped_seen += 1)
	EventBus.player_rejoined.connect(func(_pid: String, _dn: String) -> void:
		_rejoined_seen += 1)
	EventBus.game_paused.connect(func(reason: int, connected: int) -> void:
		_pause_reason = reason
		_pause_connected = connected)
	EventBus.game_resumed.connect(func(_phase: int, _time_left_ms: int) -> void:
		_resume_seen += 1)
	if role == "host":
		var err: Error = await Session.host_session(room_code)
		if err != OK:
			_fail("host_session error %s" % error_string(err))
			return
		# Pin every setting this flow depends on (2026-07-07 CI rule): one
		# short round, GRID reveal (fixed 5 s), no replays, fluid rejoin ON.
		var s: GameSettings = Session.settings.duplicate_settings()
		s.round_count = 1
		s.rounds_overridden = true
		s.draw_time_sec = 20.0
		s.judging_window_sec = 10.0
		s.pool_source = GameSettings.PoolSource.BUILT_IN
		s.reveal_style = GameSettings.RevealStyle.GRID
		s.replay_mode = GameSettings.ReplayMode.OFF
		s.is_public = false
		s.fluid_rejoin = true
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


func _on_phase_changed(phase: NetIds.Phase, data: Dictionary) -> void:
	_phase_log.append(int(phase))
	match phase:
		NetIds.Phase.DRAWING:
			_on_drawing.call_deferred(data)
		NetIds.Phase.PAUSED:
			if int(data.get("reason", -1)) == NetIds.PauseReason.BELOW_MINIMUM:
				_pause_time_left_ms = int(data.get("time_left_ms", -1))
		NetIds.Phase.JUDGING:
			_on_judging.call_deferred()
		_:
			pass


func _on_drawing(data: Dictionary) -> void:
	if _finished:
		return
	var client: SessionClient = _session_client()
	if client == null:
		_fail("no SessionClient at DRAWING")
		return
	match role:
		"host":
			pass   # the judge waits
		"stay":
			# The resumed DRAWING is a fresh phase entry: the pre-pause ready
			# was cleared (Slice 17 known limitation) - submit + ready again;
			# with the rejoiner sitting out, this alone ends DRAWING early.
			if _pause_time_left_ms >= 0 and data.has("deadline_ms"):
				var restored: int = int(data["deadline_ms"]) - _now_ms()
				_timer_restore_delta_ms = absi(restored - _pause_time_left_ms)
			client.request_submit_drawing({"doc": {"v": 1,
					"orientation": "landscape", "ops": [{"t": "clear"}]}})
			client.request_set_ready(true)
		"leaver":
			if _rejoined:
				# Back mid-round: spectating, never resubmitting (§9 sit-out).
				_spectated_after_rejoin = client.is_spectating_current_round()
				return
			if _left_once:
				return   # mid leave/rejoin cycle: never a second cycle
			client.request_submit_drawing({"doc": {"v": 1,
					"orientation": "landscape", "ops": [{"t": "text", "c": 4,
					"s": 1, "x": 100, "y": 100, "str": MARKER_TEXT}]}})
			_leave_and_rejoin()


func _leave_and_rejoin() -> void:
	await get_tree().create_timer(LEAVE_DELAY_SEC).timeout
	if _finished:
		return
	_left_once = true
	Session.leave()
	await get_tree().create_timer(REJOIN_DELAY_SEC).timeout
	if _finished:
		return
	_rejoined = true
	var err: Error = await Session.join_session(room_code)
	if err != OK:
		_fail("rejoin error %s" % error_string(err))


func _on_judging() -> void:
	if _finished:
		return
	var client: SessionClient = _session_client()
	if client == null:
		return
	if role == "host":
		# Judge: crown the leaver's kept submission - it must be on the grid.
		if _entries.size() != 2:
			_fail("reveal entries %d != 2 (kept submission missing?)" % _entries.size())
			return
		var marked_id: String = _find_marked_entry()
		if marked_id.is_empty():
			_fail("leaver's marked drawing missing from reveal entries")
			return
		await get_tree().create_timer(JUDGE_PICK_DELAY_SEC).timeout
		if _finished:
			return
		client.request_pick_winner(marked_id)
		client.request_set_ready(true)
	else:
		# Drawers (incl. the rejoined leaver) ready up; judge's gated ready
		# ends the window early.
		client.request_set_ready(true)


func _find_marked_entry() -> String:
	for entry: Dictionary in _entries:
		for op: Variant in (entry.get("doc", {}) as Dictionary).get("ops", []):
			if op is Dictionary and str((op as Dictionary).get("str", "")) == MARKER_TEXT:
				return str(entry.get("drawing_id", ""))
	return ""


func _on_results(results: Dictionary) -> void:
	_results = results
	_verify.call_deferred()


func _verify() -> void:
	# Wrap-up input contract (TDD 09 §6, folded into the results bundle).
	if bool(_results.get("ended_early", true)):
		_fail("ended_early true on a naturally finished game")
		return
	if int(_results.get("rounds_played", -1)) != 1 \
			or int(_results.get("rounds_planned", -1)) != 1:
		_fail("rounds_played/planned wrong: %s/%s"
				% [str(_results.get("rounds_played")), str(_results.get("rounds_planned"))])
		return
	var players: Array = _results.get("players", [])
	if players.size() != EXPECT_PLAYERS:
		_fail("players entry count %d != %d" % [players.size(), EXPECT_PLAYERS])
		return
	for entry: Variant in players:
		if not bool((entry as Dictionary).get("is_connected", false)):
			_fail("a player is still marked disconnected after the rejoin: %s"
					% str(entry))
			return
	# Scores: exactly the leaver's +2 (remembered score credited, §9).
	var scores: Dictionary = _results.get("final_scores", {})
	var winners: int = 0
	var total: int = 0
	for pid: Variant in scores:
		total += int(scores[pid])
		if int(scores[pid]) == GameConstants.WINNER_POINTS:
			winners += 1
	if winners != 1 or total != GameConstants.WINNER_POINTS:
		_fail("scores wrong (want exactly one +2): %s" % str(scores))
		return
	var rounds: Array = _results.get("rounds", [])
	if rounds.size() != 1 or not bool((rounds[0] as Dictionary).get("picked", false)):
		_fail("round record wrong: %s" % str(rounds))
		return
	if not _verify_role_specifics(rounds[0] as Dictionary):
		return
	if not _verify_phase_log():
		return
	_pass("drop -> pause -> rejoin -> resume -> kept submission won (+2)")


func _verify_role_specifics(round0: Dictionary) -> bool:
	if role == "leaver":
		var me: Roster.PlayerState = Session.local_player()
		if me == null or str(round0.get("winner_player_id", "")) != me.platform_id:
			_fail("winner is not the rejoined leaver: %s" % str(round0))
			return false
		if not _spectated_after_rejoin:
			_fail("leaver was not spectating after the mid-DRAWING rejoin")
			return false
		if _rejoined_seen < 1:
			_fail("leaver never saw its own rejoin status broadcast")
			return false
		return true
	# host + stay saw the drop, the below-minimum pause, and the resume.
	if _dropped_seen < 1 or _rejoined_seen < 1:
		_fail("drop/rejoin status events missing (%d/%d)" % [_dropped_seen, _rejoined_seen])
		return false
	if _pause_reason != NetIds.PauseReason.BELOW_MINIMUM or _pause_connected != 2:
		_fail("pause reason/count wrong (%d, %d)" % [_pause_reason, _pause_connected])
		return false
	if _resume_seen < 1:
		_fail("resume was never observed")
		return false
	if role == "stay":
		if _timer_restore_delta_ms < 0 \
				or _timer_restore_delta_ms > TIMER_RESTORE_TOLERANCE_MS:
			_fail("frozen timer not restored (delta %d ms)" % _timer_restore_delta_ms)
			return false
	return true


func _verify_phase_log() -> bool:
	var expected: Array[int]
	if role == "leaver":
		# Pre-drop: intro + drawing. Post-rejoin: the welcome replays the
		# already-resumed DRAWING (the rejoin itself ended the pause, so the
		# leaver never sees PAUSED), then the round plays out.
		expected = [NetIds.Phase.ROUND_INTRO, NetIds.Phase.DRAWING,
				NetIds.Phase.DRAWING, NetIds.Phase.REVEAL, NetIds.Phase.JUDGING,
				NetIds.Phase.RESOLUTION, NetIds.Phase.WRAP_UP]
	else:
		expected = [NetIds.Phase.ROUND_INTRO, NetIds.Phase.DRAWING,
				NetIds.Phase.PAUSED, NetIds.Phase.DRAWING, NetIds.Phase.REVEAL,
				NetIds.Phase.JUDGING, NetIds.Phase.RESOLUTION, NetIds.Phase.WRAP_UP]
	if _phase_log != expected:
		_fail("phase sequence mismatch: %s (want %s)" % [str(_phase_log), str(expected)])
		return false
	return true


func _session_client() -> SessionClient:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("SessionClient", true, false) as SessionClient


func _on_session_closed(reason: String) -> void:
	if role == "leaver" and reason == "left" and _left_once and not _rejoined:
		return   # our own deliberate quit
	_fail("session closed unexpectedly: %s" % reason)


static func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _pass(detail: String) -> void:
	if _finished:
		return
	_finished = true
	print("CI_RESILIENCE_OK [%s]: %s" % [role, detail])
	var linger: float = HOST_LINGER_SEC if role == "host" else CLIENT_LINGER_SEC
	await get_tree().create_timer(linger).timeout
	get_tree().quit(0)


func _fail(reason: String) -> void:
	if _finished:
		return
	_finished = true
	print("CI_RESILIENCE_FAIL [%s]: %s" % [role, reason])
	get_tree().quit(1)
