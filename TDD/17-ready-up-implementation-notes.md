# Implementation Notes: Slice 17 (mini) — Ready-Up

**Completed:** 2026-07-07 (session 6; owner core-flow confirmed same day — "Ready up is working great!")
**TDD Document:** `TDD/17-ready-up.md` (designed and approved in-session)

## Implementation Summary

Players now signal "done" instead of waiting out timers. `GameSession.set_ready(player_id, ready)` is the shared validated entry point (RPC handler + host UI): DRAWING accepts connected drawers with a submission in; JUDGING accepts all connected participants, the judge only after latching a pick. Ready locks you in — a ready drawer's resubmissions and a ready judge's re-picks are dropped until un-ready. All-ready advances immediately (DRAWING → collect/reveal; JUDGING → crown the latched pick); the phase deadline remains the guarantee, and the ready set clears at every phase entry. **Submitting alone no longer ends DRAWING** — a deliberate Slice 3 semantics change (TDD 03 updated in place) that makes long draw timers safe.

Sync: `rpc_request_set_ready` / `rpc_sync_ready_state` on `SessionClient` (cache + `ready_ids()` getter, cleared on phase sync), surfaced as `EventBus.ready_state_changed`; local-only `EventBus.judge_pick_latched` unlocks the judge's Ready button. UI: `ReadyStatusStrip` (ui/shared — initials-circle chips as the Slice 11 avatar stand-in, ☐/✅ states, optional Ready button) used vertically with names in the draw screen's new left panel and horizontally in the chat header during JUDGING ("💬 Chat | Ready | chips", owner spec). The draw screen's Submit became a prominent **Done!**/**Unready** toggle (submit + ready + lock; escape hatch back).

## Deviations from Original Design

None — the in-session design was built as agreed. One scope note: the judge-wait screen shows no drawer-progress panel (not requested; logged as a design nicety in the qa-backlog).

## Files Created/Modified

**Created:** `ui/shared/ready_status_strip.gd`, `TDD/17-ready-up.md`, `tests/game/session/test_game_session_ready.gd`
**Modified:** `game/session/game_session.gd` (set_ready/participants/all-ready, submit/pick locks, phase reset, signal), `session_client.gd` (RPC pair, cache, judge_pick_latched emit), `core/events/event_bus.gd` (2 signals), `ui/round/draw_screen.gd/.tscn` (Done!/Unready, ready panel, Body row + ChatSlot), `ui/shared/chat_panel.gd/.tscn` (header strip API + spacer), `ui/round/round_root.gd` (strip driving, ready forwarding, chat side-slot targeting + rescue-before-free), `TDD/03-core-round-loop.md` (transition table), `tools/ci/round_ci_driver.gd` (readies after submit/social/pick), plus submit-flow updates across `test_game_session*.gd`

## Key Implementation Details

- **Judge gating is the safety property:** an early JUDGING end can only be triggered with a latched pick, so consensus can never produce an accidental no-pick −1; the −1 path exists only via deadline lapse (round 1 of `verify_round.sh` still pins it).
- Disconnected players are excluded from the participant set (roster `is_connected`), so leavers never block; a leave alone doesn't re-evaluate all-ready — the next toggle or the deadline advances (Slice 9 revisits with proper departure handling and must fold rejoiners in un-ready).
- Pause/resume clears the ready set on both sides (host `_enter_phase` clear + client cache reset on phase sync); the draw screen follows the host echo rather than trusting its optimistic state.
- Reliable-channel ordering does the heavy lifting in CI: each peer's reactions/kudos precede its own ready, so the early end can never race a peer's social actions.

## Testing Summary

- 8-test dedicated suite (eligibility matrix, lock-in, judge gating, both early advances, reset, leaver tolerance, broadcast counts); suite total **380/380 green, 0 orphans**.
- Gates through the guarded wrapper: `verify_lobby.sh` + `verify_round.sh` **PASS** — the round gate now exercises ready-driven early ends in both phases plus the deadline-lapse no-pick round.
- Owner confirmation 2026-07-07: core flow ("working great"); batchables → qa-backlog Slice 17 section.

## Lessons Learned

- Replacing an implicit early-end (all-submitted) with an explicit one (all-ready) touched a dozen test flows — grepping every `submit_drawing` call site up front turned a scary semantics change into a mechanical patch.
- A consensus mechanism needs one asymmetric guard (the judge's pick gate) to stay abuse-proof; everything else is symmetric bookkeeping.

## Known Limitations

- Ready state does not survive pause/resume (re-press Done) — acceptable v1, noted in backlog.
- Avatars are initials-circles until Slice 11.
- A leaver mid-"everyone else ready" advances on the next event, not instantly (Slice 9 territory).
