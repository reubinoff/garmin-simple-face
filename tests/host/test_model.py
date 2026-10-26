"""Checks the Python port (face_model.py) against the Monkey C code and runs the SAME simple assertions that
source/tests/NoirTests.mc runs in the simulator, so the logic is also tested without device files."""
import os
import re
import unittest
from typing import ClassVar

import face_model as m

ROOT = m.ROOT
with open(os.path.join(ROOT, "source", "tests", "NoirTests.mc"), encoding="utf-8") as _fh:
    TESTS_MC = _fh.read()
with open(os.path.join(ROOT, "scripts", "make_fonts.py"), encoding="utf-8") as _fh:
    MAKE_FONTS = _fh.read()

PORT = {
    "NoirLayout.formatHour": m.format_hour, "NoirLayout.outlineWidth": m.outline_width,
    "NoirLayout.digitHeight": m.digit_height, "NoirLayout.colonGap": m.colon_gap, "NoirLayout.colonDot": m.colon_dot,
    "NoirLayout.colonOffset": m.colon_offset, "NoirLayout.timeWidth": m.time_width,
    "NoirLayout.colonColor": m.colon_color, "NoirLayout.insideCircle": m.inside_circle,
    "NoirLayout.blockFits": m.block_fits, "NoirLayout.blockShift": m.block_shift,
    "NoirLayout.maskFirstRow": m.mask_first_row, "NoirLayout.iconHeight": m.icon_height,
    "NoirLayout.iconWidth": m.icon_width, "NoirLayout.iconGap": m.icon_gap, "NoirLayout.groupGap": m.group_gap,
    "NoirLayout.fieldWidth": m.field_width, "NoirLayout.rowWidth": m.row_width,
    "NoirLayout.aodShiftX": m.aod_shift_x, "NoirLayout.aodShiftY": m.aod_shift_y, "NoirLayout.dimColor": m.dim_color,
    "NoirFormat.thousands": m.thousands, "NoirFormat.number": m.number, "NoirFormat.percent": m.percent,
    "NoirFormat.days": m.days, "NoirFormat.temperature": m.temperature, "NoirFormat.distance": m.distance,
}


LOCALS: dict = {}


def mc_value(text):
    text = text.strip()
    env = {"null": None, "true": True, "false": False}
    env.update(LOCALS)
    text = re.sub(r"NoirLayout\.([A-Z_]+)\b", lambda g: repr(m.L[g.group(1)]), text)
    text = re.sub(r"NoirFields\.([A-Z_]+)\b", lambda g: repr(m.F[g.group(1)]), text)
    text = re.sub(r"(\d+\.\d+)f\b", r"\1", text)
    text = text.replace("\\u00B0", "\u00b0")
    return eval(text, {"__builtins__": {}}, env)


