# Overview of Slices: Animal Quickdraw

**Purpose:** Summary of all slices, their relationships, dependencies, development order, and the chunk (work-session) plan. Updated as slices are completed.

**Last Updated:** 2026-07-04

---

## Project Summary

Animal Quickdraw is a 3–8 player Steam party game (Godot 4.6, Win/macOS/Linux) where a rotating judge heckles drawers over chat while they race to draw prompts like "sleepy aardvark"; drawings are stored as strokes, revealed anonymously, judged with kudos/reactions, and celebrated in an end-game wrap-up. Full spec: `game-design-brief.md`. Tech stack and approval record: `TDD/recipe.md`.

**Total Slices:** 16 (Skeleton + 15 feature slices)

---

## Slice Summary

| # | Slice Name | Description | Dependencies |
|---|------------|-------------|--------------|
| 0 | Skeleton | Structure, platform layer (ENet dev), Net/Save/Nav/EventBus, constants, text filter, test harness, dev tooling | None |
| 1 | Drawing Canvas & Stroke Engine | Canvas, tools (brush/fill/undo/clear/rotate), palette, DrawingDoc format, replay renderer | 0 |
| 2 | Lobby & Session Roster | Host/join over dev transport, roster sync, base lobby settings, chat foundation, start gate | 0 |
| 3 | Core Round Loop | Round state machine, judge rotation, built-in prompt pools (data-driven types), per-phase screens, scoring core → **playable MVP** | 1, 2 |
| 4 | Reactions, Kudos & Saving | Anonymous emoji reactions + stats, kudos economy, kudos=save, collection write path | 3 |
| 5 | Reveal Styles & Replay | One-at-a-time reveal, replay off/winner/full + speed settings, winner victory lap, captions | 3 (replay from 1) |
| 6 | Game Modes & Settings | Default/Streamlined/Social presets + Custom full surface, round-count suggestion | 3, 5 |
| 7 | Player-Created Prompt Pools | Pre-game word submission, share math, pool lock, silent backfill | 3 |
| 8 | Collection Browser & Export | Grid, view+replay, PNG export, social share, delete | 1, 4 |
| 9 | Connectivity & Resilience | Late join, disconnect/rejoin, below-minimum pause, anti-gaming toggle | 3, 4 |
| 10 | End-Game Wrap-Up | Superlatives, title cards with evidence, title points, final standings, early-end entry | 4, 9 |
| 11 | Avatars | Circular-canvas editor, fallback chain, avatar display everywhere | 1 (Steam name via 12, stubbed) |
| 12 | Steam Platform Integration | GodotSteam init, relay transport, lobbies=room codes, invites, Steam names | 2, 3 |
| 13 | Public Lobbies & Moderation | Lobby browser + filters, kick + per-game blocklist, 18+ notice, blocklist enforcement | 12 |
| 14 | Achievements & Stats | Lifetime stats tracking, Steam achievement definitions + unlock wiring | 10, 12 |
| 15 | Release Preparation | Signing/notarization, Steam depots, legal wording pass, store assets | All |

*Current status lives in `WHERE_WE_ARE.md` — the single source of truth for progress.*

---

## Dependency Notes

**Skeleton (0)** provides the platform seam (ENet now, Steam later), networking, persistence, navigation, and constants that everything builds on.

**1 & 2 are independent** — canvas is fully offline; lobby is pure networking. Either order works; the chunk plan does canvas first (highest technical risk: deterministic fill + replay).

**3 needs both:** drawers draw on the Slice 1 canvas inside a session formed by Slice 2. Slice 3 includes the *pool-type architecture* and built-in content; player-created pools (7) layer a pre-game phase on top later.

**4 before 9 and 10:** kudos allotment math (4) is referenced by late-joiner rules (9); reaction stats (4) feed superlatives (10). **9 before 10:** the below-minimum "end early" button jumps into the wrap-up sequence.

**12 late by design:** the platform interface makes Steam a transport/identity swap under the existing lobby — the whole game is developed and tested on the ENet dev backend first. **13 and 14 need 12** (lobby browser = Steam lobby list; achievements = Steam SDK). **11** works offline; its Steam-username fallback is stubbed until 12.

