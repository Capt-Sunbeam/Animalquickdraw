# macOS Signing + Notarization Procedure

**First executed:** 2026-08-13 (session 18, friend-build packaging — pulled forward from Slice 15).
**Owner one-time setup (done 2026-08-13):** Developer ID Application certificate
`Developer ID Application: SunSpark Studios LLC (DUZCV4LM3M)` in the login keychain; notary
credentials stored as keychain profile **`scribble-notary`** (Apple ID daw7423@gmail.com,
team DUZCV4LM3M, app-specific password). Neither needs touching again; certificates renew
via Xcode → Manage Certificates.

> The Slice 15 TDD (§12) wrote this procedure with profile name `aq-notary` — the real
> profile is **`scribble-notary`** (post-rename). Reconcile the TDD when Slice 15 runs.

## Procedure (per release)

All paths relative to project root. Identity + entitlements are constants:

```bash
IDENT="Developer ID Application: SunSpark Studios LLC (DUZCV4LM3M)"
ENT="tools/release/entitlements.plist"
```

1. **Export** (unsigned; preset `codesign/codesign=0` stays as-is — we hand-sign):
   ```bash
   godot --headless --path . --import
   godot --headless --path . --export-release "macOS" "builds/macos/Scribble Safari.app"
   ```

2. **Sign** — nested dylibs first, then the bundle:
   ```bash
   cd builds/macos
   codesign --force --options runtime --timestamp -s "$IDENT" \
     "Scribble Safari.app/Contents/Frameworks/libgodotsteam.macos.template_release.dylib" \
     "Scribble Safari.app/Contents/Frameworks/libsteam_api.dylib"
   codesign --force --options runtime --timestamp --entitlements "../../$ENT" -s "$IDENT" "Scribble Safari.app"
   codesign --verify --deep --strict --verbose=2 "Scribble Safari.app"
   ```

3. **Notarize + staple:**
   ```bash
   ditto -c -k --keepParent "Scribble Safari.app" ss-notarize.zip
   xcrun notarytool submit ss-notarize.zip --keychain-profile scribble-notary --wait
   xcrun stapler staple "Scribble Safari.app"
   spctl -a -vv "Scribble Safari.app"   # want: "accepted", "source=Notarized Developer ID"
   ```

4. **Distribute** — re-zip the STAPLED app (the notarize zip lacks the ticket):
   ```bash
   ditto -c -k --keepParent "Scribble Safari.app" ScribbleSafari-macOS.zip
   ```
   On failure, fetch the report: `xcrun notarytool log <submission-id> --keychain-profile scribble-notary`.

## Load-bearing lessons (2026-08-13)

- **NEVER put `steam_appid.txt` inside the .app.** codesign treats any file in
  `Contents/MacOS/` as nested code → "code object is not signed at all", verification fails.
  It is also unnecessary: `SteamBackend` passes `APP_ID` to `Steam.steamInitEx()`, and
  GodotSteam sets the `SteamAppId` env vars from it. **Machine-verified 2026-08-13:** the
  signed app, run from a directory with no `steam_appid.txt`, attached to a running Steam
  client (S_API loaded steamclient.dylib, breakpad AppID 480, Steam ID cached). Friend
  builds need only "Steam open and signed in". (Windows zips still carry the txt beside the
  exe as harmless belt-and-suspenders — no signing there to break.)
- Signing must happen AFTER any bundle content changes; if anything is added/removed,
  re-sign the outer bundle (nested dylib signatures survive).
- The 4 entitlements in `entitlements.plist` are required (Godot JIT/unsigned-exec-memory/
  dyld-env + disable-library-validation for the GodotSteam dylibs). Missing the last one
  kills the GDExtension load under the hardened runtime.
- The export ships `tests/` + `addons/gdUnit4/` (no exclude filters yet) — acceptable for
  playtest builds; hardening is a Slice 15 checklist item.
