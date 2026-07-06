# Decision Log: Animal Quickdraw

**Purpose:** Track design decisions made during development. New entries are added at the top of the Decisions section.

**Last Updated:** 2026-07-04

---

## Decisions

*New entries go here, at the top of this section.*

---

### Palette picker redesign: all-colors overlay + drag-to-pin quick slots
**Date:** 2026-07-06 | **Slice:** 1 | **Decided by:** Owner (playtest feedback)

**Context:** Owner playtested the Canvas Sandbox ("works really good") but found (a) a stuck selected-outline bug after picking a shade from the per-family popup, and (b) the per-family long-press popups force players to hunt for shades one family at a time — bad fit for a 15–30 s draw timer.

**Decision:** Replace per-family shade popups with:
1. An **"All colors" toggle** that opens an overlay grid of the full 60-color table above the palette bar (families as light→dark columns). Click any swatch to select; selection persists until the next pick.
2. **Three custom quick-slots** on the bar: drag any color (from grid or base row) onto a blank slot to pin it; click to reuse; right-click to clear. **Session-only** — not persisted (persistence to profile.json is a cheap later add if playtests want it).
3. Selection shown as an explicit outlined-swatch state driven by the picker (root-cause fix for the stuck-outline bug — never rely on button hover/focus leftovers).

**Rationale:** Brief §6 prescribes preset shades behind an "expand" — it does not prescribe per-family popups. One sweep of all 60 presets beats serial hunting under time pressure; pinned slots let players set a per-drawing palette once and draw at speed. No freeform mixing anywhere (unchanged).

**Alternatives considered:** Inline expand pushing the canvas smaller (rejected: layout jump mid-drawing); persistent slots (deferred).

**Impact:**
- Affects: `ui/canvas/palette_picker.gd` internals only (+ new `palette_swatch.gd`, `palette_slot.gd`). The `color_selected(color_index)` contract is unchanged; no other slice touched. Slice 11's avatar editor inherits the new picker automatically.
- Migration needed: No. Breaking change: No.

**Status:** [x] Code implemented [x] Tests updated (13 new; 102 total green) [x] Slice 1 TDD + implementation notes updated

---

### Slice 1: palette hex values + raster implementation choices
**Date:** 2026-07-06 | **Slice:** 1 | **Type:** Quick

