# Consistency & Integration Guide — Animal Quickdraw

**Purpose:** Development standards and integration contracts for Animal Quickdraw. All slices must follow these patterns. Filled in from `pillars/03-consistency-guide-template.md`.

**Version:** 1.0
**Last Updated:** 2026-07-04
**Project:** Animal Quickdraw

---

## Quick Reference Summary

### Section Finder — "What pattern do I need?"

| I need to... | Go to Section |
|--------------|---------------|
| Name a file, class, function, signal | 2: Naming Conventions |
| Find where to put a new file | 3: File Organization |
| Add a network message / RPC | 4: Networking & RPC Patterns |
| Emit or listen to a cross-feature event | 5: Signals & EventBus |
| Read/write local save data | 6: Persistence Patterns |
| Handle errors | 7: Error Handling |
| Build a screen or UI component | 8: UI/Scene Patterns |
| Write tests | 9: Testing Patterns |
| Integrate a new slice | 10: Integration Contracts |
| Review code | 11: Code Review Checklist |
| Performance concerns | 12: Performance Guidelines |

### Tech Stack Summary

| Component | Choice | Notes |
|-----------|--------|-------|
| Platform | Desktop game (Win/macOS/Linux) | Steam storefront |
| Engine | Godot 4.6 stable | Installed via Homebrew on dev machine |
| Language | GDScript, **static typing mandatory** | `--warnings-as-errors` for untyped declarations where practical |
| Networking | Godot high-level multiplayer (RPCs), host-authoritative | Transport behind `PlatformService`: ENet (dev), SteamMultiplayerPeer (ship) |
| Steam | GodotSteam GDExtension (addons/godotsteam) | App ID 480 (Spacewar) during dev |
| State Management | Autoload singletons + typed signals | No third-party state library |
| Storage | JSON files in `user://` | See Section 6 |
| Testing | GdUnit4 (addons/gdUnit4) | Headless-runnable for logic tests |

### Guiding Principles

1. **Host is the referee.** All game-state mutations happen on the host; clients send requests, receive state. Never trust client input.
2. **Favor laughter and flow over polish and fairness.** When a choice is ambiguous, pick the one that keeps the game moving (design brief §1).
3. **Strokes, not pixels.** Drawings are operation lists everywhere internally; rasterize only at render/export time.
4. **Deterministic replay.** Anything that affects how a drawing renders must be deterministic given the op list and the fixed internal canvas resolution.
5. **Typed everywhere.** Every var, parameter, and return type annotated. `Variant` only at serialization boundaries.

---

## 2. Naming Conventions

**Files & folders:** `snake_case.gd`, `snake_case.tscn`. Test files: `test_<source_name>.gd`.
- Good: `stroke_renderer.gd`, `game_session.gd`, `lobby_screen.tscn`
- Bad: `StrokeRenderer.gd`, `gamesession.gd`

**Classes:** `class_name PascalCase` — every non-trivial script declares one. Good: `class_name StrokeRenderer`.

**Functions/variables:** `snake_case`. Private members prefixed `_`. Constants `SCREAMING_SNAKE_CASE`. Enums `PascalCase` with `SCREAMING_SNAKE` members.

**Signals:** past tense, `snake_case`: `stroke_added`, `round_ended`, `player_joined`. Never imperative (`add_stroke` is a method, not a signal).

**RPC methods:** see Section 4 — `rpc_request_*` (client→host) and `rpc_sync_*` (host→clients) prefixes are mandatory.

**Scenes:** node names PascalCase (`CanvasPanel`, `KudosButton`). One root script per screen scene.

**Test names:** `func test_<behavior_under_test>() -> void:` — e.g. `test_kudos_allotment_rounds_half_up`.

---

## 3. File Organization Standards

