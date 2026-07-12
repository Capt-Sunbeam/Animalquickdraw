class_name SessionStats
extends RefCounted
## Host-only per-game social stats (Slice 4 TDD §2) - the integration
## contract Slice 10 mines for superlatives. Lives on GameSession; lost if
## the host quits (accepted for v1). All player references are stable uids
## (platform ids), never peer ids.

const FORMAT_VERSION: int = 1


## Per-drawing rollup.
class DrawingStats extends RefCounted:
	var drawing_id: String = ""
	var round_index: int = 0
	var author_uid: String = ""
	var prompt_text: String = ""          # display text, e.g. "sleepy aardvark"
	var reaction_counts: Dictionary = {}  # NetIds.Reaction -> int (final aggregates)
	var kudos_received: int = 0
	var won_round: bool = false           # set by GameSession at resolution

	func to_dict() -> Dictionary:
		return {
			"drawing_id": drawing_id,
			"round_index": round_index,
			"author_uid": author_uid,
			"prompt_text": prompt_text,
			"reaction_counts": reaction_counts.duplicate(),
			"kudos_received": kudos_received,
			"won_round": won_round,
		}


var drawings: Dictionary = {}                # drawing_id -> DrawingStats (registration order preserved)
var reaction_events: Array[Dictionary] = []  # {"round", "drawing_id", "reaction", "actor_uid", "added", "t_ms"}
var kudos_events: Array[Dictionary] = []     # {"round", "drawing_id", "giver_uid", "t_ms"}

var _now_ms: Callable


func _init(now_ms: Callable = Callable()) -> void:
	_now_ms = now_ms if now_ms.is_valid() else Callable(SessionStats, "_system_now_ms")


# --- Recording surface (GameSession calls) ---


func register_drawing(id: String, round_index: int, author_uid: String, prompt_text: String) -> void:
	var stats := DrawingStats.new()
	stats.drawing_id = id
	stats.round_index = round_index
	stats.author_uid = author_uid
	stats.prompt_text = prompt_text
	drawings[id] = stats


func record_reaction(round_index: int, drawing_id: String, reaction: NetIds.Reaction,
		actor_uid: String, added: bool) -> void:
	var stats: DrawingStats = drawings.get(drawing_id)
	if stats == null:
		push_error("SessionStats: reaction for unregistered drawing '%s'" % drawing_id)
		return
	stats.reaction_counts[reaction] = maxi(0,
			int(stats.reaction_counts.get(reaction, 0)) + (1 if added else -1))
	if int(stats.reaction_counts.get(reaction, 0)) == 0:
		stats.reaction_counts.erase(reaction)   # aggregates keep nonzero keys only
	reaction_events.append({"round": round_index, "drawing_id": drawing_id,
			"reaction": int(reaction), "actor_uid": actor_uid, "added": added,
			"t_ms": int(_now_ms.call())})


func record_kudos(round_index: int, drawing_id: String, giver_uid: String) -> void:
	var stats: DrawingStats = drawings.get(drawing_id)
	if stats == null:
		push_error("SessionStats: kudos for unregistered drawing '%s'" % drawing_id)
		return
	stats.kudos_received += 1
	kudos_events.append({"round": round_index, "drawing_id": drawing_id,
			"giver_uid": giver_uid, "t_ms": int(_now_ms.call())})


func record_winner(drawing_id: String) -> void:
	var stats: DrawingStats = drawings.get(drawing_id)
	if stats == null:
		push_error("SessionStats: winner for unregistered drawing '%s'" % drawing_id)
		return
	stats.won_round = true


# --- Query surface (Slice 10 builds superlatives on) ---


## Drawing with the highest final count of `reaction`; ties return the first
## registered. "" if nothing holds a nonzero count.
func top_drawing_by_reaction(reaction: NetIds.Reaction) -> String:
	var best_id: String = ""
	var best_count: int = 0
	for id: Variant in drawings.keys():   # insertion order = registration order
		var stats: DrawingStats = drawings[id]
		var count: int = int(stats.reaction_counts.get(reaction, 0))
		if count > best_count:
			best_count = count
			best_id = str(id)
	return best_id


## author_uid -> Dictionary[Reaction, int], summed over the author's
## drawings. Authors with zero reactions are absent (nonzero-only, like the
## per-drawing aggregates).
func reaction_totals_by_author() -> Dictionary:
	var out: Dictionary = {}
	for stats: DrawingStats in drawings.values():
		if stats.reaction_counts.is_empty():
			continue
		var totals: Dictionary = out.get_or_add(stats.author_uid, {})
		for reaction: Variant in stats.reaction_counts.keys():
			totals[reaction] = int(totals.get(reaction, 0)) + int(stats.reaction_counts[reaction])
	return out


## Count of net-active reaction adds by this player (adds minus removes).
func reactions_given_by(uid: String) -> int:
	var net: int = 0
	for event: Dictionary in reaction_events:
		if str(event["actor_uid"]) == uid:
			net += 1 if bool(event["added"]) else -1
	return maxi(0, net)


## author_uid -> total kudos received across their drawings. Authors with
## zero kudos are absent (nonzero-only, like the reaction aggregates).
func kudos_received_by_author() -> Dictionary:
	var out: Dictionary = {}
	for stats: DrawingStats in drawings.values():
		if stats.kudos_received > 0:
			out[stats.author_uid] = int(out.get(stats.author_uid, 0)) + stats.kudos_received
	return out


## v-tagged dump for debugging and the results bundle.
func to_dict() -> Dictionary:
	var drawing_dicts: Array[Dictionary] = []
	for stats: DrawingStats in drawings.values():
		drawing_dicts.append(stats.to_dict())
	return {
		"v": FORMAT_VERSION,
		"drawings": drawing_dicts,
		"reaction_events": reaction_events.duplicate(true),
		"kudos_events": kudos_events.duplicate(true),
	}


static func _system_now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
