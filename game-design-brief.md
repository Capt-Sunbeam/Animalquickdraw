# Drawing Party Game — Design Brief

*A pen-and-paper party game reimagined as an online multiplayer video game.*

---

## 1. Overview & North Star

This is a digital adaptation of a pen-and-paper party game. Each round, a **prompt** (typically an animal + an adjective, e.g. "sleepy aardvark") is drawn at random. One player is the **judge** for that round; everyone else races to draw the prompt on a small canvas in a short time window. Drawings are revealed anonymously, the crowd reacts and awards small tokens of appreciation, and the judge picks a favorite. The judge role rotates each round.

**North star:** the fun is *social and comedic*, not artistic. Every design decision should serve fast, silly, laughing-with-friends play. When a choice is ambiguous, favor the option that produces more laughter and keeps the game moving over the one that adds polish, fairness, or fidelity.

A key piece of the game's spirit is the **judge heckling the drawers in real time.** While players draw, the judge sees the prompt and has a prominent chat, and is encouraged to taunt and nudge ("I'm looking for the *sleepiest* of boys…") so drawers scramble to adjust. This emergent behavior from the tabletop version should be actively preserved, not treated as incidental.

---

## 2. Platforms & Distribution

- **Storefront:** Steam.
- **Operating systems:** Windows, macOS, and Linux, all first-class and smooth. A single codebase should target all three (no separate per-OS codebases).
- **Steam integration:** invite-to-game and join-game via Steam; Steam achievements; Steam username used as an avatar fallback (see §11). Networking should use Steam's relay networking so player IPs stay hidden (see §13).

---

## 3. Player Model

- **Players per game:** minimum **3**, hard maximum **8**. No opt-in beyond 8 in v1 (judging scales poorly past that; the fun-per-minute drops).
- **Minimum to start:** 3.
- **Minimum to continue:** 3. If the roster drops below 3 mid-game, the game **pauses** (see §9).
- **Roles per round:** exactly one **judge**; all other connected players are **drawers**.

---

## 4. Round Flow (State Machine)

A game consists of a **pre-game setup**, then a fixed number of **rounds**, then an **end-game wrap-up**.

### Pre-game setup
1. Lobby forms (via room code, Steam invite, or public browser — see §12).
2. Host sets mode and any adjustable settings (see §10).
3. Prompt pool is established:
   - **Built-in mode:** the game's preset pools are used; no player input needed.
   - **Player-created mode:** every player submits an equal share of words to each pool before play begins (see §8).
4. Judge rotation order is fixed.

### Each round
1. **Judge designated** (next in rotation order).
2. **Prompt drawn** from the pools and shown to all drawers. The judge also sees the prompt.
3. **Drawing phase:** the draw timer runs. Drawers draw on their canvases. The judge waits (does *not* watch live strokes) but sees the prompt prominently and has a prominent chat for heckling.
4. **Submission:** when the timer ends, whatever is on each canvas is auto-submitted. (A drawer who ticked "save to my collection" gets the final submitted version saved — see §6.)
5. **Reveal:** drawings are shown anonymously, either **one-at-a-time** then gathered into a grid, or **straight to a grid**, depending on mode/setting (see §7).
6. **Reaction / kudos / judging window:** a timed window during which drawers react with emojis and spend kudos, and the judge picks a winner. The judge may pick at any point during this window.
7. **Resolution:** at window's end, the winner is revealed with a larger, prominent view (optionally replaying its strokes, per setting). Points are tallied and shown.
8. **Advance** to the next judge and repeat until the final round.

### End-game
- The **wrap-up sequence** plays (see §10, §11).

---

## 5. What Each Role Sees, By Phase

- **Drawing phase — drawer:** their own canvas and tools, the prompt, the draw timer, a collapsible chat (small/out of the way during drawing).
- **Drawing phase — judge:** the current prompt shown clearly, a "players are drawing…" state, and a **prominent** chat for heckling. No live view of anyone's strokes.
- **Reveal — everyone:** anonymized drawings, per the reveal style in effect. In one-at-a-time reveal, each drawing gets a short individual reveal-and-react moment (optionally animating its strokes) before all drawings settle into a grid.
- **Reaction/judging window — everyone:** the full grid of drawings; reaction emojis and kudos available; the judge additionally has the winner-pick control. Chat is more prominent during reveal/judging so people can riff.

