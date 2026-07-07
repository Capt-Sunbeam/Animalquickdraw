class_name SettingsDefaults
## Mode preset skeleton (skeleton guide §3.7). Structure only - the real
## preset value dictionaries land in Slice 6; Slice 2 consumes
## DEFAULT_DRAW_TIME_SEC for the lobby's initial draw-time setting.

enum Mode { DEFAULT, STREAMLINED, SOCIAL, CUSTOM }

const DEFAULT_DRAW_TIME_SEC: float = GameConstants.DRAW_TIME_DEFAULT_SEC

## Data-driven prompt pool type (Slice 3 defines the engine; Slice 2's
## GameSettings carries the id so the start snapshot is forward-compatible).
const DEFAULT_POOL_TYPE_ID: String = "animal_adjective"

# Preset dictionaries are filled with real values in Slice 6 (kept as empty
# stubs so the PRESETS map shape is stable from day one).
const PRESET_DEFAULT: Dictionary = {}
const PRESET_STREAMLINED: Dictionary = {}
const PRESET_SOCIAL: Dictionary = {}

const PRESETS: Dictionary = {
	Mode.DEFAULT: PRESET_DEFAULT,
	Mode.STREAMLINED: PRESET_STREAMLINED,
	Mode.SOCIAL: PRESET_SOCIAL,
}
