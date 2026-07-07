class_name KudosLedger
extends RefCounted
## Host-only kudos bookkeeping (Slice 4 TDD §2/§6). Public aggregate total
## per drawing plus the host-private giver set that enforces one kudos per
## giver per drawing. Budget lives on PlayerState (kudos_granted/spent);
## this class owns per-drawing state and the allotment math.

var _kudos_by_drawing: Dictionary = {}   # drawing_id: String -> total: int
var _givers_by_drawing: Dictionary = {}  # drawing_id: String -> Dictionary[uid: String, true]


## Allotment formula (brief §11): round_count / KUDOS_PER_ROUNDS, rounded to
## nearest with .5 UP, min KUDOS_MIN_ALLOTMENT. Examples (encoded as unit
## tests): 3->1, 4->1, 5->1, 6->2, 7->2, 8->2, 10->3, 12->3, 14->4.
static func compute_allotment(round_count: int) -> int:
	return maxi(GameConstants.KUDOS_MIN_ALLOTMENT,
			floori(round_count / float(GameConstants.KUDOS_PER_ROUNDS) + 0.5))


## Resolution rule this slice defines for Slice 6's setting (§6 rule 1):
## KUDOS_AUTO derives from rounds; any explicit value (incl. 0 = kudos off
## for this game) is used as-is - the min-1 clamp applies only in AUTO mode.
static func resolve_allotment(kudos_allotment_setting: int, round_count: int) -> int:
	if kudos_allotment_setting == GameSettings.KUDOS_AUTO:
		return compute_allotment(round_count)
	return maxi(0, kudos_allotment_setting)


func has_given(drawing_id: String, uid: String) -> bool:
	return (_givers_by_drawing.get(drawing_id, {}) as Dictionary).has(uid)


## Records an accepted kudos (validation happens in GameSession before this).
func add_kudos(drawing_id: String, uid: String) -> void:
	_kudos_by_drawing[drawing_id] = int(_kudos_by_drawing.get(drawing_id, 0)) + 1
	var givers: Dictionary = _givers_by_drawing.get_or_add(drawing_id, {})
	givers[uid] = true


func total_for(drawing_id: String) -> int:
	return int(_kudos_by_drawing.get(drawing_id, 0))


## Public aggregates (drawing_id -> total) - feeds the results bundle.
func totals() -> Dictionary:
	return _kudos_by_drawing.duplicate()