## Parallel Development Notes

Sessions are sequential (solo dev + AI), but if order ever needs to flex: {1, 2} are parallel-safe after 0; {5, 6, 7, 8} are mutually independent after their listed deps; 11 can slot anywhere after 1. Coordinate on `event_bus.gd`, `net_ids.gd`, and `game_constants.gd` — the shared integration files where slices append.

---

## Chunk Plan (Work Sessions)

Hard ~180k-token context budget per session (Decision Log 2026-07-04). One chunk = one session; if a session runs hot, checkpoint early via Session End; if cool, pull the next chunk's work forward and note it in WHERE_WE_ARE.

| Chunk | Slice(s) | Contents | Playtest gate at end |
|-------|----------|----------|----------------------|
| 1 | 0 | Full skeleton | Two local instances connect |
| 2 | 1 (part 1) | Stroke model, canvas render, brush ×3, palette + shades, undo/clear, serialization + tests | Drawing feel (blocking for part 2 polish) |
| 3 | 1 (part 2) | Bucket fill, rotate, replay renderer, save-toggle stub → slice complete | Fill + replay correctness |
| 4 | 2 | Lobby & roster complete | Host/join/leave flows |
| 5 | 3 (part 1) | Pool engine + built-in content, headless state machine + scoring + tests | — (logic only) |
| 6 | 3 (part 2) | Per-phase/role screens, integration → **playable MVP** | Full 3-player round on LAN |
| 7 | 4 | Reactions, kudos, saving | Reaction/kudos UX |
| 8 | 5 | Reveal styles & replay | One-at-a-time reveal moment |
| 9 | 6 | Modes & settings | Preset behaviors |
| 10 | 7 | Player-created pools | Submission flow |
| 11 | 8 | Collection browser & export | Browser + PNG export |
| 12 | 9 | Connectivity & resilience | Join/drop/rejoin scenarios |
| 13 | 10 | Wrap-up | Wrap-up sequence |
| 14 | 11 | Avatars | Avatar editor |
| 15 | 12 | Steam integration | Steam invite/join (needs 2 Steam accounts or Spacewar) |
| 16 | 13 | Public lobbies & moderation | Browser + kick |
| 17 | 14 | Achievements & stats | Achievement unlocks |
| 18 | 15 | Release prep | Full playtest pass |

---

## Slice Document Links

| Slice | TDD Document | Implementation Notes |
|-------|--------------|----------------------|
| 0 | `TDD/00-skeleton-build-guide.md` | `TDD/00-skeleton-implementation-notes.md` |
| 1 | `TDD/01-drawing-canvas-stroke-engine.md` | `TDD/01-drawing-canvas-stroke-engine-implementation-notes.md` |
| 2 | `TDD/02-lobby-session-roster.md` | `TDD/02-lobby-session-roster-implementation-notes.md` |
| 3 | `TDD/03-core-round-loop.md` | `TDD/03-core-round-loop-implementation-notes.md` |
| 4 | `TDD/04-reactions-kudos-saving.md` | `TDD/04-reactions-kudos-saving-implementation-notes.md` |
| 5 | `TDD/05-reveal-styles-replay.md` | `TDD/05-reveal-styles-replay-implementation-notes.md` |
| 6 | `TDD/06-game-modes-settings.md` | `TDD/06-game-modes-settings-implementation-notes.md` |
| 7 | `TDD/07-player-created-pools.md` | — |
| 8 | `TDD/08-collection-browser-export.md` | — |
| 9 | `TDD/09-connectivity-resilience.md` | — |
| 10 | `TDD/10-endgame-wrapup.md` | — |
| 11 | `TDD/11-avatars.md` | — |
| 12 | `TDD/12-steam-integration.md` | — |
| 13 | `TDD/13-public-lobbies-moderation.md` | — |
| 14 | `TDD/14-achievements-stats.md` | — |
| 15 | `TDD/15-release-preparation.md` | — |
