class_name SettingsDefaults
## Mode presets (Slice 6 TDD §2; skeleton stub → real values). Plain literal
## dictionaries - core must not depend on game/ classes, so enum values are
## ints with comments; TestSettingsDefaults asserts every preset validates
## through GameSettings and guards each preset's identity. All values are
## v1 proposals - tune freely in playtesting (§10).
##
## Presets deliberately omit round_count and pool_source (always-tunable,
## never reset by a mode switch). draw_time_sec IS per-mode (§10) but stays
## editable afterward. Custom has no dict - it seeds from applied values.
## Replay values are TARGET DURATIONS in seconds (decision log 2026-07-06).

enum Mode { DEFAULT, STREAMLINED, SOCIAL, CUSTOM }

const DEFAULT_DRAW_TIME_SEC: float = GameConstants.DRAW_TIME_DEFAULT_SEC

## Data-driven prompt pool type (Slice 3 defines the engine; Slice 2's
## GameSettings carries the id so the start snapshot is forward-compatible).
const DEFAULT_POOL_TYPE_ID: String = "animal_adjective"

## The playtested happy medium: per-drawing reveal beat, winner-only replay.
const PRESET_DEFAULT: Dictionary = {
	"reveal_style": 1,           # ONE_AT_A_TIME
	"replay_mode": 1,            # WINNER_ONLY - victory lap only
	"reveal_replay_secs": 5.0,
	"winner_replay_secs": 8.0,
	"judging_window_sec": 25.0,
	"kudos_allotment": -1,       # AUTO (round_count/4, .5 up - Slice 4)
	"title_points_enabled": true,
	"draw_time_sec": 30.0,
}

## Fewer theatrics, more rounds (§10): grid reveal, no replays, quick judging.
const PRESET_STREAMLINED: Dictionary = {
	"reveal_style": 0,           # GRID - all at once
	"replay_mode": 0,            # OFF
	"reveal_replay_secs": 4.0,   # stored but unused while replay is off
	"winner_replay_secs": 6.0,
	"judging_window_sec": 15.0,
	"kudos_allotment": -1,
	"title_points_enabled": true,
	"draw_time_sec": 20.0,
}

## Slower and sillier (§10): every drawing animates, long windows, max chat.
const PRESET_SOCIAL: Dictionary = {
	"reveal_style": 1,           # ONE_AT_A_TIME
	"replay_mode": 2,            # FULL - every drawing animates at reveal
	"reveal_replay_secs": 8.0,   # longer replays = more theater (budget-capped)
	"winner_replay_secs": 12.0,
	"judging_window_sec": 40.0,
	"kudos_allotment": -1,
	"title_points_enabled": true,
	"draw_time_sec": 45.0,
}

const PRESETS: Dictionary = {
	Mode.DEFAULT: PRESET_DEFAULT,
	Mode.STREAMLINED: PRESET_STREAMLINED,
	Mode.SOCIAL: PRESET_SOCIAL,
}
