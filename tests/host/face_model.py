"""Host-side model of the Clean Air watch face (no Connect IQ SDK / device files needed).

* A line-by-line Python port of the pure functions in source/NoirLayout.mc and the field helpers in
  source/NoirFields.mc (constants are read from those files, so the port cannot silently drift).
* A renderer that draws the face like NoirTimeView.onUpdate() does, for the fenix 9 Pro 47mm (454 x 454):
  - time digits: the REAL embedded Bebas Neue bitmap fonts (resources-round-454x454/fonts/time*.fnt / .png, D-38),
    drawn glyph by glyph from the BMFont page like the device does;
  - date and fields: RobotoCondensedRegular at the requested pixel size (D-40). With CIQ_DEVICE_FONTS pointing at
    the fonts the SDK manager downloads, the device's own RobotoCondensed-Regular.ttf is used; otherwise the OFL
    Roboto variable font at width 75 stands in (tests/host/fonts), so those pixel numbers are ESTIMATES.
"""
import os
import re

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONT_DIR = os.path.join(os.path.dirname(__file__), "fonts")
ROBOTO = os.path.join(FONT_DIR, "Roboto-VariableFont_wdth,wght.ttf")
DEVICE_FONTS = os.environ.get("CIQ_DEVICE_FONTS")
if DEVICE_FONTS and os.path.exists(os.path.join(os.path.expanduser(DEVICE_FONTS), "RobotoCondensed-Regular.ttf")):
    CONDENSED = os.path.join(os.path.expanduser(DEVICE_FONTS), "RobotoCondensed-Regular.ttf")
    FONT_SOURCE = "embedded Bebas Neue time fonts + device RobotoCondensed-Regular (SDK manager)"
else:
    CONDENSED = ROBOTO
    DEVICE_FONTS = None
    FONT_SOURCE = "embedded Bebas Neue time fonts + stand-in Roboto (width 75) for the date / fields"

SCREEN = 454  # fēnix 9 Pro 47mm, device reference


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
F = _mc_constants(os.path.join(ROOT, "source", "NoirFields.mc"))
SIZES = [S["SIZE_SMALL"], S["SIZE_MEDIUM"], S["SIZE_LARGE"], S["SIZE_XLARGE"], S["SIZE_XXLARGE"]]
SIZE_NAMES = {S["SIZE_SMALL"]: "small", S["SIZE_MEDIUM"]: "medium", S["SIZE_LARGE"]: "large",
              S["SIZE_XLARGE"]: "xlarge", S["SIZE_XXLARGE"]: "xxlarge"}


def color_values():
    """NoirSettings.colorValues() read from the Monkey C source (16 palette colours, Number 0xRRGGBB)."""
    with open(os.path.join(ROOT, "source", "NoirSettings.mc"), encoding="utf-8") as fh:
        body = re.search(r"function colorValues\(\).*?\[(.*?)\]", fh.read(), re.DOTALL).group(1)
    return [int(v, 16) for v in body.split(",")]


def mc_div(a, b):
    """Monkey C integer division truncates toward zero."""
    q = abs(a) // abs(b)
    return q if (a >= 0) == (b > 0) else -q


# ---- port of NoirLayout.mc -------------------------------------------------------------------
def time_font_order(size):
    return list(range(size, -1, -1))


def digit_height(line):
    return line - L["TIME_LINE_EXTRA"]


def colon_gap(dh):
    return mc_div(dh * L["COLON_GAP_PERCENT"], 100)


def colon_dot(dh):
    return max(3, mc_div(dh * L["COLON_DOT_PERCENT"], 100))


def colon_offset(dh):
    return mc_div(dh * L["COLON_OFFSET_PERCENT"], 100)


def time_width(pair_w, dh):
    return pair_w * 2 + colon_gap(dh)


def date_vector_size(w):
    return mc_div(w * L["DATE_SIZE_PERCENT"], 100)


def row_vector_sizes(w):
    return [mc_div(w * p, 100) for p in L["ROW_SIZE_PERCENTS"]]


def icon_height(fh):
    return mc_div(fh * L["ICON_HEIGHT_PERCENT"], 100)


