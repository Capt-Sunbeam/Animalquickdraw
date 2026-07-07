class_name GameSession
extends RefCounted
## Host-only round-loop state machine (Slice 3 TDD §6). Outputs are signals;
## SessionClient translates them into rpc_sync_* broadcasts and owns the
## authoritative phase timer. Never constructed on clients. Pure logic - no
## networking, no UI, no scene tree - which is what makes the whole loop
## headless-testable (injectable clock, drive via on_phase_deadline()).

signal phase_entered(phase: NetIds.Phase, data: Dictionary)
signal session_finished(results: Dictionary)
## Slice 4: a drawing's aggregate reaction counts changed (nonzero keys only).
signal reaction_counts_changed(drawing_id: String, counts: Dictionary)
## Slice 4: a drawing's public kudos total changed.
signal kudos_total_changed(drawing_id: String, total: int)
## Slice 4: a kudos was accepted; SessionClient confirms privately to the
## giver (rpc_do_kudos_confirmed) and re-syncs the roster (spent changed).
signal kudos_confirmed(player_id: String, drawing_id: String, kudos_remaining: int)
## Slice 5: a one-at-a-time reveal beat starts (SessionClient broadcasts it
## and arms the beat timer; call on_reveal_beat_deadline when it elapses).
signal reveal_beat_started(index: int, drawing_id: String, beat_secs: float)
## Slice 5: all beats done - clients gather cards into the grid; JUDGING
## opens when the gather budget elapses.
signal reveal_gather_started(gather_secs: float)
## Slice 7: pool-setup submission progress changed; SessionClient broadcasts
## it via rpc_sync_pool_setup_progress. Entries carry display_name resolved
## from the roster (§3 payload + names for the waiting panel).
signal pool_setup_progress_changed(progress: Array)
## Slice 7: an eligible sender's pool submission failed honest validation;
## SessionClient relays the reason to that peer alone. Drop-tier failures
## (unknown sender/pool, post-lock) never emit.
signal pool_words_rejected(player_id: String, pool_id: String, reason: int)

## Slice 17: the ready-up set changed (SessionClient broadcasts it).
signal ready_state_changed(ready_ids: PackedStringArray)

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
var _pending_winner_id: String = ""        # judge's latched pick; applied at deadline
var _submissions: Dictionary = {}          # player_id -> Submission (current round)
var _ready_ids: Dictionary = {}            # Slice 17: player_id -> true, per phase
var _entries: Array[Dictionary] = []       # current reveal entries (id + doc only)
var _phase_deadline_ms: int = 0            # 0 = no deadline armed (WRAP_UP)
var _last_phase_data: Dictionary = {}      # pre-deadline copy, for pause/resume
var _now_ms: Callable
var _paused_remaining_ms: int = 0
var _resume_phase: NetIds.Phase = NetIds.Phase.LOBBY

# Slice 4: host-only social state (all keyed by stable platform ids).
var _reaction_ledger: ReactionLedger = ReactionLedger.new()
var _kudos_ledger: KudosLedger = KudosLedger.new()
var _reaction_gate: ReactionGate
var _session_stats: SessionStats

# Slice 5: reveal choreography plan for the current round (host-only).
var _reveal_director: RevealDirector = null

# Slice 7: player-created pool collection (host-only, session-scoped).
var _collector: CustomPoolCollector = null
var _pool_setup_force_at_ms: int = 0   # host force-continue unlock time


func _init(settings: GameSettings, roster: Roster, now_ms: Callable = Callable()) -> void:
	_settings = settings
	_roster = roster
	_now_ms = now_ms if now_ms.is_valid() else Callable(GameSession, "_system_now_ms")
	_reaction_gate = ReactionGate.new(_now_ms)
	_session_stats = SessionStats.new(_now_ms)
	rng.randomize()


# --- Public API (SessionClient + tests) ---


func start_game() -> void:
	_judge_order = _roster.player_ids_by_joined_order()
	for pid: String in _judge_order:
		_scoring.ensure_player(pid)
	# Slice 4: kudos allotment computed once, from the settings snapshot (§6).
	# A fresh game = a fresh economy; Slice 9 handles rejoin/late-join budgets.
	var allotment: int = KudosLedger.resolve_allotment(
			_settings.kudos_allotment, _settings.round_count)
	for player: Roster.PlayerState in _roster.players_in_join_order():
		player.kudos_granted = allotment
		player.kudos_spent = 0
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
		NetIds.Phase.REVEAL:
			# Slice 5: with beats, this deadline is the failsafe margin past
			# the schedule - it fires only if the beat chain stalled.
			if _reveal_director != null and _reveal_director.has_beats() \
					and not _reveal_director.is_done():
				push_warning("GameSession: reveal beat chain stalled; failsafe -> JUDGING")
			_open_judging()
		NetIds.Phase.JUDGING:     _finish_judging(_pending_winner_id)
		NetIds.Phase.RESOLUTION:  _advance_round()
		_: push_error("GameSession: deadline fired in phase %d" % _phase)


