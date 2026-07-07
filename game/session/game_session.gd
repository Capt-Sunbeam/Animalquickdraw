class_name GameSession
extends RefCounted
## Host-only round-loop state machine (Slice 3 TDD §6). Outputs are signals;
## SessionClient translates them into rpc_sync_* broadcasts and owns the
## authoritative phase timer. Never constructed on clients. Pure logic - no
## networking, no UI, no scene tree - which is what makes the whole loop
## headless-testable (injectable clock, drive via on_phase_deadline()).

signal phase_entered(phase: NetIds.Phase, data: Dictionary)
signal session_finished(results: Dictionary)

## Public so tests can seed deterministic shuffles/draws.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Test-observable POOL_SETUP hook flag (branch is inert until Slice 7).
var pool_setup_entered: bool = false

var _phase: NetIds.Phase = NetIds.Phase.LOBBY
var _settings: GameSettings
var _roster: Roster
var _scoring: Scoring = Scoring.new()
var _pools: PromptPools = PromptPools.new()
var _pool_type: PoolType = null
var _judge_order: Array[String] = []       # player_ids, fixed at start
var _round_index: int = -1
var _round: RoundRecord = null
var _records: Array[RoundRecord] = []
var _authors: Dictionary = {}              # drawing_id -> player_id (PRIVATE)
var _submissions: Dictionary = {}          # player_id -> Submission (current round)
var _entries: Array[Dictionary] = []       # current reveal entries (id + doc only)
var _phase_deadline_ms: int = 0            # 0 = no deadline armed (WRAP_UP)
var _last_phase_data: Dictionary = {}      # pre-deadline copy, for pause/resume
var _now_ms: Callable
var _paused_remaining_ms: int = 0
var _resume_phase: NetIds.Phase = NetIds.Phase.LOBBY


func _init(settings: GameSettings, roster: Roster, now_ms: Callable = Callable()) -> void:
	_settings = settings
	_roster = roster
	_now_ms = now_ms if now_ms.is_valid() else Callable(GameSession, "_system_now_ms")
	rng.randomize()


# --- Public API (SessionClient + tests) ---


func start_game() -> void:
	_judge_order = _roster.player_ids_by_joined_order()
	for pid: String in _judge_order:
		_scoring.ensure_player(pid)
	if not _pools.is_ready():
		_pools.load_builtin()
	_pool_type = _pools.get_type(_settings.pool_type_id)
	if _settings.pool_source == GameSettings.PoolSource.PLAYER_CREATED:
		_enter_pool_setup()   # Slice 7 fills this in
	else:
		_begin_round(0)


func get_phase() -> NetIds.Phase:
	return _phase


func get_deadline_ms() -> int:
	return _phase_deadline_ms


func current_judge_id() -> String:
	if _judge_order.is_empty() or _round_index < 0:
		return ""
	return _judge_order[_round_index % _judge_order.size()]


func scores() -> Dictionary:
	return _scoring.snapshot()


## Test seam: swap the content source before start_game.
func use_pools(pools: PromptPools) -> void:
	_pools = pools


## Called by SessionClient's host-side Timer; tests call it directly. The
## DRAWING timer is armed at deadline + SUBMIT_GRACE_MS (acceptance window).
func on_phase_deadline() -> void:
	match _phase:
		NetIds.Phase.ROUND_INTRO: _start_drawing()
		NetIds.Phase.DRAWING:     _collect_and_reveal()
		NetIds.Phase.REVEAL:      _open_judging()
		NetIds.Phase.JUDGING:     _finish_judging("")   # window lapsed, no pick
		NetIds.Phase.RESOLUTION:  _advance_round()
		_: push_error("GameSession: deadline fired in phase %d" % _phase)


## Shared validated entry point for drawer submissions - the RPC handler and
## the host's own UI both call this (5-step steps 3-4). Latest valid
## submission per player replaces any earlier one (early-submit then
## keep-drawing is legal; the resubmission wins).
func submit_drawing(player_id: String, payload: Dictionary) -> bool:
	if _phase != NetIds.Phase.DRAWING:
		return false
	if int(_now_ms.call()) > _phase_deadline_ms + GameConstants.SUBMIT_GRACE_MS:
		return false                                    # after grace - drop
	if not _is_drawer_this_round(player_id):
		return false                                    # judge/stranger - drop
	var doc: Variant = payload.get("doc")
	if not doc is Dictionary:
		return false
	if var_to_bytes(doc).size() > GameConstants.MAX_DRAWING_BYTES:
		return false                                    # oversized - drop
	if DrawingDoc.from_dict(doc) == null:
		return false                                    # malformed - drop
	var sub := Submission.new()
	sub.author_player_id = player_id
	sub.doc = doc
	sub.is_blank = false
	_submissions[player_id] = sub                       # replace = latest wins
	if _all_drawers_submitted():
		_collect_and_reveal()                           # flow over waiting (§1)
	return true


## Judge's pick. Valid only in JUDGING, only from the current judge, only
## for a drawing_id in the current reveal set. Blanks are pickable - the
## judge may reward comedy.
func pick_winner(player_id: String, drawing_id: String) -> bool:
	if _phase != NetIds.Phase.JUDGING:
		return false        # incl. duplicate/late picks after RESOLUTION began
	if player_id != current_judge_id():
		return false
	if not _authors.has(drawing_id):
		return false
	_finish_judging(drawing_id)
	return true


## Slice 9 hooks: deadline bookkeeping only - nothing calls these yet.
func pause(_reason: int) -> void:
	if _phase == NetIds.Phase.PAUSED or _phase_deadline_ms == 0:
		return
	_resume_phase = _phase
	_paused_remaining_ms = maxi(0, _phase_deadline_ms - int(_now_ms.call()))
	_phase = NetIds.Phase.PAUSED


