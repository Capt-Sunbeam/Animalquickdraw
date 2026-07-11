class_name LaunchArgs
## Slice 12: cold-launch invite parsing. When a friend uses "Join Game" /
## accepts an invite while the game is CLOSED, Steam starts the app with
## "+connect_lobby <id>" appended to the command line (two tokens, not a
## --key=value user arg). Checked once at boot after platform_ready(true).


## Returns the lobby id from "+connect_lobby <id>", or 0 when absent or
## malformed. Never throws on hostile input - it is a command line.
static func connect_lobby(args: PackedStringArray) -> int:
	var idx: int = args.find("+connect_lobby")
	if idx == -1 or idx + 1 >= args.size():
		return 0
	var raw: String = args[idx + 1]
	if not raw.is_valid_int():
		return 0
	var lobby_id: int = raw.to_int()
	return lobby_id if lobby_id > 0 else 0
