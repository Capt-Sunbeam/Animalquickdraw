class_name LobbyListing
extends RefCounted
## Slice 13: one public-browser row, STRICTLY parsed from a Steam lobby's
## metadata. LobbyMetadata.parse is tolerant by design (the invite path
## wants harmless zeros); the browser wants malformed/forged/stale lobbies
## DROPPED, never rendered half-empty (TDD 13 §2). Rows are advisory only -
## the join handshake re-validates version/capacity/blocklist (§10).

## Wire values LobbyMetadata writes (its _MODE_NAMES/_POOL_NAMES ranges).
const MODES: Array[String] = ["default", "streamlined", "social", "custom"]
const POOL_TYPES: Array[String] = ["builtin", "player"]

var lobby_id: int = 0
var name: String = ""          # re-censored locally below (defense in depth)
var mode: String = ""
var players_cur: int = 0
var players_max: int = 0
var rounds: int = 0
var draw_time: int = 0         # seconds
var pool_type: String = ""


## Returns null when any required fact is missing, out of range, or
## version-incompatible - the row is silently dropped from the browser.
static func from_lobby_metadata(lobby_id_in: int, meta: Dictionary) -> LobbyListing:
	if lobby_id_in == 0:
		return null
	if not LobbyMetadata.proto_matches(meta):
		return null                     # version mismatch / foreign lobby
	var parsed: Dictionary = LobbyMetadata.parse(meta)
	if not bool(parsed["is_public"]) or str(parsed["state"]) != LobbyMetadata.STATE_LOBBY:
		return null                     # stale Steam-filter miss / forged flag
	if not MODES.has(str(parsed["mode"])) or not POOL_TYPES.has(str(parsed["pool_type"])):
		return null
	var players: int = int(parsed["players"])
	var max_players: int = int(parsed["max_players"])
	if players < 1 or max_players < GameConstants.MIN_PLAYERS \
			or max_players > GameConstants.MAX_PLAYERS or players > max_players:
		return null
	if int(parsed["rounds"]) < 1 or int(parsed["draw_time"]) < 1:
		return null
	if str(parsed["name"]).strip_edges().is_empty():
		return null
	var listing := LobbyListing.new()
	listing.lobby_id = lobby_id_in
	# A modified host writes arbitrary metadata: the honest host censored
	# this at write time, the browser censors AGAIN with the local blocklist
	# (belt and suspenders). Rendered via Label.text only - never markup
	# (Slice 13 security-audit rule).
	listing.name = TextFilter.censor(str(parsed["name"]))
	listing.mode = str(parsed["mode"])
	listing.players_cur = players
	listing.players_max = max_players
	listing.rounds = int(parsed["rounds"])
	listing.draw_time = int(parsed["draw_time"])
	listing.pool_type = str(parsed["pool_type"])
	return listing


func has_space() -> bool:
	return players_cur < players_max
