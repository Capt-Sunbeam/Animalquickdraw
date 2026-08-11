# Sound Design Brief — Moment Inventory

**Status:** DRAFT (owner-requested inventory, 2026-07-11; **revised 2026-07-14 for Slice 19** — emoji reactions and superlatives were removed 2026-07-12, so the reaction SFX and superlative stinger are gone and the wrap-up description updated; **revised 2026-07-19** — M1 composed by the owner in Strudel, musical identity pinned below, M2/M3 direction decided, countdown tick reworked into the escalating 5-second timer cue). Sound remains its OWN future implementation session (decision log 2026-07-11) — this document is the asset shopping/composing list so the owner can source or create audio at their own pace, like the art workstreams.
**Lengths are targets, not rules.** Loops need a seamless loop point; stingers should end cleanly (natural decay).

---

## 0. Musical identity (pinned from the owner's M1, 2026-07-19)

The main-menu theme exists (owner-composed in Strudel) and defines the game's sound. Every other track and stinger should draw from this DNA so the whole game feels like one piece:

- **Key/scale:** F major pentatonic (melody F4–F5 register)
- **Chord loop:** F → Dm → B♭ → C (I–vi–IV–V)
- **Tempo:** 118 BPM (`setcpm(118/4)` in Strudel)
- **Instrument palette:** triangle swell pad, `gm_marimba` bounce, low-passed sawtooth bass, `gm_electric_guitar_muted` stabs, square-wave lead hook
- **Feel:** bouncy but relaxed; heavy low-pass filtering, light room reverb; arrangements build by unmasking layers over long cycles
- **On-theme rule of thumb:** stay in F, reuse at least one palette instrument per track. Tempo: 118 BPM or thereabouts — a guideline, not a law (M2 landed at a mellower 104; tempo-matching only matters if two tracks ever crossfade, and screens hard-switch music)
- **Sources live in [`TDD/sound/`](sound/):** one paste-ready Strudel file per asset + a README index that doubles as the composing to-do list (owner documentation feature, 2026-07-19). M1 is checked in there; every finished track gets its source added

---

## 1. Music loops

Loops should be 60–90 s before repeating (under ~45 s gets noticeably repetitive during long lobbies; over 2 min is wasted effort). All loop seamlessly.

| # | Track | Plays during | Target loop length | Character notes |
|---|-------|-------------|--------------------|-----------------|
| M1 | Main menu theme | Main menu, join dialog, avatar editor, collection browser, public browser | 60–90 s | **DONE ✓ (owner, Strudel, 2026-07-19)** — the identity tune; §0 pins its DNA |
| M2 | Lobby theme | Lobby + pool-word submission screen | 60–90 s | **DONE ✓ (owner, Strudel, 2026-07-19)** — elevator-music arrangement of M1: same melody on e-piano, 7th chords, half-time bass, 104 BPM; source in `sound/m2-lobby.strudel` |
| M3a | Drawing theme: ambient | DRAWING phase (host-pickable rotation) | 60–120 s | **DONE ✓ (owner, Strudel, 2026-07-19)** — the subtle one: triangle arp engine, upright bass, wandering vibraphone; `sound/m3-drawing-ambient.strudel` |
| M3b | Drawing theme: "oompa loompa banjo" | DRAWING phase (host-pickable rotation) | 60–120 s | **DONE ✓ (owner, Strudel, 2026-07-19)** — the upbeat one: ocarina whistle, oompah tuba, banjo skip; `sound/m3-drawing-oompa.strudel`. **Both ship (owner decision):** host multi-selects which drawing tracks are in the per-round rotation (new lobby setting, default all on; pool extensible with future tracks) |
| M6 | Judging theme ("the underwater lobby") | JUDGING (judge browsing) | ~40 s | **DONE ✓ (owner, 2026-08-10, polish session)** — ambient: M2's held 7ths + soft pad at half presence, no melody, no bass walk; sits UNDER voice chat, lets S4 land. The M4 cut's own revisit condition fired ("judging feels kind of dead"); new id, M4 stays retired. `sound/m6-judging.strudel` |
*(M4 judging and M5 wrap-up themes **CUT 2026-07-19, owner decision:** judging/reveal and the wrap-up ceremony are the stinger-dense, social-peak moments — music there competes with the SFX and with voice-chat joking, and the silence after the drawing track stops is itself a phase-change signal that makes S4/S6/S7 land harder. Revisit only if playtests feel empty; the fallback is starting M2 early at the wrap-up standings so the ceremony slides seamlessly back into the lobby. Ids retired, not reused.)*

