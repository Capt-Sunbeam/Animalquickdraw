class_name EnetBackend
extends PlatformBackend
## Dev/LAN backend (skeleton guide §3.2). Room codes map to localhost ports:
## "LOCAL" -> 24515, "LOCAL2" -> 24516, ... so several sessions can coexist.
## Real room codes are a Steam-lobby concept (Slice 12).
## Identity: uuid persisted in user://profile.json; display name from the
## --name= user arg, else "Dev-<pid>".

const BASE_PORT: int = 24515
const PROFILE_PATH: String = "profile.json"

var _platform_id: String = ""


## Maps a dev room code to a localhost port. Returns -1 for invalid codes.
## "LOCAL" -> BASE_PORT; "LOCAL<n>" (n >= 2) -> BASE_PORT + n - 1.
static func port_for_code(raw_code: String) -> int:
	var code: String = raw_code.strip_edges().to_upper()
	if code == "LOCAL":
		return BASE_PORT
	if code.begins_with("LOCAL"):
		var suffix: String = code.trim_prefix("LOCAL")
		if suffix.is_valid_int():
			var n: int = suffix.to_int()
			if n >= 2:
				return BASE_PORT + n - 1
	return -1


## Extracts "--<key>=value" from a user-arg list ("" when absent).
static func arg_value(args: PackedStringArray, key: String, default: String = "") -> String:
	var prefix: String = "--%s=" % key
	for arg: String in args:
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return default


func get_display_name() -> String:
	var name_arg: String = arg_value(OS.get_cmdline_user_args(), "name")
	if not name_arg.is_empty():
		return name_arg
	return "Dev-%d" % OS.get_process_id()


func get_platform_id() -> String:
	if not _platform_id.is_empty():
		return _platform_id
	var profile: Dictionary = Save.read_json(PROFILE_PATH, {})
	var stored: String = str(profile.get("platform_id", ""))
	if stored.is_empty():
		stored = UuidV4.generate()
		profile["v"] = int(profile.get("v", 1))
		profile["platform_id"] = stored
		Save.write_json(PROFILE_PATH, profile)
	_platform_id = stored
	return _platform_id


func create_host_peer(room_code: String) -> MultiplayerPeer:
	var port: int = port_for_code(room_code)
	if port < 0:
		push_warning("EnetBackend: invalid dev room code '%s'" % room_code)
		return null
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, GameConstants.MAX_PLAYERS) != OK:
		return null
	return peer


func create_client_peer(room_code: String) -> MultiplayerPeer:
	var port: int = port_for_code(room_code)
	if port < 0:
		push_warning("EnetBackend: invalid dev room code '%s'" % room_code)
		return null
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client("127.0.0.1", port) != OK:
		return null
	return peer
