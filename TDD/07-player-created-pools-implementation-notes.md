# Implementation Notes: Slice 7 - Player-Created Prompt Pools

**Completed:** 2026-07-07 (core-confirmed; force-continue human check + batchable items deferred to qa-backlog per owner QA process)
**TDD Document:** [07-player-created-pools.md](07-player-created-pools.md)

## Implementation Summary

Implemented exactly the TDD's shape: a deadline-less `POOL_SETUP` phase between Start and round 1 when `pool_source == PLAYER_CREATED`. `CustomPoolCollector` (host-only, RefCounted, session-scoped) owns share math (`ceil(round_count ÷ player_count)` — the brief's examples are pinned tests), atomic per-pool validation (trim, ≤24 chars, single-line, `TextFilter.is_clean`, duplicates legal), and completion gating with a `mark_departed()` Slice 9 extension point. On completion (or host force-continue after 120 s) the pools lock: words are handed to `PromptPools.set_custom_source()`, custom words draw **without replacement**, and any shortfall **silently backfills** from the built-in pools with no marker in any payload (verified by an end-to-end integration test asserting exact broadcast key sets). The submission screen builds one column per `pool_id` from phase data — future pool types get submission UI for free. The lobby's Player-created option is now selectable (a host edit handler was also wired; the option had never had one while gated).

## Deviations from Original Design

### `WordRejectReason` gained an explicit `NONE = 0`
**Original Plan:** `enum WordRejectReason { NOT_CLEAN, BAD_LENGTH, ... }` with `submit()` returning "OK (0) or a reason".
**Actual Implementation:** `enum WordRejectReason { NONE, NOT_CLEAN, BAD_LENGTH, WRONG_COUNT, ALREADY_SUBMITTED, LOCKED }`.
**Reason for Deviation:** the TDD draft's `NOT_CLEAN` would have been 0 — indistinguishable from `OK`.
**Impact:** none outside this slice; enum is append-only from here (wire rule).

### Rejection routing is a GameSession signal, not an RPC-handler decision
**Original Plan:** the RPC table implies the handler decides when to send `rpc_do_words_rejected`.
**Actual Implementation:** `GameSession.pool_words_rejected(player_id, pool_id, reason)` is emitted only for honest validation failures from eligible senders (drop-tier input — unknown sender/pool, post-lock — emits nothing, per §5); `SessionClient` translates it to a targeted RPC, host-local path included. Mirrors the Slice 4 `kudos_confirmed` pattern and keeps the drop-vs-reject rule unit-testable without a network.
**Impact:** none on the wire; behavior matches the TDD's §5/§10 intent.

### Progress payload carries `display_name`
**Original Plan:** `[{player_id, pools_done, pools_total}]`.
**Actual Implementation:** host resolves and includes `display_name` (waiting panel needs names; clients would otherwise each do roster lookups).
**Impact:** additive key; readers tolerate it.

### PromptPools: branch, not a unified `_draw_word`
**Original Plan:** §6 sketched one `_draw_word` for both sources.
**Actual Implementation:** `_compose` branches — the built-in path is **byte-identical** to Slice 3 (`_sample_without_replacement`), custom draws live in a separate `_draw_custom` with per-word built-in backfill (`_sample_builtin_excluding`, bounded retries for within-prompt distinctness).
**Reason for Deviation:** existing seeded-RNG tests pin exact built-in draw sequences; a unified path would have silently changed them.
**Impact:** none behaviorally; custom sources also cleared on `load_from()` (fresh content = fresh session).

### Pool display names are derived, not data
**Original Plan:** `pool_display_names` mapping implied per-pool display data.
**Actual Implementation:** `pool_id.capitalize()` ("animals" → "Animals") — pool JSON files carry no display names today.
**Impact:** if content ever needs localized/custom pool labels, add a `display_name` key to the pool JSON and thread it through `_enter_pool_setup`.

### Single screen, no host variant scene
The host-only force-continue row is the same scene with `HostRow` visibility gated on `multiplayer.is_server()`; the confirm dialog is Slice 1's `ConfirmDialog`.

