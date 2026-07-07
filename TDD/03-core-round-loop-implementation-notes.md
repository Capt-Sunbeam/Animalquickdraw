# Implementation Notes: Slice 3 - Core Round Loop

**Completed:** 2026-07-06 (implementation + automated gates; owner playtest confirmation pending)
**TDD Document:** `TDD/03-core-round-loop.md`

## Implementation Summary

The playable MVP. Part 1 (Chunk 5 scope) is the fully headless simulation: data-driven prompt engine (`PoolType`/`Prompt`/`PromptPools` + built-in content: 135 animals, 105 adjectives), `Scoring` with shared-rank standings, and the host-only `GameSession` RefCounted state machine (injectable clock, signal outputs) driving `LOBBY → ROUND_INTRO → DRAWING → REVEAL → JUDGING → RESOLUTION → … → WRAP_UP` with judge rotation, latest-wins submissions with grace window, blank synthesis, anonymized shuffled reveals, +2/−1 scoring, and the versioned SessionResults bundle. Part 2 (Chunk 6 scope) wires it over the network: `SessionClient` RPC endpoint on every peer, host-driven one-broadcast-per-phase deadlines, `RoundRoot` with per-phase/per-role screens (judge never sees a canvas), client-side reveal rasterization through the Slice 1 renderer, and the minimal standings screen with a working return-to-lobby loop.

Automated end-to-end gate (`tools/verify_round.sh`) passes: host + 2 clients play a full 2-round game over ENet — pick round (+2), deliberate no-pick lapse round (−1), phase sequences, role views, and results bundles verified on all three peers.

## Deviations from Original Design

### Round-start readiness handshake (new RPC `rpc_request_round_ready`)
**Original Plan:** "On Start, all peers navigate to Routes.ROUND; host then calls `GameSession.start_game()`" — no ordering mechanism specified.
**Actual Implementation:** Client `SessionClient`s report ready to the host on `_ready`; the host starts the simulation when every connected roster peer has reported, or after `ROUND_START_FAILSAFE_SEC` (3 s) regardless — a broken client can never stall the start (favor flow, brief §1).
**Reason for Deviation:** `Nav.goto` is deferred; the host's first `ROUND_INTRO` broadcast could reach clients before their `RoundRoot`/`SessionClient` exists (RPC to a missing node path is dropped, not queued). The failsafe covers hostile/crashed clients.
**Impact:** Slice 9's rejoin flow can reuse the same readiness signal.

### Return-to-lobby broadcast (new RPC `rpc_sync_return_to_lobby` on Session)
**Original Plan:** Standings screen lists "Back to lobby (host) / Waiting for host (clients)" with no mechanism.
**Actual Implementation:** `Session.return_to_lobby()` (host-only) broadcasts; all peers reset phase to LOBBY and navigate back with roster and settings intact; the host prunes players who dropped mid-game (lobby rules resume) and re-broadcasts state. Makes the whole loop replayable without restarting the app.
**Impact:** Slice 10's real wrap-up inherits a working exit path.

### `is_local_player_judge` resolves identity via `Session.local_player()`
**Original Plan:** TDD §8 sketch referenced `Net.local_player_id()`.
**Actual Implementation:** `Net` is transport-only and has no player identity; the roster mirror on `Session` maps `Net.local_peer_id()` → `platform_id` on every peer.
**Impact:** None; note for future TDD sketches.

### Multi-process gate replaces the in-GdUnit loopback relay test
**Original Plan:** §11 suggested a two-`SceneTree`-peers-over-ENet-loopback smoke inside GdUnit.
**Actual Implementation:** `RoundCiDriver` + `tools/verify_round.sh` — three real processes over real ENet playing a complete game with scripted picks and a no-pick lapse. Covers the relay contract end-to-end (phase sequence equality across peers) plus role views and scoring.
**Reason for Deviation:** Two SceneTrees in one process is not something GdUnit supports cleanly; the session-2 CI-script pattern is proven and closer to reality.

### Minor
- **`drawing_id` minted at collect time**, not on acceptance — TDD §2 and §6 disagreed; collect wins (resubmissions would otherwise churn ids nobody has seen).
- **WRAP_UP broadcasts without `deadline_ms`** — `_enter_phase` with duration ≤ 0 arms no timer; SessionClient arms its host timer only when the key is present (matches the §3 data-shape table).
- **DRAWING grace is enforced twice by design:** the host timer fires at deadline + `SUBMIT_GRACE_MS`, and `submit_drawing` also checks the injected clock — so the pure logic honors grace even when tests drive deadlines manually.
- **EventBus ordering contract:** `rpc_sync_phase` emits the phase-specific signal (`reveal_entries_received`, `session_results_ready`, …) *before* `phase_changed`, so screens swapped by `phase_changed` always see a current replica. (The round CI driver initially raced this; documented here deliberately.)
- **GameSession never starts with an empty roster** (defensive guard in `SessionClient._maybe_start_simulation`; unreachable via the 3-player lobby gate).
- **`GameSession.use_pools()` test seam** injects fixture pools; `PromptPools.load_from(dir)` loads fixtures through the same code path as real content.
- **Shuffle uses a session-owned seeded RNG** (Fisher-Yates), not `Array.shuffle()` — tests seed it; `Prompt` sampling within one draw spec is without replacement ("cat-cat hybrid" is not a prompt).
- **Content counts:** 135 animals / 105 adjectives (≥ the ~100 target); sanity tests enforce ≥ 90, non-empty, duplicate-free.

