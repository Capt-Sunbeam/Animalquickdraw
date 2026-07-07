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

# Slice 5 reveal/replay keys — authoritative from Slice 5 on; Slice 6
# surfaces them in the lobby UI and must not rename them.
# Replay settings are TARGET DURATIONS, not speed multipliers (owner
# decision 2026-07-06): the strokes speed up to fit the set time; a drawing
# shorter than the target replays at realtime (never slower).
enum RevealStyle { GRID, ONE_AT_A_TIME }
enum ReplayMode { OFF, WINNER_ONLY, FULL }

const REPLAY_SECS_MIN: float = 2.0
const REVEAL_REPLAY_SECS_MAX: float = 15.0
const WINNER_REPLAY_SECS_MAX: float = 30.0

const SETTINGS_VERSION: int = 1

## The only keys editable while a preset (non-Custom) mode is selected
## (design brief §10). Everything else is locked to the preset's values.
const ALWAYS_TUNABLE: Array[StringName] = [&"draw_time_sec", &"round_count", &"pool_source"]

## Sentinel: resolve kudos allotment from round_count at game start via
## KudosLedger.compute_allotment (Slice 4 §6). Slice 6 adds the host-facing
## setting; until then every game runs AUTO.
const KUDOS_AUTO: int = -1

var mode: int = SettingsDefaults.Mode.DEFAULT  # SettingsDefaults.Mode (enum home kept from Slice 2)
var round_count: int = 6
var draw_time_sec: float = SettingsDefaults.DEFAULT_DRAW_TIME_SEC
var pool_source: PoolSource = PoolSource.BUILT_IN
var pool_type_id: String = SettingsDefaults.DEFAULT_POOL_TYPE_ID  # Slice 3 consumes
var rounds_overridden: bool = false  # host touched the spinner; stop auto-suggesting
var kudos_allotment: int = KUDOS_AUTO  # per-player kudos budget; AUTO = derive from rounds
# Slice 6 additions:
var judging_window_sec: float = 25.0   # was a Slice 3 constant; host-tunable from Slice 6
var title_points_enabled: bool = true  # consumed by Slice 10; Custom-only edit (§11)
# Slice 5 defaults (TDD 05 §2 table, updated 2026-07-06 — the Slice 6 contract):
var reveal_style: RevealStyle = RevealStyle.ONE_AT_A_TIME
var replay_mode: ReplayMode = ReplayMode.WINNER_ONLY
var reveal_replay_secs: float = 5.0    # per-drawing reveal replay target duration
var winner_replay_secs: float = 8.0    # victory-lap replay target duration
# comments_enabled removed by Slice 16 (captions retired for the in-image
# text tool); stale profile dicts carrying the key are silently ignored.

var _frozen: bool = false              # snapshots refuse mutation (Slice 6 §5)


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
	reveal_replay_secs = clampf(reveal_replay_secs, REPLAY_SECS_MIN, REVEAL_REPLAY_SECS_MAX)
	winner_replay_secs = clampf(winner_replay_secs, REPLAY_SECS_MIN, WINNER_REPLAY_SECS_MAX)
	judging_window_sec = clampf(judging_window_sec,
			GameConstants.JUDGING_WINDOW_MIN_SEC, GameConstants.JUDGING_WINDOW_MAX_SEC)
	if kudos_allotment != KUDOS_AUTO:
		kudos_allotment = clampi(kudos_allotment, 0, GameConstants.KUDOS_ALLOTMENT_MAX)


# --- Slice 6: presets, lock rule, freeze/snapshot ---


func is_frozen() -> bool:
	return _frozen


func freeze() -> void:
	_frozen = true


## Drives UI enable/disable: everything but the always-three is locked
## unless the mode is Custom. title_points_enabled is Custom-only (§11).
func is_locked(key: StringName) -> bool:
	if mode == SettingsDefaults.Mode.CUSTOM:
		return false
	return not ALWAYS_TUNABLE.has(key)


## Applies a preset over the current values. Custom applies nothing (seeds
## from whatever is applied now). round_count / rounds_overridden /
## pool_source survive every switch; draw_time_sec resets to the preset's
## per-mode default (§10). Refused on frozen snapshots.
func apply_preset(new_mode: int) -> void:
	if _frozen:
		push_error("GameSettings: apply_preset on a frozen snapshot")
		return
	mode = new_mode
	if new_mode == SettingsDefaults.Mode.CUSTOM:
		return
	var preset: Dictionary = SettingsDefaults.PRESETS.get(new_mode, {})
	for key: Variant in preset.keys():
		_assign(StringName(str(key)), preset[key])
	clamp_to_limits()


