# QA Backlog — "Bug Hunt" List

**Purpose:** Running list of every fine-grain check, edge case, and polish item the owner has NOT yet human-tested. Per the owner's QA process (decision log 2026-07-06): between-session playtests cover **broad strokes and core functions only**; everything detailed accumulates here and gets a full pass **after the game is content-complete**. Slices are signed off on core flows + green automated gates — this file is where the little stuff lives so nothing is lost.

**How to use:**
- AI: append new items at every slice boundary (anything batchable the owner defers). Never delete an unchecked item; if code changes make an item obsolete, strike it through with a note.
- Owner: check items off whenever tested (any session); report failures as bugs.
- ✅ AUTO = an automated test/gate covers the mechanics; the human check is for look/feel only.

**Last Updated:** 2026-07-07 (session 6 — Slice 16 drag-rework + Eraser items; Slice 17 ready-up section added)

---

## ⚠️ Deferred blocking check — Slice 7 force-continue (owner deferred 2026-07-07, "test at the end with the batchable stuff")

- [ ] **Slice 7 force-continue path:** player-created game where one player never submits → host's Force continue button unlocks after the 2:00 countdown → confirm dialog → game starts and all rounds proceed with **no visible indication** of which prompts were backfilled ✅ AUTO (end-to-end test pins exact broadcast keys + 14-round completion; the human check is the flow feel + invisibility on real screens)

## Session-5 fix re-checks — CLEARED (owner, 2026-07-07)

Two owner-directed fix batches this session (decision log 2026-07-06 "Judging = latched click-to-pick" and 2026-07-07 "Kudos rematch-staleness fix…"); all machine-verified (296/296 tests + `verify_round.sh` PASS) and owner-confirmed 2026-07-07, one deferral noted below. **No blocking checks remain — Slice 7 is clear to start.**

- [x] **Kudos after rematch (BUG FIX)** — PASS
- [x] **Pause freezes timers (BUG FIX)** — PASS
- [x] **Judging click-to-pick** — PASS
- [x] **Chat beside canvas while drawing (expanded default, button toggle)** — PASS
- [x] **Prominent chat sizing (judge wait + reveals)** — PASS
- [x] **Grid social row alignment** — PASS
- [x] **Victory-lap replay (carried from session 4)** — PASS (all strokes + still hold confirmed)
- [x] ~~**Caption entry box still visible on the owner's machine**~~ — RESOLVED 2026-07-07 (Slice 16): the `comments_enabled` field no longer exists, so the stale profile key is ignored on restore; the caption UI itself is deleted. No workaround needed.

### Session-4 deferred blocking checks — RESULTS (owner, 2026-07-06 session 5)

- [x] **Slice 6 preset lock behavior** — PASS
- [x] **Slice 6 client read-only sync** — PASS (host settings mirror to clients)
- [x] **Slice 6 Esc menu + pause** — PASS
- [x] **Slice 4 kudos end-to-end (human)** — PASS ("kudos points do seem to work")
- [x] **Slice 4 reaction round-trip (human)** — PASS
- [ ] ~~**Slice 5 re-check after owner-directed fixes**~~ — SUPERSEDED: emoji legibility ok but grid alignment failed → fixed again this session (see re-check list above); victory-lap replay still unverified (carried above)

## Confirmed core flows (for context — not backlog)

- Slice 0: two-instance connect gate, all 4 steps (owner, session 2)
- Slice 1: drawing feel + palette redesign (owner, session 2 — "works really good")
- Slices 2+3 (owner, session 3): host/join by code works; wrong code fails back to menu correctly; full 3-player game start → draw → reveal → judging window + winner selection → scoring "seemed to work" → standings; overall playthrough clean

---

## Slice 1 — Drawing Canvas & Stroke Engine

- [ ] Letterboxing holds at odd window sizes (canvas keeps aspect, no distortion)
- [ ] Portrait-mode layout: toolbar/canvas arrangement still sensible
- [ ] Rotate-confirm dialog wording reads clearly
- [ ] Undo disabled-state timing (greys exactly when nothing to undo, incl. after clear/rotate)

## Slice 2 — Lobby & Session Roster

