# Slice 19 (mini): Title & Ceremony Rework + Emoji Reaction Retirement

**Version:** 1.0
**Created:** 2026-07-12 (session 14) — owner-directed mini-slice, Slice 16/18 precedent
**Dependencies:** Slice 10 (wrap-up bundle + sequence), Slice 6 (settings surface), Slice 17 (ready-strip pattern), Slice 4 (kudos — UNTOUCHED)
**Must land BEFORE Slice 14** — achievements read the final title landscape.

---

## 1. Overview

Owner decisions (2026-07-12, this session):

1. **The emoji reaction system is removed entirely** — "weakest form of title/achievement and in the way of the grid layout." All six reactions, the bar UI, the wire path, host tracking, and every derived award (all superlatives) go. **Kudos is a separate system and stays whole** (give/receive, kudos=save, wallet, gate).
2. **No one-title-per-player rule** — every title goes to its top qualifier; stacking allowed; `TitleIds.PRIORITY` becomes pure ceremony/display order.
3. **Worst Drawer is removed** (title + its planned achievements).
4. **People's Champion rebased on kudos:** most kudos received *among players with zero round wins* in the game (min 1 kudos). Consolation prize semantics preserved.
5. **New settings:** `titles_enabled` (master) + `title_ceremony` (one-at-a-time awards act vs straight to standings). Badges next to final scores show whenever `titles_enabled`, regardless of ceremony mode.
6. **Majority ready-up skip:** during the ceremony act, players can press Skip; strictly more than half of connected players → host advances everyone to standings. Local per-peer skip (Slice 10) still works immediately for the presser.

### Scope

**In:** the removals; calculator rework; two settings (presets, lobby UI, wire, snapshot); standings title badges; skip vote RPC pair; test updates; CI driver update; brief §11 amendment note.
**Out:** Slice 14 stats/achievements (next slice, this session); any judging-grid layout rework beyond what the bar's removal frees up (deferred to polish); kudos changes (none).

---

## 2. Removal Inventory (emoji system)

**Deleted files** (+ their tests):
- `ui/round/reaction_bar.gd` / `.tscn`
- `game/session/reaction_gate.gd`, `game/session/reaction_ledger.gd` (host-side machinery)
- `ui/wrapup/superlative_card.gd` / `.tscn`
- `tests/game/session/test_reaction_gate.gd`, `test_reaction_ledger.gd`

**Stripped (reaction/superlative code removed, file stays):**
- `core/constants/net_ids.gd` — `Reaction` enum (+ any reaction RPC ids). Pre-release wire removal, logged.
- `core/constants/title_ids.gd` — `WORST_DRAWER`, `SUPERLATIVE_IDS`, `SUPERLATIVE_NAMES`; PRIORITY re-commented as display order
- `core/constants/game_constants.gd` — reaction/superlative constants (incl. `WRAPUP_SUPERLATIVE_CARD_SECONDS`)
- `core/events/event_bus.gd` — reaction signals
- `game/session/game_session.gd` — react request handling / routing
- `game/session/session_client.gd` — `request_react` + reaction sync
- `game/session/session_stats.gd` — per-drawing `reaction_counts`, reaction aggregates; `reaction_stats` leaves the results bundle
- `game/session/wrap_up_calculator.gd` — `compute_superlatives` gone; `reactions_total`/`reaction_counts` leave `drawing_infos`
- `game/session/roster.gd`, `ui/round/late_join_wait.gd` — incidental references (verify at edit time)
- `ui/round/reveal_judging_screen.gd` — bar instancing, reaction gate mirror; social row = "🔒 yours" + kudos only
- Wrap-up sequence controller — superlatives act removed (sequence = [titles act if ceremony] → standings)
- `tools/ci/round_ci_driver.gd` — reaction steps out, kudos steps stay
- Remaining test files listed by the footprint grep — update in place

**Tolerance:** saved collection items / old profiles carrying reaction fields load fine (unknown-key tolerance is the established JSON pattern). Wrap-up bundle validation updated to the new shape (`superlatives` gone; still BUNDLE_VERSION 1 — nothing shipped externally).

**Brief:** `game-design-brief.md` §11 amended (reactions + superlatives struck, pointer to this TDD + decision log) — same precedent as the late-join allotment amendment.

---

## 3. Title System Changes

`WrapUpCalculator.compute_titles`:
- Drop the `titled` exclusion dict entirely (stacking allowed).
- Remove `WORST_DRAWER` branch; remove Worst Drawer from the lower-is-better list.
- `PEOPLES_CHAMPION`: candidates = authors with zero `won` infos; stat = total kudos received (min ≥ 1); evidence = highest-kudos drawing; label `"%d kudos received, zero wins"`.
- Tie-breaks unchanged (stat → earlier evidence round → lower rotation index).
- Title points unchanged (1/title, `title_points_enabled` gate) — stacking stacks points by design (owner call).

Final set (7): HOTSHOT, JUDGES_DARLING, PEOPLES_CHAMPION, GENEROUS_SOUL, SPEED_DEMON, DA_VINCI, MINIMALIST.

---

