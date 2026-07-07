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

# --- Slice 2: Lobby & Session Roster ---
const SUGGESTED_ROUNDS_PER_PLAYER: int = 2     # brief §10: ~2x player count
const ROUNDS_MIN: int = 1
const ROUNDS_MAX: int = 32
const DRAW_TIME_MIN_SEC: float = 15.0          # reconcile with Slice 6's 10-120 range when it lands
const DRAW_TIME_MAX_SEC: float = 180.0
const MAX_CHAT_LEN: int = 200
const CHAT_RATE_LIMIT_COUNT: int = 5           # max messages...
const CHAT_RATE_LIMIT_WINDOW_SEC: float = 3.0  # ...per window, per peer
const MAX_NAME_LEN: int = 24
const MAX_PLATFORM_ID_LEN: int = 64
const REGISTER_TIMEOUT_SEC: float = 10.0       # connected-but-unregistered peers get dropped
const REJECT_DISCONNECT_DELAY_SEC: float = 0.5 # let the reject RPC flush before closing the peer

# --- Slice 3: Core Round Loop (§6 timer/scoring constants; draw time and
# judging window become mode tunables via GameSettings in Slice 6) ---
const ROUND_INTRO_SEC: float = 4.0
const SUBMIT_GRACE_MS: int = 1500              # acceptance window after the drawing deadline
const REVEAL_GRID_SEC: float = 5.0             # v1 grid-look beat before judging opens
const JUDGING_WINDOW_SEC: float = 30.0
const RESOLUTION_SEC: float = 6.0
const MAX_DRAWING_BYTES: int = 262144          # wire-size cap for a submitted doc (~50 KB typical)
const COMBO_REPEAT_MAX_ATTEMPTS: int = 40      # prompt redraws before allowing a repeat
const ROUND_START_FAILSAFE_SEC: float = 3.0    # host starts even if a peer never reports ready

# --- Slice 1: Drawing Canvas & Stroke Engine ---
const BRUSH_RADII_PX: PackedInt32Array = [3, 7, 14]  # size indices 0/1/2 (brief §6)
const STROKE_MIN_POINT_DIST_PX: float = 2.0          # input decimation threshold
const STROKE_MAX_POINTS: int = 4096                  # per-stroke sanity cap (payload size)
const REPLAY_MAX_OP_GAP_SEC: float = 1.0             # inter-op idle time compressed to this
const REPLAY_NON_STROKE_OP_SEC: float = 0.25         # nominal fill/clear replay duration
const FILL_BUDGET_MS: int = 50                       # flood fill budget, main thread
