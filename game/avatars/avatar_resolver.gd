class_name AvatarResolver
extends RefCounted
## The one fallback chain for displaying any player anywhere (Slice 11 §6,
## brief §11): drawn avatar -> name circle -> deterministic house doodle.
## Pure and local - no RPCs, no awaits, safe to run on every chip bind.
## Simulation-safe: returns docs and kinds, never textures (cg §3).

enum Kind { DRAWN, NAME_CIRCLE, HOUSE }


class Resolved extends RefCounted:
	var kind: Kind = Kind.NAME_CIRCLE
	var doc: DrawingDoc = null       # DRAWN and HOUSE; null for NAME_CIRCLE
	var display_name: String = ""    # always set (tooltip everywhere)
	var house_index: int = -1        # HOUSE only


static var _house_docs: Array[DrawingDoc] = []
static var _house_loaded: bool = false


## avatar_doc: {} means none. A doc is re-validated here even when it came
## from the host (defense in depth - never rasterize unvalidated data);
## invalid == absent. Zero-op docs are not avatars (§6 rule 3).
static func resolve(avatar_doc: Dictionary, display_name: String,
		platform_id: String) -> Resolved:
	var out := Resolved.new()
	out.display_name = display_name
	if not avatar_doc.is_empty():
		var doc: DrawingDoc = DrawingDoc.from_dict(avatar_doc)
		if doc != null and doc.orientation == DrawingDoc.ORIENTATION_AVATAR \
				and not doc.ops.is_empty():
			out.kind = Kind.DRAWN
			out.doc = doc
			return out
	if not display_name.strip_edges().is_empty():
		out.kind = Kind.NAME_CIRCLE
		return out
	out.kind = Kind.HOUSE
	out.house_index = house_index_for(platform_id, display_name)
	out.doc = get_house_doc(out.house_index)
	return out


## Deterministic house pick: every peer computes the same index for the same
## player with zero syncing. Stable platform id first (same doodle across
## sessions and rejoins); name hash as the dev-edge fallback.
static func house_index_for(platform_id: String, display_name: String = "") -> int:
	var count: int = maxi(1, _loaded_house_count())
	var seed_text: String = platform_id if not platform_id.is_empty() else display_name
	return absi(seed_text.hash()) % count


## Lazy-loads and caches the shipped set. A malformed shipped file is a
## push_error + skip (screams in dev, degrades in prod - §10); the content
## parse test pins all HOUSE_AVATAR_COUNT files so it never ships broken.
static func get_house_doc(index: int) -> DrawingDoc:
	_ensure_house_loaded()
	if _house_docs.is_empty():
		return null
	return _house_docs[absi(index) % _house_docs.size()]


static func _loaded_house_count() -> int:
	_ensure_house_loaded()
	return _house_docs.size()


static func _ensure_house_loaded() -> void:
	if _house_loaded:
		return
	_house_loaded = true
	for i: int in GameConstants.HOUSE_AVATAR_COUNT:
		var file_path: String = "%shouse_%02d.json" % [GameConstants.HOUSE_AVATAR_DIR, i]
		var text: String = FileAccess.get_file_as_string(file_path)
		if text.is_empty():
			push_error("AvatarResolver: missing house avatar %s" % file_path)
			continue
		var parsed: Variant = JSON.parse_string(text)
		var doc: DrawingDoc = DrawingDoc.from_dict(parsed)
		if doc == null or doc.orientation != DrawingDoc.ORIENTATION_AVATAR:
			push_error("AvatarResolver: malformed house avatar %s" % file_path)
			continue
		_house_docs.append(doc)
