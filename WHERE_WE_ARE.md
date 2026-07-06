# WHERE_WE_ARE - Animal Quickdraw

**Purpose:** Single source of truth for project status and session continuity. Any developer or AI can read this to understand the current state and resume work seamlessly.

**Last Updated:** 2026-07-06 (end of session 2)
**Total Sessions:** 2

---

## Current Status

**Active Slice:** Slice 2: Lobby & Session Roster (not started — next session is Chunk 4)
**Current Objective:** Implement Slice 2 per `TDD/02-lobby-session-roster.md` (read the FULL TDD at session start)
**Blockers:** None
**Pending owner confirmations:**
- Slice 1 batchable polish list only (letterboxing at odd window sizes, portrait layout, rotate-confirm wording, undo disabled-state timing) — formal Slice 1 sign-off at next session start; nothing in Slice 2 depends on these

---

## Quick Links

| Document | Path | Notes |
|----------|------|-------|
| Skeleton TDD | `TDD/00-skeleton-build-guide.md` | Implemented — see implementation notes |
| Skeleton Implementation Notes | `TDD/00-skeleton-implementation-notes.md` | What was actually built + deviations |
| Current Slice TDD | `TDD/02-lobby-session-roster.md` | Active implementation guide |
| Consistency Guide | `TDD/consistency-guide.md` | Patterns and standards — read before coding |
| Recipe | `TDD/recipe.md` | Approved project contract |
| Overview + Chunk Plan | `TDD/overview-of-slices.md` | Slice deps + 18-chunk session plan |
| Latest Session Log | `TDD/logs/2026-07-06-session-2.md` | Slices 0+1 built and playtested |
| Decision Log | `TDD/decision-log.md` | Tech stack + pacing decisions |
| Design Brief | `game-design-brief.md` | Authoritative game spec (§1–§15) |

---

## Project Progress

### Completed Slices

| Slice | Name | Completed | Notes |
|-------|------|-----------|-------|
| 0 | Skeleton | 2026-07-06 | **COMPLETE** — owner confirmed the two-instance connect gate (all 4 steps); 3-platform exports build; automated connect check also PASS |
| 1 | Drawing Canvas & Stroke Engine | 2026-07-06 | Implementation complete (both parts) + owner playtested ("works really good"); palette redesigned from feedback and re-confirmed. 102 total tests green incl. 6 baked goldens. **Formal sign-off pending batchable polish list only** |

### In Progress

| Slice | Name | Started | Status | % Complete |
|-------|------|---------|--------|------------|
| — | — | — | — | — |

### Upcoming (see chunk plan in overview-of-slices.md)

| Slice | Name | Dependencies | Priority |
|-------|------|--------------|----------|
| 2 | Lobby & Session Roster | 0 | **Next (Chunk 4)** |
| 3 | Core Round Loop → playable MVP | 1, 2 | Chunks 5–6 |

---

## Session History

| Date | Session | Summary | Status |
|------|---------|---------|--------|
| 2026-07-06 | #2 | Slices 0+1 implemented and playtested: skeleton (5 autoloads, tests, exports, connect gate owner-confirmed → COMPLETE), full canvas/stroke engine (goldens, replay, sandbox), palette picker redesigned from owner playtest feedback. 102 tests green | Completed |
| 2026-07-04 | #1 | Project initialization: learned 3 Pillars, tech stack decided (Godot 4.6 + typed GDScript + GodotSteam + JSON + ENet dev mode), Recipe approved (16 slices / 18 chunks / hard 180k budget), full TDD folder generated | Completed |

---

## Next Steps

**Immediate (Next Session — Chunk 4: Slice 2 Lobby & Roster):**
1. Session Start workflow: read this file fully, then the FULL `TDD/02-lobby-session-roster.md` (all 12 sections), then consistency guide Quick Reference
2. Confirm Slice 1 batchable polish list with owner (5 min) → mark Slice 1 COMPLETE
3. Implement Slice 2: Roster + PlayerState, GameSettings, `Session` autoload (registration/chat/settings RPCs with 5-step validation), lobby screen, ChatPanel with prominence, PlayerList, join dialog, start gate
4. Blocking gates at end: 3-instance roster sync; join-by-code failure recovery; start-gate enable/disable

**Workflow gotchas (established session 2):** run `godot --headless --path . --import` after creating new class_name scripts, before tests; test command needs `--ignoreHeadlessMode`; `DRAW_TIME_DEFAULT_SEC = 30` per decision log (Slice 2 TDD's 45 is superseded).

**After Slice 2:** Slice 3 core round loop (Chunks 5–6) → playable MVP.

---

## Active Decisions/Discussions

| Topic | Status | Notes |
|-------|--------|-------|
| Steam App ID registration | Deferred | Register before Chunk 15 (Slice 12); dev uses App ID 480 |
| Art & sound | Deferred | Placeholder programmer art; revisit after MVP (Chunk 6) |

---

## Notes

- Hard ~180k-token context budget per session; end at clean checkpoints via `workflows/session-end.md`. If a session runs cool, pull the next chunk forward and record it here.
- Slice TDDs 01–15 were drafted by parallel subagents against the consistency guide + skeleton guide contracts, then reviewed; if an implementation session finds a TDD contradicting the consistency guide, the **consistency guide wins** — log a decision and fix the TDD.
- The blocking user-confirmation gate at the end of Chunk 1 is two-instance ENet connect (Slice 2 depends on it).
