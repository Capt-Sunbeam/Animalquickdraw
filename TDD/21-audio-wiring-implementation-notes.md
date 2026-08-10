# Slice 21 Implementation Notes — Audio Wiring

**Implemented:** 2026-08-10 (session 16). 600 tests green (+19 over session 14's 581); all 3 gates PASS. **Owner ear pass pending (blocking)** — machine verification can't judge a mix.

---

## What was built

- **`Audio` autoload** (`core/audio/audio_service.gd`, position 8 — last): preloaded stream dicts (4 OGG music, 21 WAV one-shots), two-player music crossfade (0.5 s), 8-player round-robin SFX pool, dedicated cue player, volume prefs, button auto-hook, all EventBus wiring.
- **Buses:** `core/audio/default_bus_layout.tres` (Master → Music, SFX) + `project.godot` `[audio]`. Volumes persist in `profile.json` `"audio"` (linear 0–1; 0 also mutes the bus). `Audio.profile_path` is the test seam (PublicNoticeGate pattern).
- **Music map** (`_desired_music`, pure on route+phase+track): menu family → M1; lobby + POOL_SETUP → M2; DRAWING → the round's M3 track; everything else (incl. ROUND_INTRO, PAUSED) → silence.
- **Timer cue:** armed by `deadline_ms` on DRAWING/JUDGING `phase_changed`; `_process` polls and fires at T−5.05 s (measured landing-note onset); drawing music fades out across the cue's first ~1 s; late arm plays mid-file so the landing still aligns; pause disarms (resume's fresh deadline re-arms); early exit cuts it, natural expiry lets it ring (`LANDING_GRACE_MS` = 500 distinguishes).
- **S1 scheduling:** same landing logic — S1 starts so its measured BEEP onset (2.84 s) lands on the ROUND_INTRO deadline = the drawing-start frame. S2 plays at intro t=0.
- **Rotation:** `GameSettings.drawing_tracks` bitmask (always-tunable, never preset-carried, clamp strips invalid bits and resets empty→ALL); host `GameSession._next_music_track()` shuffled bag on the session rng; track id rides the ROUND_INTRO payload as `"music_track"`; lobby row = two CheckBoxes (Ambient/Oompa).
- **Global SFX:** kudos (`kudos_total_changed`), chat pop (self-skipped, ±5 % pitch jitter), lobby join/leave (roster count-diff, baselined), in-game join/leave (`player_late_joined`/`rejoined`/`dropped`/`kicked`), pause/unpause, S4 on `round_resolved`, judge latch on `judge_pick_latched`.
- **All-ready chime:** played when a timed phase ends EARLY along DRAWING→REVEAL or JUDGING→RESOLUTION (deadline still > 500 ms away) — early end only happens via the Slice 17 all-ready advance, so no roster/judge bookkeeping is needed. PAUSED is excluded by the transition pairing.
- **Button auto-hook:** `SceneTree.node_added` connects `pressed` on every `BaseButton`; `toggle_mode` routes to toggle-on/off by state; `click_sfx` meta = `"none"` (kudos button, judging cards) or an sfx id override (`"sfx-ready-click"` on Done!/ready buttons).
- **Canvas/local:** eraser one-shot at local stroke begin (never from op application), text stamp at commit, undo poof at `_press_undo`; replays poof via `Audio.attach_replay_poof(player, doc)` (connects `op_started`, checks `UndoOp`) at all four ReplayPlayer hosts.
- **Wrap-up:** S6 per title card with pitch ladder (whole step per stacked title for the same player, `2^(stack/6)`); S7 on the standings act.
- **Volume UI:** `AudioSettingsPanel` (shared, code-built, debounced save) in GameMenu under Leave + `OptionsDialog` (AcceptDialog, code-built) behind a new main-menu Options button.

## Deviations from TDD 21

