extends Node
## Autoload "Stats" (Slice 14): local-first lifetime stats + achievement
## unlock mirroring. Counters accumulate into user://stats.json from
## EventBus signals - no Steam required, identical on the ENet dev backend -
## and achievement unlocks mirror to Steam via the Platform seam whenever
## it is live. Steam is a MIRROR, never the source of truth for counters
## (§14 local-first); achievements are DERIVED from counters, so the
## reconcile pass absorbs every offline window and partial failure.
##
## SDK 1.64 reality (decision log 2026-07-11/12): requestCurrentStats is
## gone - is_stats_ready() = init success; setAchievement/getAchievement/
## storeStats are synchronous (ClassDB-verified against the vendored
## GodotSteam 4.20).
##
## Single-writer: nothing outside this service mutates stats. Handlers only
## read LOCAL-player facts from broadcast payloads (one machine = one
## player's stats).

const FORMAT_VERSION: int = 1
## Clean Sweep needs a real game, not a 1-round fluke (owner set: min 3).
const CLEAN_SWEEP_MIN_ROUNDS: int = 3

## Test seam (PublicNoticeGate/AvatarStore precedent): suites point this at
## a scratch file and never touch a real profile.
var path: String = "stats.json"
## Test seam: "" = resolve the live platform id per event.
var platform_id_override: String = ""

var _stats: Dictionary = {}
# Per-game transients for Clean Sweep (rounds the LOCAL client attended
# this game; a late joiner sweeping every round they saw still counts -
# favor generosity, brief §1). Reset at LOBBY and after each game_ended.
var _game_rounds: int = 0
var _game_round_wins: int = 0


func _ready() -> void:
	# Test/gate runs never touch the real profile (the kudos_allotment
	# pin-rule lesson, generalized): under the GdUnit harness the whole
	# process sandboxes itself; CI drivers additionally set a per-PID path.
	for arg: String in OS.get_cmdline_args():
		if arg.contains("GdUnitCmdTool"):
			path = "ci_stats_gdunit.json"
			break
	_stats = _load()
	EventBus.titles_awarded.connect(_on_titles_awarded)
	EventBus.game_ended.connect(_on_game_ended)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.kudos_given.connect(_on_kudos_given)
	EventBus.collection_item_added.connect(_on_collection_item_added)
	_reconcile_achievements()   # startup pass - pushes met-but-unset unlocks


# --- Read surface (future stats page / achievement browser) ---


func get_stat(key: String) -> int:
	return int(_stats.get(key, 0))


func get_title_count(title_id: String) -> int:
	return int((_stats.get("titles_earned", {}) as Dictionary).get(title_id, 0))


func is_achievement_unlocked(id: String) -> bool:
	return (_stats.get("achievements_unlocked", []) as Array).has(id)


# --- EventBus handlers (each ends with persist -> unlock check) ---


func _on_titles_awarded(titles_by_player: Dictionary) -> void:
	var mine: Variant = titles_by_player.get(_local_id())
	if not mine is Array or (mine as Array).is_empty():
		return
	var earned: Dictionary = _stats.get_or_add("titles_earned", {})
	for title_id: Variant in mine:
		earned[str(title_id)] = int(earned.get(str(title_id), 0)) + 1
	_persist_and_check()


func _on_game_ended(standings: Array, bundle: Dictionary) -> void:
	var me: String = _local_id()
	_stats["games_played"] = get_stat("games_played") + 1
	for raw: Variant in standings:
		if raw is Dictionary and str((raw as Dictionary).get("player_id", "")) == me \
				and int((raw as Dictionary).get("rank", 0)) == 1:
			_stats["wins"] = get_stat("wins") + 1   # shared rank 1 counts (§1)
			break
	var kudos: Dictionary = (bundle.get("kudos", {}) as Dictionary).get(me, {})
	if int(kudos.get("granted", 0)) > 0 \
			and int(kudos.get("spent", 0)) == int(kudos.get("granted", 0)):
		_stats["kudos_games_all_spent"] = get_stat("kudos_games_all_spent") + 1
	if standings.size() >= GameConstants.MAX_PLAYERS:
		_stats["games_full_lobby"] = get_stat("games_full_lobby") + 1
	if _game_rounds >= CLEAN_SWEEP_MIN_ROUNDS and _game_round_wins == _game_rounds:
		_stats["clean_sweeps"] = get_stat("clean_sweeps") + 1
	_game_rounds = 0
	_game_round_wins = 0
	_persist_and_check()


