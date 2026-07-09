# WHERE_WE_ARE - Animal Quickdraw

**Purpose:** Single source of truth for project status and session continuity. Any developer or AI can read this to understand the current state and resume work seamlessly.

**Last Updated:** 2026-07-08 (end of session 8)
**Total Sessions:** 8

---

## Current Status

**Active Slice:** None coding-wise — **Slices 10 + 11 are IMPLEMENTED and await the owner's batched checks** (owner instructed session 8 to build both without stopping for human tests)
**Current Objective:** Owner runs the batched Slice 10 + 11 test list (Next Steps below — two blocking-tier items first); fix any failures, then **Slice 12: Steam Platform Integration (Chunk 15)**
**Blockers:** None for testing; Slice 12 needs GodotSteam + Steam accounts/Spacewar for its playtest gate
**Pending owner confirmations:** **Slices 10 + 11 batched checks (session-8 list — includes their normally-blocking items)**; Slice 7 force-continue check; Slice 7 + 8 + 9 + 16 + 17 batchable lists (qa-backlog)

---

## Quick Links

| Document | Path | Notes |
|----------|------|-------|
| Skeleton TDD | `TDD/00-skeleton-build-guide.md` | Implemented — see implementation notes |
| Skeleton Implementation Notes | `TDD/00-skeleton-implementation-notes.md` | What was actually built + deviations |
| **Slice 16 TDD (text tool)** | `TDD/16-in-image-text-tool.md` | Owner-approved mini-TDD; built + drag-reworked session 6 |
| **Slice 16 Implementation Notes** | `TDD/16-in-image-text-tool-implementation-notes.md` | TEXT op, PixelFont, drag-to-place Text row, Eraser, caption pipeline deleted |
| **Slice 17 TDD (ready-up)** | `TDD/17-ready-up.md` | Done/Unready in DRAWING; all-ready early advance; chat-header strip in JUDGING |
| **Slice 17 Implementation Notes** | `TDD/17-ready-up-implementation-notes.md` | Judge pick-gating rationale, Slice 9 hooks |
| **Slice 9 TDD (connectivity)** | `TDD/09-connectivity-resilience.md` | Built session 7; completion status appended |
| **Slice 9 Implementation Notes** | `TDD/09-connectivity-resilience-implementation-notes.md` | Cursor rotation, pause reuse, wrap-up-in-bundle, full late-join allotment, CI lessons |
| **Slice 10 TDD (wrap-up)** | `TDD/10-endgame-wrapup.md` | Implemented session 8; completion status appended |
| **Slice 10 Implementation Notes** | `TDD/10-endgame-wrapup-implementation-notes.md` | Bundle-in-results, WrapUpCalculator, sequence UI, host-quit hold, pin-rule lesson |
| **Slice 11 TDD (avatars)** | `TDD/11-avatars.md` | Implemented session 8; completion status appended |
| **Slice 11 Implementation Notes** | `TDD/11-avatars-implementation-notes.md` | CircleMask, AvatarStore/Resolver/Chip, platform_id sync, roster "avatar" key |
| **Next Slice TDD** | `TDD/12-steam-integration.md` | **Session 9 (Chunk 15)** — after the batched owner checks clear |
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
| Latest Session Log | `TDD/logs/2026-07-08-session-8.md` | Slices 10+11 built + documented, owner checks batched; lambda-capture + node-name-collision lessons |
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
| 16 | In-Image Text Tool + Eraser (captions replacement) | 2026-07-07 | **COMPLETE (core-confirmed)** — TEXT op in DrawingDoc v1, PixelFont goldens, drag-to-place Text row (owner rework), Eraser, caption pipeline deleted; owner confirmed font/in-round/drag/eraser. Root-cause note: `SubViewportContainer.mouse_target` must stay true (regression-tested) |
| 17 | Ready-Up | 2026-07-07 | **COMPLETE (core-confirmed)** — Done!/Unready + ready panel in DRAWING, chat-header strip in JUDGING, all-ready early advance (judge pick-gated); owner: "working great"; 380 tests green; both gates PASS |
| 9 | Connectivity & Resilience | 2026-07-07 | **COMPLETE (core-confirmed)** — owner confirmed all 4 blocking checks on a 4-instance run ("seems to be working!"); late join / rejoin memory / below-min pause + End-game-now / dodge guard; full late-join allotment (owner decision); 422 tests green; all 3 gates PASS incl. new `verify_resilience.sh` |
| 10 | End-Game Wrap-Up | 2026-07-08 | **IMPLEMENTED (owner checks batched)** — superlatives, 8-title set + points, final standings; bundle rides `results["wrap_up"]`; sequence UI with per-peer skip; host-quit hold; placeholder standings screen deleted. 453 tests green at slice end; 3 gates PASS. Awaiting the session-8 batched checks (early-end check is blocking-tier) |
| 11 | Avatars | 2026-07-08 | **IMPLEMENTED (owner checks batched)** — circular editor (Slice 1 mask hook activated), avatar.json, platform_id-keyed sync + roster `"avatar"` key, fallback chain, AvatarChip retrofits (lobby/ready strips/wrap-up/menu), 6 house avatars. 487 tests green; 3 gates PASS. Awaiting the session-8 batched checks (two-instance sync is blocking-tier) |