**Decision:**
- **Palette values chosen** (append-only from here on): family 0 greyscale white→black; families 1–11 red/orange/yellow/green/teal/blue/navy/purple/pink/brown/tan, 5 shades each, base = middle shade. Exact hex in `core/constants/palette.gd`. Default brush color = index 4 (black).
- **Fill implementation:** scanline fill over a `PackedInt32Array` pixel view (per-pixel GDScript Image access blows the 50 ms budget ~10×). Pixel-identical to the spec'd rule; LE byte order on all targets.
- **Circle stamps:** row-span `fill_rect` form of the same `dx²+dy²≤r²` rule (pixel-identical, ~30× fewer native calls).
- **Golden baking:** done by temporarily printing hashes inside the GdUnit suite (standalone `-s` scripts can't resolve project class names). Six goldens baked on macOS arm64 / Godot 4.6.stable; cross-platform verification note: re-run the golden suite on Windows/Linux when those become available (expected identical — CPU integer/IEEE math only).
- Parts 1+2 built in one pass (continuous session); the interim "fill/rotate disabled" toolbar state was never shipped.

**Context:** Slice 1 implementation. All contracts (DrawingDoc format, DocRasterizer/ReplayPlayer APIs, canvas signals) match the TDD verbatim.

---

### Skeleton toolchain pins & export settings
**Date:** 2026-07-06 | **Slice:** 0 | **Type:** Quick

**Decision:**
- **Godot:** 4.6.stable.official.89cea1439 (Homebrew). **GdUnit4:** v6.1.3, vendored from `godot-gdunit-labs/gdUnit4` into `addons/gdUnit4`.
- **Test command:** `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/` (flag mandatory; consistency guide §9 updated).
- `rendering/textures/vram_compression/import_etc2_astc=true` (required for macOS arm64/universal export).
- `config/version` must be plain dotted-numeric (`0.1.0`) — Windows export rejects suffixes like `-dev`. Slice 15's `APP_VERSION` scheme stays plain semver.

**Context:** Skeleton chunk installation and export verification. Debug exports for all three OSes build clean from CLI; export templates 4.6.stable were already installed.

---

### Session 2 pacing: continuous multi-chunk session, playtest gates batched
**Date:** 2026-07-06 | **Slice:** 0–3 | **Type:** Quick

**Decision:** This session implements Skeleton + Slices 1–3 end-to-end without per-chunk stops (owner directive, overriding the one-chunk-per-session default for this session only). Blocking playtest gates are handled as: (a) automated equivalents where machine-verifiable (e.g. `tools/verify_connect.sh` for the two-instance ENet gate; scripted loopback round tests for the MVP gate), and (b) a single batched owner-playtest checklist at session end. Slices are documented as "implementation complete — pending owner confirmation," never COMPLETE, until the owner confirms (per testing-protocol deferred-testing rules). Owner checks in after Slice 3 to decide whether to continue or reset context.

**Context:** Owner explicitly requested compressing multiple chunks into one session ("complete the skeleton and multiple slices... continue onto the next slice instead of stopping"). Documentation cadence (implementation notes + WHERE_WE_ARE per slice) is unchanged. Git is owner-managed; the AI never commits.

---

### TDD drafting reconciliation — contract refinements & judgment calls
**Date:** 2026-07-04 | **Slice:** Multiple | **Type:** Quick

**Decision:** The following calls were made while drafting slice TDDs 01–15 in parallel; the consistency guide and skeleton guide were amended to match. If any are wrong, veto before the affected chunk starts.

*Contract refinements (consistency/skeleton guides updated):*
- Authoritative rasterization (fill, replay, export, golden tests) is **CPU-side** (`DocRasterizer`); GPU/SubViewport is display-only — cross-platform determinism (Slice 1).
- `collection/index.json` uses a versioned envelope `{"v":1,"items":[...]}` (Slices 4/8 converged independently).
- Canonical `SessionClient` (all peers, owns RPCs) / host-only `GameSession` simulation split (Slice 3).
- `PlatformBackend.create_host_peer/create_client_peer` are awaitable coroutines (Steam lobby ops are callback-async; Slice 12).
- Nested data classes referenced qualified (`Roster.PlayerState`).

*Design judgment calls (owner may veto):*
- **Superlative-winning drawings also earn the +1 title point** (literal reading of brief §11 "titles/superlatives: +1 each"), gated by `title_points_enabled` (Slice 10).
- Rotating canvas orientation mid-drawing clears the canvas after a confirm dialog (Slice 1).
- Captions are not persisted with collection saves in v1 (Slice 5/8).
- `kudos_allotment = 0` (kudos off) allowed in Custom only; min-1 clamp applies to auto-compute (Slice 4/6).
- Lobby public/private visibility fixed at creation; all Steam lobbies are search-public, "private" = `aq_public="0"` metadata + code/invite as the privacy bar (Slices 12/13).
- Mid-turn judge disconnect: seat holds, window lapses → −1 no-pick; late joiners draw from the next round but react/kudos immediately (Slices 3/9).
- Defaults pending playtest: `DRAW_TIME_DEFAULT_SEC = 30`, pool-setup force-continue at 120s.
- Slice 14 adds a `Stats` autoload beyond the skeleton's original five.

**Context:** Fifteen TDDs drafted by five parallel agents against shared contracts; cross-interface audit fixed three mismatches (Slice 14's `winner_player_id` + `kudos_given`, Slice 13's lobby-metadata key names) and confirmed the rest (kudos ledger fields, `joined_order`, opaque drawing ids).

---

### Session pacing: hard 180k context budget, 18 chunks
**Date:** 2026-07-04 | **Slice:** All | **Type:** Quick

**Decision:** Work sessions follow the original 18-chunk plan with a hard ~180k-token context budget per session, ending every session at a clean checkpoint via the Session End workflow.

**Context:** The AI (Claude Fable 5) has a 1M-token context window, so consolidation to ~11 sessions with a soft 300k ceiling was proposed and viable. Owner chose maximum conservatism: cheaper individual sessions, more frequent playtest gates, guaranteed-clean handoffs. Chunk boundaries may still flex if a session runs cool (pull work forward) or hot (checkpoint early).

---

### Slice TDD authoring: shared docs centralized, per-slice TDDs drafted in parallel
**Date:** 2026-07-04 | **Slice:** All | **Type:** Quick

**Decision:** The consistency guide, skeleton guide, and all cross-slice contracts (RPC conventions, DrawingDoc format, save layout, phase enum, EventBus pattern) were authored centrally first; the 15 per-slice TDDs were then drafted by parallel subagents against those contracts and reviewed for coherence.

**Context:** Keeps the initialization session inside its own context budget while preventing agents from inventing conflicting patterns.

---

## Initial Tech Stack Decisions

### Initial Tech Stack Selection
**Date:** 2026-07-04 | **Slice:** All | **Type:** Full

#### Context
Project initialization — selecting the technology stack for a 3–8 player online drawing party game shipping on Steam for Windows/macOS/Linux from a single codebase, with Steam relay networking, a custom stroke-based drawing canvas, and local-first persistence.

#### Decision
- **Engine:** Godot 4.6 (stable), typed GDScript (static typing mandatory)
- **Steam integration:** GodotSteam GDExtension — lobbies, invites, achievements, SteamMultiplayerPeer relay transport
- **Networking architecture:** host-authoritative sessions over Godot high-level multiplayer; transport swappable behind a `PlatformService` (ENet backend for dev/LAN, Steam backend for shipping)
- **Persistence:** JSON files in `user://` (one file per saved drawing + index; profile; stats)
- **Testing:** GdUnit4, headless-runnable
- **Dev App ID:** Steam 480 (Spacewar) until a real App ID is registered (needed by Slice 12)

#### Rationale
- Godot: best-in-class 2D/UI for a menu-and-canvas game, free/open-source, single-codebase export to all three target OSes, small binaries.
- GodotSteam's SteamMultiplayerPeer plugs Steam Datagram Relay directly into Godot's RPC system, matching the host-authoritative design and §13 IP-privacy requirement.
- Typed GDScript: engine-native speed of iteration with most of the type-safety benefit; enforced via the consistency guide.
- ENet dev mode: multiplayer testing as multiple local instances without Steam accounts; also the seam for any future non-Steam build.
- JSON over SQLite: all persisted data is small (stroke data is KBs); human-readable, zero dependencies; v1 collection browser needs no querying.

#### Alternatives Considered
1. **Unity + Steamworks.NET/Mirror:** workable but heavier editor, more boilerplate, licensing overhead, weaker fit for 2D UI-heavy game.
2. **Electron/Tauri + TypeScript:** best canvas APIs, but weakest Steam relay networking story — ruled out on the §13 requirement.
3. **C# in Godot:** stronger tooling but adds .NET export complexity; Steam bindings a step behind the GDScript path.
4. **SQLite (godot-sqlite):** unnecessary dependency for v1 data shapes.
5. **Steam-only, no dev transport:** rejected — every multiplayer test would need multiple Steam accounts.

#### Impact
- **Affects:** All slices
- **Migration needed:** N/A (initial setup)
- **Breaking change:** N/A

#### Status
- [x] Documentation updated (Recipe, Consistency Guide, Skeleton Build Guide)
- [ ] Code implemented (Skeleton — Chunk 1)
- [ ] Tests updated
- [ ] Integration verified
