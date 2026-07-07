class_name Submission
extends RefCounted
## One accepted drawing submission (Slice 3 TDD §2). Host-only - author
## identity never leaves the host before RESOLUTION.

var drawing_id: String = ""        # uuidv4 minted by the host at collect time
var author_player_id: String = ""  # HOST-PRIVATE until RESOLUTION
var doc: Dictionary = {}           # serialized DrawingDoc (cg §6 wire format)
var is_blank: bool = false         # host-synthesized for a missing drawer
var caption: String = ""           # Slice 5: host-censored, anonymous, session-transient


static func blank_doc() -> Dictionary:
	return {"v": 1, "orientation": "landscape", "ops": []}
