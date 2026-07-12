extends Control
## The end-game wrap-up sequence (Slice 10 TDD §5/§7, reworked by Slice 19):
## title cards -> final standings, played locally at each peer's own pace
## with a per-peer Skip. Everything renders from the host-computed bundle in
## results["wrap_up"] - no further host coordination after the broadcast
## (the Slice 19 skip VOTE being the one deliberate exception), so the
## sequence even survives a host disconnect (Session holds the host-quit
## navigation until the show ends, then this screen degrades to Leave-only).
## Slice 19: superlatives retired; the ceremony act only plays when
## settings.title_ceremony is on (badges on the standings show regardless);
## a majority "Skip ceremony" vote jumps every peer to standings.

const TITLE_CARD: PackedScene = preload("res://ui/wrapup/title_card.tscn")
const STANDINGS_PANEL: PackedScene = preload("res://ui/wrapup/standings_panel.tscn")

var _client: SessionClient = null
var _bundle: Dictionary = {}
var _plan: Array[Dictionary] = []        # [{"kind": "title"|"standings", "entry": {}}]
var _plan_index: int = -1
var _card: Control = null
var _player_names: Dictionary = {}       # platform_id -> {"name": String, "connected": bool}
var _done: bool = false
var _voted_skip: bool = false
var _card_timer: Timer = null

@onready var _stage: CenterContainer = %Stage
@onready var _rounds_badge: Label = %RoundsBadge
@onready var _progress_label: Label = %ProgressLabel
@onready var _skip_button: Button = %SkipButton
@onready var _skip_ceremony_button: Button = %SkipCeremonyButton
@onready var _post_game: HBoxContainer = %PostGame
@onready var _back_button: Button = %BackButton
@onready var _leave_button: Button = %LeaveButton
@onready var _waiting_label: Label = %WaitingLabel


func _ready() -> void:
	_card_timer = Timer.new()
	_card_timer.one_shot = true
	_card_timer.timeout.connect(_next_card)
	add_child(_card_timer)
	_skip_button.pressed.connect(_on_skip_pressed)
	_skip_ceremony_button.pressed.connect(_on_skip_ceremony_pressed)
	EventBus.ceremony_skip_updated.connect(_on_ceremony_skip_updated)
	_back_button.pressed.connect(Session.return_to_lobby)
	_leave_button.pressed.connect(Session.leave)
	_post_game.visible = false
	# The show must go on without the host (TDD §10) - hold the host-quit
	# navigation while the local sequence plays.
	Session.hold_host_quit(true)
	tree_exiting.connect(func() -> void: Session.hold_host_quit(false))


func setup(data: Dictionary, client: SessionClient) -> void:
	_client = client
	var results: Dictionary = data.get("results", {})
	var raw: Variant = results.get("wrap_up")
	_bundle = raw if SessionClient.is_valid_wrap_up_bundle(raw) else _fallback_bundle(results)
	for entry: Variant in _bundle.get("standings", []):
		if entry is Dictionary:
			_player_names[str((entry as Dictionary).get("player_id", ""))] = {
				"name": str((entry as Dictionary).get("display_name", "?")),
				"connected": bool((entry as Dictionary).get("connected", true)),
			}
	var rounds: int = int(_bundle.get("rounds_completed", 0))
	_rounds_badge.text = ("ended early • %d %s" if bool(_bundle.get("early_end", false)) \
			else "%d %s") % [rounds, "round" if rounds == 1 else "rounds"]
	# Slice 19: the awards ceremony is a setting; badges-only games go
	# straight to standings. Frozen-snapshot read (cg reality note).
	if Session.game_settings.title_ceremony:
		for entry: Variant in _bundle.get("titles", []):
			if entry is Dictionary:
				_plan.append({"kind": "title", "entry": entry})
	_plan.append({"kind": "standings", "entry": {}})
	_skip_ceremony_button.visible = _plan.size() > 1
	_next_card()


func chat_prominence() -> ChatPanel.Prominence:
	return ChatPanel.Prominence.NORMAL


## Space advances too (never steals focused-control input - unhandled only).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not _done:
		_on_skip_pressed()
		get_viewport().set_input_as_handled()


## Skip semantics (TDD §5): first press completes the current card's
## animation instantly; a press on a settled card advances.
func _on_skip_pressed() -> void:
	if _done or _card == null:
		return
	if _card.has_method("is_animating") and _card.is_animating():
		_card.finish_now()   # standings: triggers finished -> sequence end
		return
	if _plan_index < _plan.size() - 1:
		_next_card()


