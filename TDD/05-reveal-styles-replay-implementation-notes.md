# Implementation Notes: Slice 5 - Reveal Styles & Replay

**Completed:** 2026-07-06 (implementation + automated gates; owner core-flow confirmation pending)
**TDD Document:** `TDD/05-reveal-styles-replay.md`

## Implementation Summary

Both reveal styles now exist. GRID keeps Slice 3's fixed 5 s look-beat plus a 0.25 s fade. ONE_AT_A_TIME (the new default, per the TDD's settings table) runs host-clocked beats: `RevealDirector` (host, pure logic on `GameSession`) computes each drawing's beat duration from the choreography constants + `ReplayPlanner` math; `SessionClient` is the metronome (beat `Timer` + `rpc_sync_reveal_beat`/`rpc_sync_reveal_gather` broadcasts, exactly the phase-pipeline pattern). Each beat opens the Slice 4 `ReactionGate` for the staged drawing only, with the close-grace now spanning beat boundaries. The REVEAL phase deadline is sized to the schedule plus a failsafe margin — if the beat chain ever stalls, the ordinary phase deadline force-advances to JUDGING, and stale beat timers are dropped (never a double transition).

`ReplayPlanner` (pure static math) mirrors `ReplayPlayer`'s schedule rules exactly — a drift-guard test asserts they agree — and produces reveal timescales (6 s per-drawing cap, tightened by the 30 s shared budget / drawer count) and winner timescales (10 s cap; a 30 s drawing lands at exactly 3×, the brief §7 example). Timescales feed straight into `ReplayPlayer.load_doc(doc, speed_multiplier)`, which Slice 1 had already parameterized — no renderer extension was needed.

Captions: an optional ≤80-char line rides the submission payload **beside** the doc (never inside it — docs are what collections persist), validated host-side (strip-when-disabled → flatten newlines → trim → truncate → `TextFilter.censor`), delivered anonymously inside the reveal entries, shown under the staged card, as a truncated tooltip line on grid cells, and with attribution in the winner spotlight. The victory lap (`WinnerSpotlight`) mounts inside the resolution screen when a winner was picked: large view, author reveal, caption, and a stroke replay unless `replay_mode == OFF`; emits `EventBus.winner_lap_finished`.

## Deviations from Original Design

### Stage built INSIDE `reveal_judging_screen` — no separate `reveal_stage.tscn`, no `GridLayout` retrofit
**Original Plan:** §7 a dedicated RevealStage screen + a `grid_layout.gd` helper retrofitted onto the judging grid so the REVEAL→JUDGING swap lands seamlessly.
**Actual Implementation:** The one-at-a-time stage is an overlay inside the existing reveal/judging screen; each beat settles into the *actual* judging cell (cells are built up front, transparent until their beat). REVEAL→JUDGING is the existing no-swap path.
**Reason:** Slice 3 shipped REVEAL+JUDGING as one screen with in-code cells (no `drawing_grid_cell.tscn`), so a second screen + shared-rect helper would recreate state (Slice 4 social wiring, pick affordances) only to guarantee what the single-screen approach gives by construction: zero visual jump.
**Impact:** Gameplay/UX identical to spec. Slices 8/10 wanting `GridLayout` should create it then (nothing consumes it today).

### One idle-gap constant, not two
**Original Plan:** §2 adds `REPLAY_MAX_IDLE_GAP_SECS := 0.35`.
**Actual Implementation:** Kept Slice 1's implemented `REPLAY_MAX_OP_GAP_SEC = 1.0` as the single compression constant (planner and renderer must share it or host schedules drift from client renders).
**Reason:** Two names for one concept guarantees drift; the reveal caps already bound total duration, which is what the 0.35 was protecting. Dev-tunable in one place if playtests want tighter pacing.

### Beat timing is tween-based fades (programmer art)
Card-in/to-grid are implemented as fade+settle (stage fades out, cell fades in) rather than literal slide/shrink motion paths. Durations and the beat structure match the §5 table exactly; motion polish is batchable (qa-backlog).

### Slice 1 renderer needed no extension
§9 anticipated adding a `timescale` parameter; `ReplayPlayer.load_doc` already took `speed_multiplier` with gap compression and a hard cap. The internal 10 s cap composes safely with planner timescales (planner caps are ≤ it, and it takes the max).

### Slice 4 follow-up fix: the save toggle was invisible in rounds
`draw_screen.tscn` shipped with `show_save_toggle = false`, so Slice 4's self-save was unreachable in a real game (only its tests set the property). Flipped to `true` — the toggle now appears on the round canvas as designed.

### Captions never persisted to the collection
Per TDD §2 (decision recorded here): the collection index stores prompt only; a kudos-save or self-save of a captioned drawing keeps the doc, not the caption. Revisit if playtests miss them.

## Files Created/Modified

