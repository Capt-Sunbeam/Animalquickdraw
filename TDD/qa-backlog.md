# QA Backlog — "Bug Hunt" List

**Purpose:** Running list of every fine-grain check, edge case, and polish item the owner has NOT yet human-tested. Per the owner's QA process (decision log 2026-07-06): between-session playtests cover **broad strokes and core functions only**; everything detailed accumulates here and gets a full pass **after the game is content-complete**. Slices are signed off on core flows + green automated gates — this file is where the little stuff lives so nothing is lost.

**How to use:**
- AI: append new items at every slice boundary (anything batchable the owner defers). Never delete an unchecked item; if code changes make an item obsolete, strike it through with a note.
- Owner: check items off whenever tested (any session); report failures as bugs.
- ✅ AUTO = an automated test/gate covers the mechanics; the human check is for look/feel only.

**Last Updated:** 2026-07-06 (session 3)

---

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

## Design gaps / open items (not bugs — need decisions)

- [ ] **No in-game pause/leave menu** (owner, 2026-07-06): once a game starts there is no way to reach settings or exit to the main menu except closing the window. Not covered by any planned slice — candidate homes: Slice 6 (settings surface) or Slice 9 (resilience; voluntary-leave flows). Tracked in WHERE_WE_ARE Active Decisions.

---

*Add new sections per slice as they land. Full sweep scheduled after Slice 15 (release prep) — before the release-candidate playtest pass.*
