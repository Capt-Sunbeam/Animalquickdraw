# Font Sheet Guide — Character Order & Writing Rules

**For:** the owner's pre-drawn 80-box sheets (boxes are 4×4 grid squares, drawn on grid paper).
**Pipeline:** photograph sheets → glyph extraction → potrace + FontForge → TTF → theme default font. Characters not drawn fall back to a bundled simple sans automatically (Godot font-fallback chain), so skipping a character is always safe.

---

## The rules (read before writing)

1. **One shared baseline for every box on every sheet:** pick the grid line **one square up from the box bottom**. Every character SITS on that line. Tails (g, j, p, q, y and the comma) hang **below** it into the bottom square. This is how the font gets its vertical alignment — consistency here matters more than pretty letters.
2. **Size:** capitals and tall letters (b, d, f, h, k, l, t) about **2.5–3 squares tall** from the baseline; lowercase body (a, c, e, m, n...) about **1.5–2 squares**. Keep these consistent — a font repeats its letters constantly and amplifies size wobble.
3. **Bold:** go over every stroke **2–3 times**. Letters render small (16–24 px) — faint strokes vanish. This matters more for the font than anywhere else in the art pass.
4. **Never touch the box border** with letter ink — leave a visible gap so extraction can separate glyph from box.
5. **Punctuation position is meaningful:** period ON the baseline, comma hanging below it, apostrophe/quotes up at cap height, hyphen at mid-lowercase height. Draw them where they'd sit relative to the baseline.
6. **Botched a letter?** Scribble the whole box solid, then write that same character in the NEXT box and continue the sequence from there. (Solid boxes are detected and skipped; the mapping is confirmed on a labeled contact sheet at review anyway, and single characters can be redrawn in any spare space later.)
7. **One sitting per sheet** if possible — slant and rhythm drift between sittings, and it shows in a font.

## Character order (fill boxes left→right, top→bottom)

| Boxes | Characters |
|-------|------------|
| 1–26 | `A B C D E F G H I J K L M N O P Q R S T U V W X Y Z` |
| 27–52 | `a b c d e f g h i j k l m n o p q r s t u v w x y z` |
| 53–62 | `0 1 2 3 4 5 6 7 8 9` |
| 63–76 | `. , ! ? ' " - : ( ) & + / #` |
| 77–80 | Owner's choice — suggestions: `% * ; = ~ @` or a fun dingbat (draw a `★` or `♥` and it maps to that Unicode character, usable decoratively in any UI text) |

Rationale for the 14 fixed punctuation picks: chat renders `Name: message` (colon constantly), scores render `+N` (plus), party-game UI is full of `!` and `?`, contractions need `'`, prompts/compounds need `-`, standings can use `#`, fractions/timers use `/`.

(No box needed for SPACE — its width is set during the font build.)

## Photographing

Same checklist as everything else (overhead, flat, even daylight, no flash, no shadow, fill the frame) — one photo per sheet. The **first sheet can be photographed before the rest are written**: extraction gets validated on it while the remaining sheets are filled in, so any adjustment (bolder pen, bigger letters) costs one sheet, not four.

## What the pipeline does with it

1. Detects the drawn box grid, takes each box interior, extracts the glyph (same ink extraction as UI elements, same `--bold` rescue knob)
2. Produces a **labeled contact sheet** (each glyph shown with the character the script thinks it is) — owner confirms/corrects the mapping
3. potrace vectorizes each glyph; FontForge places them on the baseline, auto-derives widths (side bearings tuned globally), and emits the TTF
4. The TTF becomes the theme default font with the fallback sans chained behind it; spacing/weight tuning is a regenerate, not a redraw

**Install note:** step 3 needs `brew install potrace fontforge` — to be confirmed with the owner before installing.
