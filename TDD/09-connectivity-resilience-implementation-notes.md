# Implementation Notes: Slice 9 - Connectivity & Resilience

**Completed:** 2026-07-07 (session 7; owner blocking checks confirmed same day — "seems to be working!")
**TDD Document:** [09-connectivity-resilience.md](09-connectivity-resilience.md)

## Implementation Summary

Design brief §9 in full, on top of the machinery that actually shipped in Slices 3/6/17. Late joiners register mid-game through the same `rpc_request_register` (the Slice 2 "in_progress" reject became the rejoin/late-join router), start at 0 points with the FULL cached standard kudos allotment (owner decision 2026-07-07, superseding the brief's half rule; explicit kudos-off grants 0), slot into the rotation immediately behind the current judge, and draw from the next round while reacting/kudosing immediately. Disconnect and deliberate quit are identical: the roster entry is retained as the memory (`mark_disconnected` zeroes the transport id), a submitted drawing stays fully in play, an unsubmitted dropped drawer gets NO card (blanks are synthesized for connected drawers only), and rejoin (`rebind_peer`, keyed by `platform_id`) restores score/kudos/rotation slot exactly. Below `MIN_PLAYERS` connected, the game freezes through the existing PAUSED pipeline with a new reason tag; any admission that recovers the roster auto-resumes with the frozen clock restored; the host can end early from the overlay into a results bundle built from completed rounds only. The `fluid_rejoin` toggle (default ON private / OFF public, host override wins, never preset-locked) arms the one-mechanism dodge guard: leaving as (or just before becoming) the judge flags you; an armed slot reached while absent forfeits with the standard −1.

## Deviations from Original Design

### Rotation: explicit judge cursor instead of the TDD's `insert_after_cursor` on a cursor that didn't exist
**Original Plan:** TDD §2 assumed Slice 3 had an ordered array + `rotation_cursor`.
**Actual Implementation:** Slice 3 shipped `judge_order[round % n]`; a mid-array insert would corrupt modulo indexing. `GameSession` now owns `_judge_cursor`, advanced per round with ghost-skip and the forfeit hook; late joiners insert BEFORE the cursor entry (cursor +1) = last in the cyclic order = judging when the rotation wraps (§9's stated intent).
**Impact:** Byte-identical to the old rotation when nobody drops (Slice 3 sim-harness test untouched and green).

### Pause: reason-tagged reuse of the Slice 6 PAUSED pipeline (no `rpc_sync_pause/resume` RPCs)
**Original Plan:** TDD §3 defined dedicated pause/resume RPCs and a `game_paused(connected_count)` signal.
**Actual Implementation:** `GameSession.pause(reason)` / `resume()` (Slice 6) extended: `NetIds.PauseReason` rides the PAUSED phase data with `connected_count` + `time_left_ms`; RoundRoot picks GameMenu (HOST_MENU) vs the new waiting overlay (BELOW_MINIMUM). Pause covers deadline-less POOL_SETUP. `EventBus.game_paused(reason, connected_count)` / `game_resumed(phase, time_left_ms)` emit from the phase pipeline.
**Impact:** One replication channel for all phase state; no new wire surface.

### Wrap-up input folded into the results bundle (no standalone `get_wrapup_input()`)
**Original Plan:** TDD §6 defined a parallel dictionary contract for Slice 10.
**Actual Implementation:** `_build_results()` gained `ended_early`, `rounds_played`, `rounds_planned`, `players` (all roster entries incl. disconnected, remembered scores, `joined_late`, `kudos_spent`); `end_game_early()` emits the same bundle with `ended_early = true`. TDD 09's "round_history"/"reaction_stats" map to the existing `rounds`/`reaction_stats` keys.
**Impact:** Slice 10 reads one shape for natural and early ends; the Slice 3 placeholder standings screen renders both unchanged.

### Departure ordering: pause wins over advancement (found by the CI gate design pass)
**Original Plan:** TDD §6 ordered drop steps as status → drop rules → pause check.
**Actual Implementation:** `handle_departure` checks pause BEFORE re-evaluating all-ready or locking a completed pool setup. In a 3-player game, a leaver would otherwise complete the remaining group's unanimity and advance the phase (or start round 0) in the same call that should have frozen the game. Regression-tested both ways; a completion that becomes satisfied during a freeze settles on resume.
**Impact:** Below-minimum freezes are strict; no phase ever advances under minimum.

### Absent-judge penalty matrix + flag consumption
**Original Plan:** §5 table: window-end −1 for the absent judge only if dodge-suspect under fluid OFF.
**Actual Implementation:** As specified — plus the window-end penalty CONSUMES `dodge_suspect`, so the same dodge can never also forfeit the player's next slot (double −1). A connected judge's no-pick −1 is unchanged. Also fixed a latent Slice 17 gap this table exposed: a disconnected judge silently left the JUDGING ready quorum, so unanimous drawers could force an early end with an empty latch (accidental −1). The judge seat now HOLDS: no early JUDGING end without the judge's pick-gated ready.

### Mid-DRAWING rejoiner sit-out is host-enforced
**Original Plan:** §6 described the sit-out as a client reality ("they have no canvas state").
**Actual Implementation:** `_sit_out_drawers` on the host: resubmissions are dropped (protecting any drawing submitted before the drop), no blank is synthesized, and the player is excluded from the DRAWING ready set (they must never block the early end). Cleared every `_begin_round`. Client mirrors it for the spectator banner + DRAWING screen routing (judge-wait view).

### Welcome snapshot: stored on Session, replayed through `rpc_sync_phase`
**Original Plan:** §3's `rpc_do_welcome_ingame` on "the Session autoload" with clients "reconstructing" state.
**Actual Implementation:** The RPC lives on Session (the joiner has no RoundRoot yet); the payload survives the Nav swap via the close-reason stash pattern (`consume_pending_welcome`), and the fresh SessionClient replays it through the exact live-broadcast handler (`rpc_sync_phase` local call; PAUSED applied as a wrapper after the underlying phase), so every EventBus ordering contract holds. JUDGING snapshots carry the reveal entries (live JUDGING broadcasts never do — the `entries` key in JUDGING data is welcome-path only); POOL_SETUP snapshots carry current progress; RoundRoot chains `setup` + `enter_judging` when a screen is born directly into JUDGING.

### Late joiners get the FULL standard allotment (owner decision, playtest day)
**Original Plan:** §2/§6: half the standard allotment, floored, minimum 1 (brief §11).
**Actual Implementation:** `admit_late_joiner` grants the cached `_standard_allotment` outright; `late_join_allotment()` and the `LATE_JOIN_*` constants were deleted. Kudos-off (explicit 0) stays off.
**Reason for Deviation:** Owner call during the blocking playtest — kudos benefit the recipient, so a full wallet is gifting power, not advantage; simpler rule. Brief §11 amended in place; see decision log 2026-07-07.
**Impact:** None outside this slice (no wire/UI change).

### EventBus status signals keyed by platform_id
**Original Plan:** §3 mixed `peer_id` (late-join/rejoin) and `platform_id` (drop).
**Actual Implementation:** All three are `(platform_id, display_name)` — the stable identity everything else uses; peer ids travel only in the roster broadcast. `rpc_sync_player_status(platform_id, kind, display_name)` with `NetIds.PlayerStatus` is the single event vehicle.

### POOL_SETUP departures: `mark_returned` added
**Original Plan:** §2/§6 only specified `mark_departed`.
**Actual Implementation:** A rejoiner during POOL_SETUP gates completion again (`CustomPoolCollector.mark_returned`) — departure only stops a player from blocking while away; their share is theirs to finish when they return.

### CI: new resilience gate + two hardening lessons
- **`tools/verify_resilience.sh`** (~35 s): host + stay + leaver; the leaver submits a marked drawing, quits mid-DRAWING (below-minimum pause on the remaining peers), rejoins ~2.5 s later (auto-resume; frozen timer restored within tolerance on the stay peer; rejoiner spectates), and its kept submission is crowned (+2 to the remembered score). Per-role phase-log equality, pause reason/count, status events, and the wrap-up contract keys verified on every peer.
- **Idempotent driver spawn:** the leaver's deliberate quit reloads the main menu, which re-runs `_handle_ci_args` — the first run spawned a second driver that fought the first (early rejoin + a duplicate leave). Drivers must guard against re-spawn on menu reload.
- **Cross-gate profile pollution:** gates share `user://profile.json`; verify_resilience's pinned GRID/10 s settings persisted via `last_lobby_settings` and broke verify_round's beat expectations on the next run. verify_round now pins `reveal_style/replay_mode/reveal_replay_secs/judging_window_sec`. Rule extended: **pin every setting your flow depends on — including ones another gate might save.**

## Files Created/Modified

**Created:**
- `ui/round/pause_overlay.gd/.tscn` — below-minimum waiting overlay (host-only End-game-now, two-click confirm)
- `ui/round/late_join_wait.gd/.tscn` — spectator banner (late joiner / sit-out rejoiner)
- `tools/ci/resilience_ci_driver.gd`, `tools/verify_resilience.sh` — automated Slice 9 gate
- `tests/game/session/test_game_session_resilience.gd` — 27-test suite (late join, rejoin, drop rules, dodge/forfeit, pause/resume, wrap-up contract, ready-set integration, POOL_SETUP departures)

**Modified:**
- `core/constants/game_constants.gd` — `JUDGE_DODGE_WINDOW_SEC`
- `core/constants/net_ids.gd` — `PauseReason`, `PlayerStatus` (append-only)
- `core/events/event_bus.gd` — 6 Slice 9 signals
- `game/session/roster.gd` — `joined_late/disconnect_at_ms/dodge_suspect` (+serialization), `mark_disconnected`, `rebind_peer`
- `game/session/settings.gd` — `is_public/fluid_rejoin/fluid_rejoin_overridden`, `apply_public_default`, `CONNECTIVITY_TUNABLE` lock exemption
- `game/session/session_rules.gd` — `ingame_register_action` (pure routing validator)
- `game/session/session_manager.gd` — register branch swap + `_handle_ingame_register`, in-game disconnect path, `rpc_do_welcome_ingame`, `rpc_sync_player_status`, welcome stash, `round_client` handle
- `game/session/game_session.gd` — judge cursor + forfeit, drop rules in collect, sit-out, ready-set integration (`_advance_if_all_ready`, judge seat-hold), pause/resume/reason, `end_game_early`, results contract keys, `admit_late_joiner/admit_rejoiner/handle_departure`, dodge guard, `build_welcome_snapshot`
- `game/session/session_client.gd` — welcome apply + spectator replica, `game_session()` accessor, `request_end_game_early`, PAUSED/resume/forfeit/JUDGING-entries handling in `rpc_sync_phase`, Session handle registration
- `game/prompts/custom_pool_collector.gd` — `mark_returned`
- `ui/round/round_root.gd/.tscn` — pause routing by reason, spectator banner + DRAWING routing, coalesced status toasts, fresh-JUDGING `enter_judging` chain
- `ui/lobby/lobby_screen.gd/.tscn` — Connectivity row (Public lobby + Fluid rejoin checkboxes)
- `ui/menu/main_menu_screen.gd` — resilience CI hook (idempotent spawn)
- `tools/ci/round_ci_driver.gd` — reveal/judging settings pinned
- Tests extended: `test_roster.gd`, `test_settings.gd`, `test_session_validation.gd`, `test_round_scenes.gd`

## Key Implementation Details

- **The retained roster entry IS the memory:** score lives in `Scoring` (platform-id-keyed, never cleared), kudos in the entry's `granted/spent` (never re-granted), the rotation slot in the never-pruned `_judge_order`. Rejoin is a rebind, not a re-registration.
- **Ghost capacity rule:** admission checks use `connected_count()`, never entry count — memory entries can exceed 8 without blocking a live player; a known disconnected platform_id rejoins even when entries are "full"; a connected duplicate identity is rejected `bad_identity` (never evict a live player).
- **Dodge evaluation is instantaneous at disconnect:** current judge → suspect; next-judge-with-phase-ending-inside-30s → suspect; no armed phase clock (POOL_SETUP/PAUSED) → only the current-judge test. `_next_judge_id_counting` counts the just-disconnected player as present ("would you have been next").
- **Resume broadcast races the rejoiner's navigation by design:** the phase re-broadcast targets `RoundRoot/SessionClient`, which the rejoiner doesn't have yet — the engine logs "node not found" on that peer and drops it; the welcome snapshot (built after the resume) carries the same state. Expected noise in gate logs.
- **PAUSED deadline is zeroed** so nothing reads a stale clock while frozen (the dodge window test in particular).

## Testing Summary

- **Unit/scene:** +43 this slice; full suite **423/423 green, 0 orphans** (resilience 27, settings/roster/rules 10, UI smokes 3, key-shape pins updated).
- **Automated gates (guarded wrapper):** `verify_lobby.sh` PASS, `verify_round.sh` PASS (after the pinning fix), **new `verify_resilience.sh` PASS** on all three roles.
- **User confirmation (2026-07-07):** blocking checks confirmed on a 4-instance windowed run (drop mid-DRAWING, below-minimum pause/resume, rejoin restore, late-join placement) — owner: "seems to be working!" (kudos counts eyeballed loosely; the economy is unit-pinned). Batchables → qa-backlog Slice 9 section.

## Lessons Learned

- Reading the dependency slices' implementation notes before coding caught all three big TDD-vs-reality gaps (rotation model, pause pipeline, results bundle) before any code was written — zero rework from those.
- A departure is three events in one (roster change, quorum change, capacity change); ordering them (pause before advancement) needed an explicit rule and tests, not intuition.
- Multi-process CI finds a class of bug unit tests can't: both gate failures this session (duplicate driver on menu reload, cross-gate profile pollution) were interaction effects between infrastructure pieces that are each individually correct.

## Known Limitations

- Host quit remains game-over for everyone (no host migration in v1, per TDD).
- Ready state doesn't survive any pause/resume (players re-press Done) — accepted Slice 17 limitation, now also applies to below-minimum pauses.
- A late joiner / rejoiner landing mid-POOL_SETUP sees a submission screen that isn't (fully) theirs to use — host-side correctness holds; UI polish in the qa-backlog.
- `rpc_do_kudos_confirmed` to a giver who dropped mid-request is still lost (no retro-delivery on rejoin — matches "no retry queue in v1", Slice 4 note).
- Connection flapping has no cooldown by design (§10) — each cycle is a cheap rebind + snapshot; toast coalescing keeps the UI calm.
