# Implementation Notes: Slice 4 - Reactions, Kudos & Saving

**Completed:** 2026-07-06 (implementation + automated gates; owner core-flow confirmation pending)
**TDD Document:** `TDD/04-reactions-kudos-saving.md`

## Implementation Summary

The reveal/judging window is now social. Host-side: `ReactionLedger` (toggle semantics, per-player-per-drawing event cap), `KudosLedger` (allotment math + one-kudos-per-giver-per-drawing), `SessionStats` (the Slice 10 superlatives contract: per-drawing rollups + full event logs, uid-keyed), and `ReactionGate` (opens with JUDGING, closes at RESOLUTION with a 250 ms grace window) all live on `GameSession` with the injected clock. `GameSession.react()` / `give_kudos()` are shared validated entry points (steps 3–4); `SessionClient` carries the RPC surface (steps 1–2) plus three new sync/do RPCs, and translates GameSession signals into broadcasts exactly like the Slice 3 phase pipeline. Kudos = +1 score applied host-side immediately but only ever broadcast at RESOLUTION (anonymity holds by construction — no score sync exists mid-phase). The giver's machine writes the drawing to `user://collection/` (index + canonical doc + thumbnail cache) through the new `CollectionStore` over the `Save` API; the Slice 1 save-toggle now works — the draw screen saves the last *submitted* doc locally when it retires. UI: `ReactionBar` (6 emoji toggles + count badges), `KudosButton` (pending → confirmed flow, no optimistic spend), `KudosWallet` pips, all hanging off the judging grid cells with a local-only "🔒 yours" hint.

Kudos allotment resolves at game start from the settings snapshot: `GameSettings.kudos_allotment` (new field, default `KUDOS_AUTO = -1`) → `KudosLedger.compute_allotment(round_count)` (÷4, half-up, min 1); explicit values pass through (0 = kudos off; min-1 clamp is AUTO-only). Slice 6 adds the host-facing setting UI.

## Deviations from Original Design

### RPCs live on SessionClient, not "GameSession's RPC surface"
**Original Plan:** TDD §3 "All added to the session network node (GameSession's RPC surface from Slice 3)".
**Actual Implementation:** Slice 3 shipped the SessionClient/GameSession split (consistency guide §4): RPC endpoints + steps 1–2 on `SessionClient`; validated entry points (steps 3–5) on `GameSession`, shared by the host's direct path.
**Reason:** Follows the canonical pattern as built; GameSession is a RefCounted with no node path.
**Impact:** None — validation identical, headless-testable.

### No `drawing_grid_cell.tscn` — cells extended in code
**Original Plan:** §7 extends "drawing_grid_cell.tscn (Slice 3 component)".
**Actual Implementation:** Slice 3 builds grid cells in `reveal_judging_screen._build_cell()`; that builder now adds the social row (ReactionBar + KudosButton + own-hint) per cell.
**Impact:** Slice 5's per-beat reveal card should reuse `ReactionBar`/`KudosButton` scenes directly.

### Extra EventBus signal: `collection_save_failed`
**Original Plan:** §3 lists 5 signals.
**Actual Implementation:** Added a 6th — emitted by `CollectionStore` on any failed write; the grid screen shows the shared error toast. `collection_item_added` / `collection_save_failed` are emitted centrally by `CollectionStore` (one choke point for kudos-save and self-save).
**Impact:** Slice 8 can reuse both.

### `Save.write_png()` added
**Reason:** Thumbs are PNG, `Save` only spoke JSON, and the no-direct-FileAccess rule (cg §6) holds. Not atomic by design — thumbnails are a regenerable cache.

### CollectionStore: doc written before index (TDD said index first)
**Reason:** A dangling index entry would surface as a broken item in Slice 8's browser; an orphaned doc file is invisible. Also added `CollectionStore.root_dir` static test seam so suites/CI never touch a real player collection.

### Self-save trigger: draw-screen retire, not the submit call
**Original Plan:** §6 "in the submit path: after the doc is handed to the network layer".
**Actual Implementation:** Saving on every submit would be wrong under latest-wins resubmission (idempotency would freeze the *first* submit). The screen tracks the last submitted doc and saves it once on `tree_exiting` (covers deadline auto-submit, early all-submitted swap, and session teardown). Self-saves use a fresh UUID as `session_drawing_id` (exactly one save per screen lifetime; cross-session collisions impossible).

### KudosButton pending-state re-enable: 2 s timeout instead of "next total/phase sync"
**Reason:** The giver's own successful kudos emits `kudos_total_changed` *before* the private confirm arrives (reliable-channel ordering), so the TDD's heuristic would flicker-re-enable mid-flight. Timeout (plus the natural phase swap) is race-free and simpler. No optimistic spend, exactly per TDD.

### Results bundle keys filled
`reaction_stats = {"totals_by_author"}`, `kudos_stats = {"received_by_author", "drawing_totals"}` — uid-keyed, nonzero-only aggregates (matching the SessionStats query surface). Slice 10 mines the full `SessionStats` host-side; readers must tolerate added keys. The Slice 3 bundle-shape test was updated accordingly (the keys were reserved *for* this slice).

