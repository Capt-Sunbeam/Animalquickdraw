# Strudel Sound Sources — Animal Quickdraw

**Purpose:** Single source of truth for the Strudel "code" behind every music track, stinger, and composed SFX (owner-requested documentation feature, 2026-07-19). The audio files that ship in the game get rendered from these sources; if a rendered asset and its source ever disagree, the source here wins — re-render.

**Companion docs:** [`TDD/sound-design-brief.md`](../sound-design-brief.md) — the full moment inventory (what plays when, target lengths) and §0 musical identity rules (key, tempo, palette) that keep every track on-theme. [`stinger-sfx-spec.md`](stinger-sfx-spec.md) — precise per-sound composing descriptions for all remaining stingers + SFX (2026-07-19).

---

## Workflow

1. Compose/iterate in the Strudel REPL (https://strudel.cc)
2. When a track reaches "done" (or a milestone worth keeping), paste the full source into its file here
3. Rendering to game assets (OGG loops / WAV one-shots into `assets/audio/`) happens in the future sound implementation session — record two full loop passes, trim the second at exact cycle boundaries for a click-free loop point

## File conventions

- One file per asset, named after its inventory id: `m1-main-menu.strudel`, `s4-winner.strudel`, `cue-timer-warning.strudel`, `sfx-<name>.strudel`
- Plain text, valid Strudel code — paste-ready. `//` comment header at the top of each file: id, status, where it plays, key/tempo
- Superseded versions: don't keep old copies in-file; git history is the archive (owner commits)

## Index / composing to-do list

| File | Inventory id | Asset | Status |
|------|--------------|-------|--------|
| `m1-main-menu.strudel` | M1 | Main menu theme | **DONE ✓** (2026-07-19) |
| `m2-lobby.strudel` | M2 | Lobby theme — elevator arrangement of M1 | **DONE ✓** (2026-07-19) |
| `m3-drawing-ambient.strudel` | M3a | Drawing theme, ambient/subtle — in the host-pickable rotation | **DONE ✓** (2026-07-19) |
| `m3-drawing-oompa.strudel` | M3b | Drawing theme, "oompa loompa banjo"/upbeat — in the host-pickable rotation | **DONE ✓** (2026-07-19) |
| — | M4 | Judging/reveal theme | **CUT** (owner, 2026-07-19 — silence + stingers carry judging; see brief §1 note) |
| — | M5 | Wrap-up/ceremony theme | **CUT** (owner, 2026-07-19 — stingers carry the ceremony; M2-early-start is the fallback) |
| `cue-timer-warning.strudel` | — | 5 s escalating timer warning + landing note (drawing + judging, one-shot) | **DONE ✓** (2026-07-19) |
| `s1-race-start.strudel` | S1 | Race start — "duh duh duh duh-BEEP" countdown into drawing (every round; repurposed from whole-game start) | **DONE ✓** (2026-07-19) |
| `s2-prompt-reveal.strudel` | S2 | Prompt reveal — "ta-da-da-DAAA" climb-over run (word appears; dovetails with S1) | **DONE ✓** (2026-07-19) |
| `s3-times-up.strudel` | S3 | Time's up stinger (timer cue lands on this) | TODO |
| `s4-winner.strudel` | S4 | Per-round winner sting — "duh duh duh-DUH" | **DONE ✓** (2026-07-19) |
| `s6-title-awarded.strudel` | S6 | Title card — compact "dh-DUH" (S4's tail; wiring pitches each stack a step up) | **DONE ✓** (2026-07-19) |
| `s7-final-podium.strudel` | S7 | Final podium — S4's motif answered higher; the game's one grand fanfare | **DONE ✓** (2026-07-19) |
| `s8-round-transition.strudel` | S8 | Round transition (skip if S2 covers it) | TODO |
| `sfx-chat-pop.strudel` | — | SFX: chat pop (incoming-message bloop) | **DONE ✓** (2026-07-19) |
| `sfx-button-press.strudel` | — | SFX: button press (triangle "tock", chat pop's deep cousin) | **DONE ✓** (2026-07-19) |
| `sfx-ready-click.strudel` | — | SFX: Done!/ready click (rising triangle pair — the "yes!" tock) | **DONE ✓** (2026-07-19) |
| `sfx-all-ready.strudel` | — | SFX: all-ready chime (three-note triangle rise) | **DONE ✓** (2026-07-19) |
| `sfx-toggle-on.strudel` | — | SFX: toggle ON tick (A4 triangle) | **DONE ✓** (2026-07-19) |
| `sfx-toggle-off.strudel` | — | SFX: toggle OFF tick (F4 triangle) | **DONE ✓** (2026-07-19) |
| `sfx-player-join.strudel` | — | SFX: player join (rising e-piano "hello") | **DONE ✓** (2026-07-19) |
| `sfx-player-leave.strudel` | — | SFX: player leave (falling e-piano goodbye) | **DONE ✓** (2026-07-19) |
| `sfx-text-stamp.strudel` | — | SFX: text stamp ("rip-THUMP" — paper tear + deep thump) | **DONE ✓** (2026-07-19) |

(S5 retired 2026-07-14 with the emoji/superlatives removal — id not reused.)

**UI/social/canvas SFX** (button press, chat pop, kudos, join/leave, etc. — full list in brief §3): add as `sfx-<name>.strudel` if composed in Strudel; sourced/recorded ones don't need a file here, just a note in the brief.