func _next_card() -> void:
	_card_timer.stop()
	_plan_index += 1
	if _plan_index >= _plan.size():
		return   # standings act ends via its finished signal, not the timer
	if _card != null:
		_card.queue_free()
		_card = null
	var item: Dictionary = _plan[_plan_index]
	var entry: Dictionary = item["entry"]
	match str(item["kind"]):
		"title":
			var card: TitleCard = TITLE_CARD.instantiate()
			_stage.add_child(card)
			var evidence: Array[Dictionary] = []
			for id: Variant in entry.get("evidence_drawing_ids", []):
				var drawing: Dictionary = _drawing_for(str(id))
				if not drawing.is_empty():
					evidence.append(drawing)
			var pid: String = str(entry.get("player_id", ""))
			card.present(entry, _name_of(pid), _connected(pid), evidence)
			_card = card
			_card_timer.start(maxf(0.1, card.display_secs()))
		"standings":
			_skip_ceremony_button.visible = false   # Slice 19: vote is moot now
			var panel: StandingsPanel = STANDINGS_PANEL.instantiate()
			_stage.add_child(panel)
			panel.finished.connect(_on_sequence_finished)
			panel.present(_bundle.get("standings", []), _titles_by_player())
			_card = panel
	_progress_label.text = _progress_dots()


# --- Slice 19: ceremony skip vote ---


## Voting also jumps YOUR view straight to standings (a voter wants out
## now); the broadcast moves everyone else when the majority lands.
func _on_skip_ceremony_pressed() -> void:
	if _done or _voted_skip:
		return
	_voted_skip = true
	_skip_ceremony_button.disabled = true
	if _client != null:
		_client.request_skip_ceremony()
	_jump_to_standings()


func _on_ceremony_skip_updated(votes: int, needed: int, skipped: bool) -> void:
	if skipped:
		_jump_to_standings()
	elif _skip_ceremony_button.visible:
		_skip_ceremony_button.text = "Skip ceremony (%d/%d)" % [votes, needed]


func _jump_to_standings() -> void:
	if _done or _plan_index >= _plan.size() - 1:
		return   # already at (or past) the standings act
	_plan_index = _plan.size() - 2   # _next_card advances onto standings
	_next_card()


## platform_id -> Array[String] of title DISPLAY names, for standings badges.
func _titles_by_player() -> Dictionary:
	var out: Dictionary = {}
	for entry: Variant in _bundle.get("titles", []):
		if entry is Dictionary:
			var pid: String = str((entry as Dictionary).get("player_id", ""))
			(out.get_or_add(pid, []) as Array).append(
					TitleIds.display_name(str((entry as Dictionary).get("id", ""))))
	return out


func _on_sequence_finished() -> void:
	if _done:
		return
	_done = true
	_skip_button.visible = false
	EventBus.wrap_up_sequence_finished.emit()
	# Post-game controls (Slice 3's reused as-is). A host quit during the
	# sequence degrades the options to Leave-only (TDD §10) - the hold stays
	# so the player exits on their own terms.
	_post_game.visible = true
	var host_gone: bool = Session.host_quit_pending()
	_back_button.visible = Session.is_host()
	_leave_button.visible = not Session.is_host() and host_gone
	_waiting_label.visible = not Session.is_host() and not host_gone
	if not host_gone:
		Session.hold_host_quit(false)


func _progress_dots() -> String:
	var dots: PackedStringArray = PackedStringArray()
	for i: int in _plan.size():
		dots.append("●" if i <= _plan_index else "○")
	return " ".join(dots)


## Bundle drawings entry ({"doc", "prompt"}) for an id; {} if absent.
func _drawing_for(drawing_id: String) -> Dictionary:
	var raw: Variant = (_bundle.get("drawings", {}) as Dictionary).get(drawing_id)
	return raw if raw is Dictionary else {}


func _name_of(player_id: String) -> String:
	return str((_player_names.get(player_id, {}) as Dictionary).get("name", "?"))


func _connected(player_id: String) -> bool:
	return bool((_player_names.get(player_id, {}) as Dictionary).get("connected", true))


## No valid wrap-up bundle (older host / malformed wire data): degrade to a
## standings-only sequence built from the base results keys - never a blank
## end screen.
func _fallback_bundle(results: Dictionary) -> Dictionary:
	var names: Dictionary = {}
	var connected: Dictionary = {}
	for raw: Variant in results.get("players", []):
		if raw is Dictionary:
			var p: Dictionary = raw
			names[str(p.get("platform_id", ""))] = str(p.get("display_name", "?"))
			connected[str(p.get("platform_id", ""))] = bool(p.get("is_connected", true))
	var standings: Array[Dictionary] = []
	for raw: Variant in results.get("standings", []):
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var pid: String = str(entry.get("player_id", ""))
		standings.append({
			"player_id": pid,
			"display_name": str(names.get(pid, pid)),
			"rank": int(entry.get("rank", 0)),
			"base_score": int(entry.get("score", 0)),
			"title_points": 0,
			"final_score": int(entry.get("score", 0)),
			"connected": bool(connected.get(pid, true)),
		})
	return {
		"v": WrapUpCalculator.BUNDLE_VERSION,
		"early_end": bool(results.get("ended_early", false)),
		"rounds_completed": int(results.get("rounds_played", 0)),
		"titles": [], "standings": standings,
		"kudos": {}, "drawings": {},
	}
