# Implementation Notes: Slice 6 - Game Modes & Settings (+ Esc menu / host pause)

**Completed:** 2026-07-06 (implementation + automated gates; owner core-flow confirmation pending)
**TDD Document:** `TDD/06-game-modes-settings.md`

## Implementation Summary

`GameSettings` is now the complete host-configurable surface: the Slice 2/5 keys plus `judging_window_sec` (previously a Slice 3 constant — the judging window is host-tunable, default 25 s) and `title_points_enabled` (Slice 10's toggle, Custom-only). Three presets (Default / Streamlined / Social) live as literal dicts in `settings_defaults.gd` with identity-guard tests; Custom seeds from applied values. The lock rule is enforced in one place (`set_value`, the single mutation gate): presets leave only draw time / round count / pool source editable. Serialized dicts carry `"v"`; newer versions are refused with defaults.

At start, `Session` freezes a `snapshot()` (kudos AUTO resolved to a concrete count) into the start payload; **every peer** reconstructs it as `Session.game_settings` (frozen) and all in-game reads — simulation and UI — use it exclusively. The lobby object is never consulted after start, and survives untouched for the next lobby (AUTO stays AUTO). Hosts get their last-hosted setup restored from `profile.json` (`last_lobby_settings`), with round count deliberately re-seeded from the current suggestion. A new `rpc_sync_round_suggestion` carries the live "(suggested: N)" hint separately from the value.

Lobby UI: the mode selector is fully enabled; a new `ModeSettingsPanel` renders preset summary chips or the full Custom surface (reveal style, replay mode, both replay *durations*, judging window, captions, title points, kudos with a live "Auto = N for R rounds" hint, combo graying), identical-but-disabled for clients.

**Owner additions (decision log 2026-07-06):** the in-game Esc menu (`GameMenu` overlay in `RoundRoot`) with Resume / **Pause game** (host-only) / Leave (two-click confirm; existing session semantics until Slice 9). Pause freezes the phase clock host-side (`GameSession.pause`, previously a Slice 9 stub, now broadcasts a PAUSED phase), pauses the reveal-beat metronome, and forces the overlay on every peer; resume re-enters the stored phase with the remaining time. `RoundRoot` keeps the live screen during PAUSED and refreshes it **in place** on resume (`refresh_deadline` on all five phase screens) — a mid-drawing pause never wipes the canvas.

## Deviations from Original Design

### Existing field names win over the TDD draft
`draw_time_sec: float` (not `draw_time_secs: int`), `round_count`, and the duration-based `reveal_replay_secs`/`winner_replay_secs` (owner decision, Slice 5 update) are kept — the TDD draft predates them. `Mode` stays in `SettingsDefaults` (its Slice 2 home), not on `GameSettings`. `suggested_rounds()` keeps its Slice 2 name.

### Engine clamps stay permissive; the UI enforces the player-facing range
TDD range 3–20 rounds is enforced by the lobby stepper (`ROUNDS_UI_MIN/MAX`); `clamp_to_limits` keeps the permissive 1–32 engine bounds. Reason: the CI gate and unit tests legitimately run 1–2-round games; two clamp regimes at the engine level would make client mirrors disagree with the host.

### Mode selector = the existing OptionButton; no `mode_selector.tscn`
Slice 2 already shipped a mode OptionButton ("coming soon"); enabling it beats adding a parallel widget. The settings panel is `mode_settings_panel.gd/.tscn` (code-built controls), mounted in the existing lobby settings box inside a ScrollContainer.

### No broadcast coalescing
The TDD's 150 ms coalescing guarded against slider drags; the panel uses steppers/options/checkboxes (discrete edits), so every edit broadcasts directly through the existing `set_settings` path.

### Draw-time range reconciled: 10–120 s
Replaces Slice 2's provisional 15–180 (its constant carried a "reconcile with Slice 6" note).

### Pause scope notes (v1, upgraded by Slice 9)
Pause is a clock freeze + modal overlay, not a simulation halt: client-side cosmetic animation (a running reveal tween/replay) finishes under the overlay, and the reaction gate stays open during a JUDGING pause (host still validates phase for picks). Leaving remains the Slice 2 semantics (host leave ends the session; a drawer becomes a blank). Slice 9 owns the upgrades.

## Files Created/Modified

**Created:** `ui/lobby/mode_settings_panel.gd/.tscn`, `ui/round/game_menu.gd/.tscn`
**Created (tests):** `tests/core/constants/test_settings_defaults.gd`, `tests/ui/lobby/test_mode_settings_panel.gd`, `tests/ui/round/test_game_menu.gd`
**Modified:** `core/constants/game_constants.gd` (Slice 6 banner: UI round range, judging window range, kudos cap, step; draw-time range reconciled), `core/constants/settings_defaults.gd` (real presets), `core/events/event_bus.gd` (`round_suggestion_changed`), `game/session/settings.gd` (new keys, versioning, lock rule, presets, freeze/snapshot, `restore_for_lobby`), `game/session/session_manager.gd` (`game_settings` snapshot object, suggestion RPC, profile persistence, start-payload snapshot), `game/session/game_session.gd` (judging window from settings; `pause()` broadcasts PAUSED), `game/session/session_client.gd` (snapshot source, `request_pause/resume`, beat-timer freeze), `ui/round/round_root.gd/.tscn` (menu, Esc, PAUSED handling, in-place resume refresh), all five phase screens (`refresh_deadline`), `ui/round/draw_screen.gd` + `reveal_judging_screen.gd` + `resolution_screen.gd` (reads moved to `Session.game_settings`), `ui/lobby/lobby_screen.gd/.tscn` (modes live, panel, suggestion hint), `tests/game/session/test_settings.gd` + `test_game_session_reveal.gd` (extended)

## Testing Summary

- **Unit/scene tests:** 24 new (settings lock/freeze/versioning 10, presets 5, judging-window + pause 2, panel smokes 4, menu/pause-UI smokes 3) — full suite **287/287 PASSED**, 0 orphans.
- **Automated gates:** `verify_lobby.sh` PASS; `verify_round.sh` PASS (now exercising the snapshot flow — the game reads the frozen payload settings end-to-end).
- **User confirmation:** PENDING — blocking checkpoints: preset lock behavior, client read-only sync; plus the owner-requested pause/Esc-menu flow.

## Lessons Learned

- Freezing a *separate* snapshot object (`Session.game_settings`) instead of freezing the lobby object keeps the post-game lobby editable and AUTO sentinels intact — the TDD's lifecycle diagram collapses two concerns the code wants separated.
- The `refresh_deadline` in-place path (same phase re-entered) fell out of pause almost for free and is exactly what Slice 9's rejoin resync will want.

## Known Limitations

- The Custom panel is programmer-art dense; layout at 1280×720 with 8 players unverified (backlog).
- Pause cosmetics: running tweens/replays finish under the overlay; PhaseTimer shows the stale countdown while paused (deadline corrects on resume).
- `validate_for_start` has no real blockers until Slice 7 (pool readiness).
- Preset values are v1 proposals awaiting the owner's tuning pass (identity tests pin only what each mode *means*).
