class_name CollectionIndexEntry
extends RefCounted
## One row of the collection index (Slice 4 write contract, restated here as
## Slice 8's binding read contract). saved_at is an ISO 8601 LOCAL datetime
## STRING - Slice 4 reality; the Slice 8 TDD draft said unix seconds. ISO
## strings sort lexicographically, so ordering needs no parsing.

var id: String = ""
var prompt: String = ""
var saved_at: String = ""                # ISO 8601, local clock at save time
var orientation: StringName = DrawingDoc.ORIENTATION_LANDSCAPE
var source: String = ""                  # CollectionStore.SOURCE_KUDOS | SOURCE_SELF
var session_drawing_id: String = ""


## null on a malformed row (missing/empty id or prompt of the wrong type) -
## the browser skips those with a warning, never crashes (cg §7).
static func from_dict(data: Dictionary) -> CollectionIndexEntry:
	var id_raw: Variant = data.get("id")
	var prompt_raw: Variant = data.get("prompt")
	if not id_raw is String or str(id_raw).is_empty() or not prompt_raw is String:
		return null
	var entry := CollectionIndexEntry.new()
	entry.id = str(id_raw)
	entry.prompt = str(prompt_raw)
	entry.saved_at = str(data.get("saved_at", ""))
	var orient := StringName(str(data.get("orientation", "landscape")))
	entry.orientation = orient if DrawingDoc.KNOWN_ORIENTATIONS.has(orient) \
			else DrawingDoc.ORIENTATION_LANDSCAPE
	entry.source = str(data.get("source", ""))
	entry.session_drawing_id = str(data.get("session_drawing_id", ""))
	return entry


func to_dict() -> Dictionary:
	return {
		"id": id,
		"prompt": prompt,
		"saved_at": saved_at,
		"orientation": String(orientation),
		"source": source,
		"session_drawing_id": session_drawing_id,
	}


## "2026-07-07T18:30:05" -> "2026-07-07" for the viewer header.
func saved_date() -> String:
	return saved_at.substr(0, 10)
