# Polish & Finishing Touches — Owner Notes

**Created:** 2026-08-10 (session 16, after the Slice 21 ear pass + 8-instance playtest). Owner's adjustment list, written up with implementation pointers so a later session can pick any item up cold. **None of these are implemented yet.**

**Status legend:** 🎵 = needs new owner composing (Strudel → extractor render) before wiring · 🔧 = pure code

---

## A. Audio — composing needed first 🎵

### A1. Replace the timer-cue sounds (drawing AND judging endings)
Owner verdict: dislikes the current escalating cue at the end of the drawing timer AND at the end of the judging timer. Both get **replacement sounds — confirmed 2026-08-10** (new compositions, not just removal; possibly two different cues — drawing vs judging have different moods; owner's call when composing).
- Compose new source(s) in Strudel → `TDD/sound/` → render via the Strudel Extractor → replace/add WAVs in `assets/audio/`.
- **Wiring note:** re-measure the landing-note onset on any new render (waveform RMS onset detection — method in `21-audio-wiring-implementation-notes.md` "Measured constants") and update `CUE_LANDING_SEC` in `core/audio/audio_service.gd`. If drawing and judging get *different* cues, `Audio` needs a per-phase cue stream pick (one-line branch where `_cue_player.stream` is set).

### A2. Judging music + per-reveal snippet — the silence experiment failed
Owner: judging and reveal "feel kind of dead". Refined spec (owner, 2026-08-10): **REVEAL gets a short sound SNIPPET that plays once per canvas reveal** (not a music loop); **JUDGING gets a short song** that loops while the judge browses. The judging half is exactly the revisit trigger written into the 2026-07-19 M4/M5 cut ("revisit only if playtests feel empty").
- **Judging song id: M6** (M4 is retired-never-reused). Short loop, §0 identity rules (F pentatonic, palette reuse); must sit UNDER voice-chat joking and let S4 land. Wiring: add to `Audio.MUSIC`, sound README render-table row, `loop=true` on its OGG import, JUDGING row of `_desired_music` → `&"m6-judging"`. **Interaction:** the cue's music-fade currently only fires for DRAWING (`_phase == NetIds.Phase.DRAWING` guard in `_process`) — extend to JUDGING; and the disliked judging cue ending is being replaced anyway (A1). Update `test_judging_resolution_wrap_up_and_paused_are_silent` (JUDGING leaves the silent set; REVEAL stays in it).
- **Reveal snippet:** a WAV one-shot per revealed canvas — this effectively fulfills the brief §3 parked "Card flip/reveal" SFX row (name it `sfx-reveal` or take stinger id S9 at composing time; S3/S5/S8 stay retired). Wiring hook: `EventBus.reveal_beat_started(index, drawing_id, beat_secs)` fires on every peer per one-at-a-time beat — one `play_sfx` line in `Audio`. **Open sub-decision:** GRID reveal style has no beats (everything appears at once) — play the snippet once on `reveal_gathered` / grid appearance, or not at all; owner's call at implementation.

---

## B. Audio — wiring changes only 🔧

### B1. Drawing-track picker: allow ANY subset, including none
Current behavior (unchecking the last track snaps back to all) is wrong. Owner spec: select as many, as few, **or none**; none = no background music during drawing; **default stays all-selected** (already true today).
- `game/session/settings.gd`: keep the invalid-bit strip in `clamp_to_limits`, **delete the `== 0 → ALL` reset**. Mask 0 becomes a legal value meaning silence.
- `game/session/game_session.gd` `_next_music_track()`: empty enabled set → return `""` (drop the index-0 fallback).
- `core/audio/audio_service.gd`: ROUND_INTRO handler — `music_track` of `""` sets `_drawing_track = &""` (silence) instead of falling back to ambient; the unknown-garbage-id fallback stays.
- Lobby UI: no change needed once the clamp stops snapping back (the checkbox row already just renders the mask).
- Tests to update: `test_drawing_tracks_clamp_strips_invalid_bits_and_never_empty` (rename/rework — empty is now legal), `test_hostile_empty_mask_falls_back_instead_of_hanging` (now expects `""`), `test_unknown_track_id_falls_back_to_ambient` (unchanged), add a none-selected → silent-drawing case.

### B2. Eraser sound: continuous loop for the whole stroke
One-shot-per-stroke is wrong; owner wants the eraser noise **looping while the mouse button is held** during an eraser stroke.
- Make a loopable version (set loop points on the existing 1 s WAV via its `.import` — `edit_loop_mode`/loop begin-end — or owner re-renders a seamless loop source; try the import-loop route first, it may Just Work on the chalkboard scrub).
- `Audio` gets a dedicated looping canvas player + `start_eraser_loop()` / `stop_eraser_loop()`; `drawing_canvas.gd` calls start in `_stroke_begin` (ERASER branch, replacing the one-shot) and stop wherever strokes end — **all of them**: mouse release, the Slice 18 source-aware `draw_hold`/D-key releases, and stroke-abort paths (`_commit_live_stroke` / cancel). Grep every `_input_state = InputState.IDLE` transition out of STROKING.

### B3. Ready-up sound goes GLOBAL
The Done!/ready click currently plays only for the presser (local `click_sfx` meta). Owner wants every player to hear each ready-up.
- Hook `EventBus.ready_state_changed(ready_ids)` in `Audio`: play `sfx-ready-click` when the set GROWS (compare against a cached copy; reset cache on phase change like SessionClient does). Unready (set shrinks) should probably stay silent — confirm with owner at implementation.
- Remove the `click_sfx` meta overrides on the Done! button (`draw_screen.gd`) and the strip button (`ready_status_strip.gd`) — set them to `"none"` instead, or the presser hears the sound twice (local click + broadcast).

---

## C. UI / menus 🔧

### C1. Exit-game button on the main menu
Add an "Exit game" button to the main-menu button list (bottom, after Collection/Options) → `get_tree().quit()`. Trivial; `main_menu_screen.tscn` + one connect.

### C2. Esc menu in the LOBBY
Esc currently does nothing in the lobby; owner wants a lobby variant of the menu: **volume sliders + any other sensible settings** reachable mid-lobby. Not the in-game GameMenu (no Pause, no kick rows needed — the lobby already has kick on the roster; Leave already exists as a button).
- Suggested shape: lightweight `LobbyMenu` (or a reuse of `GameMenu` with a mode flag) mounted in `lobby_screen.tscn`, toggled by `ui_cancel`, containing the shared `AudioSettingsPanel` + Close. Same overlay skin as GameMenu (PanelPop).
- "Other sensible settings": nothing else exists per-user today beyond volumes — leave room in the layout.

### C3. Chat hide/collapse button: drop the border
The side-chat's Hide (collapse/expand) control during drawing/judging: the word is too small and the button border crowds/covers it. Owner: **no button border on it** is fine.
- `ui/shared/chat_panel.gd` — find the hide/collapse Button; give it a borderless style: `theme_type_variation = &"EmojiButton"` (bare glyph + tint, existing variation) or `FlatButton` if it should keep the tan chip; owner said borderless, so EmojiButton-style bare is the first try.

---

## Bookkeeping when implementing

- A2 needs a decision-log entry (it reverses the M4 half of the cut on its own written revisit condition — new id M6; reveal stays music-free but gains the per-canvas snippet).
- B1 needs a decision-log line too (drawing-music "none" becomes legal; supersedes the never-empty rule from TDD 21).
- Update qa-backlog §21 items that these supersede (cue-landing feel, eraser retrigger feel).
- Full suite + 3 gates after B1/B3 (settings shape + new EventBus hook); A/B changes need a fresh owner ear pass.
