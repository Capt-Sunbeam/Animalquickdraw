# Implementation Notes: Slice 0 — Skeleton

**Completed:** 2026-07-06 — **COMPLETE.** Owner confirmed the two-instance connect playtest (host, join, both rosters, host-quit recovery) at end of session 2.
**TDD Document:** `TDD/00-skeleton-build-guide.md`

## Implementation Summary

The full skeleton per the build guide: Godot 4.6 project at repo root, folder structure per consistency guide §3, the five autoloads (`EventBus`, `Platform`, `Net`, `Save`, `Nav`), constants files, `TextFilter` + starter blocklist, theme + toast component, placeholder main menu with dev Host/Join and a connected-peers list, GdUnit4 harness (vendored v6.1.3), multi-instance dev tooling, and debug export presets for all three platforms. All 32 unit tests green; two-instance ENet connect verified via a scripted headless check.

## Deviations from Original Design

### GdUnit4 headless invocation requires `--ignoreHeadlessMode`
**Original Plan:** `godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/` (consistency guide §9, "confirm exact invocation").
**Actual Implementation:** `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/`.
**Reason for Deviation:** GdUnit4 6.1.3 hard-refuses headless runs without the flag (UI-input tests would be unreliable; our headless suites are logic-only).
**Impact:** Consistency guide §9 updated with the confirmed command. GdUnit4 also writes a `reports/` directory — added to `.gitignore`.

### Two-instance connect gate: automated equivalent added
**Original Plan:** Blocking owner confirmation — run `tools/dev_run.sh`, connect two instances.
**Actual Implementation:** `tools/verify_connect.sh` launches two headless instances with `--ci-host` / `--ci-join` dev args (handled by the main menu in debug builds) and asserts both sides observe the connection. PASS confirmed. The windowed owner playtest remains queued (this session batches playtest gates per owner directive — see decision log).
**Reason for Deviation:** Owner requested a continuous multi-slice session; the transport correctness the gate protects (Slice 2 depends on it) is machine-verifiable.
**Impact:** Slice 2 may proceed. Owner playtest still required before Slice 0 is formally COMPLETE.
**Detail worth knowing:** the CI client must linger ~1 s after connecting before quitting — an immediate `quit()` exits before the final ENet handshake ACK reaches the server, and the host never registers the peer.

### `config/version` cannot carry a `-dev` suffix
**Original Plan:** (not specified) — initially set `0.1.0-dev`.
**Actual Implementation:** `0.1.0`. Windows export metadata only accepts numeric dotted versions.
**Impact:** Slice 15's `APP_VERSION` scheme should stay plain semver.

### macOS export requires ETC2/ASTC import enabled
**Original Plan:** Export presets "exist" (guide §4).
**Actual Implementation:** Added `rendering/textures/vram_compression/import_etc2_astc=true` to project settings — Godot refuses universal/arm64 macOS exports without it.
**Impact:** None beyond slightly larger texture imports.

### SteamBackend stub fails loudly
**Original Plan:** `steam_backend.gd` — "Slice 12 fills in".
**Actual Implementation:** Stub class exists; selecting `--platform=steam` instantiates it and peer creation `push_error`s with guidance rather than silently falling back to ENet.
**Reason:** Matches Slice 12's later "no silent transport fallback" rule (brief §13) from day one.

## Files Created/Modified

- `project.godot`, `.gitignore`, `icon.svg`, `export_presets.cfg` — project config; autoload order EventBus → Platform → Net → Save → Nav
- `addons/gdUnit4/` — vendored GdUnit4 v6.1.3 (from godot-gdunit-labs/gdUnit4)
- `core/constants/` — `game_constants.gd`, `net_ids.gd`, `settings_defaults.gd` (stub presets), `routes.gd`
- `core/events/event_bus.gd` — 5 skeleton signals
- `core/platform/` — `platform_backend.gd` (awaitable peer-creation contract), `enet_backend.gd` (room-code→port mapping, profile.json identity), `steam_backend.gd` (loud stub), `platform_service.gd` (autoload facade + `--platform=` selection)
- `core/network/network_manager.gd` — host/join/leave (coroutines), EventBus signal relay, OfflineMultiplayerPeer-aware `has_active_peer()`
- `core/save/save_service.gd` — atomic JSON (temp+rename), corrupt tolerance, path traversal guard
- `core/nav/scene_manager.gd` — `Nav.goto(route)`
- `core/util/` — `text_filter.gd` (regex word-boundary blocklist, `configure()` test seam), `uuidv4.gd`
- `core/theme/main_theme.tres`, `data/blocklist.txt` (starter list, 20 words)
- `ui/shared/toast.tscn/.gd` (queued toasts), `ui/menu/main_menu_screen.tscn/.gd` (dev Host/Join, peer list, CI hooks)
- `tools/dev_run.sh` (N windowed instances), `tools/verify_connect.sh` (automated connect gate)
- `tests/core/` — 5 suites, 32 tests (save, text_filter, uuidv4, game_constants, enet_backend)

## Key Implementation Details

- **Awaitable backend contract from day one:** `create_host_peer`/`create_client_peer` are awaited everywhere (`Net.host/join` are coroutines), pre-implementing the Slice 12 amendment already recorded in the decision log — no refactor needed later.
- `Net.has_active_peer()` treats Godot's default `OfflineMultiplayerPeer` as "no peer" — naive null checks are wrong in Godot 4.
- `TextFilter` compiles one case-insensitive word-boundary regex; `configure(words)` is the test seam; empty arg restores the disk list.
- GdUnit4's CLI tool extends `SceneTree`, so autoloads are available in headless test runs — tests use `Save` etc. directly.

## Testing Summary

- Unit tests: 32 tests, all passing (`reports/` has the latest run).
- Integration: `tools/verify_connect.sh` → PASS (host and client both observed the connection).
- Exports: Linux, macOS, Windows debug exports build from CLI with no warnings.
- Startup: `godot --headless --quit-after 30` produces zero errors/warnings.
- **User confirmation: CONFIRMED 2026-07-06** — owner ran the windowed two-instance test ("it worked perfectly"): host status + self-in-list, client connect, both rosters at 2 peers, host-quit toast with clean recovery. Zero engine errors in the instance logs.

## Lessons Learned

- Godot 4's default `OfflineMultiplayerPeer` and the ENet quit-before-ACK behavior are the two traps in this layer; both are now encoded in code comments and this note.
- Checking export templates *before* writing presets saved a blind alley — they were already installed.

## Known Limitations

- Owner playtest gates deferred (session-wide, by owner directive).
- `settings_defaults.gd` presets are empty stubs until Slice 6.
- `steam_backend.gd` is a loud stub until Slice 12.
- Main menu is a dev placeholder; real navigation targets arrive with Slices 1–3.