```
res://
├── project.godot
├── addons/
│   ├── godotsteam/            # GDExtension (Slice 12)
│   └── gdUnit4/
├── core/                      # Skeleton-owned; slices rarely touch
│   ├── constants/
│   │   ├── game_constants.gd  # timers, canvas size, scoring values, kudos math
│   │   ├── net_ids.gd         # enums for message/phase/reaction IDs
│   │   └── settings_defaults.gd  # mode presets
│   ├── platform/
│   │   ├── platform_service.gd    # autoload "Platform" — facade
│   │   ├── platform_backend.gd    # abstract base
│   │   ├── enet_backend.gd        # dev/LAN
│   │   └── steam_backend.gd       # Slice 12 fills in
│   ├── network/
│   │   └── network_manager.gd     # autoload "Net"
│   ├── save/
│   │   └── save_service.gd        # autoload "Save"
│   ├── nav/
│   │   └── scene_manager.gd       # autoload "Nav"
│   ├── events/
│   │   └── event_bus.gd           # autoload "EventBus" — typed cross-feature signals
│   ├── util/
│   │   ├── text_filter.gd         # blocklist filter for all typed text
│   │   └── uuidv4.gd
│   └── theme/
│       └── main_theme.tres
├── game/                      # Simulation / rules (no UI)
│   ├── session/
│   │   ├── game_session.gd        # host-authoritative round state machine
│   │   ├── roster.gd              # players, judge rotation, late-join slots
│   │   ├── scoring.gd
│   │   └── settings.gd            # GameSettings (mode + host-tunables)
│   ├── drawing/
│   │   ├── drawing_doc.gd         # op list: strokes/fills/clears (+ serialization)
│   │   └── stroke.gd
│   └── prompts/
│       ├── pool_type.gd           # data-driven pool-type architecture
│       ├── prompt_pools.gd
│       └── data/                  # animals.json, adjectives.json (content)
├── ui/                        # Screens & components, one folder per feature
│   ├── shared/                # buttons, timers, avatar chip, player list
│   ├── menu/                  # main menu
│   ├── lobby/
│   ├── canvas/                # drawing surface + tools
│   ├── round/                 # per-phase screens (draw, judge-wait, reveal, judging)
│   ├── collection/
│   ├── avatars/
│   └── wrapup/
├── data/
│   └── blocklist.txt
└── tests/                     # mirrors res:// structure
    ├── game/...
    ├── core/...
    └── ui/...
```

**Rule:** simulation code (`game/`) never references UI nodes. UI observes simulation via signals/EventBus and sends intents via `Net`/session API. This keeps game logic headless-testable.

**Import/preload ordering** in a script: (1) `class_name`/`extends`, (2) signals, (3) enums/consts, (4) `@export` vars, (5) public vars, (6) private vars, (7) `_ready`/lifecycle, (8) public methods, (9) private methods, (10) RPC methods grouped at the end.

---

## 4. Networking & RPC Patterns

**Model:** host-authoritative. Peer ID 1 (the host) owns the `GameSession` simulation. Clients render state and send requests.

### RPC naming & direction

| Prefix | Direction | Decorator | Example |
|--------|-----------|-----------|---------|
| `rpc_request_*` | client → host | `@rpc("any_peer", "call_remote", "reliable")` | `rpc_request_pick_winner(drawing_id)` |
| `rpc_sync_*` | host → all (state replication) | `@rpc("authority", "call_local", "reliable")` | `rpc_sync_phase(phase, data)` |
| `rpc_do_*` | host → specific peer | `@rpc("authority", "call_remote", "reliable")` | `rpc_do_show_prompt(prompt)` |

Unreliable channel only for chat "typing" indicators or cosmetic effects — game state is always reliable.

### Validation pattern (mandatory in every `rpc_request_*` handler)

```gdscript
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_give_kudos(drawing_id: String) -> void:
    if not multiplayer.is_server():
        return
    var sender: int = multiplayer.get_remote_sender_id()
    var player: PlayerState = roster.get_by_peer(sender)
    if player == null:
        return                       # unknown peer — drop silently
    if not _can_give_kudos(player, drawing_id):
        return                       # invalid request — drop, never crash
    _apply_kudos(player, drawing_id) # mutate, then broadcast
```