- [ ] Roster leave/rejoin propagation: a leaver vanishes from every window, rejoiner reappears ✅ AUTO (roster sync)
- [ ] Start gate flicker: disabled at 2 ("Need 1 more player"), enables at exactly 3, re-disables if someone leaves before the click ✅ AUTO (gate logic)
- [ ] Chat: names correct on all peers; blocklisted word arrives censored as `***` everywhere ✅ AUTO
- [ ] Chat rate limit: 6 rapid messages → 6th silently absent on all peers ✅ AUTO (limiter logic)
- [ ] Live settings sync: host edits appear on clients read-only; "(suggested)" rounds tag updates as players join and disappears once the host touches the spinner
- [ ] Host-quit from lobby: clients land on menu with "Host left the game." toast, no console error spam
- [ ] Lobby full: 9th join attempt rejected with "Lobby is full" toast (impractical by hand — 9 instances; ✅ AUTO for the reject logic; verify the toast whenever convenient)
- [ ] Lobby layout holds at 1280×720 and under window resize
- [ ] Join dialog: code uppercased/trimmed; Enter submits; empty code ignored ✅ AUTO

## Slice 3 — Core Round Loop

- [ ] Judge no-pick: let the 30 s window lapse → "The judge couldn't decide… (Judge −1)"; negative score renders correctly in resolution AND standings ✅ AUTO (scoring + display values)
- [ ] Judge heckling view details: prompt huge, chat prominent with auto-focused input, heckles arrive in drawers' collapsed side column ~~strip expands on hover~~ (hover-expand removed 2026-07-06 — explicit 💬 toggle + unread badge instead; see decision log)
- [ ] Blank submission (drawer never draws/disconnects): blank card appears in grid, is pickable, looks intentional not broken ✅ AUTO (mechanics)
- [ ] Early-submit then keep drawing: the final canvas at deadline is what appears at reveal ✅ AUTO (latest-wins)
- [ ] All drawers submit early → drawing phase ends early on every peer ✅ AUTO
- [ ] Countdown sanity: no negative/frozen timers on any peer; urgency color+number under 10 s
- [ ] Portrait-orientation drawing keeps its orientation in the reveal grid and resolution views ✅ AUTO (smoke test)
- [ ] Reveal grid layout at various entry counts (2–7 drawings) and window sizes
- [ ] Back to lobby → rematch: roster/settings intact, second game runs clean (return path itself confirmed? owner ended session at standings — verify full rematch)
- [ ] Chat prominence transitions between phases feel right (collapsed → prominent → normal)
- [ ] Host-quit mid-game: clients toast and return to menu cleanly (no migration in v1 — expected behavior)

## Slice 4 — Reactions, Kudos & Saving

- [ ] Emoji bar feel/legibility at high grid density (7 drawings = 8 players; smallest cells) ✅ AUTO (mechanics)
- [ ] Wallet pips readable; pending "…" state visible on slow networks; "Saved to your collection!" toast wording feels right
- [ ] Self-save toggle: draw with toggle ON → after the round, `user://collection/` has the drawing (source "self") ✅ AUTO (unit-tested) — human check is the toggle UX itself
- [ ] "🔒 yours" hint appears ONLY on your own cell, on your machine (anonymity: confirm other players never see it) ✅ AUTO by design (local-only knowledge)
- [ ] Kudos button correctly disabled: own drawing / wallet empty / already given ✅ AUTO (validators) — human check is that the disabled states read clearly
- [ ] Rapid reaction spam feels OK (150 ms debounce; host drops no-ops) ✅ AUTO (cap + no-op logic)
- [ ] Reaction count badges update within ~1 s on all peers ✅ AUTO (CI verifies convergence) — human check is perceived latency
- [ ] Emoji glyphs render on Windows/Linux exports (dev machine is macOS; font fallback differs)
- [ ] Score at RESOLUTION visibly includes kudos +1 (winner who also got kudos shows +3 total) ✅ AUTO (scoring)
- [ ] Judge can react AND kudos while deciding (by design §11) — feels right, not distracting
- [ ] Grid cell layout with the new social row at 2–7 drawings and window resizes (cells grew 60 px taller)

## Slice 5 — Reveal Styles & Replay

