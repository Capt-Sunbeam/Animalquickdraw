# Slice 14 Implementation Notes: Achievements & Stats

**Implemented:** 2026-07-12 (session 14, Chunk 17) | **TDD:** `14-achievements-stats.md`
**Machine state:** 572 tests green (26 new across two stats suites); all 3 gates PASS
**Owner blocking check:** deferred to the Slice 15 App-ID swap (see below)

---

## What was actually built vs the TDD

The TDD's architecture shipped as designed (local-first StatsService, versioned `user://stats.json`, reconcile-from-counters, three-layer idempotent Steam mirror). Major deviations — all owner-directed in-session or API reality:

1. **The achievement set is 27, not 12** — owner-frozen 2026-07-12 (decision log): per-title first+tenth for the 7 post-Slice-19 titles (14), milestones `first_game`/`first_win`/`games_10`/`games_100`/`rounds_100`/`round_wins_25` (6), collection/kudos `save_10`/`save_50`/`save_100`/`all_kudos_spent` (4), special `title_collector` (all 7)/`full_lobby`/`clean_sweep` (3). The TDD's §2 table is superseded; `first_worst_drawer` and superlative-anything are void (Slice 19 retired both). Owner display names: Renaissance **Mammal**, Animal Aficionado, Animal Enthusiast, Animal Hoarder. `tests/core/stats/test_achievement_defs.gd` **pins the exact 27 ids** — a failure there means a forbidden rename of a Steamworks API name.
2. **Stats-API reconciliation (the TDD's §6 predates SDK 1.64):** `requestCurrentStats`/`current_stats_received` are GONE — ClassDB-probed against the vendored GodotSteam 4.20 this session. Unlock code gates on `is_stats_ready()` = init success (already shipped by Slice 12); `setAchievement`/`getAchievement`/`storeStats` are all present and synchronous. `getAchievement` returns `{"ret": bool, "achieved": bool}`.
3. **`titles_awarded` payload is pid → Array[String]** (Slice 19: titles stack) — the handler iterates and bumps every earned title in one persist.
4. **New counters beyond the TDD:** `games_full_lobby` (game_ended with ≥ 8 standings rows — disconnected players still appear, which is the honest read of "an 8-player game") and `clean_sweeps`. Clean Sweep uses per-game transients (`_game_rounds`/`_game_round_wins`), reset at LOBBY and after each `game_ended`: **min 3 rounds, every attended round won**. A late joiner who sweeps every round they saw (≥ 3) gets it — favor generosity (brief §1); noted as intended.
5. **Stats sandboxing (pin-rule lesson generalized):** the Stats autoload listens to EVERY process, so (a) under the GdUnit harness it self-sandboxes (`ci_stats_gdunit.json` — cmdline detection in `_ready`), and (b) both CI drivers (`round_ci_driver`, `resilience_ci_driver`) set a per-PID `Stats.path`, exactly like `CollectionStore.root_dir`. Without this, every gate run would bump the owner's real lifetime stats.
6. **Test seams:** `Stats.path`, `Stats.platform_id_override`, `Stats.reset_for_test()` (PublicNoticeGate/AvatarStore precedent). The mock backend test swaps `Platform.backend` with a recording `PlatformBackend` subclass — asserts one `setAchievement` per id ever and one `storeStats` per batch, then a full re-reconcile no-op.
7. **Platform seam:** `steam_achievement_is_set`/`steam_set_achievement`/`steam_store_stats` on `PlatformBackend` (no-op defaults → EnetBackend inherits), SteamBackend impl (all `_init_ok`-guarded), PlatformService forwarders. `Stats` autoload registered last (after Save/Platform/Session — order per TDD).

## Why the blocking owner check moved to Slice 15

The TDD's blocking check (live unlock toast) assumed Spacewar could carry a test achievement. It can't: App 480's achievement set is fixed and our API names don't exist there — `setAchievement("first_game")` under Spacewar just returns false (harmless; the reconcile retries forever by design). The toast check is earmarked in qa-backlog to run **with the real App ID registration** (Slice 15), alongside the already-earmarked Slice 12 re-verification. Everything testable without it is machine-verified; the offline-accrual and delete-and-relaunch checks are batchable now.

## Slice 15 owner task (filed in qa-backlog)

Create all **27** achievements on the Steamworks partner site with the exact API names from `core/stats/achievement_defs.gd` (display names/descriptions there are working copy — finalize on the site; icons needed per achievement).

## Files

- **New:** `core/stats/stats_service.gd` (autoload `Stats`), `core/stats/achievement_defs.gd`, `tests/core/stats/test_stats_service.gd` (20 cases), `tests/core/stats/test_achievement_defs.gd` (6 cases)
- **Modified:** `core/platform/platform_backend.gd` / `steam_backend.gd` / `platform_service.gd` (achievement trio), `core/events/event_bus.gd` (`achievement_unlocked`), `project.godot` (autoload), both CI drivers (stats sandbox)
