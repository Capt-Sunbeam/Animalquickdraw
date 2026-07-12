class_name WrapUpCalculator
extends RefCounted
## Host-only wrap-up bundle math (Slice 10 TDD §6, reworked by Slice 19):
## the title set, title points, and final standings, computed ONCE into a
## single immutable bundle. Pure static functions, zero UI/network
## references (headless-testable, consistency guide §3/§9).
##
## Slice 19 (owner, 2026-07-12): superlatives removed with the emoji
## reaction system; titles STACK (no one-per-player rule - PRIORITY is
## display order only); Worst Drawer cut; People's Champion is kudos-based.
##
## Inputs are the shipped Slice 3/4/9 structures (decision log 2026-07-07:
## the TDD-10 draft's round_results contract maps onto RoundRecord +
## SessionStats). Only COMPLETED rounds participate - a partial round was
## never appended to the records, so early ends exclude it by construction.
## All iteration is in deterministic order (rounds ascending, reveal order
## ascending, rotation order for player ties): same inputs, identical bundle.

const BUNDLE_VERSION: int = 1


## Flattens completed rounds into one ordered drawing-info list (rounds
## ascending, reveal order ascending) - the working set every award reads.
## Blanks are included (they can take kudos); stats-less drawings
## (defensive - never happens) carry zero counts.
static func drawing_infos(records: Array[RoundRecord], stats: SessionStats) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for record: RoundRecord in records:
		var round_infos: Array[Dictionary] = []
		for i: int in record.submissions.size():
			var sub: Submission = record.submissions[i]
			var reveal_index: int = record.reveal_order.find(sub.drawing_id)
			if reveal_index < 0:
				reveal_index = i   # pre-Slice-10 record (tests) - drawer order
			var ds: SessionStats.DrawingStats = stats.drawings.get(sub.drawing_id)
			round_infos.append({
				"drawing_id": sub.drawing_id,
				"round": record.round_index,
				"author_id": sub.author_player_id,
				"doc": sub.doc,
				"is_blank": sub.is_blank,
				"reveal_index": reveal_index,
				"prompt": record.prompt.display_text if record.prompt != null else "",
				"kudos": ds.kudos_received if ds != null else 0,
				"won": not record.winner_drawing_id.is_empty() \
						and record.winner_drawing_id == sub.drawing_id,
			})
		round_infos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["reveal_index"]) < int(b["reveal_index"]))
		out.append_array(round_infos)
	return out


