# Project Recipe: Animal Quickdraw

**Purpose:** Pre-TDD document that consolidates the project description and tech stack decisions into a structured format used to generate full Technical Design Documents. This document is a historical snapshot - once approved, it is not updated.

**Location:** `TDD/recipe.md`
**Created:** 2026-07-04
**Status:** Approved

---

## Project Overview

| Field | Value |
|-------|-------|
| **Project Name** | Animal Quickdraw |
| **Description** | A digital adaptation of a pen-and-paper drawing party game. 3–8 players; each round a rotating judge sees a prompt (animal + adjective) and heckles via chat while everyone else races to draw it. Drawings are revealed anonymously, players react and award kudos, the judge picks a winner, and an end-game wrap-up awards silly superlatives. The fun is social and comedic, not artistic. |
| **Target Platform(s)** | Desktop: Windows, macOS, Linux — single codebase, shipped on Steam |
| **Primary Users** | Friend groups playing online together via Steam (private lobbies primarily; public lobbies supported) |
| **Key Constraints** | Local-first persistence (no central server); host-authoritative sessions over Steam relay networking; drawings stored as strokes, not images; all client input treated as untrusted; no image paste/import; reasonable-indie-safety bar |

**Full design reference:** `game-design-brief.md` (project root) — the authoritative feature spec (§1–§15).

---

## Tech Stack Summary

| Component | Choice | Notes |
|-----------|--------|-------|
| **Platform** | Desktop game (Win/macOS/Linux) | Steam storefront only for v1 |
| **Engine** | Godot 4.6 (stable) | Installed on dev machine via Homebrew |
| **Language** | GDScript with static typing enforced | Typed GDScript required by consistency guide |
| **Networking** | Godot high-level multiplayer (RPCs), host-authoritative | Transport swappable: ENet (dev/LAN) and Steam relay (ship) behind a platform interface |
| **Steam Integration** | GodotSteam GDExtension | Lobbies (room codes, invites, public browser), achievements, SteamMultiplayerPeer for relay networking. Dev uses App ID 480 (Spacewar) until a real App ID exists |
| **State Management** | Autoload singletons + typed signals | Godot-idiomatic; event names centralized in constants |
| **Database/Storage** | JSON files in `user://` | One file per saved drawing + index + profile; Steam per-user save location |
| **Testing Framework** | GdUnit4 | Unit + integration tests for GDScript; scene tests for UI where valuable |
| **Build/Deploy** | Godot export presets (Win/macOS/Linux) | macOS signing/notarization + Steam depot setup in Release Prep slice |

---

## Feature List

### Core Features
- [ ] Drawing canvas: brush (3 sizes), preset palette with expandable shades, bucket fill, undo, clear, landscape/portrait rotate; fixed internal resolution for deterministic replay/fill
- [ ] Stroke-based drawing storage (color, size, timestamped points) with replay rendering at capped/adjustable speeds
- [ ] Lobby system: create/join, roster, host settings, minimum 3 / maximum 8 players
- [ ] Core round loop: judge rotation, prompt draw, draw phase with timer, auto-submit, anonymous reveal, judge pick, scoring, round advance
- [ ] Data-driven prompt pool architecture (v1 content: ~100 animals + ~100 adjectives; no exact-combo repeats; future pool types are a content drop)
- [ ] Text chat with phase-dependent prominence (judge heckling is a first-class feature)
- [ ] Reactions (anonymous emoji), kudos economy (kudos = save-to-collection), scoring incl. negative scores
- [ ] Reveal styles: grid (streamlined) and one-at-a-time with stroke animation (social); winner replay
- [ ] Game modes: Default / Streamlined / Social / Custom; host-tunable draw time, rounds, pool source in all modes
- [ ] Player-created prompt pools (equal shares, pool locks at start, silent backfill)
- [ ] Late join / disconnect / rejoin handling; below-minimum pause; anti-gaming toggle for public lobbies
- [ ] End-game wrap-up: superlatives from reaction stats, per-player title cards with evidence, final standings
- [ ] Local collection: save own drawings (opt-in) + kudos-saves; browser grid with replay, PNG export, social share, delete
- [ ] Avatars: circular-canvas editor reusing drawing tools; fallback chain (drawn → Steam username → house avatars)
- [ ] Steam: relay networking, invites/join, lobbies, achievements
- [ ] Public lobby browser with filters; host kick + per-game blocklist; 18+/unmoderated notice; typed-text word blocklist

