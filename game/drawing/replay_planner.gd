class_name ReplayPlanner
extends RefCounted
## Pure replay-timing math for host beat scheduling and victory laps
## (Slice 5 TDD §2). Mirrors ReplayPlayer's schedule rules EXACTLY (same
## gap-compression constant, same non-stroke beat) so the host's computed
## beat durations always match what clients actually render —
## test_planner_matches_player_schedule is the drift guard. No Image
## allocation, no scene deps: safe to call per-drawing on the host.


## Duration of the doc's drawing activity after idle-gap compression, at 1x.
## Malformed docs and degenerate (negative/non-finite) timestamps clamp to 0.
static func compressed_duration(doc: Dictionary) -> float:
	var parsed: DrawingDoc = DrawingDoc.from_dict(doc)
	if parsed == null:
		return 0.0
	var cursor: float = 0.0
	var natural_prev_end: float = 0.0
	for op: DrawingOp in parsed.ops:
		var natural_start: float = natural_prev_end
		var natural_end: float = natural_prev_end
		var duration: float = GameConstants.REPLAY_NON_STROKE_OP_SEC
		if op is Stroke:
			var stroke: Stroke = op
			natural_start = _finite(stroke.timestamps[0])
			natural_end = _finite(stroke.timestamps[stroke.timestamps.size() - 1])
			duration = maxf(natural_end - natural_start, 0.0)
		var gap: float = clampf(natural_start - natural_prev_end, 0.0,
				GameConstants.REPLAY_MAX_OP_GAP_SEC)
		if not is_finite(gap):
			gap = 0.0
		cursor += gap + duration
		natural_prev_end = maxf(natural_end, natural_prev_end)
	return maxf(cursor, 0.0)


## Timescale for a reveal-beat replay. target_secs is the host setting (a
## TARGET DURATION - owner decision 2026-07-06): strokes speed up to fit it,
## tightened further by an equal share of the total reveal budget, but a
## drawing shorter than the target replays at realtime, never slower.
static func reveal_timescale(doc: Dictionary, target_secs: float, drawer_count: int) -> float:
	var dur: float = compressed_duration(doc)
	if dur <= 0.0:
		return 1.0   # empty/instant docs replay "instantly" (caller skips animation)
	var target: float = minf(target_secs,
			GameConstants.REVEAL_REPLAY_BUDGET_SECS / float(maxi(1, drawer_count)))
	return maxf(1.0, dur / maxf(0.1, target))


## Timescale for the winner victory lap: fit the target duration exactly
## (30 s drawing / 5 s target = 6x; 30 s target = realtime), floor at 1x.
static func winner_timescale(doc: Dictionary, target_secs: float) -> float:
	var dur: float = compressed_duration(doc)
	if dur <= 0.0:
		return 1.0
	return maxf(1.0, dur / maxf(0.1, target_secs))


## Seconds a replay will actually take at the given timescale (for host
## beat scheduling). 0 for empty/instant docs.
static func replay_secs(doc: Dictionary, timescale: float) -> float:
	var dur: float = compressed_duration(doc)
	if dur <= 0.0 or timescale <= 0.0:
		return 0.0
	return dur / timescale


static func _finite(value: float) -> float:
	return value if is_finite(value) else 0.0
