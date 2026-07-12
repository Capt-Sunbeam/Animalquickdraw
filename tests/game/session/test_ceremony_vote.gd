class_name TestCeremonyVote
extends GdUnitTestSuite
## Slice 19 (TDD 19 §6): the ceremony skip vote - host-counted, strict
## majority of CONNECTED players, duplicate votes are no-ops, departures
## recount (and can tip a pending vote), votes outside WRAP_UP are ignored.
## Drives the host-side entry (_handle_ceremony_vote - the same path the
## RPC handler resolves into) on a treed SessionClient; the offline peer
## makes is_server() true and lets the call_local sync execute locally
## (test_session_validation precedent).

var _client: SessionClient = null
var _events: Array[Array] = []          # [votes, needed, skipped] per emission
var _saved_peer: MultiplayerPeer = null
var _saved_roster: Roster = null


func before_test() -> void:
	_saved_peer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_saved_roster = Session.roster
	Session.roster = Roster.new()
	_client = auto_free(SessionClient.new())
	add_child(_client)
	# Neutralize the round-start machinery synchronously (the deferred
	# _maybe_start_simulation and the failsafe both guard on this flag).
	_client._sim_started = true
	_client._phase = NetIds.Phase.WRAP_UP
	_events.clear()
	EventBus.ceremony_skip_updated.connect(_capture)


func after_test() -> void:
	EventBus.ceremony_skip_updated.disconnect(_capture)
	remove_child(_client)
	Session.roster = _saved_roster
	multiplayer.multiplayer_peer = _saved_peer


func _capture(votes: int, needed: int, skipped: bool) -> void:
	_events.append([votes, needed, skipped])


func _seed_players(count: int) -> void:
	for i: int in count:
		Session.roster.register(100 + i, "p%d" % i, "P%d" % i)


func test_strict_majority_of_three_needs_two_votes() -> void:
	_seed_players(3)
	_client._handle_ceremony_vote("p0")
	assert_array(_events).contains_exactly([[1, 2, false]])
	_client._handle_ceremony_vote("p1")
	assert_array(_events).contains_exactly([[1, 2, false], [2, 2, true]])


func test_two_players_need_both_votes() -> void:
	_seed_players(2)
	_client._handle_ceremony_vote("p0")
	assert_array(_events).contains_exactly([[1, 2, false]])


func test_duplicate_vote_is_a_noop() -> void:
	_seed_players(3)
	_client._handle_ceremony_vote("p0")
	_client._handle_ceremony_vote("p0")
	assert_array(_events).contains_exactly([[1, 2, false]])


func test_vote_after_skip_is_a_noop() -> void:
	_seed_players(3)
	_client._handle_ceremony_vote("p0")
	_client._handle_ceremony_vote("p1")   # majority -> skipped
	_client._handle_ceremony_vote("p2")
	assert_int(_events.size()).is_equal(2)   # nothing after the skip


func test_vote_outside_wrap_up_ignored() -> void:
	_seed_players(3)
	_client._phase = NetIds.Phase.JUDGING
	_client._handle_ceremony_vote("p0")
	assert_array(_events).is_empty()


func test_departure_tips_a_pending_vote() -> void:
	# 4 connected, 2 votes = pending (needed 3). One leaver -> 3 connected,
	# needed 2, the standing 2 votes now carry it.
	_seed_players(4)
	_client._handle_ceremony_vote("p0")
	_client._handle_ceremony_vote("p1")
	assert_array(_events).contains_exactly([[1, 3, false], [2, 3, false]])
	Session.roster.mark_disconnected(103, 0)   # p3 leaves
	_client._on_roster_changed_for_ceremony_vote([])
	assert_array(_events).contains_exactly(
			[[1, 3, false], [2, 3, false], [2, 2, true]])


func test_disconnected_voters_do_not_count() -> void:
	# p0 votes then drops: 2 connected remain, p0's vote no longer counts.
	_seed_players(3)
	_client._handle_ceremony_vote("p0")
	Session.roster.mark_disconnected(100, 0)
	_client._handle_ceremony_vote("p1")
	assert_array(_events).contains_exactly([[1, 2, false], [1, 2, false]])
