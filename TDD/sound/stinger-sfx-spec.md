# Stinger & SFX Composing Spec

**Status:** Owner-requested precise per-sound descriptions (2026-07-19). Companion to the [brief](../sound-design-brief.md) (§0 identity, §2–3 inventory) and the [README](README.md) index. Owner composes in Strudel; sources land here per file convention.

**Global rules (apply to everything below):**
- Pitched sounds sit on **F major pentatonic** notes (F G A C D) so every blip is in-key with the music
- SFX are **drier than music**: `room ≤ .15` (music runs .3–.5) — dry reads as "UI," wet reads as "song"
- Loudness ladder, top to bottom: S4/S7 → S1 → other stingers → all-ready chime + kudos → join/leave/chat/toast → button/toggle/canvas ticks (quietest)
- Everything under ~500 ms except stingers; nothing but S4/S7 gets low end + long tail at once
- **Short sounds don't build (owner, 2026-07-19):** stingers/SFX state their idea immediately — no swells, no intro gestures, no layer-unmasking. That's song architecture; a sting is 1–3 voices saying one thing once

---

## Stingers

**S1 — Race start** (~4.3 s). **FINAL (owner-approved 2026-07-19, source `s1-race-start.strudel`); REPURPOSED (owner):** fires when DRAWING begins, every round — not just at whole-game start (round 1's race start covers that moment; no separate lobby stinger planned). Mario Kart-style: three breathing unison duhs ~0.9 s apart (tuba F2 + marimba F4 + a ≤100 ms square transient), then "duh-BEEP" — a short arcade square GO at C6, envelope-limited to ~0.3 s. Wiring: the BEEP should land on the frame the drawing timer starts (mirror of the countdown cue's landing note). (First draft opened with a swell — owner cut it: short sounds don't build.)

**S2 — Prompt reveal** (~1.3 s). **FINAL (owner-approved 2026-07-19, source `s2-prompt-reveal.strudel`):** fast marimba run F4–G4–A4–C5 that doesn't stop at the landing — it climbs over through D5–F5 and finishes high on a held A5 ("ta-da-da-DAAA"). Single voice, no low end (never masks players reading the word aloud). Timing: fires at t=0 of the 4.0 s round intro; the S1 race start's duhs begin ~1.2 s later and its BEEP lands on drawing start — the pair scores the intro end-to-end. First candidate for trimming if playtests find rounds too noisy.

**S3 — Time's up** — **probably not needed** (the timer cue's 6th note is the landing). If an edge path ever wants it: single damped thunk, tuba F2 + muted-guitar F3, staccato, ~0.5 s.

**S4 — Winner announcement** (~2 s). **FINAL (owner-approved 2026-07-19, source `s4-winner.strudel`):** "duh duh duh-DUH" — marimba states C5… C5… quick C5-D5, landing on a held F5 with an octave sparkle and a single tuba F2 under the landing only. It fires at EVERY judge pick (per round), so it's short and human — no square lead, no build. (First draft was a 3 s layered fanfare; owner rejected the "spaceship tones" and length.)

**S6 — Title awarded** (~0.7 s). **FINAL (owner-approved 2026-07-19, source `s6-title-awarded.strudel`):** the winner motif's tail — "dh-DUH" (quick C5-D5 into F5) on marimba + high vibraphone with one short tuba root, compressed and tight-tailed for 3–6 back-to-back fires. Titles literally sound like a little piece of winning (quotes S4). Wiring trick, one asset: pitch each consecutive title one scale step higher — the ceremony becomes a rising ladder. (Quiet-delay draft and louder announce draft both rejected; owner wanted fanfare without repetition fatigue.)

**S7 — Final podium** (~4 s). **FINAL (owner-approved 2026-07-19, source `s7-final-podium.strudel`):** S4's "duh duh duh-DUH" motif stated, then answered a step higher; the second landing gets the warm Fmaj7 e-piano (M2's chord voice), a tuba root, and one high sparkle. Fires once, over silence, the instant the final standings (scores + title badges) appear. In Streamlined mode it's the only wrap-up sound. The game's single grand fanfare — the "roll credits" moment.

**S8 — Round transition** (~1 s). Only if S2 alone feels thin in playtests: a page-turn — marimba falling pair D5→A4, then a C5 pickup ("...and next!"). Dry, quick, skippable.

## Interaction SFX