class PortParityTest(unittest.TestCase):
    def test_constants_read_from_monkey_c(self):
        for k in ("EDGE_MARGIN", "AOD_SHIFT_PIXELS", "OUTLINE_MIN", "OUTLINE_MAX", "AOD_MASK_PERIOD",
                  "ROW_SPACING_PERCENT", "COLOR_TEXT", "COLOR_TEXT_AOD", "TIME_LINE_EXTRA", "COLON_GAP_PERCENT"):
            self.assertIn(k, m.L)
        self.assertEqual(len(m.L["OUTLINE_DX"]), 8)
        self.assertEqual(set(zip(m.L["OUTLINE_DX"], m.L["OUTLINE_DY"])),
                         {(x, y) for x in (-1, 0, 1) for y in (-1, 0, 1)} - {(0, 0)})

    def test_font_generator_shares_layout_constants(self):
        """scripts/make_fonts.py sizes the digits with the same margin / outline / colon gap the face lays out with."""
        for name, key in (("EDGE_MARGIN", "EDGE_MARGIN"), ("OUTLINE_MAX", "OUTLINE_MAX"),
                          ("COLON_GAP_PERCENT", "COLON_GAP_PERCENT")):
            gen = int(re.search(rf"^{name} = (\d+)", MAKE_FONTS, re.MULTILINE).group(1))
            self.assertEqual(gen, m.L[key], name)

    def test_monkey_c_assertions_hold_in_port(self):
        pattern = re.compile(r"Test\.assert(Equal)?\((!?)((?:NoirLayout|NoirFormat)\.\w+)\(([^()]*)\)(?:, ([^;]+))?\);")
        # Locals such as `var timeW = NoirLayout.timeWidth(170, 155);` are evaluated with the port first.
        for name, fn, args in re.findall(r"var (\w+) = ((?:NoirLayout|NoirFormat)\.\w+)\(([^()]*)\);", TESTS_MC):
            if fn in PORT and not re.search(r"\b[a-z]\w*\b", re.sub(r"Noir\w+\.\w+|true|false|null", "", args)):
                LOCALS[name] = PORT[fn](*mc_value("(" + args + ",)"))
        count = 0
        for eq, neg, fn, args, expected in pattern.findall(TESTS_MC):
            if fn not in PORT:
                continue
            # Calls on loop variables (e.g. aodShiftX(m + 8)) are covered by the dedicated port tests.
            if re.search(r"\b[a-z]\w*\b", re.sub(r"Noir\w+\.\w+|true|false|null|0x[0-9A-Fa-f]+", "", args + " " + expected)) \
                    and not all(re.fullmatch(r"\w+", v) and v in LOCALS for v in re.findall(r"\b[a-z]\w*\b",
                    re.sub(r"Noir\w+\.\w+|true|false|null|0x[0-9A-Fa-f]+", "", args + " " + expected))):
                continue
            value = PORT[fn](*mc_value("(" + args + ",)"))
            if eq:
                self.assertEqual(value, mc_value(expected), f"{fn}({args})")
            else:
                self.assertEqual(bool(value), not neg, f"{fn}({args})")
            count += 1
        self.assertGreaterEqual(count, 60)

    def test_mc_division_truncates(self):
        self.assertEqual(m.mc_div(-7, 2), -3)
        self.assertEqual(m.mc_div(7, 2), 3)

    def test_aod_shift_cycle(self):
        """D-43: 4 px (Garmin UX guidelines, Watch Faces: "moving elements up to four pixels in any direction every
        minute"); each minute moves exactly 4 px on one axis; offsets stay within +-4 px; 8 distinct positions."""
        s = m.L["AOD_SHIFT_PIXELS"]
        self.assertEqual(s, 4)
        seen = set()
        for minute in range(240):
            a, b = m.aod_shift(minute), m.aod_shift(minute + 1)
            self.assertTrue(abs(a[0]) <= s and abs(a[1]) <= s)
            self.assertEqual(sorted((abs(a[0] - b[0]), abs(a[1] - b[1]))), [0, s])
            seen.add(a)
        self.assertEqual(len(seen), 8)
        self.assertGreaterEqual(m.L["EDGE_MARGIN"], s + m.L["OUTLINE_MAX"])
        # Over a real clock day (minute of the day, incl. every full hour and midnight) no step exceeds 4 px.
        for t in range(1440):
            a, b = m.aod_shift(t), m.aod_shift((t + 1) % 1440)
            self.assertEqual(sorted((abs(a[0] - b[0]), abs(a[1] - b[1]))), [0, s], t)

    def test_view_passes_minute_of_day(self):
        """Regression: clock.min (60 % 8 != 0) made the always-on block jump 8 px at every full hour."""
        src = open(os.path.join(m.ROOT, "source", "NoirTimeView.mc"), encoding="utf-8").read()
        self.assertIn("aodShiftX(minuteOfDay)", src)
        self.assertIn("aodShiftY(minuteOfDay)", src)
        self.assertNotIn("aodShiftX(clock.min)", src)

    def test_aod_digits_dimmed(self):
        """D-43: always-on digits use 70 % of the chosen colour (UX guidelines: light grey instead of white / blue)."""
        self.assertEqual(m.L["AOD_DIGIT_PERCENT"], 70)
        self.assertEqual(m.dim_color(0xFFFFFF), 0xB2B2B2)
        for c in m.color_values():
            d = m.dim_color(c)
            for shift in (16, 8, 0):
                self.assertLessEqual((d >> shift) & 0xFF, 0xB2)

    def test_row_mask_turns_every_row_off_once_per_period(self):
        p = m.L["AOD_MASK_PERIOD"]
        for y in range(m.SCREEN):
            for start in range(5):
                self.assertTrue(any((y - m.mask_first_row(0, start + k)) % p == 0 for k in range(p)))

    def test_parse_level_port(self):
        for v, want in ((None, None), (0, 0), (76, 76), (100, 100), (101, None), (-1, None), (42.6, 43), (42.4, 42)):
            self.assertEqual(m.parse_level(v), want, v)

    def test_row_compaction(self):
        n, st, bb, hr = m.F["NONE"], m.F["STEPS"], m.F["BODY_BATTERY"], m.F["HEART_RATE"]
        self.assertEqual(m.rows_for(st, bb, n), ([st, bb], []))
        self.assertEqual(m.rows_for(st, bb, hr), ([st, bb], [hr]))
        self.assertEqual(m.rows_for(n, n, hr), ([hr], []))
        self.assertEqual(m.rows_for(n, bb, hr), ([bb], [hr]))
        self.assertEqual(m.rows_for(n, n, n), ([], []))


