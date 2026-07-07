# WHERE_WE_ARE - Animal Quickdraw

**Purpose:** Single source of truth for project status and session continuity. Any developer or AI can read this to understand the current state and resume work seamlessly.

**Last Updated:** 2026-07-06 (end of session 3)
**Total Sessions:** 3

---

## Current Status

**Active Slice:** Slice 4: Reactions, Kudos & Saving (not started — next session is Chunk 7)
**Current Objective:** Implement Slice 4 per `TDD/04-reactions-kudos-saving.md` (read the FULL TDD at session start)
**Blockers:** None
**Pending owner confirmations:** None blocking — all deferred fine-grain QA lives in **`TDD/qa-backlog.md`** (owner QA process, decision log 2026-07-06: core flows between sessions, full detail sweep after content-complete)

---

## Quick Links

| Document | Path | Notes |
|----------|------|-------|
| Skeleton TDD | `TDD/00-skeleton-build-guide.md` | Implemented — see implementation notes |
| Skeleton Implementation Notes | `TDD/00-skeleton-implementation-notes.md` | What was actually built + deviations |
| Current Slice TDD | `TDD/04-reactions-kudos-saving.md` | Active implementation guide (Chunk 7) |
| Slice 2 Implementation Notes | `TDD/02-lobby-session-roster-implementation-notes.md` | What was actually built + deviations |
| Slice 3 Implementation Notes | `TDD/03-core-round-loop-implementation-notes.md` | What was actually built + deviations |
| **QA Backlog ("bug hunt")** | `TDD/qa-backlog.md` | All deferred fine-grain checks; append every slice |
| Consistency Guide | `TDD/consistency-guide.md` | Patterns and standards — read before coding |
| Recipe | `TDD/recipe.md` | Approved project contract |
| Overview + Chunk Plan | `TDD/overview-of-slices.md` | Slice deps + 18-chunk session plan |
| Latest Session Log | `TDD/logs/2026-07-06-session-3.md` | Slices 2+3 built, gated, core-confirmed → playable MVP |
| Decision Log | `TDD/decision-log.md` | Tech stack + pacing decisions |
| Design Brief | `game-design-brief.md` | Authoritative game spec (§1–§15) |

---

## Project Progress

### Completed Slices

| Slice | Name | Completed | Notes |
|-------|------|-----------|-------|
| 0 | Skeleton | 2026-07-06 | **COMPLETE** — owner confirmed the two-instance connect gate (all 4 steps); 3-platform exports build; automated connect check also PASS |
| 1 | Drawing Canvas & Stroke Engine | 2026-07-06 | **COMPLETE (core-confirmed)** — owner playtested ("works really good"), palette redesigned + re-confirmed; polish items → qa-backlog |
| 2 | Lobby & Session Roster | 2026-07-06 | **COMPLETE (core-confirmed)** — owner confirmed join-by-code + wrong-code recovery + lobby-to-game flow; `verify_lobby.sh` PASS; detail items → qa-backlog |
| 3 | Core Round Loop → **playable MVP** | 2026-07-06 | **COMPLETE (core-confirmed)** — owner played a full game (judging + scoring + standings clean); 178 tests green; `verify_round.sh` PASS incl. no-pick −1; detail items → qa-backlog |

### In Progress

| Slice | Name | Started | Status | % Complete |
|-------|------|---------|--------|------------|
| — | — | — | — | — |

### Upcoming (see chunk plan in overview-of-slices.md)

| Slice | Name | Dependencies | Priority |
|-------|------|--------------|----------|
| 4 | Reactions, Kudos & Saving | 3 | **Next (Chunk 7)** |
| 5 | Reveal Styles & Replay | 3 | Chunk 8 |

---

## Session History

| Date | Session | Summary | Status |
|------|---------|---------|--------|
| 2026-07-06 | #3 | Slices 2+3 implemented, documented, and core-confirmed → **playable MVP on LAN**. 178 tests green; automated 3-instance gates (`verify_lobby.sh`, `verify_round.sh`) PASS. New QA process: core-flow sign-offs + `TDD/qa-backlog.md` for deferred detail QA. Design gap logged: no in-game pause/leave menu | Completed |
| 2026-07-06 | #2 | Slices 0+1 implemented and playtested: skeleton (5 autoloads, tests, exports, connect gate owner-confirmed → COMPLETE), full canvas/stroke engine (goldens, replay, sandbox), palette picker redesigned from owner playtest feedback. 102 tests green | Completed |
| 2026-07-04 | #1 | Project initialization: learned 3 Pillars, tech stack decided (Godot 4.6 + typed GDScript + GodotSteam + JSON + ENet dev mode), Recipe approved (16 slices / 18 chunks / hard 180k budget), full TDD folder generated | Completed |

---

## Next Steps

**Immediate (Next Session — Chunk 7: Slice 4 Reactions, Kudos & Saving):**
1. Session Start workflow: read this file fully, then the FULL `TDD/04-reactions-kudos-saving.md` (all 12 sections), then consistency guide Quick Reference
2. Implement Slice 4: it plugs into the REVEAL/JUDGING window via broadcast `drawing_id`s, `Scoring.add_points()`, the reserved `reaction_stats`/`kudos_stats` results keys, and the per-cell extension point in `reveal_judging_screen`; kudos-as-save starts the `user://collection/` write path
3. At the slice boundary: owner tests core flows only; append batchable/detail items to `TDD/qa-backlog.md` (QA process, decision log 2026-07-06)
4. Decide where the **in-game pause/leave menu** lands (open design item — Slice 6 or 9) before those chunks start

**Workflow gotchas:** run `godot --headless --path . --import` after creating new class_name scripts, before tests; test command needs `--ignoreHeadlessMode`; `Session` autoload = `game/session/session_manager.gd` (NOT game_session.gd — that's the host-only sim); settings field is `round_count`, not `rounds`; `SessionClient.rpc_sync_phase` emits specific EventBus signals BEFORE `phase_changed` (ordering contract); automated gates: `tools/verify_lobby.sh` (~15 s) and `tools/verify_round.sh` (~70 s, waits out a real judging window).

**After Slice 4:** Slice 5 reveal styles & replay (Chunk 8).

---

## Active Decisions/Discussions

| Topic | Status | Notes |
|-------|--------|-------|
| **In-game pause/leave menu** | **Open** | Owner-flagged 2026-07-06: once a game starts there is no settings access or exit-to-menu short of closing the window. Not covered by ANY planned slice — slot into Slice 6 (settings) or Slice 9 (resilience/voluntary leave). Decide before those chunks |
| Steam App ID registration | Deferred | Register before Chunk 15 (Slice 12); dev uses App ID 480 |
| Art & sound | Deferred | Placeholder programmer art; MVP reached (Chunk 6) — revisit timing owner's call |

---

## Notes

- Hard ~180k-token context budget per session; end at clean checkpoints via `workflows/session-end.md`. If a session runs cool, pull the next chunk forward and record it here.
- Slice TDDs 01–15 were drafted by parallel subagents against the consistency guide + skeleton guide contracts, then reviewed; if an implementation session finds a TDD contradicting the consistency guide, the **consistency guide wins** — log a decision and fix the TDD.
- The blocking user-confirmation gate at the end of Chunk 1 is two-instance ENet connect (Slice 2 depends on it).
