# Decision Log: Animal Quickdraw

**Purpose:** Track design decisions made during development. New entries are added at the top of the Decisions section.

**Last Updated:** 2026-07-12

---

## Decisions

*New entries go here, at the top of this section.*

---

### Art pass: wallpaper + font SHIPPED (concurrent session 13) — capture standard, loop-field tile, class-normalized metrics
**Date:** 2026-07-12 | **Slice:** Art pass (unnumbered) | **Decided by:** Owner + AI, iterating on live builds | **Type:** Quick

**Decision:** (1) **Collage capture standard = dark-background photos** — the owner's white-on-grid single-photo idea was tried honestly and failed on physics (curled-paper crease shadows are locally indistinguishable from bold strokes); dark cloth erases the failure class. (2) **Grid-paper batches use darkness thresholds** (`--paper-tol 0.18 --noise-floor 0.3`, now `process_incoming.py` defaults) because phone JPEG chroma desaturates thin blue grid to grey, defeating color-based suppression; plus an automatic binder-hole disk filter. (3) **Idempotent batch processing via `incoming/` → `done/` folder moves** — owner rejected a content-hash manifest as over-engineered. (4) **Wallpaper = drifting loop-field** (owner design: slow pan revealing ~3–4 screens of art): 1800² tile, ALL 130 stickers exactly once, seed 4 (`compose_tile.py`; same seed = same tile) → `assets/ui/wallpaper_tile.png` (only collage artifact in git) + `menu_wallpaper.gd`/`.gdshader` UV-scroll (Control-position animation pixel-snaps = jitter; and canvas_item fragment COLOR arrives pre-multiplied by the unscrolled texture — overwrite, never multiply). `b1_button.png` gained the solid paper fill (wallpaper showed through). (5) **Font metrics = typographic class normalization** — owner explicitly REJECTED preserving as-drawn letter sizes ("ransom note"): caps 660/digits 640/x-letters 460/ascenders 680/descenders −200, per-char symbol table (`build_font.py METRICS`). (6) **Charset mapping follows the owner's real box order** (upper row 6 is `( ) _ ^ _`; no `&` drawn — initial miscatalog rendered parens as carets). Per-glyph despeckle: single-stroke chars keep only components ≥25% of the main body; `MULTIPART_CHARS` exempt. (7) 81 glyphs shipped as theme `default_font` (`assets/fonts/aq_hand.ttf`); **undrawn chars (`. , ' - & + =`) ride Godot's system-font fallback** until drawn. potrace + fontforge brew-installed (owner consent).

**Status:** [x] Wallpaper owner-approved live [x] Font owner-approved in 3-instance gameplay [ ] Owner draws missing punctuation (any time) [ ] Wallpaper reuse on lobby/wrap-up (deferred)

---

### Art pass: style + pipeline decisions (discussion session) — pure line art, DIY printerless font, tileable wallpaper, pilot-first
**Date:** 2026-07-11 | **Slice:** Art pass (unnumbered; plan doc `TDD/art-pass-plan.md`) | **Decided by:** Owner + AI discussion | **Type:** Quick

**Decision:** (1) **UI style = pure black-ink line art** (ballpoint), color added digitally (engine tint / fills under lines); owner draws with breathing room so digital bolding stays viable. (2) **Capture = phone photos, batched** — multiple elements per sheet with margin IDs; collage scraps laid on a **dark background** for auto-segmentation; owner's light-blue grid paper is fine (blue-channel filtering; grid even helps draw straight 9-slice boxes). (3) **Wallpaper = extracted stickers composed into a seamless TILEABLE texture** (wrap-around composition is scripted, not physical) — scripted scatter with density/size/rotation knobs, owner picks from seeded candidates; line-art tile enables in-engine tinting (full-strength on menu, faint watermark elsewhere). (4) **Font = DIY printerless pipeline** (owner has no printer): hand-drawn grid boxes on grid paper with a grid-line baseline → glyph extraction → potrace + FontForge → TTF. Calligraphr-at-a-library is the fallback. (5) **Pilot before scale:** one button + one panel + one icon (+ optional font strip) + one collage batch through the WHOLE pipeline into the live theme, owner look-check as exit gate — validates the risky stack (ballpoint + grid paper + phone light) before the full drawing checklist is generated. Brief: `TDD/art/pilot-brief.md`; pipeline: `tools/art_pipeline/clean_scan.py` (elements + scraps modes, validated on synthetic photos); `art_drops/` gitignored.

**Resolved same day (owner, 2026-07-11):** (a) the in-drawing text tool KEEPS PixelFont as-is (wire-format; deliberate contrast with the UI handwriting font); (b) sound is OUT of the art pass — it gets its own session later. (c) **Font charset (owner-prepped sheets):** owner pre-drew 80 boxes (4×4 grid squares each) → 26 uppercase + 26 lowercase + 10 digits + 18 punctuation/symbols; any character NOT drawn falls back to a bundled simple sans via Godot's font-fallback chain (so arbitrary Steam names/chat always render). Character order + writing rules: `TDD/art/font-sheet-guide.md`.

**Status:** [x] Pipeline script built + synthetic-tested [x] Pilot photos (B1/P1/2 font sheets, 2026-07-11) [x] Pilot in-game look-check — **UI skin OWNER-APPROVED 2026-07-11** ("it looks so good!"); font TTF + collage legs continue (collage in concurrent session)

---

### Slice 13: security audit fix - control chars stripped from ALL broadcast text (chat line spoofing)
**Date:** 2026-07-11 | **Slice:** 13 (touches 2's chat + 7's pool words) | **Decided by:** Owner directive ("make sure no commands can get through the chat") + AI audit | **Type:** Quick

**Decision:** The owner-expanded text-input security audit found one real hole: chat was censored but NOT control-char-stripped, so a modified client could send `"hi\nAlice: ..."` and every peer's chat history would render a line spoofed from another player. Fix: `TextFilter.strip_control_chars()` (new shared home; `sanitize_name` refactored onto it) now runs in `_handle_chat` before censoring (empty-after-clean drops), and pool-word validation rejects ANY control char (was `\n` only). Audit verdict on everything else: clean - exactly one RichTextLabel exists (chat, push-API only, BBCode never parsed - pinned), zero `Expression`/`OS.execute`/`parse_bbcode`/`bbcode_enabled` anywhere, user text reaches file names only through `slugify`'s [a-z0-9-] whitelist + `Save._path_ok` traversal guard. Full audit table in the Slice 13 implementation notes.

**Status:** [x] Implemented + pinned (`test_chat_strips_control_chars_against_line_spoofing`, pool-word control-char cases)

---