def icon_width_percent(field):
    if field == F["STEPS"]:
        return 84
    if field in (F["HEART_RATE"], F["NOTIFICATIONS"], F["STRESS"]):
        return 110
    if field in (F["BATTERY"], F["BATTERY_DAYS"]):
        return 150
    if field in (F["CALORIES"], F["INTENSITY"], F["DISTANCE"]):
        return 70
    if field == F["TEMPERATURE"]:
        return 50
    return 100


def icon_width(field, fh):
    return mc_div(icon_height(fh) * icon_width_percent(field), 100)


def icon_gap(fh):
    return mc_div(fh * L["ICON_GAP_PERCENT"], 100)


def group_gap(fh):
    return mc_div(fh * L["GROUP_GAP_PERCENT"], 100)


def field_width(field, fh, text_w):
    return 0 if field == F["NONE"] else icon_width(field, fh) + icon_gap(fh) + text_w


def row_width(fh, left_w, right_w):
    return left_w + group_gap(fh) + right_w if left_w > 0 and right_w > 0 else left_w + right_w


def parse_level(v):
    if v is None:
        return None
    level = int(v + 0.5) if isinstance(v, float) else v
    return level if 0 <= level <= 100 else None


def row_spacing(h):
    return mc_div(h * L["ROW_SPACING_PERCENT"], 100)


def outline_width(line):
    return min(L["OUTLINE_MAX"], max(L["OUTLINE_MIN"], mc_div(line, 64)))


def inside_circle(radius, half_w, dy):
    return half_w * half_w + dy * dy <= radius * radius


def block_shift(second_row, row_h, spacing):
    return mc_div(row_h + spacing, 2) if second_row else 0


def block_fits(screen, time_line, time_w, pad, date_h, date_w, row_h, row1_w, row2_w):
    radius = mc_div(screen, 2) - L["EDGE_MARGIN"]
    sp = row_spacing(screen)
    shift = block_shift(row2_w > 0, row_h, sp)
    half = mc_div(time_line, 2)
    row1_bottom = half + sp + row_h - shift
    return (inside_circle(radius, mc_div(time_w, 2) + pad, half + pad + shift)
            and inside_circle(radius, mc_div(date_w, 2), shift + half + sp + date_h)
            and (row1_w <= 0 or inside_circle(radius, mc_div(row1_w, 2), row1_bottom))
            and (row2_w <= 0 or inside_circle(radius, mc_div(row2_w, 2), row1_bottom + sp + row_h)))


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
        return f"{hour:02d}"
    h = hour % 12
    return str(12 if h == 0 else h)


# ---- port of NoirFields.mc / NoirFormat ------------------------------------------------------
NO_VALUE = "--"


def number(v):
    return NO_VALUE if v is None else str(v)


def thousands(v):
    return NO_VALUE if v is None else f"{v:,}"


def percent(v):
    return NO_VALUE if v is None else f"{int(v + 0.5)}%"


def days(v):
    return NO_VALUE if v is None else f"{int(v)}d"


def temperature(celsius, metric):
    if celsius is None:
        return NO_VALUE
    v = float(celsius) if metric else float(celsius) * 9.0 / 5.0 + 32.0
    r = int(v + 0.5) if v >= 0 else -int(-v + 0.5)
    return f"{r}\u00b0"


def distance(cm, metric):
    if cm is None:
        return NO_VALUE
    tenths = mc_div(cm, 10000 if metric else 16093)
    return f"{mc_div(tenths, 10)}.{tenths % 10}"


def sample_text(field):
    if field in (F["STEPS"], F["CALORIES"]):
        return "88,888"
    if field == F["DISTANCE"]:
        return "88.8"
    if field == F["BATTERY"]:
        return "100%"
    if field == F["BATTERY_DAYS"]:
        return "88d"
    if field == F["TEMPERATURE"]:
        return "-88\u00b0"
    if field == F["INTENSITY"]:
        return "8,888"
    return "" if field == F["NONE"] else "888"


