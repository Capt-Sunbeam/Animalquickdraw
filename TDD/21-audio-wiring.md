# Slice 21 (mini): Audio Wiring

**Version:** 1.0 (owner decisions resolved 2026-08-10 — see §6)
**Created:** 2026-08-10 (session 16) — the queued sound WIRING session (all 25 assets rendered + owner-approved in `assets/audio/`, session 15)
**Dependencies:** every shipped slice's EventBus signals; Slice 6 settings machinery (track picker); Slice 20 ReplayPlayer (undo poof in replays)
**Companion docs:** `TDD/sound-design-brief.md` (moment inventory + §0 identity), `TDD/sound/README.md` (asset index + render table)

---

## 1. Overview

Wire the 25 rendered audio assets into the game: an `AudioService` autoload listening to EventBus, Music/SFX volume buses with a settings surface, the host-picked drawing-track rotation (new lobby setting), and the escalating timer cue at T−5.0 s. No new networking — every "global" sound hooks a signal the host already broadcasts.

**The one rule:** `AudioService` is never networked. Each instance plays sounds in response to (a) EventBus signals — global sounds fall out of signals that fire on all peers, local sounds out of local-only signals — and (b) direct `AudioService.play_sfx()` calls from UI for screen-local moments. Sounds are **event-synced, not sample-synced** (industry standard; players are on separate machines).

## 2. Design

### Buses & assets
- `default_bus_layout.tres`: Master → **Music**, **SFX**. Registered in `project.godot` `[audio]`.
- Volumes persist in `profile.json` under `"audio": {"master": 1.0, "music": 1.0, "sfx": 1.0}` (linear 0–1, applied via `linear_to_db`). `AudioPrefs` follows the `PublicNoticeGate.path` test-seam pattern — tests never touch the real profile.
- Music OGGs import with `loop = true` (whole-file loops per the render design); WAVs stay one-shot. **First step: run `godot --headless --path . --import`** — no audio `.import` artifacts exist yet.

### AudioService autoload (`core/audio/audio_service.gd`, autoload position 8 — last, after Stats)
- Preloads all 25 streams into typed dicts keyed by asset id.
- **Music:** two `AudioStreamPlayer`s (Music bus) for crossfades. A pure function `_desired_music(route, phase, drawing_track) -> StringName` decides the track; called from both `EventBus.scene_changed` AND `EventBus.phase_changed` (Nav drives screen-level, phase drives in-round — RoundRoot phase panels are not Nav navigations).
- **SFX:** small pool of `AudioStreamPlayer`s (SFX bus) round-robined by `play_sfx(id, pitch_scale := 1.0)`; polyphonic, never cuts a playing one-shot.
- Headless/CI: all playback is inert without an audio device; tests assert *state* (current music id, cue armed), never audible output. Gate drivers need zero changes.

### Music map
| Where | Track |
|---|---|
| Menu, join dialog, avatar editor, collection, public browser, canvas sandbox | M1 |
| Lobby + POOL_SETUP phase | M2 |
| ROUND_INTRO + DRAWING | round's M3 track (see rotation) |
| REVEAL, JUDGING, RESOLUTION, WRAP_UP | **silence** — stingers carry (M4/M5 cut 2026-07-19; M2-early-start fallback stays parked) |
| PAUSED | **fade to silence** (owner, §6 D2); fade back in on resume if the resumed phase has music |

Crossfade ~0.5 s on screen changes; the DRAWING → REVEAL/JUDGING transition is a fade-to-silence (unless the timer cue already faded it — see below).

### Drawing-track rotation (the ONLY new networked data — rides existing machinery)
- **New setting** `drawing_tracks: int` — bitmask, bit 0 = M3a ambient, bit 1 = M3b oompa (extensible). Default `3` (all on). Touches all five `settings.gd` points (`var`, `_assign`, `to_dict`, `from_dict` default, clamp: `value & VALID_MASK`, and `== 0` resets to all — the set can never be empty). Added to every preset dict (+ preset validation test). Lock status per §6 D4.
- **Lobby UI:** host-only checkbox row ("Drawing music: ☑ Ambient ☑ Oompa") following the `PublicCheck` pattern in `lobby_screen`.
- **Host pick:** `GameSession._begin_round()` draws from a shuffled bag over the enabled set using the session `rng` (no repeats until exhausted, reshuffle after; deterministic → testable). Track id rides the **ROUND_INTRO payload** (`"music_track": "m3-drawing-ambient"`) — built once per round at game_session.gd `_begin_round`, giving clients the 4 s intro to preload. Client caches it in the `ROUND_INTRO` match arm of `rpc_sync_phase`; unknown/missing id falls back to ambient (tolerant-payload rule).