class LayoutTest(unittest.TestCase):
    """Layout search on the 454 px screen with the real embedded time fonts."""

    CONFIGS: ClassVar[list[tuple[int, int, int]]] = [(1, 2, 0), (0, 0, 0), (1, 2, 3), (6, 12, 11), (4, 5, 10), (9, 8, 7), (0, 0, 3)]

    def test_layout_fits_for_every_size_and_config(self):
        for size in m.SIZES:
            for cfg in self.CONFIGS:
                lay = m.choose_layout(size, *cfg)
                self.assertTrue(m.fits(lay.time_font, lay.date_font, lay.row_font, lay.row1, lay.row2), (size, cfg))

    def test_sizes_are_distinct_with_one_row(self):
        """With one field row (the default) every size setting gets its own font: each option is really bigger."""
        names = [m.choose_layout(s, 1, 2, 0).time_font.name for s in m.SIZES]
        self.assertEqual(names, [f"TimeFont{i}" for i in range(5)])

    def test_fonts_never_grow_with_more_fields(self):
        for size in m.SIZES:
            one = m.choose_layout(size, 1, 2, 0).time_font.height
            two = m.choose_layout(size, 1, 2, 3).time_font.height
            self.assertLessEqual(two, one, size)

    def test_digits_fill_the_line(self):
        """Bebas digits are cropped to the line (lineHeight = digit height + TIME_LINE_EXTRA, D-38)."""
        from PIL import Image
        for i in range(5):
            tf = m.TimeFont(i)
            g = tf.chars["0"]
            self.assertLessEqual(abs(g["height"] - m.digit_height(tf.height)), 1, tf.name)
            self.assertLessEqual(g["yoffset"] + g["height"], tf.height)
            with Image.open(os.path.join(ROOT, "resources-round-454x454", "fonts", f"time{i}.png")) as im:
                self.assertLessEqual(im.size[0] * im.size[1], 512 * 512)

    def test_digit_height_grows_with_every_size(self):
        heights = [m.digit_height(m.choose_layout(s).time_font.height) for s in m.SIZES]
        self.assertEqual(heights, sorted(set(heights)), heights)


if __name__ == "__main__":
    unittest.main()