### Slice 13: reconciliations against shipped Slice 12/2/9 reality (deny strings, kick-on-Session, privacy flag, coroutine list, visibility toggle)
**Date:** 2026-07-11 | **Slice:** 13 | **Decided by:** AI (TDD 13's own "Slice 12 is authoritative" rule) + owner plan approval | **Type:** Quick

**Decision:** (1) **"kicked" is a string deny reason**, not the TDD's `JoinDenyReason` enum - Slice 2/9 shipped string keys through `rpc_do_reject_join`; the blocklist check is a defaulted param on both `SessionRules` gates, checked FIRST (honest reason beats "full"). (2) **Kick lives on `Session`**, not GameSession - roster/peers/handshake live there and lobby-phase kicks have no GameSession; the kicked departure reuses the existing disconnect branches + `PlayerStatus.KICKED` (append-only enum). (3) **Privacy = `aq_public` filter**, not `FRIENDS_ONLY` lobby type (Slice 12: everything Steam-PUBLIC for code search); browser filters proto+public+state Steam-side AND re-validates in `LobbyListing`'s strict parse. (4) **Lobby list is an awaitable coroutine** (`Platform.request_lobby_list()`), not EventBus signals - Slice 12's backend-contract style; only the browser consumes it. (5) **Public/Private is the existing Slice 9 lobby toggle** (host-only, changeable in-lobby), not fixed-at-creation - the shipped metadata is dynamic, the notice gates the BROWSER join path so nothing is bypassed, and `set_value(&"is_public")` already re-derives fluid_rejoin. (6) **In-game (`aq_state="ingame"`) lobbies are hidden** from the browser (late join stays possible by code/invite). (7) Post-connect handshake rejects land on the MENU (every join path's flow), not back in the browser.

**Status:** [x] Implemented (556 tests green, 3 gates PASS) [x] Kick end-to-end owner-confirmed 2026-07-11 [ ] Browser two-account pair

---

### Slice 12: API/contract deviations vs the TDD draft (stats init, invite routing, tiebreak)
**Date:** 2026-07-11 | **Slice:** 12 | **Decided by:** AI (API reality) + owner direction | **Type:** Quick

