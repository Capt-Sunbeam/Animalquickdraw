# Art Pilot — Drawing & Photo Brief

**Status:** ACTIVE (pilot agreed 2026-07-11). Purpose: validate the full paper→game pipeline on the owner's exact setup (black ballpoint + light-blue grid paper + phone photos) **before** any at-scale drawing happens.
**Pipeline script:** `tools/art_pipeline/clean_scan.py` (validated on synthetic photos 2026-07-11; real photos are the true test).
**Drop folder:** `art_drops/pilot/incoming/` (gitignored — raw photos never enter the repo; processed PNGs will land in `assets/ui/` at integration).

---

## What to draw (one sheet is enough)

All in **black ballpoint** on your grid paper. Standard grid squares are ~5 mm, so sizes are given in squares too.

| ID | Element | Size (approx) | Notes |
|----|---------|---------------|-------|
| **B1** | Button | 10 × 4 cm (~20 × 8 squares) | Rounded-ish rectangle. All personality in the **border** — wobble, double lines, tiny corner ticks. Leave the **middle empty** (it stretches and holds text). |
| **P1** | Panel frame | 10 × 10 cm (~20 × 20 squares) | Decorative border/corners, empty middle. Put a small doodle **on or touching one corner** — this tests how corner personality survives 9-slicing. |
| **I1** | Icon | 4–5 cm square | Anything fun — a star, a paw print, a pencil. Fixed art, drawn as-is. |
| **F1** *(optional)* | First font sheet | owner's pre-drawn 80-box sheets | Owner prepped real sheets (2026-07-11) — fill per **`TDD/art/font-sheet-guide.md`** and photograph the FIRST sheet whenever ready; it validates glyph extraction before the rest are written. |

### The drawing rules (from the session discussion)

1. **Go over every outline 2–3 times.** Bold to the point of looking slightly chunky on paper = right on screen.
2. **No light shading.** Solid scribbled fill or tight hatching only — faint ballpoint gray turns to noise in extraction.
3. **Leave breathing room** in the linework (owner's own note) so digital bolding stays an option.
4. **Big gaps between drawings** — at least 3–4 cm (a couple of fingers). Nothing touching.
5. **Write the ID** (B1, P1, I1) in the margin **a few cm away** from its drawing — it'll be extracted as its own tiny piece and discarded, it just tells us what's what.

### F1 font sheet (optional)

The owner pre-drew 80-box sheets (2026-07-11). Fill them following **`TDD/art/font-sheet-guide.md`** (character order, shared baseline one square up from box bottoms, size/boldness rules). Photograph the **first sheet before writing the rest** — extraction gets validated on it, so any adjustment costs one sheet, not four. Same pen rules — **extra bold matters here**, letters render small.

## The collage batch (second photo)

1. Pick **6–10 animal scraps** from the stack — mix of sizes is good.
2. Lay them on a **dark background** (dark table, dark towel) with **≥ 2 cm gaps**, roughly straight (no need to be exact; the pipeline doesn't deskew yet).
3. One overhead photo. If some pieces are tiny (1×1"), do a second, closer photo of just the small ones — closer = more pixels = more detail.

## Photo checklist (both photos)

- Directly overhead, page/pieces flat
- Even light — daylight near a window beats overhead room light; **no flash**
- Watch for your own/phone's shadow across the page
- Fill the frame, tap to focus
- HEIC straight off the iPhone is fine (the script converts)

## Handoff

AirDrop the photos to the Mac and put the files in `art_drops/pilot/incoming/`, then tell Claude they're there.

## What happens next (AI side)

1. Run the pipeline both modes; produce a contact sheet for owner review; tune thresholds/bolding against the real photos
2. Wire **B1** and **P1** into `core/theme/main_theme.tres` as StyleBoxTexture 9-slices, drop **I1** somewhere visible
3. Launch the game — owner judges the look in-place. This look-check is the pilot's exit gate
4. If F1 was drawn: glyph extraction proof, then (with owner OK) `brew install potrace fontforge` to build the test TTF

**Exit criteria:** owner sees their own ink as a live button/panel in-game and says the style direction works (or we adjust: pen, bolding, paper, style) — BEFORE the at-scale drawing checklist gets generated.

---

## Pilot status (2026-07-11)

- **UI skin leg: PASSED.** B1 + P1 extracted clean on the first real photos (no bolding needed), wired into the theme, and owner-approved across live playtests. A polish loop followed (see WHERE_WE_ARE session #12 row): theme type variations, dialog skin, layout fixes, and the measured draw-screen width fix.
- **Font leg: in progress.** Both sheets photographed; glyphs pending box-grid extraction + potrace/FontForge TTF build (brew installs — ask owner first). Owner still to draw `. , ' -` in spare boxes.
- **Collage leg: moved to a concurrent session** (which also extended `clean_scan.py` with `--keep-color`).
- **I1 icon: skipped** — corner-doodle 9-slice behavior got validated by P1 itself; icons are covered by the full art-pass checklist later.
