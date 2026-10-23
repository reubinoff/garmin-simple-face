#!/usr/bin/env python3
"""Draws design MOCKUPS of the watch face (454x454 round AMOLED, from the official device reference).

These are NOT Connect IQ simulator screenshots: fonts are DejaVu, not Garmin's, so glyph shapes and exact
positions differ from the real device. Replace with real simulator screenshots (see README) before
using them in the store listing.
"""
from PIL import Image, ImageDraw, ImageFont
import os

SIZE = 454
OUT = os.path.join(os.path.dirname(__file__), "..", "mockups")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
CAPTION = "MOCKUP - not a simulator screenshot"


def scale(rgb, pct):
    return tuple(c * pct // 100 for c in rgb)


def face(time_rgb, low_power=False, phase=0, t=("12", "34"), date="Fri 23 Oct", steps="8,432"):
    s = 4  # supersample
    im = Image.new("RGB", (SIZE * s, SIZE * s), (0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = cy = SIZE * s // 2
    if low_power:
        sh = 8 * s
        cx += -sh if phase in (0, 3) else sh
        cy += -sh if phase < 2 else sh
        time_rgb = scale(time_rgb, 60)
        tf = ImageFont.truetype(FONT, 104 * s)
        sf = ImageFont.truetype(FONT, 24 * s)
        grey = (0x6E, 0x6E, 0x6E)
    else:
        tf = ImageFont.truetype(FONT, 148 * s)
        sf = ImageFont.truetype(FONT, 38 * s)
        grey = (0xB0, 0xB0, 0xB0)
    gap = 26 * s if not low_power else 18 * s
    d.text((cx - gap // 2, cy), t[0], font=tf, fill=time_rgb, anchor="rm")
    d.text((cx + gap // 2, cy), t[1], font=tf, fill=time_rgb, anchor="lm")
    th = tf.size
    r = max(3 * s, th // 26 // 1)
    off = th * 14 // 100 // 1
    for dy in (-off, off):
        d.ellipse((cx - r, cy + dy - r, cx + r, cy + dy + r), fill=time_rgb)
    sp = SIZE * s * 3 // 100
    d.text((cx, cy - th // 2 - sp - sf.size // 2 + 4 * s), date, font=sf, fill=grey, anchor="mm")
    d.text((cx, cy + th // 2 + sp + sf.size // 2 - 4 * s), steps, font=sf, fill=grey, anchor="mm")
    im = im.resize((SIZE, SIZE), Image.LANCZOS)
    # round screen mask on a dark grey bezel so the circle is visible
    out = Image.new("RGB", (SIZE + 40, SIZE + 40 + 30), (24, 24, 24))
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, SIZE - 1, SIZE - 1), fill=255)
    out.paste(im, (20, 20), mask)
    ImageDraw.Draw(out).text((out.width // 2, out.height - 18), CAPTION, fill=(200, 80, 80),
                             font=ImageFont.truetype(FONT, 14), anchor="mm")
    return out


COLORS = {
    "white": (0xFF, 0xFF, 0xFF), "cyan": (0x00, 0xD4, 0xFF), "green": (0x30, 0xE0, 0x60),
    "yellow": (0xFF, 0xD6, 0x0A), "orange": (0xFF, 0x95, 0x00), "red": (0xFF, 0x45, 0x3A),
    "pink": (0xFF, 0x4F, 0xA0), "purple": (0xB3, 0x88, 0xFF),
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    face(COLORS["white"]).save(os.path.join(OUT, "mockup_high_power_white.png"))
    face(COLORS["cyan"]).save(os.path.join(OUT, "mockup_high_power_cyan.png"))
    face(COLORS["white"], low_power=True, phase=1).save(os.path.join(OUT, "mockup_always_on.png"))
    names = list(COLORS)
    tiles = [face(COLORS[n]).resize((227 + 20, 227 + 35)) for n in names]
    w, h = tiles[0].size
    sheet = Image.new("RGB", (w * 4, h * 2), (24, 24, 24))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % 4) * w, (i // 4) * h))
    sheet.save(os.path.join(OUT, "mockup_color_options.png"))
    print("written to", os.path.abspath(OUT))
