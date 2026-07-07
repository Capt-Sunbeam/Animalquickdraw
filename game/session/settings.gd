class_name GameSettings
extends RefCounted
## Lobby/game settings (Slice 2 TDD §2). Host-owned; clients hold read-only
## mirrors synced via rpc_sync_settings. Slice 6 extends this class with the
## full Custom surface; Slice 9 adds is_public / fluid_rejoin. New fields
## always get from_dict defaults so older payload shapes never crash a client.
##
## Field name is round_count (not the TDD draft's "rounds") to match the
## Slice 3 GameSession contract - see decision log 2026-07-06.

enum PoolSource { BUILT_IN, PLAYER_CREATED }  # PLAYER_CREATED selectable in Slice 7

var mode: int = SettingsDefaults.Mode.DEFAULT  # selector locked to DEFAULT until Slice 6
var round_count: int = 6
var draw_time_sec: float = SettingsDefaults.DEFAULT_DRAW_TIME_SEC
var pool_source: PoolSource = PoolSource.BUILT_IN
var pool_type_id: String = SettingsDefaults.DEFAULT_POOL_TYPE_ID  # Slice 3 consumes
var rounds_overridden: bool = false  # host touched the spinner; stop auto-suggesting


## brief §10: "roughly enough for everyone to judge a couple of times
## (~2x player count)", clamped to the legal round-count bounds.
static func suggested_rounds(player_count: int) -> int:
	return clampi(player_count * GameConstants.SUGGESTED_ROUNDS_PER_PLAYER,
			GameConstants.ROUNDS_MIN, GameConstants.ROUNDS_MAX)


## Clamps host-tunable values into their legal ranges (called by the host
## before every settings broadcast - never trust UI-side limits alone).
func clamp_to_limits() -> void:
	round_count = clampi(round_count, GameConstants.ROUNDS_MIN, GameConstants.ROUNDS_MAX)
	draw_time_sec = clampf(draw_time_sec, GameConstants.DRAW_TIME_MIN_SEC, GameConstants.DRAW_TIME_MAX_SEC)


func to_dict() -> Dictionary:
	return {
		"mode": mode,
		"round_count": round_count,
		"draw_time_sec": draw_time_sec,
		"pool_source": pool_source,
		"pool_type_id": pool_type_id,
		"rounds_overridden": rounds_overridden,
	}


static func from_dict(d: Dictionary) -> GameSettings:
	var s := GameSettings.new()
	s.mode = int(d.get("mode", SettingsDefaults.Mode.DEFAULT))
	s.round_count = int(d.get("round_count", 6))
	s.draw_time_sec = float(d.get("draw_time_sec", SettingsDefaults.DEFAULT_DRAW_TIME_SEC))
	s.pool_source = int(d.get("pool_source", PoolSource.BUILT_IN)) as PoolSource
	s.pool_type_id = str(d.get("pool_type_id", SettingsDefaults.DEFAULT_POOL_TYPE_ID))
	s.rounds_overridden = bool(d.get("rounds_overridden", false))
	return s


func duplicate_settings() -> GameSettings:
	return GameSettings.from_dict(to_dict())
