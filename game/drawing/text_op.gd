class_name TextOp
extends DrawingOp
## One placed line of in-image text (Slice 16 §2). Position is the top-left
## of the first glyph cell in INTERNAL canvas coordinates; glyph pixels past
## the right/bottom edge clip at raster time. Content is host-censored at
## submission (and pre-censored locally at commit so the drawer sees what
## the table will see).

var color_index: int = 0   # index into Palette.COLORS
var size_index: int = 0    # 0 | 1 | 2 -> GameConstants.TEXT_SCALES
var x: int = 0
var y: int = 0
var text: String = ""      # 1..TEXT_MAX_CHARS chars, ASCII 32-126 only


func _init() -> void:
	type = Type.TEXT
