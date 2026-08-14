# Friend Test Protocol — Slice 12 + 13 Two-Account Checks

**Created:** 2026-08-13 (session 18, alongside the signed friend builds in `builds/`).
**Purpose:** The scripted ~40-minute session with ONE friend (second Steam account) that clears
the last blocking checks for Slice 12 (TDD §7) and Slice 13 (browser pair). Everything runs
under Spacewar (App 480) — the overlay saying "Spacewar" is expected. When all boxes are
checked, both slices move to **Completed** (append completion status to both TDDs, update
WHERE_WE_ARE; impl notes already exist).

**Setup**
- Friend: `ScribbleSafari-Windows.zip` or the notarized `ScribbleSafari-macOS.zip` from `builds/`
  (readme inside each). Steam OPEN + signed in on both sides, different accounts.
- Owner runs the same exported build (or `godot --path . -- --platform=steam` with Steam open).
- Keep voice/text chat open; note anything odd in the moment — feel notes count.

## Part 1 — Slice 12 blocking (transport)

- [ ] **1. Join by code + full round over the relay:** Owner hosts → reads the 5-char code
      aloud → friend joins by code → play one full round (draw → reveal → judging → scoring).
      Watch for: roster shows both Steam persona names; no stalls at phase changes.
- [ ] **2. Invite while running:** Return to lobby (don't quit) → owner hits Invite → Steam
      overlay friend picker → friend accepts the invite toast → lands back in the lobby.
      (Friend should leave the lobby first so there's something to rejoin.)
- [ ] **3. Cold-launch join (Spacewar-limited simulation):** Friend quits the game fully.
      Owner stays hosting and grabs the lobby id — it prints in the host's log/console on
      lobby create. Friend relaunches the exe/app from a terminal with
      `+connect_lobby <lobby id>` as launch args → should land straight in the lobby.
      *Real "Join Game from friends list with game closed" is unverifiable under Spacewar
      (Steam would launch Valve's app) — this simulation is the earmarked stand-in; the real
      check reruns after the App ID swap (qa-backlog Slice 12).*
- [ ] **4. Offline mode:** Owner quits Steam entirely → launch the game → offline dialog
      appears once, Host/Join disabled with tooltip, Collection and avatar editor still work.
      (Restart Steam afterward.)

## Part 2 — Slice 13 blocking (public browser pair)

- [ ] **5. Public listing:** Owner hosts, checks **Public** → friend opens the public browser →
      row appears with correct mode / seats / rounds / draw-time / pool facts.
- [ ] **6. 18+ notice, exactly once:** Friend's FIRST public Join prompts the 18+/unmoderated
      notice → accept → joins. Leave, join a public lobby again → no second prompt.
- [ ] **7. Private flip:** Friend leaves; owner unchecks Public → row disappears from the
      friend's browser (refresh) → friend joins by the 5-char code anyway → works.

## Part 3 — batchables to fold in if time allows (qa-backlog)

- [ ] Wrong/expired code → "Room ___ not found" toast, dialog stays open for retry
- [ ] Host quits mid-lobby → friend gets the host-quit toast, lands on menu clean
- [ ] Invite accepted while friend is in another game → "Leave & join" confirm
- [ ] Slice 7 force-continue (deferred blocking): player-created pools game, friend never
      submits → Force continue unlocks after 2:00 → game proceeds, backfill invisible
- [ ] Slice 10: host End-game-now mid-game → wrap-up runs on partial data

## Bug capture

Anything broken: note the step number + what you both saw (screenshots welcome). Logs land in
`user://logs/` (macOS: `~/Library/Application Support/Godot/app_userdata/Scribble Safari/logs/`,
Windows: `%APPDATA%\Godot\app_userdata\Scribble Safari\logs\`) — grab both sides' latest file.
