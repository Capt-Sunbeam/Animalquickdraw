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

	func to_dict() -> Dictionary:
		return {
			"peer_id": peer_id,
			"platform_id": platform_id,
			"display_name": display_name,
			"score": score,
			"kudos_granted": kudos_granted,
			"kudos_spent": kudos_spent,
			"is_connected": is_connected,
			"joined_order": joined_order,
		}

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