**Created:** `game/drawing/replay_planner.gd`, `game/session/reveal_director.gd`, `ui/round/caption_input.gd/.tscn`, `ui/round/winner_spotlight.gd/.tscn`
**Created (tests):** `tests/game/drawing/test_replay_planner.gd`, `tests/game/session/test_reveal_director.gd`, `test_game_session_reveal.gd`, `tests/ui/round/test_reveal_components.gd`
**Modified:** `core/constants/game_constants.gd` (Slice 5 choreography banner), `core/events/event_bus.gd` (3 signals), `game/session/settings.gd` (RevealStyle/ReplayMode enums + 5 keys + speed clamps), `game/session/submission.gd` (caption), `game/session/game_session.gd` (director, beat chain, caption validation, REVEAL failsafe), `game/session/reaction_gate.gd` (open_for preserves running close-grace), `game/session/session_client.gd` (beat timer + 2 RPCs), `ui/round/draw_screen.gd/.tscn` (caption input, save toggle visible), `ui/round/reveal_judging_screen.gd` (stage mode, grid fade, cell captions), `ui/round/resolution_screen.gd` (spotlight mount), `tests/game/session/test_game_session.gd` + `test_game_session_social.gd` (pinned to GRID where they test Slice 3/4 semantics; entries gained `caption`), `tools/ci/round_ci_driver.gd` (beat/gather/caption verification)

## Key Implementation Details

- **Single-driver rule preserved:** the host's main phase `Timer` and the new beat `Timer` never both advance REVEAL — beats drive the normal path; the phase deadline is a failsafe with a margin (`REVEAL_BEAT_FAILSAFE_SECS`), and `on_reveal_beat_deadline` self-drops when the phase has moved on.
- **Cross-beat reaction grace:** `ReactionGate.open_for()` no longer resets a running close-grace, so a reaction racing the beat boundary still lands for the previous drawing while the new one is already live (§10).
- **Default-settings choreography is live in CI:** `verify_round.sh` (guarded wrapper) now also asserts per-peer: one beat per drawing per round in index order, one gather per round, captions present in reveal entries.
- Empty docs skip replay entirely (planner returns duration 0 → fade path); degenerate/hostile timestamps clamp to 0 and can never exceed a cap.

## Testing Summary

- **Unit/scene tests:** 27 new (replay planner 8, reveal director 6, GameSession reveal 8, UI components 5) — full suite **260/260 PASSED**, 0 orphans.
- **Automated gates:** `verify_lobby.sh` PASS; `verify_round.sh` PASS on all 3 peers including beat/gather/caption checks.
- **User confirmation:** PENDING — blocking checkpoints are the one-at-a-time *feel* and replay-cap pacing; note `replay_mode` defaults to WINNER_ONLY, so full reveal-replay feel is naturally batched with Slice 6's Social preset testing.

## Lessons Learned

- Sizing a phase deadline as "schedule + margin" gives a free, self-cleaning failsafe when a sub-schedule (beats) drives the real transition — no second authority, no race.
- Pinning older suites to the *old* default (GRID) at the rig level kept 60 pre-existing behavioral assertions meaningful after the default changed to ONE_AT_A_TIME.

## Update (2026-07-06, owner playtest feedback — applied same session)

Owner played the one-at-a-time reveal on 3 instances and directed four changes, all implemented and re-verified (263/263 tests, gates PASS):

1. **Emoji areas were cramped/hard to see** → reaction buttons 46×40 @ font 19 (was 36×32 @ 13), kudos button taller, grid cells grown to 320×300.
2. **Victory-lap replay was cut off by the fixed 6 s RESOLUTION window** → the host now sizes RESOLUTION to `replay_secs + REPLAY_STILL_HOLD_SECS (2.0) + 1 s margin` when a replay will play, so every stroke shows and the finished still holds 2 s. Reveal beats already sized themselves.
3. **Replay settings model changed: target durations, not speed multipliers** → `reveal_replay_secs` (default 5, 2–15) and `winner_replay_secs` (default 8, 2–30); timescale = duration ÷ target, floored at realtime (shorter drawings are never stretched). `ReplayPlayer.load_doc` gained `enforce_duration_cap` so planner timescales (which may legitimately mean a 30 s realtime replay) bypass the old Slice 1 10 s guard; sandbox/default callers keep it.
4. **Host pause button** → owner-approved scope for Slice 6's Esc menu (with the pause/leave decision); GameSession pause hooks await it.

Owner deferred kudos/caption/detail testing (backlog) to keep building.

## Known Limitations

- Beat motion is fade-based programmer art; slide/shrink choreography and the "grid strip" preview of settled cards are deferred (qa-backlog).
- The stage overlay letterboxes but caps at 520×390 — very large windows leave headroom (batchable).
- `winner_lap_finished` fires but nothing consumes it yet (Slice 3's resolution tally is static; Slice 10 sequences around it).
- FULL replay during reveal is reachable only via code/settings dict until Slice 6 surfaces `replay_mode`.
