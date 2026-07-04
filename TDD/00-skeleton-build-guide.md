# Slice 0: Skeleton Build Guide
## Project foundation — structure, core services, dev tooling

**Version:** 1.0
**Last Updated:** 2026-07-04
**Dependencies:** None
**Provides:** Project structure, PlatformService (ENet dev backend), NetworkManager, SaveService, SceneManager, EventBus, constants, text filter, theme foundation, GdUnit4 harness, multi-instance dev launch, export presets

> The Skeleton is infrastructure, not a vertical feature, so this guide replaces the 12-section slice contract with a systems-oriented structure. All later slices follow the full contract.

---

## 1. Goals & Exit State

When the Skeleton is complete:
- The project opens clean in Godot 4.6 with zero errors/warnings at startup.
- A placeholder main menu launches; `Nav` can switch scenes.
- Two instances launched on one machine can connect over ENet (host + join by "room code" = localhost port mapping) and see each other's names in a placeholder connected-peers list.
- `Save` round-trips JSON to `user://` atomically.
- `TextFilter` filters a test string against `data/blocklist.txt`.
- GdUnit4 runs headless with at least one real passing test per core service.
- Export presets exist for Windows/macOS/Linux (unsigned, debug).

Playable-game features (lobby UI, canvas, rounds) are **out of scope** — they are Slices 1–3.

## 2. Project Setup

1. `godot --version` → confirm 4.6.x. Create project in repo root (`project.godot` at top level; source dirs per consistency guide §3).
2. Project settings: main scene `ui/menu/main_menu_screen.tscn`; window 1280×720, resizable, `canvas_items` stretch off (UI is anchor-based); GDScript warnings elevated (untyped declaration = error where practical).
3. Install **GdUnit4** into `addons/gdUnit4` (AssetLib or vendored). Enable plugin.
4. **GodotSteam is NOT installed in the skeleton** — Slice 12. The platform layer is built against the abstract backend + ENet only, so nothing here depends on Steam binaries.
5. `.gitignore`: Godot 4 standard (`.godot/`, export artifacts) — keep `addons/` vendored (committed) for reproducible sessions.
6. Version pinning: record exact Godot + plugin versions in `TDD/decision-log.md` when installed.

## 3. Core Systems

### 3.1 Autoload registry (project settings order matters)

| Autoload | Script | Purpose |
|----------|--------|---------|
| `EventBus` | `core/events/event_bus.gd` | Typed cross-feature signals |
| `Platform` | `core/platform/platform_service.gd` | Backend facade (identity, lobby transport creation) |
| `Net` | `core/network/network_manager.gd` | Peer lifecycle, host/join, connection signals |
| `Save` | `core/save/save_service.gd` | Atomic JSON persistence |
| `Nav` | `core/nav/scene_manager.gd` | Screen navigation |

### 3.2 PlatformService (`Platform`)

Abstract seam between the game and Steam-vs-dev environments.

```gdscript
class_name PlatformBackend
extends RefCounted
# Overridden by EnetBackend now, SteamBackend in Slice 12.
func get_display_name() -> String: return "Player"
func get_platform_id() -> String: return ""          # stable per-install id (dev: from profile.json)
# Peer creation is a coroutine: Steam lobby create/join is callback-async (Slice 12),
# so callers always `await` these. EnetBackend returns immediately (still awaitable).
func create_host_peer(room_code: String) -> MultiplayerPeer: return null
func create_client_peer(room_code: String) -> MultiplayerPeer: return null
func supports_invites() -> bool: return false
func supports_lobby_browser() -> bool: return false
```

`Net.host()` / `Net.join()` therefore `await` the backend and are themselves awaitable.

- Backend selection: `--platform=enet` (default in editor builds) / `--platform=steam` (default in export release once Slice 12 lands). Read via `OS.get_cmdline_user_args()`.
- **ENet backend room codes (dev):** code `"LOCAL"` maps to `127.0.0.1:24515`; `"LOCAL2"…` map to successive ports so several sessions can coexist. Real room codes are a Steam-lobby concept (Slice 12). Dev display name: `--name=Alice` arg, else `"Dev-<pid>"`.

### 3.3 NetworkManager (`Net`)

- `host(room_code) -> Error`, `join(room_code) -> Error`, `leave()`.
- Owns `multiplayer.multiplayer_peer`; relays Godot connection signals into typed EventBus signals: `peer_connected(peer_id)`, `peer_disconnected(peer_id)`, `connection_failed()`, `server_disconnected()`.
- Exposes `is_host() -> bool`, `local_peer_id() -> int`.
- No game semantics here — roster/session logic is Slice 2/3.

