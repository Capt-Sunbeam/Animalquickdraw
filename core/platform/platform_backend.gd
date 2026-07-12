class_name PlatformBackend
extends RefCounted
## Abstract seam between the game and the Steam-vs-dev environment
## (skeleton guide §3.2). EnetBackend implements it now; SteamBackend is a
## stub until Slice 12. Peer creation is a coroutine contract: Steam lobby
## create/join is callback-async, so callers always `await` these calls.
## EnetBackend returns immediately (still awaitable).


## One-time startup init. false => multiplayer disabled this run (Slice 12:
## Steam absent/init failure). There is NO silent steam->enet fallback -
## a failed init never swaps transports implicitly (design brief §13).
func initialize() -> bool:
	return true


## Called every frame by Platform._process while this backend is active
## (Slice 12: Steam.run_callbacks() pump - nothing works without it).
func run_frame() -> void:
	pass


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


## Slice 12 invite path: join a known lobby directly, skipping code
## resolution. Coroutine like the create_*_peer pair.
@warning_ignore("unused_parameter")
func create_client_peer_for_lobby(lobby_id: int) -> MultiplayerPeer:
	return null


## The code to display in the lobby screen (ENet: the LOCAL dev code as
## typed; Steam: the generated 5-char code / the joined lobby's code).
func get_room_code() -> String:
	return ""


## No-op unless supports_invites() (Slice 12: Steam overlay friend picker).
func open_invite_overlay() -> void:
	pass


## Host-only; writes lobby metadata (Slice 12 schema). ENet: no-op.
@warning_ignore("unused_parameter")
func update_lobby_metadata(data: Dictionary) -> void:
	pass


## Called from Net.leave() on every teardown path (Slice 12: leaveLobby +
## clearRichPresence - prompt leaves prevent ghost lobbies in code searches).
func leave_cleanup() -> void:
	pass


## Slice 14 gate: the Steamworks stats API is ready for definitions/unlocks.
func is_stats_ready() -> bool:
	return false


# --- Slice 14: achievement mirror (ENet keeps the no-ops - dev builds
# exercise the full local stats pipeline with Steam calls silently skipped;
# reconcile-from-counters pushes everything on the next Steam launch). ---


## True when the achievement is already set on Steam (guards redundant calls).
@warning_ignore("unused_parameter")
func steam_achievement_is_set(achievement_id: String) -> bool:
	return false


@warning_ignore("unused_parameter")
func steam_set_achievement(achievement_id: String) -> void:
	pass


## One storeStats per unlock batch (StatsService calls after its loop).
func steam_store_stats() -> void:
	pass


## Short reason key for the last failed host/join ("full", "not_found",
## "version_mismatch", "" = none/generic). UI maps to friendly toasts.
func get_last_failure_reason() -> String:
	return ""


func supports_invites() -> bool:
	return false


func supports_lobby_browser() -> bool:
	return false


## Slice 13 public browser: list open public lobbies. Coroutine like the
## peer calls (ENet returns immediately - still awaitable). Shape:
## {"ok": bool, "lobbies": [{"id": int, "meta": Dictionary}]}. ok=false =
## the request itself failed/unsupported; empty lobbies with ok=true is a
## legitimate "no open games".
func request_lobby_list() -> Dictionary:
	return {"ok": false, "lobbies": []}
