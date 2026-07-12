# Sound Design Brief — Moment Inventory

**Status:** DRAFT (owner-requested inventory, 2026-07-11). Sound remains its OWN future implementation session (decision log 2026-07-11) — this document is the asset shopping/composing list so the owner can source or create audio at their own pace, like the art workstreams.
**Lengths are targets, not rules.** Loops need a seamless loop point; stingers should end cleanly (natural decay).

---

## 1. Music loops

Loops should be 60–90 s before repeating (under ~45 s gets noticeably repetitive during long lobbies; over 2 min is wasted effort). All loop seamlessly.

| # | Track | Plays during | Target loop length | Character notes |
|---|-------|-------------|--------------------|-----------------|
| M1 | Main menu theme | Main menu, join dialog, avatar editor, collection browser, public browser | 60–90 s | The game's identity tune. Relaxed, inviting |
| M2 | Lobby theme | Lobby + pool-word submission screen | 60–90 s | Social/waiting energy; can be a variation of M1 (same melody, different arrangement) so menu→lobby feels connected |
| M3 | Drawing theme | DRAWING phase | 60–120 s | Focus + gentle urgency; must not fight concentration — think "pleasant background scribble energy" |
| M4 | Judging/reveal theme | Reveal grid + judge deliberation | 45–60 s | Curious/suspenseful, lighter than M3 |
| M5 | Wrap-up theme | Whole wrap-up sequence (superlatives → titles → standings) | 60–90 s | Celebratory; the stingers below play OVER it, so leave dynamic headroom |

Optional later: M3 "last 10 seconds" intensity layer (same tempo, added urgency, crossfaded in) — nice-to-have, not needed for a first pass.

## 2. Stingers (one-shot musical moments)

| # | Moment | Trigger in game | Target length |
|---|--------|-----------------|---------------|
| S1 | Game start | Host presses START GAME → round intro | 2–4 s |
| S2 | Prompt reveal | Round intro shows the word | 1–2 s |
| S3 | Time's up | Drawing timer hits zero | 1–2 s |
| S4 | Winner announcement | Judge locks their pick → WinnerSpotlight | 2–4 s (the big one — fanfare) |
| S5 | Superlative card reveal | Each wrap-up superlative | 1–2 s |
| S6 | Title awarded | Each wrap-up title card | 1–2 s |
| S7 | Final podium | Wrap-up standings appear | 3–5 s (second-biggest moment) |
| S8 | Round transition | RESOLUTION → next ROUND_INTRO | 1–2 s (can double as S2) |

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
| Reaction sent/landed | Emoji reaction appears on a card |
| Kudos given | Kudos spend lands (slightly special — it's the social currency) |

**Round-flow set:**
| Sound | Trigger |
|-------|---------|
| Countdown tick | Last 5–10 s of drawing timer (one tick sound, repeated) |
| Judge pick hover/latch | Judge latching a card in judging |
| Card flip/reveal | Cards appearing in the reveal grid |
| Pause / unpause | Esc-menu pause + below-minimum auto-pause |
| Error/deny | Join failed, censored word rejected, invalid input |
| Toast | Any toast notification |
| Kicked | Kick landed (can reuse error/deny) |

**Canvas set (all optional — test for annoyance before committing):**
| Sound | Trigger |
|-------|---------|
| Pen scratch | While actively drawing a stroke (very quiet, looping while stroke held) |
| Eraser | Eraser strokes |
| Text place | Text stamp dropped on canvas |
| Undo | Undo action |

## Priority guidance (if sourcing/composing incrementally)

1. **First pass that transforms the feel:** M1 (menu), M3 (drawing), S4 (winner), button press, chat pop, countdown tick
2. **Second pass:** M5 + S7 (wrap-up), M2 (lobby), Done! click, join/leave, kudos
3. **Polish pass:** everything else, canvas set last

## Technical notes (for the future implementation session — not now)

- Godot wants **OGG Vorbis** for music (loop points supported on import) and **WAV** for short SFX
- Implementation will be an `AudioService` autoload listening to existing EventBus signals (phase_changed, titles_awarded, chat, roster changes...) — the moments above map almost 1:1 onto signals that already exist, so the wiring session is mostly asset hookup
- Volume buses (Master/Music/SFX) + a settings surface for them — scope for the sound session