### 3.4 SaveService (`Save`)

- `read_json(path: String, default: Dictionary) -> Dictionary`, `write_json(path: String, data: Dictionary) -> Error` (temp-file + rename atomic write), `delete(path)`, `list_dir(path) -> PackedStringArray`.
- All paths relative to `user://`. Corrupt file → warning + default (never crash).

### 3.5 EventBus

Initial signals (skeleton set — slices append):
```gdscript
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_failed()
signal server_disconnected()
signal scene_changed(route: String)
```

### 3.6 SceneManager (`Nav`)

- `goto(route: String)` with a `Routes` constant table in `core/constants/`; instant swap now, transition polish later. Frees the old screen, instantiates the new.

### 3.7 Constants (`core/constants/`)

- `game_constants.gd`: `CANVAS_LANDSCAPE := Vector2i(800, 600)`, `CANVAS_PORTRAIT := Vector2i(600, 800)`, player min/max (3/8), scoring values (+2 winner / +1 kudos / −1 no-pick), kudos-per-4-rounds formula constants, draw-time defaults per mode, replay speed caps. Values from design brief §6–§11; every one host-tunable or dev-tunable per brief stays here as a named constant.
- `net_ids.gd`: `enum Phase { LOBBY, POOL_SETUP, ROUND_INTRO, DRAWING, REVEAL, JUDGING, RESOLUTION, WRAP_UP, PAUSED }`, `enum Reaction { LAUGH, LOVE, WOW, DISGUST, CRY, FIRE }`.
- `settings_defaults.gd`: Default/Streamlined/Social preset dictionaries (Slice 6 consumes; skeleton stubs the structure).

### 3.8 TextFilter (`core/util/text_filter.gd`)

- Loads `res://data/blocklist.txt` (one word per line; ship a small starter list, expand later).
- `is_clean(text) -> bool`, `censor(text) -> String` (replaces matches with `***`). Case-insensitive, substring-with-word-boundary matching. Applied to chat, captions, and custom words by later slices.

### 3.9 Theme foundation

- `core/theme/main_theme.tres` with base font sizes, button/panel styles, and the project's placeholder look. `ui/shared/` gets `toast.tscn` (notification) and `app_button.tscn` if needed — keep minimal.

## 4. Dev Tooling

- **Multi-instance launch:** `tools/dev_run.sh` — launches N editor-runtime instances with `--platform=enet --name=P<i>` (and window position args) for local multiplayer testing. Godot editor's built-in "Run Multiple Instances" (Debug menu) is the alternative; script exists so CLI sessions can do it headlessly where possible.
- **Test run:** confirm exact GdUnit4 headless invocation, record it in consistency guide §9 if it differs.
- **Export presets:** `export_presets.cfg` with Windows Desktop, macOS, Linux presets (debug, unsigned). Verify a Linux + macOS export builds from CLI (`godot --headless --export-debug`). Templates must be installed once (document in implementation notes).

## 5. Implementation Checklist

### Setup
- [ ] Godot 4.6 project created at repo root; window/stretch settings; main scene set
- [ ] GdUnit4 installed & enabled; sample test runs headless
- [ ] Folder structure per consistency guide §3 created (empty `.gdkeep` where needed)
- [ ] `.gitignore` added

### Core services
- [ ] `EventBus` with skeleton signals
- [ ] `PlatformBackend` base + `EnetBackend`; `Platform` autoload with backend selection via CLI arg
- [ ] `Net` host/join/leave + signal relay
- [ ] `Save` read/write/delete/list with atomic writes + corrupt-file tolerance
- [ ] `Nav` + `Routes` constants; placeholder `main_menu_screen.tscn` with Host/Join (dev) buttons wired to `Net`
- [ ] Constants files populated from design brief values
- [ ] `TextFilter` + starter `data/blocklist.txt`
- [ ] `main_theme.tres` + toast component

### Verification
- [ ] Unit tests: Save round-trip + corrupt-file, TextFilter matching, constants sanity (min players ≥ 3 etc.), EnetBackend port mapping
- [ ] Manual: two local instances connect; peer list updates on join/leave; host quit → client sees `server_disconnected`
- [ ] Exports build for all three platforms (debug)
- [ ] **Owner confirmation:** ran `tools/dev_run.sh`, connected two instances (blocking test — Slice 2 depends on it)

### Documentation
- [ ] Update WHERE_WE_ARE; session log; implementation notes for Slice 0; decision log entries for any version pins/deviations

## 6. Exit Criteria

All checklist items done; tests green; owner confirmed two-instance connect; no startup warnings; docs updated.
