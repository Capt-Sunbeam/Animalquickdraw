class_name CustomPoolCollector
extends RefCounted
## Host-only collection + validation of player-submitted pool words during
## POOL_SETUP (Slice 7 TDD §6). Session-scoped by explicit requirement (§8):
## owned by GameSession, freed with it, never persisted anywhere.
## Validation is atomic per pool submission - all words accepted or none.

var share_per_player: int = 0
var pool_ids: PackedStringArray = PackedStringArray()
var eligible_player_ids: PackedStringArray = PackedStringArray()
var locked: bool = false

var _submissions: Dictionary = {}   # player_id -> {pool_id -> PackedStringArray}
var _departed: Dictionary = {}      # player_id -> true (Slice 9 extension point)


## §8: per-player share = round count ÷ player count, rounded up - the pools
## always hold at least round_count words; surplus goes undrawn.
static func compute_share(round_count: int, player_count: int) -> int:
	return ceili(float(round_count) / float(player_count))


## Returns NetIds.WordRejectReason.NONE on acceptance, else the reason.
## Structurally invalid input (unknown pool, non-eligible sender) returns
## WRONG_COUNT - the caller treats those and LOCKED as drop-tier (§5: no
## rejection RPC once the game has moved on / for tampered senders).
func submit(player_id: String, pool_id: String, words: PackedStringArray) -> int:
	if locked:
		return NetIds.WordRejectReason.LOCKED
	if not eligible_player_ids.has(player_id) or not pool_ids.has(pool_id):
		return NetIds.WordRejectReason.WRONG_COUNT   # shape-invalid; drop-tier
	if (_submissions.get(player_id, {}) as Dictionary).has(pool_id):
		return NetIds.WordRejectReason.ALREADY_SUBMITTED
	if words.size() != share_per_player:
		return NetIds.WordRejectReason.WRONG_COUNT
	var trimmed := PackedStringArray()
	for w: String in words:
		var word: String = w.strip_edges()
		if word.is_empty() or word.length() > GameConstants.WORD_MAX_CHARS \
				or word.contains("\n"):
			return NetIds.WordRejectReason.BAD_LENGTH
		# Never auto-censor a prompt word - "*** aardvark" isn't drawable (§2).
		if not TextFilter.is_clean(word):
			return NetIds.WordRejectReason.NOT_CLEAN
		trimmed.append(word)
	var mine: Dictionary = _submissions.get_or_add(player_id, {})
	mine[pool_id] = trimmed
	return NetIds.WordRejectReason.NONE


## True once every eligible (and not departed) player has every pool in.
## Duplicates within/across players are legal - party behavior (§2).
func is_complete() -> bool:
	for player_id: String in eligible_player_ids:
		if _departed.has(player_id):
			continue
		var mine: Dictionary = _submissions.get(player_id, {})
		for pool_id: String in pool_ids:
			if not mine.has(pool_id):
				return false
	return true


## Union of everyone's words for one pool, joined order then entry order.
func collected_words(pool_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	for player_id: String in eligible_player_ids:
		var mine: Dictionary = _submissions.get(player_id, {})
		out.append_array(mine.get(pool_id, PackedStringArray()))
	return out


## The rpc_sync_pool_setup_progress payload (§3). display_name resolution is
## the caller's job (the collector knows ids only).
func progress() -> Array:
	var out: Array = []
	for player_id: String in eligible_player_ids:
		var mine: Dictionary = _submissions.get(player_id, {})
		var done: int = 0
		for pool_id: String in pool_ids:
			if mine.has(pool_id):
				done += 1
		out.append({
			"player_id": player_id,
			"pools_done": done,
			"pools_total": pool_ids.size(),
		})
	return out


## Slice 9 extension point: a departed player no longer gates completion.
## Their already-submitted words stay in the pot (they were valid).
func mark_departed(player_id: String) -> void:
	_departed[player_id] = true


## Slice 9: a rejoiner gates completion again - departure only stopped them
## from blocking while away; their share is still theirs to finish.
func mark_returned(player_id: String) -> void:
	_departed.erase(player_id)