Rules: (1) confirm authority, (2) resolve sender to a roster entry, (3) validate the action against current phase + player state, (4) apply on host, (5) broadcast via `rpc_sync_*`. Invalid input is **dropped silently** — never trusted, never crashes the host (design brief §13).

### SessionClient / GameSession split (canonical pattern)

Godot requires RPC methods to live on nodes with identical paths on every peer, but the simulation must exist only on the host. Pattern: a thin **`SessionClient` node** exists on all peers (child of the persistent round root) and owns every session RPC; the host-only **`GameSession`** simulation is a plain `RefCounted` owned by the host's `SessionClient`. The host's own actions skip RPC and call the same validated `GameSession` entry points directly, so validation logic is shared and unit-testable without a network. (Defined in Slice 3 §8; all round-feature slices hang their RPCs on `SessionClient`.)

**Class organization:** one `class_name` per file; small data classes nest as inner classes and are referenced qualified (e.g. `Roster.PlayerState`).

### Payloads

RPC arguments are primitives, `PackedByteArray`, or `Dictionary` with documented shape. Every slice TDD documents its RPCs in the "Event/Action Definitions" section using this table format:

| RPC | Direction | Args | Validation | Effect |
|-----|-----------|------|------------|--------|

Drawings travel as serialized `DrawingDoc` dictionaries (see Section 6 format), submitted once at phase end — never live-streamed strokes in v1.

---

## 5. Signals & EventBus

- **Local signals** (node-to-node within one feature): declare on the owning node. Preferred for anything intra-feature.
- **EventBus** (`core/events/event_bus.gd`, autoload `EventBus`): only for genuinely cross-feature events. All signals declared with typed parameters and a doc comment. Slices append their signals to this file — this is the project's equivalent of the slice contract's "Event/Action Definitions".

```gdscript
## Emitted on all peers when the round phase changes. data shape depends on phase.
signal phase_changed(phase: NetIds.Phase, data: Dictionary)
## Emitted locally when a drawing is saved to the player's collection.
signal collection_item_added(item_id: String)
```

Connect in `_ready`, disconnect is automatic on free. Never emit EventBus signals from `game/` simulation on clients based on local guesses — only in response to host `rpc_sync_*` messages.

---

## 6. Persistence Patterns

All local data is JSON under `user://` via `Save` (autoload). No direct `FileAccess` outside `save_service.gd`.

```
user://
├── profile.json          # settings, avatar meta, granted/spent kudos memory is per-game (not here)
├── avatar.json           # DrawingDoc for the avatar (circular canvas)
├── stats.json            # lifetime counters (Slice 14)
├── exports/              # Slice 8: exported/share PNGs (<slug>_<id8>.png) - player deliverables
└── collection/
    ├── index.json        # {"v":1, "items":[{id, prompt, saved_at, orientation, source, session_drawing_id}]} (saved_at = ISO 8601 string)
    ├── thumbs/           # regenerable PNG thumbnail cache (not authoritative)
    └── <uuid>.json       # one DrawingDoc per saved drawing
```

**DrawingDoc serialized format (v1)** — the single canonical drawing format used on the wire, in the collection, and for the avatar:

```json
{
  "v": 1,
  "orientation": "landscape",
  "ops": [
    {"t": "stroke", "c": 4, "s": 1, "pts": [x0,y0, x1,y1, ...], "ts": [0.0, 0.016, ...]},
    {"t": "fill", "c": 7, "x": 120, "y": 88},
    {"t": "clear"},
    {"t": "text", "c": 4, "s": 1, "x": 120, "y": 88, "str": "MOO"}
  ]
}
```

