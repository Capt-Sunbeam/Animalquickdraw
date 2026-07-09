class_name TestRoster
extends GdUnitTestSuite
## Slice 2: host-authoritative roster + PlayerState serialization (TDD §11).


func _make_full_roster() -> Roster:
	var roster := Roster.new()
	for i: int in range(GameConstants.MAX_PLAYERS):
		roster.register(i + 1, "id-%d" % i, "Player %d" % i)
	return roster


func test_register_assigns_monotonic_joined_order() -> void:
	var roster := Roster.new()
	var a: Roster.PlayerState = roster.register(1, "id-a", "Alice")
	var b: Roster.PlayerState = roster.register(7, "id-b", "Bob")
	roster.remove_by_peer(7)
	var c: Roster.PlayerState = roster.register(9, "id-c", "Cleo")
	assert_int(a.joined_order).is_equal(0)
	assert_int(b.joined_order).is_equal(1)
	# Order counter never rewinds, even after a removal.
	assert_int(c.joined_order).is_equal(2)


func test_register_when_full_is_rejected_by_is_full() -> void:
	var roster := Roster.new()
	assert_bool(roster.is_full()).is_false()
	for i: int in range(GameConstants.MAX_PLAYERS - 1):
		roster.register(i + 1, "id-%d" % i, "P%d" % i)
	assert_bool(roster.is_full()).is_false()
	roster.register(99, "id-last", "Last")
	assert_bool(roster.is_full()).is_true()


func test_lookups_return_null_for_unknown_peer_or_platform_id() -> void:
	var roster := Roster.new()
	roster.register(1, "id-a", "Alice")
	assert_object(roster.get_by_peer(42)).is_null()
	assert_object(roster.get_by_platform_id("nope")).is_null()
	assert_object(roster.get_by_peer(1)).is_not_null()
	assert_object(roster.get_by_platform_id("id-a")).is_not_null()


func test_remove_by_peer_updates_connected_count() -> void:
	var roster := Roster.new()
	roster.register(1, "id-a", "Alice")
	roster.register(2, "id-b", "Bob")
	assert_int(roster.connected_count()).is_equal(2)
	roster.remove_by_peer(2)
	assert_int(roster.connected_count()).is_equal(1)
	assert_int(roster.size()).is_equal(1)
	# Removing an unknown peer is a harmless no-op.
	roster.remove_by_peer(42)
	assert_int(roster.connected_count()).is_equal(1)


func test_to_dicts_apply_dicts_round_trip_preserves_all_fields_incl_negative_score() -> void:
	var roster := Roster.new()
	var a: Roster.PlayerState = roster.register(1, "id-a", "Alice")
	a.score = -3  # brief §11: negative scores legal, no floor anywhere
	a.kudos_granted = 4
	a.kudos_spent = 2
	a.is_connected = false
	roster.register(2, "id-b", "Bob")

	var mirror := Roster.new()
	mirror.apply_dicts(roster.to_dicts())

	assert_int(mirror.size()).is_equal(2)
	var ma: Roster.PlayerState = mirror.get_by_peer(1)
	assert_int(ma.score).is_equal(-3)
	assert_int(ma.kudos_granted).is_equal(4)
	assert_int(ma.kudos_spent).is_equal(2)
	assert_bool(ma.is_connected).is_false()
	assert_str(ma.platform_id).is_equal("id-a")
	assert_str(ma.display_name).is_equal("Alice")
	assert_int(ma.joined_order).is_equal(0)
	assert_int(mirror.get_by_peer(2).joined_order).is_equal(1)


func test_from_dict_defaults_missing_keys_and_ignores_garbage_entries() -> void:
	var p: Roster.PlayerState = Roster.PlayerState.from_dict({})
	assert_int(p.peer_id).is_equal(0)
	assert_str(p.display_name).is_equal("")
	assert_bool(p.is_connected).is_true()

	var mirror := Roster.new()
	mirror.apply_dicts([{"peer_id": 3}, "garbage", 42])
	assert_int(mirror.size()).is_equal(1)
	assert_int(mirror.get_by_peer(3).peer_id).is_equal(3)


