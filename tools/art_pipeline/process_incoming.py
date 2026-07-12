#!/usr/bin/env python3
"""process_incoming.py — extract stickers from every photo in
art_drops/collage/incoming/, then move each processed photo to done/.
Next run only touches newly added photos. After processing, the full-library
contact sheet (stickers_contact.png) is regenerated for owner review.

Usage:  python3 tools/art_pipeline/process_incoming.py
"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INCOMING = ROOT / "art_drops" / "collage" / "incoming"
DONE = ROOT / "art_drops" / "collage" / "done"
STICKERS = ROOT / "art_drops" / "collage" / "stickers"
CLEAN_SCAN = Path(__file__).parent / "clean_scan.py"
PHOTO_EXTS = (".jpg", ".jpeg", ".png", ".heic", ".heif")


def main() -> int:
    DONE.mkdir(parents=True, exist_ok=True)
    photos = sorted(p for p in INCOMING.iterdir()
                    if p.suffix.lower() in PHOTO_EXTS)
    if not photos:
        print("nothing new in incoming/")
    for photo in photos:
        # --paper-tol/--noise-floor: anti-grid settings (owner-confirmed on
        # the gridanimals batches) — the stack is grid paper from here on.
        result = subprocess.run(
            [sys.executable, str(CLEAN_SCAN), str(photo),
             "--mode", "scraps", "--paper-tol", "0.18", "--noise-floor", "0.3",
             "--out", str(STICKERS)])
        if result.returncode == 0:
            photo.rename(DONE / photo.name)
        else:
            print(f"FAILED {photo.name} - left in incoming/")

    # One contact sheet covering the WHOLE library, not just this batch.
    sys.path.insert(0, str(Path(__file__).parent))
    from clean_scan import write_contact_sheet
    stickers = sorted(STICKERS.glob("*.png"))
    if stickers:
        write_contact_sheet([(p.stem, p) for p in stickers],
                            STICKERS.with_name(STICKERS.name + "_contact.png"))
    print(f"library: {len(stickers)} sticker(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
