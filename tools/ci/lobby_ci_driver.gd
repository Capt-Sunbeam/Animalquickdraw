class_name LobbyCiDriver
extends Node
## Automated Slice 2 gate driver (debug builds; tools/verify_lobby.sh).
## Added to the SceneTree root by the menu's CI hooks so it survives the
## menu -> lobby navigation. The scripted equivalent of the Chunk 4 blocking
## playtests: 3-instance roster sync, chat filtering, start gate broadcast,
## and join-failure recovery. Owner playtests remain the formal gate.

const TIMEOUT_SEC: float = 30.0
## Blocklisted probe word (data/blocklist.txt): must arrive censored.
const CHAT_PROBE: String = "hello shit"
const CHAT_PROBE_CENSORED: String = "hello ***"
## Host lingers longer than clients so final reliable broadcasts flush
## before the server process exits (same ENet quirk as verify_connect.sh).
const HOST_LINGER_SEC: float = 2.5
const CLIENT_LINGER_SEC: float = 1.0

var role: String = "join"  # "host" | "join" | "join_fail"
var room_code: String = "LOCAL"
var expect_players: int = 3

var _saw_full_roster: bool = false
var _saw_censored_chat: bool = false
var _saw_game_started: bool = false
var _started: bool = false
var _finished: bool = false


func _ready() -> void:
	get_tree().create_timer(TIMEOUT_SEC).timeout.connect(_fail.bind("timeout"))
	EventBus.roster_updated.connect(_on_roster_updated)
	EventBus.chat_message_received.connect(_on_chat_message)
	EventBus.game_started.connect(_on_game_started)
	EventBus.session_closed.connect(_on_session_closed)
	match role:
		"host":
			var err: Error = await Session.host_session(room_code)
			if err != OK:
				_fail("host_session error %s" % error_string(err))
		"join", "join_fail":
			var err: Error = await Session.join_session(room_code)
			if err != OK and role != "join_fail":
				_fail("join_session error %s" % error_string(err))


func _on_roster_updated(players: Array) -> void:
	if players.size() >= expect_players:
		_saw_full_roster = true
		if role == "host" and not _started:
			_started = true
			# Order matters: the chat probe must land before the start
			# broadcast freezes the lobby on the clients.
			Session.submit_chat(CHAT_PROBE)
			Session.start_game()
	_check_done()


func _on_chat_message(_sender_peer_id: int, _sender_name: String, text: String) -> void:
	if text == CHAT_PROBE_CENSORED:
		_saw_censored_chat = true
	elif text == CHAT_PROBE:
		_fail("chat probe arrived UNCENSORED")
	_check_done()


func _on_game_started(start_data: Dictionary) -> void:
	var settings: Dictionary = start_data.get("settings", {})
	var roster: Array = start_data.get("roster", [])
	if roster.size() != expect_players:
		_fail("start roster size %d != %d" % [roster.size(), expect_players])
		return
	# Suggested rounds for N players = 2N (nobody overrode the spinner).
	var expected_rounds: int = expect_players * GameConstants.SUGGESTED_ROUNDS_PER_PLAYER
	if int(settings.get("round_count", -1)) != expected_rounds:
		_fail("start round_count %s != %d" % [str(settings.get("round_count")), expected_rounds])
		return
	_saw_game_started = true
	_check_done()


func _on_session_closed(reason: String) -> void:
	# join_fail expects exactly this: a bad code must recover to the menu.
	if role == "join_fail" and (reason == "connection_failed" or reason == "timeout"):
		_pass("join failed cleanly with '%s'" % reason)
	elif role != "join_fail":
		_fail("session closed unexpectedly: %s" % reason)


func _check_done() -> void:
	if role == "join_fail":
		return
	if _saw_full_roster and _saw_censored_chat and _saw_game_started:
		_pass("roster=%d chat=censored start=received" % expect_players)


func _pass(detail: String) -> void:
	if _finished:
		return
	_finished = true
	print("CI_LOBBY_OK [%s]: %s" % [role, detail])
	var linger: float = HOST_LINGER_SEC if role == "host" else CLIENT_LINGER_SEC
	await get_tree().create_timer(linger).timeout
	get_tree().quit(0)


func _fail(reason: String) -> void:
	if _finished:
		return
	_finished = true
	print("CI_LOBBY_FAIL [%s]: %s" % [role, reason])
	get_tree().quit(1)
