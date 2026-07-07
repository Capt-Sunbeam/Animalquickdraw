class_name SessionRules
extends RefCounted
## Pure host-side validation logic for the lobby session (Slice 2 TDD §6).
## Kept free of Net/scene-tree dependencies so every rule is directly
## unit-testable without a live network (consistency guide §9). The Session
## autoload delegates here from its RPC handlers.


## Sliding-window chat rate limiter, per peer (host-only state). The clock
## is passed in so tests control time (no wall-clock flakiness).
class ChatRateLimiter extends RefCounted:
	var _stamps: Dictionary = {}  # peer_id -> Array of float send times (sec)

	## True (and records the send) when the peer is under
	## CHAT_RATE_LIMIT_COUNT messages per CHAT_RATE_LIMIT_WINDOW_SEC.
	func allow(peer_id: int, now_sec: float) -> bool:
		var window_start: float = now_sec - GameConstants.CHAT_RATE_LIMIT_WINDOW_SEC
		var kept: Array[float] = []
		for t: Variant in _stamps.get(peer_id, []):
			if float(t) > window_start:
				kept.append(float(t))
		if kept.size() >= GameConstants.CHAT_RATE_LIMIT_COUNT:
			_stamps[peer_id] = kept
			return false
		kept.append(now_sec)
		_stamps[peer_id] = kept
		return true

	func forget(peer_id: int) -> void:
		_stamps.erase(peer_id)

	func reset() -> void:
		_stamps.clear()


## Strip control chars, trim, truncate to MAX_NAME_LEN, censor on the host
## (brief §13), fall back to "Player <n>" if nothing survives cleaning.
static func sanitize_name(raw: String, fallback_number: int) -> String:
	var kept: String = ""
	for ch: String in raw:
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127:
			kept += ch
	kept = kept.strip_edges().substr(0, GameConstants.MAX_NAME_LEN)
	kept = TextFilter.censor(kept).strip_edges()
	if kept.is_empty():
		return "Player %d" % fallback_number
	return kept


## Registration gate (steps 3 of the 5-step pattern). Returns "" when the
## registration is acceptable, else the rpc_do_reject_join reason key.
static func register_reject_reason(phase: NetIds.Phase, connected_count: int,
		platform_id: String) -> String:
	if phase != NetIds.Phase.LOBBY:
		return "in_progress"  # Slice 9 replaces this branch with late-join/rejoin
	if connected_count >= GameConstants.MAX_PLAYERS:
		return "full"
	if platform_id.is_empty() or platform_id.length() > GameConstants.MAX_PLATFORM_ID_LEN:
		return "bad_identity"
	return ""


## Content validation for chat (rate limit is checked separately).
static func chat_text_ok(text: String) -> bool:
	return not text.strip_edges().is_empty() and text.length() <= GameConstants.MAX_CHAT_LEN


## Start gate (brief §3: 3-8 connected players, lobby phase, host only).
static func can_start(is_host: bool, phase: NetIds.Phase, connected_count: int) -> bool:
	return is_host and phase == NetIds.Phase.LOBBY \
			and connected_count >= GameConstants.MIN_PLAYERS \
			and connected_count <= GameConstants.MAX_PLAYERS


## Host-side duplicate display-name suffixing (Slice 2 TDD §10):
## "Alice" -> "Alice (2)" -> "Alice (3)" against the names already taken.
static func dedupe_display_name(name: String, taken_names: Array[String]) -> String:
	if not taken_names.has(name):
		return name
	var n: int = 2
	while taken_names.has("%s (%d)" % [name, n]):
		n += 1
	return "%s (%d)" % [name, n]
