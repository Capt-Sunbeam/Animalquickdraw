extends Node
## Autoload "Net" - peer lifecycle (skeleton guide §3.3): host/join/leave via
## the Platform backend, relaying Godot connection signals into typed
## EventBus signals. No game semantics here - roster/session logic is
## Slices 2/3.


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Coroutine - await it. Creates a server peer for the given room code.
func host(room_code: String) -> Error:
	var peer: MultiplayerPeer = await Platform.create_host_peer(room_code)
	if peer == null:
		return ERR_CANT_CREATE
	multiplayer.multiplayer_peer = peer
	return OK


## Coroutine - await it. Connects to the host behind the given room code.
func join(room_code: String) -> Error:
	var peer: MultiplayerPeer = await Platform.create_client_peer(room_code)
	if peer == null:
		return ERR_CANT_CONNECT
	multiplayer.multiplayer_peer = peer
	return OK


## Coroutine - await it. Slice 12 invite/cold-launch path: connects via a
## known Steam lobby id, skipping code resolution.
func join_lobby(lobby_id: int) -> Error:
	var peer: MultiplayerPeer = await Platform.create_client_peer_for_lobby(lobby_id)
	if peer == null:
		return ERR_CANT_CONNECT
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	if has_active_peer():
		multiplayer.multiplayer_peer.close()
	# Assigning null restores Godot's OfflineMultiplayerPeer.
	multiplayer.multiplayer_peer = null
	# Slice 12: backend teardown (Steam: leaveLobby + clearRichPresence).
	# Runs on every leave path incl. server_disconnected, so ghost lobbies
	# never linger to match future code searches.
	Platform.backend.leave_cleanup()


func has_active_peer() -> bool:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null or peer is OfflineMultiplayerPeer:
		return false
	return peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func is_host() -> bool:
	return has_active_peer() and multiplayer.is_server()


func local_peer_id() -> int:
	return multiplayer.get_unique_id() if has_active_peer() else 0


func _on_peer_connected(peer_id: int) -> void:
	EventBus.peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	EventBus.peer_disconnected.emit(peer_id)


func _on_connection_failed() -> void:
	leave()
	EventBus.connection_failed.emit()


func _on_server_disconnected() -> void:
	leave()
	EventBus.server_disconnected.emit()