## Files Created/Modified

**Created:**
- `game/prompts/custom_pool_collector.gd` — share math + validation + completion
- `ui/round/pool_setup_screen.tscn` / `.gd` — submission UI, waiting panel, force-continue
- `tests/game/prompts/test_custom_pool_collector.gd` (14 tests)
- `tests/ui/round/test_pool_setup_screen.gd` (5 tests)

**Modified:**
- `core/constants/game_constants.gd` — `WORD_MAX_CHARS = 24`, `POOL_SETUP_FORCE_AVAILABLE_SEC = 120.0`
- `core/constants/net_ids.gd` — `WordRejectReason`
- `core/events/event_bus.gd` — `pool_setup_progress_changed`, `pool_words_rejected`
- `game/prompts/prompt_pools.gd` — real `set_custom_source`, without-replacement custom draws, silent backfill
- `game/session/game_session.gd` — real `_enter_pool_setup`, `submit_pool_words`, `force_lock_pools`, `_lock_pools_and_start`, `pool_setup_progress`, two signals
- `game/session/session_client.gd` — POOL_SETUP replica, `request_submit_pool_words`, `force_continue_pool_setup`, host translators, 3 RPCs (`rpc_request_submit_words`, `rpc_do_words_rejected`, `rpc_sync_pool_setup_progress`)
- `ui/round/round_root.gd` — `POOL_SETUP → pool_setup_screen` registration
- `ui/lobby/lobby_screen.gd` — Player-created selectable + `_on_pool_selected` handler
- `tests/game/session/test_game_session.gd` — 8 pool-setup tests incl. 2 end-to-end integrations
- `tests/game/prompts/test_prompt_pools.gd` — 6 custom-source/backfill tests
- `TDD/03-core-round-loop.md` — POOL_SETUP phase-data row filled in

## Key Implementation Details

- **No deadline timer:** `_enter_phase(POOL_SETUP, 0.0, …)` — the phase ends by completion or `force_lock_pools()` only. Consequence: **host pause is unavailable during POOL_SETUP** (`pause()` requires an armed phase clock); the Esc menu still opens for Leave. Fine for v1 — there is no clock to freeze — but noted in the qa-backlog.
- **Lock idempotency:** the final-submission/force-continue race is settled by `_collector.locked` check-and-set; `_begin_round(0)` provably runs once (tested).
- **Force gate:** evaluated only on the host's own clock (`_now_ms` injectable; before/after tested) — client clock skew is structurally irrelevant.
- **Round count + eligibility snapshot at Start:** roster churn during setup changes neither shares nor round count (tested); late joiners can never submit.

## Testing Summary

- Unit + integration: **+33 tests this slice; full suite 329/329 green** (collector 14, pools 6, session 8 — incl. 14-round full-participation and force-continue-shortfall end-to-end runs asserting only-submitted-words / exactly-2-undrawn / backfill-invisible-in-payloads — UI screen 5).
- Automated gates: `verify_lobby.sh` PASS, `verify_round.sh` PASS (built-in source regression).
- **User confirmation (2026-07-07):** core blocking flow confirmed on 3 LAN instances — players are sent to the submission screen, submits work, and the game's prompts use the player-made words.

## Lessons Learned

- Keeping the built-in draw path byte-identical (branch instead of refactor) made the seeded-RNG test suite a free regression net for this slice.
- The signal→targeted-RPC translator pattern (from Slice 4 kudos) is now the house style for per-peer verdicts; the 5-step table in new TDDs should assume it.

## Known Limitations

- **Force-continue human check deferred** (owner, 2026-07-07): the 2-minute unlock + invisible-backfill flow is machine-verified but not yet human-seen — qa-backlog deferred blocking section.
- Pause is a no-op during POOL_SETUP (no phase clock) — revisit in Slice 9 if below-minimum pause needs to cover it.
- `POOL_SETUP_FORCE_AVAILABLE_SEC = 120` is untuned; log a decision if playtests want it shorter.
- Editing/withdrawing a submitted pool is unsupported by design (v1).
