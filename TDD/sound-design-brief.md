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
*(M4 judging and M5 wrap-up themes **CUT 2026-07-19, owner decision:** judging/reveal and the wrap-up ceremony are the stinger-dense, social-peak moments — music there competes with the SFX and with voice-chat joking, and the silence after the drawing track stops is itself a phase-change signal that makes S4/S6/S7 land harder. Revisit only if playtests feel empty; the fallback is starting M2 early at the wrap-up standings so the ceremony slides seamlessly back into the lobby. Ids retired, not reused.)*

Optional later: M3 "last 10 seconds" intensity layer (same tempo, added urgency, crossfaded in) — superseded in spirit by the escalating 5 s timer-warning cue; keep only if a longer ramp ever feels needed.

## 2. Stingers (one-shot musical moments)

| # | Moment | Trigger in game | Target length |
|---|--------|-----------------|---------------|
| S1 | Game start | Host presses START GAME → round intro | 2–4 s |
| S2 | Prompt reveal | Round intro shows the word | 1–2 s |
| S3 | Time's up | Drawing timer hits zero | 1–2 s — **possibly superseded** by the timer cue's built-in 6th-note landing (owner cue design 2026-07-19); decide at wiring |
| S4 | Winner announcement | Judge locks their pick → WinnerSpotlight | 2–4 s (the big one — fanfare) |
| S6 | Title awarded | Each wrap-up title card (titles stack — may fire several times per player) | 1–2 s |
| S7 | Final podium | Wrap-up standings appear (with title badges) | 3–5 s (second-biggest moment) |
| S8 | Round transition | RESOLUTION → next ROUND_INTRO | 1–2 s (can double as S2) |

*(S5 "Superlative card reveal" removed 2026-07-14 — superlatives were cut with the Slice 19 emoji retirement. Id S5 retired, not reused.)*

## 3. UI & event SFX (tiny one-shots, 50–500 ms)

**Interaction set:**
| Sound | Trigger |
|-------|---------|
| Button press | Any button (one generic + optionally a "big" variant for START GAME) |
| Button hover | Optional — skip if it gets noisy |
| Done!/ready click | Ready-up press (distinct, satisfying) |
| All-ready chime | Everyone ready → early advance |
| Toggle/checkbox | Settings toggles, Public checkbox |

**Social set:**
| Sound | Trigger |
|-------|---------|
| Chat pop | Incoming chat message (not your own) |
| Player join | Roster gains a player (lobby + late join) |
| Player leave | Roster loses a player (softer than join) |
| Kudos given | Kudos spend lands (slightly special — it's THE social currency now that reactions are gone) |

**Round-flow set:**
| Sound | Trigger |
|-------|---------|
| **Timer-warning cue (5 s + landing, escalating)** | **DONE ✓ (owner, Strudel, 2026-07-19)** — `sound/cue-timer-warning.strudel`, one-shot, never loops. Cuts in for the last 5 seconds of the **drawing AND judging** timers: five rising F-pentatonic notes (one per second), then a **6th note that lands exactly ON the phase change** out of the timed screen. **Owner requirement: the music fades smoothly INTO the cue** — countdown well heard, no rough cut (wiring: start cue at T−5.0 s; during drawing, fade music out across the cue's first ~1 s; judging is already music-free). Open question for wiring: the built-in landing note may supersede S3 |
| Judge pick hover/latch | Judge latching a card in judging |
| Card flip/reveal | Cards appearing in the reveal grid |
| Pause / unpause | Esc-menu pause + below-minimum auto-pause |
| Error/deny | Join failed, censored word rejected, invalid input |
| Toast | Any toast notification |
| Kicked | Kick landed (can reuse error/deny) |

**Canvas set (owner, 2026-07-19: pen scratch CUT; the other three are committed):**
| Sound | Trigger |
|-------|---------|
| Eraser | Eraser strokes (one-shot per stroke — no looping stroke audio now that pen scratch is cut) |
| Text place | Text stamp dropped on canvas |
| Undo poof | Undo action (also heard at undo markers in Slice 20 replays) |

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
