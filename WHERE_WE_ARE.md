# WHERE_WE_ARE - Animal Quickdraw

**Purpose:** Single source of truth for project status and session continuity. Any developer or AI can read this to understand the current state and resume work seamlessly.

**Last Updated:** 2026-07-07 (session 6, mid-session — Slice 16 built, awaiting owner checks)
**Total Sessions:** 6 (session 6 in progress)

---

## Current Status

**Active Slice:** **16 (text tool, drag-rework + Eraser) and 17 (ready-up)** — both implemented same session; 376 tests green; both gates PASS. First build of 16 was owner-confirmed, then owner-directed rework: drag-to-place text (Option B), Eraser tool, and the new ready-up system (mini-TDD 17). Awaiting owner re-check of the rework + ready-up blocking checks. Then Slice 9 (Chunk 12)
**Current Objective:** Owner checks → mark Slices 16+17 COMPLETE → Slice 9 per `TDD/09-connectivity-resilience.md`
**Blockers:** None
**Pending owner confirmations:** Slice 16 drag-flow + eraser re-check; Slice 17 blocking checks (Done/Unready, chat-header strip, early advances); owner-deferred to end-of-content QA: Slice 7 force-continue check, Slice 7 + 8 + 16 + 17 batchable lists

---

## Quick Links

| Document | Path | Notes |
|----------|------|-------|
| Skeleton TDD | `TDD/00-skeleton-build-guide.md` | Implemented — see implementation notes |
| Skeleton Implementation Notes | `TDD/00-skeleton-implementation-notes.md` | What was actually built + deviations |
| **Slice 16 TDD (text tool)** | `TDD/16-in-image-text-tool.md` | Owner-approved mini-TDD; built + drag-reworked session 6 |
| **Slice 16 Implementation Notes** | `TDD/16-in-image-text-tool-implementation-notes.md` | TEXT op, PixelFont, drag-to-place Text row, Eraser, caption pipeline deleted |
| **Slice 17 TDD (ready-up)** | `TDD/17-ready-up.md` | Done/Unready in DRAWING; all-ready early advance; chat-header strip in JUDGING |
| Next Slice TDD | `TDD/09-connectivity-resilience.md` | After Slice 16 owner checks (Chunk 12) |
| Slice 7 Implementation Notes | `TDD/07-player-created-pools-implementation-notes.md` | What was actually built + deviations (enum NONE, signal-routed rejections, branch draws) |
| Slice 8 Implementation Notes | `TDD/08-collection-browser-export-implementation-notes.md` | What was actually built + deviations (Slice 4 reality adaptations, atomic write_png) |
| Slice 4 Implementation Notes | `TDD/04-reactions-kudos-saving-implementation-notes.md` | What was actually built + deviations (incl. RAM-incident lesson) |
| Slice 5 Implementation Notes | `TDD/05-reveal-styles-replay-implementation-notes.md` | Stage-in-screen reveal, duration-based replay settings, caption pipeline |
| Slice 6 Implementation Notes | `TDD/06-game-modes-settings-implementation-notes.md` | Settings surface, snapshot object, presets, Esc menu + pause |
| Slice 2 Implementation Notes | `TDD/02-lobby-session-roster-implementation-notes.md` | What was actually built + deviations |
| Slice 3 Implementation Notes | `TDD/03-core-round-loop-implementation-notes.md` | What was actually built + deviations |
| **QA Backlog ("bug hunt")** | `TDD/qa-backlog.md` | All deferred fine-grain checks; append every slice |
| Consistency Guide | `TDD/consistency-guide.md` | Patterns and standards — read before coding |
| Recipe | `TDD/recipe.md` | Approved project contract |
| Overview + Chunk Plan | `TDD/overview-of-slices.md` | Slice deps + 18-chunk session plan |
| Latest Session Log | `TDD/logs/2026-07-07-session-5.md` | Deferred checks cleared; 2 fix batches (latched judging, chat rework, kudos rematch bug, pause timers); Slices 7+8 built + confirmed |
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
| 4 | Reactions, Kudos & Saving | 2026-07-06 | **COMPLETE (owner-confirmed 2026-07-07)** — kudos + reactions human-checked in session 5; rematch kudos-staleness bug found + fixed same session (decision log 2026-07-07); extended `verify_round.sh` PASS |
| 5 | Reveal Styles & Replay | 2026-07-06 | **COMPLETE (owner-confirmed 2026-07-07)** — victory-lap replay + emoji legibility confirmed; grid social-row alignment refixed in session 5; captions retired (off everywhere; in-image text tool scheduled after Slices 7+8) |
| 6 | Game Modes & Settings + Esc menu/pause | 2026-07-06 | **COMPLETE (owner-confirmed 2026-07-07)** — preset lock, client mirror, Esc/pause all human-checked; pause now also freezes visible countdowns (session-5 fix) |
| 7 | Player-Created Prompt Pools | 2026-07-07 | **COMPLETE (core-confirmed)** — owner confirmed the full flow on 3 instances (submission screen → submits → player words used in game); force-continue human check + detail items → qa-backlog; 329 tests green (+33); both gates PASS |
| 8 | Collection Browser & Export | 2026-07-07 | **COMPLETE (export-confirmed)** — owner verified the exported PNG externally ("works great") + Share reveal; batchable items → qa-backlog; 350 tests green (+21) |

