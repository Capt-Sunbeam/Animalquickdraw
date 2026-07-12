class_name TestWrapUpCalculator
extends GdUnitTestSuite
## Slice 10 (TDD §11) reworked by Slice 19: the title set with stacking /
## minimums / tie-breaks / evidence, standings with title points, bundle
## embedding, titles_enabled gating, and determinism. Pure static math over
## the shipped RoundRecord/SessionStats structures - no session, no network.
## (Superlatives and every reaction-based input retired with the emoji
## system - see TDD 19 + decision log 2026-07-12.)

const ROTATION: Array[String] = ["p0", "p1", "p2", "p3"]
const DRAW_TIME: float = 30.0


# --- builders ---


func _doc(op_count: int, last_ts: float = 0.0) -> Dictionary:
	var ops: Array = []
	for i: int in range(op_count):
		ops.append({"t": "clear"})
	if last_ts > 0.0:
		ops.append({"t": "stroke", "c": 0, "s": 0,
				"pts": [0.0, 0.0, 10.0, 10.0], "ts": [0.0, last_ts]})
	return {"v": 1, "orientation": "landscape", "ops": ops}


func _sub(id: String, author: String, doc: Dictionary, blank: bool = false) -> Submission:
	var sub := Submission.new()
	sub.drawing_id = id
	sub.author_player_id = author
	sub.doc = doc
	sub.is_blank = blank
	return sub


func _record(index: int, subs: Array[Submission], winner_id: String = "",
		prompt_text: String = "prompt") -> RoundRecord:
	var record := RoundRecord.new()
	record.round_index = index
	record.judge_player_id = "judge"
	var prompt := Prompt.new()
	prompt.display_text = prompt_text
	record.prompt = prompt
	record.submissions = subs
	for sub: Submission in subs:
		record.reveal_order.append(sub.drawing_id)
	record.winner_drawing_id = winner_id
	if not winner_id.is_empty():
		for sub: Submission in subs:
			if sub.drawing_id == winner_id:
				record.winner_player_id = sub.author_player_id
	return record


## SessionStats with every drawing in the records registered.
func _stats_for(records: Array[RoundRecord]) -> SessionStats:
	var stats := SessionStats.new()
	for record: RoundRecord in records:
		for sub: Submission in record.submissions:
			stats.register_drawing(sub.drawing_id, record.round_index,
					sub.author_player_id, record.prompt.display_text)
		if not record.winner_drawing_id.is_empty():
			stats.record_winner(record.winner_drawing_id)
	return stats


func _meta(pid: String, connected: bool = true, granted: int = 2, spent: int = 0) -> Dictionary:
	return {"platform_id": pid, "display_name": pid.to_upper(),
			"connected": connected, "kudos_granted": granted, "kudos_spent": spent}


