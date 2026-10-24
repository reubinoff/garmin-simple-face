#!/usr/bin/env python3
"""Draws design MOCKUPS of the watch face with the host model tests/host/face_model.py (the same drawing steps as
NoirTimeView.onUpdate: font fit, outline offsets, AOD shift, row mask).

These are NOT Connect IQ simulator screenshots: Garmin's device fonts are not redistributable, so the model uses
stand-in OFL fonts (Rajdhani Medium for the NUMBER_* fonts, Roboto for FONT_SMALL) at the sizes from the
fenix9pro47mm device reference. Glyph shapes and exact pixel counts differ from the watch.
Real screenshots go to docs/screenshots/ (see README "Screenshots").
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tests", "host"))
import face_model as m  # noqa: E402

SIZE = m.SCREEN
OUT = os.path.join(HERE, "..", "mockups")
FONT = os.path.join(HERE, "..", "..", "tests", "host", "fonts", "Roboto-VariableFont_wdth,wght.ttf")
CAPTION = "MOCKUP (host model, stand-in fonts) - not a simulator screenshot"
COLORS = dict(zip(("white", "cyan", "green", "yellow", "orange", "red", "pink", "purple"), m.color_values()))
SIZES = {"small": 0, "medium": 1, "large": 2}


def bezel(arr, caption=CAPTION):
    im = Image.fromarray(arr.astype(np.uint8))
    out = Image.new("RGB", (SIZE + 40, SIZE + 40 + 30), (24, 24, 24))
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, SIZE - 1, SIZE - 1), fill=255)
    out.paste(im, (20, 20), mask)
    ImageDraw.Draw(out).text((out.width // 2, out.height - 18), caption, fill=(200, 80, 80),
                             font=ImageFont.truetype(FONT, 13), anchor="mm")
    return out


def face(hour, minute, size="medium", low_power=False, minute_of_hour=34, caption=CAPTION):
    return bezel(m.render(SIZES[size], COLORS[hour], COLORS[minute], low_power, hour=12, minute=minute_of_hour,
                          steps=8432, date="Fri 23 Oct"), caption)


def settings_menu():
    """Rough sketch of the on-device Menu2 (the real look is drawn by the watch's system menu)."""
    im = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    d = ImageDraw.Draw(im)
    f, sub = ImageFont.truetype(FONT, 30), ImageFont.truetype(FONT, 24)
    d.text((SIZE // 2, 70), "Noir Time", font=f, fill=(255, 255, 255), anchor="mm")
    for i, (a, b) in enumerate([("Time Size", "Medium"), ("Hour Color", "White"), ("Minute Color", "Cyan")]):
        y = 150 + i * 95
        d.line((80, y - 40, SIZE - 80, y - 40), fill=(60, 60, 60), width=2)
        d.text((SIZE // 2, y - 8), a, font=f, fill=(255, 255, 255), anchor="mm")
        d.text((SIZE // 2, y + 26), b, font=sub, fill=(150, 150, 150), anchor="mm")
    return bezel(np.asarray(im), "MOCKUP (menu sketch) - the real menu is drawn by the watch")


def sheet(tiles, cols):
    w, h = tiles[0].size
    out = Image.new("RGB", (w * cols, h * ((len(tiles) + cols - 1) // cols)), (24, 24, 24))
    for i, t in enumerate(tiles):
        out.paste(t, ((i % cols) * w, (i // cols) * h))
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    small = ((SIZE + 40) // 2, (SIZE + 70) // 2)
    face("white", "white").save(os.path.join(OUT, "mockup_high_power_white.png"))
    face("white", "cyan").save(os.path.join(OUT, "mockup_high_power_white_cyan.png"))
    sheet([face("white", "cyan", z).resize(small) for z in SIZES], 3).save(os.path.join(OUT, "mockup_sizes.png"))
    sheet([face("white", "cyan", z, True).resize(small) for z in SIZES], 3) \
        .save(os.path.join(OUT, "mockup_always_on_sizes.png"))
    face("white", "cyan", "medium", True).save(os.path.join(OUT, "mockup_always_on.png"))
    sheet([face("white", "cyan", z, lp).resize(small) for z in SIZES for lp in (False, True)], 2) \
        .save(os.path.join(OUT, "mockup_active_vs_always_on.png"))
    pairs = [("white", "cyan"), ("cyan", "white"), ("orange", "yellow"), ("green", "white"),
             ("purple", "pink"), ("red", "orange"), ("yellow", "yellow"), ("pink", "purple")]
    sheet([face(a, b).resize(small) for a, b in pairs], 4).save(os.path.join(OUT, "mockup_color_options.png"))
    settings_menu().save(os.path.join(OUT, "mockup_settings_menu.png"))
    print("written to", os.path.abspath(OUT))
