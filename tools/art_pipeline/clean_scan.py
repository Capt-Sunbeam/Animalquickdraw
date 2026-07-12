#!/usr/bin/env python3
"""clean_scan.py — Animal Quickdraw art pipeline: phone photo -> game-ready PNGs.

Two modes:
  elements  (default)  Dark ink drawn on white/grid paper. Extracts each
                       drawing as a pure-black-ink RGBA sticker with soft
                       anti-aliased alpha. Light-blue grid lines are dropped
                       via the blue channel; uneven phone lighting is
                       flattened before thresholding.
  scraps               Separate paper pieces laid out on a DARK background.
                       Finds each piece of paper, crops it, and extracts the
                       drawing on it with original colors preserved
                       (paper-color distance alpha), suppressing light-blue
                       grid residue.

Usage:
  python3 tools/art_pipeline/clean_scan.py PHOTO [PHOTO...] \
      --out art_drops/pilot/out [--mode elements|scraps] \
      [--bold N] [--names B1,P1,I1] [--gap-frac 0.02] [--min-ink 200]

Names are assigned to extracted pieces in reading order (top-to-bottom,
left-to-right). Unnamed pieces fall back to <photo-stem>_NN.png.

HEIC photos are converted automatically via macOS `sips`.
Requires: Pillow, numpy (no OpenCV needed).
"""

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

DOWNSCALE_LONG_SIDE = 1400  # analysis resolution; crops come from full res


# ---------------------------------------------------------------- loading

def load_image(path: Path) -> Image.Image:
    if path.suffix.lower() in (".heic", ".heif"):
        tmp = Path(tempfile.mkstemp(suffix=".png")[1])
        subprocess.run(
            ["sips", "-s", "format", "png", str(path), "--out", str(tmp)],
            check=True, capture_output=True,
        )
        img = Image.open(tmp).convert("RGB")
        tmp.unlink(missing_ok=True)
        return img
    return Image.open(path).convert("RGB")


# ---------------------------------------------------------------- numpy helpers

def box_blur(gray: np.ndarray, radius: int) -> np.ndarray:
    """Fast box blur via integral image (edge-padded)."""
    if radius < 1:
        return gray.copy()
    padded = np.pad(gray, radius + 1, mode="edge")
    integ = padded.cumsum(0).cumsum(1)
    r = radius
    size = 2 * r + 1
    h, w = gray.shape
    out = (
        integ[size:size + h, size:size + w]
        - integ[0:h, size:size + w]
        - integ[size:size + h, 0:w]
        + integ[0:h, 0:w]
    )
    return out / (size * size)


def binary_dilate(mask: np.ndarray, iters: int) -> np.ndarray:
    m = mask.copy()
    for _ in range(iters):
        grown = m.copy()
        grown[1:, :] |= m[:-1, :]
        grown[:-1, :] |= m[1:, :]
        grown[:, 1:] |= m[:, :-1]
        grown[:, :-1] |= m[:, 1:]
        m = grown
    return m


def binary_erode(mask: np.ndarray, iters: int) -> np.ndarray:
    return ~binary_dilate(~mask, iters)


def gray_dilate(alpha: np.ndarray, iters: int) -> np.ndarray:
    """Max-filter dilation for the --bold knob (thickens strokes)."""
    a = alpha.copy()
    for _ in range(iters):
        grown = a.copy()
        np.maximum(grown[1:, :], a[:-1, :], out=grown[1:, :])
        np.maximum(grown[:-1, :], a[1:, :], out=grown[:-1, :])
        np.maximum(grown[:, 1:], a[:, :-1], out=grown[:, 1:])
        np.maximum(grown[:, :-1], a[:, 1:], out=grown[:, :-1])
        a = grown
    return a


def connected_components(mask: np.ndarray):
    """Label 8-connected components. Returns (labels, count).

    Plain BFS — fine at analysis resolution (<= ~2 MP masks).
    """
    labels = np.zeros(mask.shape, dtype=np.int32)
    h, w = mask.shape
    current = 0
    ys_all, xs_all = np.nonzero(mask)
    for y0, x0 in zip(ys_all, xs_all):
        if labels[y0, x0]:
            continue
        current += 1
        stack = [(y0, x0)]
        labels[y0, x0] = current
        while stack:
            cy, cx = stack.pop()
            ylo, yhi = max(cy - 1, 0), min(cy + 2, h)
            xlo, xhi = max(cx - 1, 0), min(cx + 2, w)
            local = mask[ylo:yhi, xlo:xhi] & (labels[ylo:yhi, xlo:xhi] == 0)
            for dy, dx in zip(*np.nonzero(local)):
                labels[ylo + dy, xlo + dx] = current
                stack.append((ylo + dy, xlo + dx))
    return labels, current