- `c` = palette color index (never raw RGB — palette is a versioned constant table), `s` = brush size index (0/1/2), `pts` = flattened point pairs in **internal canvas coordinates** (800×600 landscape / 600×800 portrait), `ts` = per-point seconds since drawing start (drives replay).
- `text` op (Slice 16): `s` = text scale index into `TEXT_SCALES`, `x`/`y` = in-canvas top-left anchor, `str` = 1–50 chars of ASCII 32–126 rendered from the embedded `PixelFont` (append-only glyph table, like the palette). Content is host-censored via `TextFilter` at submission; the canvas pre-censors identically at commit.
- Fill is an op replayed against the rasterized state of all prior ops at the fixed internal resolution — this is what makes replay deterministic. Rendering code must be resolution-independent only at *display* time (scale the finished texture), never at raster time.
- **Determinism rule:** all authoritative rasterization (fill resolution, replay, export, golden tests) happens on the **CPU** via the Slice 1 `DocRasterizer` — GPU/SubViewport rendering is display-only, since GPU raster output is not bit-identical across platforms. Fill/clear ops carry no timestamps; replay assigns them a nominal duration constant (Slice 1).

**Write pattern:** `Save.write_json(path, data)` — atomic (write temp, rename). **Read pattern:** `Save.read_json(path, default)` — returns default on missing/corrupt and logs a warning; the game never crashes on bad save data.

**Versioning:** every persisted dict carries `"v": int`. Readers accept `v <= CURRENT` and migrate forward; unknown higher versions are rejected with a user-visible message.

---

## 7. Error Handling Standards

Three layers:
1. **Core/services** (`Save`, `Platform`, `Net`): return typed result objects or safe defaults; push warnings via `push_warning`. Never `assert` on user data or network input in release paths.
2. **Simulation** (`game/`): invalid network requests are dropped silently (Section 4). Internal invariant violations use `push_error` + safe recovery (skip round step, never kill the session).
3. **UI:** user-visible failures (connection lost, save failed) surface as a non-blocking toast/dialog component from `ui/shared/`. Message text is friendly, never a stack trace.

Network disconnect handling is defined by Slice 9; until then, drop-to-main-menu with a dialog is the fallback everywhere.

---

## 8. UI/Scene Patterns

- **Screens** live in `ui/<feature>/<name>_screen.tscn` + matching script; navigated via `Nav.goto(scene_path)` (which also handles transition + cleanup). In-round phase screens are children of a persistent `RoundRoot` scene swapped by phase — not full `Nav` navigations.
- **Components** (reused widgets) live in `ui/shared/` or the feature folder; expose `@export` config + signals; no upward `get_parent()` reach-arounds.
- **Theme:** all styling through `core/theme/main_theme.tres` + theme variations. No per-node hardcoded colors/fonts except the drawing palette itself.
- **Layout:** design for 1280×720 base, anchor/container-based so the window is freely resizable. The canvas view letterboxes to preserve the fixed internal aspect. **Slice 18:** the project runs `canvas_items`/`expand` window stretch with a 960×540 minimum window (`GameConstants.WINDOW_MIN_SIZE`, applied in `Nav._ready`) — screens must stay container/anchor-driven (no absolute-pixel layouts), and test suites that simulate OS-level input must park `content_scale_mode` (see `test_text_drag_drop.gd`).
- **Chat prominence** is a property of the phase screen (judge-drawing phase: large; drawer-drawing phase: collapsed), not a global toggle.
- **User Confirmation Checkpoints:** every slice TDD lists UI features the owner must playtest before slice completion (per `workflows/testing-protocol.md` — blocking vs batchable).

---

## 9. Testing Patterns

**Framework:** GdUnit4. Tests in `tests/`, mirroring source paths (`game/session/scoring.gd` → `tests/game/session/test_scoring.gd`).

```gdscript
class_name TestScoring
extends GdUnitTestSuite

func test_judge_no_pick_applies_minus_one() -> void:
    var scoring := Scoring.new()
    scoring.apply_no_pick_penalty("judge_id")
    assert_int(scoring.get_score("judge_id")).is_equal(-1)
```

