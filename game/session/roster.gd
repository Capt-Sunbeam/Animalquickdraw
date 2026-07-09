class_name Roster
extends RefCounted
## Host-authoritative player roster (Slice 2 TDD §2). One entry per player
## who has ever been part of this session. Entries are NOT removed on
## in-game disconnect (Slice 9 relies on this); in the lobby phase leavers
## ARE removed (no memory needed pre-game). Clients hold read-only mirrors
## rebuilt exclusively via apply_dicts.


## Serialization keys mirror field names exactly. from_dict applies typed
## coercion and a default for every missing key, so payloads from
## newer/older peers never crash a mirror rebuild.
class PlayerState extends RefCounted:
	var peer_id: int = 0            # transport peer id (1 = host; 0 while disconnected, Slice 9)
	var platform_id: String = ""    # stable identity: dev uuid / SteamID64 (Slice 12); rejoin key (Slice 9)
	var display_name: String = ""   # sanitized on host before storage
	var score: int = 0              # may be negative (brief §11) - no floor anywhere
	var kudos_granted: int = 0      # filled by Slice 4 at game start
	var kudos_spent: int = 0        # incremented by Slice 4
	var is_connected: bool = true
	var joined_order: int = 0       # monotonic; judge-rotation basis (Slice 3)
	# --- Slice 9 additions ---
	var joined_late: bool = false   # joined after game start (never submits pool words)
	var disconnect_at_ms: int = -1  # host clock at drop; -1 = connected
	var dodge_suspect: bool = false # fluid OFF: left near their judge turn
	# --- Slice 11 ---
	var avatar_doc: Dictionary = {} # validated serialized DrawingDoc; {} = none.
	                                # Relay data - the host validates but never
	                                # rasterizes; receivers re-validate before use.

	func to_dict() -> Dictionary:
		var out: Dictionary = {
			"peer_id": peer_id,
			"platform_id": platform_id,
			"display_name": display_name,
			"score": score,
			"kudos_granted": kudos_granted,
			"kudos_spent": kudos_spent,
			"is_connected": is_connected,
			"joined_order": joined_order,
			"joined_late": joined_late,
			"disconnect_at_ms": disconnect_at_ms,
			"dodge_suspect": dodge_suspect,
		}
		if not avatar_doc.is_empty():
			out["avatar"] = avatar_doc   # omitted when none - snapshots stay small
		return out

	static func from_dict(d: Dictionary) -> PlayerState:
		var p := PlayerState.new()
		p.peer_id = int(d.get("peer_id", 0))
		p.platform_id = str(d.get("platform_id", ""))
		p.display_name = str(d.get("display_name", ""))
		p.score = int(d.get("score", 0))
		p.kudos_granted = int(d.get("kudos_granted", 0))
		p.kudos_spent = int(d.get("kudos_spent", 0))
		p.is_connected = bool(d.get("is_connected", true))
		p.joined_order = int(d.get("joined_order", 0))
		p.joined_late = bool(d.get("joined_late", false))
		p.disconnect_at_ms = int(d.get("disconnect_at_ms", -1))
		p.dodge_suspect = bool(d.get("dodge_suspect", false))
		var avatar: Variant = d.get("avatar")
		p.avatar_doc = avatar if avatar is Dictionary else {}
		return p


var _players: Array[PlayerState] = []
var _next_joined_order: int = 0


func register(peer_id: int, platform_id: String, display_name: String) -> PlayerState:
	var p := PlayerState.new()
	p.peer_id = peer_id
	p.platform_id = platform_id
	p.display_name = display_name
	p.joined_order = _next_joined_order
	_next_joined_order += 1
	_players.append(p)
	return p


## Lobby-phase removal only. In-game disconnects keep the entry and flip
## is_connected instead (Slice 9 rejoin depends on the retained entry).
func remove_by_peer(peer_id: int) -> void:
	for i: int in range(_players.size()):
		if _players[i].peer_id == peer_id:
			_players.remove_at(i)
			return


## Slice 9 in-game disconnect: the entry - score, kudos ledger, rotation
## slot, reaction stats - is the "memory" §9/§11 require. peer_id resets to
## 0 so a stale transport id can never match a future peer. Returns the
## entry (null for unknown peers). now_ms uses the caller's clock (the
## GameSession-injectable one in practice) so the dodge bookkeeping is
## testable without wall time.
func mark_disconnected(peer_id: int, now_ms: int) -> PlayerState:
	var p: PlayerState = get_by_peer(peer_id)
	if p == null:
		return null
	p.is_connected = false
	p.peer_id = 0
	p.disconnect_at_ms = now_ms
	return p


## Slice 9 rejoin: rebind a retained entry to a fresh transport peer. Score,
## kudos granted/spent, and joined_order are deliberately untouched - that
## IS the restore (§9, §11). Clears all disconnect bookkeeping.
func rebind_peer(platform_id: String, peer_id: int) -> PlayerState:
	var p: PlayerState = get_by_platform_id(platform_id)
	if p == null:
		return null
	p.peer_id = peer_id
	p.is_connected = true
	p.disconnect_at_ms = -1
	p.dodge_suspect = false
	return p


func get_by_peer(peer_id: int) -> PlayerState:
	for p: PlayerState in _players:
		if p.peer_id == peer_id:
			return p
	return null


func get_by_platform_id(platform_id: String) -> PlayerState:
	for p: PlayerState in _players:
		if p.platform_id == platform_id:
			return p
	return null


func connected_count() -> int:
	var n: int = 0
	for p: PlayerState in _players:
		if p.is_connected:
			n += 1
	return n


func is_full() -> bool:
	return connected_count() >= GameConstants.MAX_PLAYERS


func size() -> int:
	return _players.size()


func players_in_join_order() -> Array[PlayerState]:
	var sorted: Array[PlayerState] = _players.duplicate()
	sorted.sort_custom(func(a: PlayerState, b: PlayerState) -> bool:
		return a.joined_order < b.joined_order)
	return sorted


## Stable platform ids in join order - the judge-rotation basis (Slice 3).
func player_ids_by_joined_order() -> Array[String]:
	var ids: Array[String] = []
	for p: PlayerState in players_in_join_order():
		ids.append(p.platform_id)
	return ids


func to_dicts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: PlayerState in _players:
		out.append(p.to_dict())
	return out


## Client mirror replace. Also re-derives the join counter so a roster that
## later becomes authoritative (never happens in v1 - no host migration)
## cannot mint duplicate joined_order values.
func apply_dicts(dicts: Array) -> void:
	_players.clear()
	_next_joined_order = 0
	for raw: Variant in dicts:
		if not raw is Dictionary:
			continue
		var p: PlayerState = PlayerState.from_dict(raw)
		_players.append(p)
		_next_joined_order = maxi(_next_joined_order, p.joined_order + 1)
