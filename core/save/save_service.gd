extends Node
## Autoload "Save" - atomic JSON persistence under user:// (skeleton guide
## §3.4). All paths are relative to user://; no direct FileAccess outside
## this file (consistency guide §6). Corrupt/missing files return the
## caller's default with a warning - the game never crashes on bad saves.


## Reads a JSON dictionary. Missing, unreadable, corrupt, or non-dictionary
## content returns `default` (warning logged for corrupt content).
func read_json(path: String, default: Dictionary) -> Dictionary:
	if not _path_ok(path):
		return default
	var full: String = _full(path)
	if not FileAccess.file_exists(full):
		return default
	var file: FileAccess = FileAccess.open(full, FileAccess.READ)
	if file == null:
		push_warning("Save: could not open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return default
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Save: %s is corrupt or not a JSON object; using default." % path)
		return default
	return parsed


## Atomic write: temp file + rename, so a crash mid-write never leaves a
## half-written save behind.
func write_json(path: String, data: Dictionary) -> Error:
	if not _path_ok(path):
		return ERR_INVALID_PARAMETER
	var full: String = _full(path)
	var dir_err: Error = _ensure_parent_dir(full)
	if dir_err != OK:
		return dir_err
	var tmp: String = full + ".tmp"
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("Save: could not open %s for writing (%s)" % [path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var rename_err: Error = DirAccess.rename_absolute(tmp, full)
	if rename_err != OK:
		push_warning("Save: atomic rename failed for %s (%s)" % [path, error_string(rename_err)])
		DirAccess.remove_absolute(tmp)
	return rename_err


func delete(path: String) -> Error:
	if not _path_ok(path):
		return ERR_INVALID_PARAMETER
	var full: String = _full(path)
	if not FileAccess.file_exists(full):
		return OK  # deleting a missing file is a successful no-op
	return DirAccess.remove_absolute(full)


func list_dir(path: String) -> PackedStringArray:
	if not _path_ok(path):
		return PackedStringArray()
	var dir: DirAccess = DirAccess.open(_full(path))
	if dir == null:
		return PackedStringArray()
	return dir.get_files()


func _full(path: String) -> String:
	return "user://" + path


## Rejects absolute paths and traversal - saves never escape user://.
func _path_ok(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.begins_with("user://") or path.contains(".."):
		push_error("Save: invalid path '%s' (must be relative to user://)" % path)
		return false
	return true


func _ensure_parent_dir(full_path: String) -> Error:
	var parent: String = full_path.get_base_dir()
	if DirAccess.dir_exists_absolute(parent):
		return OK
	return DirAccess.make_dir_recursive_absolute(parent)