func test_players_in_join_order_sorts_by_joined_order() -> void:
	var roster := Roster.new()
	roster.register(5, "id-a", "A")
	roster.register(2, "id-b", "B")
	roster.register(9, "id-c", "C")
	var mirror := Roster.new()
	# Mirror rebuild delivers dicts in arbitrary order; join order must hold.
	var dicts: Array[Dictionary] = roster.to_dicts()
	dicts.reverse()
	mirror.apply_dicts(dicts)
	var ordered: Array[Roster.PlayerState] = mirror.players_in_join_order()
	assert_int(ordered[0].peer_id).is_equal(5)
	assert_int(ordered[1].peer_id).is_equal(2)
	assert_int(ordered[2].peer_id).is_equal(9)


# --- Slice 9: disconnect memory + rejoin rebind ---


func test_mark_disconnected_keeps_entry_and_zeroes_peer_id() -> void:
	var roster := Roster.new()
	roster.register(1, "id-a", "Alice")
	roster.register(7, "id-b", "Bob")
	var p: Roster.PlayerState = roster.mark_disconnected(7, 12345)
	assert_object(p).is_not_null()
	assert_int(roster.size()).is_equal(2)            # entry retained (the memory)
	assert_int(roster.connected_count()).is_equal(1)
	assert_bool(p.is_connected).is_false()
	assert_int(p.peer_id).is_equal(0)                # stale transport id never matches
	assert_int(p.disconnect_at_ms).is_equal(12345)
	assert_object(roster.mark_disconnected(42, 0)).is_null()   # unknown peer no-op


func test_rebind_peer_restores_connection_and_preserves_memory() -> void:
	var roster := Roster.new()
	var p: Roster.PlayerState = roster.register(3, "id-a", "Alice")
	p.score = -2                                     # negative survives (§11 no floor)
	p.kudos_granted = 2
	p.kudos_spent = 1
	roster.mark_disconnected(3, 999)
	p.dodge_suspect = true
	var back: Roster.PlayerState = roster.rebind_peer("id-a", 9)
	assert_object(back).is_same(p)
	assert_int(back.peer_id).is_equal(9)
	assert_bool(back.is_connected).is_true()
	assert_int(back.disconnect_at_ms).is_equal(-1)
	assert_bool(back.dodge_suspect).is_false()       # flag clears on return
	assert_int(back.score).is_equal(-2)              # memory untouched
	assert_int(back.kudos_granted).is_equal(2)
	assert_int(back.kudos_spent).is_equal(1)
	assert_int(back.joined_order).is_equal(0)        # original rotation slot
	assert_object(roster.rebind_peer("nope", 5)).is_null()


func test_slice9_fields_round_trip_and_default() -> void:
	var roster := Roster.new()
	var p: Roster.PlayerState = roster.register(1, "id-a", "Alice")
	p.joined_late = true
	roster.mark_disconnected(1, 777)
	p.dodge_suspect = true
	var mirror := Roster.new()
	mirror.apply_dicts(roster.to_dicts())
	var m: Roster.PlayerState = mirror.get_by_platform_id("id-a")
	assert_bool(m.joined_late).is_true()
	assert_int(m.disconnect_at_ms).is_equal(777)
	assert_bool(m.dodge_suspect).is_true()
	# Pre-Slice-9 payloads default cleanly.
	var old: Roster.PlayerState = Roster.PlayerState.from_dict({"peer_id": 2})
	assert_bool(old.joined_late).is_false()
	assert_int(old.disconnect_at_ms).is_equal(-1)
	assert_bool(old.dodge_suspect).is_false()


# --- Slice 11: avatar doc on the roster ---


func test_avatar_doc_round_trips_and_is_omitted_when_empty() -> void:
	var roster := Roster.new()
	var with_avatar: Roster.PlayerState = roster.register(2, "pid-a", "Alice")
	with_avatar.avatar_doc = {"v": 1, "orientation": "avatar",
			"ops": [{"t": "fill", "c": 17, "x": 256, "y": 256}]}
	roster.register(3, "pid-b", "Bob")   # no avatar
	var dicts: Array[Dictionary] = roster.to_dicts()
	assert_bool(dicts[0].has("avatar")).is_true()
	assert_bool(dicts[1].has("avatar")).is_false()   # omitted - snapshots stay small
	var mirror := Roster.new()
	mirror.apply_dicts(dicts)
	assert_dict(mirror.get_by_platform_id("pid-a").avatar_doc)\
			.is_equal(with_avatar.avatar_doc)
	assert_dict(mirror.get_by_platform_id("pid-b").avatar_doc).is_empty()
