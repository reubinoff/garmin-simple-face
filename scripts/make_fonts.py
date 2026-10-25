#!/usr/bin/env python3
"""Generates the Bebas Neue time-digit bitmap fonts (DECISIONS.md D-38).

Connect IQ reads custom fonts as BMFont files (text .fnt descriptor + PNG page), declared with a <font> resource
("Resources" -> "Fonts", https://developer.garmin.com/connect-iq/core-topics/resources/). BMFont itself is a Windows
program, so this script writes the same text format with Garmin's recommended export options (padding 0, spacing 1,
8-bit texture whose single channel is the glyph, text descriptor, PNG), rasterised with FreeType (Pillow).

One folder per round screen resolution (family qualifier resources-round-WxH, "Build Configuration"), five fonts per
folder: TimeFont0..TimeFont4 = Small..XX-Large. Only the digits 0-9 are included (the colon is drawn as two squares).
The digit height of XX-Large is the largest that fits "00:00" inside the round screen (same formula as
NoirLayout.blockFits); the smaller sizes are fixed fractions of it.

    python3 scripts/make_fonts.py          # rewrites resources-round-*/fonts/
"""
from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TTF = os.path.join(ROOT, "assets", "fonts", "BebasNeue", "BebasNeue-Regular.ttf")
# Every round resolution in manifest.xml (D-36).
RESOLUTIONS = [208, 218, 240, 260, 280, 360, 390, 416, 454, 466]
# Small, Medium, Large, X-Large, XX-Large as percent of the largest digit height that fits.
SIZE_PERCENT = [56, 68, 80, 90, 100]
# Must match NoirLayout: EDGE_MARGIN, OUTLINE_MAX, COLON_GAP_PERCENT, and the time width model below.
EDGE_MARGIN = 12
OUTLINE_MAX = 3
COLON_GAP_PERCENT = 27
CHARS = "0123456789"
TEXTURE_WIDTH = 512


def _measure(font: ImageFont.FreeTypeFont) -> tuple[float, int]:
    """(digit advance / digit height, digit height) for a font."""
    top, bottom = 10**6, -(10**6)
    for ch in CHARS:
        box = _ink(font, ch)[1]
        top, bottom = min(top, box[1]), max(bottom, box[3])
    height = bottom - top + 1
    return font.getlength("0") / height, height