1. **Button press** (~80 ms). **FINAL (owner-approved 2026-07-19, source `sfx-button-press.strudel`):** triangle "tock" at F3 with a −3 semitone pitch drop (`penv`), lpf 1200, near-dry — the deep cousin of the approved chat pop, so the whole UI speaks one triangle-plus-bend voice. (Marimba tick, deeper marimba, and upright-bass drafts all rejected.)
2. **Big button** (START GAME variant, ~150 ms): the same tock at F2 with decay ~.12 and a bit more gain — TODO, audition when convenient.
3. **Done!/ready click** (~200 ms). **FINAL (owner-approved 2026-07-19, source `sfx-ready-click.strudel`):** two rising triangle notes F4→C5 — the "yes!" answer to the button press (same triangle UI voice, opposite direction: press bends down, ready hops up).
4. **All-ready chime** (~400 ms). **FINAL (owner-approved 2026-07-19, source `sfx-all-ready.strudel`):** three rising triangle notes F4–A4–C5 — the completion of the ready click's two-note rise. Loud enough to announce the early advance over drawing music.
5. **Toggle/checkbox** (~50 ms). **FINAL (owner-approved 2026-07-19, sources `sfx-toggle-on.strudel` / `sfx-toggle-off.strudel`):** whisper-quiet triangle ticks — **A4 = ON, F4 = OFF** (pitch up = on, down = off). Two renders.

## Social SFX

6. **Chat pop** (~80 ms): soft triangle "bloop," pitch dropping A4→F4 across the note, sustain 0, dry, very quiet — after the drawing music this is the most-heard sound in the game; it must disappear into the background. (Wiring: randomize playback speed ±5% so rapid chats don't machine-gun.)
7. **Player join** (~300 ms). **FINAL (owner-approved 2026-07-19, source `sfx-player-join.strudel`):** warm e-piano rise F4→C5, small room. A little "hello" in M2's lobby voice.
8. **Player leave** (~300 ms). **FINAL (owner-approved 2026-07-19, source `sfx-player-leave.strudel`):** the mirror — C5→F4, quieter, darker (lpf 1600). A soft "goodbye," NOT a sad trombone.
9. **Kudos given** (~500 ms). **FINAL (owner-approved 2026-07-19, source `sfx-kudos.strudel`, option C "the wooden gift"):** a rising marimba pair "da-DING" (A4→F5) with one high octave shimmer on the landing — kudos speaks the winner sting's language. No delay echoes (v1's vibraphone-plus-delay draft rejected). Slightly more special than a UI click, pleasant on the twentieth hearing.

## Round-flow SFX

10. **Judge card latch** (~200 ms). **FINAL (owner-approved 2026-07-19, source `sfx-judge-latch.strudel`):** "tk-TUK" — a mechanical click pair where the second lands deeper (marimba F3→F2 under white-noise clicks), bone dry, no tail. ClickED into place, past tense.
11. **Card flip/reveal** (~120 ms): paper whip — white noise with hpf sweeping ~800→6000 Hz, capped by a marimba A4 tick. Bone dry: grid reveals fire in sequence and the overlaps must stay clean.
12. **Pause / unpause** (~1 s each). **FINAL (owner-approved 2026-07-19, sources `sfx-pause.strudel` / `sfx-unpause.strudel`, pair A "the staircase"):** one wave split in two — unpause rides UP a six-note triangle run (F pentatonic from F3, cresting on held F4, bright filter); pause rides DOWN the mirror run (settling on held F3, dark filter). Owner direction: the full updraft/downdraft, not a segment near the top. (E-piano pair and octave-glide drafts rejected — e-piano read too close to join/leave.)
13. **Error/deny** (~150 ms): single dead-note pluck — muted guitar F3 killed instantly, lpf snapping ~2000→500. An unmistakable "no" with zero harshness. **Kicked** = this pitched down an octave (F2, ~250 ms) — a heavier door.
14. **Toast** (~200 ms): neutral triangle A4 ping, soft attack, very quiet. Must not read good OR bad — toasts carry both kinds of news.

## Canvas SFX (pen scratch CUT — owner, 2026-07-19)

15. **Eraser** (~500 ms). **FINAL (owner-approved 2026-07-19, source `sfx-eraser.strudel`):** chalkboard scrubbing — three soft band-passed noise wipes (bpf 1100), first stroke longer, soft attacks so they read as rubbing. One-shot per eraser stroke.
16. **Text-stamp place** (~250 ms). **FINAL (owner-approved 2026-07-19, source `sfx-text-stamp.strudel`):** "rip-THUMP" — a crackly paper tear (crackle source, density 8) into a deep marimba F2 thump landing ~125 ms later. A touch louder than a button press; placing text is deliberate.
17. **Undo poof** (~300 ms). **FINAL (owner-approved 2026-07-19, source `sfx-undo-poof.strudel`):** a breathy falling bottle-tone — sine + noise mix (blowing across a bottle) with pitch dropping 5 semitones as it swells and vanishes (air sucked out), lpf-darkened tail. Also plays at undo markers in Slice 20 replays — the drawn-then-poof gag.
