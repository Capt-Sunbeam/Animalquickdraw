class_name ReactionLedger
extends RefCounted
## Host-only reaction bookkeeping (Slice 4 TDD §2/§6). Per drawing, per
## NetIds.Reaction, the SET of reactor uids - a player holds at most one of
## each reaction type per drawing, so toggling keeps counts honest and
## spam-proof. No-op toggles report unchanged and must not be broadcast or
## recorded. A per-(player, drawing) changed-toggle cap bounds SessionStats
## growth against button-mashing (§10).

var _reactors: Dictionary = {}      # drawing_id -> Dictionary[Reaction, Dictionary[uid, true]]
var _toggle_counts: Dictionary = {} # "drawing_id|uid" -> changed-toggle count (cap enforcement)


## Applies a toggle. Returns true only if state actually changed (and the
## (player, drawing) event cap is not exhausted) - callers broadcast/record
## only on true.
func set_reaction(drawing_id: String, reaction: NetIds.Reaction, uid: String, active: bool) -> bool:
	var cap_key: String = drawing_id + "|" + uid
	if int(_toggle_counts.get(cap_key, 0)) >= GameConstants.REACTION_EVENT_CAP:
		return false
	var by_reaction: Dictionary = _reactors.get_or_add(drawing_id, {})
	var uids: Dictionary = by_reaction.get_or_add(reaction, {})
	if active == uids.has(uid):
		return false            # no-op toggle - drop, never broadcast
	if active:
		uids[uid] = true
	else:
		uids.erase(uid)
	_toggle_counts[cap_key] = int(_toggle_counts.get(cap_key, 0)) + 1
	return true


func is_active(drawing_id: String, reaction: NetIds.Reaction, uid: String) -> bool:
	var by_reaction: Dictionary = _reactors.get(drawing_id, {})
	var uids: Dictionary = by_reaction.get(reaction, {})
	return uids.has(uid)


## Aggregate counts for one drawing: Reaction -> int, nonzero keys only
## (the wire shape of rpc_sync_reaction_counts).
func counts_for(drawing_id: String) -> Dictionary:
	var out: Dictionary = {}
	var by_reaction: Dictionary = _reactors.get(drawing_id, {})
	for reaction: Variant in by_reaction.keys():
		var n: int = (by_reaction[reaction] as Dictionary).size()
		if n > 0:
			out[reaction] = n
	return out