1. **Autoload named `Audio`, not `AudioService`** — matches the project's short autoload style (Nav/Net/Save/Stats).
2. **No SessionClient change at all** — the TDD planned caching `music_track` in the client's ROUND_INTRO match arm; `Audio` reads the `phase_changed` payload directly, so the payload plumbing needed zero touched lines outside `game_session.gd`.
3. **ROUND_INTRO is music-silent** (TDD §2 table said intro+drawing) — the brief's M3 row says DRAWING only; the stingers own the intro and M3 punching in on S1's BEEP is the stronger moment.
4. **`drawing_tracks` not added to preset dicts** (TDD said add + update preset test) — presets not carrying it means mode switches never reset music taste (round_count/pool_source precedent). No preset test change needed.
5. **Canonical track list lives in `GameConstants.DRAWING_MUSIC_TRACKS`** (append-only), not in Audio — `game/` sim code must not depend on an audio autoload. Audio validates payload ids against it; a test pins that every entry has a stream.
6. **Cue + stingers ride the SFX bus** — the cue is game information (timer warning); muting Music must not silence it.
7. **All-ready chime via early-transition detection** — the TDD's "AudioService computes eligibility from its roster mirror" was dropped as needless bookkeeping (see above).

## Measured constants (owner's renders, waveform-analyzed this session)

| Constant | Value | Meaning |
|---|---|---|
| `CUE_LANDING_SEC` | 5.05 | landing-note onset in cue-timer-warning.wav (6.00 s file; notes at ~0.05/1.05/…/4.05) |
| `S1_BEEP_SEC` | 2.84 | BEEP onset in s1-race-start.wav (4.52 s file; duhs at 0.05/0.91/1.77/2.62, quick duh-BEEP) |

## Files created/modified

**New:** `core/audio/audio_service.gd`, `core/audio/default_bus_layout.tres`, `ui/shared/audio_settings_panel.gd`, `ui/menu/options_dialog.gd`, `tests/core/audio/test_audio_service.gd`, `tests/game/session/test_music_rotation.gd`, `TDD/21-audio-wiring.md`, this file.
**Modified:** `project.godot` ([audio] + autoload), 4 music `.ogg.import` (loop=true), `game_constants.gd`, `settings.gd` (6 touch points), `game_session.gd` (bag + payload), `lobby_screen.gd/.tscn` (music row), `main_menu_screen.gd/.tscn` (Options), `game_menu.gd` (volume section), `kudos_button.gd`, `reveal_judging_screen.gd` (card meta + replay poof), `ready_status_strip.gd`, `draw_screen.gd`, `drawing_canvas.gd` (eraser/stamp/undo/replay), `winner_spotlight.gd`, `collection_viewer.gd`, `wrap_up_screen.gd` (S6/S7), `tests/game/session/test_settings.gd` (+4), `tests/game/session/test_game_session.gd` (payload pin).

## Tests

600 total (+19): 12 AudioService state tests (music map table, payload track + fallback, cue arm/disarm, pause fade + resume, volume clamp/persist via seam), 4 rotation-bag tests (coverage-before-repeat, single-track, seed-determinism, hostile-empty-mask), 4 settings tests (round-trip/default, clamp, always-tunable, preset-survival), 1 ROUND_INTRO payload pin. AudioService tests call handlers directly (no EventBus emission — other autoloads must not react); assert state only, never audible output.

## Lessons / gotchas

- **Audio `.import` params are editable post-generation:** run `--import` once, `sed` `loop=false` → `loop=true` on the music OGGs, re-import. No editor session needed.
- **`AcceptDialog` children need manual anchors/offsets** (JoinDialog precedent) — reserve bottom space for the OK button.
- **Headless audio is inert, not absent:** `play()` on pooled players never errors without a device, so gates/CI need zero audio special-casing (verified: all 3 gates pass with the autoload live).
- The button auto-hook sees CheckBox/OptionButton via `is BaseButton` — desired here (toggle sounds), but any future button that must stay silent needs the `click_sfx` meta, not an exclusion list in Audio.

## Follow-ups (qa-backlog Slice 21 section)

Owner ear pass items + late-joiner fallback-track note + slider theme polish — see `TDD/qa-backlog.md` §21.
