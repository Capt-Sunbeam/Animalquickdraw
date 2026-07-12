class_name SessionStats
extends RefCounted
## Host-only per-game social stats (Slice 4 TDD §2) - the integration
## contract Slice 10 mines for titles. Lives on GameSession; lost if
## the host quits (accepted for v1). All player references are stable uids
## (platform ids), never peer ids.
## Slice 19: emoji reaction tracking removed with the reaction system;
## kudos is the remaining social currency.

const FORMAT_VERSION: int = 1


## Per-drawing rollup.
class DrawingStats extends RefCounted:
	var drawing_id: String = ""
	var round_index: int = 0
	var author_uid: String = ""
	var prompt_text: String = ""          # display text, e.g. "sleepy aardvark"
	var kudos_received: int = 0
	var won_round: bool = false           # set by GameSession at resolution

	func to_dict() -> Dictionary:
		return {
			"drawing_id": drawing_id,
			"round_index": round_index,
			"author_uid": author_uid,
			"prompt_text": prompt_text,
			"kudos_received": kudos_received,
			"won_round": won_round,
		}


var drawings: Dictionary = {}                # drawing_id -> DrawingStats (registration order preserved)
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


# --- Query surface (Slice 10 builds titles on) ---


## author_uid -> total kudos received across their drawings. Authors with
## zero kudos are absent (nonzero-only).
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
		"kudos_events": kudos_events.duplicate(true),
	}


static func _system_now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
