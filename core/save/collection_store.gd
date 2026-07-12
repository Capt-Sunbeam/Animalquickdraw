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


# ---- Slice 8: read / delete / export surface ----


const EXPORT_DIR: String = "exports"
const SLUG_MAX_CHARS: int = 40


## Newest-first entries; malformed rows are skipped with a warning; an index
## from a NEWER app version is rejected whole (cg §6 versioning).
static func list_entries() -> Array[CollectionIndexEntry]:
	var index: Dictionary = _read_index()
	var out: Array[CollectionIndexEntry] = []
	if int(index.get("v", INDEX_VERSION)) > INDEX_VERSION:
		push_warning("CollectionStore: index version %s is newer than this build supports"
				% str(index.get("v")))
		return out
	for raw: Variant in index.get("items", []):
		var entry: CollectionIndexEntry = null
		if raw is Dictionary:
			entry = CollectionIndexEntry.from_dict(raw)
		if entry == null:
			push_warning("CollectionStore: skipping malformed index row (%s)" % str(raw))
			continue
		out.append(entry)
	# Append order IS chronological (single writer); reversing is newest-first
	# and, unlike sorting saved_at, keeps same-second saves stable.
	out.reverse()
	return out


## The item's DrawingDoc; null on missing file or corrupt/invalid content
## (Save + DrawingDoc.from_dict log the warnings - cg §7 degrade-never-break).
static func read_doc(id: String) -> DrawingDoc:
	if not _id_ok(id):
		return null
	var raw: Dictionary = Save.read_json("%s/%s.json" % [root_dir, id], {})
	if raw.is_empty():
		return null
	return DrawingDoc.from_dict(raw)


## Cached thumb if present AND the expected size for this orientation (a
## size mismatch means the thumb constants changed - regenerate); else
## regenerates from the doc (best-effort rewrite); null when the doc itself
## is gone (caller shows the missing-art placeholder).
static func get_thumb(id: String, orientation: StringName) -> Image:
	if not _id_ok(id):
		return null
	var expected: Vector2i = thumb_size_for(orientation)
	var cached: Image = Save.read_png(_thumb_path(id))
	if cached != null and Vector2i(cached.get_width(), cached.get_height()) == expected:
		return cached
	var doc: DrawingDoc = read_doc(id)
	if doc == null:
		return null
	var img: Image = _make_thumb(doc)
	Save.write_png(_thumb_path(id), img)   # failure = warning, never an error dialog
	return img


## Removes an item everywhere, INDEX-FIRST: a crash mid-delete can only
## orphan invisible files, never dangle a visible index row (TDD §6).
## Idempotent - deleting an id that isn't there returns OK.
static func delete(id: String) -> Error:
	if not _id_ok(id):
		return ERR_INVALID_PARAMETER
	var index: Dictionary = _read_index()
	var items: Array = index.get("items", [])
	for i: int in range(items.size()):
		if items[i] is Dictionary and str((items[i] as Dictionary).get("id", "")) == id:
			items.remove_at(i)
			index["items"] = items
			var err: Error = Save.write_json(_index_path(), index)
			if err != OK:
				return err   # item still visible; files intact - retryable
			break
	Save.delete("%s/%s.json" % [root_dir, id])   # best-effort from here:
	Save.delete(_thumb_path(id))                 # orphans are invisible (§10)
	return OK


## Rasterizes at the internal resolution, then upscales EXPORT_SCALE x with
## nearest-neighbor. Re-rastering at a higher resolution is deliberately
## rejected: brush stamps and flood-fill topology are not scale-invariant,
## so a "hi-res" export could differ from what the judge actually saw
## (determinism principle 4). Returns the user:// relative path, "" on failure.
static func export_png(id: String) -> String:
	var entry: CollectionIndexEntry = null
	for candidate: CollectionIndexEntry in list_entries():
		if candidate.id == id:
			entry = candidate
			break
	var doc: DrawingDoc = read_doc(id)
	if entry == null or doc == null:
		return ""
	var img: Image = DocRasterizer.rasterize(doc)
	img.resize(img.get_width() * GameConstants.EXPORT_SCALE,
			img.get_height() * GameConstants.EXPORT_SCALE, Image.INTERPOLATE_NEAREST)
	var path: String = "%s/%s_%s.png" % [EXPORT_DIR, slugify(entry.prompt), id.substr(0, 8)]
	if Save.write_png(path, img) != OK:
		return ""
	return path


## Filesystem-safe slug: lowercased, [a-z0-9] runs joined by single dashes,
## capped, "drawing" when nothing survives (player-created prompts can be
## arbitrarily hostile - Slice 7).
static func slugify(prompt: String) -> String:
	var out: String = ""
	var pending_dash: bool = false
	for ch: String in prompt.to_lower():
		var is_safe: bool = (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9")
		if is_safe:
			if pending_dash and not out.is_empty():
				out += "-"
			out += ch
			pending_dash = false
		else:
			pending_dash = true
	out = out.left(SLUG_MAX_CHARS).trim_suffix("-")
	return out if not out.is_empty() else "drawing"


## Expected thumb dimensions for an orientation (long edge capped at
## COLLECTION_THUMB_MAX_PX - Slice 4 shipped this; the TDD 08 draft's
## 256x192 was superseded by the existing constant).
static func thumb_size_for(orientation: StringName) -> Vector2i:
	var canvas: Vector2i = GameConstants.CANVAS_PORTRAIT \
			if orientation == DrawingDoc.ORIENTATION_PORTRAIT \
			else GameConstants.CANVAS_LANDSCAPE
	var scale: float = GameConstants.COLLECTION_THUMB_MAX_PX / float(maxi(canvas.x, canvas.y))
	return Vector2i(maxi(1, roundi(canvas.x * scale)), maxi(1, roundi(canvas.y * scale)))


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
	Save.write_png(_thumb_path(item_id), _make_thumb(doc))


## One thumb pipeline for save-time writes and Slice 8 regeneration.
static func _make_thumb(doc: DrawingDoc) -> Image:
	var img: Image = DocRasterizer.rasterize(doc)
	var long_edge: int = maxi(img.get_width(), img.get_height())
	if long_edge > GameConstants.COLLECTION_THUMB_MAX_PX:
		var scale: float = GameConstants.COLLECTION_THUMB_MAX_PX / float(long_edge)
		img.resize(maxi(1, roundi(img.get_width() * scale)),
				maxi(1, roundi(img.get_height() * scale)), Image.INTERPOLATE_BILINEAR)
	return img


static func _thumb_path(item_id: String) -> String:
	return "%s/thumbs/%s.png" % [root_dir, item_id]


## Item ids are uuids we minted - anything path-shaped is hostile input.
static func _id_ok(id: String) -> bool:
	return not id.is_empty() and not id.contains("/") and not id.contains("\\") \
			and not id.contains(".")