## Slice 5: SessionClient's beat timer elapsed - advance the reveal plan.
## Stale timers (failsafe already advanced the phase) are dropped.
func on_reveal_beat_deadline() -> void:
	if _phase != NetIds.Phase.REVEAL or _reveal_director == null:
		return
	_advance_reveal()


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
	if _ready_ids.has(player_id):
		return false                                    # ready locks you in (Slice 17)
	var sub := Submission.new()
	sub.author_player_id = player_id
	sub.doc = _censor_text_ops(doc)                     # Slice 16 (§6 rules)
	sub.is_blank = false
	_submissions[player_id] = sub                       # replace = latest wins
	# Slice 17: submitting no longer ends the phase early - the ready-up set
	# does (all connected drawers ready -> collect). The deadline (blanks for
	# missing drawers) remains the guarantee.
	return true


## Judge's pick. Valid only in JUDGING, only from the current judge, only
## for a drawing_id in the current reveal set. Blanks are pickable - the
## judge may reward comedy. The pick is LATCHED, not applied: the judge may
## change it freely until the judging window lapses, and the deadline is
## what crowns the winner (owner feedback 2026-07-06 - no confirm button,
## no early phase end). An empty latch at deadline = no-pick penalty.
func pick_winner(player_id: String, drawing_id: String) -> bool:
	if _phase != NetIds.Phase.JUDGING:
		return false        # incl. late picks after RESOLUTION began
	if player_id != current_judge_id():
		return false
	if not _authors.has(drawing_id):
		return false
	if _ready_ids.has(player_id):
		return false        # ready locks the latched pick (Slice 17)
	_pending_winner_id = drawing_id
	return true


## Slice 17: shared validated ready-up entry point (RPC handler + host UI).
## DRAWING: connected drawers only, and only with a submission in (the Done
## button submits first). JUDGING: every connected participant; the judge
## only after latching a pick - a group can never ready the judge into an
## accidental no-pick -1. Ready locks you in (resubmits/re-picks dropped);
## un-ready is the escape hatch until the phase advances. When every
## participant is ready the phase advances immediately; the phase deadline
## remains the guarantee when someone never readies.
func set_ready(player_id: String, ready: bool) -> bool:
	if not _ready_participants().has(player_id):
		return false
	if ready:
		if _phase == NetIds.Phase.DRAWING and not _submissions.has(player_id):
			return false
		if _phase == NetIds.Phase.JUDGING and player_id == current_judge_id() \
				and _pending_winner_id.is_empty():
			return false
		_ready_ids[player_id] = true
	else:
		_ready_ids.erase(player_id)
	ready_state_changed.emit(ready_snapshot())
	if ready and _all_ready():
		match _phase:
			NetIds.Phase.DRAWING: _collect_and_reveal()
			NetIds.Phase.JUDGING: _finish_judging(_pending_winner_id)
	return true


func ready_snapshot() -> PackedStringArray:
	var ids := PackedStringArray()
	for pid: String in _ready_ids:
		ids.append(pid)
	return ids


## Slice 7: shared validated entry point for pool-word submissions - the RPC
## handler and the host's own UI both call this (5-step steps 3-4). Returns
## NetIds.WordRejectReason (NONE = accepted). Emits pool_words_rejected only
## for honest validation failures from eligible senders; drop-tier input
## (wrong phase, unknown sender/pool, post-lock) is silently ignored (§5).
func submit_pool_words(player_id: String, pool_id: String,
		words: PackedStringArray) -> int:
	if _phase != NetIds.Phase.POOL_SETUP or _collector == null:
		return NetIds.WordRejectReason.LOCKED   # game moved on - drop
	var result: int = _collector.submit(player_id, pool_id, words)
	if result != NetIds.WordRejectReason.NONE:
		if result != NetIds.WordRejectReason.LOCKED \
				and _collector.eligible_player_ids.has(player_id) \
				and _collector.pool_ids.has(pool_id):
			pool_words_rejected.emit(player_id, pool_id, result)
		return result
	pool_setup_progress_changed.emit(pool_setup_progress())
	if _collector.is_complete():
		_lock_pools_and_start()
	return result


