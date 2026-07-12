# QA Backlog — "Bug Hunt" List

**Purpose:** Running list of every fine-grain check, edge case, and polish item the owner has NOT yet human-tested. Per the owner's QA process (decision log 2026-07-06): between-session playtests cover **broad strokes and core functions only**; everything detailed accumulates here and gets a full pass **after the game is content-complete**. Slices are signed off on core flows + green automated gates — this file is where the little stuff lives so nothing is lost.

**How to use:**
- AI: append new items at every slice boundary (anything batchable the owner defers). Never delete an unchecked item; if code changes make an item obsolete, strike it through with a note.
- Owner: check items off whenever tested (any session); report failures as bugs.
- ✅ AUTO = an automated test/gate covers the mechanics; the human check is for look/feel only.

**Last Updated:** 2026-07-11 (session 10 — Slice 12 Steam section added, incl. the owner-earmarked real-App-ID pass)

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

- [ ] ~~Emoji bar feel/legibility at high grid density~~ (OBSOLETE 2026-07-12: emoji reaction system removed by Slice 19)
- [ ] Wallet pips readable; pending "…" state visible on slow networks; "Saved to your collection!" toast wording feels right
- [ ] Self-save toggle: draw with toggle ON → after the round, `user://collection/` has the drawing (source "self") ✅ AUTO (unit-tested) — human check is the toggle UX itself
- [ ] "🔒 yours" hint appears ONLY on your own cell, on your machine (anonymity: confirm other players never see it) ✅ AUTO by design (local-only knowledge)
- [ ] Kudos button correctly disabled: own drawing / wallet empty / already given ✅ AUTO (validators) — human check is that the disabled states read clearly
- [ ] ~~Rapid reaction spam feels OK~~ (OBSOLETE 2026-07-12: Slice 19)
- [ ] ~~Reaction count badges update within ~1 s~~ (OBSOLETE 2026-07-12: Slice 19)
- [ ] Emoji glyphs still in use (🔒 yours, 🏅 badges, chat text) render on Windows/Linux exports (dev machine is macOS; font fallback differs)
- [ ] Score at RESOLUTION visibly includes kudos +1 (winner who also got kudos shows +3 total) ✅ AUTO (scoring)
- [ ] Judge can kudos while deciding (by design §11) — feels right, not distracting
- [ ] Grid cell layout at 2–7 drawings and window resizes (Slice 19: reaction row removed — the drawing got the freed height; re-look at density)

## Slice 5 — Reveal Styles & Replay

- [ ] One-at-a-time beat rhythm feels theatrical but not draggy (3 s hold per card; tune constants if needed) ✅ AUTO (schedule mechanics)
- [ ] Beat motion polish: card-in/to-grid are fades in v1 — real slide/shrink choreography + "grid strip" preview of settled cards deferred by design
- [ ] Stage overlay sizing at large windows (card caps at 520×390) and with portrait drawings (letterboxing)
- [ ] ~~Caption entry ergonomics: chip → field expansion, Enter returns focus to canvas, 80-char counter~~ (OBSOLETE 2026-07-07: captions removed by Slice 16 — text lives in the drawing now)
- [ ] ~~Caption presentation: under staged card, truncated line + tooltip on grid cells, attributed in winner spotlight; blocklisted word arrives censored~~ (OBSOLETE 2026-07-07: same — see Slice 16 section below)
- [ ] Victory lap: winner replay speed feels right (default 3×, 10 s cap); author reveal moment lands ✅ AUTO (cap math)
- [ ] Full reveal replay (replay_mode FULL) — batch with Slice 6 Social preset testing (not reachable via UI until the settings surface lands)
- [ ] GRID style still snappy: single 0.25 s fade, straight to judging ✅ AUTO
- [ ] Kudos on the staged card during its beat; racing the beat boundary still lands (250 ms grace) ✅ AUTO (gate logic + CI)
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

*ALL blocking checks CONFIRMED (owner, 2026-07-07): font legibility; in-round text flow; drag-to-place landing (after the `mouse_target` fix); single drag preview; eraser + footprint cursor. Chat side-column height: "acceptable, not perfect" — polish item below. Batchable leftovers:*

- [ ] Chat side-column height polish (owner: acceptable for now) — it aligns to the canvas row bottom via `chat_side_slot()`; explore exact canvas-frame alignment at odd aspect ratios

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