### In Progress

| Slice | Name | Started | Status | % Complete |
|-------|------|---------|--------|------------|
| 16 (mini) | In-Image Text Tool + Eraser | 2026-07-07 | First build owner-confirmed; drag-to-place rework + Eraser built same session; **awaiting owner re-check** | ~95% |
| 17 (mini) | Ready-Up | 2026-07-07 | Implementation complete; 376 tests green; both gates PASS; **awaiting owner blocking checks** | ~95% |

### Upcoming (see chunk plan in overview-of-slices.md)

| Slice | Name | Dependencies | Priority |
|-------|------|--------------|----------|
| 9 | Connectivity & Resilience | 2, 3 | Chunk 12, next after Slice 16 sign-off |

---

## Session History

| Date | Session | Summary | Status |
|------|---------|---------|--------|
| 2026-07-06/07 | #5 | Session-4 deferred checks cleared + two owner-directed fix batches (latched click-to-pick judging, chat toggle/side-placement/adaptive sizing, fixed-shape social rows, kudos rematch-staleness bug fix, pause freezes timers, captions retired). **Slices 7 + 8 implemented, documented, owner-confirmed** (pool submission flow; export verified externally). 287 → 350 tests green; gates PASS. Text tool scheduled as session 6's first item | Completed |
| 2026-07-06 | #4 | Slices 4+5+6 implemented and documented: reactions/kudos/collection saves, reveal styles + replays + captions + victory lap, presets/Custom settings + frozen snapshot, Esc menu with host pause. 287 tests green; extended gates PASS. Owner playtested the reveal live (4 fixes applied, incl. duration-based replay settings); all other human checks deferred to the qa-backlog. Incident: CI driver used an ENet peer id as a loop bound → ~80 GB RAM crash; root-caused, fixed, guarded wrapper adopted for gate runs | Completed |
| 2026-07-06 | #3 | Slices 2+3 implemented, documented, and core-confirmed → **playable MVP on LAN**. 178 tests green; automated 3-instance gates (`verify_lobby.sh`, `verify_round.sh`) PASS. New QA process: core-flow sign-offs + `TDD/qa-backlog.md` for deferred detail QA. Design gap logged: no in-game pause/leave menu | Completed |
| 2026-07-06 | #2 | Slices 0+1 implemented and playtested: skeleton (5 autoloads, tests, exports, connect gate owner-confirmed → COMPLETE), full canvas/stroke engine (goldens, replay, sandbox), palette picker redesigned from owner playtest feedback. 102 tests green | Completed |
| 2026-07-04 | #1 | Project initialization: learned 3 Pillars, tech stack decided (Godot 4.6 + typed GDScript + GodotSteam + JSON + ENet dev mode), Recipe approved (16 slices / 18 chunks / hard 180k budget), full TDD folder generated | Completed |

---

## Next Steps