## Single mutation gate for the lobby UI. Returns false (and mutates
## nothing) when frozen, unknown key, or locked under the preset rule.
## Values clamp, never reject (defense in depth - the UI can't produce
## out-of-range values anyway).
func set_value(key: StringName, value: Variant) -> bool:
	if _frozen:
		push_error("GameSettings: set_value('%s') on a frozen snapshot" % key)
		return false
	if is_locked(key):
		return false
	if not _assign(key, value):
		return false
	if key == &"round_count":
		rounds_overridden = true
	clamp_to_limits()
	return true


## Deep copy with kudos AUTO resolved to a concrete count and _frozen set -
## the immutable object Slice 3's start payload carries and every in-game
## system reads (§6).
func snapshot() -> GameSettings:
	var snap: GameSettings = duplicate_settings()
	snap.clamp_to_limits()
	if snap.kudos_allotment == KUDOS_AUTO:
		snap.kudos_allotment = KudosLedger.compute_allotment(snap.round_count)
	snap._frozen = true
	return snap


## Human-readable start blockers; empty = good to go. Values are clamped on
## every edit so range failures should be unreachable; Slice 7 adds the
## player-created-pool readiness check here.
func validate_for_start(_player_count: int) -> PackedStringArray:
	return PackedStringArray()


func _assign(key: StringName, value: Variant) -> bool:
	match key:
		&"mode": mode = int(value)
		&"reveal_style": reveal_style = int(value) as RevealStyle
		&"replay_mode": replay_mode = int(value) as ReplayMode
		&"reveal_replay_secs": reveal_replay_secs = float(value)
		&"winner_replay_secs": winner_replay_secs = float(value)
		&"judging_window_sec": judging_window_sec = float(value)
		&"kudos_allotment": kudos_allotment = int(value)
		&"title_points_enabled": title_points_enabled = bool(value)
		&"draw_time_sec": draw_time_sec = float(value)
		&"round_count": round_count = int(value)
		&"pool_source": pool_source = int(value) as PoolSource
		&"pool_type_id": pool_type_id = str(value)
		_:
			return false
	return true


func to_dict() -> Dictionary:
	return {
		"v": SETTINGS_VERSION,
		"judging_window_sec": judging_window_sec,
		"title_points_enabled": title_points_enabled,
		"mode": mode,
		"round_count": round_count,
		"draw_time_sec": draw_time_sec,
		"pool_source": pool_source,
		"pool_type_id": pool_type_id,
		"rounds_overridden": rounds_overridden,
		"kudos_allotment": kudos_allotment,
		"reveal_style": reveal_style,
		"replay_mode": replay_mode,
		"reveal_replay_secs": reveal_replay_secs,
		"winner_replay_secs": winner_replay_secs,
	}


static func from_dict(d: Dictionary) -> GameSettings:
	var s := GameSettings.new()
	# Newer-version dicts are refused (consistency guide §6); missing v = v1.
	if int(d.get("v", SETTINGS_VERSION)) > SETTINGS_VERSION:
		push_warning("GameSettings: rejecting settings dict v%s (> %d); using defaults"
				% [str(d.get("v")), SETTINGS_VERSION])
		return s
	s.judging_window_sec = float(d.get("judging_window_sec", 25.0))
	s.title_points_enabled = bool(d.get("title_points_enabled", true))
	s.mode = int(d.get("mode", SettingsDefaults.Mode.DEFAULT))
	s.round_count = int(d.get("round_count", 6))
	s.draw_time_sec = float(d.get("draw_time_sec", SettingsDefaults.DEFAULT_DRAW_TIME_SEC))
	s.pool_source = int(d.get("pool_source", PoolSource.BUILT_IN)) as PoolSource
	s.pool_type_id = str(d.get("pool_type_id", SettingsDefaults.DEFAULT_POOL_TYPE_ID))
	s.rounds_overridden = bool(d.get("rounds_overridden", false))
	s.kudos_allotment = int(d.get("kudos_allotment", KUDOS_AUTO))
	s.reveal_style = int(d.get("reveal_style", RevealStyle.ONE_AT_A_TIME)) as RevealStyle
	s.replay_mode = int(d.get("replay_mode", ReplayMode.WINNER_ONLY)) as ReplayMode
	s.reveal_replay_secs = float(d.get("reveal_replay_secs", 5.0))
	s.winner_replay_secs = float(d.get("winner_replay_secs", 8.0))
	return s


func duplicate_settings() -> GameSettings:
	return GameSettings.from_dict(to_dict())


## Restores a host's persisted lobby settings (`last_lobby_settings`) for a
## NEW lobby: values re-validated; round_count re-seeded from the current
## suggestion - stale counts from a different-sized group are worse than
## the hint (Slice 6 §4).
static func restore_for_lobby(d: Dictionary, player_count: int) -> GameSettings:
	var s: GameSettings = from_dict(d)
	s.clamp_to_limits()
	s.rounds_overridden = false
	s.round_count = suggested_rounds(player_count)
	return s