Canvas orientation (landscape or portrait, see §7) is preserved in all reveal and judging views.

---

## 6. Canvas & Drawing Tools

Deliberately **middle-ground** tooling: powerful enough to draw fast, simple enough for non-artists, nothing that slows people down.

**Tools:**
- Brush with **three sizes**.
- **Bucket fill.**
- **Undo.**
- **Erase / clear.**
- **Rotate** the canvas between landscape (default) and portrait; the chosen orientation is preserved through reveal and judging.

**Color:** a fixed palette of ~10–12 base colors. An **expand/drill-down** option reveals additional preset shades within a color family (e.g. several yellows). All colors are **presets** — no freeform color mixing or custom color creation (it's fiddly and slows play).

**Save-to-collection control:** a button/checkbox on the drawing surface, **off by default**, that the drawer can activate while working. When active, the **final submitted** version of the drawing is saved to that player's local collection. It never awards points and is never visible to other players. Players may save as many of their own drawings as they like (storage is local — see §6 storage note).

**Storage format:** drawings are stored as **strokes**, not flat images. Each stroke records its color, brush size, and the sequence of points (with timestamps). This is far smaller than an image (kilobytes vs. hundreds of kilobytes), and it enables **replaying the drawing being drawn**. Strokes are used everywhere internally, including in the collection (so collection items can animate themselves being drawn). A drawing is flattened to a **PNG only on export/social-share** (see §11).

**Avatar canvas:** the avatar editor reuses the exact same tools, but on a **circular** canvas instead of a rectangle, and is accessed from the main menu (see §11).

---

## 7. Reveal Styles & Stroke Replay

Two reveal styles, selected by mode/setting:

- **Grid reveal (Streamlined):** all drawings appear at once in a grid. No per-drawing moment.
- **One-at-a-time reveal (Social):** each drawing comes up individually, animating its strokes as it's "drawn," giving everyone a beat to react, before all drawings gather into a grid for the judge's final pick.

**Stroke replay** (animating a drawing being drawn) is available because drawings are stored as strokes. It's controlled by settings:
- **Off:** drawings appear instantly (fastest).
- **Winner-only:** only the round winner's drawing animates, as a victory-lap moment.
- **Full:** every drawing animates on first reveal (most theatrical, slowest — used in one-at-a-time reveal).

**Replay speed** is adjustable and capped so it stays snappy — e.g. a 30-second drawing should replay in no more than ~10 seconds. **Reveal replay speed** and **winner replay speed** are separate adjustable settings. In the preset modes these are locked to sensible values; in Custom the host can set them.

---

## 8. Prompt Pools

- Two **separate pools** — one for animals, one for adjectives — so a prompt is never two animals or two adjectives. Each round draws one from each.
- **Built-in content:** roughly **100 animals** and **100 adjectives**, drawn from randomly.
- **Player-created content:** each player submits an **equal share** to each pool in the pre-game setup. Per-player share = **round count ÷ player count, rounded up**, so the pool always has *enough* (surplus words simply go undrawn; every player submits the same amount).
  - Examples: 4 players / 16 rounds → 4 per pool each; 4 players / 8 rounds → 2 each; 4 players / 14 rounds → 4 each (14÷4=3.5 → 4), yielding 16 per pool with 2 unused.
- **No exact-combo repeats** within a session.
- **Pool locks at game start.** A declared 12-round game stays 12 rounds regardless of who joins or leaves. Late joiners do **not** submit words and never alter the pool. If attrition ever leaves a custom pool short of what's needed, **silently backfill** from the built-in pool as a safety net.

**Pool-type architecture (build now, content later):** the code should support **selectable pool types** from day one. A pool type is **data-driven**: it declares which underlying pools it draws from and how many draws from each. The round asks the current pool type for a prompt. v1 ships only the Animal + Adjective type as content, but the architecture must let future types (e.g. Animal Hybrid = two animals, Famous People, Objects) be added as a content/config drop with no re-architecture.

---

## 9. Connectivity, Late-Join & Drop-Out

The goal is **fluid, forgiving** play that favors flow over strict fairness ("it's a goofy game").

**Late join:** a player who joins mid-game is slotted into the rotation **immediately behind the current judge**, so they judge when it comes back around. They can draw and score right away, starting with fewer points because they joined late. They do not submit prompt words and do not change the fixed pool.

**Disconnect / quit:** treated the same whether it's a temporary disconnect or a permanent quit.
- While disconnected, the player's involvement is **paused**: they're skipped for judge, and their card doesn't appear.
- If they **rejoin**, the game remembers them and restores their score.
- A drawing already submitted into an in-progress round **stays** in that round: it's still judged and still eligible for reactions/kudos even if its author drops before judging finishes.

**Anti-gaming (best-effort, not high priority):** the fluid late-join/rejoin model is intended for **private lobbies** and can be toggled. It defaults **on in private lobbies** and **off in public lobbies**. In public lobbies, prevent obvious abuse such as leaving right before/after one's own judge turn to dodge or repeat it. Perfect fairness is not required; keep the safeguard simple.

**Below-minimum pause:** if the roster drops below 3, freeze at the current phase and show "waiting for players…" to everyone. The **host** gets a button to **end the game and jump to the wrap-up** using whatever has happened so far. If a third player joins/rejoins, resume.

---

## 10. Game Modes & Settings

Three preset modes plus **Custom**. Selecting a preset locks all settings **except** the three the host can always tune: **draw-time**, **number of rounds**, and **prompt-pool source** (built-in vs. player-created).

- **Default:** the playtested happy medium.
- **Streamlined:** cuts between-round and in-round overhead. Grid reveal, replay off, quick judging. Fewer theatrics, more rounds.
- **Social:** slower and sillier. One-at-a-time reveal with stroke animation, longer reaction windows, more chat time.
- **Custom:** exposes the full settings surface (reveal style, replay on/off and speeds, judging-window length, comments on/off, kudos allotment, title-points on/off, etc.).

**Draw-time defaults** are per-mode **code constants** (easily tuned in playtesting) and are always host-adjustable.

**Number of rounds:** the game suggests a default that's **divisible by the current player count** (so everyone judges an equal number of times). The host may override to any value in range. In player-created mode, a non-divisible choice just means some submitted words go unused (submission math already rounds up to guarantee enough); in built-in mode divisibility is irrelevant.

**Recommended rounds:** roughly enough for everyone to judge a couple of times (e.g. ~2× player count).

**Comments (anonymous artist defense):** an optional one-line caption a drawer can write for their drawing, shown at reveal. Toggleable on/off when starting the lobby.

**Title points on/off:** in Custom only, the host can toggle whether end-game titles award points. Otherwise titles award points by default.

---

## 11. Scoring, Kudos, Reactions & Wrap-Up

### Scoring
- **Judge's winner pick:** **+2** to the winning drawing's author.
- **Each kudos:** **+1** to the recipient.
- **Judge no-pick penalty:** if the judging window ends with no pick, **no round winner** and the judge loses **−1**.
- **End-game titles/superlatives:** **+1 each** by default; value is a **backend code constant** (tunable by the developers, not exposed to players) and can be toggled on/off only in Custom mode.

**Negative scores are legal.** They must be handled cleanly everywhere they appear — display, sorting, tie-breaks, and the wrap-up. There is **no floor**.

### Kudos economy
- Kudos can be spent **anytime reactions are active** (during a per-drawing reveal moment or on the grid).
- Kudos are for **other players' drawings only** — you cannot kudos your own.
- Giving a kudos **also saves that drawing to your collection** (kudos and save-to-collection are the same action). This naturally limits collection bloat and keeps kudos from being spent frivolously.
- **Default allotment:** 1 kudo per player per 4 rounds, computed at game start and rounded to nearest (**.5 rounds up**). Examples: 4–5 rounds → 1; 6–8 rounds → 2; 10 rounds → 3 (10÷4=2.5→3). Host can change the allotment in lobby settings.
- **Late joiners** get the **full standard allotment** the match started with. Re-joiners are **not** topped up again — the game remembers what each player was granted and spent, so leaving and rejoining never nets extra kudos.
  > **Update (2026-07-07):** was "half the standard allotment, floored at a minimum of 1" — owner simplified during the Slice 9 playtest: kudos benefit the recipient, not the giver, so a full wallet gives no scoring advantage, and gifting is the late joiner's main verb while they spectate. See decision log.

### Reaction emojis
- Available during reveal and on the grid.
- **Anonymous** — you can see reaction counts but not who reacted. (Keeps the UI clean and encourages honesty.)
- You **cannot** react to your own drawing.
- Reactions award **no points**. Their aggregate stats feed the end-game wrap-up.
- The **judge** may also use reactions and kudos (and save drawings), giving the judge autonomy and involvement, especially in text-only public play.

### End-game wrap-up
A full, mildly animated closing sequence — a "your game, wrapped" moment that rewards staying to the end:
- **Superlatives** derived from emoji reaction stats (e.g. most-laughed-at drawing, most-disgusted-at drawing, etc.).
- **Per-player title cards** — silly session titles (e.g. "Worst Drawer," "Hotshot") shown with **evidence**: the drawing(s) that earned the title.
- **Final standings** (1st, 2nd, 3rd, etc.), accounting for any title points and negative scores.
- Titles are **per-game** and awarded fresh each session (a player may earn the same title across many sessions over their play "career").

### Avatars
- Drawn by the player in the avatar editor (circular canvas, same tools), editable anytime from the main menu.
- **Fallback chain:** (1) the player's drawn avatar; if none, (2) a blank circle showing the player's **Steam username** in a clean font; if no Steam username is retrievable, (3) a randomly assigned one of a small set of **pre-drawn house avatars**.

### Steam achievements (permanent) vs. session titles (per-game)
Two tiers:
- **Session titles** — the fun, per-game superlatives above; ephemeral to that game's results.
- **Steam achievements** — permanent, account-tied unlocks, mirrored to Steam via its SDK. Examples: earning a given title for the first time; earning a title many times (e.g. Hotshot ×10); saving N drawings to your collection; spending all your kudos in a game; playing 100 rounds / 100 games.

---

## 12. Lobbies & Joining

Three ways to get into a game, **all in v1**:

- **Room codes:** a player enters a room's code/name to join friends directly.
- **Steam invites:** invite-to-game and join-game through Steam.
- **Public lobby browser:** a browsable list of open public lobbies showing **mode, current/max players, round count, draw-time, and prompt-pool type**, with basic filtering and a **join** button.

**No matchmaking** in v1 (skill-based matchmaking needs a population a new game won't have; room codes match how the game is actually played).

**Host moderation lever:** the host can **kick** a player from their own lobby. A kicked player is added to a **per-game blocklist** and cannot rejoin **that specific game**. This is not a persistent global ban.

**Public lobby content notice:** public lobbies are **unmoderated** and must be clearly labeled as such. The core game is all-ages, but public play should carry an **18+ / at-your-own-risk** notice because user-generated drawings and text are unmoderated. (Exact legal wording to be reviewed before launch.)

---

## 13. Networking & Safety (Design-Level Requirements)

- **Use Steam's relay networking** so players never connect directly to a stranger's raw IP and IPs stay hidden. This defends the average user against the "join a public lobby hosted on some stranger's machine, get your IP / get targeted" problem.
- **Treat all client input as untrusted.** The host session validates everything clients send; no client can cause arbitrary behavior. No arbitrary data execution.
- **Typed text** (chat, captions, custom words) runs against a **blocklist** of disallowed words.
- **Drawings are inherently unmoderated** — with paste/image-import disabled and a 15–30s time limit, the practical worst case is someone writing something inappropriate by hand. This is accepted and disclosed rather than solved.
- The goal is **reasonable safety for an indie game**: make casual malice annoying enough not to bother with. Not designed to stop a determined expert attacker.
- **No image paste / import** onto the canvas — drawings must be physically drawn.

---

## 14. Data & Persistence (Local-First)

- **No central server holds player data.** Collections, achievements, titles, and avatars are saved to a **local file** on the player's own machine (Steam's per-user save location).
- **Steam achievements** are the only thing that lives "in the cloud," via Steam's SDK.
- When a player saves a drawing (via kudos or the self-save control), the drawing's stroke data — received over the network like any other — is written to their local save.
- **No global gallery or cross-player sharing** service; sharing is an **export** action (§11) that produces a PNG the player can save or post. This keeps sharing infrastructure-free and matches the friends-first design.

---

## 15. Collection Browser (v1 scope)

- A simple scrollable **grid** of the player's saved drawings, each showing its prompt (animal + adjective).
- **Click to view** larger and watch the stroke **replay**.
- Per-item actions: **Export PNG**, **Social Share**, **Delete**.
- No search, tags, or folders in v1.