## Slice 7: host force-continue - time-gated escape hatch (§10: a stuck
## waiting screen with a visible host escape beats any automatic guess).
## The is_server() guard lives in SessionClient; missing shares are NOT
## synthesized - shortfall is covered lazily by silent backfill at draw time.
func force_lock_pools() -> bool:
	if _phase != NetIds.Phase.POOL_SETUP or _collector == null:
		return false
	if int(_now_ms.call()) < _pool_setup_force_at_ms:
		return false
	_lock_pools_and_start()
	return true


## Slice 7: §3 progress payload with display names resolved from the roster.
func pool_setup_progress() -> Array:
	if _collector == null:
		return []
	var out: Array = _collector.progress()
	for entry: Dictionary in out:
		var player: Roster.PlayerState = _roster.get_by_platform_id(
				str(entry["player_id"]))
		entry["display_name"] = player.display_name if player != null else "?"
	return out


## Slice 4: reaction toggle. Shared validated entry point - the RPC handler
## and the host's own UI both call this (5-step steps 3-4; steps 1-2 live in
## SessionClient). Returns false on any invalid/no-op request (drop, never
## crash - brief §13).
func react(player_id: String, drawing_id: String, reaction_value: int, active: bool) -> bool:
	if not _reaction_gate.is_open_for(drawing_id):
		return false                                    # window closed (incl. grace, §10)
	if reaction_value < 0 or reaction_value >= NetIds.Reaction.size():
		return false                                    # not a NetIds.Reaction
	var author: String = str(_authors.get(drawing_id, ""))
	if author.is_empty() or author == player_id:
		return false                                    # unknown drawing / own drawing
	var reaction: NetIds.Reaction = reaction_value as NetIds.Reaction
	if not _reaction_ledger.set_reaction(drawing_id, reaction, player_id, active):
		return false                                    # no-op toggle or event cap - not broadcast
	_session_stats.record_reaction(_round_index, drawing_id, reaction, player_id, active)
	reaction_counts_changed.emit(drawing_id, _reaction_ledger.counts_for(drawing_id))
	return true


## Slice 4: spend one kudos on someone else's drawing. +1 to the author's
## score applies immediately host-side; the scoreboard broadcast stays
## deferred to RESOLUTION (Slice 3 contract - no score sync exists between
## phases, so anonymity holds by construction). Host processes requests in
## arrival order - host order wins the last-kudos race (§10).
func give_kudos(player_id: String, drawing_id: String) -> bool:
	if not _reaction_gate.is_open_for(drawing_id):
		return false
	var author: String = str(_authors.get(drawing_id, ""))
	if author.is_empty() or author == player_id:
		return false                                    # unknown drawing / self-kudos
	var player: Roster.PlayerState = _roster.get_by_platform_id(player_id)
	if player == null:
		return false
	if player.kudos_spent >= player.kudos_granted:
		return false                                    # budget exhausted
	if _kudos_ledger.has_given(drawing_id, player_id):
		return false                                    # one kudos per giver per drawing
	player.kudos_spent += 1
	_kudos_ledger.add_kudos(drawing_id, player_id)
	# A disconnected author still scores (§10) - the roster entry is retained
	# in-game (Slice 2/9 contract) and scoring is keyed by platform id.
	_scoring.add_points(author, GameConstants.KUDOS_POINTS)
	_session_stats.record_kudos(_round_index, drawing_id, player_id)
	kudos_total_changed.emit(drawing_id, _kudos_ledger.total_for(drawing_id))
	kudos_confirmed.emit(player_id, drawing_id, player.kudos_granted - player.kudos_spent)
	return true


## Slice 4/10: host-side stats surface (Slice 10 mines superlatives here).
func session_stats() -> SessionStats:
	return _session_stats


## Slice 6 (host Esc menu) + Slice 9 (below-minimum): freezes the phase
## clock and broadcasts PAUSED; resume() re-enters the stored phase with
## the remaining time. Deliberately NOT via _enter_phase - that would
## clobber _last_phase_data, which resume needs intact.
func pause(_reason: int) -> void:
	if _phase == NetIds.Phase.PAUSED or _phase_deadline_ms == 0:
		return
	_resume_phase = _phase
	_paused_remaining_ms = maxi(0, _phase_deadline_ms - int(_now_ms.call()))
	_phase = NetIds.Phase.PAUSED
	phase_entered.emit(NetIds.Phase.PAUSED, {"resume_phase": int(_resume_phase)})


func resume() -> void:
	if _phase != NetIds.Phase.PAUSED:
		return
	# Re-enter the stored phase with a fresh deadline for the remaining time.
	_enter_phase(_resume_phase, _paused_remaining_ms / 1000.0, _last_phase_data.duplicate(true))


