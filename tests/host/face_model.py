"""Host-side model of the Noir Time watch face (no Connect IQ SDK / device files needed).

* A line-by-line Python port of the pure functions in source/NoirLayout.mc (constants are read from that file,
  so the port cannot silently drift).
* A renderer that draws the face like NoirTimeView.onUpdate() does, with STAND-IN fonts: Rajdhani Medium and
  Roboto Regular - the families/files the fēnix 9 Pro 47mm device reference lists for FONT_NUMBER_* and
  FONT_SMALL/FONT_LARGE - from Google Fonts (OFL, in tests/host/fonts). Garmin's own rasteriser and font files
  are inside the login-gated device files, so pixel numbers from this model are ESTIMATES, not measurements.

Font-size mapping: the device reference gives one "Font Size" per font. It is not documented whether that is the
line height or the glyph height, so two mappings are modelled:
  "line"  - size = ascent + descent (as Dc.getFontHeight would report a normal font)  -> smaller glyphs
  "digit" - size = height of the digit "0" (number fonts cropped to the digits)        -> larger glyphs (worst case)
"""
import os
import re

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONT_DIR = os.path.join(os.path.dirname(__file__), "fonts")
RAJDHANI = os.path.join(FONT_DIR, "Rajdhani-Medium.ttf")
ROBOTO = os.path.join(FONT_DIR, "Roboto-VariableFont_wdth,wght.ttf")
# Font-accurate mode: CIQ_DEVICE_FONTS=~/.Garmin/ConnectIQ/Fonts (downloaded by the SDK manager with
# "device download --include-fonts"; Garmin files, never committed). The device's simulator.json maps
# numberMild/Medium/Hot/ThaiHot to Bionic_Medium.ttf and small/large to Roboto-Regular.ttf.
DEVICE_FONTS = os.environ.get("CIQ_DEVICE_FONTS")
if DEVICE_FONTS and os.path.exists(os.path.join(os.path.expanduser(DEVICE_FONTS), "Bionic_Medium.ttf")):
    RAJDHANI = os.path.join(os.path.expanduser(DEVICE_FONTS), "Bionic_Medium.ttf")
    ROBOTO = os.path.join(os.path.expanduser(DEVICE_FONTS), "Roboto-Regular.ttf")
    CONDENSED = os.path.join(os.path.expanduser(DEVICE_FONTS), "RobotoCondensed-Regular.ttf")
    FONT_SOURCE = "device fonts (Bionic_Medium / Roboto-Regular / RobotoCondensed-Regular from the SDK manager)"
else:
    CONDENSED = ROBOTO  # stand-in: Roboto variable font at width 75 (condensed)
    DEVICE_FONTS = None
    FONT_SOURCE = "stand-in fonts (Rajdhani Medium / Roboto, Google Fonts)"

SCREEN = 454  # fēnix 9 Pro 47mm, device reference

# Font heights from the fēnix 9 Pro 47mm device reference (fenix9pro47mm).
FONTS = {
    "FONT_XTINY": ("roboto", 37), "FONT_TINY": ("roboto", 47), "FONT_SMALL": ("roboto", 53), "FONT_LARGE": ("roboto", 71),
    "FONT_NUMBER_MILD": ("rajdhani", 113), "FONT_NUMBER_MEDIUM": ("rajdhani", 153),
    "FONT_NUMBER_HOT": ("rajdhani", 173), "FONT_NUMBER_THAI_HOT": ("rajdhani", 210),
}


def _mc_constants(path):
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    consts = {}
    for name, value in re.findall(r"const (\w+) = ([^;]+);", text):
        value = value.strip()
        if re.fullmatch(r"0x[0-9A-Fa-f]+|-?\d+", value):
            consts[name] = int(value, 0)
        elif value.startswith('"'):
            consts[name] = value.strip('"')
        elif value.startswith("["):
            consts[name] = [int(v) for v in re.findall(r"-?\d+", value.split(" as ")[0])]
    return consts


L = _mc_constants(os.path.join(ROOT, "source", "NoirLayout.mc"))
S = _mc_constants(os.path.join(ROOT, "source", "NoirSettings.mc"))

