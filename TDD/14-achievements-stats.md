# Slice 14: Achievements & Stats
## Local lifetime stats in user://stats.json, EventBus-driven StatsService, and Steam achievement mirroring

**Version:** 1.0
**Last Updated:** 2026-07-04
**Dependencies:**
- Slice 10 (`titles_awarded` / `game_ended` EventBus signals + wrap-up bundle kudos summary)
- Slice 12 (GodotSteam init via SteamBackend — achievement mirroring when available)
- Slice 4 (`kudos_given` signal), Slice 3 (`phase_changed` RESOLUTION data), Skeleton (`EventBus`, `Save`, `collection_item_added` signal)

**Provides:** `Stats` autoload (StatsService), versioned `user://stats.json`, v1 achievement definition table (12), idempotent unlock logic with Steam mirror + startup reconcile — fully functional offline/dev

---

## 1. Overview

The brief's two-tier reward model (§11): **session titles** are ephemeral and fresh every game (Slice 10); **Steam achievements** are permanent, account-tied unlocks layered on top (§11, §14). This slice builds the permanent tier as **local-first**: a `StatsService` accumulates lifetime counters into `user://stats.json` by listening to EventBus signals — no Steam required, works identically on the ENet dev backend — and mirrors achievement unlocks to Steam via GodotSteam whenever it's available. Steam is a *mirror*, never the source of truth for stats (§14: no central server holds player data; achievements are the only cloud-resident artifact).

### Scope

**In Scope:**
- `user://stats.json` (versioned) with all counters the v1 achievement set needs
- `Stats` autoload: EventBus listeners (game end, title awarded, kudos spent, drawing saved, round resolution), atomic persistence
- v1 achievement set (12) — each with id, trigger condition, and the stat it reads
- Idempotent unlock logic: re-fires are no-ops; local `achievements_unlocked` cache
- Steam mirror: `setAchievement`/`storeStats` on unlock when Steam is live; startup **reconcile pass** pushes any met-but-unset achievements (covers offline play)
- Stats persist and accumulate regardless of Steam availability

**Out of Scope (Other Slices / Not v1):**
- Steamworks partner-site achievement configuration (API names, icons, descriptions) — **Slice 15 owner task**; ids defined here are the contract
- In-game achievement browser/UI — Steam overlay + client display suffice for v1
- Steam Stats API (`setStatInt` server-side stats) — local JSON is authoritative; only achievement *unlocks* mirror to Steam in v1
- Session titles themselves (Slice 10) and any leaderboards (not v1)

### Key Scenarios

1. **Normal unlock:** player earns Hotshot for the first time → `titles_awarded` fires → `titles_earned.hotshot` becomes 1 → `first_hotshot` condition met → local unlock recorded → Steam popup appears (Steam running).
2. **Offline/dev play:** same flow minus the Steam call; next launch with Steam available, the reconcile pass sets the achievement.
3. **Quit mid-game:** no `game_ended` → `games_played` untouched (staying to the end is what counts, §11), but `rounds_played` kept its per-round increments.

---

## 2. Data Models

### LifetimeStats (in-memory mirror of stats.json)

**File: `res://core/stats/stats_service.gd`** (held as a typed Dictionary; shape below is the contract)

| Field | Type | Default | Incremented by |
|-------|------|---------|----------------|
| v | int | 1 | — (format version) |
| games_played | int | 0 | `game_ended` (wrap-up reached, incl. early end) |
| rounds_played | int | 0 | `phase_changed` → RESOLUTION (rounds you were connected for) |
| wins | int | 0 | `game_ended` with local player at rank 1 (shared rank 1 counts) |
| round_wins | int | 0 | RESOLUTION where the winning drawing is the local player's |
| titles_earned | Dictionary[String, int] | `{}` | `titles_awarded` — keyed by `TitleIds` id (absent = 0) |
| kudos_spent_total | int | 0 | `kudos_given` |
| kudos_games_all_spent | int | 0 | `game_ended` where bundle kudos: granted > 0 and spent == granted |
| drawings_saved | int | 0 | `collection_item_added` (covers kudos-saves and self-saves — same action, §11) |
| achievements_unlocked | Array[String] | `[]` | Unlock logic (local cache; sorted, unique) |

### AchievementDef

**File: `res://core/stats/achievement_defs.gd`** — `class_name AchievementDefs`, a static table (data-driven; adding an achievement = adding a row + Steamworks config).