# --- Internal transitions (host timer / early triggers) ---


## Slice 7: enters the word-submission phase. NO deadline timer is armed -
## the phase ends by completion or host force-continue, never by clock.
func _enter_pool_setup() -> void:
	pool_setup_entered = true
	_collector = CustomPoolCollector.new()
	_collector.share_per_player = CustomPoolCollector.compute_share(
			_settings.round_count, _judge_order.size())
	var ids := PackedStringArray()
	for d: Dictionary in _pool_type.draws:
		var pool_id: String = str(d["pool"])
		if not ids.has(pool_id):
			ids.append(pool_id)   # derived from PoolType.draws - future types free
	_collector.pool_ids = ids
	# Roster snapshot at Start: late joiners are never added (§8 pool lock).
	_collector.eligible_player_ids = PackedStringArray(_judge_order)
	_pool_setup_force_at_ms = int(_now_ms.call()) \
			+ int(GameConstants.POOL_SETUP_FORCE_AVAILABLE_SEC * 1000.0)
	var display_names: Dictionary = {}
	for pool_id: String in ids:
		display_names[pool_id] = pool_id.capitalize()
	_enter_phase(NetIds.Phase.POOL_SETUP, 0.0, {
		"share_per_player": _collector.share_per_player,
		"pool_ids": ids,
		"pool_display_names": display_names,
		"force_available_at_ms": _pool_setup_force_at_ms,
	})


## Slice 7: hands the collected words to PromptPools and starts round 0.
## Idempotent under the final-submission/force-continue race (§10): locking
## is checked-and-set once; the loser of the race finds locked == true.
func _lock_pools_and_start() -> void:
	if _collector == null or _collector.locked:
		return
	_collector.locked = true
	for pool_id: String in _collector.pool_ids:
		_pools.set_custom_source(pool_id, _collector.collected_words(pool_id))
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
		# Slice 4: stats registration (blanks included - they are reactable).
		_session_stats.register_drawing(sub.drawing_id, _round_index, pid,
				_round.prompt.display_text if _round.prompt != null else "")
	_shuffle_entries()
	# Slice 5: reveal choreography. GRID keeps Slice 3's fixed-length look
	# beat; ONE_AT_A_TIME sizes the phase to the beat schedule (+ failsafe -
	# the main deadline only fires if the beat chain stalls).
	_reveal_director = RevealDirector.new(_settings.reveal_style, _entries,
			_settings, _drawers_this_round().size())
	var reveal_data: Dictionary = {
		"entries": _entries.duplicate(),
		"reveal_style": int(_settings.reveal_style),
	}
	if _reveal_director.has_beats():
		_enter_phase(NetIds.Phase.REVEAL,
				_reveal_director.total_secs() + GameConstants.REVEAL_BEAT_FAILSAFE_SECS,
				reveal_data)
		_advance_reveal()   # first beat (after the phase broadcast - ordered)
	else:
		_enter_phase(NetIds.Phase.REVEAL, GameConstants.REVEAL_GRID_SEC, reveal_data)


## Slice 5: performs the director's next step. Beats open the gate for the
## staged drawing only (the previous drawing keeps Slice 4's close grace);
## the gather closes it; JUDGING then reopens for the whole set.
func _advance_reveal() -> void:
	var action: Dictionary = _reveal_director.next_action()
	if action.has("beat"):
		var beat: Dictionary = action["beat"]
		_reaction_gate.close()
		_reaction_gate.open_for(PackedStringArray([str(beat["drawing_id"])]))
		reveal_beat_started.emit(int(beat["index"]), str(beat["drawing_id"]),
				float(beat["secs"]))
	elif action.has("gather"):
		_reaction_gate.close()
		reveal_gather_started.emit(float(action["gather"]))
	else:
		_open_judging()


## In-image text moderation (Slice 16 §6): every TEXT op's content is
## host-censored, then re-truncated (censoring can lengthen). The censored
## dict is what gets stored and broadcast; the canvas applies the same censor
## at commit, so honest clients never see a difference. Censored text is
## funnier than a rejected drawing - never rejected (chat/caption precedent).
func _censor_text_ops(doc: Dictionary) -> Dictionary:
	var raw_ops: Variant = doc.get("ops")
	if not raw_ops is Array:
		return doc
	var needs_censor: bool = false
	for op: Variant in raw_ops:
		if op is Dictionary and str(op.get("t", "")) == "text" \
				and not TextFilter.is_clean(str(op.get("str", ""))):
			needs_censor = true
			break
	if not needs_censor:
		return doc
	var out: Dictionary = doc.duplicate(true)
	for op: Variant in out["ops"]:
		if op is Dictionary and str(op.get("t", "")) == "text":
			op["str"] = TextFilter.censor(str(op.get("str", ""))) \
					.left(GameConstants.TEXT_MAX_CHARS)
	return out


