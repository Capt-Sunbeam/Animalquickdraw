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

# --- Slice 2: Lobby & Session Roster ---

## Roster mirror replaced on this peer. players = Array of PlayerState dicts.
signal roster_updated(players: Array)
## Lobby settings mirror replaced on this peer.
signal lobby_settings_changed(settings: Dictionary)
## A chat message cleared host filtering and was broadcast.
signal chat_message_received(sender_peer_id: int, sender_name: String, text: String)
## Host pressed Start; settings/roster are frozen. Slice 3 takes over from here.
signal game_started(start_data: Dictionary)
## This peer left or was rejected/disconnected; UI should return to menu.
## reason is a short key ("left", "host_quit", "full", "in_progress",
## "bad_identity", "connection_failed", "timeout").
signal session_closed(reason: String)

# --- Slice 3: Core Round Loop ---

## Emitted on all peers when the round phase changes. data shape depends on
## phase (Slice 3 TDD §3).
signal phase_changed(phase: NetIds.Phase, data: Dictionary)
## Emitted on all peers at ROUND_INTRO with the round header info.
signal round_started(round_index: int, round_count: int, judge_player_id: String)
## Emitted on all peers when the anonymized reveal entries arrive (REVEAL
## phase data).
signal reveal_entries_received(entries: Array)
## Emitted on all peers at RESOLUTION. result is the RESOLUTION phase data dict.
signal round_resolved(result: Dictionary)
## Emitted on all peers whenever authoritative scores are (re)broadcast.
signal scores_updated(scores: Dictionary)
## Emitted on all peers at WRAP_UP with the SessionResults bundle (Slice 10
## consumes).
signal session_results_ready(results: Dictionary)