### Aggregate queries are nonzero-only
`reaction_totals_by_author()` / `kudos_received_by_author()` omit authors with zero — consistent with the nonzero-only wire counts. Slice 10 derives zeros from the roster if needed.

## Files Created/Modified

**Created (host logic):** `game/session/reaction_ledger.gd`, `kudos_ledger.gd`, `session_stats.gd`, `reaction_gate.gd`
**Created (save):** `core/save/collection_store.gd`
**Created (UI):** `ui/round/reaction_bar.gd/.tscn`, `kudos_button.gd/.tscn`, `kudos_wallet.gd/.tscn`
**Created (tests):** `tests/game/session/test_reaction_ledger.gd`, `test_kudos_ledger.gd`, `test_session_stats.gd`, `test_reaction_gate.gd`, `test_game_session_social.gd`; `tests/core/save/test_collection_store.gd`; `tests/ui/round/test_social_components.gd`
**Modified:** `core/constants/game_constants.gd` (Slice 4 banner: `REACTION_EVENT_CAP`, `REACTION_CLOSE_GRACE_MSEC`, `REACTION_DEBOUNCE_MSEC`, `COLLECTION_THUMB_MAX_PX`), `core/events/event_bus.gd` (6 signals), `core/save/save_service.gd` (`write_png`), `game/session/settings.gd` (`KUDOS_AUTO` + `kudos_allotment`), `game/session/game_session.gd` (ledgers/stats/gate, react/give_kudos, allotment grant, stats hooks, results keys), `game/session/session_client.gd` (round cache + accessors, 2 request + 3 sync/do RPCs, kudos-confirm collection write), `game/session/session_manager.gd` (`broadcast_roster()`), `ui/round/draw_screen.gd` (self-save on retire), `ui/round/reveal_judging_screen.gd/.tscn` (social row per cell, wallet, toasts), `tests/game/session/test_game_session.gd` (bundle-shape), `tools/ci/round_ci_driver.gd` (social script + verification)

## Key Implementation Details

- **Own-drawing detection is purely local:** `SessionClient` remembers the doc this peer last submitted and deep-compares against reveal entries (`is_own_drawing`). Nothing on the wire marks authorship. A drawer who never submitted (synthesized blank) matches nothing — their own blank renders interactive, but the host rejects self-reactions regardless (UI hint only, correctness is host-side).
- **Kudos roster sync:** each accepted kudos triggers `Session.broadcast_roster()` (new host-only method) so every peer's `kudos_granted/spent` mirror stays current; the fields were already in the Slice 2 roster payload.
- **Host-player confirm path:** the host's own kudos confirm skips RPC (`rpc_id` to self is invalid) — `SessionClient` calls the local handler directly.
- **Gate + grace:** `ReactionGate` snapshots the open set at `close()`; requests inside `REACTION_CLOSE_GRACE_MSEC` (250 ms) still land (their count syncs may arrive during RESOLUTION; the UI just doesn't show the tick).
- **CI (`tools/verify_round.sh`) now also verifies the social layer live:** judge toggles LAUGH on→off→on (every peer must observe the decrement sync) and spends a kudos (giver-side collection index/doc/thumb verified, wallet 1→0); drawers cross-react FIRE using own-drawing detection; all peers verify converged final counts/totals and the kudos-adjusted score sum (+2 +1 −1).

## Testing Summary

- **Unit/scene tests:** 55 new (reaction ledger 5, kudos ledger 6, session stats 7, reaction gate 5, GameSession social 19, collection store 7, UI social components 6) — full suite **233/233 PASSED**, 0 orphans.
- **Automated gates:** `verify_lobby.sh` PASS (no regressions); `verify_round.sh` PASS on all 3 peers with the extended social verification.
- **User confirmation:** PENDING — owner core-flow check at the slice boundary (QA process, decision log 2026-07-06); batchable items appended to `TDD/qa-backlog.md`.

## Lessons Learned

- **Never use an ENet peer id as a loop bound / allocation count.** Client peer ids are random 32-bit ints; a CI helper that built "peer-id many ops" allocated ~10⁹ dictionaries, froze two headless instances at ~40 GB each, and took the dev machine down (2026-07-06 RAM incident). Fixed to `joined_order` with a hard clamp; the guarded runner (output-to-file + RSS watchdog, scratchpad `safe_verify_round.sh` pattern) is worth keeping for gate runs.
- Reliable-channel ordering guarantees are load-bearing for CI observers: captures that happen in deferred calls can run *after* same-batch RPCs have been processed (the round-0 entry-id capture had to move from JUDGING to the REVEAL handler).
- The EventBus specific-before-`phase_changed` ordering contract (Slice 3) again proved its worth — the reveal screen builds before any reaction sync can arrive.

## Known Limitations

- Reaction/kudos state is per-round and host-memory only; a host quit loses `SessionStats` (accepted for v1, per TDD).
- The reaction-count badge and kudos totals render with programmer-art emoji buttons; grid density at 8 players unverified by a human (backlog).
- `rpc_do_kudos_confirmed` to a giver who disconnected mid-request is silently lost — their local collection copy is skipped (their kudos/score still stand). Slice 9's rejoin does not retro-deliver it (matches "no retry queue in v1").
- Gate `OpenSubset` (per-beat reveal) is implemented and tested at the gate level but nothing opens it until Slice 5.
