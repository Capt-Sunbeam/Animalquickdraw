# WHERE_WE_ARE - Animal Quickdraw

**Purpose:** Single source of truth for project status and session continuity. Any developer or AI can read this to understand the current state and resume work seamlessly.

**Last Updated:** 2026-07-07 (mid-session 5 — fixes confirmed, Slice 7 cleared to start)
**Total Sessions:** 5 (session 5 in progress)

---

## Current Status

**Active Slice:** Slice 7: Player-Created Prompt Pools (cleared to start — awaiting owner go-ahead, Chunk 10)
**Current Objective:** Implement Slice 7 per `TDD/07-player-created-pools.md` (full TDD already read this session). All session-4 deferred checks and both session-5 fix batches are owner-confirmed (2026-07-07); no blocking checks remain
**Blockers:** None
**Pending owner confirmations:** None blocking. One deferral: caption entry box still appears for hosts whose saved profile predates the captions-off default (root cause + workaround in qa-backlog) — resolves with the in-image text tool

---

## Quick Links

| Document | Path | Notes |
|----------|------|-------|
| Skeleton TDD | `TDD/00-skeleton-build-guide.md` | Implemented — see implementation notes |
| Skeleton Implementation Notes | `TDD/00-skeleton-implementation-notes.md` | What was actually built + deviations |
| Current Slice TDD | `TDD/07-player-created-pools.md` | Next implementation guide (Chunk 10) |
| Slice 4 Implementation Notes | `TDD/04-reactions-kudos-saving-implementation-notes.md` | What was actually built + deviations (incl. RAM-incident lesson) |
| Slice 5 Implementation Notes | `TDD/05-reveal-styles-replay-implementation-notes.md` | Stage-in-screen reveal, duration-based replay settings, caption pipeline |
| Slice 6 Implementation Notes | `TDD/06-game-modes-settings-implementation-notes.md` | Settings surface, snapshot object, presets, Esc menu + pause |
| Slice 2 Implementation Notes | `TDD/02-lobby-session-roster-implementation-notes.md` | What was actually built + deviations |
| Slice 3 Implementation Notes | `TDD/03-core-round-loop-implementation-notes.md` | What was actually built + deviations |
| **QA Backlog ("bug hunt")** | `TDD/qa-backlog.md` | All deferred fine-grain checks; append every slice |
| Consistency Guide | `TDD/consistency-guide.md` | Patterns and standards — read before coding |
| Recipe | `TDD/recipe.md` | Approved project contract |
| Overview + Chunk Plan | `TDD/overview-of-slices.md` | Slice deps + 18-chunk session plan |
| Latest Session Log | `TDD/logs/2026-07-06-session-4.md` | Slices 4+5+6 built + gated; RAM incident post-mortem; owner feedback loop on reveals |
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

### In Progress

| Slice | Name | Started | Status | % Complete |
|-------|------|---------|--------|------------|
| — | — | — | — | — |

### Upcoming (see chunk plan in overview-of-slices.md)

| Slice | Name | Dependencies | Priority |
|-------|------|--------------|----------|
| 7 | Player-Created Prompt Pools | 3 | **Next (Chunk 10)** |
| 8 | Collection Browser & Export | 1, 4 | Chunk 11 |

---

## Session History

| Date | Session | Summary | Status |
|------|---------|---------|--------|
| 2026-07-06/07 | #5 | Session-4 deferred checks cleared (all pass) + two owner-directed fix batches: latched click-to-pick judging (no crown button, timer crowns), chat side-placement + explicit 💬 toggle (hover-expand removed) + adaptive prominent height, fixed-shape grid social rows, kudos rematch-staleness bug fix (roster rebroadcast at sim start), pause now freezes local timers, captions off everywhere (text tool scheduled). 296 tests green; `verify_round.sh` PASS. All fixes owner-confirmed 2026-07-07. Slice 7 next | In progress |
| 2026-07-06 | #4 | Slices 4+5+6 implemented and documented: reactions/kudos/collection saves, reveal styles + replays + captions + victory lap, presets/Custom settings + frozen snapshot, Esc menu with host pause. 287 tests green; extended gates PASS. Owner playtested the reveal live (4 fixes applied, incl. duration-based replay settings); all other human checks deferred to the qa-backlog. Incident: CI driver used an ENet peer id as a loop bound → ~80 GB RAM crash; root-caused, fixed, guarded wrapper adopted for gate runs | Completed |
| 2026-07-06 | #3 | Slices 2+3 implemented, documented, and core-confirmed → **playable MVP on LAN**. 178 tests green; automated 3-instance gates (`verify_lobby.sh`, `verify_round.sh`) PASS. New QA process: core-flow sign-offs + `TDD/qa-backlog.md` for deferred detail QA. Design gap logged: no in-game pause/leave menu | Completed |
| 2026-07-06 | #2 | Slices 0+1 implemented and playtested: skeleton (5 autoloads, tests, exports, connect gate owner-confirmed → COMPLETE), full canvas/stroke engine (goldens, replay, sandbox), palette picker redesigned from owner playtest feedback. 102 tests green | Completed |
| 2026-07-04 | #1 | Project initialization: learned 3 Pillars, tech stack decided (Godot 4.6 + typed GDScript + GodotSteam + JSON + ENet dev mode), Recipe approved (16 slices / 18 chunks / hard 180k budget), full TDD folder generated | Completed |