_XL = ["FONT_NUMBER_THAI_HOT", "FONT_NUMBER_HOT", "FONT_NUMBER_MEDIUM", "FONT_NUMBER_MILD"]
FONT_CANDIDATES = {
    S["SIZE_SMALL"]: ["FONT_NUMBER_MILD", "FONT_LARGE"],
    S["SIZE_MEDIUM"]: ["FONT_NUMBER_MEDIUM", "FONT_NUMBER_MILD"],
    S["SIZE_LARGE"]: ["FONT_NUMBER_HOT", "FONT_NUMBER_MEDIUM", "FONT_NUMBER_MILD"],
    S["SIZE_XLARGE"]: _XL,
    S["SIZE_XXLARGE"]: _XL,   # fallback only; XX-Large uses the scalable condensed face
}
SIZES = sorted(FONT_CANDIDATES)
STATS_FONTS = ["FONT_SMALL", "FONT_TINY", "FONT_XTINY"]   # NoirLayout.statsFontCandidates()


def color_values():
    """NoirSettings.colorValues() read from the Monkey C source (16 palette colours, Number 0xRRGGBB)."""
    with open(os.path.join(ROOT, "source", "NoirSettings.mc"), encoding="utf-8") as fh:
        body = re.search(r"function colorValues\(\).*?\[(.*?)\]", fh.read(), re.S).group(1)
    return [int(v, 16) for v in body.split(",")]


SIZE_NAMES = {S["SIZE_SMALL"]: "small", S["SIZE_MEDIUM"]: "medium", S["SIZE_LARGE"]: "large",
              S["SIZE_XLARGE"]: "xlarge", S["SIZE_XXLARGE"]: "xxlarge"}


def mc_div(a, b):
    """Monkey C integer division truncates toward zero."""
    q = abs(a) // abs(b)
    return q if (a >= 0) == (b > 0) else -q


# ---- port of NoirLayout.mc -------------------------------------------------------------------
def row_spacing(h):
    return mc_div(h * L["ROW_SPACING_PERCENT"], 100)


def colon_radius(fh):
    return max(3, mc_div(fh, 26))


def colon_gap(fh):
    return colon_radius(fh) * 6


def colon_dot_offset(fh):
    return mc_div(fh * 14, 100)


def outline_width(fh):
    return min(L["OUTLINE_MAX"], max(L["OUTLINE_MIN"], mc_div(fh, 64)))


def inside_circle(radius, half_w, dy):
    return half_w * half_w + dy * dy <= radius * radius


def digit_half_height(fh, percent):
    return mc_div(fh * percent + 99, 100)


def block_fits(screen, th, digit_half, digits_w, date_h, date_w, stats_h, stats_w, pad):
    radius = mc_div(screen, 2) - L["EDGE_MARGIN"]
    sp = row_spacing(screen)
    half_w = mc_div(digits_w * 2 + colon_gap(th), 2) + pad
    half_h = digit_half + pad
    return (inside_circle(radius, half_w, half_h)
            and inside_circle(radius, mc_div(date_w, 2), mc_div(th, 2) + sp + date_h)
            and (stats_w <= 0 or inside_circle(radius, mc_div(stats_w, 2), mc_div(th, 2) + sp + stats_h)))


def icon_height(fh):
    return mc_div(fh * L["ICON_HEIGHT_PERCENT"], 100)


def steps_icon_width(fh):
    return mc_div(icon_height(fh) * L["STEPS_ICON_WIDTH_PERCENT"], 100)


def body_battery_icon_width(fh):
    return mc_div(icon_height(fh) * L["BODY_BATTERY_ICON_WIDTH_PERCENT"], 100)


def icon_gap(fh):
    return mc_div(fh * L["ICON_GAP_PERCENT"], 100)


def group_gap(fh):
    return mc_div(fh * L["GROUP_GAP_PERCENT"], 100)


def stats_row_width(fh, show_steps, steps_w, show_bb, bb_w):
    w = 0
    if show_steps:
        w += steps_icon_width(fh) + icon_gap(fh) + steps_w
    if show_bb:
        if show_steps:
            w += group_gap(fh)
        w += body_battery_icon_width(fh) + icon_gap(fh) + bb_w
    return w


def parse_body_battery(v):
    if v is None:
        return None
    level = int(v + 0.5) if isinstance(v, float) else v
    return level if 0 <= level <= 100 else None


def format_body_battery(level):
    return "--" if level is None else str(level)


def aod_shift(minute):
    p = minute % 4
    s = L["AOD_SHIFT_PIXELS"]
    return (-s if p in (0, 3) else s, -s if p < 2 else s)