### Timer cue (T−5.0 s, DRAWING + JUDGING)
- The 6.0 s WAV: five rising notes at t=0–4 s, landing note at t=5.0 s, tail to 6.0 s. Start playback at `deadline_ms − 5000` → the landing note lands on the phase change (within network latency; clients schedule off the same host-broadcast absolute deadline the visible countdown uses).
- Implemented by polling in `_process` against the cached deadline (no cancellable timers to leak): entering DRAWING/JUDGING arms the cue; when `remaining ≤ 5.0 s` and unplayed → play. **Pause-safe by construction:** `game_paused` disarms; resume re-enters the phase via a fresh `rpc_sync_phase` with a NEW `deadline_ms`, which re-arms. If a phase *starts* with < 5 s remaining, the cue starts mid-file at the matching offset so the landing still aligns.
- During DRAWING the music fades out across the cue's first ~1 s (owner requirement: smooth fade INTO the cue); JUDGING is already silent.
- Early advance (all-ready) while the cue plays → stop the cue at the phase change (no landing; S-transition sounds cover it).

### Stinger + SFX signal map
**Global (signal fires on all peers):**
| Sound | Hook |
|---|---|
| S2 prompt reveal, then S1 race start | `phase_changed` → ROUND_INTRO: S2 at t=0, S1 immediately after-ish (S1's BEEP at ~4.0 s lands on the DRAWING frame; 0.3 s tail overhangs by design) |
| S4 winner | `round_resolved` (fires before RESOLUTION's `phase_changed`) |
| S6 title card / S7 podium | direct calls from `wrap_up_screen._next_card()` (card pacing is screen-local); S6 pitch ladder: `pitch_scale` steps up per stacked title for the same player |
| Kudos | `kudos_total_changed` — everyone hears kudos land (owner: global) |
| Player join / leave | `roster_updated` count-diff (covers lobby + in-game), baselined on session join so your own arrival snapshot is silent; kick → leave sound |
| All-ready chime | `ready_state_changed` when the ready set covers all eligible non-judge actives (AudioService computes from its roster mirror) |
| Pause / unpause | `game_paused` / `game_resumed` |
| Chat pop | `chat_message_received`, skipped when sender is self; ±5 % pitch jitter |

**Local (local-only signal or direct UI call):**
| Sound | Hook |
|---|---|
| Button press | auto-hook (below) |
| Toggle on/off | auto-hook, `toggle_mode` special case |
| Ready click | Done!/Unready button via meta override |
| Judge latch | `judge_pick_latched` (never networked) |
| Eraser / text stamp | canvas local input (stroke start / stamp drop) — **never** from `DrawingDoc` op application, or you'd hear remote players' tools |
| Undo poof | local undo press + `ReplayPlayer` UndoOp application (replays run per-peer → everyone hears replay poofs; intended, matches Slice 20) |

### Button-press auto-hook
No shared button component exists (17 scenes of plain `Button`s); the theme can't carry signals. `AudioService` connects to `SceneTree.node_added`: every `BaseButton` gets `pressed` → click SFX. `toggle_mode` buttons route to toggle-on/off by state (CheckBox/OptionButton inherit Button here — desired). **Opt-out/override via meta:** `set_meta("click_sfx", &"none")` (judging CardButtons — judge latch has its own sound; kudos button — the global ding covers it) or `set_meta("click_sfx", &"ready-click")` (Done! button). Absent meta = default click.

### Volume settings surface (per §6 D3)
Shared `AudioSettingsPanel` (three sliders: Master/Music/SFX, live-applied, saved on change) mounted in: (a) the Esc `GameMenu` — its first settings section, and (b) the main menu via a new small Options dialog (AcceptDialog, paper-skinned). First options surface in the game.

## 3. Edge cases
- Host leaves mid-round / return to lobby → music re-decides from route (`session_closed` → menu → M1); cue disarmed on any phase exit.
- Late joiner mid-DRAWING: welcome snapshot's phase data carries no `music_track` (ROUND_INTRO already passed) → fallback ambient this round, correct from next round. (Acceptable; noted for qa-backlog.)
- Rejoin/resume: fresh `deadline_ms` re-arms the cue correctly; music re-decides.
- `draw_time_sec` < 5 s can't happen (clamp ≥ 15 s) but the mid-file-offset branch guards it anyway.
- Replay poofs during victory lap / collection viewer replays: same ReplayPlayer path — plays everywhere replays play. SFX bus, so muting SFX silences them.
- Two SFX same frame (e.g. all-ready chime + phase change): polyphonic pool absorbs it.

## 4. Testing
- Settings: `drawing_tracks` round-trip, clamp (invalid bits stripped, 0 → all), preset validation test updated, lock behavior.
- Rotation bag: seeded rng → deterministic order, no repeat until exhausted, single-track set degenerates to that track, payload carries the id.
- `_desired_music` pure-function table test (route × phase matrix).
- Cue math: arm/disarm on phase transitions, T−5.0 s trigger vs deadline, pause disarm + resume re-arm, mid-file offset when remaining < 5 s.
- Auto-hook: synthetic tree with Button/CheckBox/meta-override nodes → correct sfx id chosen (state assert, no audio).
- Roster diff: baseline suppression, join/leave/kick classification.
- All 3 gates PASS (audio must be inert headless).
- **Owner ear pass (blocking):** full game with sound — music transitions, cue landing feel, stinger timing, mix levels. Per workflow memory: announce before any audible run.

## 5. Checklist
- [x] Import pass; `default_bus_layout.tres`; OGG loop flags
- [x] `Audio` autoload: streams, music crossfade, SFX pool, volume prefs (+ test seam)
- [x] Music map + `_desired_music` (+ tests) — intro is music-silent, deviation logged
- [x] Timer cue (+ tests) — landing measured at 5.05 s
- [x] `drawing_tracks` setting + lobby UI (+ tests) — NOT in presets, deviation logged
- [x] Host rotation bag + ROUND_INTRO payload (+ tests) — no client cache needed, Audio reads the payload
- [x] Stinger/SFX hooks per map (S1 landing-scheduled @2.84 s, S2, S4, S6+ladder, S7, kudos, join/leave, all-ready via early-transition detection, pause, chat jitter)
- [x] Button auto-hook + meta overrides
- [x] Canvas local SFX (eraser, stamp, undo) + `attach_replay_poof` at all 4 replay hosts
- [x] `AudioSettingsPanel` in GameMenu + main-menu Options dialog
- [x] Full suite (600) + 3 gates PASS; docs done — **owner ear pass PENDING (blocking)**

---

## COMPLETION STATUS (2026-08-10, session 16)

**IMPLEMENTED + machine-verified.** 600 tests green (+19); verify_lobby / verify_round / verify_resilience all PASS. Deviations + measured constants in `21-audio-wiring-implementation-notes.md`. **Blocking owner check: the ear pass** — full game with sound (music transitions, cue landing, S1 BEEP alignment, mix levels); batchable ear items in qa-backlog §21.

## 6. Resolved decisions (owner, 2026-08-10)
- **D1 — S3/S8 officially CUT:** the cue's landing note IS the time's-up sound; S2 covers round transitions. Ids retired, not reused (S3/S8 rows in the sound README flip to CUT).
- **D2 — Music FADES TO SILENCE on pause** (owner chose over keep-playing): `game_paused` → music fade-out (~0.5 s); `game_resumed` → fade back in if the resumed phase has music. Pause/unpause SFX still play.
- **D3 — Volume surface:** shared `AudioSettingsPanel` in the Esc `GameMenu` + a new paper-skinned Options dialog on the main menu.
- **D4 — `drawing_tracks` joins `ALWAYS_TUNABLE`** — host can change it in every mode.
