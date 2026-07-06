class_name PlatformBackend
extends RefCounted
## Abstract seam between the game and the Steam-vs-dev environment
## (skeleton guide §3.2). EnetBackend implements it now; SteamBackend is a
## stub until Slice 12. Peer creation is a coroutine contract: Steam lobby
## create/join is callback-async, so callers always `await` these calls.
## EnetBackend returns immediately (still awaitable).


func get_display_name() -> String:
	return "Player"


## Stable per-install identity (dev: uuid from profile.json; Steam: SteamID64).
func get_platform_id() -> String:
	return ""


@warning_ignore("unused_parameter")
func create_host_peer(room_code: String) -> MultiplayerPeer:
	return null


@warning_ignore("unused_parameter")
func create_client_peer(room_code: String) -> MultiplayerPeer:
	return null


func supports_invites() -> bool:
	return false


func supports_lobby_browser() -> bool:
	return false