### Secondary Features
- [ ] Comments/captions on drawings (toggleable)
- [ ] Title points on/off (Custom mode)
- [ ] Steam achievements tied to titles, collection, kudos, play counts

### Future Considerations (Out of Initial Scope)
- Additional pool types (Animal Hybrid, Famous People, Objects) — architecture supports, content later
- More than 8 players; matchmaking; global gallery / cross-player sharing service
- Non-Steam storefronts (thin platform interface leaves the seam open)

---

## Slice Breakdown

### Slice 0: Skeleton
**Description:** Project foundation — structure, conventions, core systems, dev tooling.
**Key Deliverables:**
- Godot project setup, folder structure, typed-GDScript conventions, GdUnit4 harness
- Platform interface (`PlatformService`): ENet dev backend now, Steam backend stubbed
- Core autoloads: scene manager, network manager (host/join/RPC conventions), save service (JSON in `user://`), constants/event names, blocklist text-filter utility
- Theme foundation, multi-instance dev launch tooling, export presets (unsigned)

### Slice 1: Drawing Canvas & Stroke Engine
**Description:** The complete drawing surface and the stroke data model everything else consumes.
**Key Deliverables:**
- Canvas at fixed internal resolution; brush ×3, palette + shade drill-down, bucket fill (deterministic), undo, clear, rotate
- Stroke model + JSON serialization; replay renderer with speed caps
- Save-to-collection toggle control (persists via save service)

### Slice 2: Lobby & Session Roster
**Description:** Getting players into a shared session (dev transport) with a host-controlled lobby.
**Key Deliverables:**
- Create/join session (room code over ENet dev backend), roster sync, host role
- Base lobby settings UI (rounds, draw time, pool source placeholder)
- Text chat foundation (used later in-game), start gate (min 3, max 8)

### Slice 3: Core Round Loop
**Description:** The playable heart: full round state machine, end-to-end.
**Key Deliverables:**
- Server-side game state machine: judge rotation → prompt → draw phase (timer) → auto-submit → grid reveal → judge pick window → resolution → advance → basic end screen
- Data-driven prompt pool engine + built-in animal/adjective content (~100 each), no-repeat rule
- Per-phase, per-role screens (drawer canvas view, judge heckle view with prominent chat)
- Scoring core: +2 winner, −1 judge no-pick, negative scores legal
- **Milestone: game is playable end-to-end on LAN after this slice**

### Slice 4: Reactions, Kudos & Saving
**Description:** The social economy layer on top of the loop.
**Key Deliverables:**
- Anonymous emoji reactions (fixed set), aggregate counts, no self-react, stats recorded for wrap-up
- Kudos: allotment math (per-round formula, host-adjustable), +1 scoring, no self-kudos, judge can react/kudos
- Kudos = save-to-collection; collection write path (local JSON)

### Slice 5: Reveal Styles & Replay
**Description:** The theatrical reveal options.
**Key Deliverables:**
- One-at-a-time reveal with stroke animation and per-drawing react moment, gather-to-grid
- Replay settings: off / winner-only / full; separate reveal + winner replay speeds with caps
- Winner victory-lap view; canvas orientation preserved everywhere; optional captions at reveal

### Slice 6: Game Modes & Settings
**Description:** Preset modes and the full settings surface.
**Key Deliverables:**
- Default / Streamlined / Social presets (locked settings) + always-tunable three (draw time, rounds, pool source)
- Custom mode full settings surface; round-count suggestion (divisible by player count)
- Per-mode code-constant defaults, easily tuned

