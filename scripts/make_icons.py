#!/usr/bin/env python3
"""Renders the two on-device store icons (Connect IQ brand guidelines, "On Device App Icon": 128 x 128 px, sRGB,
a full-colour icon for OLED devices and a low-colour icon limited to the 64-colour palette for MIP devices;
https://developer.garmin.com/brand-guidelines/connect-iq/):

    python3 scripts/make_icons.py [out_dir]      (default: store/icons)

* store/icons/icon_24bit_128.png   - 24-bit truecolour PNG (RGB, no alpha).
* store/icons/icon_64color_128.png - 8-bit palette PNG whose every pixel is one of the 64 colours with channels in
  {0x00, 0x55, 0xAA, 0xFF} (the Connect IQ 64-colour palette), no alpha, no dithering.

Design = a preview of the face (the guidelines: "For watch faces, using a preview of the watch face as the app icon
often works best"): the round black screen with the time 10:08 in the REAL Bebas Neue font
(assets/fonts/BebasNeue, the same font as the embedded time bitmaps, D-38), white hours, cyan minutes, and the
face's SQUARE colon drawn with the face's own proportions (source/NoirLayout.mc COLON_GAP_PERCENT,
COLON_DOT_PERCENT, COLON_OFFSET_PERCENT of the digit height; grey COLOR_TEXT when the two colours differ). The
background around the screen is a solid dark slate, because the guidelines say not to use black or transparent
backgrounds. No text, no Garmin branding. Drawn at 8x and downsampled for clean edges. Needs Pillow.
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "store", "icons")
BEBAS = os.path.join(ROOT, "assets", "fonts", "BebasNeue", "BebasNeue-Regular.ttf")
SIZE, SS = 128, 8
LEVELS = (0x00, 0x55, 0xAA, 0xFF)


def layout_const(name):
    src = open(os.path.join(ROOT, "source", "NoirLayout.mc"), encoding="utf-8").read()
    return int(re.search(r"const\s+%s\s*=\s*(0x[0-9A-Fa-f]+|\d+)\s*;" % name, src).group(1), 0)


def rgb(c):
    return (c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF


def render(bg, ring, hour_c, minute_c, colon_c, time_width=92):
    """One icon at SIZE x SIZE (RGB), drawn at SS x and downsampled."""
    S = SIZE * SS
    img = Image.new("RGB", (S, S), bg)
    d = ImageDraw.Draw(img)
    c = S // 2
    r_ring, r_screen = 60 * SS, 57 * SS
    if ring:
        d.ellipse((c - r_ring, c - r_ring, c + r_ring, c + r_ring), fill=ring)
    d.ellipse((c - r_screen, c - r_screen, c + r_screen, c + r_screen), fill=(0, 0, 0))

    gap_p, dot_p, off_p = (layout_const(n) for n in ("COLON_GAP_PERCENT", "COLON_DOT_PERCENT", "COLON_OFFSET_PERCENT"))
    hour, minute = "10", "08"
    # Pick the font size so the whole time is time_width px wide at 128 px (fits inside the round screen).
    size = 40 * SS
    for _ in range(40):
        font = ImageFont.truetype(BEBAS, size)
        x0, y0, x1, y1 = font.getbbox("0")
        dh = y1 - y0
        total = font.getlength(hour) + font.getlength(minute) + dh * gap_p / 100
        if abs(total - time_width * SS) < SS:
            break
        size = int(size * time_width * SS / total)
    gap, dot, off = dh * gap_p / 100, max(3 * SS, dh * dot_p / 100), dh * off_p / 100
    # Vertical: centre the digit box (cap height of "0") on the screen centre, like the face's time row.
    top = c - dh / 2 - y0
    d.text((c - gap / 2, top), hour, font=font, fill=hour_c, anchor="ra")
    d.text((c + gap / 2, top), minute, font=font, fill=minute_c, anchor="la")
    for cy in (c - off, c + off):
        d.rectangle((c - dot / 2, cy - dot / 2, c + dot / 2 - 1, cy + dot / 2 - 1), fill=colon_c)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def palette64():
    pal = [v for r in LEVELS for g in LEVELS for b in LEVELS for v in (r, g, b)]
    p = Image.new("P", (1, 1))
    p.putpalette(pal + [0] * (768 - len(pal)))
    return p


def main():
    os.makedirs(OUT, exist_ok=True)
    text = layout_const("COLOR_TEXT")
    # 24-bit: slate background (same as the cover), thin grey ring, cyan 0x00D4FF (a face colour option).
    full = render((0x3A, 0x3F, 0x47), (0x4A, 0x50, 0x5A), (255, 255, 255), rgb(0x00D4FF), rgb(text))
    p24 = os.path.join(OUT, "icon_24bit_128.png")
    full.save(p24, "PNG", optimize=True)
    # 64-colour: every colour picked from the palette first (grey 0x555555 background, cyan 0x00AAFF, colon
    # 0xAAAAAA), then the anti-aliased edges are mapped to the nearest palette colour without dithering.
    low = render((0x55, 0x55, 0x55), None, (255, 255, 255), (0x00, 0xAA, 0xFF), (0xAA, 0xAA, 0xAA))
    low = low.quantize(palette=palette64(), dither=Image.Dither.NONE)
    used = sorted({c for _, c in low.getcolors(256)})
    p64 = os.path.join(OUT, "icon_64color_128.png")
    low.save(p64, "PNG", optimize=True, bits=8)
    for p in (p24, p64):
        im = Image.open(p)
        print(f"{p}: {im.size[0]}x{im.size[1]} mode={im.mode} {os.path.getsize(p)} bytes")
    print(f"64-colour icon uses {len(used)} palette entries, all from the 4-level-per-channel palette")


if __name__ == "__main__":
    main()