*Core flow OWNER-CONFIRMED 2026-07-07 ("Ready up is working great!"). Remaining detail checks batchable:*

- [ ] Ready panel (left of canvas) at 1280×720 and window resizes; name truncation on long names
- [ ] ~~Initials-chip colors readable/distinct for similar names (placeholder until Slice 11 avatars)~~ — OBSOLETE 2026-07-08: Slice 11 replaced the initials chips with real AvatarChips (see Slice 11 section)
- [ ] Chat-header strip fit with 8 players (chips may crowd the header at min width)
- [ ] "Waiting for the others..." vs "Sent! Keep tweaking..." status wording reads right
- [ ] Pause → resume clears everyone's ready (by design; re-press Done) — acceptable? ✅ AUTO (reset logic)
- [ ] Judge's Ready button disabled-until-pick: is the why obvious? (tooltip says "Pick a winner first")
- [x] ~~Leaver while everyone else is ready: phase advances on the next ready toggle or deadline (not instantly on the leave)~~ — RESOLVED by Slice 9 (2026-07-07): departures re-evaluate all-ready immediately (below-minimum pause wins when both apply); regression-tested
- [ ] Judge-wait screen (judge's DRAWING view) has no ready panel — would the judge want to see drawers' progress there? (design nicety, not a bug)

## Slice 9 — Connectivity & Resilience

*Machine coverage: 24-test resilience suite + `verify_resilience.sh` (drop → below-min pause → rejoin → resume → kept submission wins, per-role phase logs, wrap-up contract keys). Blocking owner checks listed in WHERE_WE_ARE. Batchables:*

- [ ] Toasts for join/drop/rejoin read correctly and don't stack absurdly (3 s same-message coalescing implemented — flapping check) ✅ AUTO (coalescing logic; human feel check remains)
- [ ] Judge drops during JUDGING: window completes, kudos still spendable, "couldn't decide" resolution shows; fluid ON → no −1 ✅ AUTO (penalty matrix + seat-hold tests; human look remains)
- [ ] `fluid_rejoin` OFF: quit as next-judge inside the 30 s window, stay away → round intro announces "dodged judging: −1", next player judges ✅ AUTO (forfeit tests; toast/intro copy human check)
- [ ] Host End-game-now → (placeholder until Slice 10) standings incl. the disconnected player's remembered score ✅ AUTO (contract keys; screen look human check)
- [ ] Late joiner can react/kudos during the round they joined into (spectator banner doesn't block the grid)
- [ ] Public checkbox flips the fluid-rejoin default; manual override sticks ✅ AUTO (settings tests; lobby UI feel check)
- [ ] Pause overlay: chat usable while frozen; Esc still opens the menu over it for Leave; overlay count updates on further drops
- [ ] Spectator banner copy ("You're in!…" / "You're back in!…") placement over each phase screen; judge-wait's "players are drawing…" text doubles as the spectator view — reads OK?
- [ ] Late joiner / rejoiner landing mid-POOL_SETUP: the submission screen shows columns a late joiner can never submit (host drops them silently) and a rejoiner's re-submits show "already submitted" — polish wanted?
- [ ] Rejoin mid-JUDGING: grid builds fully judgeable straight from the welcome snapshot (machine-verified state; human look check)
- [ ] Ready state lost across pause/resume now also applies to below-minimum pauses (re-press Done) — same accepted limitation as Slice 17

## Slice 10 — End-Game Wrap-Up

*Machine coverage: 18-test calculator suite (titles/stacking/tie-breaks/standings/determinism — reworked by Slice 19) + relay signal-order tests + scene smokes; `verify_round.sh` drives a full game into WRAP_UP on 3 peers. NOTE: the TDD's normally-blocking check (early-end wrap-up) is in the END-OF-SESSION batched list per owner instruction 2026-07-07 — test it first. Batchables:*

- [ ] Full wrap-up sequence feel after a kudos-heavy 3-player game: titles → standings pacing (5 s/0.8 s constants — tune if draggy; superlatives act removed by Slice 19) ✅ AUTO (mechanics)
- [ ] Skip isolation: skipping on one client does not affect the others ✅ AUTO by design (skip is purely local)
- [ ] Skip semantics feel: first press finishes the replay flourish, second advances — intuitive or annoying on static title cards (which advance on first press)?
- [ ] Negative score display in final standings (judge with only no-pick penalties) — true minus, podium still plays ✅ AUTO (render values)
- [ ] Title-point breakdown tooltip on standings scores (hover) — discoverable enough?
- [ ] ~~Superlative card replay flourish~~ (OBSOLETE 2026-07-12: superlatives removed by Slice 19)
- [ ] Title card evidence fan at 1–3 drawings incl. portrait orientation (letterboxed, not stretched)
- [ ] "(left early)" dimming on disconnected players' title cards + standings rows
- [ ] Progress dots + "That's a wrap!" header + rounds badge (incl. "ended early • N rounds" wording)
- [ ] Host quit mid-sequence on a client: sequence finishes, then Leave-only post-game (no toast currently — is one wanted?)
- [ ] `title_points_enabled` OFF (Custom): no "+1" chips anywhere, standings = base scores ✅ AUTO (points zeroed)
- [ ] Stat label wording pass: "done with N% of the clock to spare", "just N.N marks per drawing", "N kudos received, zero wins" — funny or confusing?
- [ ] Chat stays usable (NORMAL prominence) through the whole sequence

## Slice 11 — Avatars

*Machine coverage: resolver/store/circle-mask/validation suites + chip and editor scene tests; all three gates instantiate real chips. NOTE: the TDD's normally-blocking check (two-instance avatar sync) is in the END-OF-SESSION batched list per owner instruction 2026-07-07 — test it first. Batchables:*

- [ ] Drawing feel inside the circle: edge clamping doesn't fight the cursor when stroking across the rim
- [ ] Fill stays inside the circle, including fills seeded near the rim ✅ AUTO (mask goldens; the feel check remains)
- [ ] Name-circle legibility at 26/32/48/96 px; the two-character fallback below 48 px feels right
- [ ] House avatars look intentional; the same player gets the same doodle everywhere ✅ AUTO (deterministic pick; the look is the human check)
- [ ] Editor flows: load-existing (edit on top), unsaved-changes prompt on Back/Esc, Clear-avatar confirm, "Avatar saved" toast, "getting complex" toast near the op cap
- [ ] Editor layout at 1280×720: circular canvas letterboxing; transparent corners over the UI background read as "not canvas" (or does it want a dedicated circle backing?)
- [ ] Chips sit well at their sizes: lobby rows (48), ready panel + chat strip (26), wrap-up title card (96) + standings (48), menu button (32)
- [ ] **Anonymity check:** no avatar chips anywhere on reveal/judging drawing grids (hard rule, brief §4) ✅ AUTO by construction (surfaces untouched) — eyeball it anyway
- [ ] Disconnected players' chips dim correctly (lobby list rows dim whole-row; wrap-up title card dims chip + name)
- [ ] Text tool + eraser inside the avatar editor: sensible or clutter? (kept per "same tools" — cut if it reads as noise)
- [ ] Roster broadcast size with 8 avatar'd players (each ≤ ~10 KB typical) — any visible join/kudos lag on real networks?
- [ ] Rejoin/late-join avatar delivery: joiner sees existing faces, existing peers see the joiner's ✅ AUTO by design (roster snapshot path; human check on a real run)

## Slice 18 — Canvas Ergonomics & Display Scaling

*Machine coverage: zoom/pan math (clamp, zoom-at-cursor round-trip, fit-identity vs the Slice 1 map), hold-to-draw source rules incl. the `_process` fallback, minimap view-rect math, D-click end-to-end, toolbar zoom cluster signals; all three gates green. Core-confirmed 2026-07-10 (trackpad flow incl. minimap + D-click; no scaling issues reported). Batchables:*

- [ ] Mouse-path view controls feel: wheel pan speed/direction, Shift+wheel horizontal, Ctrl/Cmd+wheel zoom factor, middle-drag pan (constants are first guesses — tune freely)
- [ ] Trackpad two-finger pan speed (`CANVAS_GESTURE_PAN_FACTOR`) at 2×–8× zoom
- [ ] Zoom cluster: − / % / + stepping feels right; % label as reset-to-fit is discoverable (tooltip enough?)
- [ ] Minimap (rework): size/position/opacity of the inset; view-rect visibility over busy drawings; hold-D pan vs click-drag pan both feel right
- [ ] D-as-click (rework): palette swatches, size buttons, save toggle, zoom cluster, chat focus all respond to pointer+D; no surprise clicks on empty space
- [ ] Text-chip drag on a trackpad still requires real click-drag (accepted rework limitation) — painful enough to revisit?
- [ ] Hold-D + Fill: press stamps once at the pointer — repeat-press cadence acceptable?
- [ ] Hold-D in the avatar editor: rim clamping while key-drawing across the circle edge
- [ ] Zoomed drawing near canvas edges: strokes clamp to the edge exactly (no drift at 8×)
- [ ] Eraser footprint circle + text-chip drag preview sizes stay correct at every zoom level
- [ ] Sandbox replay while zoomed reads acceptably (accepted TDD limitation — confirm it's not confusing)
- [ ] Window at exactly 960×540: lobby, reveal grid, wrap-up all usable (min-size floor sanity)
- [ ] Extreme aspect ratios (ultrawide, tall/narrow): `expand` aspect keeps layouts sane
- [ ] High zoom linear filtering (soft pixels) — fine for now, or want nearest-neighbor above 1×? (art-pass question)

## Slice 12 — Steam Platform Integration

*Machine coverage: room-code/metadata/launch-args/backend-selection suites + coroutine-contract test + offline-menu and invite-button scene tests; all 3 ENet gates green; single-instance Steam smoke PASS (real client: init, lobby, metadata read-back, relay host peer). BLOCKING two-account checks listed in WHERE_WE_ARE — they gate Slices 13/14. Batchables:*

- [ ] Wrong/expired code → "Room ___ not found" toast within the 10 s timeout; join dialog stays open for retry ✅ AUTO (reason mapping; the feel check remains)
- [ ] Steam persona name appears in the roster (and censored if it trips the blocklist — try renaming your Steam account to a blocklisted word for one run) ✅ AUTO (censor path; the human check is the real persona flow)
- [ ] Invite button absent when running `--platform=enet` ✅ AUTO (scene test)
- [ ] Invite button → overlay friend picker opens; with the overlay disabled in Steam settings, the room code beside it is the fallback — wording clear enough?
- [ ] Host quits → second account gets the host-quit toast; no zombie lobby left (rejoin by the same code should fail "not found")
- [ ] Lobby metadata in a Steamworks debug dump matches the schema table (spot-check for Slice 13) ✅ AUTO (smoke verified write+read-back; eyeball once anyway)
- [ ] Invite accepted while in another game → "Leave & join" confirm; declining leaves the current game untouched
- [ ] Steam-quit boot: offline dialog once, Host/Join disabled with tooltip, collection + avatar editor fully usable
- [ ] **Real App ID pass (owner-earmarked 2026-07-11, runs with Slice 15):** register the App ID, then the §9 swap procedure (APP_ID constant, delete `steam_appid.txt` from the shipped depot, Steamworks build config) and re-verify under the real ID: overlay shows "Animal Quickdraw", invites, **cold-launch "Join Game" with the game closed launches OUR exe** (unverifiable under Spacewar — Steam would launch Valve's app; until then simulate with manual `+connect_lobby <id>`), store-visible lobby names

## Slice 13 — Public Lobbies & Moderation

*Machine coverage: blocklist/kick/handshake suites (incl. blocklist-beats-rejoin + honest-reason ordering), strict listing parse (drops malformed/forged/version-mismatch/private/ingame + local re-censor), notice gate persistence + version-bump re-prompt, browser screen over a stubbed backend (rows, empty/failed states, both filters, full-row Join disabled, notice gating), chat control-char spoof fix pinned, menu gating on ENet; all 3 gates green. **Kick end-to-end OWNER-CONFIRMED 2026-07-11** (session 11, 3-instance ENet: lobby kick, rejoin denial, in-game Esc-menu kick). Remaining BLOCKING check in WHERE_WE_ARE: browser two-account pair. Batchables:*

- [ ] Notice shows exactly once: first public Join prompts, second doesn't; fresh `user://` (or bumped `PUBLIC_NOTICE_VERSION`) re-prompts once ✅ AUTO (gate logic; the feel check remains)
- [ ] Filters + refresh: mode filter, has-space filter, 2 s refresh cooldown feel right; full lobbies show greyed Join
- [ ] Browser row layout at 960×540 (name truncation, column widths with 8/8 + long host names)
- [ ] Kick confirm dialog wording in lobby; Esc-menu two-click kick ("Sure? (pauses game)" when dropping below 3) discoverable enough?
- [ ] Kicked player's blocking dialog on the menu reads right; remaining players' "was kicked" toast distinct from the disconnect toast
- [ ] Kick during the target's judge turn: round continues via the judge-drop path (machine-covered; eyeball once)
- [x] ~~Kick below 3 players mid-game: below-minimum pause + "waiting for players" overlay behaves~~ — covered by the owner's 2026-07-11 in-game kick run (3-player game)
- [ ] 18+ banner wording/placement on the browser (placeholder text - final wording is Slice 15's legal pass with the `PUBLIC_NOTICE_VERSION` bump)
- [ ] Public toggle tooltips in the lobby settings read clearly (private default)
- [ ] Try a blocklisted word as a Steam persona name hosting a public lobby: browser row shows it censored (double-censor path)

## Slice 19 — Title & Ceremony Rework + Emoji Retirement (added 2026-07-12)

*Machine coverage: reworked 18-test calculator suite (stacking, kudos-based People's Champion, titles_enabled gating), 7-test ceremony-vote suite (strict majority, dedupe, departure recount, phase guard), Slice 19 settings tests (round-trip, preset lock, Streamlined identity), updated UI smokes; all 3 gates PASS with the kudos-only CI driver (every peer's kudos-save now verified). Batchables:*

- [ ] Ceremony skip vote feel on 3+ instances: button label progress `(1/2)`, voter jumps immediately, majority jumps everyone; a mid-ceremony leaver tips a pending vote
- [ ] Standings badge line legibility: stacked titles (2–3 badges on one player), long title names at 960×540, "🏅 A · B" separator readability
- [ ] Streamlined preset: badges-only wrap-up pacing feels right (straight to standings)
- [ ] Custom panel: End-game titles / Awards ceremony / Title points rows — ceremony+points grey out when titles are off (honest-disable), wording clear
- [ ] Judging grid after the reaction-row removal: drawings visibly larger; density at 5–7 entries re-eyeballed (owner's grid concern — partially relieved, full layout rework still a candidate for polish)
- [ ] Titles-off game end-to-end: wrap-up goes straight to plain standings, nothing references titles anywhere

## Slice 14 — Achievements & Stats (added 2026-07-12)

*Machine coverage: 26 tests across two suites — frozen 27-id table pin, per-def threshold sweep (counter + title + collector), accumulation from all five EventBus signals, clean-sweep transients, persistence rules (corrupt/version/unknown-keys), 3-layer unlock idempotency, recording-mock Steam reconcile (one setAchievement per id ever, one storeStats per batch), ENet no-op path. Stats are SANDBOXED in every harness/gate run (GdUnit self-sandbox + per-PID CI driver paths) — gate runs never bump the owner's real stats.json.*

- [ ] **BLOCKING (deferred to the Slice 15 App-ID swap):** live Steam unlock toast — Spacewar (App 480) cannot carry our custom achievement API names, so the toast check runs with the real App ID registration, alongside the earmarked Slice 12 re-verification pass
- [ ] Offline ENet accrual: play a full dev game → inspect `user://stats.json` counters (games/rounds/wins/titles/kudos/saves)
- [ ] Delete `stats.json` → relaunch with Steam: no crash, no revocation, met-condition achievements re-set harmlessly
- [ ] Full House + Clean Sweep sanity when a real 8-player game / a 3-round sweep happens (fold into any big playtest)
- [ ] Achievement display names + descriptions final pass on the Steamworks partner site (Slice 15 owner task: create all 27 with the exact ids from `achievement_defs.gd`)

## Design gaps / open items (not bugs — need decisions)

- [x] ~~**No in-game pause/leave menu** (owner, 2026-07-06)~~ — RESOLVED: Slice 6 shipped the Esc menu (Resume/Leave + host pause); Slice 9 upgraded leave semantics (graceful leave = disconnect with rejoin memory, below-minimum pause, host End-game-now)

---

*Add new sections per slice as they land. Full sweep scheduled after Slice 15 (release prep) — before the release-candidate playtest pass.*
