extends Node
## Autoload "Platform" - facade over the active PlatformBackend
## (skeleton guide §3.2). Backend selection: --platform=enet|steam user arg
## wins; otherwise editor/dev runs default to enet and exported builds
## default to steam (Slice 12 flip). There is NO silent steam->enet
## fallback after a failed Steam init (design brief §13) - a failed init
## disables multiplayer for the run instead (see platform_ok).

var backend: PlatformBackend
## Convenience for UI affordances (Invite button, share-code text).
var is_steam: bool = false
## Result of backend initialization. false => multiplayer disabled this run;
## menus stay usable for local features (collection, avatar editor).
## Screens that load after boot read this instead of racing platform_ready.
var platform_ok: bool = true


func _ready() -> void:
	var kind: String = EnetBackend.arg_value(
			OS.get_cmdline_user_args(), "platform", default_platform_kind())
	match kind:
		"steam":
			backend = SteamBackend.new()
			is_steam = true
		"enet":
			backend = EnetBackend.new()
		_:
			push_warning("Unknown --platform=%s; using ENet dev backend." % kind)
			backend = EnetBackend.new()
	platform_ok = backend.initialize()
	EventBus.platform_ready.emit(platform_ok)


func _process(_delta: float) -> void:
	backend.run_frame()


## Editor/dev (incl. headless tests and dev_run.sh instances) => enet;
## exported builds (any template) => steam. Static + arg-driven for tests.
static func default_platform_kind() -> String:
	return "enet" if OS.has_feature("editor") else "steam"


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


## Coroutine - always await. Slice 12 invite path (known lobby id).
func create_client_peer_for_lobby(lobby_id: int) -> MultiplayerPeer:
	return await backend.create_client_peer_for_lobby(lobby_id)


## The room code to display (Steam: generated/joined 5-char code; ENet:
## the LOCAL dev code).
func get_room_code() -> String:
	return backend.get_room_code()


## Steam overlay friend picker; no-op on enet (button hidden anyway).
func open_invite_overlay() -> void:
	backend.open_invite_overlay()


## Host-only lobby metadata writes (Slice 12 schema; Session calls on
## create/settings/roster/state changes). No-op on enet.
func update_lobby_metadata(data: Dictionary) -> void:
	backend.update_lobby_metadata(data)


## Slice 14 gate: stats/achievements API ready.
func is_stats_ready() -> bool:
	return backend.is_stats_ready()


## Short reason key for the last failed host/join ("" = none/generic).
func get_last_failure_reason() -> String:
	return backend.get_last_failure_reason()


## Cold-launch invite: Steam started us with "+connect_lobby <id>".
## Checked once after boot; 0 = normal launch.
func get_launch_lobby() -> int:
	return LaunchArgs.connect_lobby(OS.get_cmdline_args())


func supports_invites() -> bool:
	return backend.supports_invites()


func supports_lobby_browser() -> bool:
	return backend.supports_lobby_browser()
