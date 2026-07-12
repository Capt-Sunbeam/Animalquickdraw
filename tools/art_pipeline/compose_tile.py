#!/usr/bin/env python3
"""compose_tile.py — scatter extracted stickers into a SEAMLESSLY TILEABLE
square texture (Animal Quickdraw menu wallpaper).

Wrap-around: any sticker crossing a tile edge is also drawn entering from
the opposite edge (all 9 torus offsets), so the result repeats infinitely
with no visible seam. Placement uses toroidal-distance rejection sampling
to keep stickers from piling up.

Output is ink-on-TRANSPARENT (RGBA): the engine supplies the paper color
and can tint/fade the whole tile (full-strength menu, faint watermark
elsewhere).

Usage:
  python3 tools/art_pipeline/compose_tile.py \
      --stickers art_drops/collage/stickers --out art_drops/collage/tiles/t1.png \
      [--size 2048] [--count 30] [--scale 0.10-0.20] [--rot 30] \
      [--spacing 0.85] [--seed 1] [--exclude ram,fox] [--preview]

Same seed + same sticker set => identical tile (owner picks by seed).
"""

import argparse
import random
import sys
from pathlib import Path

from PIL import Image

PLACE_TRIES = 250


def toroidal_dist2(ax: float, ay: float, bx: float, by: float, t: float) -> float:
    dx = abs(ax - bx)
    dy = abs(ay - by)
    dx = min(dx, t - dx)
    dy = min(dy, t - dy)
    return dx * dx + dy * dy


def paste_wrapped(tile: Image.Image, sticker: Image.Image, cx: float, cy: float) -> None:
    t = tile.width
    w, h = sticker.size
    for ox in (-t, 0, t):
        for oy in (-t, 0, t):
            x = int(round(cx + ox - w / 2.0))
            y = int(round(cy + oy - h / 2.0))
            if x + w <= 0 or y + h <= 0 or x >= t or y >= t:
                continue
            tile.alpha_composite(sticker, (x, y))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--stickers", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--size", type=int, default=2048)
    ap.add_argument("--count", type=int, default=30,
                    help="number of sticker placements")
    ap.add_argument("--scale", type=str, default="0.10-0.20",
                    help="sticker long side as a fraction of tile size, min-max")
    ap.add_argument("--rot", type=float, default=30.0,
                    help="max rotation jitter, degrees either way")
    ap.add_argument("--spacing", type=float, default=0.85,
                    help="min distance factor (1.0 = bounding circles touch)")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--exclude", type=str, default="",
                    help="comma-separated sticker names (without .png) to skip")
    ap.add_argument("--preview", action="store_true",
                    help="also write <out>_preview.png: 2x2 tiled on paper")
    args = ap.parse_args()

    rng = random.Random(args.seed)
    lo, hi = (float(v) for v in args.scale.split("-"))
    excluded = {n.strip() for n in args.exclude.split(",") if n.strip()}

    paths = sorted(p for p in args.stickers.glob("*.png")
                   if p.stem not in excluded)
    if not paths:
        print("no stickers found in", args.stickers)
        return 1
    sources = {p.stem: Image.open(p).convert("RGBA") for p in paths}

    # Balanced bag: every sticker appears floor/ceil(count/n) times.
    names = list(sources.keys())
    bag = []
    while len(bag) < args.count:
        batch = names[:]
        rng.shuffle(batch)
        bag.extend(batch)
    bag = bag[:args.count]

    tile = Image.new("RGBA", (args.size, args.size), (0, 0, 0, 0))
    placed = []  # (cx, cy, radius)
    skipped = 0

    for name in bag:
        src = sources[name]
        frac = rng.uniform(lo, hi)
        target = frac * args.size
        f = target / max(src.size)
        stk = src.resize((max(1, int(src.width * f)),
                          max(1, int(src.height * f))), Image.LANCZOS)
        stk = stk.rotate(rng.uniform(-args.rot, args.rot),
                         expand=True, resample=Image.BICUBIC)
        radius = 0.42 * max(stk.size)  # tighter than half-diagonal: ink
                                       # rarely fills the corners of its box

        for _ in range(PLACE_TRIES):
            cx = rng.uniform(0, args.size)
            cy = rng.uniform(0, args.size)
            ok = True
            for (px, py, pr) in placed:
                min_d = (radius + pr) * args.spacing
                if toroidal_dist2(cx, cy, px, py, args.size) < min_d * min_d:
                    ok = False
                    break
            if ok:
                paste_wrapped(tile, stk, cx, cy)
                placed.append((cx, cy, radius))
                break
        else:
            skipped += 1

    args.out.parent.mkdir(parents=True, exist_ok=True)
    tile.save(args.out)
    print(f"{args.out.name}: {len(placed)} placed, {skipped} skipped "
          f"(seed {args.seed}, {len(names)} distinct stickers)")

    if args.preview:
        paper = (244, 239, 225)
        two = Image.new("RGB", (args.size * 2, args.size * 2), paper)
        for ox in (0, args.size):
            for oy in (0, args.size):
                two.paste(tile, (ox, oy), tile)
        two.thumbnail((1400, 1400), Image.LANCZOS)
        prev = args.out.with_name(args.out.stem + "_preview.png")
        two.save(prev)
        print(f"  -> {prev.name} (2x2 tiled preview)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