**Decision:** (1) **Stats init:** Steamworks SDK 1.64 removed `requestCurrentStats`/`current_stats_received` (ClassDB-verified) - `is_stats_ready()` = init success; Slice 14 must not wait on the callback. (2) **Invite routing lives in Session, not the menu** - accepts can arrive on any screen and the confirm dialog must survive scene swaps; menu only renders states. Slice 13's browser joins should reuse `Session.join_session_by_lobby()`. (3) **Code-collision tiebreak** = highest member count, then Steam's result order (creation time isn't on the wire; TDD said "newest"). (4) **Lobby privacy note (per TDD):** all lobbies are created Steam-`PUBLIC` (search requires it); "private" = `aq_public:"0"` + obscure code - the intended bar for a party game. (5) **Dev-testing guarantee (owner requirement 2026-07-11):** ENet stays the editor/dev/test default - only exported builds default to steam; regression-pinned (`test_editor_runs_default_to_enet`).

**Status:** [x] Implemented (532 tests green, 3 gates PASS, Steam smoke PASS) [ ] Owner two-account protocol

---

### Slice 12: GodotSteam GDExtension 4.20 vendored (version pin)
**Date:** 2026-07-11 | **Slice:** 12 | **Decided by:** AI (per TDD §12 setup) | **Type:** Quick

**Decision:** Vendored **GodotSteam GDExtension 4.20** (release tag `v4.20-gde`, published 2026-06-24; Steamworks SDK **1.64**; compatibility_minimum Godot 4.4) into `addons/godotsteam`, unmodified from upstream (`godotsteam-4.20-gdextension-plugin-4.4.zip` from the project's Codeberg releases). All shipping platforms covered (win64/osx/linux64) plus upstream extras (win32/linux32/linuxarm64/androidarm64) — kept intact so upgrades are a clean folder swap. The bundled editor plugin (`plugin.cfg`) is only an update-checker dock and is left **disabled**; the GDExtension itself loads from `godotsteam.gdextension` regardless. `steam_appid.txt` (`480`) committed at project root for dev; **must be excluded from shipping builds** (Slice 15 checklist). Verified post-import: `Steam` singleton, `SteamMultiplayerPeer`, `steamInitEx`, `createLobby` all registered headlessly with ENet still the default backend.

**Status:** [x] Vendored + import verified [ ] Slice 12 implementation on top

### Slice 18 rework: D doubles as a click; zoom navigation via minimap (fix over scrap)
**Date:** 2026-07-10 | **Slice:** 18 (same-session owner rework) | **Decided by:** Owner | **Type:** Quick

**Decision:** First playtest found zoom disorienting (no position sense; trackpad pan never arrived) and wanted D to click buttons too. Owner chose the full fix over scrapping zoom: (1) D outside the canvas synthesizes a left-click pair at the pointer (`push_input` viewport-local — one rule for all buttons, no stuck-press state); (2) a `CanvasMinimap` corner inset (visible while zoomed) shows the whole drawing + view rectangle, and click-drag or **hold-D-and-move** on it pans — answering "where am I?" and "how do I move?" in one widget; (3) trackpad gestures rerouted from `gui_input` to `_input` with an explicit hit-test (platform-flaky Control delivery was why pan "didn't exist"), wheel events scale by `factor` for precise trackpad scrolling. Text-chip drag stays real-click-drag (D-hold drag risks stuck state near text fields) — batchable.

**Status:** [x] Implemented (505 tests green, 3 gates PASS) [x] Owner re-check confirmed 2026-07-10 ("that's great"; minimap border polish applied same day)

---

### Slice 18 (mini) inserted: canvas ergonomics & display scaling before Steam
**Date:** 2026-07-10 | **Slice:** 18 (owner-inserted mini-slice, between Chunks 14 and 15) | **Decided by:** Owner | **Type:** Full

#### Context
Owner playtests surfaced three ergonomics problems: no window stretch mode (small windows clip text, fullscreen leaves the UI tiny), no canvas zoom for detail work, and click-drag drawing being hostile to trackpad players.

#### Decision
- **Insert a mini-slice now rather than after Slice 12** — every future playtest (including Slice 12's two-machine Steam tests) benefits, and zoom + hold-to-draw touch the same input path so batching avoids rework. TDD: `TDD/18-canvas-ergonomics.md`.
- **Window scaling = `canvas_items` stretch + `expand` aspect + 960×540 min window.** Chosen over per-screen responsive rework (the art pass restyles screens anyway) and over `keep` aspect (letterbox bars).
- **Canvas zoom is display-only and implemented INSIDE the SubViewport** (RasterView resize, not container scale): the ViewportBox's `stretch = true` ties render-target size to container size, so scaling the container would grow VRAM ~O(zoom²) (≈150 MB at 8× fullscreen). Internal raster resolution untouched — determinism not in play.
- **Hold-to-draw is an InputMap action (`draw_hold`, physical D) handled in `_unhandled_key_input`** — focused text fields consume typed keys first, making "typing d never inks" structural rather than a focus check. Stroke source is tracked so key and mouse releases stay independent.
- **Testing rule discovered:** suites driving OS-level simulated input must park `content_scale_mode = DISABLED` (the stretch transform makes simulated global positions miss); recorded in consistency guide §8.

**Status:** [x] Implemented (501 tests green, 3 gates PASS) [x] Owner checks cleared 2026-07-10 (trackpad flow confirmed after same-session rework; slice COMPLETE)

---

### Art pass: hand-drawn UI skin planned; slotted after Slice 14, before Slice 15 completes
**Date:** 2026-07-08 | **Slice:** Future mini-slice (all UI surfaces) | **Decided by:** Owner | **Type:** Quick

**Decision:** The owner will hand-draw the full UI skin (menus/panels/buttons via 9-slice scans, a custom handwriting font, and a main-menu wallpaper collaged from their existing hand-drawn animals). Plan captured in `TDD/art-pass-plan.md`. Ordering: finish Slices 12–14 and the batched testing first, THEN the art pass, THEN Slice 15's store assets + release-candidate playtest (those must happen with final art). Waiting until after Slice 14 also means the UI inventory (the drawing checklist) covers every screen once — nothing drawn twice.

**Scope guards:** the drawing palette and the text tool's PixelFont are deterministic wire-format constants — untouched by the art pass unless explicitly re-decided (versioned + golden rebake). Sound remains a separate open item.

**Status:** [x] Plan doc created [ ] Mini-TDD (at scheduling) [ ] Inventory generated [ ] Assets produced [ ] Integrated

---

### Slice 11: avatar sync keyed by platform_id, avatar rides the roster payload, AvatarStore seam, house set generated
**Date:** 2026-07-08 | **Slice:** 11 (extends 2's roster wire format; retrofits 3/17/10 surfaces) | **Type:** Full

#### Context
The Slice 11 TDD (drafted 2026-07-04) keyed avatar sync by peer_id, put load/save inline in the editor, and assumed a single "join accepted" send trigger. Since then Slice 9 standardized platform_id as the stable identity (peer ids zero out on disconnect), added a second join path (in-game welcome), and Slice 16 added text/eraser to the standard toolset.

#### Decision
- **`rpc_sync_avatar(platform_id, doc)` / `EventBus.avatar_updated(platform_id)`** — stable identity everywhere; chips survive rejoins with no special casing. Chip live mode: `bind_platform_id(pid, fallback_name)` (fallback keeps Session-free surfaces honest on roster misses).
- **The roster snapshot carries an optional per-player `"avatar"` key** (omitted when empty) — `rpc_sync_roster` and both welcome payloads deliver avatars for free; `rpc_request_set_avatar`/`rpc_sync_avatar` handle the initial upload + change broadcast. Host validation is `SessionRules.avatar_doc_error` (plain function, silent drop): ≤ 32 KB, valid doc, `"avatar"` orientation, ≤ 512 ops, non-empty.
- **`AvatarStore`** (static, path seam per CollectionStore.root_dir) centralizes `user://avatar.json` for its three consumers (editor, Session send trigger on THREE paths — host self-register, lobby welcome, in-game welcome — and the menu chip).
- **Circular mode = the Slice 1 mask hook activated:** `CircleMask` owns the one equation (mask image, contains, rim clamp, display alpha applied AFTER authoritative raster — goldens hash the unmodified raster). Text/eraser stay available in the editor (mask-correct by construction).
- **Name-circle small-size fallback:** below 48 px the circle shows the name's first two characters; the full name lives in the tooltip (a 9-char name in a 26 px circle is noise, not identity).
- **Deterministic house pick:** `hash(platform_id) % count` (name-hash fallback) — same doodle for the same player on every peer and across sessions, zero sync. The 6 shipped docs are generated programmer art (content-parse test pins them; format is the ordinary DrawingDoc, replaceable any time).
- **Anonymity hard rule holds:** no chips on reveal/judging grids (surfaces untouched).

#### Impact
- Affects: Slice 2 wire format (optional key, tolerated by from_dict defaults), Slices 3/17/10 surfaces (chips), Slice 12 (Steam names flow through `Platform.get_display_name()` with zero changes here), Slice 13 (house set / chips reusable)
- Migration needed: No
- Breaking change: No

#### Status
- [x] Code implemented [x] Tests updated (487/487, 0 orphans) [x] Gates PASS (lobby/round/resilience) [x] TDD + implementation notes updated [x] Slice 2 implementation notes annotated [ ] Owner confirmation (batched, end of session)

---

### Slice 10: wrap-up bundle rides the results broadcast — no dedicated RPC, no route, no begin_wrap_up
**Date:** 2026-07-07 | **Slice:** 10 (touches 3's RoundRecord, 9's results bundle) | **Type:** Full

#### Context
The Slice 10 TDD (drafted 2026-07-04) specified `rpc_sync_wrap_up_bundle`, `Routes.WRAP_UP` + `Nav.goto`, and a new `GameSession.begin_wrap_up(early)`. The shipped code (Slices 3/6/9) already has: a WRAP_UP phase broadcast carrying the results dictionary through `rpc_sync_phase` (the one replication channel), phase screens as RoundRoot children (never Nav routes), and both wrap-up entry paths (`_advance_round` natural end, Slice 9's `end_game_early`). Consistency guide/code reality wins.

#### Decision
- **The computed wrap-up bundle is `results["wrap_up"]`** — built by the new `WrapUpCalculator` inside `_build_results(early)`, broadcast once with the WRAP_UP phase, validated client-side (`SessionClient.is_valid_wrap_up_bundle`), never mutated. Base `final_scores`/`standings` keys stay BASE scores (Slice 3 shape pins + CI score-sum checks); title/superlative points live only in `wrap_up.standings`, the authoritative final display. Welcome snapshots deliver the bundle to WRAP_UP-time joiners for free.
- **Wrap-up screen is the WRAP_UP phase screen** (`ui/wrapup/wrap_up_screen.tscn` replaces the Slice 3 placeholder standings screen, which is deleted). EventBus order on every peer: `session_results_ready` → `wrap_up_started` → `titles_awarded` → `game_ended` → `phase_changed` (Slice 14's feed is safe even if the player quits mid-sequence).
- **`RoundRecord.reveal_order` records the post-shuffle entry order** — the superlative earlier-reveal tie-break key, captured at collect time, never re-derived.
- **Speed Demon interpretation:** finish time = last *stroke* timestamp (fill/clear/text ops are timestamp-less); ≥ 2 timestamped non-blank docs required; draw time is the frozen `draw_time_sec`.
- **Host quit mid-sequence defers via `Session.hold_host_quit`:** the wrap-up screen holds navigation while its local show plays; a pending quit degrades the post-game controls to Leave-only ("the wrapped moment is the payoff").

#### Impact
- Affects: Slice 14 (consumes the three signals + `wrap_up.kudos`/`rounds_completed` exactly as the TDD promised), Slice 11 (retrofits AvatarChip into title cards + standings rows)
- Migration needed: No (results readers tolerate unknown keys by contract)
- Breaking change: No

#### In passing (same session)
- Pre-existing Slice 5 bug fixed: `WinnerSpotlight._process` dereferenced `_player` after the finishing `advance()` synchronously nulled it via the `finished` handler — a script error on every natural victory-lap finish (gate-log noise since Slice 5; final still-frame update skipped). Local-capture fix here and in the new `SuperlativeCard`.
- CI pin rule, third instance: `verify_round`'s wallet check assumed the AUTO kudos allotment but never pinned it — the owner's real playtest profile carried `kudos_allotment: 2` and failed the gate. Pinned. Rule extended: **human playtest residue in `last_lobby_settings` is a third writer, alongside other gates.**

#### Status
- [x] Code implemented [x] Tests updated (453/453, 0 orphans) [x] Gates PASS (lobby/round/resilience) [x] TDD + implementation notes updated [ ] Owner confirmation (batched, end of session)

---

### Late joiners get the FULL standard kudos allotment (supersedes brief §11's half rule)
**Date:** 2026-07-07 | **Slice:** 9 | **Decided by:** Owner (during the Slice 9 blocking playtest)

**Decision:** A mid-game joiner receives the same kudos allotment every original player got at game start — not "half, floored, min 1." Rejoiners are unchanged (still exactly what they had left; never topped up).

**Rationale (owner + review):** Kudos give +1 to the *recipient*, so a full wallet is pure gifting power — no personal scoring advantage to joining late. Reacting/kudosing is precisely what a late joiner does while spectating their arrival round, and "everyone gets the same" is simpler to explain. Accepted trade-off: a final-round joiner can dump a full wallet and mildly inflate scores — noise, per flow-over-fairness (§1). A kudos-off game (explicit allotment 0) stays off for late joiners.

**Impact:** `admit_late_joiner` grants `_standard_allotment` directly; `late_join_allotment()` + its two constants deleted; brief §11 amended in place; tests updated. No wire/UI change.

**Status:** [x] Code implemented [x] Tests updated [x] Brief §11 amended [x] Implementation notes updated

---

### Slice 9: connectivity built on the existing pause/results/rotation machinery — cursor rotation, reason-tagged pause, wrap-up folded into the results bundle, absent-judge penalty matrix
**Date:** 2026-07-07 | **Slice:** 9 (state-machine changes to 3/17; extends 2/4/7 surfaces) | **Type:** Full

#### Context
The Slice 9 TDD (drafted 2026-07-04) assumed a cursor-based judge rotation, dedicated `rpc_sync_pause/resume` RPCs, and a standalone `get_wrapup_input()` payload. The code that actually shipped (Slices 3/6/17) has a modulo rotation, a full PAUSED-phase pipeline from the Esc menu, and a versioned results bundle. Consistency guide/code reality wins (WHERE_WE_ARE rule); the TDD's *behaviors* were kept, its *mechanisms* were adapted.

#### Decision
- **Rotation cursor replaces modulo:** `GameSession` now advances an explicit `_judge_cursor` each round (identical to the old `round % n` when nobody drops — pinned by the untouched Slice 3 sim harness). The cursor model is what makes late-join insertion, ghost-skip, and the OFF-mode forfeit possible. Late joiners insert immediately BEFORE the cursor entry (cursor +1), i.e. last in the cyclic order — they judge when the rotation wraps (§9), and rejoiners keep their original entry, so leave/rejoin can never move anyone's turn.
- **Below-minimum pause rides the Slice 6 PAUSED pipeline** — no new pause RPCs. `pause(reason)` gained a real reason (`NetIds.PauseReason`: HOST_MENU / BELOW_MINIMUM) carried in the PAUSED phase data with `connected_count` + `time_left_ms`; RoundRoot picks the surface by reason (GameMenu vs the new waiting overlay). Pause now also covers deadline-less POOL_SETUP (freeze with 0 remaining). Ordering rule: **a departure checks pause BEFORE all-ready re-evaluation or pool-completion locking** — freezing wins; a game below minimum never advances. `resume()` refuses to lift a BELOW_MINIMUM pause while still below minimum; host-menu pauses are never auto-resumed.
- **Wrap-up input contract folded into the results bundle** (no parallel `get_wrapup_input()` dict): `_build_results()` gained `ended_early / rounds_played / rounds_planned / players` (all roster entries incl. disconnected, with remembered scores). `end_game_early()` (host, only while PAUSED) emits the same bundle with `ended_early = true`; the partial round contributes nothing. Slice 10 reads ONE shape.
- **Judge seat holds + penalty matrix:** JUDGING can never end early without the judge's pick-gated ready — a disconnected judge means the window runs to its deadline (this also fixes a latent Slice 17 gap where a vanished judge silently left the early-end quorum, letting unanimous drawers force an empty-latch −1). At window end with no pick: connected judge −1 (unchanged); absent judge forgiven — unless dodge-suspect under fluid OFF, where the −1 lands and **consumes the flag** (never a second forfeit for the same dodge).
- **Mid-DRAWING rejoiner sits the round out, host-enforced:** their pre-drop submission is protected (resubmission dropped, card stays judgeable); no blank is synthesized for them; they neither block nor satisfy the DRAWING ready set; full participation resumes next round.
- **Welcome snapshot replays through `rpc_sync_phase`:** `rpc_do_welcome_ingame` lives on the Session autoload (the joiner has no RoundRoot yet), stashes the payload across the Nav swap (close-reason pattern), and the fresh SessionClient replays it through the exact live-broadcast code path (PAUSED applied as a wrapper after the underlying phase). JUDGING snapshots piggyback the reveal entries (live JUDGING broadcasts never carry them); POOL_SETUP snapshots carry current progress.
- **EventBus status signals are platform_id-keyed** (TDD draft mixed peer_id/platform_id): `player_dropped/rejoined/late_joined(platform_id, display_name)` + `judge_slot_forfeited`; `game_paused(reason, connected_count)`; `game_resumed(phase, time_left_ms)`.
- **CI:** new `tools/verify_resilience.sh` (3 instances: drop mid-DRAWING → below-minimum pause → rejoin → auto-resume with restored timer → kept submission wins). Two CI lessons codified: (1) driver spawn must be **idempotent** — the leaver's deliberate quit reloads the menu, which re-runs `_handle_ci_args` and spawned a second fighting driver; (2) gates pollute each other through the shared `user://profile.json` (`last_lobby_settings`) — verify_round now pins reveal_style/replay/judging_window (it broke when verify_resilience's GRID/10 s profile leaked into it). **Every driver pins every setting its flow depends on — including ones another gate might save.**

#### Alternatives Considered
1. **TDD-literal `insert_after_cursor` + separate pause RPCs + standalone wrap-up dict:** parallel mechanisms for behaviors the shipped pipeline already handles; more wire surface, two results shapes for Slice 10.
2. **True op-removing rotation (remove disconnected entries, re-insert on rejoin):** breaks the "leave+rejoin never moves your turn" invariant the retained-entry model gives for free.
3. **Letting a rejoined drawer resume drawing mid-round:** clobbers their surviving submission with a blank canvas; rejected (TDD's own sit-out reasoning).

#### Impact
- **Affects:** GameSession/SessionClient/Session/Roster/GameSettings/SessionRules/CustomPoolCollector, RoundRoot + 2 new scenes, lobby settings panel, round + resilience CI drivers.
- **Migration needed:** No — all payload keys additive with defaults; PlayerState/settings dicts tolerate old shapes.
- **Breaking change:** No (wire enums appended only).

#### Status
- [x] Code implemented
- [x] Tests updated (380 → 423 green, 0 orphans)
- [x] Integration verified (verify_lobby + verify_round + verify_resilience all PASS)
- [ ] Owner blocking checks (4-instance run — pending)

---

### Session-6 playtest fix batch: side chat bottom-aligns to the canvas; text drop delivery (SubViewportContainer.mouse_target); eraser footprint cursor
**Date:** 2026-07-07 | **Slice:** 16/17 surfaces | **Type:** Quick

**Decision (owner playtest findings, all fixed same session):**
- **Side chat height:** the drawing view's side chat ran to the window bottom past the Done row. Screens can now host the side chat in their own slot — new optional `chat_side_slot()` screen method (DrawScreen returns a slot inside its canvas row, so the chat's bottom == canvas bottom); `RoundRoot` rescues the chat out of a retiring screen before freeing it.
- **Text drag-drop never landed — TRUE root cause found on the second report:** since Godot 4.5, the drag system only offers drops to `gui.target_control`, and a `SubViewportContainer` becomes `target_control` ONLY when its `mouse_target` property is true (default FALSE — verified in 4.6 `viewport.cpp _update_mouse_over`). With it false the canvas container is structurally invisible to every drop, no errors anywhere. Fix: `CanvasDropTarget._ready()` sets `mouse_target = true` (+ regression test pinning it — unsetting it would break drops with zero test failures otherwise). Along the way the handlers moved to scripted virtuals (`CanvasDropTarget`/`TextChipDrag`) and drag previews became mouse-transparent — good hygiene, but neither was the cause. Headless CANNOT verify real drop delivery (the WM mouse-over pipeline needs `windowmanager_window_over`; null headless) — the new suite drives the real drag-source path + the exact handler chain the engine invokes, and the final delivery is owner-verified windowed.
- **Eraser footprint cursor:** `EraserCursor` overlay circle at the mouse, sized to the brush radius at display scale, shown while the eraser is active. Display-only (GPU) — the deterministic raster path is untouched.
- Also from this playtest: **ready-up core flow owner-confirmed** ("working great").

**Status:** [x] Fixed [x] 380/380 tests [x] Gates PASS [x] Owner re-check 2026-07-07 (drag lands after the mouse_target fix; single preview; eraser + cursor good; chat height acceptable — polish note in backlog)

---

### Slice 17 (mini): ready-up — all-ready ends DRAWING and JUDGING early; supersedes "judging never ends early"
**Date:** 2026-07-07 | **Slice:** 17 (state-machine change to 3; UI on 2/6 surfaces) | **Decided by:** Owner

**Decision:**
- **DRAWING:** submitting no longer ends the phase — the ready-up set does (all CONNECTED drawers ready → collect). The **Done!** button (prominent, replaces Submit) = submit current canvas + ready + lock tools; **Unready** is the escape hatch. A ready drawer's resubmissions are dropped.
- **JUDGING:** ends early when ALL connected participants (drawers + judge) ready — this amends the 2026-07-06 "the deadline is the only crown" rule, which flagged full-window pacing for review; group consensus is the fix. **The judge's ready requires a latched pick** (a group can never ready the judge into an accidental −1) and locks it (re-picks dropped until un-ready). Empty-latch −1 still only via deadline lapse.
- **UI:** ready panel (initials chips + ☐/✅; Slice 11 swaps in real avatars) left of the canvas in DRAWING; in JUDGING a strip inline in the chat header — "Chat | Ready | player chips" (owner spec). Ready set clears at every phase change (incl. pause/resume — players re-ready).
- Deadlines remain the guarantee everywhere; disconnected players never block all-ready.

**Impact:** Slice 3 TDD transition table updated in place; Slice 9 folds rejoiners into the participant set; CI driver readies after submit/social/pick (round-1 no-pick lapse still deadline-driven). Mini-TDD: `TDD/17-ready-up.md`.

**Status:** [x] Code implemented [x] Tests green (380/380, incl. new ready suite) [x] Gates PASS [x] Owner core-flow confirmed 2026-07-07 ("working great") — SLICE 17 COMPLETE

---

### Slice 16 rework: drag-to-place text (Option B) + Eraser tool
**Date:** 2026-07-07 | **Slice:** 16 (canvas surface) | **Decided by:** Owner (post-playtest)

**Decision:**
- **Text placement is now drag-and-drop** (owner picked Option B over in-place drag): a persistent **Text row** under the toolbar — type in the box, a chip rendered by the committal blitter appears beside it, drag the chip onto the canvas; the drop point commits the TextOp (centered on cursor, clamped in-canvas). Text stays in the box for repeat stamps; the input's clear button resets it. The drag preview and the drop-hover preview both render through `DocRasterizer`, so what you hold is exactly what lands. The click-to-place floating editor, `TEXT_EDITING` input state, and `Tool.TEXT` are gone; typed-but-undragged text is simply not part of the drawing (no auto-commit surprise at the deadline).
- **Eraser tool added:** a toolbar tool that strokes in `Palette.ERASE_COLOR_INDEX` (0 = white == `CANVAS_BACKGROUND`). A true op-removing eraser was rejected: op-list surgery + invisible-in-replay erasing; background-color strokes are deterministic, undoable, replay-visible (part of the show), and format-free. The palette selection is untouched while erasing.
- Owner confirmed the pre-rework blocking checks first (font legible; in-round flow worked as implemented) — the rework is UX-directed, not a defect fix.

**Impact:** `drawing_canvas.gd/.tscn`, `canvas_toolbar.gd/.tscn`, `palette.gd` (+`ERASE_COLOR_INDEX`); no wire/format/raster changes — TextOp and the blitter are untouched. Slice 16 TDD §7 superseded by this entry.

**Status:** [x] Code implemented [x] Tests green [x] Gates PASS [x] Owner re-check confirmed 2026-07-07 — SLICE 16 COMPLETE

---

### Slice 16 (mini): in-image text tool — format stays v1, font8x8 glyphs, censor-not-reject, caption pipeline deleted
**Date:** 2026-07-07 | **Slice:** 16 (touches 1/3/5/6) | **Type:** Quick

**Decision:**
- **TEXT op ships inside DrawingDoc v1** (`{"t":"text","c","s","x","y","str"}`): additive op types are backward-compatible (old docs never contain them) and no shipped build exists to care about forward-compatibility — no version bump, no migration. Strict `from_dict` rules: ASCII 32–126 only, 1–50 chars, in-canvas anchor, scale index 0–2.
- **Font = public-domain `font8x8_basic`** (Hepper/Sondaar/IBM), embedded as a 760-byte table in `core/constants/pixel_font.gd` — fetched from the canonical repo, not hand-transcribed. Append-only like the palette; goldens pin the rendered pixels (new `text_mixed` golden). Integer scales [2,3,4] → 16/24/32 px glyphs; blit = per-row bit-runs → `fill_rect` spans (CPU, no AA — determinism rules hold).
- **Blocked words are censored, never rejected** (owner choice 2026-07-07, chat precedent): host censors TEXT ops at submission (censor → re-truncate); the canvas applies the IDENTICAL sequence at commit so the drawer's local doc equals the broadcast doc — which `SessionClient.is_own_drawing`'s doc-equality check depends on.
- **Text is permanent once placed** (owner choice): commit-on-Enter, undo removes the whole op; no movable text objects in v1.
- **Caption pipeline deleted outright** (files, `Submission.caption`, reveal-entry key, beat-secs term, `comments_enabled` setting + presets row + Custom checkbox, `CAPTION_MAX_CHARS`/`REVEAL_CAPTION_SECS`). Removing the settings field makes stale `last_lobby_settings` keys silently ignored — the qa-backlog "caption box leftover" resolves permanently with no migration.
- **CI hardening (found during the gate run):** the round driver now pins `pool_source = BUILT_IN` — the host's restored profile carried `PLAYER_SUBMITTED` from the owner's Slice 7 playtest, parking the gate in deadline-less POOL_SETUP until timeout. Rule: CI drivers pin every setting their script's flow depends on.

**Status:** [x] Code implemented [x] Tests green (365/365) [x] Gates PASS (verify_lobby + verify_round incl. text-op round-trip assertions) [x] Mini-TDD `TDD/16-in-image-text-tool.md` (owner-approved pre-build) [ ] Owner blocking checks (font legibility in sandbox; full-round text flow)

---

### Slice 8: exports rasterize at 1× and upscale 2× nearest-neighbor
**Date:** 2026-07-07 | **Slice:** 8 | **Type:** Quick

**Decision:** exported PNGs are `DocRasterizer` output at the internal resolution (800×600/600×800) upscaled `EXPORT_SCALE = 2`× with nearest-neighbor → 1600×1200/1200×1600. Re-rasterizing ops at a true 2× resolution was rejected: brush stamps and flood-fill topology are not scale-invariant (a pixel pinch that stops a fill at 1× can leak at 2×), so a "hi-res" export could differ from what the judge actually saw — violating determinism principle 4. Nearest-neighbor keeps the crisp no-AA marker look and is pixel-exact (test-pinned: every 2×2 block equals its source pixel). `OS.shell_show_in_file_manager` works as-is on macOS; Linux fallback opens the exports folder via `shell_open`. Also: `Save.write_png` became atomic — exports are deliverables, not caches.

**Status:** [x] Code implemented [x] Tests green [x] Owner verified the export externally (2026-07-07)

---

### Kudos rematch-staleness fix; pause freezes local timers; side chat defaults expanded; captions retired in favor of a planned in-image text tool
**Date:** 2026-07-07 | **Slice:** 3/4/5/6 surfaces (session-5 second playtest round) | **Decided by:** Owner

**Context:** Owner re-tested the first fix batch. New findings: (1) kudos buttons wrongly disabled for some clients — owner correctly suspected state "sticking around from another test game"; (2) pausing froze phase progression but not the visible countdowns, and a drawer paused past the deadline would get auto-submitted and locked out; (3) the side chat should start expanded; (4) captions are unwanted — replace with text placed inside the drawing itself.

**Decision:**
- **Bug fix (kudos):** `GameSession.start_game()` resets every player's kudos economy on the **host roster only**; nothing re-broadcast it, so client wallets kept the previous game's granted/spent (first game: granted=0 until the first kudos forced a sync; rematch: spent counts persisted — exactly the owner's "one can, one can't"). Fix: `SessionClient` broadcasts the roster immediately after starting the simulation. `Session.broadcast_roster()`'s guard switched from `Net.is_host()` to `multiplayer.is_server()` so headless tests exercise the same path. Regression test + `verify_round.sh` PASS.
- **Bug fix (pause):** `PhaseTimer` freezes its rendered countdown on `PAUSED` (re-arms on the resume `start()`), and the draw screen's local auto-submit is suppressed while paused — the host's refreshed deadline is the only clock that matters on resume.
- **Side chat defaults expanded:** the drawer's drawing view declares NORMAL prominence (expanded) in the SIDE placement; the 💬 toggle still collapses it.
- **Captions retired:** `comments_enabled` now defaults false everywhere (field default + every preset); the Custom toggle remains as dormant opt-in plumbing. Replacement direction: a **text tool in the drawing canvas** (place text into the image like a paint editor). Not yet scheduled — needs a deterministic text-raster design (bitmap-font glyph blitting keeps CPU raster determinism; host-side TextFilter on text ops) and touches Slice 1 (doc/ops/rasterizer/canvas UI), Slice 3 (submission validation), Slice 5 (caption pipeline removal).

**Impact:**
- Affects: `session_client.gd`/`session_manager.gd` (roster sync), `phase_timer.gd`/`draw_screen.gd` (pause), `settings.gd`/`settings_defaults.gd` (caption defaults — preset identity tests updated), chat defaults. The qa-backlog "PhaseTimer shows a stale countdown while paused" known-limitation item is resolved.
- The text tool is **scheduled after Slices 7+8** (owner, 2026-07-07): built this session if the context budget allows, else first item next session.
- Migration needed: No. Breaking change: No.

**Status:** [x] Code implemented [x] Tests green (296/296) [x] verify_round gate PASS [x] Owner re-test (2026-07-07 — all pass; caption-box leftover deferred, see qa-backlog) [x] Text-tool scheduled (after Slices 7+8)

---

### Judging = latched click-to-pick; chat gets explicit toggle + per-phase placement; fixed-shape social rows
**Date:** 2026-07-06 | **Slice:** 3/4/5 surfaces (session-5 deferred-check playtest) | **Decided by:** Owner

**Context:** Session-5 opened with the deferred blocking checks from session 4. All five machine-verified flows passed (preset lock, client mirror, Esc/pause, kudos, reactions), but the playtest surfaced four UX problems: chat hover-expand fired constantly mid-drawing; chat sat under the canvas instead of beside it; the prominent chat crowded the reveal grid's social controls; the grid's kudos/emoji rows misaligned across cells; and the judge's confirm-button pick flow felt wrong.

**Decision:**
- **Judging is click-to-pick with a LATCHED selection:** clicking a drawing sends the pick immediately; the host latches it (re-picks overwrite, last one wins) and the **judging deadline is what crowns the winner** — the "Crown this drawing" confirm button is gone and a pick no longer ends the phase early. Empty latch at deadline keeps the −1 no-pick penalty. State-machine change to Slice 3: `JUDGING → RESOLUTION` now fires **only** on the deadline.
- **Chat expansion is an explicit toggle button, never hover.** Collapsed chat shows an unread badge; expanding clears it. A user toggle survives same-phase refreshes (pause/resume); phase changes reset to the phase's default.
- **Chat placement is per-phase, like prominence:** the drawer's drawing view puts chat in a SIDE column right of the canvas (collapsed by default); judge-wait and reveal/judging keep BOTTOM expanded. `RoundRoot` reparents its persistent panel between the two slots.
- **PROMINENT chat height adapts to the viewport** (`clampf(22% of height, 120, 300)` px) so the expanded chat never covers grid cells' emoji/kudos controls.
- **Grid social rows have a fixed shape in every cell** (row 1: centered reactions; row 2: yours-hint | caption | kudos with reserved slots) so cells align regardless of caption/ownership; cell min size 340×310.

**Rationale:** Owner-directed after live play. Latching keeps the riffing window at full length (the judge can change their mind as reactions land) at the cost of never ending judging early — flagged for pacing review; if full-window judging drags, shorten `judging_window_sec` or add "timer accelerates once picked" later.

**Impact:**
- Affects: Slice 3 (judging state machine + RPC semantics — TDD updated in place), Slice 5 (reveal-screen cells), Slice 2/6 (chat panel component; lobby chat just gains the toggle header). Slice 7's `POOL_SETUP` screen inherits the new chat defaults automatically (bottom/normal).
- Migration needed: No. Breaking change: No (RPC signature unchanged; only host handling).

**Status:** [x] Code implemented [x] Tests updated (293/293 green) [x] Slice 3 TDD updated [x] Owner re-test of the four fixes (2026-07-07 — all confirmed)

---

### Slice 6: snapshot as a separate object, permissive engine clamps, preset v1 values, pause shell
**Date:** 2026-07-06 | **Slice:** 6 | **Type:** Quick

**Decision:**
- **`Session.game_settings`** (new, per-peer) holds the frozen start-payload snapshot every in-game system reads; the lobby `Session.settings` object stays editable and keeps AUTO sentinels for the next lobby. The TDD's freeze-the-lobby-object lifecycle conflated the two.
- **Engine clamps stay permissive (rounds 1–32); the lobby stepper enforces the player-facing 3–20** — CI and unit tests legitimately run 1–2-round games, and dual clamp regimes would desync host/client mirrors.
- **Preset v1 values recorded** (expect tuning): Streamlined = grid/no replay/15 s judging/20 s draw/captions off; Social = one-at-a-time/FULL replay/8 s reveal + 12 s winner targets/40 s judging/45 s draw; Default = one-at-a-time/winner-only 8 s/25 s judging/30 s draw. Identity tests pin each mode's meaning, not exact numbers.
- **`judging_window_sec` became a setting** (was Slice 3's constant; default 25 s per TDD).
- **Pause (owner addition):** `GameSession.pause()` (ex-Slice 9 stub) broadcasts a PAUSED phase; `RoundRoot` keeps the live screen under a forced overlay and resume refreshes deadlines **in place** (`refresh_deadline` on all phase screens) so a mid-drawing pause never wipes a canvas. Beat metronome freezes via `Timer.paused`. Leave = existing Slice 2 semantics until Slice 9.
- Existing names win over the TDD draft (`draw_time_sec`, duration-based replay keys, `SettingsDefaults.Mode`); draw-time range reconciled to 10–120 s; no 150 ms coalescing (steppers don't chatter); mode selector reuses Slice 2's OptionButton.

**Status:** [x] Code implemented [x] Tests green (287/287) [x] Gates PASS [x] Implementation notes written [ ] Owner core-flow sign-off

---

### Replay settings are target durations; finished replays hold a 2 s still
**Date:** 2026-07-06 | **Slice:** 5 (contract consumed by 6) | **Decided by:** Owner (playtest)

**Decision:** `reveal_replay_secs` / `winner_replay_secs` replace the speed-multiplier settings: the replay speeds up to fit the set time (30 s drawing @ 5 s target = 6×; @ 30 s = realtime), floored at realtime for shorter drawings. Every finished replay holds the completed still for `REPLAY_STILL_HOLD_SECS = 2.0`; the host sizes RESOLUTION to fit the full winner replay + hold (it may exceed the 6 s base — a replay is never cut off). `ReplayPlayer`'s Slice 1 hard 10 s cap became caller-optional (`enforce_duration_cap`) since a host-set 30 s realtime replay is now legitimate. Also from the same playtest: reaction UI enlarged; host pause button folded into Slice 6's Esc menu.

**Impact:** Slice 5 TDD §2 table updated in place; Slice 6 must surface the renamed keys (its TDD draft references the old speed keys — the updated table wins).

---

### In-game pause/leave menu lands in Slice 6 (shell), semantics upgraded in Slice 9
**Date:** 2026-07-06 | **Slice:** 6, 9 | **Decided by:** Owner

**Context:** Owner-flagged gap (2026-07-06, session 3): once a game starts there is no settings access or exit-to-menu short of closing the window. Covered by no planned slice; candidate homes were Slice 6 (settings surface) or Slice 9 (resilience/voluntary-leave).

**Decision:** Slice 6 ships the menu shell — an in-game Esc overlay with Resume / Leave to main menu (leave uses the existing session paths: host leaving ends the session for everyone, a drawer leaving becomes a blank and stays on the roster). Slice 9 upgrades the semantics behind the same button (graceful voluntary leave, rejoin memory, below-minimum pause) without moving the UI.

**Rationale:** The gap hurts every playtest between now and Chunk 12; Slice 6 is UI-heavy anyway and the shell only exposes already-existing behavior, so the added scope is small.

**Impact:** Slice 6 scope grows by the Esc overlay; Slice 9's TDD assumptions unchanged (it owns leave/rejoin semantics either way). WHERE_WE_ARE Active Decisions entry resolved.

---

### Slice 5: stage-in-screen reveal, single gap constant, captions transient, beat failsafe
**Date:** 2026-07-06 | **Slice:** 5 | **Type:** Quick

**Decision:**
- **One-at-a-time stage built inside `reveal_judging_screen`** (no `reveal_stage.tscn`, no `GridLayout` retrofit): beats settle into the real judging cells, making REVEAL→JUDGING seamless by construction and reusing all Slice 4 cell wiring. GridLayout can be created when Slices 8/10 actually need it.
- **Single idle-gap constant:** kept Slice 1's implemented `REPLAY_MAX_OP_GAP_SEC = 1.0` instead of adding the TDD's duplicate `REPLAY_MAX_IDLE_GAP_SECS = 0.35` — planner and renderer must share one compression rule or host beat schedules drift from client renders; the reveal caps already guarantee pacing.
- **Captions are session-transient and payload-level:** they ride the submission payload beside the doc (never inside it), so collection saves can never leak them; not persisted in v1 (revisit if playtests miss them).
- **Beat-chain failsafe:** the REVEAL phase deadline = beat schedule + `REVEAL_BEAT_FAILSAFE_SECS`; the ordinary deadline force-advances if beats stall, and stale beat timers self-drop — the host phase timer and beat timer can never double-advance.
- **`ReactionGate.open_for()` now preserves a running close-grace** so reactions racing a beat boundary still land for the previous drawing (§10).
- **Slice 4 follow-up fix:** `draw_screen.tscn` had `show_save_toggle = false`, making self-save unreachable in real rounds; flipped to true.
- Slice 1's `ReplayPlayer` needed no extension (already had `speed_multiplier` + cap, composing safely with planner timescales).

**Status:** [x] Code implemented [x] Tests green (260/260) [x] Gates PASS (incl. beat/gather/caption checks) [x] Implementation notes written [ ] Owner core-flow sign-off

---

### Slice 4: RPC placement, collection write path details, pending-state UX, CI social gate
**Date:** 2026-07-06 | **Slice:** 4 | **Type:** Quick

**Decision:**
- **Reaction/kudos RPCs live on `SessionClient`** (steps 1–2) with validated `GameSession.react()/give_kudos()` entry points (steps 3–5) — the TDD's "GameSession RPC surface" wording predates the Slice 3 SessionClient/GameSession split, which wins.
- **`CollectionStore` writes doc-before-index** (TDD said index first): a dangling index entry would render as a broken item in the Slice 8 browser, an orphaned doc file is invisible. `Save.write_png()` added so thumbnails stay behind the single-choke-point rule; `CollectionStore.root_dir` static seam keeps tests/CI out of real collections. `CollectionStore` centrally emits `collection_item_added` + new 6th signal `collection_save_failed`.
- **Self-save fires when the draw screen retires** (last *submitted* doc), not per submit call — latest-wins resubmission makes per-submit idempotent saves keep the wrong (first) version.
- **KudosButton pending state re-enables on a 2 s timeout**, not the TDD's "next total/phase sync" heuristic — the giver's own `kudos_total_changed` precedes their private confirm on the reliable channel, so the heuristic flicker-re-enables mid-flight. No optimistic spend, per TDD.
- **`GameSettings.kudos_allotment` field added now** (default `KUDOS_AUTO = -1`; explicit 0 = kudos off, min-1 clamp AUTO-only). Slice 6 adds the UI.
- **Results bundle `reaction_stats`/`kudos_stats` filled** with uid-keyed nonzero-only aggregates (`totals_by_author` / `received_by_author` + `drawing_totals`); Slice 10 mines full `SessionStats` host-side.
- **`verify_round.sh` gate extended to the social layer** (judge react/un-react/re-react + kudos with giver-side collection-file verification; drawers cross-react; per-peer convergence checks). **Incident:** the first driver version used a raw ENet peer id (random 32-bit int) as an op-count loop bound — two headless instances froze allocating ~10⁹ dictionaries (~80 GB RAM, machine crash). Fixed to `joined_order` + hard clamp; rule recorded: never use peer ids as sizes/bounds. Gate runs now use a guarded wrapper (output to file + RSS watchdog).

**Status:** [x] Code implemented [x] Tests green (233/233) [x] Gates PASS [x] Implementation notes written [ ] Owner core-flow sign-off

---

### QA process: core-flow sign-offs + deferred fine-grain QA backlog
**Date:** 2026-07-06 | **Slice:** All | **Decided by:** Owner

**Context:** The testing protocol's slice-completion gate batches all UI confirmation onto the owner at every slice boundary. With multi-slice sessions, the detailed checklists outpace the owner's between-session testing time.

**Decision:** Owner playtests between slices/sessions cover **broad strokes and core functions only**. A slice is signed off (marked COMPLETE) on: core-flow owner playtest + full test suite green + automated multi-instance gates green. All fine-grain checks, edge cases, and polish items accumulate in **`TDD/qa-backlog.md`** ("bug hunt" list) — items are added at every slice boundary and never dropped. A full QA sweep of the backlog happens after the game is content-complete (before/with Slice 15 release prep).

**Rationale:** Keeps development velocity while guaranteeing nothing slips untracked; automated gates already machine-verify most mechanics, so human QA can focus on feel and edge cases in one batch.

**Impact:** Affects every slice's completion workflow (supersedes the per-slice batchable-confirmation step of `workflows/slice-completion.md` §3 — batchable items now go to the backlog by default). Retroactively applied: Slices 1, 2, 3 marked COMPLETE (core-confirmed); their deferred items are the backlog's initial content.

**Status:** [x] qa-backlog.md created [x] Slices 1–3 statuses updated [x] WHERE_WE_ARE updated

---

### Slice 3: round-start handshake, return-to-lobby, CI gate substitution
**Date:** 2026-07-06 | **Slice:** 3 | **Type:** Quick

**Decision:**
- **Round-start readiness handshake:** clients' `SessionClient` sends `rpc_request_round_ready`; the host starts the simulation when all connected roster peers report ready or after `ROUND_START_FAILSAFE_SEC = 3.0` (a broken client never stalls the start). Added beyond the TDD because the first `ROUND_INTRO` broadcast can otherwise race clients' deferred scene swap (RPCs to missing node paths are dropped, not queued).
- **`rpc_sync_return_to_lobby`** added to the Session autoload: the standings screen's "Back to lobby" returns everyone to the lobby with roster/settings intact; host prunes mid-game leavers. The TDD named the button but no mechanism.
- **In-GdUnit ENet loopback relay test replaced** by `tools/verify_round.sh` + `RoundCiDriver`: three real processes play a full 2-round game (pick +2, deliberate no-pick −1) and verify phase sequences, role views, and results bundles per peer. GdUnit cannot host two SceneTrees; the multi-process pattern (from `verify_connect`/`verify_lobby`) covers more.
- **EventBus ordering contract:** `SessionClient.rpc_sync_phase` emits phase-specific signals before `phase_changed` so screens always see a current replica.
- **`drawing_id` minted at collect time** (TDD §2 "on acceptance" vs §6 "at collect" — collect wins; resubmission would churn acceptance-time ids).
- **Session-3 pacing (owner directive):** blocking playtest gates for Slices 2+3 are batched to a single owner checklist at session end; automated equivalents ran green first (extends the session-2 precedent).

**Context:** Slice 3 implementation (session 3). Full detail in `TDD/03-core-round-loop-implementation-notes.md`. 178 tests green; `verify_lobby.sh` + `verify_round.sh` both PASS.

**Impact:** Affects Slices 9 (readiness signal reusable for rejoin), 10 (working lobby-return path). Migration: none. Breaking: none.

**Status:** [x] Code implemented [x] Tests green (178) [x] Implementation notes written [ ] Owner playtest confirmation

---

### Slice 2: Session autoload placement, settings field names, dev-gate harness
**Date:** 2026-07-06 | **Slice:** 2 | **Type:** Quick

**Decision:**
- **`Session` autoload** registered as `game/session/session_manager.gd`, ordered after `Save`, before `Nav`. The Slice 2 TDD's `game_session.gd` placement is superseded: that file name stays reserved for Slice 3's host-only `GameSession` RefCounted simulation (consistency guide §4 SessionClient/GameSession split wins on conflict).
- **`GameSettings` field names unified with Slice 3:** `round_count` (not `rounds`), plus `pool_type_id` defaulting to `SettingsDefaults.DEFAULT_POOL_TYPE_ID` ("animal_adjective") added now so the start snapshot is forward-compatible.
- **Draw-time range** 15–180 s per Slice 2 TDD; default stays 30 s (2026-07-04 decision supersedes the TDD's 45).
- **New `game/session/session_rules.gd`:** pure static validators + injectable-clock `ChatRateLimiter`, so every host-side rule is unit-testable without a network (cg §9). Future request handlers follow this pattern.
- **Client-side join/register watchdogs** (10 s, epoch-guarded) added beyond the TDD's host-side timeout — ENet/UDP gives no fast failure for dead room codes; without them the client hangs in "Connecting…".
- **Automated Slice 2 gate:** `LobbyCiDriver` + `tools/verify_lobby.sh` (3-instance roster/chat/start + dead-code recovery), per the session-2 "automated equivalents for blocking gates" precedent. Owner playtests remain the formal gate.

**Context:** Slice 2 implementation (session 3). Full deviation detail in `TDD/02-lobby-session-roster-implementation-notes.md`.

**Impact:** Affects Slices 3 (file name now free as documented), 6 (settings field names), 9 (watchdog/timeout groundwork). Migration: none. Breaking: none.

**Status:** [x] Code implemented [x] Tests green (135 total) [x] Implementation notes written [ ] Owner playtest confirmation

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
