#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""make-dmg-background.py — derive the disk image's background from the source artwork (F-311).

`Design/dmg/source.png` is the artwork with nothing in the icon positions: the Finder draws the real
app icon, the Applications folder and both names on top of the background, so anything of the sort
baked into the picture would appear twice. The first artwork was a rendering of the finished window and
had to have them painted out; this reads the empty one directly, and *checks* that it is empty rather
than trusting the file name.

The artwork is the stage only — gradient, flare, dot pattern and the peach ribbon. The lettering is
placed here rather than drawn into it, because every position depends on geometry the picture cannot
know: the wordmark has to clear the icons, the arrow has to fit the gap between them, and the address
has to stay below the ribbon. Change the window or the icon size in make-dmg.sh and this follows.

And the labels, which is the one thing the artwork cannot solve for itself. The Finder draws icon names
in the **system's** label colour — near-black in light appearance, white in dark — and it has no idea
what is behind them. Measured on this artwork, the label row sits at luminance 17–29 of 255: white text
is bright and clear there, black text is all but invisible, and most Macs are in light mode.

Around 50 % luminance is the only range where both survive, so a soft glow in the artwork's own peach
lifts exactly the two label rows to roughly 120. An ellipse rather than a plate: a hard edge would be a
foreign body in a composition made of flowing shapes, and as a glow it reads as warm light under the
icons. The result is measured afterwards, so the numbers chosen here cannot quietly stop being true.

Geometry comes from `make-dmg.sh`: a 600 × 400 window, 128 pt icons centred at (150,200) and (450,200),
names drawn below them at roughly y 266–290.