### In Progress

| Slice | Name | Started | Status | % Complete |
|-------|------|---------|--------|------------|
| — | — | — | — | — |

### Upcoming (see chunk plan in overview-of-slices.md)

| Slice | Name | Dependencies | Priority |
|-------|------|--------------|----------|
| 12 | Steam Platform Integration | 2, 3 (Platform facade swap) | **Next (session 9, Chunk 15)** — after the batched owner checks clear |

---

## Session History

| Date | Session | Summary | Status |
|------|---------|---------|--------|
| 2026-07-07/08 | #8 | **Slices 10 + 11 implemented and documented back-to-back, NO owner tests** (owner instruction — all checks batched to session end). Slice 10: WrapUpCalculator + bundle-in-results (no new RPC/route), three-act sequence UI with per-peer skip, host-quit hold, placeholder standings screen deleted. Slice 11: circular avatar editor (mask hook activated), AvatarStore/Resolver/Chip + platform_id-keyed sync + roster `"avatar"` key, retrofits everywhere, 6 house avatars. In passing: pre-existing WinnerSpotlight null race fixed; `verify_round` now pins `kudos_allotment` (owner-profile pollution — pin-rule 3rd instance). 422 → 487 tests green; all 3 gates PASS after each slice | Completed (owner checks pending) |
| 2026-07-07 | #7 | **Slice 9 implemented, documented, owner-confirmed** (all 4 blocking checks on a 4-instance run). Built on shipped machinery, deviations logged: judge rotation cursor (replaces Slice 3 modulo), below-min pause rides the Slice 6 PAUSED pipeline (reason-tagged), wrap-up contract folded into the results bundle, judge seat-hold fixes a latent Slice 17 early-end gap, mid-DRAWING rejoiner sit-out. Owner decision: late joiners get the FULL kudos allotment (brief §11 amended). New gate `verify_resilience.sh` (drop→pause→rejoin→resume→kept card wins); its first runs surfaced + fixed a departure-ordering bug, non-idempotent CI driver spawn, and cross-gate profile pollution (pin rule extended). 380 → 422 tests green; all 3 gates PASS | Completed |
| 2026-07-07 | #6 | **Slices 16 + 17 implemented, documented, owner-confirmed.** Slice 16: TEXT op in DrawingDoc v1 + PixelFont goldens + host censoring; caption pipeline deleted (incl. the profile-leftover fix); owner-directed same-session rework to drag-to-place + Eraser tool + footprint cursor. Slice 17: ready-up (Done!/Unready, ready panel, chat-header strip, all-ready early advance, judge pick-gated — supersedes "judging never ends early"). Root causes nailed: CI must pin `pool_source` (restored profile parked a gate in POOL_SETUP); `SubViewportContainer.mouse_target` (default false since Godot 4.5) silently blocks ALL drops — now set + regression-pinned. 350 → 380 tests green; gates PASS | Completed |
| 2026-07-06/07 | #5 | Session-4 deferred checks cleared + two owner-directed fix batches (latched click-to-pick judging, chat toggle/side-placement/adaptive sizing, fixed-shape social rows, kudos rematch-staleness bug fix, pause freezes timers, captions retired). **Slices 7 + 8 implemented, documented, owner-confirmed** (pool submission flow; export verified externally). 287 → 350 tests green; gates PASS. Text tool scheduled as session 6's first item | Completed |
| 2026-07-06 | #4 | Slices 4+5+6 implemented and documented: reactions/kudos/collection saves, reveal styles + replays + captions + victory lap, presets/Custom settings + frozen snapshot, Esc menu with host pause. 287 tests green; extended gates PASS. Owner playtested the reveal live (4 fixes applied, incl. duration-based replay settings); all other human checks deferred to the qa-backlog. Incident: CI driver used an ENet peer id as a loop bound → ~80 GB RAM crash; root-caused, fixed, guarded wrapper adopted for gate runs | Completed |
| 2026-07-06 | #3 | Slices 2+3 implemented, documented, and core-confirmed → **playable MVP on LAN**. 178 tests green; automated 3-instance gates (`verify_lobby.sh`, `verify_round.sh`) PASS. New QA process: core-flow sign-offs + `TDD/qa-backlog.md` for deferred detail QA. Design gap logged: no in-game pause/leave menu | Completed |
| 2026-07-06 | #2 | Slices 0+1 implemented and playtested: skeleton (5 autoloads, tests, exports, connect gate owner-confirmed → COMPLETE), full canvas/stroke engine (goldens, replay, sandbox), palette picker redesigned from owner playtest feedback. 102 tests green | Completed |
| 2026-07-04 | #1 | Project initialization: learned 3 Pillars, tech stack decided (Godot 4.6 + typed GDScript + GodotSteam + JSON + ENet dev mode), Recipe approved (16 slices / 18 chunks / hard 180k budget), full TDD folder generated | Completed |

