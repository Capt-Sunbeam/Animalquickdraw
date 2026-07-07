class_name PromptPools
extends RefCounted
## Loads word pools + pool types from JSON content, draws prompts through a
## PoolType, and enforces no-exact-combo-repeat per session (Slice 3 TDD §6).
## Content is res:// data (read directly - Save handles only user://).
## Missing/corrupt content is a push_error + empty pool; the lobby start
## gate checks is_ready() so a session can never start without content.

const DATA_DIR: String = "res://game/prompts/data/"
const POOL_TYPES_FILE: String = "pool_types.json"

## Public so tests can seed deterministic draws.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _pools: Dictionary = {}            # pool_id -> PackedStringArray
var _types: Dictionary = {}            # type_id -> PoolType
var _custom_sources: Dictionary = {}   # Slice 7 extension point (stub)
var _drawn_combo_keys: Dictionary = {} # combo_key -> true (session-scoped set)


func _init() -> void:
	rng.randomize()


func load_builtin() -> void:
	load_from(DATA_DIR)


## Test seam: fixtures load through the same path as real content.
func load_from(dir: String) -> void:
	_pools.clear()
	_types.clear()
	_drawn_combo_keys.clear()
	var types_raw: Dictionary = _read_json(dir.path_join(POOL_TYPES_FILE))
	for raw: Variant in types_raw.get("types", []):
		if not raw is Dictionary:
			continue
		var t: PoolType = PoolType.from_dict(raw)
		if t.id.is_empty() or t.draws.is_empty() or t.template.is_empty():
			push_error("PromptPools: malformed pool type entry skipped (%s)" % str(raw))
			continue
		_types[t.id] = t
	for type: PoolType in _types.values():
		for d: Dictionary in type.draws:
			var pool_id: String = str(d["pool"])
			if pool_id.is_empty() or _pools.has(pool_id):
				continue
			_pools[pool_id] = _load_pool(dir, pool_id)


func is_ready() -> bool:
	if _types.is_empty():
		return false
	for type: PoolType in _types.values():
		for d: Dictionary in type.draws:
			var words: PackedStringArray = _pools.get(str(d["pool"]), PackedStringArray())
			if words.size() < int(d["count"]):
				return false
	return true


func get_type(type_id: String) -> PoolType:
	var t: PoolType = _types.get(type_id)
	if t == null:
		push_error("PromptPools: unknown pool type '%s'" % type_id)
	return t


func pool_size(pool_id: String) -> int:
	var words: PackedStringArray = _pools.get(pool_id, PackedStringArray())
	return words.size()


## Slice 7 extension point: injects a session-scoped custom word list
## consumed before the built-in list (draw-without-replacement + silent
## backfill semantics are defined in Slice 7 - stored but unused here).
func set_custom_source(pool_id: String, words: PackedStringArray) -> void:
	_custom_sources[pool_id] = words


## Draws through the type, retrying on exact-combo repeats. On exhaustion,
## allows the repeat with a warning - never stall the round (cg §7; with
## the 100x100 built-in space this is unreachable in practice).
func draw_prompt(type: PoolType) -> Prompt:
	for attempt: int in range(GameConstants.COMBO_REPEAT_MAX_ATTEMPTS):
		var candidate: Prompt = _compose(type)
		if not _drawn_combo_keys.has(candidate.combo_key):
			_drawn_combo_keys[candidate.combo_key] = true
			return candidate
	push_warning("PromptPools: combo space exhausted for '%s'; allowing a repeat." % type.id)
	var repeat: Prompt = _compose(type)
	_drawn_combo_keys[repeat.combo_key] = true
	return repeat


func _compose(type: PoolType) -> Prompt:
	var parts := PackedStringArray()
	for d: Dictionary in type.draws:
		var words: PackedStringArray = _pools.get(str(d["pool"]), PackedStringArray())
		var count: int = int(d["count"])
		parts.append_array(_sample_without_replacement(words, count))
	return Prompt.make(type, parts)


## Distinct words within one draw spec ("cat-cat hybrid" is not a prompt).
func _sample_without_replacement(words: PackedStringArray, count: int) -> PackedStringArray:
	var picked := PackedStringArray()
	if words.is_empty() or count <= 0:
		push_error("PromptPools: draw from empty/insufficient pool")
		return picked
	var indices: Array[int] = []
	for i: int in range(words.size()):
		indices.append(i)
	for n: int in range(mini(count, indices.size())):
		var pick: int = rng.randi_range(0, indices.size() - 1)
		picked.append(words[indices[pick]])
		indices.remove_at(pick)
	return picked


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("PromptPools: missing content file %s" % path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("PromptPools: could not open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("PromptPools: %s is corrupt or not a JSON object" % path)
		return {}
	return parsed


func _load_pool(dir: String, pool_id: String) -> PackedStringArray:
	var raw: Dictionary = _read_json(dir.path_join(pool_id + ".json"))
	var words := PackedStringArray()
	for w: Variant in raw.get("words", []):
		var word: String = str(w).strip_edges()
		if not word.is_empty():
			words.append(word)
	if words.is_empty():
		push_error("PromptPools: pool '%s' is empty" % pool_id)
	return words