## Files Created/Modified

**Created (game logic):**
- `game/prompts/pool_type.gd`, `game/prompts/prompt.gd`, `game/prompts/prompt_pools.gd`
- `game/prompts/data/pool_types.json`, `animals.json`, `adjectives.json`
- `game/session/scoring.gd`, `submission.gd`, `round_record.gd`
- `game/session/game_session.gd` — host-only round state machine
- `game/session/session_client.gd` — RPC endpoint on all peers

**Created (UI):**
- `ui/shared/phase_timer.gd/.tscn`
- `ui/round/round_root.gd/.tscn` (hosts SessionClient + persistent chat)
- `ui/round/round_intro_screen`, `draw_screen`, `judge_wait_screen`, `reveal_judging_screen`, `resolution_screen`, `standings_screen` (.gd/.tscn each)

**Created (tests/tools):**
- `tests/game/prompts/test_prompt_pools.gd` + `tests/fixtures/prompts/*.json`
- `tests/game/session/test_scoring.gd`, `test_game_session.gd` (incl. 8-round sim harness)
- `tests/ui/round/test_round_scenes.gd`
- `tools/ci/round_ci_driver.gd`, `tools/verify_round.sh`

**Modified:**
- `core/constants/game_constants.gd` — §6 timer/size constants + `ROUND_START_FAILSAFE_SEC`
- `core/constants/routes.gd` — `Routes.ROUND`
- `core/events/event_bus.gd` — 6 Slice 3 signals
- `game/session/roster.gd` — `player_ids_by_joined_order()`
- `game/session/session_manager.gd` — `game_started` → `Nav.goto(ROUND)`; return-to-lobby RPC
- `ui/menu/main_menu_screen.gd` — round CI hooks

## Key Implementation Details

- **Timers:** one `deadline_ms` (unix ms) broadcast per phase; clients render countdowns locally (`PhaseTimer` clamps ≥ 0, urgency = color + number). The host's single re-armed `Timer` is the only authority; early transitions (all-submitted, early pick) simply broadcast the next phase.
- **Judge rotation** is `judge_order[round_index % n]` over platform ids fixed at start from `joined_order`; scores are keyed by platform id, never peer id (Slice 9 reconnect-safe).
- **Anonymity:** reveal entries carry exactly `drawing_id` + `doc`; the `_authors` map never leaves the host; authorship is revealed only for the winner at RESOLUTION.
- **Reveal rendering:** each doc rasterizes once client-side through `DocRasterizer` into a cached `ImageTexture`; the grid shows textures, orientation preserved (portrait entries smoke-tested).
- **Draw screen:** early Submit keeps the canvas editable (latest-wins resubmission); local countdown zero auto-submits unconditionally and locks input; the host's grace window absorbs the transit.
- **Extension hooks in place and inert:** `POOL_SETUP` branch (`pool_setup_entered` observable), `pause()/resume()` with remaining-deadline bookkeeping, `set_custom_source()` stub, reserved `reaction_stats`/`kudos_stats` keys, submission payload tolerates unknown keys (Slice 5 captions).

## Testing Summary

- **Unit/scene tests:** 43 new (prompt engine 10, scoring 6, game session 19 incl. the full-loop sim harness, round scene smokes 8); full suite **178/178 PASSED**, 0 orphans.
- **Sim harness:** scripted 4-player, 8-round game — every player judges exactly twice, no combo repeats, final scores sum to 8×WINNER_POINTS.
- **Automated integration:** `tools/verify_round.sh` **PASS** — 3 processes over ENet, 2-round game, pick + no-pick paths, per-peer phase-sequence equality, role-view checks, results-bundle verification. (`tools/verify_lobby.sh` also still PASS; no Slice 2 regressions — full suite green.)
- **User confirmation:** PENDING — owner directed batched playtests for Slices 2+3 at session end (see WHERE_WE_ARE).

## Lessons Learned

- Signal-ordering contracts (specific signal before `phase_changed`) need documenting the moment they exist — the round CI driver caught the race within minutes of writing it.
- Godot's child-before-parent `_ready` order matters for autonomously-starting nodes: deferring the simulation start was necessary so the host's own RoundRoot never misses the first broadcast.
- The multi-process CI-driver pattern (session 2's `verify_connect` → `verify_lobby` → `verify_round`) scales well; each new slice's gate reuses the previous scaffolding.

## Known Limitations

- Host quit mid-game ends the session for everyone (no host migration in v1 — per TDD; clients toast and return to menu via the Slice 2 path).
- The judge's DRAWING view and reveal grid are functional but bare (programmer art; polish deferred per the art decision).
- Reveal grid columns are a simple sqrt heuristic; extreme window sizes may want manual tuning (batchable playtest item).
- `verify_round.sh` takes ~70 s by design (round 2 waits out the real 30 s judging window).
- Return-to-lobby resets nothing about scores by design (scores live in the finished GameSession; a fresh game constructs a fresh one) — but `PlayerState.score` in the roster remains unused until Slice 10 decides its role.