def _ink(font: ImageFont.FreeTypeFont, ch: str) -> tuple[np.ndarray, tuple[int, int, int, int]]:
    """Glyph coverage (uint8) and its ink box (x0, y0, x1, y1) relative to the pen origin on the baseline."""
    size = font.size
    canvas = Image.new("L", (size * 2, size * 2))
    origin = (size // 2, size * 3 // 2)
    ImageDraw.Draw(canvas).text(origin, ch, font=font, fill=255, anchor="ls")
    pixels = np.array(canvas)
    ys, xs = np.nonzero(pixels)
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
    return pixels[y0:y1 + 1, x0:x1 + 1], (x0 - origin[0], y0 - origin[1], x1 - origin[0], y1 - origin[1])


def font_for_digit_height(target: int) -> ImageFont.FreeTypeFont:
    """Pixel size whose digit height is closest to target (searched, FreeType hinting makes it non-linear)."""
    best = None
    guess = round(target / 0.71)
    for px in range(max(8, guess - 6), guess + 7):
        font = ImageFont.truetype(TTF, px)
        diff = abs(_measure(font)[1] - target)
        if best is None or diff < best[0]:
            best = (diff, font)
    assert best is not None
    return best[1]


def max_digit_height(screen: int, ratio: float) -> int:
    """Largest digit height H with the "00:00" box (half width 2*adv + gap/2 + pad, half height H/2 + pad)
    inside the circle of radius screen/2 - EDGE_MARGIN."""
    radius = screen // 2 - EDGE_MARGIN
    h = 1
    while True:
        nxt = h + 1
        half_w = 2 * ratio * nxt + nxt * COLON_GAP_PERCENT / 200 + OUTLINE_MAX
        half_h = nxt / 2 + OUTLINE_MAX
        if math.hypot(half_w, half_h) > radius:
            return h
        h = nxt


def write_font(folder: str, name: str, font: ImageFont.FreeTypeFont) -> tuple[int, int]:
    glyphs = {ch: _ink(font, ch) for ch in CHARS}
    top = min(box[1] for _, box in glyphs.values())
    bottom = max(box[3] for _, box in glyphs.values())
    line_height = bottom - top + 3          # 1 px above, 1 px below the digits (+1 inclusive)
    base = -top + 1                          # baseline from the top of the line
    # Shelf packing, spacing 1 px.
    x = y = 0
    shelf = 0
    places = {}
    for ch in CHARS:
        w, h = glyphs[ch][0].shape[1], glyphs[ch][0].shape[0]
        if x + w > TEXTURE_WIDTH:
            x, y, shelf = 0, y + shelf + 1, 0
        places[ch] = (x, y)
        x += w + 1
        shelf = max(shelf, h)
    tex_h = y + shelf
    tex_w = min(TEXTURE_WIDTH, max(places[c][0] + glyphs[c][0].shape[1] for c in CHARS))
    page = Image.new("L", (tex_w, tex_h))
    lines = []
    for ch in CHARS:
        pix, box = glyphs[ch]
        px, py = places[ch]
        page.paste(Image.fromarray(pix), (px, py))
        lines.append(
            f"char id={ord(ch)} x={px} y={py} width={pix.shape[1]} height={pix.shape[0]} xoffset={box[0]} "
            f"yoffset={box[1] + base} xadvance={round(font.getlength(ch))} page=0 chnl=15"
        )
    png = f"{name}.png"
    page.save(os.path.join(folder, png), optimize=True)
    header = [
        (f'info face="Bebas Neue" size={font.size} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 '
        "padding=0,0,0,0 spacing=1,1 outline=0"),
        (f"common lineHeight={line_height} base={base} scaleW={tex_w} scaleH={tex_h} pages=1 packed=0 "
        "alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4"),
        f'page id=0 file="{png}"',
        f"chars count={len(CHARS)}",
    ]
    with open(os.path.join(folder, f"{name}.fnt"), "w", encoding="ascii", newline="\n") as fh:
        fh.write("\n".join(header + lines + ["kernings count=0", ""]))
    return line_height, tex_w * tex_h


def main() -> None:
    ratio = _measure(ImageFont.truetype(TTF, 200))[0]
    summary = []
    for screen in RESOLUTIONS:
        folder = os.path.join(ROOT, f"resources-round-{screen}x{screen}", "fonts")
        os.makedirs(folder, exist_ok=True)
        hmax = max_digit_height(screen, ratio)
        entries = []
        for i, percent in enumerate(SIZE_PERCENT):
            font = font_for_digit_height(hmax * percent // 100)
            line_height, area = write_font(folder, f"time{i}", font)
            entries.append(f'    <font id="TimeFont{i}" filename="time{i}.fnt" filter="{CHARS}" antialias="true" />')
            summary.append((screen, i, _measure(font)[1], line_height, area))
        xml = (
            '<fonts xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
            'xsi:noNamespaceSchemaLocation="https://developer.garmin.com/downloads/connect-iq/resources.xsd">\n'
            f"    <!-- Bebas Neue (SIL OFL 1.1, assets/fonts/BebasNeue/OFL.txt), digits only, generated by "
            f"scripts/make_fonts.py for {screen} x {screen} round screens (DECISIONS.md D-38). -->\n"
            + "\n".join(entries) + "\n</fonts>\n"
        )
        with open(os.path.join(folder, "fonts.xml"), "w", encoding="utf-8") as fh:
            fh.write(xml)
    for screen, i, digit, line, area in summary:
        print(f"{screen:4d} size {i}: digit {digit:3d} px, line {line:3d} px, texture {area} px")


if __name__ == "__main__":
    main()