**Immediate (Session 6 — in progress):**
1. ~~Text tool (Slice 16)~~ DONE + first-build checks confirmed; ~~owner-directed rework~~ DONE (drag-to-place Option B, Eraser, ready-up Slice 17; 376 tests green; both gates PASS)
2. **Owner checks:** (a) Slice 16 rework — type in the Text row, drag the chip onto the canvas (all 3 sizes, colors); Eraser feel; (b) Slice 17 — Done!/Unready in drawing (panel checkmarks update everywhere, phase advances when all drawers ready), JUDGING chat-header strip (judge's Ready locked until they pick; all-ready crowns early). Then slice-completion workflow for 16+17
3. Then Slice 9: Connectivity & Resilience (Chunk 12) — read its FULL TDD; `CustomPoolCollector.mark_departed()` extension point is ready for it; **Slice 9 must fold rejoiners into the ready-up participant set (TDD 17 §9)**
4. Reality notes: replay settings are TARGET DURATIONS; in-game reads use `Session.game_settings` (frozen snapshot); `judging_window_sec` setting (default 25 s); judging ends at the deadline OR when all connected participants ready up (Slice 17 — judge's ready requires a latched pick; submitting never advances DRAWING, ready does); chat placement/prominence are per-phase-screen properties (`chat_placement()`/`chat_prominence()`); **captions are GONE — text lives inside the DrawingDoc as TEXT ops (v1 format, `PixelFont`, host-censored at submission; canvas pre-censors identically — own-drawing detection relies on that equality)**; POOL_SETUP has no phase clock (pause is a no-op there); `CollectionStore` read surface + `Save` PNG/`globalize` helpers exist (Slice 8) for future image work; **CI drivers must pin every setting their flow depends on** (round driver pins `pool_source` — a restored host profile once parked the gate in POOL_SETUP)

**Workflow gotchas:** run `godot --headless --path . --import` after creating new class_name scripts, before tests; test command needs `--ignoreHeadlessMode`; `Session` autoload = `game/session/session_manager.gd` (NOT game_session.gd — that's the host-only sim); settings field is `round_count`, not `rounds`; `SessionClient.rpc_sync_phase` emits specific EventBus signals BEFORE `phase_changed` (ordering contract); automated gates: `tools/verify_lobby.sh` (~15 s) and `tools/verify_round.sh` (~90 s — waits out a real judging window + reveal beats). **Run gates through a guarded wrapper: redirect all output to a file, poll godot RSS and kill above ~3 GB, hard wall-clock cap (the session-4 scratchpad `safe_verify_round.sh` did exactly this — recreate it; scratchpads don't persist). NEVER use ENet peer ids as loop bounds/sizes (random 32-bit ints; caused the 2026-07-06 ~80 GB RAM crash).** Manual playtests: `tools/dev_run.sh 3` launches 3 windowed instances.

---

## Active Decisions/Discussions

| Topic | Status | Notes |
|-------|--------|-------|
| **In-image text tool (captions replacement)** | **Built (2026-07-07, session 6)** | Slice 16 mini-TDD approved + implemented same session (censor-not-reject and permanent-text confirmed by owner pre-build). Awaiting the two blocking owner checks; batchables in qa-backlog Slice 16 section |
| **In-game pause/leave menu** | **Decided (2026-07-06)** | Owner: menu shell (Esc → Resume / Leave to menu) ships in **Slice 6**; Slice 9 upgrades leave semantics (graceful leave, rejoin, below-minimum pause) behind the same button. See decision log |
| Steam App ID registration | Deferred | Register before Chunk 15 (Slice 12); dev uses App ID 480 |
| Art & sound | Deferred | Placeholder programmer art; MVP reached (Chunk 6) — revisit timing owner's call |

---

## Notes

- Hard ~180k-token context budget per session; end at clean checkpoints via `workflows/session-end.md`. If a session runs cool, pull the next chunk forward and record it here.
- Slice TDDs 01–15 were drafted by parallel subagents against the consistency guide + skeleton guide contracts, then reviewed; if an implementation session finds a TDD contradicting the consistency guide, the **consistency guide wins** — log a decision and fix the TDD.
- The blocking user-confirmation gate at the end of Chunk 1 is two-instance ENet connect (Slice 2 depends on it).
