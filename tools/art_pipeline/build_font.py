#!/usr/bin/env python3
"""build_font.py — assemble the owner's hand-drawn glyphs into a real TTF.

Pipeline: glyph PNGs (from extract_glyphs.py) -> 1-bit PBM -> potrace SVG
outlines -> FontForge assembly (ff_assemble.py, run under fontforge's own
python) -> assets/fonts/aq_hand.ttf.

Metrics model:
  - em 1000, ascent 780, descent 220, cap height 660
  - every glyph is normalized to its TYPOGRAPHIC CLASS height (all caps
    to cap height, all x-letters to one x-height, ascenders/descenders
    to theirs) — the owner's letterFORMS survive, but the as-drawn size
    wobble does not (preserving it read as a ransom note; owner verdict
    2026-07-12)
  - vertical placement per character (descenders hang, parens dip,
    quotes float, tilde centers); everything else sits on the baseline
  - advance = glyph width + fixed side bearings; SPACE is synthetic
  - glyphs are upscaled before tracing so thin ballpoint strokes vector
    cleanly even from small-drawn originals

Regeneration is free: fix a glyph PNG (or redraw + re-extract), re-run.

Usage:  python3 tools/art_pipeline/build_font.py
Requires: potrace + fontforge (brew install potrace fontforge)
"""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FONT_DIR = ROOT / "art_drops" / "font"
GLYPH_DIR = FONT_DIR / "glyphs"
OUT_TTF = ROOT / "assets" / "fonts" / "aq_hand.ttf"

EM = 1000
ASCENT = 780
DESCENT = 220
LSB = 55.0
RSB = 55.0
SPACE_ADV = 300
TRACE_MIN_H = 400  # upscale glyph rasters to at least this before potrace

# char -> (target height in em units, bottom relative to baseline).
# Class defaults below; this dict is the per-character override table.
METRICS: dict = {}
for _c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
    METRICS[_c] = (660.0, 0.0)
for _c in "0123456789":
    METRICS[_c] = (640.0, 0.0)
for _c in "acemnorsuvwxz":
    METRICS[_c] = (460.0, 0.0)
for _c in "bdfhkl":
    METRICS[_c] = (680.0, 0.0)
for _c in "gpqy":
    METRICS[_c] = (640.0, -200.0)
for _c in "()[]{}":
    METRICS[_c] = (760.0, -140.0)
METRICS.update({
    "t": (600.0, 0.0),
    "i": (580.0, 0.0),
    "j": (740.0, -200.0),
    "!": (660.0, 0.0), "?": (660.0, 0.0), "&": (660.0, 0.0),
    "#": (620.0, 0.0), "%": (620.0, 0.0), "@": (620.0, 0.0),
    "<": (400.0, 120.0), ">": (400.0, 120.0),
    "*": (300.0, 390.0), "^": (260.0, 440.0),
    "~": (240.0, 210.0),
    '"': (220.0, 470.0), "'": (220.0, 470.0),
    ":": (460.0, 0.0), ";": (560.0, -110.0),
    ",": (200.0, -110.0), ".": (120.0, 0.0),
    "-": (90.0, 255.0), "=": (260.0, 170.0),
    "+": (400.0, 120.0), "/": (700.0, -20.0), "\\": (700.0, -20.0),
    "_": (80.0, -80.0),
})


def main() -> int:
    meta = json.loads((FONT_DIR / "glyphs.json").read_text())

    tmp = Path(tempfile.mkdtemp(prefix="aqfont_"))
    jobs = []
    for ch, entry in sorted(meta.items(), key=lambda kv: ord(kv[0])):
        if ch not in METRICS:
            print(f"no metrics for {ch!r} - add to METRICS; skipped")
            continue
        target_h, bottom = METRICS[ch]
        png = GLYPH_DIR / entry["file"]
        alpha_img = Image.open(png).split()[-1]
        # Upscale small originals so potrace gets smooth, unbroken strokes.
        if alpha_img.height < TRACE_MIN_H:
            factor = TRACE_MIN_H / alpha_img.height
            alpha_img = alpha_img.resize(
                (max(1, round(alpha_img.width * factor)), TRACE_MIN_H),
                Image.LANCZOS)
        alpha = np.asarray(alpha_img)
        bw = np.where(alpha > 100, 0, 255).astype(np.uint8)  # potrace traces black
        pbm = tmp / (entry["file"] + ".pbm")
        svg = tmp / (entry["file"] + ".svg")
        Image.fromarray(bw).convert("1").save(pbm)
        subprocess.run(["potrace", str(pbm), "-s", "-o", str(svg)], check=True)
        jobs.append({"char": ch, "svg": str(svg), "h_em": target_h,
                     "bottom": bottom, "lsb": LSB, "rsb": RSB})

    OUT_TTF.parent.mkdir(parents=True, exist_ok=True)
    job = {"em": EM, "ascent": ASCENT, "descent": DESCENT,
           "space": SPACE_ADV, "glyphs": jobs, "out": str(OUT_TTF),
           "family": "Animal Quickdraw Hand",
           "fontname": "AnimalQuickdrawHand"}
    job_path = tmp / "job.json"
    job_path.write_text(json.dumps(job))

    result = subprocess.run(
        ["fontforge", "-lang=py", "-script",
         str(Path(__file__).parent / "ff_assemble.py"), str(job_path)],
        capture_output=True, text=True)
    if result.stdout.strip():
        print(result.stdout)
    if result.returncode != 0:
        print(result.stderr)
        return 1
    print(f"-> {OUT_TTF}  ({len(jobs)} glyphs + space)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