- [ ] One-at-a-time beat rhythm feels theatrical but not draggy (3 s hold per card; tune constants if needed) ✅ AUTO (schedule mechanics)
- [ ] Beat motion polish: card-in/to-grid are fades in v1 — real slide/shrink choreography + "grid strip" preview of settled cards deferred by design
- [ ] Stage overlay sizing at large windows (card caps at 520×390) and with portrait drawings (letterboxing)
- [ ] ~~Caption entry ergonomics: chip → field expansion, Enter returns focus to canvas, 80-char counter~~ (OBSOLETE 2026-07-07: captions removed by Slice 16 — text lives in the drawing now)
- [ ] ~~Caption presentation: under staged card, truncated line + tooltip on grid cells, attributed in winner spotlight; blocklisted word arrives censored~~ (OBSOLETE 2026-07-07: same — see Slice 16 section below)
- [ ] Victory lap: winner replay speed feels right (default 3×, 10 s cap); author reveal moment lands ✅ AUTO (cap math)
- [ ] Full reveal replay (replay_mode FULL) — batch with Slice 6 Social preset testing (not reachable via UI until the settings surface lands)
- [ ] GRID style still snappy: single 0.25 s fade, straight to judging ✅ AUTO
- [ ] Reaction/kudos on the staged card during its beat; racing the beat boundary still lands (250 ms grace) ✅ AUTO (gate logic + CI)
- [ ] Slow-client hard-snap: hitch a client mid-beat → it snaps to the next beat cleanly (hard to reproduce by hand)
- [ ] Save-toggle now visible on the round canvas (Slice 4 fix) — placement/wording feels right

## Slice 6 — Game Modes & Settings (+ Esc menu / pause)

