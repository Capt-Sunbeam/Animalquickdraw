# Strudel Sound Sources — Scribble Safari

**Purpose:** Single source of truth for the Strudel "code" behind every music track, stinger, and composed SFX (owner-requested documentation feature, 2026-07-19). The audio files that ship in the game get rendered from these sources; if a rendered asset and its source ever disagree, the source here wins — re-render.

**Companion docs:** [`TDD/sound-design-brief.md`](../sound-design-brief.md) — the full moment inventory (what plays when, target lengths) and §0 musical identity rules (key, tempo, palette) that keep every track on-theme. [`stinger-sfx-spec.md`](stinger-sfx-spec.md) — precise per-sound composing descriptions for all remaining stingers + SFX (2026-07-19).

---

## Workflow

1. Compose/iterate in the Strudel REPL (https://strudel.cc)
2. When a track reaches "done" (or a milestone worth keeping), paste the full source into its file here
3. Rendering to game assets (OGG loops / WAV one-shots into `assets/audio/`): run the **Strudel Extractor** (`node tools/strudel_extractor/server.mjs`, see its README) — it captures the live engine and slices on exact cycle boundaries by clock arithmetic (2026-08-10; supersedes the old two-pass/manual-trim plan). **All 25 assets rendered + owner-approved 2026-08-10.** **WIRED into the game 2026-08-10 (Slice 21, session 16)** — `Audio` autoload, buses, cue scheduling, rotation setting; see `TDD/21-audio-wiring.md`

## File conventions

- One file per asset, named after its inventory id: `m1-main-menu.strudel`, `s4-winner.strudel`, `cue-timer-warning.strudel`, `sfx-<name>.strudel`
- Plain text, valid Strudel code — paste-ready. `//` comment header at the top of each file: id, status, where it plays, key/tempo
- Superseded versions: don't keep old copies in-file; git history is the archive (owner commits)

> **2026-07-19 (later):** Strudel's native export drops the global reverb/delay bus (confirmed on both strudel.cc and warm.strudel.cc) — hand-exports of these files are unusable. Rendering uses the live-capture tool instead.
>
> **2026-08-10 (polish session):** three polish assets composed via chat iteration — **`m6-judging`** (new — the M4 revisit condition fired), **`sfx-reveal`** (new — the parked card-flip row), and **`cue-timer-warning` v2** (replaces the escalating ladder; no landing note). **All three RENDERED same day** (one file per page session; cue verified by onset analysis — beeps at exact 1 s spacing; m6 = 40.000 s exact; sfx-reveal = 2.29 s with tail). The other 24 rendered assets are untouched.
>
> **2026-08-09: the tool is BUILT — the Strudel Extractor** (`tools/strudel_extractor/`, renamed from the "Strudel Sound Renderer" spec at `tools/sound_pipeline/`). Run `node tools/strudel_extractor/server.mjs`, open the printed URL, Process. Render settings are set in the app (remembered automatically; no file headers, no source edits). The `.mask("<1 0>")` trick is fully retired — the tool captures one-shot tails natively. Owner decisions at the build session: **all music loops render from cycle 0** (intro cycles included; the phase-chosen start offsets below are superseded), s4/s7 windows shrink to 0→1.

## Render settings (2026-07-19; revised 2026-08-09)

Per-file start/end cycles for converting sources to audio. One-shots keep their tails (the tool extends past the boundary to true silence). Music → OGG (loop points on import); cue/stingers/SFX → WAV.

| File | Start cycle | End cycle | ≈ Length | Note |
|------|-------------|-----------|----------|------|
| `cue-timer-warning` | 0 | 5 | 5.0 s | one-shot; v2 (2026-08-10): four F4 beeps + A4, one per second — the A4 IS the landing (onset 4.046 s, hits the phase change; no ding after) |
| `m1-main-menu` | 0 | 104 | 3:32 | the full arrangement; outro thins into the intro by design — loop the whole thing |
| `m2-lobby` | 0 | 40 | 92 s | from cycle 0 (owner, 2026-08-09 — intro in the loop); spans the full slow(32) filter period |
| `m3-drawing-ambient` | 0 | 80 | 2:51 | from cycle 0 (owner, 2026-08-09); spans the slow(14)+slow(8) periods |
| `m3-drawing-oompa` | 0 | 64 | 2:10 | from cycle 0 (owner, 2026-08-09); spans the slow(6)+slow(12) periods |
| `m6-judging` | 0 | 16 | 40 s | polish session (2026-08-10); spans the slow(16) filter period |
| `s1-race-start` | 0 | 1 | 4.3 s | tail dies inside the cycle |
| `s2-prompt-reveal` | 0 | 1 | 2.0 s | |
| `s4-winner` | 0 | 1 | ~2.5 s | tail captured natively by the extractor (mask trick retired) |
| `s6-title-awarded` | 0 | 1 | 2.0 s | |
| `s7-final-podium` | 0 | 1 | ~6 s | tail captured natively by the extractor (mask trick retired); measured 4.0 s music + ~2 s ring-out |
| `sfx-all-ready` | 0 | 1 | 1.0 s | |
| `sfx-button-press` | 0 | 1 | 1.0 s | |
| `sfx-chat-pop` | 0 | 1 | 1.0 s | |
| `sfx-eraser` | 0 | 1 | 1.0 s | |
| `sfx-judge-latch` | 0 | 1 | 1.0 s | |
| `sfx-kudos` | 0 | 1 | 2.0 s | |
| `sfx-pause` | 0 | 1 | 2.0 s | |
| `sfx-player-join` | 0 | 1 | 1.0 s | |
| `sfx-player-leave` | 0 | 1 | 1.0 s | |
| `sfx-ready-click` | 0 | 1 | 1.0 s | |
| `sfx-reveal` | 0 | 1 | ~2.3 s | polish session (2026-08-10); 1 s run + native ring-out tail |
| `sfx-text-stamp` | 0 | 1 | 1.0 s | |
| `sfx-toggle-off` | 0 | 1 | 1.0 s | |
| `sfx-toggle-on` | 0 | 1 | 1.0 s | |
| `sfx-undo-poof` | 0 | 1 | 1.0 s | |
| `sfx-unpause` | 0 | 1 | 2.0 s | |

Trailing silence inside a one-shot render is harmless (trim in an editor later if you want snappier files — optional polish, the wiring session can also handle it).

## Index / composing to-do list

| File | Inventory id | Asset | Status |
|------|--------------|-------|--------|
| `m1-main-menu.strudel` | M1 | Main menu theme | **DONE ✓** (2026-07-19) |
| `m2-lobby.strudel` | M2 | Lobby theme — elevator arrangement of M1 | **DONE ✓** (2026-07-19) |
| `m3-drawing-ambient.strudel` | M3a | Drawing theme, ambient/subtle — in the host-pickable rotation | **DONE ✓** (2026-07-19) |
| `m3-drawing-oompa.strudel` | M3b | Drawing theme, "oompa loompa banjo"/upbeat — in the host-pickable rotation | **DONE ✓** (2026-07-19) |
| — | M4 | Judging/reveal theme | **CUT** (owner, 2026-07-19 — silence + stingers carry judging; see brief §1 note). Its written revisit condition fired: see M6 |
| `m6-judging.strudel` | M6 | Judging theme — ambient "underwater lobby" (M2's held 7ths + pad at half presence; new id, M4 stays retired) | **DONE ✓** (2026-08-10, polish session) |
| — | M5 | Wrap-up/ceremony theme | **CUT** (owner, 2026-07-19 — stingers carry the ceremony; M2-early-start is the fallback) |
| `cue-timer-warning.strudel` | — | Timer warning v2: four F4 beeps then A4 — the A4 lands ON the timer end (drawing + judging, one-shot) | **DONE ✓** (v2 2026-08-10 — replaces the 2026-07-19 escalating ladder) |
| `s1-race-start.strudel` | S1 | Race start — "duh duh duh duh-BEEP" countdown into drawing (every round; repurposed from whole-game start) | **DONE ✓** (2026-07-19) |
| `s2-prompt-reveal.strudel` | S2 | Prompt reveal — "ta-da-da-DAAA" climb-over run (word appears; dovetails with S1) | **DONE ✓** (2026-07-19) |
| `s3-times-up.strudel` | S3 | Time's up stinger | **CUT** (owner, 2026-08-10 wiring session — the timer cue's landing note IS the time's-up sound; id retired) |
| `s4-winner.strudel` | S4 | Per-round winner sting — "duh duh duh-DUH" | **DONE ✓** (2026-07-19) |
| `s6-title-awarded.strudel` | S6 | Title card — compact "dh-DUH" (S4's tail; wiring pitches each stack a step up) | **DONE ✓** (2026-07-19) |
| `s7-final-podium.strudel` | S7 | Final podium — S4's motif answered higher; the game's one grand fanfare | **DONE ✓** (2026-07-19) |
| `s8-round-transition.strudel` | S8 | Round transition | **CUT** (owner, 2026-08-10 wiring session — S2 covers it; id retired) |
| `sfx-chat-pop.strudel` | — | SFX: chat pop (incoming-message bloop) | **DONE ✓** (2026-07-19) |
| `sfx-button-press.strudel` | — | SFX: button press (triangle "tock", chat pop's deep cousin) | **DONE ✓** (2026-07-19) |
| `sfx-ready-click.strudel` | — | SFX: Done!/ready click (rising triangle pair — the "yes!" tock) | **DONE ✓** (2026-07-19) |
| `sfx-all-ready.strudel` | — | SFX: all-ready chime (three-note triangle rise) | **DONE ✓** (2026-07-19) |
| `sfx-toggle-on.strudel` | — | SFX: toggle ON tick (A4 triangle) | **DONE ✓** (2026-07-19) |
| `sfx-toggle-off.strudel` | — | SFX: toggle OFF tick (F4 triangle) | **DONE ✓** (2026-07-19) |
| `sfx-player-join.strudel` | — | SFX: player join (rising e-piano "hello") | **DONE ✓** (2026-07-19) |
| `sfx-player-leave.strudel` | — | SFX: player leave (falling e-piano goodbye) | **DONE ✓** (2026-07-19) |
| `sfx-text-stamp.strudel` | — | SFX: text stamp ("rip-THUMP" — paper tear + deep thump) | **DONE ✓** (2026-07-19) |
| `sfx-judge-latch.strudel` | — | SFX: judge card latch ("tk-TUK" click pair, second deeper) | **DONE ✓** (2026-07-19) |
| `sfx-eraser.strudel` | — | SFX: eraser (chalkboard scrub, three soft wipes) | **DONE ✓** (2026-07-19) |
| `sfx-undo-poof.strudel` | — | SFX: undo poof (breathy falling bottle-tone) | **DONE ✓** (2026-07-19) |
| `sfx-pause.strudel` | — | SFX: pause (staircase run down the wave, settles dark) | **DONE ✓** (2026-07-19) |
| `sfx-unpause.strudel` | — | SFX: unpause (staircase run up the wave, crests bright) | **DONE ✓** (2026-07-19) |
| `sfx-kudos.strudel` | — | SFX: kudos given ("da-DING" wooden gift — the winner sting's language) | **DONE ✓** (2026-07-19) |
| `sfx-reveal.strudel` | — | SFX: canvas reveal ("curtain pull" — pentatonic run into S4's accented octave landing; once per reveal beat) | **DONE ✓** (2026-08-10, polish session) |

(S5 retired 2026-07-14 with the emoji/superlatives removal — id not reused.)

**UI/social/canvas SFX** (button press, chat pop, kudos, join/leave, etc. — full list in brief §3): add as `sfx-<name>.strudel` if composed in Strudel; sourced/recorded ones don't need a file here, just a note in the brief.
