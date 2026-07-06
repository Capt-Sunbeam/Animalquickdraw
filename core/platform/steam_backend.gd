class_name SteamBackend
extends PlatformBackend
## Stub - filled in by Slice 12 (GodotSteam identity + SDR relay transport).
## GodotSteam is deliberately NOT installed in the skeleton, so this class
## must never touch Steam APIs. Selecting --platform=steam before Slice 12
## fails loudly rather than silently falling back to a non-relay transport
## (design brief §13).


func get_display_name() -> String:
	return "Player"


@warning_ignore("unused_parameter")
func create_host_peer(room_code: String) -> MultiplayerPeer:
	push_error("SteamBackend is not implemented until Slice 12; run with --platform=enet.")
	return null


@warning_ignore("unused_parameter")
func create_client_peer(room_code: String) -> MultiplayerPeer:
	push_error("SteamBackend is not implemented until Slice 12; run with --platform=enet.")
	return null
