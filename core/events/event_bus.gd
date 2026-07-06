extends Node
## Autoload "EventBus" - typed cross-feature signals (consistency guide §5).
## Only genuinely cross-feature events belong here; slices append their
## signals with doc comments. Clients never emit game-state signals from
## local guesses - only in response to host rpc_sync_*/rpc_do_* messages.

## Emitted when a peer connects to the active session (relayed by Net).
signal peer_connected(peer_id: int)
## Emitted when a peer disconnects from the active session (relayed by Net).
signal peer_disconnected(peer_id: int)
## Emitted on a client when its connection attempt to a host fails.
signal connection_failed()
## Emitted on a client when the server closed the connection.
signal server_disconnected()
## Emitted after Nav swaps to a new screen. route is the scene path.
signal scene_changed(route: String)
