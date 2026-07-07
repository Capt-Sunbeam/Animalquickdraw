class_name CollectionStore
extends RefCounted
## Local collection write path (Slice 4 TDD §4/§6): index.json + one
## canonical DrawingDoc json per saved drawing + a regenerable PNG thumb.
## Uses only the Save API - no direct FileAccess (consistency guide §6).
## Slice 8's browser reads this layout.

const INDEX_VERSION: int = 1

const SOURCE_KUDOS: String = "kudos"
const SOURCE_SELF: String = "self"

## Test seam: collection root under user://. Tests point this at a sandbox
## dir (and restore it) so suites never touch a real player collection.
## Gameplay code never changes it.
static var root_dir: String = "collection"


## Saves a drawing to the local collection. Idempotent per
## session_drawing_id (a retry or double-fire can never double-write).
## Returns the collection item id, or "" on failure - callers toast via
## EventBus.collection_save_failed; a failed save never rolls back the kudos
## (host truth and local disk are decoupled, §10).
static func save_drawing(doc: Dictionary, prompt_text: String,
		session_drawing_id: String, source: String) -> String:
	var index: Dictionary = _read_index()
	var existing: String = _find_by_session_id(index, session_drawing_id)
	if not existing.is_empty():
		return existing                      # duplicate - no rewrite (§10)
	var parsed: DrawingDoc = DrawingDoc.from_dict(doc)
	if parsed == null:
		push_warning("CollectionStore: refusing to save malformed doc")
		EventBus.collection_save_failed.emit()
		return ""
	var item_id: String = UuidV4.generate()
	# Doc before index: a dangling index entry would surface as a broken item
	# in the Slice 8 browser; an orphaned doc file is invisible.
	if Save.write_json("%s/%s.json" % [root_dir, item_id], doc) != OK:
		EventBus.collection_save_failed.emit()
		return ""
	var items: Array = index.get("items", [])
	items.append({
		"id": item_id,
		"prompt": prompt_text,
		"saved_at": Time.get_datetime_string_from_system(),  # local wall clock, ISO 8601
		"orientation": String(parsed.orientation),
		"source": source,
		"session_drawing_id": session_drawing_id,
	})
	index["items"] = items
	if Save.write_json(_index_path(), index) != OK:
		EventBus.collection_save_failed.emit()
		return ""
	_write_thumb(item_id, parsed)            # failure non-fatal - cache only
	EventBus.collection_item_added.emit(item_id)
	return item_id


static func has_session_drawing(session_drawing_id: String) -> bool:
	return not _find_by_session_id(_read_index(), session_drawing_id).is_empty()


# --- Private ---


static func _index_path() -> String:
	return "%s/index.json" % root_dir


static func _read_index() -> Dictionary:
	# Corrupt/missing index recovers to empty (Save.read_json logs the warning).
	var index: Dictionary = Save.read_json(_index_path(), {"v": INDEX_VERSION, "items": []})
	if not index.get("items") is Array:
		index = {"v": INDEX_VERSION, "items": []}
	return index


static func _find_by_session_id(index: Dictionary, session_drawing_id: String) -> String:
	if session_drawing_id.is_empty():
		return ""
	for raw: Variant in index.get("items", []):
		if raw is Dictionary and str((raw as Dictionary).get("session_drawing_id", "")) == session_drawing_id:
			return str((raw as Dictionary).get("id", ""))
	return ""


static func _write_thumb(item_id: String, doc: DrawingDoc) -> void:
	var img: Image = DocRasterizer.rasterize(doc)
	var long_edge: int = maxi(img.get_width(), img.get_height())
	if long_edge > GameConstants.COLLECTION_THUMB_MAX_PX:
		var scale: float = GameConstants.COLLECTION_THUMB_MAX_PX / float(long_edge)
		img.resize(maxi(1, roundi(img.get_width() * scale)),
				maxi(1, roundi(img.get_height() * scale)), Image.INTERPOLATE_BILINEAR)
	Save.write_png("%s/thumbs/%s.png" % [root_dir, item_id], img)