def fill_holes(mask: np.ndarray) -> np.ndarray:
    """Fill regions not connected to the border (ink strokes, enclosed paper)."""
    inv = ~mask
    lbl, n = connected_components(inv)
    if n == 0:
        return mask
    border = np.unique(np.concatenate(
        [lbl[0, :], lbl[-1, :], lbl[:, 0], lbl[:, -1]]))
    filled = mask.copy()
    for j in range(1, n + 1):
        if j not in border:
            filled |= lbl == j
    return filled


def reading_order(boxes):
    """Sort bounding boxes top-to-bottom then left-to-right, with row grouping."""
    if not boxes:
        return []
    heights = [b[3] - b[1] for b in boxes]
    row_band = max(1.0, float(np.median(heights)) * 0.8)
    indexed = list(enumerate(boxes))
    indexed.sort(key=lambda ib: (round(((ib[1][1] + ib[1][3]) / 2) / row_band),
                                 (ib[1][0] + ib[1][2]) / 2))
    return [i for i, _ in indexed]


# ---------------------------------------------------------------- elements mode

def extract_elements(img: Image.Image, args):
    """Dark ink on light paper -> list of (bbox_fullres, alpha_fullres)."""
    rgb = np.asarray(img, dtype=np.float32) / 255.0
    full_h, full_w = rgb.shape[:2]

    # Blue channel as grayscale: light-blue grid lines are bright here
    # (near paper), black ballpoint stays dark.
    gray_full = rgb[:, :, 2]

    scale = max(full_w, full_h) / DOWNSCALE_LONG_SIDE
    if scale > 1.0:
        ds_size = (int(full_w / scale), int(full_h / scale))
        gray_ds = np.asarray(
            Image.fromarray((gray_full * 255).astype(np.uint8)).resize(
                ds_size, Image.BILINEAR), dtype=np.float32) / 255.0
    else:
        scale = 1.0
        gray_ds = gray_full

    # Flatten uneven phone lighting: normalize against a heavy local blur.
    bg = box_blur(gray_ds, max(gray_ds.shape) // 8)
    norm_ds = gray_ds / np.maximum(bg, 1e-3)

    ink_ds = norm_ds < args.threshold

    # Despeckle at analysis resolution before grouping.
    lbl, n = connected_components(ink_ds)
    if n:
        counts = np.bincount(lbl.ravel())
        min_ds_area = max(4, int(args.min_ink / (scale * scale)))
        keep = counts >= min_ds_area
        keep[0] = False
        ink_ds = keep[lbl]

    # Merge nearby strokes into one element (corner doodles etc. belong to
    # the frame they sit next to), then split into groups.
    gap_iters = max(1, int(args.gap_frac * max(ink_ds.shape)))
    grouped = binary_dilate(ink_ds, gap_iters)
    labels, count = connected_components(grouped)

    pieces = []
    for i in range(1, count + 1):
        ys, xs = np.nonzero((labels == i) & ink_ds)
        if len(ys) == 0:
            continue
        pad = int(0.02 * max(full_w, full_h))
        x0 = max(0, int(xs.min() * scale) - pad)
        y0 = max(0, int(ys.min() * scale) - pad)
        x1 = min(full_w, int((xs.max() + 1) * scale) + pad)
        y1 = min(full_h, int((ys.max() + 1) * scale) + pad)

        # Full-res alpha inside the crop, illumination-flattened the same way.
        crop = gray_full[y0:y1, x0:x1]
        bg_crop = box_blur(crop, max(crop.shape) // 4 + 1)
        norm_crop = crop / np.maximum(bg_crop, 1e-3)
        alpha = np.clip((args.threshold + args.softness - norm_crop)
                        / args.softness, 0.0, 1.0)

        # Mask to this group only (upscaled), so near neighbours don't bleed in.
        group_ds = binary_dilate(labels == i, 2)
        gy0, gy1 = int(y0 / scale), int(np.ceil(y1 / scale))
        gx0, gx1 = int(x0 / scale), int(np.ceil(x1 / scale))
        group_crop = Image.fromarray(
            (group_ds[gy0:gy1, gx0:gx1] * 255).astype(np.uint8)).resize(
            (x1 - x0, y1 - y0), Image.NEAREST)
        alpha *= (np.asarray(group_crop, dtype=np.float32) / 255.0)

        pieces.append(((x0, y0, x1, y1), alpha))

    order = reading_order([p[0] for p in pieces])
    return [(pieces[i][0], pieces[i][1], None) for i in order]  # None = pure ink


# ---------------------------------------------------------------- scraps mode

def extract_scraps(img: Image.Image, args):
    """Paper pieces on a dark background -> colored stickers."""
    rgb = np.asarray(img, dtype=np.float32) / 255.0
    full_h, full_w = rgb.shape[:2]
    lum_full = rgb.mean(axis=2)

    scale = max(full_w, full_h) / DOWNSCALE_LONG_SIDE
    if scale > 1.0:
        ds_size = (int(full_w / scale), int(full_h / scale))
        lum_ds = np.asarray(
            Image.fromarray((lum_full * 255).astype(np.uint8)).resize(
                ds_size, Image.BILINEAR), dtype=np.float32) / 255.0
    else:
        scale = 1.0
        lum_ds = lum_full

    dark, bright = np.percentile(lum_ds, 10), np.percentile(lum_ds, 90)
    paper_mask = lum_ds > (dark + bright) / 2.0

    labels, count = connected_components(paper_mask)
    min_ds_area = int(0.002 * paper_mask.size)

    # Largest first: enclosed paper islands (inside a drawn loop) come out as
    # their own components — the containing piece is kept, the islands skipped.
    comps = []
    for i in range(1, count + 1):
        ys, xs = np.nonzero(labels == i)
        if len(ys) >= min_ds_area:
            comps.append((len(ys), i, ys, xs))
    comps.sort(key=lambda c: -c[0])

    claimed = np.zeros(paper_mask.shape, dtype=bool)  # ds-space, filled pieces
    pieces = []
    for _, i, ys, xs in comps:
        dy0, dy1 = ys.min(), ys.max() + 1
        dx0, dx1 = xs.min(), xs.max() + 1
        cy, cx = (dy0 + dy1) // 2, (dx0 + dx1) // 2
        if claimed[cy, cx]:
            continue  # nested inside an already-kept piece

        # Hole-filled piece mask: keeps the ink and any enclosed paper.
        local = fill_holes(labels[dy0:dy1, dx0:dx1] == i)
        claimed[dy0:dy1, dx0:dx1] |= local

        pad = int(0.005 * max(full_w, full_h))
        x0 = max(0, int(dx0 * scale) - pad)
        y0 = max(0, int(dy0 * scale) - pad)
        x1 = min(full_w, int(dx1 * scale) + pad)
        y1 = min(full_h, int(dy1 * scale) + pad)

        crop = rgb[y0:y1, x0:x1]

        # Flat-field each channel against its local blur so paper ~= 1.0
        # everywhere regardless of phone-lighting vignette. Clamp at 1.0:
        # only darker-than-paper deviations count as ink (kills bright halos).
        norm = np.empty_like(crop)
        for c in range(3):
            ch = crop[:, :, c]
            bgc = box_blur(ch, max(ch.shape) // 6 + 1)
            norm[:, :, c] = np.minimum(ch / np.maximum(bgc, 1e-3), 1.0)

        # Alpha from distance below paper -> keeps any pen color.
        dist = np.sqrt(((norm - 1.0) ** 2).sum(axis=2))
        alpha = np.clip((dist - args.paper_tol) / args.softness, 0.0, 1.0)

        # Kill grid residue: distinctly blue-vs-red AND still light = grid
        # lines, not pen (a dark blue pen stroke stays: its min channel is low).
        grid = ((norm[:, :, 2] - norm[:, :, 0] > 0.08)
                & (norm.min(axis=2) > 0.55))
        alpha[grid] = 0.0

        # Confine to the (hole-filled) paper piece, eroded inward so the
        # paper's cut edge and the dark background never read as ink.
        # Build the mask in a ds-space window that matches the PADDED crop —
        # resizing the raw bbox mask over the padded crop shifts it at edges.
        wy0, wy1 = int(y0 / scale), int(np.ceil(y1 / scale))
        wx0, wx1 = int(x0 / scale), int(np.ceil(x1 / scale))
        window = np.zeros((wy1 - wy0, wx1 - wx0), dtype=bool)
        window[dy0 - wy0:dy1 - wy0, dx0 - wx0:dx1 - wx0] = local
        window = binary_erode(window, 3)
        piece_full = Image.fromarray((window * 255).astype(np.uint8)).resize(
            (x1 - x0, y1 - y0), Image.NEAREST)
        alpha *= (np.asarray(piece_full, dtype=np.float32) / 255.0)

        # Drop sub-visible residue so trimming works on real signal only.
        alpha[alpha < args.noise_floor] = 0.0

        # Despeckle: drop tiny alpha islands (grid-dash remnants). Real small
        # features (an eye dot) are far bigger than min_ink at photo res.
        amask = alpha > 0
        lbl2, n2 = connected_components(amask)
        if n2:
            counts = np.bincount(lbl2.ravel())
            tiny = counts < args.min_ink
            tiny[0] = False
            alpha[tiny[lbl2]] = 0.0

        pieces.append(((x0, y0, x1, y1), alpha, crop))

    order = reading_order([p[0] for p in pieces])
    return [pieces[i] for i in order]


# ---------------------------------------------------------------- output

def save_piece(alpha: np.ndarray, color, out_path: Path, bold: int):
    if bold > 0:
        alpha = gray_dilate(alpha, bold)
    h, w = alpha.shape
    out = np.zeros((h, w, 4), dtype=np.uint8)
    if color is None:
        out[:, :, 3] = (alpha * 255).astype(np.uint8)  # RGB stays black ink
    else:
        out[:, :, :3] = (color * 255).astype(np.uint8)
        out[:, :, 3] = (alpha * 255).astype(np.uint8)

    # Trim fully-transparent margins down to a small border.
    ys, xs = np.nonzero(out[:, :, 3] > 8)
    if len(ys):
        margin = max(4, int(0.02 * max(h, w)))
        y0, y1 = max(0, ys.min() - margin), min(h, ys.max() + 1 + margin)
        x0, x1 = max(0, xs.min() - margin), min(w, xs.max() + 1 + margin)
        out = out[y0:y1, x0:x1]

    Image.fromarray(out).save(out_path)
    return out.shape[1], out.shape[0]


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("photos", nargs="+", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--mode", choices=("elements", "scraps"), default="elements")
    ap.add_argument("--bold", type=int, default=0,
                    help="thicken strokes by N pixels (dilation)")
    ap.add_argument("--names", type=str, default="",
                    help="comma-separated names in reading order across all photos")
    ap.add_argument("--gap-frac", type=float, default=0.02, dest="gap_frac",
                    help="stroke-merge radius as fraction of image size (elements)")
    ap.add_argument("--min-ink", type=int, default=200, dest="min_ink",
                    help="min ink pixels (full res) to keep a component")
    ap.add_argument("--threshold", type=float, default=0.80,
                    help="ink threshold on illumination-normalized blue channel")
    ap.add_argument("--softness", type=float, default=0.10,
                    help="alpha ramp width (anti-aliasing)")
    ap.add_argument("--paper-tol", type=float, default=0.08, dest="paper_tol",
                    help="scraps: color distance from paper treated as paper")
    ap.add_argument("--noise-floor", type=float, default=0.15, dest="noise_floor",
                    help="scraps: zero alpha below this (kills grid residue)")
    args = ap.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    names = [n.strip() for n in args.names.split(",") if n.strip()]
    name_idx = 0
    total = 0

    for photo in args.photos:
        img = load_image(photo)
        if args.mode == "elements":
            pieces = extract_elements(img, args)
        else:
            pieces = extract_scraps(img, args)

        print(f"{photo.name}: {len(pieces)} piece(s)")
        for k, (bbox, alpha, color) in enumerate(pieces):
            if name_idx < len(names):
                stem = names[name_idx]
                name_idx += 1
            else:
                stem = f"{photo.stem}_{k + 1:02d}"
            out_path = args.out / f"{stem}.png"
            w, h = save_piece(alpha, color, out_path, args.bold)
            print(f"  -> {out_path.name}  {w}x{h}px  (from bbox {bbox})")
            total += 1

    print(f"done: {total} piece(s) -> {args.out}")
    return 0 if total else 1


if __name__ == "__main__":
    sys.exit(main())
