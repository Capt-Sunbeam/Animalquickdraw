class_name AvatarStore
extends RefCounted
## The local player's avatar file (Slice 11 §4): exactly one DrawingDoc with
## orientation "avatar" at user://avatar.json, written atomically through
## Save. Presence of the file IS the "has avatar" state - no duplicated meta
## in profile.json (§4). `path` is a test seam (CollectionStore.root_dir
## pattern) so suites never touch a real player's avatar.

static var path: String = "avatar.json"


## Parsed local avatar; null = none (missing file, corrupt content, wrong
## orientation, or zero ops - an empty doc is not an avatar, §6 rule 3).
## Corrupt-but-present files warn and are LEFT untouched (a newer-version
## doc must survive a downgrade round-trip, §10).
static func load_doc() -> DrawingDoc:
	var raw: Dictionary = Save.read_json(path, {})
	if raw.is_empty():
		return null
	var doc: DrawingDoc = DrawingDoc.from_dict(raw)
	if doc == null or doc.orientation != DrawingDoc.ORIENTATION_AVATAR:
		push_warning("AvatarStore: %s exists but is not a valid avatar doc" % path)
		return null
	if doc.ops.is_empty():
		return null
	return doc


static func save_doc(doc: DrawingDoc) -> Error:
	if doc == null or doc.ops.is_empty():
		return ERR_INVALID_DATA   # empty docs are never written (§4)
	return Save.write_json(path, doc.to_dict())


static func clear() -> Error:
	return Save.delete(path)
