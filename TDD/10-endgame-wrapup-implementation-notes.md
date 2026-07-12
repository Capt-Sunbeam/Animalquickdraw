# Implementation Notes: Slice 10 - End-Game Wrap-Up

**Completed:** 2026-07-07 (session 8; machine-verified — owner checks batched to end-of-session list per owner instruction)
**TDD Document:** [10-endgame-wrapup.md](10-endgame-wrapup.md)

## Implementation Summary

The "your game, wrapped" closer, built on the reconciled input contract (decision log 2026-07-07: the wrap-up input is the extended SessionResults bundle, not the TDD-09 draft's standalone dict). `WrapUpCalculator` (pure static, host-only, headless-tested) computes superlatives (one per Reaction, zero-count omitted), the v1 title set (8 titles, priority assignment, at-most-one-card-per-player, minimums, full tie-break chains, evidence selection), title/superlative points (+1 each, `title_points_enabled`-gated, default on), and final standings (base + title points, competition ranking, negatives unclamped, disconnected players included). The bundle — with every referenced DrawingDoc embedded and deduped — rides **inside the existing results dictionary** as `results["wrap_up"]`, broadcast once through the WRAP_UP `rpc_sync_phase`. SessionClient validates the shape client-side and emits `wrap_up_started` → `titles_awarded` → `game_ended` (before `phase_changed`, per the ordering contract); the new `ui/wrapup/` screen plays the three-act sequence locally (superlative cards with a ≤3 s replay flourish → static title cards → podium-order standings) with per-peer Skip (finish-then-advance semantics), then emits `wrap_up_sequence_finished` and shows the Slice 3 post-game controls. A host quit mid-sequence is deferred by a new Session hold and degrades the end state to Leave-only. Slice 3's placeholder standings screen is deleted.

## Deviations from Original Design

### No `rpc_sync_wrap_up_bundle` RPC — the bundle rides the results
**Original Plan:** TDD §3 defined a dedicated host→all bundle RPC.
**Actual Implementation:** `_build_results()` gained a `"wrap_up"` key computed by `WrapUpCalculator.build_bundle(...)`; the WRAP_UP phase broadcast (already carrying results) is the only wire surface. Client-side shape validation (`SessionClient.is_valid_wrap_up_bundle`: v==1 + typed keys) guards the three signal emissions; a malformed bundle drops with a warning and the screen degrades to base standings.
**Reason:** One replication channel for round state (consistency guide §4/§5); Slice 9 set the precedent by folding the wrap-up input into the same bundle. Late joiners/rejoiners during WRAP_UP get everything via the welcome snapshot for free (it replays `_last_phase_data`).
**Impact:** Slice 14 subscribes to the EventBus signals exactly as the TDD promised; no wire-format change for anyone else.

### No `Routes.WRAP_UP`, no `begin_wrap_up()`
**Original Plan:** §3/§6: `Nav.goto(Routes.WRAP_UP)` and a new `GameSession.begin_wrap_up(early)`.
**Actual Implementation:** The wrap-up screen is a RoundRoot **phase screen** (`PHASE_SCREENS[WRAP_UP]`), like every in-round surface (consistency guide §8 wins). The shipped entry points already exist: `_advance_round()` (natural end) and Slice 9's `end_game_early()` (early end) both flow through `_build_results(early)`. Idempotency the TDD wanted from `begin_wrap_up` holds structurally: `end_game_early` requires PAUSED and WRAP_UP re-entry is impossible (regression-tested).

### Bundle `drawings` map shape: `{"doc": ..., "prompt": ...}` per entry
**Original Plan:** §2 embedded the prompt inside the DrawingDoc dict itself.
**Actual Implementation:** Each entry wraps the untouched canonical doc plus its prompt. Docs stay byte-identical to what was submitted (no non-canonical keys inside the doc format).

### RoundRecord gained `reveal_order`
The superlative tie-break needs the on-screen reveal order, which was never recorded (entries are shuffled after RoundRecord submissions are appended in drawer order). `_collect_and_reveal` now writes the post-shuffle id order onto the record; `drawing_infos` sorts by it. Old records without it (tests) fall back to submission order.

### Speed Demon finish time = last *stroke* timestamp
**Original Plan:** §2 "last op `ts` ÷ round draw-time" over non-empty drawings.
**Actual Implementation:** Fill/clear/text ops carry no timestamps, so a doc's finish time is its latest stroke timestamp; docs with zero stroke timestamps are excluded from the mean, and eligibility requires ≥ 2 *timestamped* docs. Draw time is the frozen `draw_time_sec` (per-round times don't exist — settings are a frozen snapshot).

### Host-quit deferral lives on Session (`hold_host_quit`)
**Original Plan:** §10 "server_disconnected handling is deferred until wrap_up_sequence_finished".
**Actual Implementation:** `Session._on_server_disconnected` remembers the quit instead of navigating while the wrap-up screen holds the flag (set in `_ready`, released at sequence end or screen exit). If the quit arrived mid-sequence, the end state shows **Leave** instead of "Waiting for the host..." and the player exits on their own terms; flags reset with session state.

### Base `final_scores`/`standings` keys stay base-only
Title/superlative points live **only** in `wrap_up.standings` (the authoritative final display). The Slice 3 bundle keys keep their pinned shape; the CI drivers' score-sum checks read them unchanged.