func _metas(pids: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pid: String in pids:
		out.append(_meta(pid))
	return out


## Two rounds, four drawings, no social data - the neutral base fixture.
func _base_records() -> Array[RoundRecord]:
	return [
		_record(0, [_sub("d0", "p1", _doc(2)), _sub("d1", "p2", _doc(3))], "", "round zero"),
		_record(1, [_sub("d2", "p0", _doc(1)), _sub("d3", "p2", _doc(4))], "", "round one"),
	]


func _titles_of(records: Array[RoundRecord], stats: SessionStats,
		points_on: bool = true) -> Array[Dictionary]:
	var infos: Array[Dictionary] = WrapUpCalculator.drawing_infos(records, stats)
	return WrapUpCalculator.compute_titles(infos, stats.kudos_events, ROTATION,
			DRAW_TIME, points_on)


func _title_holder(titles: Array[Dictionary], title_id: String) -> String:
	for t: Dictionary in titles:
		if str(t["id"]) == title_id:
			return str(t["player_id"])
	return ""


# --- titles ---


func test_hotshot_most_kudos_received_with_evidence_drawing() -> void:
	var records: Array[RoundRecord] = _base_records()
	var stats: SessionStats = _stats_for(records)
	stats.record_kudos(0, "d1", "p0")   # p2's d1: 1 kudos
	stats.record_kudos(1, "d3", "p0")   # p2's d3: 2 kudos -> evidence
	stats.record_kudos(1, "d3", "p1")
	var titles: Array[Dictionary] = _titles_of(records, stats)
	assert_str(_title_holder(titles, TitleIds.HOTSHOT)).is_equal("p2")
	for t: Dictionary in titles:
		if str(t["id"]) == TitleIds.HOTSHOT:
			assert_int(int(t["stat_value"])).is_equal(3)
			assert_str(str(t["stat_label"])).is_equal("3 kudos received")
			assert_array(t["evidence_drawing_ids"]).contains_exactly(["d3"])
			assert_int(int(t["points"])).is_equal(1)


func test_titles_stack_one_player_can_hold_several() -> void:
	# Slice 19: p2 leads BOTH hotshot (kudos) and judges_darling (2 wins) and
	# takes BOTH cards - the one-title-per-player rule is gone.
	var records: Array[RoundRecord] = [
		_record(0, [_sub("d0", "p1", _doc(2)), _sub("d1", "p2", _doc(3))], "d1"),
		_record(1, [_sub("d2", "p0", _doc(1)), _sub("d3", "p2", _doc(4))], "d3"),
	]
	var stats: SessionStats = _stats_for(records)
	stats.record_kudos(0, "d1", "p0")
	var titles: Array[Dictionary] = _titles_of(records, stats)
	assert_str(_title_holder(titles, TitleIds.HOTSHOT)).is_equal("p2")
	assert_str(_title_holder(titles, TitleIds.JUDGES_DARLING)).is_equal("p2")


func test_stacked_titles_stack_title_points_in_standings() -> void:
	# Same double-title fixture: p2's two cards are worth 2 title points.
	var records: Array[RoundRecord] = [
		_record(0, [_sub("d0", "p1", _doc(2)), _sub("d1", "p2", _doc(3))], "d1"),
		_record(1, [_sub("d2", "p0", _doc(1)), _sub("d3", "p2", _doc(4))], "d3"),
	]
	var stats: SessionStats = _stats_for(records)
	stats.record_kudos(0, "d1", "p0")
	var bundle: Dictionary = WrapUpCalculator.build_bundle(records, stats,
			_metas(["p0", "p1", "p2"]), {"p0": 0, "p1": 0, "p2": 4},
			["p0", "p1", "p2"], DRAW_TIME, true, false)
	for row: Variant in bundle["standings"]:
		if str((row as Dictionary)["player_id"]) == "p2":
			assert_int(int((row as Dictionary)["title_points"])).is_greater_equal(2)


func test_title_omitted_when_no_player_meets_minimum() -> void:
	# One win each: judges_darling needs >= 2 wins -> omitted entirely.
	var records: Array[RoundRecord] = [
		_record(0, [_sub("d0", "p1", _doc(2)), _sub("d1", "p2", _doc(3))], "d0"),
		_record(1, [_sub("d2", "p0", _doc(1)), _sub("d3", "p2", _doc(4))], "d3"),
	]
	var stats: SessionStats = _stats_for(records)
	var titles: Array[Dictionary] = _titles_of(records, stats)
	assert_str(_title_holder(titles, TitleIds.JUDGES_DARLING)).is_equal("")
	# No kudos anywhere: hotshot/generous_soul/peoples_champion also omitted.
	assert_str(_title_holder(titles, TitleIds.HOTSHOT)).is_equal("")
	assert_str(_title_holder(titles, TitleIds.GENEROUS_SOUL)).is_equal("")
	assert_str(_title_holder(titles, TitleIds.PEOPLES_CHAMPION)).is_equal("")


func test_peoples_champion_most_kudos_among_zero_win_players() -> void:
	# Slice 19 rebase: p2 has the most kudos but won a round; p1 has fewer
	# kudos and zero wins -> p1 is the People's Champion (and Hotshot still
	# goes to p2 - titles stack, PC just has its own zero-wins pool).
	var records: Array[RoundRecord] = [
		_record(0, [_sub("d0", "p1", _doc(2)), _sub("d1", "p2", _doc(3))], "d1"),
	]
	var stats: SessionStats = _stats_for(records)
	stats.record_kudos(0, "d1", "x1")
	stats.record_kudos(0, "d1", "x2")
	stats.record_kudos(0, "d1", "x3")   # p2: 3 kudos, but a winner
	stats.record_kudos(0, "d0", "x1")   # p1: 1 kudos, zero wins
	var titles: Array[Dictionary] = _titles_of(records, stats)
	assert_str(_title_holder(titles, TitleIds.HOTSHOT)).is_equal("p2")
	assert_str(_title_holder(titles, TitleIds.PEOPLES_CHAMPION)).is_equal("p1")
	for t: Dictionary in titles:
		if str(t["id"]) == TitleIds.PEOPLES_CHAMPION:
			assert_int(int(t["stat_value"])).is_equal(1)
			assert_str(str(t["stat_label"])).is_equal("1 kudos received, zero wins")


func test_peoples_champion_omitted_when_every_kudosed_player_won() -> void:
	# Only the round winner received kudos -> nobody in the zero-wins pool.
	var records: Array[RoundRecord] = [
		_record(0, [_sub("d0", "p1", _doc(2)), _sub("d1", "p2", _doc(3))], "d1"),
	]
	var stats: SessionStats = _stats_for(records)
	stats.record_kudos(0, "d1", "x1")
	var titles: Array[Dictionary] = _titles_of(records, stats)
	assert_str(_title_holder(titles, TitleIds.PEOPLES_CHAMPION)).is_equal("")


func test_generous_soul_most_kudos_spent_with_spend_order_evidence() -> void:
	var records: Array[RoundRecord] = _base_records()
	var stats: SessionStats = _stats_for(records)
	stats.record_kudos(0, "d1", "p0")   # p0 spends on d1 then d2 then d3
	stats.record_kudos(1, "d2", "p0")
	stats.record_kudos(1, "d3", "p0")
	stats.record_kudos(1, "d3", "p1")
	var titles: Array[Dictionary] = _titles_of(records, stats)
	# Hotshot goes to p2 (d1+d3 = 3 received); generous soul to p0 (3 given).
	assert_str(_title_holder(titles, TitleIds.GENEROUS_SOUL)).is_equal("p0")
	for t: Dictionary in titles:
		if str(t["id"]) == TitleIds.GENEROUS_SOUL:
			assert_array(t["evidence_drawing_ids"]).contains_exactly(["d1", "d2", "d3"])


func test_speed_demon_ignores_empty_drawings_and_requires_two() -> void:
	# p1: two timestamped drawings (finish 6s, 12s of 30s -> mean 0.3).
	# p2: one timestamped drawing + one blank -> ineligible (< 2 usable).
	var records: Array[RoundRecord] = [
		_record(0, [_sub("d0", "p1", _doc(0, 6.0)), _sub("d1", "p2", _doc(0, 3.0))]),
		_record(1, [_sub("d2", "p1", _doc(0, 12.0)),
				_sub("d3", "p2", Submission.blank_doc(), true)]),
	]
	var stats: SessionStats = _stats_for(records)
	var titles: Array[Dictionary] = _titles_of(records, stats)
	assert_str(_title_holder(titles, TitleIds.SPEED_DEMON)).is_equal("p1")
	for t: Dictionary in titles:
		if str(t["id"]) == TitleIds.SPEED_DEMON:
			assert_float(float(t["stat_value"])).is_equal_approx(0.3, 0.0001)
			assert_array(t["evidence_drawing_ids"]).contains_exactly(["d0"])  # lowest fraction


func test_minimalist_excludes_zero_op_docs_da_vinci_takes_most_marks() -> void:
	# p1 heavy (5+7 ops), p2 light (1+2 ops), p0 has a zero-op submission
	# that must not count toward Minimalist.
	var records: Array[RoundRecord] = [
		_record(0, [_sub("d0", "p1", _doc(5)), _sub("d1", "p2", _doc(1)),
				_sub("d2", "p0", _doc(0))]),
		_record(1, [_sub("d3", "p1", _doc(7)), _sub("d4", "p2", _doc(2)),
				_sub("d5", "p0", _doc(0))]),
	]
	var stats: SessionStats = _stats_for(records)
	var titles: Array[Dictionary] = _titles_of(records, stats)
	assert_str(_title_holder(titles, TitleIds.DA_VINCI)).is_equal("p1")
	assert_str(_title_holder(titles, TitleIds.MINIMALIST)).is_equal("p2")
	for t: Dictionary in titles:
		if str(t["id"]) == TitleIds.DA_VINCI:
			assert_array(t["evidence_drawing_ids"]).contains_exactly(["d3"])  # 7 ops
		if str(t["id"]) == TitleIds.MINIMALIST:
			assert_array(t["evidence_drawing_ids"]).contains_exactly(["d1"])  # 1 op


func test_title_tie_breaks_stat_then_round_then_rotation_index() -> void:
	# p1 and p3 tie on kudos received (2 each). p3's best evidence is round 0,
	# p1's is round 1 -> earlier round wins for p3.
	var records: Array[RoundRecord] = [
		_record(0, [_sub("d0", "p3", _doc(1)), _sub("d1", "p1", _doc(1))]),
		_record(1, [_sub("d2", "p3", _doc(1)), _sub("d3", "p1", _doc(1))]),
	]
	var stats: SessionStats = _stats_for(records)
	stats.record_kudos(0, "d0", "x1")
	stats.record_kudos(0, "d0", "x2")   # p3: 2 kudos, evidence round 0
	stats.record_kudos(1, "d3", "x1")
	stats.record_kudos(1, "d3", "x2")   # p1: 2 kudos, evidence round 1
	var titles: Array[Dictionary] = _titles_of(records, stats)
	assert_str(_title_holder(titles, TitleIds.HOTSHOT)).is_equal("p3")
	# Pure tie (same stat, same round): the rotation index decides.
	var a: Dictionary = {"player_id": "p2", "stat_value": 0,
			"evidence_round": 0, "stat_label": "", "evidence_ids": []}
	var b: Dictionary = {"player_id": "p1", "stat_value": 0,
			"evidence_round": 0, "stat_label": "", "evidence_ids": []}
	assert_bool(WrapUpCalculator._beats(a, b, true, ROTATION)).is_false()   # p1 earlier
	assert_bool(WrapUpCalculator._beats(b, a, true, ROTATION)).is_true()


func test_points_zeroed_when_title_points_disabled() -> void:
	var records: Array[RoundRecord] = [
		_record(0, [_sub("d0", "p1", _doc(2)), _sub("d1", "p2", _doc(3))], "d1"),
	]
	var stats: SessionStats = _stats_for(records)
	stats.record_kudos(0, "d0", "p2")
	var bundle: Dictionary = WrapUpCalculator.build_bundle(records, stats,
			_metas(["p0", "p1", "p2"]), {"p0": 0, "p1": 1, "p2": 2},
			["p0", "p1", "p2"], DRAW_TIME, false, false)
	assert_bool((bundle["titles"] as Array).is_empty()).is_false()
	for t: Variant in bundle["titles"]:
		assert_int(int((t as Dictionary)["points"])).is_equal(0)
	for row: Variant in bundle["standings"]:
		assert_int(int((row as Dictionary)["title_points"])).is_equal(0)
		assert_int(int((row as Dictionary)["final_score"]))\
				.is_equal(int((row as Dictionary)["base_score"]))


func test_titles_disabled_yields_empty_titles_and_base_standings() -> void:
	# Slice 19: titles_enabled=false -> no titles computed at all, standings
	# are pure base scores, and no evidence drawings are embedded.
	var records: Array[RoundRecord] = [
		_record(0, [_sub("d0", "p1", _doc(2)), _sub("d1", "p2", _doc(3))], "d1"),
	]
	var stats: SessionStats = _stats_for(records)
	stats.record_kudos(0, "d1", "p0")   # would earn Hotshot if titles were on
	var bundle: Dictionary = WrapUpCalculator.build_bundle(records, stats,
			_metas(["p0", "p1", "p2"]), {"p0": 0, "p1": 1, "p2": 2},
			["p0", "p1", "p2"], DRAW_TIME, true, false, false)
	assert_array(bundle["titles"]).is_empty()
	assert_dict(bundle["drawings"]).is_empty()
	for row: Variant in bundle["standings"]:
		assert_int(int((row as Dictionary)["title_points"])).is_equal(0)
		assert_int(int((row as Dictionary)["final_score"]))\
				.is_equal(int((row as Dictionary)["base_score"]))


# --- standings ---


func test_standings_competition_ranking_with_ties_and_negatives() -> void:
	var standings: Array[Dictionary] = WrapUpCalculator.compute_standings(
			{"p0": -3, "p1": 4, "p2": 4, "p3": -3}, [],
			_metas(["p0", "p1", "p2", "p3"]), ROTATION)
	assert_int(standings.size()).is_equal(4)
	assert_str(str(standings[0]["player_id"])).is_equal("p1")   # tie order = rotation
	assert_int(int(standings[0]["rank"])).is_equal(1)
	assert_int(int(standings[1]["rank"])).is_equal(1)           # shared rank
	assert_int(int(standings[2]["rank"])).is_equal(3)           # competition jump
	assert_int(int(standings[2]["final_score"])).is_equal(-3)   # negatives unclamped
	assert_int(int(standings[3]["rank"])).is_equal(3)


func test_standings_include_disconnected_players_and_apply_title_points() -> void:
	var metas: Array[Dictionary] = [_meta("p0"), _meta("p1", false), _meta("p2")]
	var titles: Array[Dictionary] = [
		{"id": TitleIds.HOTSHOT, "player_id": "p1", "stat_value": 2,
				"stat_label": "2 kudos received", "evidence_drawing_ids": ["d0"],
				"points": 1},
		{"id": TitleIds.SPEED_DEMON, "player_id": "p1", "stat_value": 0.3,
				"stat_label": "done with 70% of the clock to spare",
				"evidence_drawing_ids": ["d0"], "points": 1},
	]
	var standings: Array[Dictionary] = WrapUpCalculator.compute_standings(
			{"p0": 2, "p1": 1, "p2": 2}, titles, metas, ["p0", "p1", "p2"])
	# p1 (disconnected): 1 base + 2 stacked title points = 3 -> outright first.
	assert_str(str(standings[0]["player_id"])).is_equal("p1")
	assert_bool(bool(standings[0]["connected"])).is_false()
	assert_int(int(standings[0]["title_points"])).is_equal(2)
	assert_int(int(standings[0]["final_score"])).is_equal(3)
	assert_int(int(standings[0]["rank"])).is_equal(1)
	assert_int(int(standings[1]["rank"])).is_equal(2)


# --- bundle ---


func test_bundle_embeds_each_referenced_drawing_once() -> void:
	# d1 is evidence for BOTH hotshot and peoples_champion... embedded once.
	var records: Array[RoundRecord] = [
		_record(0, [_sub("d0", "p1", _doc(2)), _sub("d1", "p2", _doc(3))]),
	]
	var stats: SessionStats = _stats_for(records)
	stats.record_kudos(0, "d1", "p0")
	var bundle: Dictionary = WrapUpCalculator.build_bundle(records, stats,
			_metas(["p0", "p1", "p2"]), {"p0": 0, "p1": 0, "p2": 0},
			["p0", "p1", "p2"], DRAW_TIME, true, false)
	var drawings: Dictionary = bundle["drawings"]
	assert_bool(drawings.has("d1")).is_true()
	var entry: Dictionary = drawings["d1"]
	assert_str(str(entry["prompt"])).is_equal("prompt")
	assert_bool((entry["doc"] as Dictionary).has("ops")).is_true()
	# Every embedded id must be referenced by some title's evidence.
	var referenced: Dictionary = {}
	for t: Variant in bundle["titles"]:
		for id: Variant in (t as Dictionary)["evidence_drawing_ids"]:
			referenced[str(id)] = true
	for id: Variant in drawings.keys():
		assert_bool(referenced.has(str(id))).is_true()


func test_empty_session_produces_standings_only_bundle() -> void:
	var stats := SessionStats.new()
	var bundle: Dictionary = WrapUpCalculator.build_bundle([], stats,
			_metas(["p0", "p1", "p2"]), {}, ["p0", "p1", "p2"],
			DRAW_TIME, true, true)
	assert_int(int(bundle["v"])).is_equal(1)
	assert_bool(bool(bundle["early_end"])).is_true()
	assert_int(int(bundle["rounds_completed"])).is_equal(0)
	assert_bool(bundle.has("superlatives")).is_false()   # retired key stays gone
	assert_array(bundle["titles"]).is_empty()
	assert_dict(bundle["drawings"]).is_empty()
	var standings: Array = bundle["standings"]
	assert_int(standings.size()).is_equal(3)   # every rostered player, score 0
	for row: Variant in standings:
		assert_int(int((row as Dictionary)["final_score"])).is_equal(0)
		assert_int(int((row as Dictionary)["rank"])).is_equal(1)


func test_same_inputs_produce_identical_bundle() -> void:
	var records: Array[RoundRecord] = [
		_record(0, [_sub("d0", "p1", _doc(2, 5.0)), _sub("d1", "p2", _doc(3, 9.0))], "d1"),
		_record(1, [_sub("d2", "p0", _doc(1, 2.0)), _sub("d3", "p2", _doc(4, 20.0))], "d3"),
	]
	var stats: SessionStats = _stats_for(records)
	stats.record_kudos(0, "d0", "p2")
	stats.record_kudos(1, "d2", "p2")
	var a: Dictionary = WrapUpCalculator.build_bundle(records, stats,
			_metas(["p0", "p1", "p2"]), {"p0": 1, "p1": 2, "p2": 4},
			["p0", "p1", "p2"], DRAW_TIME, true, false)
	var b: Dictionary = WrapUpCalculator.build_bundle(records, stats,
			_metas(["p0", "p1", "p2"]), {"p0": 1, "p1": 2, "p2": 4},
			["p0", "p1", "p2"], DRAW_TIME, true, false)
	assert_bool(a == b).is_true()   # deep equality - deterministic (§6 rule 5)


func test_kudos_summary_carries_granted_and_spent_for_slice_14() -> void:
	var stats := SessionStats.new()
	var bundle: Dictionary = WrapUpCalculator.build_bundle([], stats,
			[_meta("p0", true, 2, 2), _meta("p1", true, 2, 1)], {},
			["p0", "p1"], DRAW_TIME, true, false)
	assert_dict(bundle["kudos"]).is_equal({
		"p0": {"granted": 2, "spent": 2},
		"p1": {"granted": 2, "spent": 1},
	})
