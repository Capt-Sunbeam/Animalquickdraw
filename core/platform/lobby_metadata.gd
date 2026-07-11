class_name LobbyMetadata
## Slice 12: pure builder/parser for the Steam lobby metadata schema
## (TDD 12 §2 - the contract Slice 13's browser consumes; additive keys
## only once shipped). Steam metadata is string-only, so every value here
## is a String. No Steam calls in this file - SteamBackend/Session feed
## dictionaries through Platform.update_lobby_metadata; Slice 13 reuses
## parse() on the read side.

const KEY_PROTO: String = "aq_proto"
const KEY_CODE: String = "aq_code"
const KEY_NAME: String = "aq_name"
const KEY_MODE: String = "aq_mode"
const KEY_PLAYERS: String = "aq_players"
const KEY_MAX_PLAYERS: String = "aq_max_players"
const KEY_ROUNDS: String = "aq_rounds"
const KEY_DRAW_TIME: String = "aq_draw_time"
const KEY_POOL_TYPE: String = "aq_pool_type"
const KEY_PUBLIC: String = "aq_public"
const KEY_STATE: String = "aq_state"

const STATE_LOBBY: String = "lobby"
const STATE_INGAME: String = "ingame"

## SettingsDefaults.Mode -> wire string (lowercase enum names, TDD 12 §2).
const _MODE_NAMES: Dictionary = {
	SettingsDefaults.Mode.DEFAULT: "default",
	SettingsDefaults.Mode.STREAMLINED: "streamlined",
	SettingsDefaults.Mode.SOCIAL: "social",
	SettingsDefaults.Mode.CUSTOM: "custom",
}

## GameSettings.PoolSource -> wire string ("prompt-pool type" browser column).
const _POOL_NAMES: Dictionary = {
	GameSettings.PoolSource.BUILT_IN: "builtin",
	GameSettings.PoolSource.PLAYER_CREATED: "player",
}


## The full metadata set written at lobby creation. settings is a
## GameSettings.to_dict() dictionary; host_name is censored here (Steam
## persona names are untrusted typed text like any other, guide §13).
static func build_full(code: String, host_name: String, settings: Dictionary,
		player_count: int, ingame: bool) -> Dictionary:
	var meta: Dictionary = {
		KEY_PROTO: NetIds.PROTOCOL_VERSION,
		KEY_CODE: code,
		KEY_NAME: "%s's game" % TextFilter.censor(host_name),
		KEY_MAX_PLAYERS: str(GameConstants.MAX_PLAYERS),
	}
	meta.merge(settings_keys(settings))
	meta.merge(players_key(player_count))
	meta.merge(state_key(ingame))
	return meta


## Only the settings-driven keys - written on every host settings change.
static func settings_keys(settings: Dictionary) -> Dictionary:
	return {
		KEY_MODE: str(_MODE_NAMES.get(int(settings.get("mode", 0)), "default")),
		KEY_ROUNDS: str(int(settings.get("round_count", 0))),
		KEY_DRAW_TIME: str(int(settings.get("draw_time_sec", 0.0))),
		KEY_POOL_TYPE: str(_POOL_NAMES.get(int(settings.get("pool_source", 0)), "builtin")),
		KEY_PUBLIC: "1" if bool(settings.get("is_public", false)) else "0",
	}


## Connected-player count - written on every roster change.
static func players_key(count: int) -> Dictionary:
	return {KEY_PLAYERS: str(count)}


## lobby/ingame flag - written at game start and on return to lobby.
static func state_key(ingame: bool) -> Dictionary:
	return {KEY_STATE: STATE_INGAME if ingame else STATE_LOBBY}


## Read side (Slice 13's browser rows; also the invite-path proto check).
## Tolerates missing keys with typed defaults - a foreign App-ID-480 lobby
## parses to harmless zeros rather than crashing a browser row.
static func parse(meta: Dictionary) -> Dictionary:
	return {
		"proto": str(meta.get(KEY_PROTO, "")),
		"code": str(meta.get(KEY_CODE, "")),
		"name": str(meta.get(KEY_NAME, "")),
		"mode": str(meta.get(KEY_MODE, "default")),
		"players": str(meta.get(KEY_PLAYERS, "0")).to_int(),
		"max_players": str(meta.get(KEY_MAX_PLAYERS, "0")).to_int(),
		"rounds": str(meta.get(KEY_ROUNDS, "0")).to_int(),
		"draw_time": str(meta.get(KEY_DRAW_TIME, "0")).to_int(),
		"pool_type": str(meta.get(KEY_POOL_TYPE, "builtin")),
		"is_public": str(meta.get(KEY_PUBLIC, "0")) == "1",
		"state": str(meta.get(KEY_STATE, STATE_LOBBY)),
	}


## Exact-match protocol gate. The search path enforces this via a string
## filter; the invite path (which bypasses search) calls it explicitly
## before creating a peer (TDD 12 §10 version mismatch).
static func proto_matches(meta: Dictionary) -> bool:
	return str(meta.get(KEY_PROTO, "")) == NetIds.PROTOCOL_VERSION
