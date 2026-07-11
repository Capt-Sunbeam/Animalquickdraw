class_name RoomCode
## Slice 12: 5-char human room codes for Steam lobbies. Generated host-side
## at lobby creation, stored as lobby metadata aq_code, joined via a lobby
## search string-filtered on that key. The alphabet drops 0/O/1/I/L so codes
## survive being read aloud or scrawled on a napkin (~33.5M combinations).
## ENet dev codes ("LOCAL", "LOCAL2") are a separate namespace and never
## pass is_valid - EnetBackend maps them to ports itself.


static func generate() -> String:
	var chars: PackedStringArray = []
	for i: int in GameConstants.ROOM_CODE_LENGTH:
		chars.append(GameConstants.ROOM_CODE_ALPHABET[randi() % GameConstants.ROOM_CODE_ALPHABET.length()])
	return "".join(chars)


## Uppercases and trims user input; the join dialog calls this as-you-type.
static func normalize(raw: String) -> String:
	return raw.strip_edges().to_upper()


## True when the (normalized) code has the right length and alphabet.
static func is_valid(code: String) -> bool:
	if code.length() != GameConstants.ROOM_CODE_LENGTH:
		return false
	for ch: String in code:
		if not GameConstants.ROOM_CODE_ALPHABET.contains(ch):
			return false
	return true
