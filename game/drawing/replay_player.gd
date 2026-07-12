class_name ReplayPlayer
extends RefCounted
## Timed, capped stroke replay (Slice 1 §6). Deliberately NOT a node: pure
## logic driven by advance(delta) from whatever node hosts it (sandbox now,
## reveal screens in Slice 5), keeping it headless-testable.
##
## Schedule rules: within-stroke pacing is kept as-is (it IS the
## performance); idle gaps between ops are compressed to
## REPLAY_MAX_OP_GAP_SEC; fill/clear ops consume REPLAY_NON_STROKE_OP_SEC;
## the whole replay is rate-capped so compressed duration D finishes within
## REPLAY_MAX_DURATION_SEC regardless of the requested speed (brief §7).
## The replay end-state is bit-identical to DocRasterizer.rasterize(doc).

signal op_started(op_index: int)
signal finished()


class OpSchedule:
	extends RefCounted
	var start: float = 0.0
	var duration: float = 0.0


var _doc: DrawingDoc = null
var _image: Image = null
var _schedule: Array[OpSchedule] = []
var _total_duration: float = 0.0
var _rate: float = 1.0
var _playhead: float = 0.0
var _op_index: int = 0          # first op not yet fully applied
var _stamped_points: int = 0    # points already stamped in the current stroke
var _op_announced: bool = false
var _finished: bool = false


## speed_multiplier >= 1.0; caller (Slice 5/6 settings, sandbox UI) supplies
## it. enforce_duration_cap keeps the Slice 1 REPLAY_MAX_DURATION_SEC guard
## for callers with no plan of their own (sandbox); Slice 5 passes false -
## its ReplayPlanner timescales already encode the host-set target duration
## (which may legitimately exceed the old 10 s cap, e.g. realtime replays).
func load_doc(doc: DrawingDoc, speed_multiplier: float = 1.0,
		enforce_duration_cap: bool = true) -> void:
	_doc = doc
	_image = DocRasterizer.new_canvas_image(doc.canvas_size())
	_schedule.clear()
	_playhead = 0.0
	_op_index = 0
	_stamped_points = 0
	_op_announced = false
	_finished = false
	var cursor: float = 0.0
	var natural_prev_end: float = 0.0
	for op: DrawingOp in doc.ops:
		var entry := OpSchedule.new()
		var natural_start: float = natural_prev_end
		var natural_end: float = natural_prev_end
		if op is Stroke:
			var stroke: Stroke = op
			natural_start = stroke.timestamps[0]
			natural_end = stroke.timestamps[stroke.timestamps.size() - 1]
			entry.duration = maxf(natural_end - natural_start, 0.0)
		else:
			entry.duration = GameConstants.REPLAY_NON_STROKE_OP_SEC
		var gap: float = clampf(natural_start - natural_prev_end, 0.0, GameConstants.REPLAY_MAX_OP_GAP_SEC)
		entry.start = cursor + gap
		cursor = entry.start + entry.duration
		natural_prev_end = maxf(natural_end, natural_prev_end)
		_schedule.append(entry)
	_total_duration = cursor
	if _total_duration > 0.0 and enforce_duration_cap:
		_rate = maxf(speed_multiplier, _total_duration / GameConstants.REPLAY_MAX_DURATION_SEC)
	else:
		_rate = maxf(speed_multiplier, 1.0)


## Advances the playhead; returns false once finished. Call each frame.
func advance(delta: float) -> bool:
	if _finished:
		return false
	_playhead += delta * _rate
	_apply_up_to_playhead()
	if _op_index >= _doc.ops.size() and _playhead >= _total_duration:
		_finish()
		return false
	return true


## Current raster - push into an ImageTexture for display.
func get_image() -> Image:
	return _image


## Instant finish (Slice 5 "skip" affordance; Slice 8 viewer).
func skip_to_end() -> void:
	if _finished:
		return
	while _op_index < _doc.ops.size():
		var op: DrawingOp = _doc.ops[_op_index]
		if not _op_announced:
			op_started.emit(_op_index)
		if op is Stroke:
			# A partially stamped stroke resumes from its last stamped point
			# (so the connecting segment is not skipped); an untouched one
			# stamps fully from index 0.
			var stroke: Stroke = op
			DocRasterizer.stamp_stroke_range(_image, stroke, maxi(_stamped_points - 1, 0), stroke.points.size() - 1)
		elif op is UndoOp:
			# Slice 20: revert to the effective state incl. this marker.
			_image = DocRasterizer.rasterize_prefix(_doc, _op_index + 1)
		else:
			DocRasterizer.apply_op(_image, op)
		_advance_to_next_op()
	_playhead = _total_duration
	_finish()


## Effective playback rate (exposed for tests and host beat scheduling).
func get_rate() -> float:
	return _rate


func get_total_duration() -> float:
	return _total_duration


func _apply_up_to_playhead() -> void:
	while _op_index < _doc.ops.size():
		var entry: OpSchedule = _schedule[_op_index]
		if _playhead < entry.start:
			return
		var op: DrawingOp = _doc.ops[_op_index]
		if not _op_announced:
			_op_announced = true
			op_started.emit(_op_index)
		if op is Stroke:
			var stroke: Stroke = op
			var t0: float = stroke.timestamps[0]
			var target: int = _stamped_points
			while target < stroke.points.size() \
					and entry.start + (stroke.timestamps[target] - t0) <= _playhead:
				target += 1
			if target > _stamped_points:
				var from_idx: int = maxi(_stamped_points - 1, 0)
				DocRasterizer.stamp_stroke_range(_image, stroke, from_idx, target - 1)
				_stamped_points = target
			if _stamped_points < stroke.points.size():
				return  # mid-stroke; wait for more playhead
		elif op is UndoOp:
			# Slice 20: the undone work vanishes at op start (drawn -> beat ->
			# poof); one effective-prefix re-raster, same cost as the initial
			# raster. The beat duration is the usual non-stroke pacing.
			_image = DocRasterizer.rasterize_prefix(_doc, _op_index + 1)
			if _playhead < entry.start + entry.duration:
				_advance_to_next_op()
				return
		else:
			# Fill/clear apply at op start; their duration is a pacing beat.
			DocRasterizer.apply_op(_image, op)
			if _playhead < entry.start + entry.duration:
				_advance_to_next_op()
				return
		_advance_to_next_op()


func _advance_to_next_op() -> void:
	_op_index += 1
	_stamped_points = 0
	_op_announced = false


func _finish() -> void:
	if _finished:
		return
	_finished = true
	finished.emit()