def mask_first_row(top, minute):
    p = L["AOD_MASK_PERIOD"]
    row = top
    while row % p != minute % p:
        row += 1
    return row


def colon_color(hour_c, minute_c):
    return hour_c if hour_c == minute_c else L["COLOR_TEXT"]


def format_hour(hour, is24):
    if is24:
        return "%02d" % hour
    h = hour % 12
    return str(12 if h == 0 else h)


def format_steps(steps):
    if steps is None:
        return "--"
    return "{:,}".format(steps)


# ---- stand-in fonts ------------------------------------------------------------------------
class Font:
    def __init__(self, name, mapping):
        if name.startswith("VECTOR_"):   # Graphics.getVectorFont({:face => RobotoCondensedRegular, :size => px})
            family, height = "condensed", int(name.split("_")[1])
            mapping = "line"  # measured in the simulator: getFontHeight == requested px, "00" width as in the TTF
        else:
            family, height = FONTS[name]
        self.name, self.height, self.family, self.mapping = name, height, family, mapping
        path = {"rajdhani": RAJDHANI, "roboto": ROBOTO, "condensed": CONDENSED}[family]
        self.condensed = family == "condensed"
        probe = self._load(path, 1000)
        if mapping == "digit" and family == "rajdhani":
            box = probe.getbbox("0", anchor="ls")
            em = 1000 * height / (box[3] - box[1])
        else:
            asc, desc = probe.getmetrics()
            em = 1000 * height / (asc + desc)
        self.font = self._load(path, max(1, round(em)))

    def _load(self, path, size):
        f = ImageFont.truetype(path, size)
        if path == ROBOTO and not DEVICE_FONTS:
            if self.condensed:
                f.set_variation_by_axes([75, 400])
            else:
                f.set_variation_by_name("Regular")
        return f

    def width(self, text):
        return int(round(self.font.getlength(text)))

    def draw(self, d, x, y, text, justify, fill):
        """Dc.drawText with TEXT_JUSTIFY_{LEFT,RIGHT,CENTER} | TEXT_JUSTIFY_VCENTER."""
        w = self.font.getlength(text)
        left = {"left": x, "right": x - w, "center": x - w / 2}[justify]
        if self.mapping == "digit" and self.family == "rajdhani":
            d.text((left, y + self.height / 2), text, font=self.font, fill=fill, anchor="ls")
        else:
            d.text((left, y), text, font=self.font, fill=fill, anchor="lm")


def stats_width(sf, show_steps=True, show_bb=True):
    return stats_row_width(sf.height, show_steps, sf.width(L["SAMPLE_STEPS"]), show_bb,
                           sf.width(L["SAMPLE_BODY_BATTERY"]))


def fits(f, small, percent, stats=None, show_steps=True, show_bb=True):
    """Port of NoirTimeView.fits(); stats = stats-row font (default: the smallest candidate, as the time font search)."""
    stats = stats or small
    return block_fits(SCREEN, f.height, digit_half_height(f.height, percent), f.width("00"), small.height,
                      small.width(L["SAMPLE_DATE"]), stats.height, stats_width(stats, show_steps, show_bb),
                      outline_width(f.height))


def choose_time_font(size, mapping, show_steps=True, show_bb=True):
    """Port of NoirTimeView.updateLayout() / chooseVectorFont(): first time candidate that fits (against the smallest
    stats font), then the largest stats font that fits. Returns (time font, date font, stats font)."""
    small = Font("FONT_SMALL", mapping)
    smallest = Font(STATS_FONTS[-1], mapping)
    chosen = None
    if size == S["SIZE_XXLARGE"]:
        for px in range(L["XXL_SIZE_MAX"], L["XXL_SIZE_MIN"] - 1, -L["XXL_SIZE_STEP"]):
            f = Font("VECTOR_%d" % px, mapping)
            if fits(f, small, L["DIGIT_HALF_PERCENT_CONDENSED"], smallest, show_steps, show_bb):
                chosen = f
                break
    if chosen is None:
        cands = FONT_CANDIDATES[size]
        chosen = Font(cands[-1], mapping)
        for name in cands:
            f = Font(name, mapping)
            if fits(f, small, L["DIGIT_HALF_PERCENT_NUMBER"], smallest, show_steps, show_bb):
                chosen = f
                break
    pct = L["DIGIT_HALF_PERCENT_CONDENSED" if chosen.condensed else "DIGIT_HALF_PERCENT_NUMBER"]
    stats = smallest
    for name in STATS_FONTS:
        sf = Font(name, mapping)
        if fits(chosen, small, pct, sf, show_steps, show_bb):
            stats = sf
            break
    return chosen, small, stats