func _on_phase_changed(phase: NetIds.Phase, data: Dictionary) -> void:
	match phase:
		NetIds.Phase.LOBBY:
			_game_rounds = 0        # rematch / fresh session
			_game_round_wins = 0
		NetIds.Phase.RESOLUTION:
			_stats["rounds_played"] = get_stat("rounds_played") + 1
			_game_rounds += 1
			if str(data.get("winner_player_id", "")) == _local_id():
				_stats["round_wins"] = get_stat("round_wins") + 1
				_game_round_wins += 1
			_persist_and_check()
		_:
			pass


func _on_kudos_given(_drawing_id: String, _remaining: int) -> void:
	_stats["kudos_spent_total"] = get_stat("kudos_spent_total") + 1
	_persist_and_check()


func _on_collection_item_added(_item_id: String) -> void:
	_stats["drawings_saved"] = get_stat("drawings_saved") + 1
	_persist_and_check()


# --- Unlocks: idempotent, reconcile-from-counters (TDD 14 §6) ---


## Safe to run repeatedly: conditions are monotonic (counters never
## decrease), re-fires are no-ops at three layers (local cache, the
## is-set guard, Steam's own setAchievement idempotency).
func _reconcile_achievements() -> void:
	var unlocked: Array = _stats.get_or_add("achievements_unlocked", [])
	var dirty: bool = false
	var steam_dirty: bool = false
	var steam_live: bool = Platform.is_stats_ready()
	for def: AchievementDefs.Def in AchievementDefs.all():
		if not AchievementDefs.is_met(def, _stats):
			continue
		if not unlocked.has(def.id):                      # first local unlock
			unlocked.append(def.id)
			dirty = true
			EventBus.achievement_unlocked.emit(def.id)
		if steam_live and not Platform.steam_achievement_is_set(def.id):
			Platform.steam_set_achievement(def.id)
			steam_dirty = true
	if steam_dirty:
		Platform.steam_store_stats()                      # one store per batch
	if dirty:
		unlocked.sort()
		_stats["achievements_unlocked"] = unlocked
		Save.write_json(path, _stats)


func _persist_and_check() -> void:
	Save.write_json(path, _stats)
	_reconcile_achievements()


# --- Persistence ---


func _load() -> Dictionary:
	var loaded: Dictionary = Save.read_json(path, _defaults())
	if int(loaded.get("v", FORMAT_VERSION)) > FORMAT_VERSION:
		push_warning("Stats: rejecting stats.json v%s (> %d); using defaults"
				% [str(loaded.get("v")), FORMAT_VERSION])
		return _defaults()
	# Missing counters default via get_stat(); unknown future keys are
	# PRESERVED because we mutate the loaded dict in place (guide §6).
	loaded["v"] = FORMAT_VERSION
	return loaded


func _defaults() -> Dictionary:
	return {
		"v": FORMAT_VERSION,
		"games_played": 0,
		"rounds_played": 0,
		"wins": 0,
		"round_wins": 0,
		"titles_earned": {},
		"kudos_spent_total": 0,
		"kudos_games_all_spent": 0,
		"drawings_saved": 0,
		"games_full_lobby": 0,
		"clean_sweeps": 0,
		"achievements_unlocked": [],
	}


func _local_id() -> String:
	return platform_id_override if not platform_id_override.is_empty() \
			else Platform.get_platform_id()


## Test seam: reload state from `path` (suites swap the path, then reset).
func reset_for_test() -> void:
	_stats = _load()
	_game_rounds = 0
	_game_round_wins = 0