```gdscript
class_name AchievementDefs
extends RefCounted

class Def extends RefCounted:
    var id: String                 # MUST equal the Steamworks API name (Slice 15 config)
    var stat_key: String           # "" for custom evaluators
    var threshold: int
    var title_id: String = ""      # set for title-based achievements (reads titles_earned)
    var custom: Callable           # optional: func(stats: Dictionary) -> bool

static func all() -> Array[Def]: ...
static func is_met(def: Def, stats: Dictionary) -> bool: ...
```

### v1 Achievement Set (12)

| # | id (Steam API name) | Display name (working) | Trigger condition | Stat read |
|---|---------------------|------------------------|-------------------|-----------|
| 1 | `first_game` | Welcome to the Zoo | Finish your first game (reach the wrap-up) | `games_played >= 1` |
| 2 | `first_win` | Top Dog | Finish a game in 1st place | `wins >= 1` |
| 3 | `first_hotshot` | Hotshot | Earn the Hotshot title for the first time (§11) | `titles_earned.hotshot >= 1` |
| 4 | `hotshot_x10` | Serial Hotshot | Earn Hotshot 10 times (§11 example) | `titles_earned.hotshot >= 10` |
| 5 | `first_worst_drawer` | Wear It Proudly | Earn the Worst Drawer title | `titles_earned.worst_drawer >= 1` |
| 6 | `title_collector` | One of Everything | Earn every v1 title at least once (career, §11) | custom: all 8 `TitleIds` counts ≥ 1 |
| 7 | `save_10` | Petting Zoo | 10 drawings saved to your collection | `drawings_saved >= 10` |
| 8 | `save_50` | Full Menagerie | 50 drawings saved | `drawings_saved >= 50` |
| 9 | `all_kudos_spent` | Big Spender | Spend your entire kudos allotment in one game (§11) | `kudos_games_all_spent >= 1` |
| 10 | `rounds_100` | Century of Scribbles | Play 100 rounds (§11) | `rounds_played >= 100` |
| 11 | `games_100` | Party Animal | Play 100 games (§11) | `games_played >= 100` |
| 12 | `round_wins_25` | Judge Magnet | Win 25 rounds (judge picks) | `round_wins >= 25` |

Display names/descriptions are working copy — finalized on the Steamworks partner site (Slice 15). **Ids are frozen here**: they are the Steamworks API names, and renaming after partner-site setup is churn.

---

## 3. Event/Action Definitions

### Consumed EventBus signals (no new RPCs — this slice is entirely local + Steam API)

| Signal | Emitter | StatsService handler behavior |
|--------|---------|-------------------------------|
| `titles_awarded(titles_by_player: Dictionary)` | Slice 10 | If local `platform_id` present: `titles_earned[title_id] += 1` |
| `game_ended(standings: Array, bundle: Dictionary)` | Slice 10 | `games_played += 1`; local rank == 1 → `wins += 1`; bundle `kudos[local]`: granted > 0 and spent == granted → `kudos_games_all_spent += 1` |
| `phase_changed(phase: NetIds.Phase, data: Dictionary)` | Slice 3 | On `RESOLUTION`: `rounds_played += 1`; `data.winner_player_id == local platform_id` → `round_wins += 1` (confirmed against Slice 3's RESOLUTION payload) |
| `kudos_given(drawing_id: String, remaining: int)` | Slice 4 (confirmed — declared in Slice 4 §3) | `kudos_spent_total += 1` |
| `collection_item_added(item_id: String)` | Slice 4/8 (declared in consistency guide §5) | `drawings_saved += 1` |

Every handler ends with: persist → run unlock check (Section 6). Handlers only ever read **local-player** facts from broadcast payloads; other players' stats are never recorded (§14 local-first, one machine = one player's stats).

### Emitted EventBus signal

**Append to `res://core/events/event_bus.gd`:**

```gdscript
## Emitted locally when an achievement unlocks for the first time (local cache transition
## locked -> unlocked). Steam shows its own overlay; this is for logs/future in-game UI.
signal achievement_unlocked(achievement_id: String)
```

---

## 4. Storage Schema Extensions

### stats.json

**File: `user://stats.json`** (via `Save.read_json` / `Save.write_json` — atomic, corrupt-tolerant; slot already reserved in consistency guide §6)

```json
{
  "v": 1,
  "games_played": 12,
  "rounds_played": 143,
  "wins": 3,
  "round_wins": 21,
  "titles_earned": {"hotshot": 2, "worst_drawer": 1},
  "kudos_spent_total": 31,
  "kudos_games_all_spent": 4,
  "drawings_saved": 17,
  "achievements_unlocked": ["first_game", "first_hotshot"]
}
```