## 4. Settings

`GameSettings` (wire dict + snapshot + client mirror + from_dict defaults, established Slice 6 pattern):

| Field | Type | Default | Presets |
|---|---|---|---|
| `titles_enabled` | bool | true | true everywhere |
| `title_ceremony` | bool | true | Default/Social true, **Streamlined false** |

- `titles_enabled == false` → wrap-up bundle carries empty `titles`, no ceremony act, no badges; `titles_awarded` doesn't emit (nothing awarded — Slice 14 title achievements simply don't progress that game, intended).
- `title_ceremony == false` → titles still computed + `titles_awarded` emitted; sequence goes straight to standings-with-badges.
- Lobby UI: two rows in the session-12 two-column settings layout; Custom-editable, preset-driven otherwise; host-only editing as usual.

---

## 5. Standings Badges

Standings act rows gain a per-player badge strip: one compact chip per title held (theme `SmallButton`-style non-interactive, display name text; ♛ prefix for Judge's Darling not required — keep it plain v1). Data source: `wrap_up.standings` rows already join to `wrap_up.titles` by `player_id` — aggregation happens screen-side, no bundle change. Shown whenever `titles_enabled` (ceremony on or off). Multiple badges wrap within the row (stacking exists now).

---

## 6. Majority Skip Vote

RPC pair on the wrap-up path (host-authoritative, cg §4):
- `rpc_request_skip_ceremony()` (client→host, called once per press; also fires for the host's own press locally) — host records the sender's platform_id in a per-ceremony `Dictionary` (idempotent).
- Threshold: `votes > connected_count / 2` (strictly more than half of *currently connected* players; recompute on every vote AND on departures — a leaver can tip an existing vote over).
- On threshold: `rpc_sync_ceremony_skipped()` → every peer jumps to the standings act. Late/duplicate votes after skip are no-ops.
- Presser UX: pressing Skip advances the presser's own view immediately (existing Slice 10 per-peer skip) *and* counts toward the vote; button shows `Skip (2/3)`-style progress via a small sync of the count (piggyback on the skip sync or a lightweight count sync — implementer's choice, host remains source of truth).
- Vote state dies with the ceremony (nothing persisted; rematch = fresh).

---

## 7. Edge Cases

- **2 players connected:** majority = 2 votes (strictly >1). Correct—both want out.
- **Everyone already locally skipped:** each press counted at press time; vote may complete after some peers already sit at standings — sync is then a no-op for them.
- **Departure mid-vote:** recount against new connected set; may trigger skip immediately.
- **titles_enabled off + ceremony on:** ceremony act never enters (nothing to award) — settings UI greys `title_ceremony` when titles are off (honest UI, host-side only).
- **Zero titles granted** (e.g. no kudos given anywhere, no 2-win player, …): ceremony act auto-skips (nothing to show) exactly like the shipped empty-superlatives behavior did.
- **Rejoiner during ceremony:** receives current act via the existing wrap-up snapshot path; their vote counts against the current connected set.

---

## 8. Testing Strategy

- **Calculator:** stacking (one player sweeps ≥2 titles), Worst Drawer absent, People's Champion kudos rebase (zero-wins guard, min 1 kudos, tie-breaks), superlatives gone from bundle, empty-titles bundle when disabled.
- **Settings:** preset table (Streamlined ceremony off), wire round-trip, snapshot freeze, from_dict defaults for old dicts (missing keys → true).
- **Skip vote:** thresholds at 2/3/5/8 connected; idempotent double-press; departure recount tips vote; post-skip votes no-op; host press counts.
- **Badges:** rows show chips for titled players (incl. multiple), none when titles_enabled off.
- **Removal regression:** full suite compiles + runs with zero `Reaction`/`reaction_` references outside collection-tolerance code; `verify_round.sh` (updated driver) + `verify_lobby.sh` + `verify_resilience.sh` PASS.

**Owner checks:** ceremony skip vote feel + badges legibility (batchable — fold into next playtest); Streamlined preset pacing (batchable).

---

## 9. Implementation Checklist

- [x] Removal inventory executed (files deleted, strips applied, `--import` after class changes)
- [x] Calculator rework + tests
- [x] Settings fields + presets + lobby UI + mirror + tests
- [x] Standings badges + tests
- [x] Skip vote RPCs + tests
- [x] CI driver updated; all 3 gates PASS (guarded wrapper)
- [x] Brief §11 amended; decision log entry; qa-backlog reaction items pruned
- [x] Implementation notes written; WHERE_WE_ARE updated

---

## COMPLETION STATUS (2026-07-12, session 14)

**IMPLEMENTED + machine-verified.** 572 tests green; verify_lobby / verify_round / verify_resilience all PASS (round driver reworked to the kudos-only social script — now stronger: kudos-save verified on all three peers). One deviation from §2's inventory: `ReactionGate` was renamed to `SocialGate`, not deleted — it always gated kudos. `titles_awarded` now carries pid → Array (stacking). Owner feel-checks are batchable (qa-backlog Slice 19 section). See `19-title-ceremony-rework-implementation-notes.md`.