Optional later: M3 "last 10 seconds" intensity layer (same tempo, added urgency, crossfaded in) — superseded in spirit by the escalating 5 s timer-warning cue; keep only if a longer ramp ever feels needed.

## 2. Stingers (one-shot musical moments)

| # | Moment | Trigger in game | Target length |
|---|--------|-----------------|---------------|
| S1 | Race start (repurposed, owner 2026-07-19) | Drawing begins, EVERY round; round 1's doubles as the game-start moment | **DONE ✓ (owner, 2026-07-19)** — "duh duh duh duh-BEEP" countdown; `sound/s1-race-start.strudel` |
| S2 | Prompt reveal | Round intro shows the word (t=0 of the 4 s intro; S1's countdown fills the rest) | **DONE ✓ (owner, 2026-07-19)** — "ta-da-da-DAAA" climb-over run; `sound/s2-prompt-reveal.strudel` |
| S3 | Time's up | Drawing timer hits zero | **CUT (owner, 2026-08-10)** — originally because the cue's landing note covered it; the cue v2 (polish session, same day) then removed the landing too: time's up is now intentionally unsounded — the next phase's audio carries the arrival |
| S4 | Winner announcement | Judge locks their pick → WinnerSpotlight | **DONE ✓ (owner, 2026-07-19)** — ~2 s "duh duh duh-DUH" marimba sting; `sound/s4-winner.strudel` |
| S6 | Title awarded | Each wrap-up title card (titles stack — may fire several times per player) | **DONE ✓ (owner, 2026-07-19)** — compact "dh-DUH"; `sound/s6-title-awarded.strudel` |
| S7 | Final podium | Wrap-up standings appear (with title badges) | **DONE ✓ (owner, 2026-07-19)** — S4's motif answered higher, Fmaj7 landing; `sound/s7-final-podium.strudel` |
| S8 | Round transition | RESOLUTION → next ROUND_INTRO | **CUT (owner, 2026-08-10)** — S2 covers it |

*(S5 "Superlative card reveal" removed 2026-07-14 — superlatives were cut with the Slice 19 emoji retirement. Id S5 retired, not reused.)*

## 3. UI & event SFX (tiny one-shots, 50–500 ms)

**Interaction set:**
| Sound | Trigger |
|-------|---------|
| Button press | Any button — **DONE ✓ (owner, 2026-07-19, `sound/sfx-button-press.strudel`)**; optional "big" START GAME variant still to audition |
| Button hover | Optional — skip if it gets noisy |
| Done!/ready click | Ready-up press — **DONE ✓ (owner, 2026-07-19, `sound/sfx-ready-click.strudel`)** |
| All-ready chime | Everyone ready → early advance — **DONE ✓ (owner, 2026-07-19, `sound/sfx-all-ready.strudel`)** |
| Toggle/checkbox | Settings toggles, Public checkbox — **DONE ✓ (owner, 2026-07-19, `sound/sfx-toggle-on/off.strudel`, 2 renders)** |

**Social set:**
| Sound | Trigger |
|-------|---------|
| Chat pop | Incoming chat message (not your own) |
| Player join | Roster gains a player (lobby + late join) — **DONE ✓ (owner, 2026-07-19, `sound/sfx-player-join.strudel`)** |
| Player leave | Roster loses a player (softer than join) — **DONE ✓ (owner, 2026-07-19, `sound/sfx-player-leave.strudel`)** |
| Kudos given | Kudos spend lands (slightly special — it's THE social currency now that reactions are gone) — **DONE ✓ (owner, 2026-07-19, `sound/sfx-kudos.strudel`)** |

**Round-flow set:**
| Sound | Trigger |
|-------|---------|
| **Timer-warning cue v2 (4 beeps + 1 higher, NO landing)** | **DONE ✓ v2 (owner, 2026-08-10, polish session)** — `sound/cue-timer-warning.strudel`, one-shot, never loops; replaces the 2026-07-19 escalating ladder (owner disliked it at both timer endings). End of the **drawing AND judging** timers: four identical soft triangle F4 beeps counting the last four seconds, then **the A4 lands exactly ON the phase change** (owner: the last note must end the timer precisely — the A4 is the landing; the ding after it was cut). **The music still fades smoothly INTO the cue** (wiring: landing-scheduled start at T−`CUE_LANDING_SEC` = 4.046 s measured; during drawing, fade music out across the cue's first ~1 s; with M6, judging needs the same fade) |
| Judge pick hover/latch | Judge latching a card in judging — **DONE ✓ (owner, 2026-07-19, `sound/sfx-judge-latch.strudel`)** |
| Card flip/reveal | Cards appearing in the reveal grid — **DONE ✓ (owner, 2026-08-10, polish session, `sound/sfx-reveal.strudel`)** — "curtain pull," once per reveal beat; GRID-style sub-decision deferred to wiring |
| Pause / unpause | Esc-menu pause + below-minimum auto-pause — **DONE ✓ (owner, 2026-07-19, `sound/sfx-pause.strudel` + `sfx-unpause.strudel`)** |
| Error/deny | Join failed, censored word rejected, invalid input |
| Toast | Any toast notification |
| Kicked | Kick landed (can reuse error/deny) |

**Canvas set (owner, 2026-07-19: pen scratch CUT; the other three are committed):**
| Sound | Trigger |
|-------|---------|
| Eraser | Eraser strokes (one-shot per stroke — no looping stroke audio now that pen scratch is cut) — **DONE ✓ (owner, 2026-07-19, `sound/sfx-eraser.strudel`)** |
| Text place | Text stamp dropped on canvas — **DONE ✓ (owner, 2026-07-19, `sound/sfx-text-stamp.strudel`)** |
| Undo poof | Undo action (also heard at undo markers in Slice 20 replays) — **DONE ✓ (owner, 2026-07-19, `sound/sfx-undo-poof.strudel`)** |

**Per-sound composing spec:** every stinger and SFX above is precisely described (voice, notes, envelope, length, character) in [`sound/stinger-sfx-spec.md`](sound/stinger-sfx-spec.md) (2026-07-19).

## Priority guidance (if sourcing/composing incrementally)

1. **First pass that transforms the feel:** M1 (menu — ✓ done), M3a/M3b (drawing — ✓ done), S4 (winner), button press, chat pop, timer-warning cue (— ✓ done)
2. **Second pass:** S7 (podium — M5 cut), M2 (lobby — ✓ done), Done! click, join/leave, kudos
3. **Polish pass:** everything else, canvas set last

## Technical notes (for the future implementation session — not now)

- Godot wants **OGG Vorbis** for music (loop points supported on import) and **WAV** for short SFX
- Implementation will be an `AudioService` autoload listening to existing EventBus signals (phase_changed, titles_awarded, chat, roster changes...) — the moments above map almost 1:1 onto signals that already exist, so the wiring session is mostly asset hookup
- Volume buses (Master/Music/SFX) + a settings surface for them — scope for the sound session
- **Drawing-music picker (owner, 2026-07-19):** new lobby setting — host multi-selects which drawing tracks are in the rotation (default: all enabled); per-round rotation through the enabled set (shuffled order, no repeats until the set is exhausted) rather than pure random; rides the existing Slice 6 settings sync/snapshot machinery; track pool extensible later