**Commands** (from project root — confirmed in Skeleton chunk, 2026-07-06):
- All tests: `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/`
- Single suite: same command with `-a tests/game/session/test_scoring.gd`
- `--ignoreHeadlessMode` is required (GdUnit4 6.1.3 refuses headless otherwise); fine for logic tests — UI input simulation is unreliable headless, which is why UI coverage is scene *smoke* tests + owner playtests.
- GdUnit4 writes `reports/` at the project root (gitignored).

**What must be tested** (per Testing Protocol coverage table):
- All `game/` logic: scoring, kudos math, pool draws/no-repeat, rotation, state transitions, serialization round-trips — target 80%+.
- RPC validation logic: host-side request validators tested directly as functions (do not require live network).
- Multiplayer flows: tested manually via multi-instance dev launch (skeleton provides a launch script); document as manual tests.
- UI: scene smoke tests (instantiates without error) + owner playtest confirmation. Deep UI automation is not required in v1.

**Determinism tests:** stroke replay and bucket fill get golden tests — serialize → replay → compare rasterized `Image` hashes at internal resolution.

---

## 10. Integration Contracts

Every slice integrates at these points, in order:

1. **Constants** — add IDs/tunables to `core/constants/` (never inline magic values).
2. **EventBus** — declare new cross-feature signals in `event_bus.gd` with doc comments.
3. **RPCs** — add to the owning session/feature node following Section 4; document in the slice TDD.
4. **Save schema** — extend Section 6 layout; bump `v` if a format changes; add migration.
5. **Scenes/navigation** — register screens with `Nav` route constants.
6. **Settings** — new host-tunable settings go through `game/session/settings.gd` + `settings_defaults.gd` presets.
7. **Tests** — mirror-path tests for all new logic.
8. **Docs** — update WHERE_WE_ARE, decision log if deviating.

**Slice implementation order** is defined in `TDD/recipe.md` (Slice Dependency Order) and `TDD/overview-of-slices.md` — those are authoritative; do not restate here.

---

## 11. Code Review Checklist

- [ ] Static typing on every declaration; no untyped `var x =`
- [ ] Naming conventions (Sections 2, 4) followed, incl. RPC prefixes
- [ ] No magic values — constants in `core/constants/`
- [ ] Every `rpc_request_*` handler follows the 5-step validation pattern
- [ ] `game/` code has zero UI references; UI mutates state only via requests
- [ ] Typed text passes through `TextFilter` before display/broadcast
- [ ] Save reads tolerate missing/corrupt files
- [ ] Tests written, passing, mirror-pathed
- [ ] No regressions: full test suite green
- [ ] EventBus signals documented; payload shapes match TDD

---

## 12. Performance Guidelines

- **Canvas:** draw into a `SubViewport` at internal resolution; strokes rendered incrementally (only new ops per frame), full re-raster only on undo/replay. Bucket fill operates on an `Image` snapshot — O(pixels), fine at 800×600; run on the main thread but budget < 50ms.
- **Replay:** precompute per-op start times; advance by frame delta; cap total replay duration per settings (§7 of design brief).
- **Network:** drawings submitted once per round as a single payload (typ. < 50 KB). Chat/reactions are tiny. No per-frame netcode.
- **Reveal grid:** render each drawing to a cached `ImageTexture` once; grid shows textures, not live canvases.
- **Collection browser:** thumbnails cached to `user://collection/thumbs/` as small PNGs on save (regenerable cache — not authoritative data).

## 13. Accessibility Guidelines (v1 baseline)

- All interactive controls reachable by mouse; minimum click target 32×32 px.
- Text via theme with a global UI scale setting (later polish).
- Never rely on color alone for game-critical state (timer also shows numbers; judge marked with icon + label).
- Chat/caption font sizes respect theme scale.

---

**End of Consistency & Integration Guide**
