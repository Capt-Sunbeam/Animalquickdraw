# Slice 15: Release Preparation
## App ID swap, export hardening, signing/notarization, Steam depots & config, legal pass, performance pass, full-game playtest

**Version:** 1.0
**Last Updated:** 2026-07-04
**Dependencies:** All slices (0–14) complete
**Provides:** Shippable, signed, uploadable builds for Windows/macOS/Linux; configured Steamworks app (achievements, rich presence, store page inputs); finalized legal wording; verified performance and full-game playtest sign-off

---

## 1. Overview

This slice is checklist-heavy and light on new code: it turns a finished game into a shippable Steam product. Most work is configuration, tooling scripts, owner accounts/paperwork, and verification passes. Several tasks are **owner tasks with lead time** — flagged inline and gathered in Section 12; start the long-lead ones (App ID registration, Apple Developer account) well before the rest of this slice.

### Scope

**In Scope:**
- Dev App ID 480 (Spacewar) → real App ID swap behind one constant
- Export hardening: release presets, icons, version numbering scheme
- macOS codesign + notarization procedure; Windows/Linux packaging
- Steam depot/build layout + `steamcmd` upload scripts in `tools/steam/`
- Steamworks partner-site config: achievements (Slice 14 table), rich presence strings (Slice 12), store metadata
- Final legal wording pass on the 18+/unmoderated notice (§12; Slice 13's `PUBLIC_NOTICE_VERSION` bump)
- Performance pass (canvas, 8-player reveal, wrap-up bundle) and day-one default-settings sanity
- Full-game playtest checklist: every mode + §9 connectivity scenarios
- Store assets (screenshots, capsules) — flagged as owner/art tasks

**Out of Scope:**
- New gameplay features or balance changes beyond constant tuning
- Localization (English-only v1)
- Windows code signing certificate (optional for Steam; ship unsigned in v1 unless owner decides otherwise — SmartScreen warnings only affect non-Steam distribution)
- Post-launch patching pipeline / branches beyond `default` + a `beta` branch

---

## 2. Data Models

N/A — no new runtime data structures. All persisted formats (DrawingDoc v1, profile/stats/collection JSON) are frozen as of Slice 14; any change now would require a version bump and is out of scope.

---

## 3. Event/Action Definitions

N/A — no new RPCs or EventBus signals. The release build must ship with the exact network surface tested in Slices 0–14.

---

## 4. Storage Schema Extensions

N/A — no `user://` changes. One behavioral note: bumping `GameConstants.PUBLIC_NOTICE_VERSION` (Section 6) re-prompts the 18+ dialog once per install by design (Slice 13 §4) — this is a constant change, not a schema change.

---

## 5. State Machines

N/A — no new states or transitions.

---

## 6. Business Logic

The only code in this slice:

**File: `res://core/constants/game_constants.gd`** (edits)
```gdscript
const APP_VERSION: String = "1.0.0"        # single source of truth — see scheme below
const STEAM_APP_ID: int = 480              # OWNER TASK: replace with real App ID before release builds
const PUBLIC_NOTICE_VERSION: int = 2       # bump iff legal pass changes wording (Slice 13)
const PUBLIC_NOTICE_TEXT: String = "..."   # final lawyer-reviewed wording (§12)
```

**Version numbering scheme:** semver `MAJOR.MINOR.PATCH` — `1.0.0` at launch; PATCH = fixes, MINOR = content/feature updates, MAJOR = reserved. `APP_VERSION` is read by: main-menu version label, lobby metadata `aq_ver` (Slice 12 — keeps incompatible builds out of each other's browsers), and the build scripts (depot description). `project.godot` `config/version` and export preset versions must be set to the same string — a release checklist item, verified by a unit test comparing `ProjectSettings.get_setting("application/config/version")` to `APP_VERSION`.

**App ID swap:** `SteamBackend` initializes GodotSteam from `STEAM_APP_ID`; `steam_appid.txt` (dev-only convenience file) must be **excluded from release exports** (export filter) — shipping it is a common leak that breaks Steam launch attribution.

---

## 7. UI Components

No new screens. Three touch-ups:
- Main menu gains a small `APP_VERSION` label (bottom corner).
- `PUBLIC_NOTICE_TEXT` final wording lands in Slice 13's existing dialog + browser banner.
- Icon set applied: window/taskbar icon in `project.godot`, plus per-platform export icons (Section 12).

### User Confirmation Checkpoints
- [ ] **Full-game playtest sign-off** (blocking — this *is* the slice's exit gate): Section 11 matrix completed by the owner
- [ ] **Notice wording approved** (blocking): owner (with legal review, §12) approves final text before builds
- [ ] **Store assets approved** (blocking for store release, not for build work): owner signs off capsules/screenshots

---

## 8. State Management

N/A — no new autoloads, stores, or signals.

---

## 9. Integration Points

### Dependencies (What This Slice Needs)
- **Slice 14:** frozen achievement id table (Steamworks config input)
- **Slice 12:** rich presence string keys + lobby metadata `aq_ver`; SteamBackend init path for the App ID swap
- **Slice 13:** `PUBLIC_NOTICE_VERSION`/`PUBLIC_NOTICE_TEXT` constants for the legal pass
- **Slice 6:** mode preset constants (`settings_defaults.gd`, draw-time defaults in `game_constants.gd`) for day-one tuning
- **Skeleton:** export presets (debug) to harden into release presets

### Steamworks partner-site configuration map (owner + AI-assisted, needs real App ID first)

| Steamworks section | Source of truth in repo |
|--------------------|-------------------------|
| Achievements (12: API name, display name, description, icons ×2) | Slice 14 §2 table (API names must match **exactly**) |
| Rich presence localization file | Slice 12 TDD's string keys |
| Store page (description, tags, specs, unmoderated-UGC content survey answers) | `game-design-brief.md` + this slice's asset list |
| Depots & launch options | Section 12 depot layout + `tools/steam/` scripts |
| Steam Input / controller | None — declare mouse/keyboard only (v1) |

### Provides
- `tools/steam/` upload pipeline and release presets for all future patches
- The release checklist itself (Section 12) as the template for post-launch updates

---

## 10. Edge Cases

### macOS Gatekeeper rejects the build
**Scenario:** Users get "app is damaged / unidentified developer" despite signing.
**Handling:** The Section 12 procedure requires hardened runtime + the Godot-required entitlements (JIT, unsigned executable memory, dyld env, disable-library-validation — the GodotSteam `.framework`/dylib needs the last one), notarization **and stapling**, verified with `spctl -a -vv` on a clean machine before upload. Steam's own download path also strips quarantine, but direct-download testers hit Gatekeeper — staple regardless.
**Rationale:** Notarization failures are the classic macOS release trap; verify on a machine that never saw the dev cert.

### Real App ID arrives late
**Scenario:** Steamworks registration (owner task: $100 fee + partner onboarding + store review lead time, typically weeks) isn't done when builds are ready.
**Handling:** Everything except partner-site config and real-App-ID smoke tests proceeds on 480. The swap is one constant + config; schedule store review with Valve's ~2-week minimum review windows in mind.
**Rationale:** Decouple code-readiness from paperwork; that's why `STEAM_APP_ID` is a single constant.

### Linux runs outside the Steam Runtime
**Scenario:** Distro-specific glibc/driver issues on exotic setups.
**Handling:** Export x86_64 against the Steam Linux Runtime (sniper) target; test via Steam client on one Debian-family and one Arch-family box. Ship no system dependencies beyond the runtime.
**Rationale:** §2 requires Linux first-class; the runtime is the sane support boundary.

### Leftover dev artifacts in release builds
**Scenario:** `steam_appid.txt`, `--platform=enet` defaults, debug logging, or GdUnit4 shipping to players.
**Handling:** Release preset export filters exclude `steam_appid.txt`, `tests/`, `addons/gdUnit4/`; release builds default to the Steam backend (skeleton §3.2 flag flips); a smoke test launches the release build with no args and asserts Steam init path.
**Rationale:** Preset hardening is exactly this slice's job.

### Performance regressions only visible at 8 players
**Scenario:** Reveal grid or wrap-up feels fine at 3 players, hitches at 8.
**Handling:** Section 11 performance pass scripts an 8-instance LAN session; budgets: steady 60 fps on the dev machine during drawing; reveal raster of 8 drawings < 1 frame each (cached textures, guide §12); full-replay reveal at cap speed with no hitch; wrap-up bundle < 2 MB and applied without a visible stall.
**Rationale:** 8 is the hard max (§3) and the only interesting perf point.

---

## 11. Testing Strategy

### Unit Tests
- [ ] `test_app_version_matches_project_settings_version`
- [ ] `test_public_notice_version_bumped_when_text_changed` (guard: hash of text recorded alongside version)
- [ ] Full existing suite green on the **release** export template (headless run against release build where feasible)

### Release Verification (per platform: Windows, macOS, Linux)
- [ ] Release export builds from CLI (`godot --headless --export-release <preset>`)
- [ ] Launches from Steam client (real App ID) with overlay, invites, relay networking functional
- [ ] macOS: `codesign --verify --deep --strict`, `spctl -a -vv`, notarization `Accepted`, stapled
- [ ] No dev artifacts present (Section 10 filter list spot-checked inside the package)

### Performance Pass
- [ ] 8-player LAN session: drawing phase 60 fps; fill tool < 50 ms budget holds (guide §12)
- [ ] 8-drawing one-at-a-time reveal with full replay: no frame hitches
- [ ] Wrap-up with maximal evidence bundle: broadcast + sequence smooth on min-spec (1280×720 window)

### Full-Game Playtest Matrix (owner sign-off — blocking)
- [ ] **Default mode**, built-in pools, 4 players → wrap-up: scoring, kudos, titles all sane
- [ ] **Streamlined mode**: grid reveal, replay off, quick judging verified
- [ ] **Social mode**: one-at-a-time reveal + full replay + captions verified
- [ ] **Custom mode**: every exposed setting changed from default once; title-points toggle off verified in standings
- [ ] **Player-created pools** (§8): submission math, lock at start, silent backfill after attrition
- [ ] **§9 connectivity:** late join (rotation slot behind judge, half kudos); disconnect + rejoin (score restored, no kudos top-up); drop below 3 → pause → resume; pause → host early-end → wrap-up on partial data; submitted drawing of a dropper still judged
- [ ] **§12/§13:** room-code join, Steam invite join, public browser join; kick + rejoin denial; notice once per install
- [ ] **Achievements (§11/§14):** at least first_game, first_hotshot, all_kudos_spent unlock live on Steam
- [ ] **Day-one settings sanity:** draw-time defaults per mode, kudos allotment, replay speed caps, suggested round count — final values from these playtests written back into `game_constants.gd`/`settings_defaults.gd` (constant tuning, no logic changes)

---

## 12. Implementation Checklist

### Owner tasks — start FIRST (long lead time)
- [ ] **OWNER:** Steamworks app registration (real App ID; $100; partner agreement; allow weeks incl. store review)
- [ ] **OWNER:** Apple Developer Program account active ($99/yr) + Developer ID Application certificate issued
- [ ] **OWNER:** Decide on Windows code signing (default: skip for v1)
- [ ] **OWNER/ART:** Store assets — header capsule 460×215, small 231×87, main 616×353, library 600×900 + hero/logo, ≥5 screenshots 1920×1080, optional trailer
- [ ] **OWNER:** Legal review of `PUBLIC_NOTICE_TEXT` final wording (§12)

### Code & constants
- [ ] `APP_VERSION` constant + main-menu label + `project.godot` version + version unit test
- [ ] `STEAM_APP_ID` constant wired through SteamBackend init; swap to real App ID when issued
- [ ] Final notice text landed; `PUBLIC_NOTICE_VERSION` bumped iff wording changed
- [ ] Day-one default constants updated from playtest results

### Export hardening
- [ ] Release presets (Windows/macOS/Linux): release templates, `APP_VERSION` set, export filters exclude `tests/`, `addons/gdUnit4/`, `steam_appid.txt`
- [ ] Icons: `.ico` (Windows preset), `.icns` (macOS preset), PNG set (Linux/project icon)
- [ ] Release build defaults to Steam backend; ENet only via explicit `--platform=enet`

### macOS codesign + notarization (documented procedure — `tools/release/notarize_macos.md`)
- [ ] Entitlements plist: `com.apple.security.cs.allow-jit`, `allow-unsigned-executable-memory`, `allow-dyld-environment-variables`, `disable-library-validation`
- [ ] Godot preset codesigning with Developer ID + hardened runtime + entitlements (or manual `codesign --deep --force --options runtime --entitlements ...`)
- [ ] `ditto -c -k --keepParent AnimalQuickdraw.app aq.zip` → `xcrun notarytool submit aq.zip --keychain-profile aq-notary --wait` → `xcrun stapler staple AnimalQuickdraw.app`
- [ ] Verify on clean machine: `spctl -a -vv`, first-launch OK

### Windows / Linux packaging
- [ ] Windows: exe + pck (embedded pck preferred), icon + file metadata verified
- [ ] Linux: x86_64 binary, Steam Linux Runtime target, executable bit preserved in depot

### Steam depots & upload (`tools/steam/`)
- [ ] Depot layout: content depot per OS (AppID+1 win / +2 mac / +3 linux), shared `default` branch + `beta` branch
- [ ] `app_build.vdf` + three `depot_build_*.vdf` + `upload_build.sh` (steamcmd login → run_app_build; build desc = `APP_VERSION` + git short hash)
- [ ] Launch options per OS configured on partner site; test install via `beta` branch on all three OSes

### Steamworks configuration (needs real App ID)
- [ ] All 12 achievements created with **exact API names** from Slice 14 §2, names/descriptions/icons; published
- [ ] Rich presence localization file uploaded (Slice 12 keys)
- [ ] Store page: description, tags, UGC/content survey ("unmoderated user-generated content" disclosed, §12), system requirements, assets uploaded
- [ ] Steam relay networking (SDR) config confirmed enabled for the app (§13)

### Verification passes
- [ ] Section 11 unit + release verification per platform
- [ ] Performance pass complete; any fixes are constant/caching-level only
- [ ] Full-game playtest matrix complete with owner sign-off (**blocking exit gate**)

### Documentation
- [ ] Update WHERE_WE_ARE (project → release-ready); Implementation Notes with exact tool versions, cert identities (redacted), upload procedure dry-run log
- [ ] Decision Log: final day-one constant values + rationale; any deviations from this checklist
