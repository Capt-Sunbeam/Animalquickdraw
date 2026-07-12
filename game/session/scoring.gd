class_name Scoring
extends RefCounted
## Score ledger (Slice 3 TDD §6). Negative scores are legal; there is no
## floor anywhere (brief §11). Extension points: Slice 4 kudos and Slice 10
## title points both route through add_points - no new scoring surface.

var _scores: Dictionary = {}   # player_id -> int


func ensure_player(player_id: String) -> void:
	if not _scores.has(player_id):
		_scores[player_id] = 0


func add_points(player_id: String, delta: int) -> void:
	ensure_player(player_id)
	_scores[player_id] = int(_scores[player_id]) + delta


func apply_winner(player_id: String) -> void:
	add_points(player_id, GameConstants.WINNER_POINTS)        # +2


func apply_no_pick_penalty(judge_id: String) -> void:
	add_points(judge_id, GameConstants.JUDGE_NO_PICK_POINTS)  # -1


func get_score(player_id: String) -> int:
	return int(_scores.get(player_id, 0))


func snapshot() -> Dictionary:
	return _scores.duplicate()


## Ranked standings: score descending; ties share the better rank; stable
## order within a tie follows tiebreak_order (joined_order in practice).
## Negative scores sort naturally - no clamping (brief §11).
static func standings(scores: Dictionary, tiebreak_order: Array[String]) -> Array[Dictionary]:
	var ids: Array[String] = []
	for pid: String in tiebreak_order:
		if scores.has(pid):
			ids.append(pid)
	for pid: Variant in scores.keys():
		if not ids.has(str(pid)):
			ids.append(str(pid))  # not in tiebreak list - append in key order
	# Stable sort by score desc: sort_custom is not guaranteed stable, so
	# sort (score desc, tiebreak index asc) explicitly.
	var index_of: Dictionary = {}
	for i: int in range(ids.size()):
		index_of[ids[i]] = i
	var sorted: Array[String] = ids.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool:
		var sa: int = int(scores[a])
		var sb: int = int(scores[b])
		if sa != sb:
			return sa > sb
		return int(index_of[a]) < int(index_of[b]))
	var out: Array[Dictionary] = []
	for i: int in range(sorted.size()):
		var pid: String = sorted[i]
		var rank: int = i + 1
		# Tie shares the better (earlier) rank.
		if i > 0 and int(scores[pid]) == int(scores[sorted[i - 1]]):
			rank = int(out[i - 1]["rank"])
		out.append({"player_id": pid, "score": int(scores[pid]), "rank": rank})
	return out
