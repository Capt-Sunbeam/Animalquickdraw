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

# --- Slice 4: Reactions, Kudos & Saving ---

## Emitted on all peers when a drawing's aggregate reaction counts change.
## counts: Dictionary[NetIds.Reaction -> int], nonzero entries only.
signal reaction_counts_changed(drawing_id: String, counts: Dictionary)
## Emitted on all peers when a drawing's public kudos total changes.
signal kudos_total_changed(drawing_id: String, total: int)
## Emitted locally on the giver when their kudos is confirmed by the host.
signal kudos_wallet_changed(remaining: int)
## Emitted locally on the giver alongside kudos_wallet_changed, identifying
## the drawing. Consumed by Slice 14 stats (kudos_spent_total).
signal kudos_given(drawing_id: String, remaining: int)
## Emitted locally when a drawing is saved to this player's collection
## (kudos-save or self-save).
signal collection_item_added(item_id: String)
## Emitted locally when a collection write fails (disk error). UI shows the
## shared error toast; a failed save never rolls back the kudos (Slice 4 §10).
signal collection_save_failed()

# --- Slice 5: Reveal Styles & Replay ---

## Emitted on all peers when a one-at-a-time reveal beat starts. beat_secs is
## the host-computed total beat duration (drives client progress affordances).
signal reveal_beat_started(index: int, drawing_id: String, beat_secs: float)
## Emitted on all peers when the reveal gathers into the judging grid.
signal reveal_gathered()
## Emitted locally when the winner victory-lap presentation finishes.
signal winner_lap_finished(drawing_id: String)

# --- Slice 6: Game Modes & Settings ---

## Emitted on every peer when the round-count suggestion is recomputed.
## overridden = the host explicitly set rounds; the suggestion is hint-only.
signal round_suggestion_changed(suggested: int, overridden: bool)

# --- Slice 7: Player-Created Prompt Pools ---

## Emitted on all peers when pool-setup submission progress updates.
## progress: [{"player_id": String, "display_name": String, "pools_done": int,
## "pools_total": int}] in joined order.
signal pool_setup_progress_changed(progress: Array)
## Emitted locally on a submitter when the host rejects a pool submission.
## reason: NetIds.WordRejectReason (never NONE or LOCKED).
signal pool_words_rejected(pool_id: String, reason: int)