---

## Next Steps

**Immediate (Session 5 continues — Chunk 10: Slice 7 Player-Created Prompt Pools, then Slice 8):**
1. Slice 7 on owner go-ahead (TDD read in full this session): headless core first (`CustomPoolCollector` share math → `PromptPools` custom draw/backfill → `GameSession` phase wiring → RPCs → `pool_setup_screen`), test-alongside
2. Slice 7 touchpoints already in place: `pool_source` setting (lobby option currently "(coming soon)" — enable it), `GameSettings.validate_for_start` hook (stub ready), inert `POOL_SETUP` phase branch in `GameSession` (`pool_setup_entered` observable), share math off `round_count`
3. Then Slice 8 (Collection Browser & Export — Chunk 11); then the **in-image text tool** (owner, 2026-07-07: replaces captions; after Slices 7+8 if budget allows, else first next session)
4. Slice 5/6 reality notes: replay settings are TARGET DURATIONS (`reveal_replay_secs`/`winner_replay_secs`); in-game reads use `Session.game_settings` (frozen snapshot), never lobby settings; `judging_window_sec` is a setting (default 25 s). **New (session 5):** judging never ends early — picks are latched, the deadline crowns; chat placement/prominence are per-phase-screen properties (`chat_placement()`/`chat_prominence()`); captions default OFF (owner profiles saved before 2026-07-07 may restore them ON — see qa-backlog deferral)

**Workflow gotchas:** run `godot --headless --path . --import` after creating new class_name scripts, before tests; test command needs `--ignoreHeadlessMode`; `Session` autoload = `game/session/session_manager.gd` (NOT game_session.gd — that's the host-only sim); settings field is `round_count`, not `rounds`; `SessionClient.rpc_sync_phase` emits specific EventBus signals BEFORE `phase_changed` (ordering contract); automated gates: `tools/verify_lobby.sh` (~15 s) and `tools/verify_round.sh` (~90 s — waits out a real judging window + reveal beats). **Run gates through a guarded wrapper: redirect all output to a file, poll godot RSS and kill above ~3 GB, hard wall-clock cap (the session-4 scratchpad `safe_verify_round.sh` did exactly this — recreate it; scratchpads don't persist). NEVER use ENet peer ids as loop bounds/sizes (random 32-bit ints; caused the 2026-07-06 ~80 GB RAM crash).** Manual playtests: `tools/dev_run.sh 3` launches 3 windowed instances.

---

## Active Decisions/Discussions

| Topic | Status | Notes |
|-------|--------|-------|
| **In-image text tool (captions replacement)** | **Decided (2026-07-07)** | Owner: captions retired (off everywhere); players will instead place text INTO drawings (paint-editor style). Build after Slices 7+8 this session if budget allows, else first next session. Design notes in decision log (bitmap-font deterministic raster, host-side TextFilter, touches Slices 1/3/5) |
| **In-game pause/leave menu** | **Decided (2026-07-06)** | Owner: menu shell (Esc → Resume / Leave to menu) ships in **Slice 6**; Slice 9 upgrades leave semantics (graceful leave, rejoin, below-minimum pause) behind the same button. See decision log |
| Steam App ID registration | Deferred | Register before Chunk 15 (Slice 12); dev uses App ID 480 |
| Art & sound | Deferred | Placeholder programmer art; MVP reached (Chunk 6) — revisit timing owner's call |

---

## Notes

- Hard ~180k-token context budget per session; end at clean checkpoints via `workflows/session-end.md`. If a session runs cool, pull the next chunk forward and record it here.
- Slice TDDs 01–15 were drafted by parallel subagents against the consistency guide + skeleton guide contracts, then reviewed; if an implementation session finds a TDD contradicting the consistency guide, the **consistency guide wins** — log a decision and fix the TDD.
- The blocking user-confirmation gate at the end of Chunk 1 is two-instance ENet connect (Slice 2 depends on it).