## The title set in ceremony order (TDD 19 §3). Every title goes to its top
## qualifier - titles STACK (Slice 19: no one-per-player exclusion); no
## qualifier = title omitted. Player tie-break chain: stat -> earlier
## best-evidence round -> lower rotation index.
static func compute_titles(infos: Array[Dictionary], kudos_events: Array[Dictionary],
		rotation_order: Array[String], draw_time_sec: float,
		points_on: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for title_id: String in TitleIds.PRIORITY:
		var candidates: Array[Dictionary] = _candidates_for(
				title_id, infos, kudos_events, draw_time_sec)
		var higher_is_better: bool = not [TitleIds.SPEED_DEMON,
				TitleIds.MINIMALIST].has(title_id)
		var best: Dictionary = {}
		for c: Dictionary in candidates:
			if best.is_empty() or _beats(c, best, higher_is_better, rotation_order):
				best = c
		if best.is_empty():
			continue
		out.append({
			"id": title_id,
			"player_id": str(best["player_id"]),
			"stat_value": best["stat_value"],
			"stat_label": str(best["stat_label"]),
			"evidence_drawing_ids": best["evidence_ids"],
			"points": GameConstants.TITLE_POINTS_VALUE if points_on else 0,
		})
	return out


## Final standings: base + title points, standard competition
## ranking (1, 2, 2, 4), negatives unclamped (§11 - no floor anywhere).
## Display order within a tie = rotation index. Every rostered player
## appears, connected or not.
static func compute_standings(scores: Dictionary,
		titles: Array[Dictionary], players_meta: Array[Dictionary],
		rotation_order: Array[String]) -> Array[Dictionary]:
	var title_points: Dictionary = {}    # player_id -> int
	for t: Dictionary in titles:
		var pid: String = str(t["player_id"])
		title_points[pid] = int(title_points.get(pid, 0)) + int(t["points"])
	var rows: Array[Dictionary] = []
	for meta: Dictionary in players_meta:
		var pid: String = str(meta["platform_id"])
		var base: int = int(scores.get(pid, 0))
		var tp: int = int(title_points.get(pid, 0))
		rows.append({
			"player_id": pid,
			"display_name": str(meta.get("display_name", pid)),
			"base_score": base,
			"title_points": tp,
			"final_score": base + tp,
			"connected": bool(meta.get("connected", true)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["final_score"]) != int(b["final_score"]):
			return int(a["final_score"]) > int(b["final_score"])
		return _rotation_index(str(a["player_id"]), rotation_order) \
				< _rotation_index(str(b["player_id"]), rotation_order))
	for i: int in rows.size():
		var rank: int = i + 1
		if i > 0 and int(rows[i]["final_score"]) == int(rows[i - 1]["final_score"]):
			rank = int(rows[i - 1]["rank"])
		rows[i]["rank"] = rank
	return rows


## The whole bundle (TDD §2), broadcast once inside the results dictionary
## and never mutated afterwards. Evidence DrawingDocs are embedded (deduped,
## prompt-annotated) so late joiners/rejoiners render everything with zero
## cache repair.
static func build_bundle(records: Array[RoundRecord], stats: SessionStats,
		players_meta: Array[Dictionary], scores: Dictionary,
		rotation_order: Array[String], draw_time_sec: float,
		points_on: bool, early: bool, titles_on: bool = true) -> Dictionary:
	var infos: Array[Dictionary] = drawing_infos(records, stats)
	# Slice 19: titles_enabled=false -> empty titles, zero title points -
	# standings degrade to pure base scores; no badges, no ceremony.
	var titles: Array[Dictionary] = []
	if titles_on:
		titles = compute_titles(infos, stats.kudos_events,
				rotation_order, draw_time_sec, points_on)
	var standings: Array[Dictionary] = compute_standings(scores,
			titles, players_meta, rotation_order)
	var kudos: Dictionary = {}
	for meta: Dictionary in players_meta:
		kudos[str(meta["platform_id"])] = {
			"granted": int(meta.get("kudos_granted", 0)),
			"spent": int(meta.get("kudos_spent", 0)),
		}
	var by_id: Dictionary = {}
	for info: Dictionary in infos:
		by_id[str(info["drawing_id"])] = info
	var drawings: Dictionary = {}
	for t: Dictionary in titles:
		for id: Variant in t["evidence_drawing_ids"]:
			_embed_drawing(drawings, by_id, str(id))
	return {
		"v": BUNDLE_VERSION,
		"early_end": early,
		"rounds_completed": records.size(),
		"titles": titles,
		"standings": standings,
		"kudos": kudos,
		"drawings": drawings,
	}


# --- Title candidate computation (one branch per TitleIds row) ---


## Candidates for one title: [{player_id, stat_value, stat_label,
## evidence_ids, evidence_round}], minimums already applied. Iteration is in
## info order per author, so per-author evidence tie-breaks (earlier round,
## then earlier reveal) fall out of strictly-better comparisons.
static func _candidates_for(title_id: String, infos: Array[Dictionary],
		kudos_events: Array[Dictionary], draw_time_sec: float) -> Array[Dictionary]:
	var by_author: Dictionary = {}   # player_id -> Array[Dictionary] (info order kept)
	for info: Dictionary in infos:
		(by_author.get_or_add(str(info["author_id"]), []) as Array).append(info)
	var out: Array[Dictionary] = []
	match title_id:
		TitleIds.HOTSHOT:
			for pid: Variant in by_author.keys():
				var best: Dictionary = _best_info(by_author[pid], "kudos", true)
				var total: int = _sum_int(by_author[pid], "kudos")
				if total >= 1:
					out.append(_candidate(str(pid), total,
							"%d kudos received" % total, [str(best["drawing_id"])],
							int(best["round"])))
		TitleIds.JUDGES_DARLING:
			for pid: Variant in by_author.keys():
				var wins: Array[Dictionary] = []
				for info: Dictionary in by_author[pid]:
					if bool(info["won"]):
						wins.append(info)
				if wins.size() >= 2:
					var evidence: Array[String] = []
					for info: Dictionary in wins.slice(0, GameConstants.WRAPUP_TITLE_EVIDENCE_MAX):
						evidence.append(str(info["drawing_id"]))
					out.append(_candidate(str(pid), wins.size(),
							"%d round wins" % wins.size(), evidence, int(wins[0]["round"])))
		TitleIds.PEOPLES_CHAMPION:
			# Slice 19 rebase (owner): the reaction criterion died with the
			# emoji system - now the most-kudos'd player who never won a round
			# (consolation semantics preserved on kudos data).
			for pid: Variant in by_author.keys():
				if _sum_int(by_author[pid], "won") > 0:
					continue   # any round win excludes (§2)
				var total: int = _sum_int(by_author[pid], "kudos")
				if total >= 1:
					var best: Dictionary = _best_info(by_author[pid], "kudos", true)
					out.append(_candidate(str(pid), total,
							"%d kudos received, zero wins" % total,
							[str(best["drawing_id"])], int(best["round"])))
		TitleIds.GENEROUS_SOUL:
			var known_ids: Dictionary = {}
			for info: Dictionary in infos:
				known_ids[str(info["drawing_id"])] = int(info["round"])
			var spent_on: Dictionary = {}   # giver -> Array[String], spend order
			for event: Dictionary in kudos_events:
				var drawing_id: String = str(event["drawing_id"])
				if not known_ids.has(drawing_id):
					continue   # partial-round spend - frozen out with its round
				(spent_on.get_or_add(str(event["giver_uid"]), []) as Array).append(drawing_id)
			for pid: Variant in spent_on.keys():
				var ids: Array = spent_on[pid]
				var evidence: Array[String] = []
				for id: Variant in ids.slice(0, GameConstants.WRAPUP_TITLE_EVIDENCE_MAX):
					evidence.append(str(id))
				out.append(_candidate(str(pid), ids.size(),
						"%d kudos given" % ids.size(), evidence,
						int(known_ids[str(ids[0])])))
		TitleIds.SPEED_DEMON:
			for pid: Variant in by_author.keys():
				var fractions: Array[float] = []
				var best: Dictionary = {}
				var best_frac: float = INF
				for info: Dictionary in by_author[pid]:
					if bool(info["is_blank"]):
						continue
					var finish: float = _finish_ts(info["doc"])
					if finish <= 0.0:
						continue   # no stroke timestamps - undefined finish (§10)
					var frac: float = finish / maxf(draw_time_sec, 0.001)
					fractions.append(frac)
					if frac < best_frac:
						best_frac = frac
						best = info
				if fractions.size() >= 2:
					var mean: float = _mean(fractions)
					out.append(_candidate(str(pid), mean,
							"done with %d%% of the clock to spare" % roundi((1.0 - mean) * 100.0),
							[str(best["drawing_id"])], int(best["round"])))
		TitleIds.DA_VINCI:
			for pid: Variant in by_author.keys():
				var counts: Array[float] = []
				var best: Dictionary = {}
				var best_ops: int = -1
				for info: Dictionary in by_author[pid]:
					if bool(info["is_blank"]):
						continue
					var ops: int = _op_count(info["doc"])
					counts.append(float(ops))
					if ops > best_ops:
						best_ops = ops
						best = info
				if counts.size() >= 2:
					var mean: float = _mean(counts)
					out.append(_candidate(str(pid), mean,
							"%.1f marks per drawing" % mean,
							[str(best["drawing_id"])], int(best["round"])))
		TitleIds.MINIMALIST:
			for pid: Variant in by_author.keys():
				var counts: Array[float] = []
				var best: Dictionary = {}
				var best_ops: int = 0
				for info: Dictionary in by_author[pid]:
					if bool(info["is_blank"]):
						continue
					var ops: int = _op_count(info["doc"])
					if ops <= 0:
						continue   # empty canvases are excluded (§10)
					counts.append(float(ops))
					if best.is_empty() or ops < best_ops:
						best_ops = ops
						best = info
				if counts.size() >= 2:
					var mean: float = _mean(counts)
					out.append(_candidate(str(pid), mean,
							"just %.1f marks per drawing" % mean,
							[str(best["drawing_id"])], int(best["round"])))
	return out


static func _candidate(player_id: String, stat_value: Variant, stat_label: String,
		evidence_ids: Array[String], evidence_round: int) -> Dictionary:
	return {
		"player_id": player_id,
		"stat_value": stat_value,
		"stat_label": stat_label,
		"evidence_ids": evidence_ids,
		"evidence_round": evidence_round,
	}


## Player-level tie-break chain (§2): better stat -> earlier best-evidence
## round -> lower rotation index.
static func _beats(a: Dictionary, b: Dictionary, higher_is_better: bool,
		rotation_order: Array[String]) -> bool:
	var sa: float = float(a["stat_value"])
	var sb: float = float(b["stat_value"])
	if sa != sb:
		return sa > sb if higher_is_better else sa < sb
	if int(a["evidence_round"]) != int(b["evidence_round"]):
		return int(a["evidence_round"]) < int(b["evidence_round"])
	return _rotation_index(str(a["player_id"]), rotation_order) \
			< _rotation_index(str(b["player_id"]), rotation_order)


static func _rotation_index(player_id: String, rotation_order: Array[String]) -> int:
	var index: int = rotation_order.find(player_id)
	return index if index >= 0 else rotation_order.size()


## First info with the strictly-highest (or lowest) int stat - info order
## encodes the earlier-round/earlier-reveal tie-break.
static func _best_info(author_infos: Array, key: String, higher: bool) -> Dictionary:
	var best: Dictionary = {}
	for info: Dictionary in author_infos:
		if best.is_empty():
			best = info
			continue
		var v: int = int(info[key])
		var bv: int = int(best[key])
		if (v > bv) if higher else (v < bv):
			best = info
	return best


static func _sum_int(author_infos: Array, key: String) -> int:
	var total: int = 0
	for info: Dictionary in author_infos:
		total += int(info[key])
	return total


static func _mean(values: Array[float]) -> float:
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / float(values.size())


## Latest stroke timestamp in a serialized doc; 0.0 when no stroke carries
## one (fill/clear/text ops have no timestamps).
static func _finish_ts(doc: Variant) -> float:
	if not doc is Dictionary:
		return 0.0
	var last: float = 0.0
	for op: Variant in (doc as Dictionary).get("ops", []):
		if op is Dictionary and str((op as Dictionary).get("t", "")) == "stroke":
			var ts: Variant = (op as Dictionary).get("ts")
			if ts is Array and not (ts as Array).is_empty():
				last = maxf(last, float((ts as Array)[-1]))
	return last


static func _op_count(doc: Variant) -> int:
	if not doc is Dictionary:
		return 0
	var ops: Variant = (doc as Dictionary).get("ops")
	return (ops as Array).size() if ops is Array else 0


static func _embed_drawing(drawings: Dictionary, by_id: Dictionary, drawing_id: String) -> void:
	if drawings.has(drawing_id) or not by_id.has(drawing_id):
		return
	var info: Dictionary = by_id[drawing_id]
	drawings[drawing_id] = {"doc": info["doc"], "prompt": str(info["prompt"])}