func _open_judging() -> void:
	_pending_winner_id = ""   # fresh latch; a stale pick must never carry over
	# Slice 4: the whole reveal set accepts reactions/kudos during JUDGING
	# (Slice 5 additionally opens per-drawing beats during REVEAL).
	var ids := PackedStringArray()
	for entry: Dictionary in _entries:
		ids.append(str(entry["drawing_id"]))
	_reaction_gate.open_all(ids)
	# Slice 6: the window is a host-tunable setting (was a Slice 3 constant).
	_enter_phase(NetIds.Phase.JUDGING, _settings.judging_window_sec, {})


## Empty id = window lapsed -> judge -1 (§11), picked=false. Otherwise the
## author is resolved from the private map - the only moment authorship is
## revealed, and only for the winner.
func _finish_judging(winner_drawing_id: String) -> void:
	_reaction_gate.close()   # Slice 4: grace window absorbs racing requests (§10)
	var data: Dictionary = {"picked": false, "winner_drawing_id": "",
			"winner_player_id": "", "winner_display_name": ""}
	if winner_drawing_id.is_empty():
		_scoring.apply_no_pick_penalty(current_judge_id())
	else:
		var author: String = str(_authors[winner_drawing_id])
		_scoring.apply_winner(author)
		_session_stats.record_winner(winner_drawing_id)
		_round.winner_drawing_id = winner_drawing_id
		_round.winner_player_id = author
		data["picked"] = true
		data["winner_drawing_id"] = winner_drawing_id
		data["winner_player_id"] = author
		var player: Roster.PlayerState = _roster.get_by_platform_id(author)
		data["winner_display_name"] = player.display_name if player != null else ""
	data["scores"] = _scoring.snapshot()
	# Slice 5 (owner feedback 2026-07-06): the victory lap must show EVERY
	# stroke and then hold the finished still - size the phase to fit.
	var duration: float = GameConstants.RESOLUTION_SEC
	if bool(data["picked"]) and _settings.replay_mode != GameSettings.ReplayMode.OFF:
		var winner_doc: Dictionary = {}
		for entry: Dictionary in _entries:
			if str(entry["drawing_id"]) == winner_drawing_id:
				winner_doc = entry["doc"]
		var replay: float = ReplayPlanner.replay_secs(winner_doc,
				ReplayPlanner.winner_timescale(winner_doc, _settings.winner_replay_secs))
		duration = maxf(duration,
				replay + GameConstants.REPLAY_STILL_HOLD_SECS + 1.0)
	_enter_phase(NetIds.Phase.RESOLUTION, duration, data)


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
		# Slice 4 aggregates (uid-keyed). Slice 10 mines the full SessionStats
		# host-side; these bundle keys carry the shareable rollups to all
		# peers. Readers must tolerate unknown keys.
		"reaction_stats": {
			"totals_by_author": _session_stats.reaction_totals_by_author(),
		},
		"kudos_stats": {
			"received_by_author": _session_stats.kudos_received_by_author(),
			"drawing_totals": _kudos_ledger.totals(),
		},
	}


# --- Helpers ---


func _enter_phase(phase: NetIds.Phase, duration_sec: float, data: Dictionary) -> void:
	_phase = phase
	_ready_ids.clear()   # Slice 17: ready-up never carries across phases
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


## Slice 17: who must ready for the current phase to advance early -
## connected drawers during DRAWING (the judge has nothing to finish);
## connected drawers + judge during JUDGING. Other phases have no ready-up.
## Disconnected players never block (roster keeps their entry; Slice 9 owns
## richer departure semantics).
func _ready_participants() -> Array[String]:
	match _phase:
		NetIds.Phase.DRAWING:
			return _connected_of(_drawers_this_round())
		NetIds.Phase.JUDGING:
			var all: Array[String] = _drawers_this_round()
			all.append(current_judge_id())
			return _connected_of(all)
		_:
			return []


func _connected_of(ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for pid: String in ids:
		var p: Roster.PlayerState = _roster.get_by_platform_id(pid)
		if p != null and p.is_connected:
			out.append(pid)
	return out


func _all_ready() -> bool:
	var participants: Array[String] = _ready_participants()
	if participants.is_empty():
		return false
	for pid: String in participants:
		if not _ready_ids.has(pid):
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
