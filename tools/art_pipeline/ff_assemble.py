# Runs under FontForge's bundled python:  fontforge -lang=py -script ff_assemble.py job.json
# Assembles potrace SVG outlines into a TTF per the job spec produced by
# build_font.py. Import scaling is normalized from the glyph's own bounding
# box (FontForge's SVG unit mapping is not trusted), so placement is exact.
import json
import sys

import fontforge
import psMat

job = json.load(open(sys.argv[1]))

font = fontforge.font()
font.encoding = "UnicodeFull"
font.em = job["em"]
font.ascent = job["ascent"]
font.descent = job["descent"]
font.familyname = job["family"]
font.fontname = job["fontname"]
font.fullname = job["family"]

for g in job["glyphs"]:
    glyph = font.createChar(ord(g["char"]))
    glyph.importOutlines(g["svg"])
    xmin, ymin, xmax, ymax = glyph.boundingBox()
    height = ymax - ymin
    width = xmax - xmin
    if height <= 0 or width <= 0:
        print("empty outline for", repr(g["char"]))
        continue
    s = g["h_em"] / height
    glyph.transform(psMat.translate(-xmin, -ymin))
    glyph.transform(psMat.scale(s))
    glyph.transform(psMat.translate(g["lsb"], g["bottom"]))
    glyph.removeOverlap()
    glyph.simplify()
    glyph.round()
    glyph.width = int(round(g["lsb"] + width * s + g["rsb"]))

space = font.createChar(32)
space.width = job["space"]

font.generate(job["out"])
print("generated", job["out"], "with", len(job["glyphs"]), "glyphs")