# ---- fonts -----------------------------------------------------------------------------------
class TimeFont:
    """An embedded BMFont (text .fnt + 8-bit PNG) drawn like Dc.drawText draws a custom font."""

    def __init__(self, index, screen=SCREEN):
        folder = os.path.join(ROOT, f"resources-round-{screen}x{screen}", "fonts")
        with open(os.path.join(folder, f"time{index}.fnt"), encoding="ascii") as fh:
            text = fh.read()
        self.name = f"TimeFont{index}"
        self.height = int(re.search(r"lineHeight=(\d+)", text).group(1))
        page = re.search(r'file="([^"]+)"', text).group(1)
        self.page = np.asarray(Image.open(os.path.join(folder, page)).convert("L"))
        self.chars = {}
        for line in text.splitlines():
            if line.startswith("char "):
                kv = dict(re.findall(r"(\w+)=(-?\d+)", line))
                self.chars[chr(int(kv["id"]))] = {k: int(v) for k, v in kv.items()}

    def width(self, text):
        return sum(self.chars[c]["xadvance"] for c in text)

    def draw(self, arr, x, top, text, justify, color):
        """Top-justified (no VCENTER) like NoirTimeView; justify left / right. Alpha-blends onto arr (float RGB)."""
        pen = x - self.width(text) if justify == "right" else x
        for c in text:
            g = self.chars[c]
            cov = self.page[g["y"]:g["y"] + g["height"], g["x"]:g["x"] + g["width"]].astype(float) / 255.0
            gx, gy = pen + g["xoffset"], top + g["yoffset"]
            _blend(arr, gx, gy, cov, color)
            pen += g["xadvance"]


def _blend(arr, x, y, cov, color):
    h, w = cov.shape
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(arr.shape[1], x + w), min(arr.shape[0], y + h)
    if x1 <= x0 or y1 <= y0:
        return
    c = cov[y0 - y:y1 - y, x0 - x:x1 - x][..., None]
    arr[y0:y1, x0:x1] = arr[y0:y1, x0:x1] * (1 - c) + np.array(rgb(color), dtype=float) * c


class TextFont:
    """Graphics.getVectorFont({:face => RobotoCondensedRegular, :size => px}): getFontHeight == px (measured)."""

    def __init__(self, px):
        self.name, self.height = f"ROBOTO_CONDENSED_{px}", px
        probe = self._load(1000)
        asc, desc = probe.getmetrics()
        self.font = self._load(max(1, round(1000 * px / (asc + desc))))

    @staticmethod
    def _load(size):
        f = ImageFont.truetype(CONDENSED, size)
        if CONDENSED == ROBOTO:
            f.set_variation_by_axes([75, 400])
        return f

    def width(self, text):
        return round(self.font.getlength(text))

    def draw(self, d, x, y, text, justify, fill):
        """Dc.drawText with TEXT_JUSTIFY_{LEFT,CENTER} | TEXT_JUSTIFY_VCENTER."""
        w = self.font.getlength(text)
        left = {"left": x, "center": x - w / 2}[justify]
        d.text((left, y), text, font=self.font, fill=fill, anchor="lm")


class Layout:
    def __init__(self, time_font, date_font, row_font, row1, row2):
        self.time_font, self.date_font, self.row_font, self.row1, self.row2 = time_font, date_font, row_font, row1, row2
        self.spacing = row_spacing(SCREEN)
        self.shift = block_shift(bool(row2), row_font.height, self.spacing)


def rows_for(left, right, bottom):
    none = F["NONE"]
    if left == none and right == none:
        return ([] if bottom == none else [bottom]), []
    row1 = [right] if left == none else ([left] if right == none else [left, right])
    return row1, ([] if bottom == none else [bottom])


def _sample_row_width(fields, font):
    widths = [0, 0]
    for i, f in enumerate(fields):
        widths[i] = field_width(f, font.height, font.width(sample_text(f)))
    return row_width(font.height, widths[0], widths[1])


def fits(tf, date_font, row_font, row1, row2):
    """Port of NoirTimeView.fits()."""
    line = tf.height
    return block_fits(SCREEN, line, time_width(tf.width("00"), digit_height(line)), outline_width(line),
                      date_font.height, date_font.width(L["SAMPLE_DATE"]), row_font.height,
                      _sample_row_width(row1, row_font), _sample_row_width(row2, row_font))


