# Art Pass Plan — Hand-Drawn UI Skin

**Status:** PLANNED + REFINED (rough plan approved 2026-07-08, session 8; refined in the 2026-07-11 art discussion session — see the decision log entry of that date and **`TDD/art/pilot-brief.md`**). Not yet scheduled or numbered; becomes an owner-approved mini-TDD (Slice 16 precedent) when it starts. **PILOT COMPLETE — ALL THREE LEGS OWNER-APPROVED:** UI skin (2026-07-11, session 12), wallpaper + font (2026-07-12, session 13). B1/P1 skin, the 130-sticker drifting wallpaper, and the 81-glyph handwriting font (`assets/fonts/aq_hand.ttf`) are ALL live in the shipped theme/menu. See `TDD/art/pilot-brief.md` §Pilot status and the 2026-07-12 decision-log entry. Remaining before "art pass done": owner draws `. , ' - & + =` glyphs (any time), full UI inventory + at-scale drawing after Slice 14, optional wallpaper reuse on lobby/wrap-up.
**Agreed ordering (owner decision, 2026-07-08):** finish the remaining slices and the batched testing first, then the art pass — slotted **after Slice 14, before Slice 15 completes** (store assets and the release-candidate playtest pass must happen with the final look, not programmer art).

## Refinements settled 2026-07-11 (owner + AI discussion)

- **Style:** pure black-ink line art (ballpoint); color is digital (engine tint / fills under lines). Owner technique rules: double/triple-stroke outlines, no light ballpoint shading (solid fill or hatching instead), ~1.5–2× target size (not 3× — ballpoint lines are thin), breathing room for digital bolding.
- **Paper:** owner's light-blue grid paper is CLEARED — blue-channel filtering drops the grid; the grid even helps draw straight 9-slice rectangles. (Friends' collage scraps on the more-saturated blue grid: also fine.)
- **Capture:** phone photos, batched — many elements per sheet with margin IDs, big gaps (3–4 cm); collage scraps photographed on a **dark background** for automatic piece detection; HEIC handled.
- **Pipeline:** `tools/art_pipeline/clean_scan.py` (built + synthetic-tested 2026-07-11): illumination flattening, blue-grid removal, soft-alpha ink extraction, gap-based element grouping, despeckle, `--bold` stroke-thickening knob; `scraps` mode with hole-filled piece masks preserving pen color. Raw drops: `art_drops/` (gitignored).
- **Wallpaper:** extracted stickers → **seamless tileable texture** (owner idea) — wrap-around handled in scripted composition (never on paper); scatter generator with density/size/rotation knobs, seeded candidates, owner picks; line-art tile is engine-tintable (full-strength menu, faint watermark elsewhere). Compositor script: to be built after pilot validates extraction.
- **Font:** owner has NO printer → **DIY printerless pipeline replaces Calligraphr** as the primary path: hand-drawn boxes on grid paper (grid line = shared baseline, descenders below), glyph extraction via the same script family, potrace + FontForge (Homebrew installs — ask owner first) → TTF. Unlimited characters, same bolding knob, free regeneration. Fallback: print the Calligraphr template at a library.
- **Pilot-first (owner agreed):** nothing is drawn at scale until the pilot passes — see `TDD/art/pilot-brief.md` (B1 button + P1 panel + I1 icon + optional F1 font strip + one collage batch, through the whole pipeline, wired into the live theme, owner look-check as exit gate).
- **Slice reality update:** Slices 12 + 13 are now implemented (sessions 10–11), so their screens (lobby browser, kick UI, public notice) exist for the UI inventory; only Slice 14's surfaces remain outstanding.

---

## Vision

Replace the placeholder programmer art with a fully hand-drawn identity, made by the owner on paper and scanned in:

1. **Hand-drawn menus/UI** — panels, buttons, icons for every screen
2. **A custom handwriting font** for all UI text
3. **A main-menu wallpaper** collaged from the owner's existing hand-drawn animals (from in-person games with friends)

The game's architecture makes this an asset swap, not a rewrite: all styling flows through `core/theme/main_theme.tres` (consistency guide §8 — no per-node hardcoded styles anywhere except the drawing palette).

---

## Workstream 1: UI inventory (AI produces — the drawing checklist)