---

## Next Steps

**Immediate — OWNER: the session-8 batched test list (Slices 10 + 11).** Run `tools/dev_run.sh 3` (or 4). Blocking-tier items FIRST:

1. **[BLOCKING] Slice 10 early-end wrap-up:** start a 3-player game, have one player quit during round 1's drawing (below-minimum pause) → host presses End game now → all peers land on the wrap-up with all-zero standings, no empty award cards, "ended early" badge
2. **[BLOCKING] Slice 11 two-instance avatar sync:** draw + save an avatar on instance A (menu → Avatar) → host/join a lobby → A's face shows on BOTH instances' lobby lists; B (no avatar) shows a name circle on both
3. Slice 10 full sequence: play a short game with reactions/kudos → superlative cards (replay flourish + author reveal) → title cards → podium standings; pacing feels right
4. Slice 10 skip isolation: skip on one client — others unaffected; first press finishes a card's replay, second advances
5. Slice 10 negative scores: a no-pick judge shows a true minus in the final standings; title-point breakdown tooltip on hover
6. Slice 11 editor flows: draw in the circle (rim clamping feel, fills near the rim), Save toast, re-open loads existing, unsaved-changes prompt, Clear avatar confirm
7. Slice 11 chips: lobby rows / ready panel + chat strip / wrap-up title card + standings / menu button all show faces (or name circles); **no chips on reveal/judging grids** (anonymity)
8. Slice 11 house avatars: two dev instances with no avatar AND blank name (edge) get consistent doodles
9. Full lists mirrored in `TDD/qa-backlog.md` Slice 10 + 11 sections — check off whatever you test