### Slice 7: Player-Created Prompt Pools
**Description:** The pre-game word submission flow.
**Key Deliverables:**
- Submission UI + share math (rounds ÷ players, rounded up), equal shares per pool
- Pool lock at start; late joiners never alter pool; silent backfill from built-in pool

### Slice 8: Collection Browser & Export
**Description:** Browsing and sharing saved drawings.
**Key Deliverables:**
- Scrollable grid with prompts; click-to-view with replay
- Export PNG (flatten strokes), social share, delete

### Slice 9: Connectivity & Resilience
**Description:** Forgiving late-join/drop-out behavior.
**Key Deliverables:**
- Late join: slot behind current judge, reduced starting points, half kudos (min 1, floored)
- Disconnect/rejoin: pause involvement, skip judge, restore score, no kudos top-up; submitted drawings persist in round
- Below-minimum pause + host end-early-to-wrap-up; anti-gaming toggle (default on-private/off-public)

### Slice 10: End-Game Wrap-Up
**Description:** The "your game, wrapped" closing sequence.
**Key Deliverables:**
- Superlatives from reaction stats; per-player title cards with evidence drawings
- Title points (backend constant, Custom toggle); final standings with negative-score handling
- Early-end entry path (from Slice 9's host button)

### Slice 11: Avatars
**Description:** Drawn avatars using the existing canvas.
**Key Deliverables:**
- Avatar editor (circular canvas, same tools) from main menu; local persistence
- Fallback chain: drawn → Steam username circle → random house avatar; avatar display in lobby/game/wrap-up

### Slice 12: Steam Platform Integration
**Description:** Swap the dev transport for the real thing.
**Key Deliverables:**
- GodotSteam init (App ID 480 for dev); SteamMultiplayerPeer relay transport behind the platform interface
- Steam lobbies mapped to room codes; invite-to-game and join-via-friend; Steam usernames
- ENet dev mode remains available via launch flag

### Slice 13: Public Lobbies & Moderation
**Description:** Public discovery and the safety bar.
**Key Deliverables:**
- Public lobby browser (Steam lobby list): mode, players, rounds, draw time, pool type + filters + join
- Host kick + per-game blocklist; 18+/unmoderated notice; blocklist filter wired to all typed text (chat, captions, custom words)

### Slice 14: Achievements & Stats
**Description:** Permanent progression via Steam.
**Key Deliverables:**
- Local stats tracking (rounds/games played, titles earned, kudos spent, drawings saved)
- Steam achievement definitions + unlock wiring (title-firsts, title×N, collection, kudos, play counts)

### Slice 15: Release Preparation
**Description:** Shipping mechanics.
**Key Deliverables:**
- Final export presets; macOS signing/notarization; Steam depots/builds
- Public-lobby legal wording review pass; playtest checklist; store-asset export (screenshots)

---

## Slice Dependency Order

| Order | Slice | Depends On | Notes |
|-------|-------|------------|-------|
| 1 | 0 Skeleton | None | Foundation — must be first |
| 2 | 1 Canvas & Strokes | Skeleton | Parallelizable with Slice 2 |
| 3 | 2 Lobby & Roster | Skeleton | Parallelizable with Slice 1 |
| 4 | 3 Core Round Loop | 1, 2 | Playable MVP milestone |
| 5 | 4 Reactions & Kudos | 3 | Also creates collection write path |
| 6 | 5 Reveal & Replay | 3 (replay from 1) | |
| 7 | 6 Modes & Settings | 3, 5 | Presets lock reveal/replay settings |
| 8 | 7 Player-Created Pools | 3 | |
| 9 | 8 Collection Browser | 1, 4 | Offline feature; flexible position |
| 10 | 9 Connectivity | 3, 4 | Late-join kudos rules need 4 |
| 11 | 10 Wrap-Up | 4, 9 | Reaction stats + early-end entry |
| 12 | 11 Avatars | 1 | Steam-name fallback stubs until 12 |
| 13 | 12 Steam Integration | 2, 3 | Transport swap under existing lobby |
| 14 | 13 Public Lobbies | 12 | |
| 15 | 14 Achievements | 10, 12 | Titles must exist to mirror |
| 16 | 15 Release Prep | All | |

---

## Chunk Plan (Work Sessions)

Each chunk is one work session, targeted to stay under ~180k tokens of context so sessions complete without compaction. A slice may span multiple chunks; chunk boundaries are checkpointed in WHERE_WE_ARE.

| Chunk | Slice(s) | Contents | Est. Size |
|-------|----------|----------|-----------|
| 1 | 0 | Full skeleton | Medium |
| 2 | 1 (part 1) | Stroke model, canvas render, brush, palette, undo/clear, serialization + tests | Medium-Large |
| 3 | 1 (part 2) | Bucket fill, rotate, replay renderer, save toggle, polish → slice complete | Medium |
| 4 | 2 | Full lobby & roster slice | Medium |
| 5 | 3 (part 1) | Pool engine + content, state machine headless + tests | Medium |
| 6 | 3 (part 2) | Phase/role screens, integration → playable MVP | Large |
| 7 | 4 | Reactions, kudos, saving | Medium |
| 8 | 5 | Reveal styles & replay | Medium |
| 9 | 6 | Modes & settings | Medium |
| 10 | 7 | Player-created pools | Small-Medium |
| 11 | 8 | Collection browser & export | Medium |
| 12 | 9 | Connectivity & resilience | Large — stop at checkpoint if hot |
| 13 | 10 | Wrap-up | Medium |
| 14 | 11 | Avatars | Small-Medium |
| 15 | 12 | Steam integration | Large — stop at checkpoint if hot |
| 16 | 13 | Public lobbies & moderation | Medium |
| 17 | 14 | Achievements & stats | Small-Medium |
| 18 | 15 | Release prep | Medium |

**Chunk discipline:** start each session with the Session Start workflow; if context runs hot mid-chunk, stop at a clean checkpoint, run Session End, and resume next session. Estimates get corrected as real sessions calibrate them.

---

## Open Questions

1. **Steam App ID:** Development proceeds on App ID 480 (Spacewar). A real App ID (Steamworks registration, ~$100) is needed before Slice 12 can be fully verified and is required for Slice 15.
   - *Recommendation:* register when Slice 12 approaches; no earlier dependency.
2. **Art & sound:** All TDDs assume placeholder programmer art and no audio design. Real art/sfx are a content pass, not a slice.
   - *Recommendation:* revisit after MVP milestone (Chunk 6).

---

## Approval

**By approving this Recipe, you confirm:**
- [x] The tech stack choices are correct
- [x] The feature list is complete for the initial release
- [x] The slice breakdown makes sense
- [x] The dependency order is logical
- [x] All open questions have been resolved or accepted as noted

**Approved by:** Capt-Sunbeam (project owner)
**Approval Date:** 2026-07-04

> Pacing decision: the original 18-chunk plan with a hard ~180k-token-per-session context budget was confirmed by the owner (over a proposed 11-session consolidation) — maximum conservatism, clean checkpoints every session. See Decision Log.

---

## What Happens Next

After approval, the following documents will be generated:

1. **Skeleton Build Guide** (`TDD/00-skeleton-build-guide.md`)
2. **Slice TDDs** (`TDD/01-…` through `TDD/15-…`, following the Slice Contract Template)
3. **Project Consistency Guide** (`TDD/consistency-guide.md`)
4. **Overview of Slices** (`TDD/overview-of-slices.md`) — including the chunk plan
5. **WHERE_WE_ARE.md** (project root)
6. **Decision Log** (`TDD/decision-log.md`) — initialized with tech stack decisions
