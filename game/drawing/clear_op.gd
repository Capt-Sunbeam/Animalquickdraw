class_name ClearOp
extends DrawingOp
## Wipes the canvas to Palette.CANVAS_BACKGROUND (Slice 1 §2). Recorded (not
## destructive to history) so replays show the wipe and undo can restore the
## pre-clear picture.


func _init() -> void:
	type = Type.CLEAR
