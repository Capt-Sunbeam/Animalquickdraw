# WHERE_WE_ARE - Animal Quickdraw

**Purpose:** Single source of truth for project status and session continuity. Any developer or AI can read this to understand the current state and resume work seamlessly.

**Last Updated:** 2026-07-06 (session 2, in progress — continuous multi-chunk session per decision log)
**Total Sessions:** 2 (session 2 in progress)

---

## Current Status

**Active Slice:** Slice 2: Lobby & Session Roster
**Current Objective:** Implement Slice 2 per `TDD/02-lobby-session-roster.md`
**Blockers:** None
**Pending owner confirmations (batched for session end):**
- Slice 0: windowed two-instance playtest via `tools/dev_run.sh`
- Slice 1: drawing feel; fill + replay correctness in the Canvas Sandbox (debug menu); batchable UI list in its implementation notes

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
| Latest Session Log | `TDD/logs/2026-07-04-session-1.md` | Initialization session |
| Decision Log | `TDD/decision-log.md` | Tech stack + pacing decisions |
| Design Brief | `game-design-brief.md` | Authoritative game spec (§1–§15) |

---

## Project Progress

### Completed Slices

| Slice | Name | Completed | Notes |
|-------|------|-----------|-------|
| 0 | Skeleton | 2026-07-06 | Implementation complete, 32/32 tests green, 3-platform exports build, automated connect gate PASS. **Pending owner playtest** (batched) |
| 1 | Drawing Canvas & Stroke Engine | 2026-07-06 | Implementation complete (both parts), 89 total tests green incl. 6 baked goldens. **Pending owner playtest** (batched) |

### In Progress

| Slice | Name | Started | Status | % Complete |
|-------|------|---------|--------|------------|
| 2 | Lobby & Session Roster | 2026-07-06 | Starting | 0% |

### Upcoming (see chunk plan in overview-of-slices.md)

| Slice | Name | Dependencies | Priority |
|-------|------|--------------|----------|
| 3 | Core Round Loop → playable MVP | 1, 2 | This session |

---

## Session History

| Date | Session | Summary | Status |
|------|---------|---------|--------|
| 2026-07-04 | #1 | Project initialization: learned 3 Pillars, tech stack decided (Godot 4.6 + typed GDScript + GodotSteam + JSON + ENet dev mode), Recipe approved (16 slices / 18 chunks / hard 180k budget), full TDD folder generated | Completed |

---

## Next Steps

**Immediate (this session, in order):**
1. Slice 1 Part 1: stroke model, palette, DocRasterizer + goldens, DrawingCanvas, toolbar/palette UI, sandbox screen, serialization tests
2. Slice 1 Part 2: bucket fill, rotate, ReplayPlayer, save-toggle stub, determinism goldens
3. Slice 2: lobby & roster (Session autoload, registration/chat/settings RPCs, lobby screen)
4. Slice 3: core round loop (headless state machine + content, then phase screens) → playable MVP
5. Session end: batched playtest checklist, session log, owner check-in

**After this session:** owner playtests the batched checklist; then Slice 4 (reactions/kudos) per chunk plan.

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