func resume() -> void:
	if _phase != NetIds.Phase.PAUSED:
		return
	# Re-enter the stored phase with a fresh deadline for the remaining time.
	_enter_phase(_resume_phase, _paused_remaining_ms / 1000.0, _last_phase_data.duplicate(true))


# --- Internal transitions (host timer / early triggers) ---


func _enter_pool_setup() -> void:
	# Slice 7 replaces this body with the word-submission phase; the hook
	# exists now so the branch point is stable.
	pool_setup_entered = true
	_begin_round(0)


func _begin_round(index: int) -> void:
	_round_index = index
	_submissions.clear()
	_authors.clear()
	_entries.clear()
	_round = RoundRecord.new()
	_round.round_index = index
	_round.judge_player_id = current_judge_id()
	_enter_phase(NetIds.Phase.ROUND_INTRO, GameConstants.ROUND_INTRO_SEC, {
		"round_index": index,
		"round_count": _settings.round_count,
		"judge_player_id": _round.judge_player_id,
	})


func _start_drawing() -> void:
	var prompt: Prompt = _pools.draw_prompt(_pool_type)
	_round.prompt = prompt
	_enter_phase(NetIds.Phase.DRAWING, _settings.draw_time_sec, {
		"prompt_text": prompt.display_text,
		"prompt_parts": prompt.parts,
	})


## Ends DRAWING: blanks for missing drawers (still judgeable - §4), private
## author map, host-RNG shuffle, REVEAL broadcast with anonymized entries.
func _collect_and_reveal() -> void:
	for pid: String in _drawers_this_round():
		if not _submissions.has(pid):
			var blank := Submission.new()
			blank.author_player_id = pid
			blank.doc = Submission.blank_doc()
			blank.is_blank = true
			_submissions[pid] = blank
	_entries.clear()
	_round.submissions.clear()
	for pid: String in _drawers_this_round():
		var sub: Submission = _submissions[pid]
		sub.drawing_id = UuidV4.generate()
		_authors[sub.drawing_id] = pid
		_round.submissions.append(sub)
		_entries.append({"drawing_id": sub.drawing_id, "doc": sub.doc})
	_shuffle_entries()
	_enter_phase(NetIds.Phase.REVEAL, GameConstants.REVEAL_GRID_SEC, {
		"entries": _entries.duplicate(),
	})


func _open_judging() -> void:
	_enter_phase(NetIds.Phase.JUDGING, GameConstants.JUDGING_WINDOW_SEC, {})


## Empty id = window lapsed -> judge -1 (§11), picked=false. Otherwise the
## author is resolved from the private map - the only moment authorship is
## revealed, and only for the winner.
func _finish_judging(winner_drawing_id: String) -> void:
	var data: Dictionary = {"picked": false, "winner_drawing_id": "",
			"winner_player_id": "", "winner_display_name": ""}
	if winner_drawing_id.is_empty():
		_scoring.apply_no_pick_penalty(current_judge_id())
	else:
		var author: String = str(_authors[winner_drawing_id])
		_scoring.apply_winner(author)
		_round.winner_drawing_id = winner_drawing_id
		_round.winner_player_id = author
		data["picked"] = true
		data["winner_drawing_id"] = winner_drawing_id
		data["winner_player_id"] = author
		var player: Roster.PlayerState = _roster.get_by_platform_id(author)
		data["winner_display_name"] = player.display_name if player != null else ""
	data["scores"] = _scoring.snapshot()
	_enter_phase(NetIds.Phase.RESOLUTION, GameConstants.RESOLUTION_SEC, data)


func _advance_round() -> void:
	_records.append(_round)
	if _round_index + 1 < _settings.round_count:
		_begin_round(_round_index + 1)
	else:
		var results: Dictionary = _build_results()
		_enter_phase(NetIds.Phase.WRAP_UP, 0.0, {"results": results})
		session_finished.emit(results)


## SessionResults bundle (§2) - Slices 4/10 extend it; unknown keys must be
## tolerated by all readers. reaction_stats/kudos_stats reserved for Slice 4.
func _build_results() -> Dictionary:
	var rounds: Array[Dictionary] = []
	for record: RoundRecord in _records:
		rounds.append(record.to_result_dict())
	return {
		"v": 1,
		"rounds": rounds,
		"final_scores": _scoring.snapshot(),
		"standings": Scoring.standings(_scoring.snapshot(), _judge_order),
		"reaction_stats": {},
		"kudos_stats": {},
	}


# --- Helpers ---


func _enter_phase(phase: NetIds.Phase, duration_sec: float, data: Dictionary) -> void:
	_phase = phase
	_last_phase_data = data.duplicate(true)
	if duration_sec > 0.0:
		_phase_deadline_ms = int(_now_ms.call()) + int(duration_sec * 1000.0)
		data["deadline_ms"] = _phase_deadline_ms
	else:
		_phase_deadline_ms = 0   # terminal/no-timer phase (WRAP_UP)
	phase_entered.emit(phase, data)


func _drawers_this_round() -> Array[String]:
	var drawers: Array[String] = []
	var judge: String = current_judge_id()
	for pid: String in _judge_order:
		if pid != judge:
			drawers.append(pid)
	return drawers


func _is_drawer_this_round(player_id: String) -> bool:
	return _judge_order.has(player_id) and player_id != current_judge_id()


func _all_drawers_submitted() -> bool:
	for pid: String in _drawers_this_round():
		if not _submissions.has(pid):
			return false
	return true


## Fisher-Yates on the session RNG (Array.shuffle would use the global RNG,
## which tests cannot seed).
func _shuffle_entries() -> void:
	for i: int in range(_entries.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = _entries[i]
		_entries[i] = _entries[j]
		_entries[j] = tmp


static func _system_now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