**First task of the art session:** generate `TDD/art/ui-inventory.md` by walking every scene AND every code-built element (many rows/chips/cards are constructed in code — a scene-file scrape alone misses half the UI). For each screen:

- Every button, label, panel, icon, overlay, with states (normal/hover/pressed/disabled)
- Rough on-screen size and whether it stretches (9-slice) or is fixed art
- A checkbox per item — the document IS the owner's drawing checklist

**Coverage:** main menu, join dialog, avatar editor, collection browser + viewer, lobby (roster, settings panel + Custom surface, chat), pool setup, round intro, draw screen (toolbar, palette, text row, ready panel), judge wait, reveal/judging grid (cards, reaction bar, kudos button/wallet), resolution/winner spotlight, wrap-up (3 card types + standings), Esc menu, pause overlay, spectator banner, toasts, confirm dialogs, phase timer, chat panel, ready strips, avatar chips — **plus the Slice 12–14 screens (lobby browser, kick UI, achievement surfaces), which is why the inventory waits until those slices exist.**

## Workstream 2: Asset production (owner draws — any time, at own pace)

**Menus/panels/buttons:**
- Draw oversized (2–3× target size) on clean paper; scan or photograph flat with good light
- Draw ONE normal state per element style — hover/pressed/disabled will be generated as tint/offset effects in the theme (only draw extra states for elements where that reads wrong)
- Panels and buttons become **9-slice textures**: draw the border/corners as the personality, keep the middle stretchable — one drawing serves every size (the UI must stay freely resizable, 1280×720 minimum)

**Custom font:**
- Recommended path: a handwriting-font service (e.g. Calligraphr): print their template, draw the alphabet + digits + punctuation, scan, receive a TTF
- The TTF drops into the theme as the default UI font — every label/button in the game changes in one place, with a bundled simple sans chained as fallback for any character not drawn (Godot font-fallback)
- **Carve-out — RESOLVED (owner, 2026-07-11):** the in-drawing text tool's `PixelFont` stays AS-IS (it's part of the deterministic drawing wire format; changing it would re-render every saved drawing and break goldens — and the pixel-vs-handwriting contrast reads as intentional)

**Wallpaper:**
- Scan the existing hand-drawn animals (phone photos fine; flat, even light)
- AI scripts the cleanup (paper → transparency, auto-crop) and can auto-compose a scattered sticker-sheet collage — or the owner composes one PNG by hand in an image editor
- Lands as a background TextureRect on the main menu; motif reusable on lobby/wrap-up screens later

## Workstream 3: Integration (AI wires it in)

1. **Pipeline:** an asset drop folder convention (e.g. `art_drops/` gitignored raw scans → `res://assets/ui/` processed) + a cleanup script (white-to-alpha thresholding, auto-crop, downscale) so scans become game-ready PNGs mechanically
2. **Theme:** StyleBoxTexture 9-slices for panels/buttons, the TTF as theme default font, state variants via modulate/offset
3. **Backgrounds:** main-menu wallpaper + any per-screen touches
4. **Verification:** scene smoke tests stay green; layout checks at 1280×720 and resized windows; owner look/feel playtest is the gate (this pass is INHERENTLY owner-judged)

## Session plan sketch

| Session | Work |
|---------|------|
| Art session A (after Slice 14) | Mini-TDD written + approved; UI inventory generated; pipeline + drop folder built; wallpaper composed from whatever scans exist |
| Owner, offline, any time | Draw against the checklist; font template; scan animals (can start TODAY — no dependency on the inventory for wallpaper/font) |
| Art session B | Integration: theme/font/wallpaper wired, per-screen pass, smoke tests, owner playtest |

## Constraints and notes

- The drawing **palette** and **PixelFont** are versioned wire-format constants — art pass never touches them (palette is append-only forever)
- Layout stays anchor/container-based and resizable; no fixed-resolution art assumptions
- Exports must include the new asset types (PNG/TTF are standard imports — verify the 3-platform export presets after integration)
- **Sound — RESOLVED (owner, 2026-07-11): OUT of the art pass.** It gets its own dedicated session later; this plan's scope is visual only
- Assets are cheap to iterate: the pipeline means a redrawn button is a rescan, not a code change

---

*When this pass is scheduled: write the mini-TDD from this plan, decision-log the scope choices (text-tool font in/out, sound in/out), and follow the normal slice workflows.*
