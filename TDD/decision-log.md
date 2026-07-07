# Decision Log: Animal Quickdraw

**Purpose:** Track design decisions made during development. New entries are added at the top of the Decisions section.

**Last Updated:** 2026-07-06

---

## Decisions

*New entries go here, at the top of this section.*

---

### Kudos rematch-staleness fix; pause freezes local timers; side chat defaults expanded; captions retired in favor of a planned in-image text tool
**Date:** 2026-07-07 | **Slice:** 3/4/5/6 surfaces (session-5 second playtest round) | **Decided by:** Owner

**Context:** Owner re-tested the first fix batch. New findings: (1) kudos buttons wrongly disabled for some clients — owner correctly suspected state "sticking around from another test game"; (2) pausing froze phase progression but not the visible countdowns, and a drawer paused past the deadline would get auto-submitted and locked out; (3) the side chat should start expanded; (4) captions are unwanted — replace with text placed inside the drawing itself.

**Decision:**
- **Bug fix (kudos):** `GameSession.start_game()` resets every player's kudos economy on the **host roster only**; nothing re-broadcast it, so client wallets kept the previous game's granted/spent (first game: granted=0 until the first kudos forced a sync; rematch: spent counts persisted — exactly the owner's "one can, one can't"). Fix: `SessionClient` broadcasts the roster immediately after starting the simulation. `Session.broadcast_roster()`'s guard switched from `Net.is_host()` to `multiplayer.is_server()` so headless tests exercise the same path. Regression test + `verify_round.sh` PASS.
- **Bug fix (pause):** `PhaseTimer` freezes its rendered countdown on `PAUSED` (re-arms on the resume `start()`), and the draw screen's local auto-submit is suppressed while paused — the host's refreshed deadline is the only clock that matters on resume.
- **Side chat defaults expanded:** the drawer's drawing view declares NORMAL prominence (expanded) in the SIDE placement; the 💬 toggle still collapses it.
- **Captions retired:** `comments_enabled` now defaults false everywhere (field default + every preset); the Custom toggle remains as dormant opt-in plumbing. Replacement direction: a **text tool in the drawing canvas** (place text into the image like a paint editor). Not yet scheduled — needs a deterministic text-raster design (bitmap-font glyph blitting keeps CPU raster determinism; host-side TextFilter on text ops) and touches Slice 1 (doc/ops/rasterizer/canvas UI), Slice 3 (submission validation), Slice 5 (caption pipeline removal).

**Impact:**
- Affects: `session_client.gd`/`session_manager.gd` (roster sync), `phase_timer.gd`/`draw_screen.gd` (pause), `settings.gd`/`settings_defaults.gd` (caption defaults — preset identity tests updated), chat defaults. The qa-backlog "PhaseTimer shows a stale countdown while paused" known-limitation item is resolved.
- The text tool is **scheduled after Slices 7+8** (owner, 2026-07-07): built this session if the context budget allows, else first item next session.
- Migration needed: No. Breaking change: No.

**Status:** [x] Code implemented [x] Tests green (296/296) [x] verify_round gate PASS [x] Owner re-test (2026-07-07 — all pass; caption-box leftover deferred, see qa-backlog) [x] Text-tool scheduled (after Slices 7+8)

---

### Judging = latched click-to-pick; chat gets explicit toggle + per-phase placement; fixed-shape social rows
**Date:** 2026-07-06 | **Slice:** 3/4/5 surfaces (session-5 deferred-check playtest) | **Decided by:** Owner

**Context:** Session-5 opened with the deferred blocking checks from session 4. All five machine-verified flows passed (preset lock, client mirror, Esc/pause, kudos, reactions), but the playtest surfaced four UX problems: chat hover-expand fired constantly mid-drawing; chat sat under the canvas instead of beside it; the prominent chat crowded the reveal grid's social controls; the grid's kudos/emoji rows misaligned across cells; and the judge's confirm-button pick flow felt wrong.

**Decision:**
- **Judging is click-to-pick with a LATCHED selection:** clicking a drawing sends the pick immediately; the host latches it (re-picks overwrite, last one wins) and the **judging deadline is what crowns the winner** — the "Crown this drawing" confirm button is gone and a pick no longer ends the phase early. Empty latch at deadline keeps the −1 no-pick penalty. State-machine change to Slice 3: `JUDGING → RESOLUTION` now fires **only** on the deadline.
- **Chat expansion is an explicit toggle button, never hover.** Collapsed chat shows an unread badge; expanding clears it. A user toggle survives same-phase refreshes (pause/resume); phase changes reset to the phase's default.
- **Chat placement is per-phase, like prominence:** the drawer's drawing view puts chat in a SIDE column right of the canvas (collapsed by default); judge-wait and reveal/judging keep BOTTOM expanded. `RoundRoot` reparents its persistent panel between the two slots.
- **PROMINENT chat height adapts to the viewport** (`clampf(22% of height, 120, 300)` px) so the expanded chat never covers grid cells' emoji/kudos controls.
- **Grid social rows have a fixed shape in every cell** (row 1: centered reactions; row 2: yours-hint | caption | kudos with reserved slots) so cells align regardless of caption/ownership; cell min size 340×310.

**Rationale:** Owner-directed after live play. Latching keeps the riffing window at full length (the judge can change their mind as reactions land) at the cost of never ending judging early — flagged for pacing review; if full-window judging drags, shorten `judging_window_sec` or add "timer accelerates once picked" later.

**Impact:**
- Affects: Slice 3 (judging state machine + RPC semantics — TDD updated in place), Slice 5 (reveal-screen cells), Slice 2/6 (chat panel component; lobby chat just gains the toggle header). Slice 7's `POOL_SETUP` screen inherits the new chat defaults automatically (bottom/normal).
- Migration needed: No. Breaking change: No (RPC signature unchanged; only host handling).

**Status:** [x] Code implemented [x] Tests updated (293/293 green) [x] Slice 3 TDD updated [x] Owner re-test of the four fixes (2026-07-07 — all confirmed)

---

### Slice 6: snapshot as a separate object, permissive engine clamps, preset v1 values, pause shell
**Date:** 2026-07-06 | **Slice:** 6 | **Type:** Quick

**Decision:**
- **`Session.game_settings`** (new, per-peer) holds the frozen start-payload snapshot every in-game system reads; the lobby `Session.settings` object stays editable and keeps AUTO sentinels for the next lobby. The TDD's freeze-the-lobby-object lifecycle conflated the two.
- **Engine clamps stay permissive (rounds 1–32); the lobby stepper enforces the player-facing 3–20** — CI and unit tests legitimately run 1–2-round games, and dual clamp regimes would desync host/client mirrors.
- **Preset v1 values recorded** (expect tuning): Streamlined = grid/no replay/15 s judging/20 s draw/captions off; Social = one-at-a-time/FULL replay/8 s reveal + 12 s winner targets/40 s judging/45 s draw; Default = one-at-a-time/winner-only 8 s/25 s judging/30 s draw. Identity tests pin each mode's meaning, not exact numbers.
- **`judging_window_sec` became a setting** (was Slice 3's constant; default 25 s per TDD).
- **Pause (owner addition):** `GameSession.pause()` (ex-Slice 9 stub) broadcasts a PAUSED phase; `RoundRoot` keeps the live screen under a forced overlay and resume refreshes deadlines **in place** (`refresh_deadline` on all phase screens) so a mid-drawing pause never wipes a canvas. Beat metronome freezes via `Timer.paused`. Leave = existing Slice 2 semantics until Slice 9.
- Existing names win over the TDD draft (`draw_time_sec`, duration-based replay keys, `SettingsDefaults.Mode`); draw-time range reconciled to 10–120 s; no 150 ms coalescing (steppers don't chatter); mode selector reuses Slice 2's OptionButton.

**Status:** [x] Code implemented [x] Tests green (287/287) [x] Gates PASS [x] Implementation notes written [ ] Owner core-flow sign-off

---

### Replay settings are target durations; finished replays hold a 2 s still
**Date:** 2026-07-06 | **Slice:** 5 (contract consumed by 6) | **Decided by:** Owner (playtest)

**Decision:** `reveal_replay_secs` / `winner_replay_secs` replace the speed-multiplier settings: the replay speeds up to fit the set time (30 s drawing @ 5 s target = 6×; @ 30 s = realtime), floored at realtime for shorter drawings. Every finished replay holds the completed still for `REPLAY_STILL_HOLD_SECS = 2.0`; the host sizes RESOLUTION to fit the full winner replay + hold (it may exceed the 6 s base — a replay is never cut off). `ReplayPlayer`'s Slice 1 hard 10 s cap became caller-optional (`enforce_duration_cap`) since a host-set 30 s realtime replay is now legitimate. Also from the same playtest: reaction UI enlarged; host pause button folded into Slice 6's Esc menu.

**Impact:** Slice 5 TDD §2 table updated in place; Slice 6 must surface the renamed keys (its TDD draft references the old speed keys — the updated table wins).

---

### In-game pause/leave menu lands in Slice 6 (shell), semantics upgraded in Slice 9
**Date:** 2026-07-06 | **Slice:** 6, 9 | **Decided by:** Owner

**Context:** Owner-flagged gap (2026-07-06, session 3): once a game starts there is no settings access or exit-to-menu short of closing the window. Covered by no planned slice; candidate homes were Slice 6 (settings surface) or Slice 9 (resilience/voluntary-leave).

**Decision:** Slice 6 ships the menu shell — an in-game Esc overlay with Resume / Leave to main menu (leave uses the existing session paths: host leaving ends the session for everyone, a drawer leaving becomes a blank and stays on the roster). Slice 9 upgrades the semantics behind the same button (graceful voluntary leave, rejoin memory, below-minimum pause) without moving the UI.

**Rationale:** The gap hurts every playtest between now and Chunk 12; Slice 6 is UI-heavy anyway and the shell only exposes already-existing behavior, so the added scope is small.

**Impact:** Slice 6 scope grows by the Esc overlay; Slice 9's TDD assumptions unchanged (it owns leave/rejoin semantics either way). WHERE_WE_ARE Active Decisions entry resolved.

---

### Slice 5: stage-in-screen reveal, single gap constant, captions transient, beat failsafe
**Date:** 2026-07-06 | **Slice:** 5 | **Type:** Quick

**Decision:**
- **One-at-a-time stage built inside `reveal_judging_screen`** (no `reveal_stage.tscn`, no `GridLayout` retrofit): beats settle into the real judging cells, making REVEAL→JUDGING seamless by construction and reusing all Slice 4 cell wiring. GridLayout can be created when Slices 8/10 actually need it.
- **Single idle-gap constant:** kept Slice 1's implemented `REPLAY_MAX_OP_GAP_SEC = 1.0` instead of adding the TDD's duplicate `REPLAY_MAX_IDLE_GAP_SECS = 0.35` — planner and renderer must share one compression rule or host beat schedules drift from client renders; the reveal caps already guarantee pacing.
- **Captions are session-transient and payload-level:** they ride the submission payload beside the doc (never inside it), so collection saves can never leak them; not persisted in v1 (revisit if playtests miss them).
- **Beat-chain failsafe:** the REVEAL phase deadline = beat schedule + `REVEAL_BEAT_FAILSAFE_SECS`; the ordinary deadline force-advances if beats stall, and stale beat timers self-drop — the host phase timer and beat timer can never double-advance.
- **`ReactionGate.open_for()` now preserves a running close-grace** so reactions racing a beat boundary still land for the previous drawing (§10).
- **Slice 4 follow-up fix:** `draw_screen.tscn` had `show_save_toggle = false`, making self-save unreachable in real rounds; flipped to true.
- Slice 1's `ReplayPlayer` needed no extension (already had `speed_multiplier` + cap, composing safely with planner timescales).

**Status:** [x] Code implemented [x] Tests green (260/260) [x] Gates PASS (incl. beat/gather/caption checks) [x] Implementation notes written [ ] Owner core-flow sign-off

---

### Slice 4: RPC placement, collection write path details, pending-state UX, CI social gate
**Date:** 2026-07-06 | **Slice:** 4 | **Type:** Quick

**Decision:**
- **Reaction/kudos RPCs live on `SessionClient`** (steps 1–2) with validated `GameSession.react()/give_kudos()` entry points (steps 3–5) — the TDD's "GameSession RPC surface" wording predates the Slice 3 SessionClient/GameSession split, which wins.
- **`CollectionStore` writes doc-before-index** (TDD said index first): a dangling index entry would render as a broken item in the Slice 8 browser, an orphaned doc file is invisible. `Save.write_png()` added so thumbnails stay behind the single-choke-point rule; `CollectionStore.root_dir` static seam keeps tests/CI out of real collections. `CollectionStore` centrally emits `collection_item_added` + new 6th signal `collection_save_failed`.
- **Self-save fires when the draw screen retires** (last *submitted* doc), not per submit call — latest-wins resubmission makes per-submit idempotent saves keep the wrong (first) version.
- **KudosButton pending state re-enables on a 2 s timeout**, not the TDD's "next total/phase sync" heuristic — the giver's own `kudos_total_changed` precedes their private confirm on the reliable channel, so the heuristic flicker-re-enables mid-flight. No optimistic spend, per TDD.
- **`GameSettings.kudos_allotment` field added now** (default `KUDOS_AUTO = -1`; explicit 0 = kudos off, min-1 clamp AUTO-only). Slice 6 adds the UI.
- **Results bundle `reaction_stats`/`kudos_stats` filled** with uid-keyed nonzero-only aggregates (`totals_by_author` / `received_by_author` + `drawing_totals`); Slice 10 mines full `SessionStats` host-side.
- **`verify_round.sh` gate extended to the social layer** (judge react/un-react/re-react + kudos with giver-side collection-file verification; drawers cross-react; per-peer convergence checks). **Incident:** the first driver version used a raw ENet peer id (random 32-bit int) as an op-count loop bound — two headless instances froze allocating ~10⁹ dictionaries (~80 GB RAM, machine crash). Fixed to `joined_order` + hard clamp; rule recorded: never use peer ids as sizes/bounds. Gate runs now use a guarded wrapper (output to file + RSS watchdog).

**Status:** [x] Code implemented [x] Tests green (233/233) [x] Gates PASS [x] Implementation notes written [ ] Owner core-flow sign-off

---

### QA process: core-flow sign-offs + deferred fine-grain QA backlog
**Date:** 2026-07-06 | **Slice:** All | **Decided by:** Owner

**Context:** The testing protocol's slice-completion gate batches all UI confirmation onto the owner at every slice boundary. With multi-slice sessions, the detailed checklists outpace the owner's between-session testing time.

**Decision:** Owner playtests between slices/sessions cover **broad strokes and core functions only**. A slice is signed off (marked COMPLETE) on: core-flow owner playtest + full test suite green + automated multi-instance gates green. All fine-grain checks, edge cases, and polish items accumulate in **`TDD/qa-backlog.md`** ("bug hunt" list) — items are added at every slice boundary and never dropped. A full QA sweep of the backlog happens after the game is content-complete (before/with Slice 15 release prep).

**Rationale:** Keeps development velocity while guaranteeing nothing slips untracked; automated gates already machine-verify most mechanics, so human QA can focus on feel and edge cases in one batch.

**Impact:** Affects every slice's completion workflow (supersedes the per-slice batchable-confirmation step of `workflows/slice-completion.md` §3 — batchable items now go to the backlog by default). Retroactively applied: Slices 1, 2, 3 marked COMPLETE (core-confirmed); their deferred items are the backlog's initial content.

**Status:** [x] qa-backlog.md created [x] Slices 1–3 statuses updated [x] WHERE_WE_ARE updated

---

### Slice 3: round-start handshake, return-to-lobby, CI gate substitution
**Date:** 2026-07-06 | **Slice:** 3 | **Type:** Quick

**Decision:**
- **Round-start readiness handshake:** clients' `SessionClient` sends `rpc_request_round_ready`; the host starts the simulation when all connected roster peers report ready or after `ROUND_START_FAILSAFE_SEC = 3.0` (a broken client never stalls the start). Added beyond the TDD because the first `ROUND_INTRO` broadcast can otherwise race clients' deferred scene swap (RPCs to missing node paths are dropped, not queued).
- **`rpc_sync_return_to_lobby`** added to the Session autoload: the standings screen's "Back to lobby" returns everyone to the lobby with roster/settings intact; host prunes mid-game leavers. The TDD named the button but no mechanism.
- **In-GdUnit ENet loopback relay test replaced** by `tools/verify_round.sh` + `RoundCiDriver`: three real processes play a full 2-round game (pick +2, deliberate no-pick −1) and verify phase sequences, role views, and results bundles per peer. GdUnit cannot host two SceneTrees; the multi-process pattern (from `verify_connect`/`verify_lobby`) covers more.
- **EventBus ordering contract:** `SessionClient.rpc_sync_phase` emits phase-specific signals before `phase_changed` so screens always see a current replica.
- **`drawing_id` minted at collect time** (TDD §2 "on acceptance" vs §6 "at collect" — collect wins; resubmission would churn acceptance-time ids).
- **Session-3 pacing (owner directive):** blocking playtest gates for Slices 2+3 are batched to a single owner checklist at session end; automated equivalents ran green first (extends the session-2 precedent).

**Context:** Slice 3 implementation (session 3). Full detail in `TDD/03-core-round-loop-implementation-notes.md`. 178 tests green; `verify_lobby.sh` + `verify_round.sh` both PASS.

**Impact:** Affects Slices 9 (readiness signal reusable for rejoin), 10 (working lobby-return path). Migration: none. Breaking: none.

**Status:** [x] Code implemented [x] Tests green (178) [x] Implementation notes written [ ] Owner playtest confirmation

---

### Slice 2: Session autoload placement, settings field names, dev-gate harness
**Date:** 2026-07-06 | **Slice:** 2 | **Type:** Quick

**Decision:**
- **`Session` autoload** registered as `game/session/session_manager.gd`, ordered after `Save`, before `Nav`. The Slice 2 TDD's `game_session.gd` placement is superseded: that file name stays reserved for Slice 3's host-only `GameSession` RefCounted simulation (consistency guide §4 SessionClient/GameSession split wins on conflict).
- **`GameSettings` field names unified with Slice 3:** `round_count` (not `rounds`), plus `pool_type_id` defaulting to `SettingsDefaults.DEFAULT_POOL_TYPE_ID` ("animal_adjective") added now so the start snapshot is forward-compatible.
- **Draw-time range** 15–180 s per Slice 2 TDD; default stays 30 s (2026-07-04 decision supersedes the TDD's 45).
- **New `game/session/session_rules.gd`:** pure static validators + injectable-clock `ChatRateLimiter`, so every host-side rule is unit-testable without a network (cg §9). Future request handlers follow this pattern.
- **Client-side join/register watchdogs** (10 s, epoch-guarded) added beyond the TDD's host-side timeout — ENet/UDP gives no fast failure for dead room codes; without them the client hangs in "Connecting…".
- **Automated Slice 2 gate:** `LobbyCiDriver` + `tools/verify_lobby.sh` (3-instance roster/chat/start + dead-code recovery), per the session-2 "automated equivalents for blocking gates" precedent. Owner playtests remain the formal gate.

**Context:** Slice 2 implementation (session 3). Full deviation detail in `TDD/02-lobby-session-roster-implementation-notes.md`.

**Impact:** Affects Slices 3 (file name now free as documented), 6 (settings field names), 9 (watchdog/timeout groundwork). Migration: none. Breaking: none.

**Status:** [x] Code implemented [x] Tests green (135 total) [x] Implementation notes written [ ] Owner playtest confirmation

---

### Palette picker redesign: all-colors overlay + drag-to-pin quick slots
**Date:** 2026-07-06 | **Slice:** 1 | **Decided by:** Owner (playtest feedback)

**Context:** Owner playtested the Canvas Sandbox ("works really good") but found (a) a stuck selected-outline bug after picking a shade from the per-family popup, and (b) the per-family long-press popups force players to hunt for shades one family at a time — bad fit for a 15–30 s draw timer.

**Decision:** Replace per-family shade popups with:
1. An **"All colors" toggle** that opens an overlay grid of the full 60-color table above the palette bar (families as light→dark columns). Click any swatch to select; selection persists until the next pick.
2. **Three custom quick-slots** on the bar: drag any color (from grid or base row) onto a blank slot to pin it; click to reuse; right-click to clear. **Session-only** — not persisted (persistence to profile.json is a cheap later add if playtests want it).
3. Selection shown as an explicit outlined-swatch state driven by the picker (root-cause fix for the stuck-outline bug — never rely on button hover/focus leftovers).

**Rationale:** Brief §6 prescribes preset shades behind an "expand" — it does not prescribe per-family popups. One sweep of all 60 presets beats serial hunting under time pressure; pinned slots let players set a per-drawing palette once and draw at speed. No freeform mixing anywhere (unchanged).

**Alternatives considered:** Inline expand pushing the canvas smaller (rejected: layout jump mid-drawing); persistent slots (deferred).

**Impact:**
- Affects: `ui/canvas/palette_picker.gd` internals only (+ new `palette_swatch.gd`, `palette_slot.gd`). The `color_selected(color_index)` contract is unchanged; no other slice touched. Slice 11's avatar editor inherits the new picker automatically.
- Migration needed: No. Breaking change: No.

**Status:** [x] Code implemented [x] Tests updated (13 new; 102 total green) [x] Slice 1 TDD + implementation notes updated

---

### Slice 1: palette hex values + raster implementation choices
**Date:** 2026-07-06 | **Slice:** 1 | **Type:** Quick

**Decision:**
- **Palette values chosen** (append-only from here on): family 0 greyscale white→black; families 1–11 red/orange/yellow/green/teal/blue/navy/purple/pink/brown/tan, 5 shades each, base = middle shade. Exact hex in `core/constants/palette.gd`. Default brush color = index 4 (black).
- **Fill implementation:** scanline fill over a `PackedInt32Array` pixel view (per-pixel GDScript Image access blows the 50 ms budget ~10×). Pixel-identical to the spec'd rule; LE byte order on all targets.
- **Circle stamps:** row-span `fill_rect` form of the same `dx²+dy²≤r²` rule (pixel-identical, ~30× fewer native calls).
- **Golden baking:** done by temporarily printing hashes inside the GdUnit suite (standalone `-s` scripts can't resolve project class names). Six goldens baked on macOS arm64 / Godot 4.6.stable; cross-platform verification note: re-run the golden suite on Windows/Linux when those become available (expected identical — CPU integer/IEEE math only).
- Parts 1+2 built in one pass (continuous session); the interim "fill/rotate disabled" toolbar state was never shipped.

**Context:** Slice 1 implementation. All contracts (DrawingDoc format, DocRasterizer/ReplayPlayer APIs, canvas signals) match the TDD verbatim.

---

### Skeleton toolchain pins & export settings
**Date:** 2026-07-06 | **Slice:** 0 | **Type:** Quick

**Decision:**
- **Godot:** 4.6.stable.official.89cea1439 (Homebrew). **GdUnit4:** v6.1.3, vendored from `godot-gdunit-labs/gdUnit4` into `addons/gdUnit4`.
- **Test command:** `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/` (flag mandatory; consistency guide §9 updated).
- `rendering/textures/vram_compression/import_etc2_astc=true` (required for macOS arm64/universal export).
- `config/version` must be plain dotted-numeric (`0.1.0`) — Windows export rejects suffixes like `-dev`. Slice 15's `APP_VERSION` scheme stays plain semver.

**Context:** Skeleton chunk installation and export verification. Debug exports for all three OSes build clean from CLI; export templates 4.6.stable were already installed.

---

### Session 2 pacing: continuous multi-chunk session, playtest gates batched
**Date:** 2026-07-06 | **Slice:** 0–3 | **Type:** Quick

**Decision:** This session implements Skeleton + Slices 1–3 end-to-end without per-chunk stops (owner directive, overriding the one-chunk-per-session default for this session only). Blocking playtest gates are handled as: (a) automated equivalents where machine-verifiable (e.g. `tools/verify_connect.sh` for the two-instance ENet gate; scripted loopback round tests for the MVP gate), and (b) a single batched owner-playtest checklist at session end. Slices are documented as "implementation complete — pending owner confirmation," never COMPLETE, until the owner confirms (per testing-protocol deferred-testing rules). Owner checks in after Slice 3 to decide whether to continue or reset context.

**Context:** Owner explicitly requested compressing multiple chunks into one session ("complete the skeleton and multiple slices... continue onto the next slice instead of stopping"). Documentation cadence (implementation notes + WHERE_WE_ARE per slice) is unchanged. Git is owner-managed; the AI never commits.

---

### TDD drafting reconciliation — contract refinements & judgment calls
**Date:** 2026-07-04 | **Slice:** Multiple | **Type:** Quick

**Decision:** The following calls were made while drafting slice TDDs 01–15 in parallel; the consistency guide and skeleton guide were amended to match. If any are wrong, veto before the affected chunk starts.

*Contract refinements (consistency/skeleton guides updated):*
- Authoritative rasterization (fill, replay, export, golden tests) is **CPU-side** (`DocRasterizer`); GPU/SubViewport is display-only — cross-platform determinism (Slice 1).
- `collection/index.json` uses a versioned envelope `{"v":1,"items":[...]}` (Slices 4/8 converged independently).
- Canonical `SessionClient` (all peers, owns RPCs) / host-only `GameSession` simulation split (Slice 3).
- `PlatformBackend.create_host_peer/create_client_peer` are awaitable coroutines (Steam lobby ops are callback-async; Slice 12).
- Nested data classes referenced qualified (`Roster.PlayerState`).

*Design judgment calls (owner may veto):*
- **Superlative-winning drawings also earn the +1 title point** (literal reading of brief §11 "titles/superlatives: +1 each"), gated by `title_points_enabled` (Slice 10).
- Rotating canvas orientation mid-drawing clears the canvas after a confirm dialog (Slice 1).
- Captions are not persisted with collection saves in v1 (Slice 5/8).
- `kudos_allotment = 0` (kudos off) allowed in Custom only; min-1 clamp applies to auto-compute (Slice 4/6).
- Lobby public/private visibility fixed at creation; all Steam lobbies are search-public, "private" = `aq_public="0"` metadata + code/invite as the privacy bar (Slices 12/13).
- Mid-turn judge disconnect: seat holds, window lapses → −1 no-pick; late joiners draw from the next round but react/kudos immediately (Slices 3/9).
- Defaults pending playtest: `DRAW_TIME_DEFAULT_SEC = 30`, pool-setup force-continue at 120s.
- Slice 14 adds a `Stats` autoload beyond the skeleton's original five.

**Context:** Fifteen TDDs drafted by five parallel agents against shared contracts; cross-interface audit fixed three mismatches (Slice 14's `winner_player_id` + `kudos_given`, Slice 13's lobby-metadata key names) and confirmed the rest (kudos ledger fields, `joined_order`, opaque drawing ids).

---

### Session pacing: hard 180k context budget, 18 chunks
**Date:** 2026-07-04 | **Slice:** All | **Type:** Quick

**Decision:** Work sessions follow the original 18-chunk plan with a hard ~180k-token context budget per session, ending every session at a clean checkpoint via the Session End workflow.

**Context:** The AI (Claude Fable 5) has a 1M-token context window, so consolidation to ~11 sessions with a soft 300k ceiling was proposed and viable. Owner chose maximum conservatism: cheaper individual sessions, more frequent playtest gates, guaranteed-clean handoffs. Chunk boundaries may still flex if a session runs cool (pull work forward) or hot (checkpoint early).

---

### Slice TDD authoring: shared docs centralized, per-slice TDDs drafted in parallel
**Date:** 2026-07-04 | **Slice:** All | **Type:** Quick

**Decision:** The consistency guide, skeleton guide, and all cross-slice contracts (RPC conventions, DrawingDoc format, save layout, phase enum, EventBus pattern) were authored centrally first; the 15 per-slice TDDs were then drafted by parallel subagents against those contracts and reviewed for coherence.

**Context:** Keeps the initialization session inside its own context budget while preventing agents from inventing conflicting patterns.

---

## Initial Tech Stack Decisions

### Initial Tech Stack Selection
**Date:** 2026-07-04 | **Slice:** All | **Type:** Full

#### Context
Project initialization — selecting the technology stack for a 3–8 player online drawing party game shipping on Steam for Windows/macOS/Linux from a single codebase, with Steam relay networking, a custom stroke-based drawing canvas, and local-first persistence.

#### Decision
- **Engine:** Godot 4.6 (stable), typed GDScript (static typing mandatory)
- **Steam integration:** GodotSteam GDExtension — lobbies, invites, achievements, SteamMultiplayerPeer relay transport
- **Networking architecture:** host-authoritative sessions over Godot high-level multiplayer; transport swappable behind a `PlatformService` (ENet backend for dev/LAN, Steam backend for shipping)
- **Persistence:** JSON files in `user://` (one file per saved drawing + index; profile; stats)
- **Testing:** GdUnit4, headless-runnable
- **Dev App ID:** Steam 480 (Spacewar) until a real App ID is registered (needed by Slice 12)

#### Rationale
- Godot: best-in-class 2D/UI for a menu-and-canvas game, free/open-source, single-codebase export to all three target OSes, small binaries.
- GodotSteam's SteamMultiplayerPeer plugs Steam Datagram Relay directly into Godot's RPC system, matching the host-authoritative design and §13 IP-privacy requirement.
- Typed GDScript: engine-native speed of iteration with most of the type-safety benefit; enforced via the consistency guide.
- ENet dev mode: multiplayer testing as multiple local instances without Steam accounts; also the seam for any future non-Steam build.
- JSON over SQLite: all persisted data is small (stroke data is KBs); human-readable, zero dependencies; v1 collection browser needs no querying.

#### Alternatives Considered
1. **Unity + Steamworks.NET/Mirror:** workable but heavier editor, more boilerplate, licensing overhead, weaker fit for 2D UI-heavy game.
2. **Electron/Tauri + TypeScript:** best canvas APIs, but weakest Steam relay networking story — ruled out on the §13 requirement.
3. **C# in Godot:** stronger tooling but adds .NET export complexity; Steam bindings a step behind the GDScript path.
4. **SQLite (godot-sqlite):** unnecessary dependency for v1 data shapes.
5. **Steam-only, no dev transport:** rejected — every multiplayer test would need multiple Steam accounts.

#### Impact
- **Affects:** All slices
- **Migration needed:** N/A (initial setup)
- **Breaking change:** N/A

#### Status
- [x] Documentation updated (Recipe, Consistency Guide, Skeleton Build Guide)
- [ ] Code implemented (Skeleton — Chunk 1)
- [ ] Tests updated
- [ ] Integration verified
