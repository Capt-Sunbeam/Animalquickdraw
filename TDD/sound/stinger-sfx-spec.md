# Stinger & SFX Composing Spec

**Status:** Owner-requested precise per-sound descriptions (2026-07-19). Companion to the [brief](../sound-design-brief.md) (§0 identity, §2–3 inventory) and the [README](README.md) index. Owner composes in Strudel; sources land here per file convention.

**Global rules (apply to everything below):**
- Pitched sounds sit on **F major pentatonic** notes (F G A C D) so every blip is in-key with the music
- SFX are **drier than music**: `room ≤ .15` (music runs .3–.5) — dry reads as "UI," wet reads as "song"
- Loudness ladder, top to bottom: S4/S7 → S1 → other stingers → all-ready chime + kudos → join/leave/chat/toast → button/toggle/canvas ticks (quietest)
- Everything under ~500 ms except stingers; nothing but S4/S7 gets low end + long tail at once

---

## Stingers

**S1 — Game start** (~2.5 s). M1's intro gesture as a launchpad: triangle pad on F2+C3, slow attack (~.4), low-pass sweeping open ~500→2500 Hz across ~1.2 s — then everything lands on ONE unison downbeat hit: tuba F2 + marimba F4 + square F5, short ring-out. Message: "here we go."

**S2 — Prompt reveal** (~1 s). Fast marimba run up F4–G4–A4–C5–D5 at grace-note speed (~60–80 ms per note), last note D5 accented with a little room. A curtain-flick "ta-da." No low end — it must never mask players reading the word aloud.

**S3 — Time's up** — **probably not needed** (the timer cue's 6th note is the landing). If an edge path ever wants it: single damped thunk, tuba F2 + muted-guitar F3, staccato, ~0.5 s.

**S4 — Winner announcement** (~3 s). THE fanfare, built from M1's hook voice (square + its −12 octave echo). Pickup C5–D5 (16th-note pace) → **F5 held** ~0.8 s with vibrato (`vib(5).vibmod(.3)`) → step up to **A5 held** with a fast marimba roll (A4+D5 alternating) underneath → release into a falling marimba sparkle D5–C5–A4. Saw/tuba bass F2 punctuates the two held-note downbeats. Loudest sound in the game except S7.

**S6 — Title awarded** (~0.8 s). Vibraphone two-note A4→D5, soft attack, M3a's delay (`.delay(.25).delaytime(.375)`), **zero bass content**, modest gain — designed to fire back-to-back during the ceremony (titles stack) without piling into mud. Wiring-session trick, one asset: pitch successive fires up one scale step per stacked title.

**S7 — Final podium** (4–5 s). S4's skeleton, orchestrated up: Fmaj7 e-piano stab (f3,a3,c4,e4) under each held note, a second rising phrase F5→A5→C6, and a final full-palette F-major unison (tuba F2, e-piano Fmaj7, marimba F5, square A5) left ringing ~1.5 s with the biggest room of any sound (~.5). The "roll credits" moment.

**S8 — Round transition** (~1 s). Only if S2 alone feels thin in playtests: a page-turn — marimba falling pair D5→A4, then a C5 pickup ("...and next!"). Dry, quick, skippable.

## Interaction SFX

1. **Button press** (~80 ms): single marimba F4, instant attack, decay ~.08, sustain 0, lpf ~3000, near-dry, quiet. A woody tick — matches the paper UI.
2. **Big button** (START GAME variant, ~150 ms): same gesture with more mass — marimba F3 layered over a soft tuba F2, slightly longer decay. Same family, bigger body.
3. **Done!/ready click** (~150 ms): two grace notes flicking upward, C5→F5 marimba ~40 ms apart, tiny room. A "check!" that feels rewarding to press.
4. **All-ready chime** (~600 ms): vibraphone arpeggio F4–A4–C5 (~90 ms apart) with light delay. Bright and legible over the drawing music — it announces the early advance.
5. **Toggle/checkbox** (~50 ms): whisper-quiet marimba tick — **A4 for ON, F4 for OFF** (pitch up = on, down = off).

## Social SFX

6. **Chat pop** (~80 ms): soft triangle "bloop," pitch dropping A4→F4 across the note, sustain 0, dry, very quiet — after the drawing music this is the most-heard sound in the game; it must disappear into the background. (Wiring: randomize playback speed ±5% so rapid chats don't machine-gun.)
7. **Player join** (~300 ms): warm e-piano rise F4→C5, small room. A little "hello."
8. **Player leave** (~300 ms): the mirror — C5→F4, quieter, darker (lpf ~1500), faster decay. A soft "goodbye," NOT a sad trombone.
9. **Kudos given** (~600 ms): the special one — marimba + vibraphone in unison, grace C5→D5, with M3a's delay trailing two echoes. A warm gift-sparkle, not a slot machine. Sits slightly louder than the other social sounds.

## Round-flow SFX

10. **Judge card latch** (~80 ms): physical "thock" — marimba F3 plus a ~10 ms noise-click transient, dead dry. A stamp landing.
11. **Card flip/reveal** (~120 ms): paper whip — white noise with hpf sweeping ~800→6000 Hz, capped by a marimba A4 tick. Bone dry: grid reveals fire in sequence and the overlaps must stay clean.
12. **Pause / unpause** (~400 ms each): one mechanism, two directions. Pause: e-piano A4→D4 with the low-pass closing ~2500→800 ("world on hold"). Unpause: D4→A4 with the filter reopening.
13. **Error/deny** (~150 ms): single dead-note pluck — muted guitar F3 killed instantly, lpf snapping ~2000→500. An unmistakable "no" with zero harshness. **Kicked** = this pitched down an octave (F2, ~250 ms) — a heavier door.
14. **Toast** (~200 ms): neutral triangle A4 ping, soft attack, very quiet. Must not read good OR bad — toasts carry both kinds of news.

## Canvas SFX (pen scratch CUT — owner, 2026-07-19)

15. **Eraser** (~120 ms): two low-passed noise puffs (lpf ~900), ~60 ms each, whisper-quiet. One-shot per eraser stroke.
16. **Text-stamp place** (~100 ms): paper thump — marimba F3 + a noise tap, a touch louder than button press (placing text is a deliberate act).
17. **Undo poof** (~220 ms): an air puff — noise burst, bandpass sweeping ~1200→400 Hz, soft almost-reversed attack, **no pitch content** (spam-undo safe). Quiet. Also plays at undo markers in Slice 20 replays — it's part of the replay's drawn-then-poof gag, so keep it charming.