### Fixed in passing: ReplayPlayer null race in `_process` (pre-existing, Slice 5)
`WinnerSpotlight._process` (and my identical first cut of `SuperlativeCard`) crashed with "Nonexistent function 'get_image' in base 'Nil'" on the exact frame a replay finished naturally: `advance()` synchronously emits `finished`, whose handler nulls `_player`, and the next line dereferenced the field. Every natural victory-lap finish logged this error (masked as gate-log noise since Slice 5; the final still-frame update was silently skipped). Both `_process` implementations now capture the player in a local before advancing.

### CI pin rule struck again: `kudos_allotment`
`verify_round`'s wallet check (judge 1→0) assumes the AUTO allotment, but the driver never pinned `kudos_allotment` — the owner's real playtest profile carried an explicit `2` via `last_lobby_settings`, granting 2 kudos and failing the gate. Pinned to `KUDOS_AUTO`. Third instance of the class; the rule stands: **pin every setting your flow depends on, including ones a human playtest may persist.**

## Files Created/Modified

**Created:**
- `core/constants/title_ids.gd` — title + superlative ids and display names (append-only wire contract for Slice 14)
- `game/session/wrap_up_calculator.gd` — the whole §6 computation surface
- `ui/wrapup/wrap_up_screen.gd/.tscn` — sequence state machine, skip, progress dots, post-game controls
- `ui/wrapup/superlative_card.gd/.tscn` — replay flourish (capped), reaction count, author reveal, "+1" chip
- `ui/wrapup/title_card.gd/.tscn` — static evidence fan (max 3), "(left early)" dimming
- `ui/wrapup/standings_panel.gd/.tscn` — podium reveal (3rd→2nd→1st→rest), winner pulse, breakdown tooltips
- `tests/game/session/test_wrap_up_calculator.gd` (18), `tests/ui/wrapup/test_wrapup_scenes.gd` (9)

**Modified:**
- `core/constants/game_constants.gd` — WRAPUP_* pacing constants (TITLE_POINTS_VALUE existed)
- `core/events/event_bus.gd` — the four Slice 10 signals
- `game/session/round_record.gd` — `reveal_order`
- `game/session/game_session.gd` — reveal-order capture, `_build_results(early)` + `wrap_up` key + `_wrapup_players_meta()`
- `game/session/session_client.gd` — WRAP_UP branch signal emissions + bundle validator
- `game/session/session_manager.gd` — host-quit hold/pending
- `ui/round/round_root.gd` — WRAP_UP → wrap-up screen
- `ui/round/winner_spotlight.gd` — null-race fix
- `tools/ci/round_ci_driver.gd` — `kudos_allotment` pin
- `tests/game/session/test_game_session.gd` (+3 integration), `tests/ui/round/test_round_scenes.gd` (standings screen tests replaced)
- **Deleted:** `ui/round/standings_screen.gd/.tscn`

## Key Implementation Details

- **Determinism:** infos are ordered (round asc, reveal asc); strictly-greater/lesser comparisons over that order ARE the drawing-level tie-breaks. Player ties: stat → earlier best-evidence round → lower rotation index (`_judge_order` position — late joiners included deterministically). `test_same_inputs_produce_identical_bundle` pins deep equality.
- **Partial rounds contribute nothing by construction** — the calculator only reads `_records`; Generous Soul filters kudos_events to recorded drawings, so a spend on a never-resolved round's drawing is frozen out with its round.
- **GDScript lambda captures are by-value** (three test-writing rounds re-learned it): mutate a captured container, never reassign the variable. The Rig pattern exists for this reason.
- Worst Drawer counts synthesized blank cards (they are reactable); its zero-total label reads "not a single reaction or kudos".
- The wrap-up screen tolerates a missing/invalid bundle end-to-end (fallback standings from base results keys) — the RoundRoot smoke test drives that path.

## Testing Summary

- **Unit/scene:** +31 this slice; full suite **453/453 green, 0 orphans** (calculator 18, wrap-up UI/relay 9, GameSession integration 3, round-scenes swap updated).
- **Automated gates (guarded wrapper):** `verify_lobby.sh` PASS, `verify_round.sh` PASS (after the allotment pin; zero script errors in the log post-fix), `verify_resilience.sh` PASS.
- **User confirmation:** BATCHED per owner instruction (2026-07-07) — including the TDD's normally-blocking early-end check. See the end-of-session test list / qa-backlog Slice 10 section.

## Lessons Learned

- Synchronous signal emission mid-method is a footgun: any handler that mutates the emitter's caller state (nulling `_player`) breaks the very next line. Capture locals before calls that may emit.
- The CI pin rule needs to include *human playtest residue*, not just other gates — the owner's real profile is a third writer to `last_lobby_settings`.

## Known Limitations

- Title cards show name text; Slice 11 retrofits `AvatarChip` (96 px) here and in standings rows.
- Card motion is fades/steps, not the TDD's slide choreography sketches — same v1 stance as the Slice 5 reveal polish (backlogged).
- `stat_label` strings are English-only literals (localization is out of v1 scope).
- Skip is per-card; there is no "skip whole sequence" affordance (holding Space works in practice).
