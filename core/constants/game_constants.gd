class_name GameConstants
## Named constants from the design brief (§3, §6-§11). No magic values in
## code (consistency guide §10) - every tunable lives here or in
## SettingsDefaults. Slices append their constants below their own banner.

# --- Players (brief §3) ---
const MIN_PLAYERS: int = 3
const MAX_PLAYERS: int = 8

# --- Canvas internal resolutions (brief §6; consistency guide §6) ---
const CANVAS_LANDSCAPE: Vector2i = Vector2i(800, 600)
const CANVAS_PORTRAIT: Vector2i = Vector2i(600, 800)

# --- Scoring (brief §11): negative scores are legal, no floor anywhere ---
const WINNER_POINTS: int = 2
const KUDOS_POINTS: int = 1
const JUDGE_NO_PICK_POINTS: int = -1
const TITLE_POINTS_VALUE: int = 1  # backend constant, never player-facing (Slice 10)

# --- Kudos economy (brief §11): allotment = round_count / KUDOS_PER_ROUNDS,
# rounded to nearest with .5 up, min KUDOS_MIN_ALLOTMENT (math lands in Slice 4) ---
const KUDOS_PER_ROUNDS: int = 4
const KUDOS_MIN_ALLOTMENT: int = 1

# --- Draw time (brief §10; per-mode presets in SettingsDefaults, Slice 6) ---
const DRAW_TIME_DEFAULT_SEC: float = 30.0  # decision log 2026-07-04, pending playtest

# --- Replay pacing cap (brief §7: a 30 s drawing replays in <= ~10 s) ---
const REPLAY_MAX_DURATION_SEC: float = 10.0

# --- Slice 1: Drawing Canvas & Stroke Engine ---
const BRUSH_RADII_PX: PackedInt32Array = [3, 7, 14]  # size indices 0/1/2 (brief §6)
const STROKE_MIN_POINT_DIST_PX: float = 2.0          # input decimation threshold
const STROKE_MAX_POINTS: int = 4096                  # per-stroke sanity cap (payload size)
const REPLAY_MAX_OP_GAP_SEC: float = 1.0             # inter-op idle time compressed to this
const REPLAY_NON_STROKE_OP_SEC: float = 0.25         # nominal fill/clear replay duration
const FILL_BUDGET_MS: int = 50                       # flood fill budget, main thread
