extends Node
## Autoload "Platform" - facade over the active PlatformBackend
## (skeleton guide §3.2). Backend selection: --platform=enet|steam user arg;
## defaults to enet (dev) until Slice 12 flips the export-release default.

var backend: PlatformBackend


func _ready() -> void:
	var kind: String = EnetBackend.arg_value(OS.get_cmdline_user_args(), "platform", "enet")
	match kind:
		"steam":
			backend = SteamBackend.new()
		"enet":
			backend = EnetBackend.new()
		_:
			push_warning("Unknown --platform=%s; using ENet dev backend." % kind)
			backend = EnetBackend.new()


func get_display_name() -> String:
	return backend.get_display_name()


func get_platform_id() -> String:
	return backend.get_platform_id()


## Coroutine - always await (skeleton guide §3.2).
func create_host_peer(room_code: String) -> MultiplayerPeer:
	return await backend.create_host_peer(room_code)


## Coroutine - always await (skeleton guide §3.2).
func create_client_peer(room_code: String) -> MultiplayerPeer:
	return await backend.create_client_peer(room_code)


func supports_invites() -> bool:
	return backend.supports_invites()


func supports_lobby_browser() -> bool:
	return backend.supports_lobby_browser()