**Then (Next Session — Session 9):**
1. Session Start workflow; collect batched-test results FIRST and fix failures before new work
2. **Slice 12: Steam Platform Integration (Chunk 15)** — read its FULL TDD; needs GodotSteam GDExtension installed + dev App ID 480 (Spacewar); the playtest gate needs two Steam accounts or Spacewar
3. Slice 10 reality notes: wrap-up bundle = `results["wrap_up"]` (validate via `SessionClient.is_valid_wrap_up_bundle`); base `final_scores`/`standings` stay BASE scores — final display truth is `wrap_up.standings`; EventBus order on WRAP_UP: `session_results_ready` → `wrap_up_started` → `titles_awarded` → `game_ended` → `phase_changed` (Slice 14's feed); host-quit-mid-sequence defers via `Session.hold_host_quit`
4. Slice 11 reality notes: avatar sync keyed by platform_id; roster payload carries an optional `"avatar"` key; `AvatarStore.path` is the test seam; `AvatarChip.set_player(...)` static vs `bind_platform_id(pid, fallback_name)` live; Slice 12's Steam names flow through `Platform.get_display_name()` with zero avatar-code changes (the facade point)
5. Reality notes (carried): judge rotation is a CURSOR (`_judge_cursor`); pause is reason-tagged; departures check pause BEFORE advancement; judge seat HOLDS; late joiners get the FULL kudos allotment; replay settings are TARGET DURATIONS; in-game reads use `Session.game_settings` (frozen); captions are GONE (TEXT ops, host-censored, canvas pre-censors identically); `CollectionStore` + `Save` PNG helpers exist

**Workflow gotchas:** run `godot --headless --path . --import` after creating new class_name scripts, before tests; test command needs `--ignoreHeadlessMode`; `Session` autoload = `game/session/session_manager.gd` (NOT game_session.gd — that's the host-only sim); settings field is `round_count`, not `rounds`; `SessionClient.rpc_sync_phase` emits specific EventBus signals BEFORE `phase_changed` (ordering contract); automated gates: `tools/verify_lobby.sh` (~15 s), `tools/verify_round.sh` (~90 s), `tools/verify_resilience.sh` (~35 s, Slice 9). **Run gates through a guarded wrapper: redirect all output to a file, poll godot RSS and kill above ~3 GB, hard wall-clock cap (recreate `safe_gate.sh` in the scratchpad; scratchpads don't persist). KILL any `dev_run.sh` instances before gate runs — they hold the dev ENet port. NEVER use ENet peer ids as loop bounds/sizes (random 32-bit ints; 2026-07-06 ~80 GB RAM crash). CI drivers must pin EVERY setting their flow depends on — `last_lobby_settings` has THREE writers: other gates (verify_resilience's GRID/10 s broke verify_round's beats, 2026-07-07) AND the owner's own playtests (their profile's `kudos_allotment: 2` broke verify_round's wallet check, session 8) — and driver spawn must be idempotent against menu reloads (a mid-scenario leave reloads the menu and re-runs `_handle_ci_args`).** GDScript gotchas (session 8): lambda captures are BY-VALUE — mutate a captured container, never reassign (the Rig pattern exists for this); shared components must namespace internal node names (recursive `find_child` sees through component boundaries — AvatarChip's label is `ChipNameLabel` for this reason); a signal handler that nulls a field the emitter's caller still holds crashes the next line — capture a local before calls that may emit (WinnerSpotlight/SuperlativeCard fix). Godot engine gotcha (2026-07-07): drops onto a `SubViewportContainer` require `mouse_target = true` (default false since 4.5) — `CanvasDropTarget` sets it, a test pins it; headless can never verify real drop delivery. Expected gate-log noise: the resume broadcast races a rejoiner's navigation ("Node not found: RoundRoot/SessionClient" on that peer — the welcome snapshot covers it). Manual playtests: `tools/dev_run.sh N` launches N windowed instances (rejoin = Join again from the SAME window; the instance name is the identity).

---

## Active Decisions/Discussions

| Topic | Status | Notes |
|-------|--------|-------|
| **In-image text tool (captions replacement)** | **RESOLVED — Slice 16 COMPLETE (2026-07-07)** | Built, owner-reworked to drag-to-place + Eraser, all confirmed. Batchables in qa-backlog Slice 16 section |
| **In-game pause/leave menu** | **RESOLVED — Slice 9 COMPLETE (2026-07-07)** | Slice 6 shipped the Esc menu; Slice 9 shipped the upgraded semantics: leave = disconnect with rejoin memory, below-minimum pause + auto-resume, host End-game-now. See decision log |
| Steam App ID registration | Deferred | Register before Chunk 15 (Slice 12); dev uses App ID 480 |
| Art & sound | Deferred | Placeholder programmer art; MVP reached (Chunk 6) — revisit timing owner's call |

---

## Notes

- Hard ~180k-token context budget per session; end at clean checkpoints via `workflows/session-end.md`. If a session runs cool, pull the next chunk forward and record it here.
- Slice TDDs 01–15 were drafted by parallel subagents against the consistency guide + skeleton guide contracts, then reviewed; if an implementation session finds a TDD contradicting the consistency guide, the **consistency guide wins** — log a decision and fix the TDD.
- The blocking user-confirmation gate at the end of Chunk 1 is two-instance ENet connect (Slice 2 depends on it).