- [ ] Preset value tuning pass: play Streamlined and Social end-to-end; adjust the v1 constants (they're deliberately code constants — identity tests pin only what each mode means)
- [ ] Custom panel layout/legibility at 1280×720; summary chip wording reads clearly ✅ AUTO (render logic)
- [ ] Suggested-rounds hint "(suggested: N)" recomputes as players join/leave; a host override survives roster changes ✅ AUTO (logic)
- [ ] Combo graying feels right: GRID/OFF gray the replay-duration steppers
- [ ] Kudos "Auto = N for R rounds" hint updates live as rounds change ✅ AUTO
- [ ] Host convenience: settings restored when re-hosting (rounds re-seed by design); corrupt profile falls back silently ✅ AUTO (restore logic)
- [ ] Esc menu feel: open/close, two-click leave confirm wording
- [ ] Pause during DRAWING: canvas strokes survive resume; countdown resumes with remaining time ✅ AUTO (refresh-in-place logic)
- [ ] Pause during REVEAL beats: overlay on, beats resume where they left off (cosmetic tween may settle under the overlay — known v1 limitation)
- [ ] ~~PhaseTimer shows a stale countdown while paused (corrects on resume) — acceptable? (known v1 limitation)~~ RESOLVED 2026-07-07: owner ruled not acceptable; timers now freeze on pause (decision log) — re-check in the blocking list above
- [ ] Client sees "Host paused the game" and cannot dismiss it; host sees Resume game ✅ AUTO (menu state logic)

## Slice 7 — Player-Created Prompt Pools

- [ ] Blocked-word inline error reads clearly and doesn't lose the other typed words in the column
- [ ] Progress panel updates live as other players submit; finished players get a ✓ ✅ AUTO (progress payload + panel render logic)
- [ ] Non-divisible share case: 4 players / 14 rounds asks for 4 words per pool and the game still ends after exactly 14 rounds ✅ AUTO (e2e integration)
- [ ] Host force-continue countdown next to the button reads clearly; button enables exactly at unlock ✅ AUTO (time gate)
- [ ] Pool-setup screen layout holds at 1280×720 and under window resize (2 columns of 4+ word rows)
- [ ] Duplicate words across players accepted silently (two "sleepy"s is normal party behavior) ✅ AUTO
- [ ] `POOL_SETUP_FORCE_AVAILABLE_SEC` = 120 s untuned — shorten if the wait drags in real groups (log a decision if changed)
- [ ] Known v1: host pause is a no-op during POOL_SETUP (phase has no clock to freeze; Esc menu still opens for Leave) — acceptable? Revisit with Slice 9's below-minimum pause

## Slice 8 — Collection Browser & Export

*Owner-confirmed 2026-07-07: the blocking export check (PNG opens externally, correct dimensions, in-game look — "works great") and Share's reveal-in-Finder. Everything below is untested:*

- [ ] Viewer replay: pacing feels right at 1× and 2×; Skip works mid-replay; still returns cleanly after the replay ends ✅ AUTO (play/skip/finish state logic)
- [ ] Delete flow: confirm wording reads well; card removal isn't jarring; count label updates ✅ AUTO (index-first delete + grid update logic)
- [ ] Portrait drawings: correct aspect on cards AND in the viewer (letterboxed, never stretched)
- [ ] Empty state: wording reads well and points at the right in-game actions (needs a fresh/emptied collection to see)
- [ ] Grid scroll with many items (~100+): smooth, thumbs stream in without hitching ✅ AUTO for the pump budget (2/frame); the feel is the human check
- [ ] Thumbs self-heal: delete `user://collection/thumbs/` while the game is closed → browsing regenerates them over a few seconds ✅ AUTO (regeneration logic)
- [ ] Missing-doc husk: delete a `<uuid>.json` by hand → card shows "(missing drawing)", viewer offers Delete only, deleting purges the entry cleanly ✅ AUTO (degrade logic)
- [ ] Exported PNG survives a platform re-compress (drag into Discord — crisp edges hold)
- [ ] Polish note (owner, 2026-07-07): Share = Export + reveal feels duplicative — "fine for now"; differentiate post-v1 (clipboard copy / native share sheet candidates)

## Slice 16 (mini) — In-Image Text Tool (+ 2026-07-07 drag-to-place rework + Eraser)

*First-build blocking checks CONFIRMED (owner, 2026-07-07): font legibility in the sandbox; in-round text flow. The drag rework + eraser re-check is in the owner checklist — not here. Batchable leftovers:*

- [ ] ~~Entry box ergonomics near canvas edges / window resize~~ (OBSOLETE same day: floating box replaced by the toolbar Text row + drag chip)
- [ ] ~~Click-elsewhere-commits flow under time pressure~~ (OBSOLETE same day: drag-to-place rework)
- [ ] Unsupported characters (é, emoji, tabs) typed into the box are silently absent from the chip — clear enough, or does it need a hint? ✅ AUTO (filter logic)
- [ ] Blocked word censors to *** live in the chip as you type — feels fair, not naggy? ✅ AUTO (censor logic)
- [ ] Text at all 3 sizes over dark fills: palette color choice makes text readable (no outline in v1 — is one needed?)
- [ ] Drag chip legibility at small sizes (chip caps at 28 px tall / 320 wide); drag preview scale matches the landing size at odd window sizes
- [ ] Repeat-stamp flow (text stays in the box after a drop) — handy or surprising? Input's ⊗ clears it
- [ ] Eraser feel: sizes S/M/L adequate? Erasing over fills leaves crisp edges (exact-match rule) ✅ AUTO (mechanics)
- [ ] Replays show erasing as white strokes (by design — part of the show): reads fine, not confusing?
- [ ] Text pops in as a beat during replays (like fills) — reads fine at high speed-ups? ✅ AUTO (schedule math)
- [ ] Grid cells: the social row's center slot is now an empty spacer (was captions) — alignment still holds at 2–7 drawings
- [ ] Exported PNG with text: crisp at 2× nearest-neighbor (should be by construction) ✅ AUTO (export path unchanged)

## Slice 17 (mini) — Ready-Up

*Blocking checks (Done/Unready flow; chat-header ready strip; both early advances) are in the owner checklist — not here. Batchable leftovers:*

- [ ] Ready panel (left of canvas) at 1280×720 and window resizes; name truncation on long names
- [ ] Initials-chip colors readable/distinct for similar names (placeholder until Slice 11 avatars)
- [ ] Chat-header strip fit with 8 players (chips may crowd the header at min width)
- [ ] "Waiting for the others..." vs "Sent! Keep tweaking..." status wording reads right
- [ ] Pause → resume clears everyone's ready (by design; re-press Done) — acceptable? ✅ AUTO (reset logic)
- [ ] Judge's Ready button disabled-until-pick: is the why obvious? (tooltip says "Pick a winner first")
- [ ] Leaver while everyone else is ready: phase advances on the next ready toggle or deadline (not instantly on the leave) — acceptable until Slice 9? ✅ AUTO (connected-only set)
- [ ] Judge-wait screen (judge's DRAWING view) has no ready panel — would the judge want to see drawers' progress there? (design nicety, not a bug)

## Design gaps / open items (not bugs — need decisions)

- [ ] **No in-game pause/leave menu** (owner, 2026-07-06): once a game starts there is no way to reach settings or exit to the main menu except closing the window. Not covered by any planned slice — candidate homes: Slice 6 (settings surface) or Slice 9 (resilience; voluntary-leave flows). Tracked in WHERE_WE_ARE Active Decisions.

---

*Add new sections per slice as they land. Full sweep scheduled after Slice 15 (release prep) — before the release-candidate playtest pass.*
