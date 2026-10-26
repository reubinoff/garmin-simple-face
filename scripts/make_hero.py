#!/usr/bin/env python3
"""Renders the Connect IQ Store hero image store/hero/hero_1440x720.png (1440 x 720 px, store limit 2048 KB).

    python3 scripts/make_hero.py [screenshot] [out]

* Title "CLEAN AIR" in Bebas Neue (assets/fonts/BebasNeue, SIL OFL) - the same font as the watch-face time.
* Tagline and feature line in Roboto (tests/host/fonts, SIL OFL).
* Right side: the round screen of a REAL simulator screenshot from docs/screenshots/ (default: the XLarge
  white/cyan frame), masked to its 454 px circle and framed by a thin grey ring - no mock-up of the face.
* Background: dark slate radial gradient, so the black watch screen still stands out. Needs Pillow.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SHOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "screenshots", "active_xlarge_white-cyan.png")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "store", "hero", "hero_1440x720.png")
BEBAS = os.path.join(ROOT, "assets", "fonts", "BebasNeue", "BebasNeue-Regular.ttf")
ROBOTO = os.path.join(ROOT, "tests", "host", "fonts", "Roboto-VariableFont_wdth,wght.ttf")
W, H = 1440, 720
SS = 2  # supersampling for smooth circle edges


def roboto(size, weight):
    f = ImageFont.truetype(ROBOTO, size)
    try:
        f.set_variation_by_axes([100, weight])  # axes: wdth, wght
    except (OSError, ValueError):
        pass
    return f


def main():
    # Background: radial gradient from #2A2F37 (left of centre) to #0B0D10 at the corners.
    bg = Image.radial_gradient("L").resize((W * 2, H * 2))
    bg = bg.crop((W // 2 + 200, H // 2, W // 2 + 200 + W, H // 2 + H))
    lo, hi = (42, 47, 55), (11, 13, 16)
    base = Image.merge("RGB", [bg.point(lambda v, a=a, b=b: int(a + (b - a) * v / 255)) for a, b in zip(lo, hi)])

    # Watch: 454 px round screen scaled to 560 px, grey ring, centred at (1075, 360).
    d, cx, cy, ring = 560, 1075, 360, 6
    shot = Image.open(SHOT).convert("RGB").resize((d * SS, d * SS), Image.LANCZOS)
    mask = Image.new("L", (d * SS, d * SS), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, d * SS - 1, d * SS - 1), fill=255)
    big = base.resize((W * SS, H * SS), Image.LANCZOS)
    dr = ImageDraw.Draw(big)
    r = (d // 2 + ring) * SS
    dr.ellipse(((cx * SS) - r, (cy * SS) - r, (cx * SS) + r, (cy * SS) + r), fill=(74, 80, 90))
    big.paste(shot, (cx * SS - d * SS // 2, cy * SS - d * SS // 2), mask)
    img = big.resize((W, H), Image.LANCZOS)

    # Text block on the left.
    dr = ImageDraw.Draw(img)
    x = 120
    title = ImageFont.truetype(BEBAS, 200)
    dr.text((x, 175), "CLEAN AIR", font=title, fill=(255, 255, 255))
    dr.text((x + 4, 405), "Fresh. Simple. Clean as morning air.", font=roboto(40, 400), fill=(0, 207, 255))
    dr.text((x + 4, 470), "Big time, date, steps & Body Battery", font=roboto(32, 300), fill=(170, 176, 186))
    dr.text((x + 4, 515), "Three configurable data fields", font=roboto(32, 300), fill=(170, 176, 186))

    img.save(OUT, "PNG", optimize=True)
    print(f"{OUT}: {img.size[0]}x{img.size[1]}, {os.path.getsize(OUT)} bytes")


if __name__ == "__main__":
    main()
