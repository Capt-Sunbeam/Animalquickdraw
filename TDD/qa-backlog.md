# QA Backlog — "Bug Hunt" List

**Purpose:** Running list of every fine-grain check, edge case, and polish item the owner has NOT yet human-tested. Per the owner's QA process (decision log 2026-07-06): between-session playtests cover **broad strokes and core functions only**; everything detailed accumulates here and gets a full pass **after the game is content-complete**. Slices are signed off on core flows + green automated gates — this file is where the little stuff lives so nothing is lost.

**How to use:**
- AI: append new items at every slice boundary (anything batchable the owner defers). Never delete an unchecked item; if code changes make an item obsolete, strike it through with a note.
- Owner: check items off whenever tested (any session); report failures as bugs.
- ✅ AUTO = an automated test/gate covers the mechanics; the human check is for look/feel only.

**Last Updated:** 2026-07-06 (session 4 — Slice 4 + 5 + 6 items added)

---

## ⚠️ Deferred blocking checks — DO THESE FIRST next session (owner deferred at session-4 close)

These were each slice's *blocking* owner checkpoints; the mechanics are all machine-verified (unit tests + `verify_round.sh`), so what's deferred is the human look/feel/correctness confirmation. **Slice 7 builds on the Slice 6 settings surface — check those two before starting it.**

- [ ] **Slice 6 preset lock behavior:** on Streamlined only draw time/rounds/pool editable; Custom unlocks everything incl. title points; switching back re-locks ✅ AUTO (lock-rule tests)
- [ ] **Slice 6 client read-only sync:** second instance mirrors every host edit read-only, incl. a join-in-progress full sync ✅ AUTO (sync logic)
- [ ] **Slice 6 Esc menu + pause:** host pauses mid-drawing → clients locked on "Host paused"; resume keeps canvas strokes + remaining time ✅ AUTO (refresh-in-place logic)
- [ ] **Slice 4 kudos end-to-end (human):** give a kudos → wallet pip spends, toast, `user://collection/` gains index+doc+thumb, +1 visible at resolution ✅ AUTO (CI-verified incl. collection files)
- [ ] **Slice 4 reaction round-trip (human):** react/un-react propagates to all peers within ~1 s ✅ AUTO (CI-verified convergence)
- [ ] **Slice 5 re-check after owner-directed fixes:** emoji areas now roomy/legible; victory-lap replay plays ALL strokes then holds the still 2 s (owner saw the broken versions; the fixes are untested)

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
- [ ] Judge heckling view details: prompt huge, chat prominent with auto-focused input, heckles arrive in drawers' collapsed strip, strip expands on hover
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
- [ ] Caption entry ergonomics: chip → field expansion, Enter returns focus to canvas, 80-char counter
- [ ] Caption presentation: under staged card, truncated line + tooltip on grid cells, attributed in winner spotlight; blocklisted word arrives censored ✅ AUTO (validation)
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
- [ ] PhaseTimer shows a stale countdown while paused (corrects on resume) — acceptable? (known v1 limitation)
- [ ] Client sees "Host paused the game" and cannot dismiss it; host sees Resume game ✅ AUTO (menu state logic)

## Design gaps / open items (not bugs — need decisions)

- [ ] **No in-game pause/leave menu** (owner, 2026-07-06): once a game starts there is no way to reach settings or exit to the main menu except closing the window. Not covered by any planned slice — candidate homes: Slice 6 (settings surface) or Slice 9 (resilience; voluntary-leave flows). Tracked in WHERE_WE_ARE Active Decisions.

---

*Add new sections per slice as they land. Full sweep scheduled after Slice 15 (release prep) — before the release-candidate playtest pass.*
