class_name ReactionGate
extends RefCounted
## Host-side gate deciding which drawings accept reaction/kudos requests
## right now (Slice 4 TDD §5). This slice wires JUDGING (open_all) and
## RESOLUTION (close); Slice 5's one-at-a-time reveal beats will call
## open_for per revealed drawing. close() honors a short grace window so a
## request racing the phase flip is accepted, not punished (§10 - favor flow).

var _open_ids: Dictionary = {}      # drawing_id -> true while open
var _closed_at_ms: int = 0          # 0 = currently open (or never opened)
var _grace_ids: Dictionary = {}     # snapshot of _open_ids at close()
var _now_ms: Callable


func _init(now_ms: Callable = Callable()) -> void:
	_now_ms = now_ms if now_ms.is_valid() else Callable(ReactionGate, "_system_now_ms")


## Slice 5: open exactly these drawings (one reveal beat). Deliberately
## does NOT clear a running close-grace: at beat boundaries the previous
## drawing's grace window keeps absorbing racing requests (§10) while the
## new drawing is already live.
func open_for(ids: PackedStringArray) -> void:
	_open_ids.clear()
	for id: String in ids:
		_open_ids[id] = true


## JUDGING: the whole round's reveal set accepts.
func open_all(ids: PackedStringArray) -> void:
	open_for(ids)


func close() -> void:
	if _open_ids.is_empty():
		return
	_grace_ids = _open_ids.duplicate()
	_open_ids.clear()
	_closed_at_ms = int(_now_ms.call())


func is_open_for(drawing_id: String) -> bool:
	if _open_ids.has(drawing_id):
		return true
	# In-flight requests inside the grace window still count (§10).
	if _closed_at_ms > 0 and _grace_ids.has(drawing_id) \
			and int(_now_ms.call()) - _closed_at_ms <= GameConstants.REACTION_CLOSE_GRACE_MSEC:
		return true
	return false


static func _system_now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
