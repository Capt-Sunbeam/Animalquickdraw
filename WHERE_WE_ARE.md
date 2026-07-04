# WHERE_WE_ARE - Animal Quickdraw

**Purpose:** Single source of truth for project status and session continuity. Any developer or AI can read this to understand the current state and resume work seamlessly.

**Last Updated:** 2026-07-04 (initialization session)
**Total Sessions:** 1

---

## Current Status

**Active Slice:** Slice 0: Skeleton (not started — next session is Chunk 1)
**Current Objective:** Implement the Skeleton per `TDD/00-skeleton-build-guide.md`
**Blockers:** None

---

## Quick Links

| Document | Path | Notes |
|----------|------|-------|
| Skeleton TDD | `TDD/00-skeleton-build-guide.md` | Foundation architecture — Chunk 1 |
| Current Slice TDD | `TDD/00-skeleton-build-guide.md` | Active implementation guide |
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
| — | (none yet — documentation phase complete) | | |

### In Progress

| Slice | Name | Started | Status | % Complete |
|-------|------|---------|--------|------------|
| — | — | — | — | — |

### Upcoming (see chunk plan in overview-of-slices.md)

| Slice | Name | Dependencies | Priority |
|-------|------|--------------|----------|
| 0 | Skeleton | None | **Next (Chunk 1)** |
| 1 | Drawing Canvas & Stroke Engine | 0 | Chunks 2–3 |
| 2 | Lobby & Session Roster | 0 | Chunk 4 |
| 3 | Core Round Loop → playable MVP | 1, 2 | Chunks 5–6 |

---

## Session History

| Date | Session | Summary | Status |
|------|---------|---------|--------|
| 2026-07-04 | #1 | Project initialization: learned 3 Pillars, tech stack decided (Godot 4.6 + typed GDScript + GodotSteam + JSON + ENet dev mode), Recipe approved (16 slices / 18 chunks / hard 180k budget), full TDD folder generated | Completed |

---

## Next Steps

**Immediate (Next Session — Chunk 1: Skeleton):**
1. Session Start workflow: read this file fully, then `TDD/00-skeleton-build-guide.md` fully, then consistency guide Quick Reference
2. Create the Godot 4.6 project + folder structure + GdUnit4
3. Implement core autoloads (EventBus, Platform+EnetBackend, Net, Save, Nav), constants, TextFilter, theme, dev launch script
4. Tests + owner confirmation: two local instances connect

**After Current Objective:**
- Chunk 2: Canvas part 1 (stroke model, brush, palette, undo/clear, serialization)
- Chunk 3: Canvas part 2 (fill, rotate, replay) → Slice 1 complete

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
