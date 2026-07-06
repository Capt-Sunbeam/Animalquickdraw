class_name TextFilter
## Blocklist filter for all typed text (skeleton guide §3.8; brief §13).
## Case-insensitive, substring-with-word-boundary matching against
## res://data/blocklist.txt (one word per line, # comments). Applied to
## chat, captions, and custom words by later slices - always on the host.

const BLOCKLIST_PATH: String = "res://data/blocklist.txt"
const CENSOR_TEXT: String = "***"

static var _regex: RegEx = null
static var _load_attempted: bool = false


## True when the text contains no blocklisted word.
static func is_clean(text: String) -> bool:
	var regex: RegEx = _get_regex()
	if regex == null:
		return true
	return regex.search(text) == null


## Replaces every blocklisted word with CENSOR_TEXT.
static func censor(text: String) -> String:
	var regex: RegEx = _get_regex()
	if regex == null:
		return text
	return regex.sub(text, CENSOR_TEXT, true)


## Test seam: replaces the loaded blocklist with an explicit word list.
## Pass an empty array to reload from disk on next use.
static func configure(words: PackedStringArray) -> void:
	if words.is_empty():
		_regex = null
		_load_attempted = false
	else:
		_regex = _build_regex(words)
		_load_attempted = true


static func _get_regex() -> RegEx:
	if not _load_attempted:
		_load_attempted = true
		_regex = _build_regex(_load_words())
	return _regex


static func _load_words() -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	var file: FileAccess = FileAccess.open(BLOCKLIST_PATH, FileAccess.READ)
	if file == null:
		push_warning("TextFilter: could not open %s; filtering disabled." % BLOCKLIST_PATH)
		return words
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		words.append(line)
	return words


static func _build_regex(words: PackedStringArray) -> RegEx:
	if words.is_empty():
		return null
	var escaped: PackedStringArray = PackedStringArray()
	for word: String in words:
		escaped.append(_regex_escape(word.to_lower()))
	var pattern: String = "(?i)\\b(?:%s)\\b" % "|".join(escaped)
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		push_error("TextFilter: blocklist regex failed to compile; filtering disabled.")
		return null
	return regex


static func _regex_escape(word: String) -> String:
	var specials: String = "\\^$.|?*+()[]{}"
	var out: String = ""
	for ch: String in word:
		if specials.contains(ch):
			out += "\\" + ch
		else:
			out += ch
	return out
