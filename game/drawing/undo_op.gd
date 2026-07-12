class_name UndoOp
extends DrawingOp
## Recorded undo marker (Slice 20): cancels the previous EFFECTIVE op via
## DrawingDoc.resolve_effective - never destructive to history, so replays
## show the undone work being drawn and then removed (owner request,
## 2026-07-12). Wire shape: {"t": "undo"}, no params.


func _init() -> void:
	type = Type.UNDO
