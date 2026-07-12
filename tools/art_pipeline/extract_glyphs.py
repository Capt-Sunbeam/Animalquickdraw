#!/usr/bin/env python3
"""extract_glyphs.py — pull font glyphs out of the owner's hand-drawn box
sheets (grid paper, pen boxes, one character per box, photographed on a
table).

Approach: find the PAGE (biggest bright region), find INK on it, then find
CELLS = enclosed non-ink regions of box-interior size. Only ink inside a
cell counts as a glyph, which makes the whole thing immune to binder
holes, table wood, page edges, and stray marks between boxes. Cells are
read in row order and mapped to a per-page layout string.

Layout string: rows separated by '/', cell tokens separated by spaces,
'_' = deliberately empty box. Token count per row must match detected
cells; mismatches are warned loudly (mapping shift risk).

Output: art_drops/font/glyphs/U<hex>.png (ink on transparency) +
glyphs.json (char -> file, cell height in px for later em-scaling) +
a labeled contact sheet for OWNER review.

Usage:
  python3 tools/art_pipeline/extract_glyphs.py PHOTO --layout "A B C/D E F" \
      [--out art_drops/font] [--threshold 0.8]
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from clean_scan import (DOWNSCALE_LONG_SIDE, binary_dilate, binary_erode,
                        box_blur, connected_components, fill_holes,
                        load_image)

MIN_GLYPH_INK_PX = 60          # full-res px below which a cell is "empty"

# Characters that legitimately have detached parts (dots, paired marks).
# Everything else is expected to be one connected stroke cluster, so any
# small extra component is a fleck/box remnant regardless of size.
MULTIPART_CHARS = set('ij!?:;"%=\'.,')


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("photo", type=Path)
    ap.add_argument("--layout", type=str, required=True)
    ap.add_argument("--out", type=Path, default=Path("art_drops/font"))
    ap.add_argument("--threshold", type=float, default=0.8,
                    help="ink threshold on normalized blue channel")
    ap.add_argument("--close-gaps", type=int, default=3, dest="close_gaps",
                    help="ink dilation (analysis px) closing box-corner gaps "
                         "so every cell counts as enclosed")
    args = ap.parse_args()

    layout_rows = [row.split() for row in args.layout.split("/")]

    img = load_image(args.photo)
    rgb = np.asarray(img, dtype=np.float32) / 255.0
    full_h, full_w = rgb.shape[:2]
    scale = max(full_w, full_h) / DOWNSCALE_LONG_SIDE
    if scale > 1.0:
        ds_size = (int(full_w / scale), int(full_h / scale))
        rgb_ds = np.asarray(img.resize(ds_size, Image.BILINEAR),
                            dtype=np.float32) / 255.0
    else:
        scale = 1.0
        rgb_ds = rgb

    # --- page: biggest bright region, hole-filled
    lum_ds = rgb_ds.mean(axis=2)
    dark, bright = np.percentile(lum_ds, 10), np.percentile(lum_ds, 90)
    paper = lum_ds > (dark + bright) / 2.0
    lbl, n = connected_components(paper)
    if n == 0:
        print("no page found")
        return 1
    counts = np.bincount(lbl.ravel())
    counts[0] = 0
    page = fill_holes(lbl == int(counts.argmax()))
    page_inner = binary_erode(page, 3)

    # --- ink on the page (blue channel, illumination-flattened)
    gray_ds = rgb_ds[:, :, 2]
    bg = box_blur(gray_ds, max(gray_ds.shape) // 8)
    ink_ds = (gray_ds / np.maximum(bg, 1e-3) < args.threshold) & page_inner

    # --- cells: enclosed non-ink regions of box-interior size. The outer
    # blank page region touches the page border band; cells don't.
    blank = page_inner & ~binary_dilate(ink_ds, args.close_gaps)
    cl, cn = connected_components(blank)
    border_ids = set(np.unique(np.concatenate(
        [cl[0, :], cl[-1, :], cl[:, 0], cl[:, -1]])))
    # Also mark anything touching the page's eroded boundary as "outside":
    boundary = page_inner & ~binary_erode(page_inner, 4)
    border_ids |= set(np.unique(cl[boundary]))
    border_ids.discard(0)

    ccounts = np.bincount(cl.ravel())
    page_area = int(page_inner.sum())
    cells = []
    for i in range(1, cn + 1):
        if i in border_ids or ccounts[i] < page_area * 0.001 \
                or ccounts[i] > page_area * 0.05:
            continue
        ys, xs = np.nonzero(cl == i)
        h = ys.max() - ys.min() + 1
        w = xs.max() - xs.min() + 1
        if not (0.4 < w / h < 2.5):
            continue
        cells.append((ys.min(), xs.min(), ys.max() + 1, xs.max() + 1, i))

    if not cells:
        print("no cells found")
        return 1

    # --- reading order with row clustering
    heights = [c[2] - c[0] for c in cells]
    row_band = float(np.median(heights)) * 0.7
    cells.sort(key=lambda c: (round(((c[0] + c[2]) / 2) / row_band),
                              (c[1] + c[3]) / 2))
    rows: list = [[cells[0]]]
    for cell in cells[1:]:
        prev = rows[-1][-1]
        if abs(((cell[0] + cell[2]) / 2) - ((prev[0] + prev[2]) / 2)) < row_band:
            rows[-1].append(cell)
        else:
            rows.append([cell])

    print(f"{args.photo.name}: {len(cells)} cell(s) in {len(rows)} row(s); "
          f"layout wants {sum(len(r) for r in layout_rows)} in {len(layout_rows)} row(s)")

    # --- map + extract
    glyph_dir = args.out / "glyphs"
    glyph_dir.mkdir(parents=True, exist_ok=True)
    meta_path = args.out / "glyphs.json"
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}

    gray_full = rgb[:, :, 2]
    review = []   # (char, cropped RGBA image) for the contact sheet
    extracted = 0
    empty = 0
    for r_idx, row in enumerate(rows):
        if r_idx >= len(layout_rows):
            print(f"WARNING: detected row {r_idx + 1} has no layout row - skipped")
            continue
        tokens = layout_rows[r_idx]
        if len(tokens) != len(row):
            print(f"WARNING: row {r_idx + 1}: {len(row)} cell(s) detected but "
                  f"layout has {len(tokens)} token(s) - mapping may shift!")
        for c_idx, cell in enumerate(row):
            if c_idx >= len(tokens):
                break
            char = tokens[c_idx]
            y0, x0, y1, x1, comp_id = cell
            # cell region (incl. glyph holes), shrunk so box lines stay out
            region = fill_holes(cl[y0:y1, x0:x1] == comp_id)
            region = binary_erode(region, 3)
            fy0, fx0 = int(y0 * scale), int(x0 * scale)
            fy1, fx1 = int(np.ceil(y1 * scale)), int(np.ceil(x1 * scale))
            fy1, fx1 = min(fy1, full_h), min(fx1, full_w)
            crop = gray_full[fy0:fy1, fx0:fx1]
            bgc = box_blur(crop, max(crop.shape) // 3 + 1)
            norm = crop / np.maximum(bgc, 1e-3)
            alpha = np.clip((args.threshold + 0.1 - norm) / 0.1, 0.0, 1.0)
            mask = np.asarray(Image.fromarray(
                (region * 255).astype(np.uint8)).resize(
                (fx1 - fx0, fy1 - fy0), Image.NEAREST), dtype=np.float32) / 255.0
            alpha *= mask
            # Per-glyph despeckle: box-line remnants and paper flecks
            # inflate the bbox (breaking height normalization and advance
            # width downstream). Keep real detached parts (i/j/?/! dots):
            # the threshold is relative to the glyph's main body.
            gl, gn = connected_components(alpha > 0.3)
            if gn > 1:
                gcounts = np.bincount(gl.ravel())
                gcounts[0] = 0
                if char in MULTIPART_CHARS:
                    keep_min = max(60.0, 0.02 * gcounts.max())
                else:
                    # single-stroke chars: anything much smaller than the
                    # main body is a fleck (25% guard spares a genuinely
                    # two-stroke letterform)
                    keep_min = 0.25 * gcounts.max()
                drop = gcounts < keep_min
                drop[0] = False
                alpha[drop[gl]] = 0.0
            ink_px = int((alpha > 0.5).sum())
            if char == "_" or ink_px < MIN_GLYPH_INK_PX:
                if char != "_" and ink_px < MIN_GLYPH_INK_PX:
                    print(f"  row {r_idx + 1} cell {c_idx + 1} ('{char}'): "
                          f"EMPTY ({ink_px}px ink) - skipped")
                empty += 1
                continue
            out = np.zeros((alpha.shape[0], alpha.shape[1], 4), dtype=np.uint8)
            out[:, :, 3] = (alpha * 255).astype(np.uint8)
            ys2, xs2 = np.nonzero(out[:, :, 3] > 8)
            pad = 4
            gy0, gy1 = max(0, ys2.min() - pad), min(out.shape[0], ys2.max() + 1 + pad)
            gx0, gx1 = max(0, xs2.min() - pad), min(out.shape[1], xs2.max() + 1 + pad)
            out = out[gy0:gy1, gx0:gx1]
            fname = f"U{ord(char):04X}.png"
            Image.fromarray(out).save(glyph_dir / fname)
            meta[char] = {"file": fname,
                          "cell_h_px": int((y1 - y0) * scale),
                          "glyph_h_px": int(out.shape[0]),
                          "photo": args.photo.name}
            review.append((char, out))
            extracted += 1

    meta_path.write_text(json.dumps(meta, indent=1, ensure_ascii=False) + "\n")

    # --- owner-review contact sheet (append-safe: rebuilt from ALL meta)
    sheet_cells = []
    for char, entry in sorted(meta.items(), key=lambda kv: ord(kv[0])):
        gpath = glyph_dir / entry["file"]
        if not gpath.exists():
            continue
        im = Image.open(gpath)
        im.thumbnail((110, 110))
        cell_img = Image.new("RGB", (124, 148), (244, 239, 225))
        # black ink from alpha
        ink_rgba = Image.new("RGBA", im.size, (30, 26, 22, 255))
        ink_rgba.putalpha(im.split()[-1])
        cell_img.paste(ink_rgba, (max(0, (124 - im.width) // 2), 30), ink_rgba)
        d = ImageDraw.Draw(cell_img)
        d.text((6, 4), char, fill=(140, 60, 30))
        sheet_cells.append(cell_img)
    if sheet_cells:
        cols = 12
        rows_n = (len(sheet_cells) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * 130 + 10, rows_n * 154 + 10), (90, 90, 100))
        for k, cimg in enumerate(sheet_cells):
            sheet.paste(cimg, (10 + (k % cols) * 130, 10 + (k // cols) * 154))
        sheet_path = args.out / "glyphs_contact.png"
        sheet.save(sheet_path)
        print(f"contact sheet -> {sheet_path}")

    print(f"done: {extracted} glyph(s) extracted, {empty} empty cell(s); "
          f"charset so far: {len(meta)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
