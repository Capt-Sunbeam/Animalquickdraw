class_name DrawingOp
extends RefCounted
## Base class for one entry in a DrawingDoc op list (Slice 1 §2).

enum Type { STROKE, FILL, CLEAR }

var type: Type