Usage: Tools/make-dmg-background.py [--check]
"""
from __future__ import annotations

import pathlib
import sys

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageStat
except ImportError:
    print("Pillow is needed: python3 -m pip install --user Pillow", file=sys.stderr)
    raise SystemExit(2)

REPO = pathlib.Path(__file__).resolve().parents[1]
SOURCE = REPO / "Design/dmg/source.png"
OUT_1X = REPO / "Design/dmg/background.png"
OUT_2X = REPO / "Design/dmg/background@2x.png"

WINDOW = (600, 400)
ICON_CENTRES = (150, 450)
ICON_BOX = (64, 136, 264)       # half-width, top, bottom of a 128 pt icon at y = 200
LABEL_Y = 278                   # where the Finder draws the names
LABEL_ROW = (258, 302)          # a little either side of it, for the glow
GLOW_COLOUR = (206, 128, 96)    # the artwork's own peach, at a luminance both label colours survive

# Above this much variation, something is drawn where an icon belongs. Measured on both artworks: the
# one with the icons rendered in scores about 50, the empty one about 3.
ICON_ZONE_VARIATION = 15.0
# The label row has to land in the middle of the range: darker and black text disappears, lighter and
# white does.
LABEL_LUMINANCE = (100, 150)


def luminance(pixel) -> int:
    return int(0.299 * pixel[0] + 0.587 * pixel[1] + 0.114 * pixel[2])


def main() -> int:
    if not SOURCE.exists():
        print(f"  ⚠️  {SOURCE.relative_to(REPO)} is missing", file=sys.stderr)
        return 1

    image = Image.open(SOURCE).convert("RGB")
    width, height = image.size
    problems = 0

    # 3:2, or the artwork is stretched into the window rather than fitted to it.
    if abs(width / height - WINDOW[0] / WINDOW[1]) > 0.01:
        print(f"  ⚠️  {width}×{height} is not 3:2 — it will be distorted in a "
              f"{WINDOW[0]}×{WINDOW[1]} window", file=sys.stderr)
        problems += 1

    sx, sy = width / WINDOW[0], height / WINDOW[1]

    # Is anything drawn where the Finder will put the icons? If so the finished image shows two of
    # everything, which is the mistake the first artwork made and which is invisible until the disk
    # image is opened.
    grey = image.convert("L")
    half, top, bottom = ICON_BOX
    for centre in ICON_CENTRES:
        box = (int((centre - half) * sx), int(top * sy), int((centre + half) * sx), int(bottom * sy))
        variation = ImageStat.Stat(grey.crop(box)).stddev[0]
        if variation > ICON_ZONE_VARIATION:
            print(f"  ⚠️  something is drawn at ({centre},200) — variation {variation:.1f}. The Finder "
                  f"draws the real icon there, so both would show.", file=sys.stderr)
            problems += 1

    # The lettering. Positions are derived from the same geometry as the icons: the wordmark sits above
    # them, the arrow inside the gap they leave (x 214–386), the address below the ribbon.
    draw = ImageDraw.Draw(result_base := image.copy())
    peach = (255, 138, 91)

    def font(size: int, weight: str = "Regular"):
        # SFNS is the system face and carries its weights as variations; PIL cannot select those, so
        # the bold pieces use the bold face on disk. Helvetica is the fallback wherever SF is absent.
        for path in (f"/System/Library/Fonts/Supplemental/Arial {weight}.ttf" if weight == "Bold"
                     else "/System/Library/Fonts/SFNS.ttf",
                     "/System/Library/Fonts/Helvetica.ttc"):
            try:
                return ImageFont.truetype(path, int(size * sy))
            except OSError:
                continue
        return ImageFont.load_default()

    def centred(text: str, y: int, f, fill, anchor_y: str = "mm"):
        draw.text((width / 2, int(y * sy)), text, font=f, fill=fill, anchor=f"m{anchor_y[1]}")

    centred("Peach Commander", 74, font(30, "Bold"), (255, 255, 255))
    draw.rounded_rectangle([int(246 * sx), int(96 * sy), int(354 * sx), int(99 * sy)],
                           radius=int(1.5 * sy), fill=peach)

    # The arrow, in the strip the two icons leave free. Two short strokes ahead of it for the motion
    # the artwork's own arrow had.
    for x0, x1, y0 in ((222, 244, 192), (222, 236, 205)):
        draw.rounded_rectangle([int(x0 * sx), int(y0 * sy), int(x1 * sx), int((y0 + 3) * sy)],
                               radius=int(1.5 * sy), fill=(255, 157, 104, 140))
    draw.rounded_rectangle([int(254 * sx), int(196 * sy), int(340 * sx), int(204 * sy)],
                           radius=int(4 * sy), fill=peach)
    draw.polygon([(int(338 * sx), int(186 * sy)), (int(372 * sx), int(200 * sy)),
                  (int(338 * sx), int(214 * sy))], fill=(255, 122, 61))

    # The address, below the ribbon and clear of the labels.
    centred("github.com/hkiam/PeachCommander", 374, font(13), (255, 255, 255))
    image = result_base

    # The glow under the two label rows.
    mask = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(mask)
    for centre in ICON_CENTRES:
        draw.ellipse([int((centre - 105) * sx), int(LABEL_ROW[0] * sy),
                      int((centre + 105) * sx), int(LABEL_ROW[1] * sy)], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(int(16 * sx)))
    glow = Image.new("RGB", image.size, GLOW_COLOUR)
    result = Image.composite(glow, image, mask.point(lambda v: int(v * 0.92)))

    # Read the result back rather than assume the numbers above still do what they did.
    pixels = result.load()
    values = []
    for centre in ICON_CENTRES:
        value = luminance(pixels[int(centre * sx), int(LABEL_Y * sy)])
        values.append(value)
        if not LABEL_LUMINANCE[0] <= value <= LABEL_LUMINANCE[1]:
            print(f"  ⚠️  the label row at x={centre} is at luminance {value}; one of the two label "
                  f"colours will be hard to read", file=sys.stderr)
            problems += 1

    if "--check" not in sys.argv and problems == 0:
        result.resize((WINDOW[0] * 2, WINDOW[1] * 2), Image.LANCZOS).save(OUT_2X)
        result.resize(WINDOW, Image.LANCZOS).save(OUT_1X)
        print(f"wrote {OUT_1X.relative_to(REPO)} and {OUT_2X.relative_to(REPO)}")

    print(f"source={width}×{height} label_row_luminance={values} problems={problems}")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
