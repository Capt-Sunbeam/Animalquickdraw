class_name AvatarStore
extends RefCounted
## The local player's avatar file (Slice 11 §4): exactly one DrawingDoc with
## orientation "avatar" at user://avatar.json, written atomically through
## Save. Presence of the file IS the "has avatar" state - no duplicated meta
## in profile.json (§4). `path` is a test seam (CollectionStore.root_dir
## pattern) so suites never touch a real player's avatar.

static var path: String = default_path_for_args(OS.get_cmdline_user_args())


## Dev instances on one machine share user://, so they would all read the
## same avatar file (same problem, same cure as
## EnetBackend.disambiguate_platform_id): a --name= user arg namespaces the
## file ("avatar_P2.json") so local playtest instances keep distinct
## avatars. Steam builds launch without user args -> plain "avatar.json";
## this is dev-only.
static func default_path_for_args(args: PackedStringArray) -> String:
	if EnetBackend.arg_value(args, "platform", "enet") != "enet":
		return "avatar.json"
	var tag: String = _name_tag(EnetBackend.arg_value(args, "name"))
	if tag.is_empty():
		return "avatar.json"
	return "avatar_%s.json" % tag


## Filesystem-safe subset of the --name arg (Save._path_ok rejects ".."
## anywhere in a path, so whitelist instead of patching characters out).
static func _name_tag(raw: String) -> String:
	var tag: String = ""
	for i: int in raw.length():
		var ch: String = raw[i]
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") \
				or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			tag += ch
	return tag


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