def choose_layout(size, left=None, right=None, bottom=None):
    """Port of NoirTimeView.updateLayout(): first time font (selected size, then smaller) that fits against the
    smallest row font, then the largest row font that fits next to it."""
    left = F["STEPS"] if left is None else left
    right = F["BODY_BATTERY"] if right is None else right
    bottom = F["NONE"] if bottom is None else bottom
    row1, row2 = rows_for(left, right, bottom)
    date_font = TextFont(date_vector_size(SCREEN))
    row_fonts = [TextFont(px) for px in row_vector_sizes(SCREEN)]
    smallest = row_fonts[-1]
    tf = None
    for i in time_font_order(size):
        tf = TimeFont(i)
        if fits(tf, date_font, smallest, row1, row2):
            break
    row_font = smallest
    for rf in row_fonts[:-1]:
        if fits(tf, date_font, rf, row1, row2):
            row_font = rf
            break
    return Layout(tf, date_font, row_font, row1, row2)


# ---- renderer --------------------------------------------------------------------------------
def rgb(c):
    return ((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF)


def p(x, a):
    return mc_div(x * a, 100)


def draw_icon(d, field, x, top, w, h, fill):
    """NoirTimeView.drawIcon / drawStepsIcon / drawBodyBatteryIcon / drawBatteryIcon."""
    if field == F["STEPS"]:
        pr = p(h, 84)
        fore_rx, heel_rx, fore_ry, heel_ry = p(w, 22), p(w, 17), p(pr, 31), p(pr, 20)
        for i in range(2):
            cx = x + (p(w, 24) if i == 0 else p(w, 76))
            py = top + (0 if i == 0 else h - pr)
            for ey, rx, ry in ((py + fore_ry, fore_rx, fore_ry), (py + pr - heel_ry, heel_rx, heel_ry)):
                d.ellipse((cx - rx, ey - ry, cx + rx, ey + ry), fill=fill)
    elif field == F["BODY_BATTERY"]:
        s = min(w, h)
        left, y0 = x + mc_div(w - s, 2), top + mc_div(h - s, 2)
        pen = max(2, mc_div(s, 10))
        cx, cy = left + mc_div(s, 2), y0 + mc_div(s, 2)
        r = mc_div(s, 2) - mc_div(pen + 1, 2)
        hp = mc_div(pen, 2)
        d.arc((cx - r - hp, cy - r - hp, cx + r + hp, cy + r + hp), start=120, end=420, fill=fill, width=pen)
        hr = max(1, p(s, 11))
        hy = y0 + p(s, 30)
        d.ellipse((cx - hr, hy - hr, cx + hr, hy + hr), fill=fill)
        pts = [(20, 36), (29, 29), (42, 47), (58, 47), (71, 29), (80, 36), (61, 58), (61, 96), (39, 96), (39, 58)]
        d.polygon([(left + p(s, a), y0 + p(s, b)) for a, b in pts], fill=fill)
    elif field == F["HEART_RATE"]:
        r = p(w, 27)
        d.ellipse((x, top, x + 2 * r, top + 2 * r), fill=fill)
        d.ellipse((x + w - 2 * r, top, x + w, top + 2 * r), fill=fill)
        yb = top + mc_div(r * 13, 10)
        d.polygon([(x + p(w, 2), yb), (x + p(w, 98), yb), (x + mc_div(w, 2), top + h)], fill=fill)
    elif field in (F["BATTERY"], F["BATTERY_DAYS"]):
        bh = p(h, 72)
        y0 = top + mc_div(h - bh, 2)
        bw = p(w, 88)
        pen = max(2, mc_div(bh, 7))
        d.rectangle((x, y0, x + bw - 1, y0 + bh - 1), fill=fill)
        d.rectangle((x + bw, y0 + mc_div(bh, 4), x + w - 1, y0 + bh - mc_div(bh, 4) - 1), fill=fill)
        d.rectangle((x + pen, y0 + pen, x + bw - pen - 1, y0 + bh - pen - 1), fill=(0, 0, 0))
        inset = pen * 2
        if field == F["BATTERY_DAYS"]:
            cell = mc_div(bw - 2 * inset - 2 * pen, 3)
            for i in range(3):
                cx0 = x + inset + i * (cell + pen)
                d.rectangle((cx0, y0 + inset, cx0 + cell - 1, y0 + bh - inset - 1), fill=fill)
        else:
            d.rectangle((x + inset, y0 + inset, x + inset + p(bw - 2 * inset, 65) - 1, y0 + bh - inset - 1), fill=fill)
    elif field == F["CALORIES"]:
        r = mc_div(w, 2)
        cy = top + h - r
        d.ellipse((x, cy - r, x + 2 * r, cy + r), fill=fill)
        d.polygon([(x, cy), (x + p(w, 18), top + p(h, 42)), (x + p(w, 48), top), (x + p(w, 82), top + p(h, 30)),
                   (x + w, cy)], fill=fill)
    elif field == F["FLOORS"]:
        d.polygon([(x, top + h), (x, top + mc_div(h * 2, 3)),
                   (x + mc_div(w, 3), top + mc_div(h * 2, 3)), (x + mc_div(w, 3), top + mc_div(h, 3)),
                   (x + mc_div(w * 2, 3), top + mc_div(h, 3)), (x + mc_div(w * 2, 3), top), (x + w, top),
                   (x + w, top + h)], fill=fill)
    elif field == F["INTENSITY"]:
        d.polygon([(x + p(w, 62), top), (x, top + p(h, 58)), (x + p(w, 44), top + p(h, 58)), (x + p(w, 34), top + h),
                   (x + w, top + p(h, 40)), (x + p(w, 56), top + p(h, 40))], fill=fill)
    elif field == F["NOTIFICATIONS"]:
        bubble = p(h, 76)
        d.rounded_rectangle((x, top, x + w - 1, top + bubble - 1), radius=mc_div(h, 5), fill=fill)
        d.polygon([(x + p(w, 18), top + bubble - 1), (x + p(w, 18), top + h), (x + p(w, 48), top + bubble - 1)],
                  fill=fill)
    elif field == F["STRESS"]:
        pen = max(2, mc_div(h, 7))
        m2 = mc_div(pen, 2)
        xs = [x + m2, x + p(w, 22), x + p(w, 44), x + p(w, 64), x + p(w, 82), x + w - m2]
        ys = [top + mc_div(h, 2), top + m2, top + h - m2, top + p(h, 20), top + p(h, 75), top + mc_div(h, 2)]
        d.line(list(zip(xs, ys)), fill=fill, width=pen)
    elif field == F["TEMPERATURE"]:
        r = mc_div(w, 2)
        q = mc_div(w, 4)
        d.rounded_rectangle((x + q, top, x + w - q - 1, top + h - r - 1), radius=q, fill=fill)
        d.ellipse((x, top + h - 2 * r, x + 2 * r, top + h), fill=fill)
    elif field == F["DISTANCE"]:
        r = mc_div(w, 2)
        d.ellipse((x, top, x + 2 * r, top + 2 * r), fill=fill)
        yb = top + mc_div(r * 13, 10)
        d.polygon([(x + p(w, 4), yb), (x + p(w, 96), yb), (x + r, top + h)], fill=fill)
        hr = mc_div(r * 2, 5)
        d.ellipse((x + r - hr, top + r - hr, x + r + hr, top + r + hr), fill=(0, 0, 0))


DEFAULT_TEXTS = {F["STEPS"]: "8,432", F["BODY_BATTERY"]: "76", F["HEART_RATE"]: "62", F["BATTERY"]: "85%",
                 F["BATTERY_DAYS"]: "12d", F["CALORIES"]: "1,840", F["FLOORS"]: "14", F["INTENSITY"]: "150",
                 F["NOTIFICATIONS"]: "3", F["STRESS"]: "28", F["TEMPERATURE"]: "18\u00b0", F["DISTANCE"]: "6.4"}


def render(size, hour_color, minute_color, low_power, hour=10, minute=8, date="FRI 23 OCT", is24=True,
           layout=None, texts=None, left=None, right=None, bottom=None):
    """Returns an RGB numpy array (SCREEN x SCREEN x 3) drawn like NoirTimeView.onUpdate()."""
    lay = layout or choose_layout(size, left, right, bottom)
    texts = texts or DEFAULT_TEXTS
    tf, df, rf = lay.time_font, lay.date_font, lay.row_font
    arr = np.zeros((SCREEN, SCREEN, 3), dtype=float)
    cx = SCREEN // 2
    cy = SCREEN // 2 - lay.shift
    text_c = L["COLOR_TEXT"]
    colon_c = colon_color(hour_color, minute_color)
    if low_power:
        dx, dy = aod_shift(minute)
        cx, cy = cx + dx, cy + dy
        text_c = L["COLOR_TEXT_AOD"]
    line = tf.height
    dh = digit_height(line)
    gap, dot, off, ow = colon_gap(dh), colon_dot(dh), colon_offset(dh), outline_width(line)
    top = cy - mc_div(line, 2)
    hx, mx = cx - mc_div(gap, 2), cx + mc_div(gap, 2)
    dot_x = cx - mc_div(dot, 2)
    dot_ys = (cy - off - mc_div(dot, 2), cy + off - mc_div(dot, 2))
    ht, mt = format_hour(hour, is24), f"{minute:02d}"
    if low_power:
        for x, t, j, c in ((hx, ht, "right", hour_color), (mx, mt, "left", minute_color)):
            for ddx, ddy in zip(L["OUTLINE_DX"], L["OUTLINE_DY"]):
                tf.draw(arr, x + ddx * ow, top + ddy * ow, t, j, c)
            tf.draw(arr, x, top, t, j, 0)
        for yy in dot_ys:
            arr[yy - ow:yy + dot + ow, dot_x - ow:dot_x + dot + ow] = rgb(colon_c)
            arr[yy:yy + dot, dot_x:dot_x + dot] = 0
    else:
        tf.draw(arr, hx, top, ht, "right", hour_color)
        tf.draw(arr, mx, top, mt, "left", minute_color)
        for yy in dot_ys:
            arr[yy:yy + dot, dot_x:dot_x + dot] = rgb(colon_c)
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    df.draw(d, cx, top - lay.spacing - mc_div(df.height, 2), date, "center", rgb(text_c))
    row_y = top + line + lay.spacing + mc_div(rf.height, 2)
    for fields, y in ((lay.row1, row_y), (lay.row2, row_y + rf.height + lay.spacing)):
        if not fields:
            continue
        h = rf.height
        widths = [field_width(f, h, rf.width(texts[f])) for f in fields]
        x = cx - mc_div(row_width(h, widths[0], widths[1] if len(widths) > 1 else 0), 2)
        ih = icon_height(h)
        itop = y - mc_div(ih, 2)
        for f, w_all in zip(fields, widths):
            w = icon_width(f, h)
            draw_icon(d, f, x, itop, w, ih, rgb(text_c))
            rf.draw(d, x + w + icon_gap(h), y, texts[f], "left", rgb(text_c))
            x += w_all + group_gap(h)
    out = np.asarray(im).copy()
    if low_power:  # NoirTimeView.drawRowMask()
        for y in range(mask_first_row(0, minute), SCREEN, L["AOD_MASK_PERIOD"]):
            out[y, :, :] = 0
    yy, xx = np.ogrid[:SCREEN, :SCREEN]
    outside = (xx - SCREEN / 2 + 0.5) ** 2 + (yy - SCREEN / 2 + 0.5) ** 2 > (SCREEN / 2) ** 2
    out[outside] = 0  # round screen
    return out


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


def burn_in_run(size, hour_color, minute_color, start_minute, minutes, left=None, right=None, bottom=None,
                texts=None):
    """Simulates `minutes` consecutive always-on updates (one per minute, as documented for low power) and
    returns (max lit fraction, max luminance fraction, longest run of consecutive minutes any pixel stayed on)."""
    lay = choose_layout(size, left, right, bottom)
    run = np.zeros((SCREEN, SCREEN), dtype=np.int32)
    longest, max_lit, max_lum = 0, 0.0, 0.0
    for i in range(minutes):
        t = (start_minute + i) % 1440
        arr = render(size, hour_color, minute_color, True, hour=t // 60, minute=t % 60, layout=lay, texts=texts)
        on = arr.max(axis=2) > 0
        run = np.where(on, run + 1, 0)
        longest = max(longest, int(run.max()))
        max_lit = max(max_lit, lit_fraction(arr)[0])
        max_lum = max(max_lum, luminance_fraction(arr))
    return max_lit, max_lum, longest
