# Slice 19 Implementation Notes: Title & Ceremony Rework + Emoji Retirement

**Implemented:** 2026-07-12 (session 14) | **TDD:** `19-title-ceremony-rework.md`
**Machine state:** 572 tests green (556 → 572 net, after deleting the reaction suites and adding vote/settings/stacking coverage); all 3 gates PASS

---

## What was actually built vs the TDD

Everything in the mini-TDD shipped. Deviations and discoveries:

1. **`ReactionGate` was NOT deleted — it became `SocialGate`** (`game/session/social_gate.gd`). The TDD's removal inventory listed it as deletable, but it always gated **kudos** too (`give_kudos` checks `is_open_for`). Same behavior, honest name; `REACTION_CLOSE_GRACE_MSEC` → `SOCIAL_CLOSE_GRACE_MSEC` (still 250 ms). `ReactionLedger` was pure-reaction and did die.
2. **`titles_awarded` payload shape changed** (wire/signal contract): values are now `Array[String]` of title ids per player — stacking means one player can hold several. EventBus doc updated; Slice 14's handler iterates the array. Pre-release change, logged here + decision log.
3. **CI driver rework made the gate STRONGER:** `round_ci_driver.gd` lost its reaction script and now has ALL THREE peers spend their kudos (drawers kudos the first non-own entry, judge kudos entry 0). Totals are deterministic regardless of the shuffle (entry0 = 2, entry1 = 1), and the kudos-save collection write + wallet-empty check now run on **every peer**, not just the judge. Score math: `expected_total = WINNER + 3×KUDOS + NO_PICK`; the lapsed judge's exact score derives from whether they authored entry0 (won: −1+2+2k) or entry1 (−1+1k).
4. **Skip vote lives on SessionClient, not GameSession** — the ceremony is presentation; GameSession's job ended at `session_finished`. Host counts votes in `_ceremony_votes` (platform_id-keyed, deduped), strict majority = `votes > connected/2` recomputed against *currently connected* players on every vote AND on roster syncs (a leaver can tip a pending vote — regression-tested). One latched `_ceremony_skipped`; `rpc_sync_ceremony_skip(votes, needed, skipped)` is call_local so the host UI updates too.
5. **Voting jumps YOUR view immediately** (`_jump_to_standings`), then the majority broadcast moves everyone else — so the button is both the old per-peer escape hatch and the vote.
6. **Badges:** `StandingsPanel.present(standings, titles_by_player)` — second arg maps pid → Array of display names; the name cell became a VBox (NameLabel + optional "🏅 A · B" BadgesLabel at font 13). Empty map = no badge line (covers titles-off AND the fallback bundle for free).
7. **`build_bundle` gained a trailing `titles_on: bool = true`** rather than reading settings (calculator stays pure). GDScript gotcha: a typed ternary (`x if c else [] as Array[Dictionary]`) fails at runtime — the else-branch cast doesn't type the expression; use an if-statement.
8. **Settings:** `titles_enabled` + `title_ceremony` are preset-locked keys (Custom-editable), carried by all three presets; Streamlined sets `title_ceremony: false`. Lobby UI greys Awards ceremony + Title points when titles are off (honest-disable).
9. **People's Champion label:** `"N kudos received, zero wins"`; evidence = highest-kudos drawing. Minimum ≥ 1 kudos.
10. **Old saved data:** collection items / results carrying legacy reaction fields load fine (unknown-key tolerance was already the JSON pattern everywhere). `BUNDLE_VERSION` stays 1 — nothing ever shipped externally.

## Files

- **Deleted:** `ui/round/reaction_bar.*`, `game/session/reaction_ledger.gd`, `ui/wrapup/superlative_card.*`, `tests/.../test_reaction_ledger.gd`
- **Renamed:** `reaction_gate.gd` → `social_gate.gd` (+ test)
- **Stripped:** `net_ids.gd` (Reaction enum), `event_bus.gd`, `game_constants.gd`, `title_ids.gd` (WORST_DRAWER + superlatives), `session_stats.gd`, `game_session.gd` (react() + reaction_stats), `session_client.gd` (react RPCs), `reveal_judging_screen.gd` (bar rows), `round_ci_driver.gd`, `game-design-brief.md` §11 (amended, precedent: late-join allotment)
- **Reworked:** `wrap_up_calculator.gd`, `wrap_up_screen.gd/.tscn` (SkipCeremonyButton), `standings_panel.gd`, `settings.gd`, `settings_defaults.gd`, `mode_settings_panel.gd`
- **New:** `tests/game/session/test_ceremony_vote.gd` (7 tests)

## Owner checks

All batchable (qa-backlog Slice 19 section): vote feel on 3+ instances, badge legibility with stacked titles, Streamlined pacing, judging-grid density re-look (the reaction row removal gave every cell's drawing ~40 px more height — partial relief for the owner's 5+ player grid concern; the full layout rework remains a polish candidate).
