class_name RevealDirector
extends RefCounted
## Host-side reveal choreography plan (Slice 5 TDD §6). Owned by
## GameSession; pure logic - GameSession emits the beats as signals and
## SessionClient is the metronome (same split as the phase pipeline).
## GRID style produces no beats; ONE_AT_A_TIME produces one beat per
## drawing (in the already-shuffled anonymous order) followed by a gather
## budget, after which JUDGING opens.

enum Step { BEATS, GATHER, DONE }

var _beats: Array[Dictionary] = []   # {"index": int, "drawing_id": String, "secs": float}
var _cursor: int = -1                # index of the beat currently playing
var _step: Step = Step.DONE


## entries = the REVEAL wire entries ({drawing_id, doc, caption}), already
## shuffled by GameSession. drawer_count feeds the shared replay budget.
func _init(style: GameSettings.RevealStyle, entries: Array[Dictionary],
		settings: GameSettings, drawer_count: int) -> void:
	if style != GameSettings.RevealStyle.ONE_AT_A_TIME:
		return
	for i: int in entries.size():
		var entry: Dictionary = entries[i]
		_beats.append({
			"index": i,
			"drawing_id": str(entry.get("drawing_id", "")),
			"secs": compute_beat_secs(entry.get("doc", {}),
					str(entry.get("caption", "")), settings, drawer_count),
		})
	_step = Step.BEATS if not _beats.is_empty() else Step.DONE


## The beat timeline table (TDD 05 §5): card-in + content + caption + hold
## + to-grid. Only FULL replay animates during reveal beats.
static func compute_beat_secs(doc: Dictionary, caption: String,
		settings: GameSettings, drawer_count: int) -> float:
	var secs: float = GameConstants.REVEAL_CARD_IN_SECS
	var replay: float = 0.0
	if settings.replay_mode == GameSettings.ReplayMode.FULL:
		replay = ReplayPlanner.replay_secs(doc,
				ReplayPlanner.reveal_timescale(doc, settings.reveal_replay_secs, drawer_count))
	secs += replay if replay > 0.0 else GameConstants.REVEAL_SHOW_FADE_SECS
	if not caption.is_empty():
		secs += GameConstants.REVEAL_CAPTION_SECS
	secs += GameConstants.REVEAL_REACT_HOLD_SECS
	secs += GameConstants.REVEAL_TO_GRID_SECS
	return secs


func has_beats() -> bool:
	return not _beats.is_empty()


## Total reveal duration: all beats + the final gather budget. The main
## REVEAL phase deadline is this plus a failsafe margin.
func total_secs() -> float:
	var total: float = 0.0
	for beat: Dictionary in _beats:
		total += float(beat["secs"])
	if not _beats.is_empty():
		total += GameConstants.REVEAL_TO_GRID_SECS   # gather budget
	return total


## Advances the plan. Returns the next action for the host to perform:
## {"beat": {...}} -> broadcast the beat; {"gather": secs} -> broadcast the
## gather; {} -> reveal finished, open JUDGING.
func next_action() -> Dictionary:
	match _step:
		Step.BEATS:
			_cursor += 1
			if _cursor < _beats.size():
				return {"beat": _beats[_cursor]}
			_step = Step.GATHER
			return {"gather": GameConstants.REVEAL_TO_GRID_SECS}
		Step.GATHER:
			_step = Step.DONE
			return {}
		_:
			return {}


func current_drawing_id() -> String:
	if _cursor >= 0 and _cursor < _beats.size():
		return str(_beats[_cursor]["drawing_id"])
	return ""


func is_done() -> bool:
	return _step == Step.DONE


func beats() -> Array[Dictionary]:
	return _beats
