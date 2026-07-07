# Slice 17 (mini): Ready-Up
## Players signal "done" in DRAWING and JUDGING; when everyone's in, the game moves on

**Version:** 1.0
**Last Updated:** 2026-07-07
**Dependencies:** Slice 3 (round state machine — transition changes), Slice 2/6 (chat panel header), Slice 16 (Done button shares the draw screen bottom bar)
**Provides:** `set_ready` host entry point + RPC pair; ready-state broadcast; `ReadyStatusStrip` shared component; early-advance semantics for DRAWING and JUDGING

> Owner-inserted mini-slice (2026-07-07, session 6 discussion): lets groups set long draw timers without waiting them out, and ends the judging/reaction window by consensus. Approved design: pressing ready locks you in (with Unready as the escape hatch); judge's ready requires a latched pick.

---

## 1. Overview

**In Scope:** ready toggle RPC + host validation; all-ready early advance (DRAWING → collect, JUDGING → crown latched pick); Done!/Unready button replacing Submit (prominent, bottom bar); ready roster panel left of the canvas (initials-circle chips — Slice 11 swaps in real avatars — with ☐/✅); JUDGING ready strip inline in the chat header ("Chat | Ready button | player chips"); ready set cleared at every phase change.

**Out of Scope:** ready-up in REVEAL beats / RESOLUTION / POOL_SETUP (force-continue covers it); departed-player rejoin interactions (Slice 9 — disconnected players simply never block all-ready); avatar art (Slice 11).

## 2–4. Data / Events / Storage

No models, no storage. Wire additions: `rpc_request_set_ready(ready: bool)` (client→host, 5-step validated → `GameSession.set_ready`) and `rpc_sync_ready_state(ready_ids: PackedStringArray)` (host→all, cached on `SessionClient.ready_ids()`, emitted as `EventBus.ready_state_changed`). Local-only `EventBus.judge_pick_latched` unlocks the judge's Ready button.

## 5. State Machine Changes (Slice 3 TDD updated in place)

| Phase | New early-end condition | Notes |
|-------|------------------------|-------|
| DRAWING | ALL connected drawers ready | Replaces all-submitted advance; ready requires a submission (Done submits first); ready drawer's resubmits dropped until un-ready |
| JUDGING | ALL connected participants (drawers + judge) ready | Judge's ready requires a latched pick → an early end always crowns; empty-latch −1 only via deadline lapse. Judge's re-picks dropped while ready |

Ready set clears on every `_enter_phase` (incl. pause/resume — players re-ready after a resume). Deadlines remain the guarantee; a player who never readies can never stall beyond them. Disconnected players are excluded from the participant set (never block).

## 6–8. Logic / UI / State

- `GameSession.set_ready(player_id, ready) -> bool` (validated, emits `ready_state_changed`); `ready_snapshot()`.
- `ui/shared/ready_status_strip.gd` (`ReadyStatusStrip`): per-player initials-circle + ☐/✅, vertical-with-names (draw panel) or horizontal-compact-with-button (chat header). Data pushed in; no Session coupling.
- Draw screen: `ReadyPanel` left of canvas; **Done!** button (200×52, font 22) = submit + ready + lock tools; press again = **Unready** (unlock). Host echo corrects optimistic state.
- Chat header (JUDGING only, driven by RoundRoot): "💬 Chat  [Ready]  chip☐ chip☐ chip☐ … [Hide]". ChatPanel exposes `show_ready_strip/update_ready_ids/set_ready_local/set_ready_button_enabled` + `ready_toggled` signal; RoundRoot forwards to `SessionClient`.

## 9. Integration Points

Slice 9 must fold rejoin into the participant set (a rejoiner mid-phase arrives un-ready). Slice 10 wrap-up screens unaffected. CI: round driver readies after submit/social/pick; round-1 no-pick lapse still deadline-driven.

## 10. Edge Cases

Hostile ready without submission → dropped. Group pressure on the judge → impossible (pick-gated). Leaver while rest are ready → connected-only set; next ready toggle or deadline advances (a leave itself doesn't re-evaluate — deadline covers the gap; Slice 9 revisits). Pause/resume → set cleared both sides, screens re-sync from the empty broadcast/cache.

## 11. Testing

`tests/game/session/test_game_session_ready.gd` (8 tests: eligibility, lock-in, judge gating, early advances, reset, leaver tolerance, broadcast). Existing suites updated: submit-auto-advance flows now ready-driven. Gates: `verify_round.sh` exercises both early ends + the round-1 deadline lapse. Owner checks: §12.

## 12. Implementation Checklist

- [x] GameSession set_ready/participants/all-ready + submit/pick locks + phase reset
- [x] SessionClient RPC pair + cache + judge_pick_latched; EventBus signals
- [x] ReadyStatusStrip; draw screen Done!/Unready + panel; chat header strip via RoundRoot
- [x] Tests (376 green) + CI driver readies; both gates PASS
- [ ] Owner blocking checks: Done/Unready feel in DRAWING (panel updates on all peers); JUDGING ready strip in chat header (judge locked until pick); all-ready early advance in both phases
- [ ] Docs: decision log, WHERE_WE_ARE, implementation notes on completion

---

**End of Slice 17 (mini): Ready-Up**