def rgb(c):
    return ((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF)


def draw_steps_icon(d, x, top, w, h, fill):
    """NoirTimeView.drawStepsIcon: two shoe prints (forefoot + heel ellipses), left one higher."""
    pr = mc_div(h * 84, 100)
    fore_rx, heel_rx = mc_div(w * 22, 100), mc_div(w * 17, 100)
    fore_ry, heel_ry = mc_div(pr * 31, 100), mc_div(pr * 20, 100)
    for i in range(2):
        cx = x + (mc_div(w * 24, 100) if i == 0 else mc_div(w * 76, 100))
        py = top + (0 if i == 0 else h - pr)
        for ey, rx, ry in ((py + fore_ry, fore_rx, fore_ry), (py + pr - heel_ry, heel_rx, heel_ry)):
            d.ellipse((cx - rx, ey - ry, cx + rx, ey + ry), fill=fill)


def draw_body_battery_icon(d, x, top, w, h, fill):
    """NoirTimeView.drawBodyBatteryIcon (D-34): figure with raised arms inside a gauge ring open at the bottom."""
    s = min(w, h)
    left, y0 = x + mc_div(w - s, 2), top + mc_div(h - s, 2)
    pen = max(2, mc_div(s, 10))
    cx, cy = left + mc_div(s, 2), y0 + mc_div(s, 2)
    r = mc_div(s, 2) - mc_div(pen + 1, 2)
    # Garmin angles are counter-clockwise from 3 o'clock; PIL's are clockwise. Garmin 300 -> 240 CCW == PIL 120 -> 420.
    d.arc((cx - r - mc_div(pen, 2), cy - r - mc_div(pen, 2), cx + r + mc_div(pen, 2), cy + r + mc_div(pen, 2)),
          start=120, end=420, fill=fill, width=pen)
    hr = max(1, mc_div(s * 11, 100))
    hy = y0 + mc_div(s * 30, 100)
    d.ellipse((cx - hr, hy - hr, cx + hr, hy + hr), fill=fill)
    pts = [(20, 36), (29, 29), (42, 47), (58, 47), (71, 29), (80, 36), (61, 58), (61, 96), (39, 96), (39, 58)]
    d.polygon([(left + mc_div(s * a, 100), y0 + mc_div(s * b, 100)) for a, b in pts], fill=fill)


def render(size, hour_color, minute_color, low_power, hour=10, minute=8, steps=8432, date="Fri 23 Oct",
           is24=True, mapping="line", fonts=None, body_battery=76, show_steps=True, show_bb=True):
    # mask=False is not offered on purpose: the model always draws exactly what the watch draws.
    """Returns an RGB numpy array (SCREEN x SCREEN x 3) drawn like NoirTimeView.onUpdate()."""
    tf, sf, stf = fonts if fonts else choose_time_font(size, mapping, show_steps, show_bb)
    im = Image.new("RGB", (SCREEN, SCREEN), (0, 0, 0))
    d = ImageDraw.Draw(im)
    th, sh = tf.height, sf.height
    cx = cy = SCREEN // 2
    text_c = L["COLOR_TEXT"]
    colon_c = colon_color(hour_color, minute_color)
    if low_power:
        dx, dy = aod_shift(minute)
        cx, cy = cx + dx, cy + dy
        text_c = L["COLOR_TEXT_AOD"]
    gap, r, off, ow = colon_gap(th), colon_radius(th), colon_dot_offset(th), outline_width(th)
    hx, mx = cx - mc_div(gap, 2), cx + mc_div(gap, 2)
    ht, mt = format_hour(hour, is24), "%02d" % minute
    if low_power:
        for x, t, j, c in ((hx, ht, "right", hour_color), (mx, mt, "left", minute_color)):
            for ddx, ddy in zip(L["OUTLINE_DX"], L["OUTLINE_DY"]):
                tf.draw(d, x + ddx * ow, cy + ddy * ow, t, j, rgb(c))
            tf.draw(d, x, cy, t, j, (0, 0, 0))
        for yy in (cy - off, cy + off):  # Dc.drawCircle with pen width ow (pen centred on the radius)
            d.ellipse((cx - r - ow / 2, yy - r - ow / 2, cx + r + ow / 2, yy + r + ow / 2), outline=rgb(colon_c),
                      width=ow)
    else:
        tf.draw(d, hx, cy, ht, "right", rgb(hour_color))
        tf.draw(d, mx, cy, mt, "left", rgb(minute_color))
        for yy in (cy - off, cy + off):
            d.ellipse((cx - r, yy - r, cx + r, yy + r), fill=rgb(colon_c))
    row = mc_div(th, 2) + row_spacing(SCREEN) + mc_div(sh, 2)
    sf.draw(d, cx, cy - row, date, "center", rgb(text_c))
    if show_steps or show_bb:   # NoirTimeView.drawStatsRow
        h = stf.height
        y = cy + mc_div(th, 2) + row_spacing(SCREEN) + mc_div(h, 2)
        st, bt = format_steps(steps), format_body_battery(body_battery)
        total = stats_row_width(h, show_steps, stf.width(st), show_bb, stf.width(bt))
        x = cx - mc_div(total, 2)
        ih = icon_height(h)
        itop = y - mc_div(ih, 2)
        if show_steps:
            w = steps_icon_width(h)
            draw_steps_icon(d, x, itop, w, ih, rgb(text_c))
            x += w + icon_gap(h)
            stf.draw(d, x, y, st, "left", rgb(text_c))
            x += stf.width(st) + group_gap(h)
        if show_bb:
            w = body_battery_icon_width(h)
            draw_body_battery_icon(d, x, itop, w, ih, rgb(text_c))
            stf.draw(d, x + w + icon_gap(h), y, bt, "left", rgb(text_c))
    arr = np.asarray(im).copy()
    if low_power:  # NoirTimeView.drawRowMask()
        for y in range(mask_first_row(0, minute), SCREEN, L["AOD_MASK_PERIOD"]):
            arr[y, :, :] = 0
    yy, xx = np.ogrid[:SCREEN, :SCREEN]
    outside = (xx - SCREEN / 2 + 0.5) ** 2 + (yy - SCREEN / 2 + 0.5) ** 2 > (SCREEN / 2) ** 2
    arr[outside] = 0  # round screen
    return arr


def screen_pixels():
    yy, xx = np.ogrid[:SCREEN, :SCREEN]
    return int(((xx - SCREEN / 2 + 0.5) ** 2 + (yy - SCREEN / 2 + 0.5) ** 2 <= (SCREEN / 2) ** 2).sum())


def lit_fraction(arr):
    """'a pixel is considered on when rendering any color other than black' (AMOLED FAQ); share of ALL
    454x454 pixels (the rule says 'screen pixels'), and of the round visible area."""
    lit = int((arr.max(axis=2) > 0).sum())
    return lit / (SCREEN * SCREEN), lit / screen_pixels()


def luminance_fraction(arr):
    """Mean relative luminance (Rec. 709 weights) of the visible area, 0..1 (Venu 2+ '10 % luminance' rule)."""
    y = (0.2126 * arr[..., 0] + 0.7152 * arr[..., 1] + 0.0722 * arr[..., 2]) / 255.0
    return float(y.sum() / screen_pixels())


def burn_in_run(size, hour_color, minute_color, start_minute, minutes, mapping="line", steps=8432, body_battery=76):
    """Simulates `minutes` consecutive always-on updates (one per minute, as documented for low power) and
    returns (max lit fraction, max luminance fraction, longest run of consecutive minutes any pixel stayed on)."""
    fonts = choose_time_font(size, mapping)
    run = np.zeros((SCREEN, SCREEN), dtype=np.int32)
    longest, max_lit, max_lum = 0, 0.0, 0.0
    for i in range(minutes):
        t = (start_minute + i) % 1440
        arr = render(size, hour_color, minute_color, True, hour=t // 60, minute=t % 60, steps=steps,
                     mapping=mapping, fonts=fonts, body_battery=body_battery)
        on = arr.max(axis=2) > 0
        run = np.where(on, run + 1, 0)
        longest = max(longest, int(run.max()))
        max_lit = max(max_lit, lit_fraction(arr)[0])
        max_lum = max(max_lum, luminance_fraction(arr))
    return max_lit, max_lum, longest