**Rules (consistency guide §6):**
- Missing file → defaults (fresh install). Corrupt file → warning + defaults; the game never crashes on bad save data. Loss of local unlock cache is repaired by the startup reconcile (Steam remains the record of *unlocks*; local JSON remains the record of *counters* — counter loss on corruption is accepted, §14).
- `titles_earned` keys restricted to `TitleIds` constants; unknown keys preserved on write (forward compatibility).
- Version: readers accept `v <= 1` and migrate forward; higher versions rejected with a user-visible message.

**Write pattern:** in-memory mutate → `Save.write_json("stats.json", _stats)` after each handled event. Events are low-frequency (per-round at worst), so per-event atomic writes are cheap and crash-safe; no debounce needed.

---

## 5. State Machines

N/A — achievements are monotonic latches (locked → unlocked, never back) and stats are append-only counters; there are no multi-state transitions worth a machine. The latch rule is captured in the idempotent unlock logic (Section 6) and its tests.

---

## 6. Business Logic

### StatsService

**File: `res://core/stats/stats_service.gd`** — autoload **`Stats`** (registered after `Save` and `Platform` in the autoload order; new entry appended to the skeleton's registry).

```gdscript
extends Node
# Autoload "Stats". Lifetime stats + achievement unlock mirroring.

var _stats: Dictionary = {}

func _ready() -> void:
    _stats = Save.read_json("stats.json", _defaults())
    EventBus.titles_awarded.connect(_on_titles_awarded)
    EventBus.game_ended.connect(_on_game_ended)
    EventBus.phase_changed.connect(_on_phase_changed)
    EventBus.kudos_given.connect(_on_kudos_given)
    EventBus.collection_item_added.connect(_on_collection_item_added)
    _reconcile_achievements()   # startup pass — pushes met-but-unset unlocks to Steam

func get_stat(key: String) -> int: ...
func get_title_count(title_id: String) -> int: ...

func _bump(key: String, by: int = 1) -> void:
    _stats[key] = int(_stats.get(key, 0)) + by
    _persist_and_check()

func _persist_and_check() -> void:
    Save.write_json("stats.json", _stats)
    _reconcile_achievements()
```

**Business Rules:**
1. **Local player only:** handlers resolve the local `platform_id` via `Platform` once and ignore other players' entries in broadcast payloads.
2. **Stats before Steam:** counters always persist locally first; Steam calls can fail freely without losing anything.
3. **games_played counts wrap-ups reached** (normal or early-end) — quitting mid-game earns nothing at game granularity (§11 rewards staying), while `rounds_played` still accrues per round.
4. A shared rank 1 (tie) counts as a win — favor generosity (§1).

### Idempotent unlock + reconcile

```gdscript
func _reconcile_achievements() -> void:
    var unlocked: Array = _stats.get("achievements_unlocked", [])
    var dirty := false
    var steam_dirty := false
    for def: AchievementDefs.Def in AchievementDefs.all():
        if not AchievementDefs.is_met(def, _stats):
            continue
        if not unlocked.has(def.id):                      # first local unlock
            unlocked.append(def.id)
            dirty = true
            EventBus.achievement_unlocked.emit(def.id)
        if Platform.is_steam_ready():                     # mirror (idempotent on Steam side)
            if not Platform.steam_achievement_is_set(def.id):
                Platform.steam_set_achievement(def.id)    # wraps Steam.setAchievement
                steam_dirty = true
    if steam_dirty:
        Platform.steam_store_stats()                      # one storeStats per batch
    if dirty:
        _stats["achievements_unlocked"] = unlocked
        Save.write_json("stats.json", _stats)
```

- **Re-fires are no-ops** at three layers: condition already met + id already in local cache (no signal re-emit), `steam_achievement_is_set` guard (no redundant API call), and Steam's own `setAchievement` idempotency as the last resort.
- **Reconcile covers every offline/failure window:** achievements are *derived* from counters, so any unlock missed while Steam was down is recomputed and pushed on the next `_reconcile_achievements()` (every stat change + every startup).
- Conditions are monotonic (counters never decrease), so "met" can never become "unmet" — reconcile is safe to run repeatedly.

### Platform seam additions (Slice 12's backend surface)

`PlatformBackend` gains no-op defaults; `SteamBackend` implements via GodotSteam (`requestCurrentStats` on init; guard all calls behind stats-received):

```gdscript
func is_steam_ready() -> bool: return false
func steam_achievement_is_set(id: String) -> bool: return false
func steam_set_achievement(id: String) -> void: pass
func steam_store_stats() -> void: pass
```

EnetBackend keeps the no-ops — dev builds exercise the full local pipeline with Steam calls silently skipped.

---

## 7. UI Components

N/A — no in-game achievement or stats UI in v1. Steam's overlay renders unlock toasts and the achievement list; the local `achievement_unlocked` signal exists for logging now and any future in-game browser. (Dev verification uses logs + `stats.json` inspection, not UI.)

### User Confirmation Checkpoints

- [ ] **Steam unlock toast** (blocking for slice completion, needs Spacewar App ID 480 with configured test achievement or a stand-in): earning a mapped achievement in a live Steam session shows the overlay popup
- [ ] **Offline accrual** (batchable): a full ENet dev game updates `stats.json` counters correctly with Steam absent

---

## 8. State Management

**State container:** the `Stats` autoload (Section 6) — the only holder of lifetime stats; UI and future features read through its getters, never `Save` directly.

**State Shape:** the `stats.json` dictionary (Section 4), loaded once at startup, mutated only by EventBus handlers, persisted atomically on every mutation.

**Selectors/Computed:**
| Name | Purpose | Dependencies |
|------|---------|--------------|
| `get_stat(key)` | Raw counter read | `_stats` |
| `get_title_count(title_id)` | Per-title career count | `_stats.titles_earned` |
| `is_achievement_unlocked(id)` | Local unlock cache check | `_stats.achievements_unlocked` |

**Actions:** internal `_bump`/handlers only — no public mutation API. Nothing outside StatsService may write stats (single-writer keeps counters trustworthy).

---

## 9. Integration Points

### Dependencies (What This Slice Needs)

#### From Skeleton
- `Save` (atomic JSON), `EventBus`, autoload registry (new `Stats` entry), `Platform` seam

#### From Slice 10
- `titles_awarded` + `game_ended(standings, bundle)` signals; bundle `kudos` map (spend-all detection) and `TitleIds` constants

#### From Slice 3
- `phase_changed` RESOLUTION payload field `winner_player_id` (confirmed against Slice 3 §3)

#### From Slice 4
- `kudos_given` signal (confirmed — Slice 4 §3); `collection_item_added` (owned by Slice 4)

#### From Slice 12
- SteamBackend + GodotSteam init; this slice adds the four achievement methods to the backend surface

### Provides (For Future Slices / Slice 15)
- **Frozen achievement id table (Section 2)** — the exact API names Slice 15 configures on the Steamworks partner site (owner task: create each achievement with matching API name, display name, description, locked/unlocked icons, then publish)
- **`Stats` getters + `achievement_unlocked` signal** — future in-game stats page / achievement browser
- **stats.json v1 format** — future counters extend with a version bump + migration

### Integration Checklist
- [ ] `Stats` autoload registered (project settings, after Save/Platform)
- [ ] `achievement_unlocked` appended to EventBus with doc comment
- [ ] Backend achievement methods added to `PlatformBackend` (+ Steam impl, ENet no-ops)
- [ ] Signal-name reconciliation with Slices 3/4/10 recorded in Decision Log if any differ
- [ ] Slice 15 task filed: Steamworks achievement configuration from Section 2 table

---

## 10. Edge Cases

### Steam offline / dev backend for weeks
**Scenario:** Player accrues stats across many ENet or Steam-offline sessions.
**Handling:** Counters accumulate locally; first launch with Steam ready, the startup reconcile derives and pushes every met achievement in one batch (`storeStats` once).
**Rationale:** Achievements derive from counters — no unlock-event queue to lose (§14 local-first).

### stats.json corrupt or deleted
**Scenario:** Disk corruption, or player wipes `user://`.
**Handling:** `Save` returns defaults + warning; counters restart at zero (accepted loss — no cloud stat recovery in v1, §14). Already-unlocked Steam achievements are untouched on Steam; local cache repopulates via reconcile *only for conditions still met*, and `steam_achievement_is_set` prevents any weirdness for ones no longer met locally — Steam never revokes.
**Rationale:** Never crash on bad saves (guide §6); permanent tier stays permanent.

### Empty-stats wrap-up (early end at round 1)
**Scenario:** `game_ended` fires from an early-end with zero rounds completed and no titles.
**Handling:** `games_played += 1` (a wrap-up was reached), everything else untouched — `titles_awarded` map is empty, kudos granted may be > 0 with spent 0 (no all-spent credit). No unlock check misfires because conditions read counters, not events.
**Rationale:** Graceful on whatever data exists — mirrors Slice 10's contract.

### Duplicate signal delivery / re-fired unlock
**Scenario:** A bug replays `titles_awarded`, or reconcile runs twice concurrently-ish.
**Handling:** Counter double-bump is a (bug-level) inaccuracy, but unlocks stay correct: local cache + Steam-set guard make re-fires no-ops. `achievement_unlocked` emits at most once per id per install.
**Rationale:** Idempotency contract of this slice.

### Rejoining a game after disconnect
**Scenario:** Player drops in round 4, rejoins round 6, stays to wrap-up.
**Handling:** `rounds_played` counted only rounds where the local client received RESOLUTION (4 of 8, say); `games_played`/`wins`/titles come from the wrap-up broadcast which the rejoined client receives normally.
**Rationale:** "Rounds you actually played" is the honest number; no host-side per-player attendance ledger needed.

### `setAchievement` succeeds but `storeStats` fails
**Scenario:** Steam API hiccup between calls.
**Handling:** Local cache already recorded the unlock; next reconcile re-checks `steam_achievement_is_set` (unstored sets still read back true in-session; after restart, if lost, the condition is still met → set again).
**Rationale:** Reconcile-from-counters absorbs every partial-failure ordering.

### Performance Considerations
Event frequency is human-scale (per round / per click); a full reconcile is 12 condition checks over a small dict — negligible. One `storeStats` per batch avoids Steam rate-limit warnings. `stats.json` stays < 1 KB.

---

## 11. Testing Strategy

### Unit Tests

**Location:** `res://tests/core/stats/test_stats_service.gd`, `test_achievement_defs.gd`

#### Stats accumulation
- [ ] `test_game_ended_increments_games_played_and_win_on_rank_one`
- [ ] `test_shared_rank_one_counts_as_win`
- [ ] `test_titles_awarded_increments_only_local_player_title`
- [ ] `test_resolution_increments_rounds_and_round_wins_for_local_winner`
- [ ] `test_kudos_given_increments_spent_total`
- [ ] `test_collection_item_added_increments_drawings_saved`
- [ ] `test_all_kudos_spent_detected_from_bundle_granted_equals_spent`
- [ ] `test_all_kudos_spent_not_credited_when_granted_zero`

#### Persistence
- [ ] `test_stats_round_trip_through_save`
- [ ] `test_corrupt_stats_file_yields_defaults_without_crash`
- [ ] `test_unknown_future_keys_preserved_on_write`
- [ ] `test_higher_version_rejected_with_message`

#### Achievement conditions & idempotency
- [ ] `test_each_of_12_defs_met_exactly_at_threshold` (parameterized over the table)
- [ ] `test_title_collector_requires_all_eight_titles`
- [ ] `test_unlock_emits_signal_once_then_never_again`
- [ ] `test_reconcile_is_noop_when_nothing_newly_met`
- [ ] `test_reconcile_pushes_met_achievement_when_steam_becomes_ready` (mock backend)
- [ ] `test_steam_calls_skipped_entirely_on_enet_backend`

### Integration Tests
- [ ] Scripted fake session (emit the five signals in realistic order) → final `stats.json` matches expected counters and unlock list
- [ ] Mock Steam backend recording calls: exactly one `setAchievement` per id ever, one `storeStats` per batch

### UI/Component Tests
N/A — no UI in this slice (Section 7).

### Manual Testing Required
- [ ] Live Steam (Spacewar) session: unlock toast appears for a configured achievement — **blocking**
- [ ] Offline ENet game end-to-end: inspect `stats.json` counters — batchable
- [ ] Delete `stats.json`, relaunch with Steam: no crash, no revocation, met-condition achievements re-set harmlessly — batchable

---

## 12. Implementation Checklist

### Setup
- [ ] Create `core/stats/` with `stats_service.gd` + `achievement_defs.gd`; register `Stats` autoload
- [ ] Append `achievement_unlocked` to EventBus
- [ ] Reconcile assumed signal/field names with Slices 3/4/10 TDDs (Decision Log if changed)

### Data Layer
- [ ] stats.json defaults, load with corrupt tolerance, version check, atomic writes
- [ ] `AchievementDefs` table for all 12 ids + `is_met` (threshold + title + custom evaluators)

### Business Logic
- [ ] Five EventBus handlers with local-player resolution
- [ ] `_reconcile_achievements` with three-layer idempotency + batch `storeStats`
- [ ] `PlatformBackend` achievement methods: ENet no-ops + SteamBackend GodotSteam impl (guard on `requestCurrentStats` completion)

### Testing
- [ ] All unit/integration tests above green; full suite green (no regressions)

### User Confirmation
- [ ] Blocking: live Steam unlock toast confirmed
- [ ] Batchable: offline accrual + delete-and-relaunch scenarios confirmed

### Documentation
- [ ] Update WHERE_WE_ARE; Implementation Notes
- [ ] File the Slice 15 owner task: configure all 12 achievements on the Steamworks partner site with the exact API names from Section 2
