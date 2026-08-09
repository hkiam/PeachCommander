#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""make-dmg-background.py — derive the disk image's background from the source artwork (F-311).

The artwork in `Design/dmg/source.png` is a *picture of the finished window*: it shows the app icon,
the Applications folder and both names. A disk image background must not — the Finder draws the real
icons and labels on top of it, so anything baked in appears twice. Two changes turn one into the other,
and both are here rather than in an image editor so the result can be made again from the source.

**The icons and labels are painted out.** The two regions are refilled by interpolating across them
from their own left and right edges, which suits a background that is a smooth gradient, and the seams
are then blurred so the patches do not read as rectangles.

**A soft glow goes under each label.** This is the one thing the artwork cannot solve by itself: the
Finder draws icon names in the *system's* label colour, which is near-black in light mode and white in
dark mode, and the artwork's dark stage only works for one of them. Measured on the real file, the
label row sits at luminance 30 of 255 — white text is bright and clear there, black text is all but
invisible, and most Macs are in light mode.

Around 50 % luminance is the only range where both remain legible, so the glow lifts exactly the two
label rows to roughly 120. It is a soft ellipse rather than a plate because a hard edge would be a
foreign body in a composition made of flowing shapes; it reads as warm light under the icons.

Geometry is fixed by `make-dmg.sh`: a 600 × 400 window, 128 pt icons centred at (150,200) and
(450,200), names drawn below them at roughly y 266–290.

Usage: Tools/make-dmg-background.py [--check]
"""
from __future__ import annotations

import pathlib
import sys

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    print("Pillow is needed: python3 -m pip install --user Pillow", file=sys.stderr)
    raise SystemExit(2)

REPO = pathlib.Path(__file__).resolve().parents[1]
SOURCE = REPO / "Design/dmg/source.png"
OUT_1X = REPO / "Design/dmg/background.png"
OUT_2X = REPO / "Design/dmg/background@2x.png"

# The window, and what the Finder puts where in it.
WINDOW = (600, 400)
ICON_CENTRES = (150, 450)
LABEL_ROW = (258, 302)          # a little either side of where the names are drawn
COVER = [(74, 126, 238, 300), (374, 126, 538, 300)]   # icon + label, generously
GLOW_COLOUR = (206, 128, 96)    # the artwork's own peach, at a luminance both label colours survive


def luminance(pixel) -> int:
    return int(0.299 * pixel[0] + 0.587 * pixel[1] + 0.114 * pixel[2])


def build() -> Image.Image:
    """The source artwork with the baked-in icons removed and the label rows lifted."""
    image = Image.open(SOURCE).convert("RGB")
    width, height = image.size
    sx, sy = width / WINDOW[0], height / WINDOW[1]

    def scaled(x0, y0, x1, y1):
        return int(x0 * sx), int(y0 * sy), int(x1 * sx), int(y1 * sy)

    pixels = image.load()
    regions = [scaled(*box) for box in COVER]
    for x0, y0, x1, y1 in regions:
        for y in range(y0, y1):
            left = pixels[max(0, x0 - 3), y]
            right = pixels[min(width - 1, x1 + 3), y]
            span = max(1, x1 - x0)
            for x in range(x0, x1):
                t = (x - x0) / span
                pixels[x, y] = tuple(int(left[c] * (1 - t) + right[c] * t) for c in range(3))

    seams = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(seams)
    for x0, y0, x1, y1 in regions:
        draw.rectangle([x0 - 6, y0 - 6, x1 + 6, y1 + 6], fill=255)
    seams = seams.filter(ImageFilter.GaussianBlur(14))
    image = Image.composite(image.filter(ImageFilter.GaussianBlur(6)), image, seams)

    glow_mask = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(glow_mask)
    for centre in ICON_CENTRES:
        draw.ellipse([int((centre - 105) * sx), int(LABEL_ROW[0] * sy),
                      int((centre + 105) * sx), int(LABEL_ROW[1] * sy)], fill=255)
    glow_mask = glow_mask.filter(ImageFilter.GaussianBlur(int(16 * sx)))
    glow = Image.new("RGB", image.size, GLOW_COLOUR)
    return Image.composite(glow, image, glow_mask.point(lambda v: int(v * 0.92)))


def main() -> int:
    if not SOURCE.exists():
        print(f"  ⚠️  {SOURCE.relative_to(REPO)} is missing", file=sys.stderr)
        return 1

    image = build()
    width, height = image.size
    sx, sy = width / WINDOW[0], height / WINDOW[1]

    # The point of the glow is a number, so it is read back rather than trusted. Both label rows have
    # to land in the middle of the range; too dark and black text disappears, too light and white does.
    problems = 0
    for centre in ICON_CENTRES:
        value = luminance(image.load()[int(centre * sx), int(278 * sy)])
        if not 100 <= value <= 150:
            print(f"  ⚠️  the label row at x={centre} is at luminance {value}; "
                  f"one of the two label colours will be hard to read", file=sys.stderr)
            problems += 1

    if "--check" not in sys.argv:
        image.resize((1200, 800), Image.LANCZOS).save(OUT_2X)
        image.resize(WINDOW, Image.LANCZOS).save(OUT_1X)
        print(f"wrote {OUT_1X.relative_to(REPO)} and {OUT_2X.relative_to(REPO)}")

    lums = [luminance(image.load()[int(c * sx), int(278 * sy)]) for c in ICON_CENTRES]
    print(f"label_row_luminance={lums} problems={problems}")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
