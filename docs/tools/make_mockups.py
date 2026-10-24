#!/usr/bin/env python3
"""Draws design MOCKUPS of the watch face (454x454 round AMOLED, from the official device reference).

These are NOT Connect IQ simulator screenshots: fonts are DejaVu, not Garmin's, so glyph shapes and exact
positions differ from the real device, and the real font per size is chosen on the watch by a fit check
(DECISIONS.md D-17). Replace with real simulator screenshots (see README) before using them in the store listing.
"""
from PIL import Image, ImageDraw, ImageFont
import os

SIZE = 454
OUT = os.path.join(os.path.dirname(__file__), "..", "mockups")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
CAPTION = "MOCKUP - not a simulator screenshot"
GREY, GREY_AOD = (0xB0, 0xB0, 0xB0), (0x6E, 0x6E, 0x6E)
# Stand-in pixel sizes for the device fonts (NUMBER_MILD 113 / NUMBER_MEDIUM 153 / NUMBER_HOT 173, FONT_LARGE 71),
# scaled by ~0.88 because DejaVu digits are taller than their em box suggests.
TIME_PX = {"small": 100, "medium": 134, "large": 152}
TIME_PX_AOD = {"small": 62, "medium": 100, "large": 100}


def scale(rgb, pct):
    return tuple(c * pct // 100 for c in rgb)


def bezel(im, caption=CAPTION):
    out = Image.new("RGB", (SIZE + 40, SIZE + 40 + 30), (24, 24, 24))
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, SIZE - 1, SIZE - 1), fill=255)
    out.paste(im, (20, 20), mask)
    ImageDraw.Draw(out).text((out.width // 2, out.height - 18), caption, fill=(200, 80, 80),
                             font=ImageFont.truetype(FONT, 14), anchor="mm")
    return out


def face(hour_rgb, minute_rgb, size="medium", low_power=False, phase=0, t=("12", "34"),
         date="Fri 23 Oct", steps="8,432", raw=False):
    s = 4  # supersample
    im = Image.new("RGB", (SIZE * s, SIZE * s), (0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = cy = SIZE * s // 2
    colon_rgb = hour_rgb if hour_rgb == minute_rgb else GREY
    if low_power:
        sh = 8 * s
        cx += -sh if phase in (0, 3) else sh
        cy += -sh if phase < 2 else sh
        colon_rgb = GREY_AOD if colon_rgb == GREY else scale(colon_rgb, 60)
        hour_rgb, minute_rgb = scale(hour_rgb, 60), scale(minute_rgb, 60)
        tf = ImageFont.truetype(FONT, TIME_PX_AOD[size] * s)
        sf = ImageFont.truetype(FONT, 24 * s)
        grey = GREY_AOD
    else:
        tf = ImageFont.truetype(FONT, TIME_PX[size] * s)
        sf = ImageFont.truetype(FONT, 38 * s)
        grey = GREY
    th = tf.size
    r = max(3 * s, th // 26)
    gap = r * 6
    d.text((cx - gap // 2, cy), t[0], font=tf, fill=hour_rgb, anchor="rm")
    d.text((cx + gap // 2, cy), t[1], font=tf, fill=minute_rgb, anchor="lm")
    off = th * 14 // 100
    for dy in (-off, off):
        d.ellipse((cx - r, cy + dy - r, cx + r, cy + dy + r), fill=colon_rgb)
    sp = SIZE * s * 3 // 100
    d.text((cx, cy - th // 2 - sp - sf.size // 2 + 4 * s), date, font=sf, fill=grey, anchor="mm")
    d.text((cx, cy + th // 2 + sp + sf.size // 2 - 4 * s), steps, font=sf, fill=grey, anchor="mm")
    im = im.resize((SIZE, SIZE), Image.LANCZOS)
    return im if raw else bezel(im)


def settings_menu():
    """Rough sketch of the on-device Menu2 (the real look is drawn by the watch's system menu)."""
    im = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    d = ImageDraw.Draw(im)
    title = ImageFont.truetype(FONT, 30)
    lab = ImageFont.truetype(FONT, 30)
    sub = ImageFont.truetype(FONT_REG, 24)
    d.text((SIZE // 2, 70), "Noir Time", font=title, fill=(255, 255, 255), anchor="mm")
    rows = [("Time Size", "Medium"), ("Hour Color", "White"), ("Minute Color", "Cyan")]
    for i, (a, b) in enumerate(rows):
        y = 150 + i * 95
        d.line((80, y - 40, SIZE - 80, y - 40), fill=(60, 60, 60), width=2)
        d.text((SIZE // 2, y - 8), a, font=lab, fill=(255, 255, 255), anchor="mm")
        d.text((SIZE // 2, y + 26), b, font=sub, fill=(150, 150, 150), anchor="mm")
    return bezel(im, CAPTION + " (menu sketch)")


def sheet(tiles, cols):
    w, h = tiles[0].size
    out = Image.new("RGB", (w * cols, h * ((len(tiles) + cols - 1) // cols)), (24, 24, 24))
    for i, t in enumerate(tiles):
        out.paste(t, ((i % cols) * w, (i // cols) * h))
    return out


COLORS = {
    "white": (0xFF, 0xFF, 0xFF), "cyan": (0x00, 0xD4, 0xFF), "green": (0x30, 0xE0, 0x60),
    "yellow": (0xFF, 0xD6, 0x0A), "orange": (0xFF, 0x95, 0x00), "red": (0xFF, 0x45, 0x3A),
    "pink": (0xFF, 0x4F, 0xA0), "purple": (0xB3, 0x88, 0xFF),
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    W, C = COLORS["white"], COLORS["cyan"]
    face(W, W).save(os.path.join(OUT, "mockup_high_power_white.png"))
    face(W, C).save(os.path.join(OUT, "mockup_high_power_white_cyan.png"))
    small = (227 + 20, 227 + 35)
    sheet([face(W, C, size=z).resize(small) for z in ("small", "medium", "large")], 3) \
        .save(os.path.join(OUT, "mockup_sizes.png"))
    sheet([face(W, C, size=z, low_power=True, phase=1).resize(small) for z in ("small", "medium", "large")], 3) \
        .save(os.path.join(OUT, "mockup_always_on_sizes.png"))
    face(W, C, low_power=True, phase=1).save(os.path.join(OUT, "mockup_always_on.png"))
    pairs = [("white", "cyan"), ("cyan", "white"), ("orange", "yellow"), ("green", "white"),
             ("purple", "pink"), ("red", "orange"), ("yellow", "yellow"), ("pink", "purple")]
    sheet([face(COLORS[a], COLORS[b]).resize(small) for a, b in pairs], 4) \
        .save(os.path.join(OUT, "mockup_color_options.png"))
    settings_menu().save(os.path.join(OUT, "mockup_settings_menu.png"))
    # lit-pixel estimate for always-on (stand-in font, NOT a measurement)
    for z in ("small", "medium", "large"):
        im = face(W, W, size=z, low_power=True, phase=1, raw=True).convert("L")
        lit = sum(1 for p in im.getdata() if p > 8)
        print(f"AOD {z}: ~{100 * lit / (SIZE * SIZE):.1f}% of pixels lit (estimate)")
    print("written to", os.path.abspath(OUT))
