"""Checks the Python port (face_model.py) against the Monkey C code and runs the SAME simple assertions that
source/tests/NoirTests.mc runs in the simulator, so the logic is also tested without device files."""
import os
import re
import unittest

import face_model as m

ROOT = m.ROOT
with open(os.path.join(ROOT, "source", "tests", "NoirTests.mc"), encoding="utf-8") as _fh:
    TESTS_MC = _fh.read()

PORT = {
    "formatSteps": lambda v: m.format_steps(v), "formatHour": m.format_hour, "outlineWidth": m.outline_width,
    "colonRadius": m.colon_radius, "colonGap": m.colon_gap, "colonDotOffset": m.colon_dot_offset,
    "colonColor": m.colon_color, "insideCircle": m.inside_circle, "blockFits": m.block_fits,
    "digitHalfHeight": m.digit_half_height,
    "maskFirstRow": m.mask_first_row,
    "iconHeight": m.icon_height, "stepsIconWidth": m.steps_icon_width, "bodyBatteryIconWidth": m.body_battery_icon_width,
    "iconGap": m.icon_gap, "groupGap": m.group_gap, "statsRowWidth": m.stats_row_width,
    "formatBodyBattery": m.format_body_battery,
}


def mc_value(text):
    text = text.strip()
    env = {"null": None, "true": True, "false": False}
    text = re.sub(r"NoirLayout\.(\w+)", lambda g: repr(m.L[g.group(1)]), text)
    return eval(text, {"__builtins__": {}}, env)


class PortParityTest(unittest.TestCase):
    def test_constants_read_from_monkey_c(self):
        for k in ("EDGE_MARGIN", "AOD_SHIFT_PIXELS", "OUTLINE_MIN", "OUTLINE_MAX", "AOD_MASK_PERIOD",
                  "ROW_SPACING_PERIOD" if False else "ROW_SPACING_PERCENT", "COLOR_TEXT", "COLOR_TEXT_AOD"):
            self.assertIn(k, m.L)
        self.assertEqual(len(m.L["OUTLINE_DX"]), 8)
        self.assertEqual(set(zip(m.L["OUTLINE_DX"], m.L["OUTLINE_DY"])),
                         {(x, y) for x in (-1, 0, 1) for y in (-1, 0, 1)} - {(0, 0)})

    def test_monkey_c_assertions_hold_in_port(self):
        pattern = re.compile(r"Test\.assert(Equal)?\((!?)NoirLayout\.(\w+)\(([^()]*)\)(?:, ([^;]+))?\);")
        count = 0
        for eq, neg, fn, args, expected in pattern.findall(TESTS_MC):
            if fn not in PORT:
                continue
            value = PORT[fn](*mc_value("(" + args + ",)"))
            if eq:
                self.assertEqual(value, mc_value(expected), "%s(%s)" % (fn, args))
            else:
                self.assertEqual(bool(value), not neg, "%s(%s)" % (fn, args))
            count += 1
        self.assertGreaterEqual(count, 30)

    def test_mc_division_truncates(self):
        self.assertEqual(m.mc_div(-7, 2), -3)
        self.assertEqual(m.mc_div(7, 2), 3)

    def test_aod_shift_cycle(self):
        s = m.L["AOD_SHIFT_PIXELS"]
        for minute in range(120):
            a, b = m.aod_shift(minute), m.aod_shift(minute + 1)
            self.assertEqual(sum(abs(a[i] - b[i]) == 2 * s for i in (0, 1)), 1)
        self.assertGreaterEqual(m.L["EDGE_MARGIN"], s + m.L["OUTLINE_MAX"])

    def test_row_mask_turns_every_row_off_once_per_period(self):
        p = m.L["AOD_MASK_PERIOD"]
        for y in range(m.SCREEN):
            for start in range(5):
                self.assertTrue(any((y - m.mask_first_row(0, start + k)) % p == 0 for k in range(p)))

    def test_layout_fits_for_every_size_and_mapping(self):
        for mapping in ("line", "digit"):
            for size in m.SIZES:
                for steps, bb in ((True, True), (True, False), (False, True), (False, False)):
                    tf, sf, stf = m.choose_time_font(size, mapping, steps, bb)
                    pct = m.L["DIGIT_HALF_PERCENT_CONDENSED" if tf.condensed else "DIGIT_HALF_PERCENT_NUMBER"]
                    self.assertTrue(m.fits(tf, sf, pct, stf, steps, bb), (mapping, size, tf.name, stf.name))

    def test_toggles_never_change_the_time_font(self):
        """The time font is chosen against the smallest stats font, so showing / hiding fields never resizes the time."""
        for size in m.SIZES:
            names = {m.choose_time_font(size, "line", s, b)[0].name for s in (True, False) for b in (True, False)}
            self.assertEqual(len(names), 1, (size, names))

    def test_steps_only_keeps_font_small(self):
        """With Body Battery hidden the steps row keeps FONT_SMALL (the pre-icon look) for every size."""
        for size in m.SIZES:
            self.assertEqual(m.choose_time_font(size, "line", True, False)[2].name, "FONT_SMALL", size)

    def test_body_battery_parse_port(self):
        for v, want in ((None, None), (0, 0), (76, 76), (100, 100), (101, None), (-1, None), (42.6, 43), (42.4, 42)):
            self.assertEqual(m.parse_body_battery(v), want, v)

    def test_sizes_are_monotonic(self):
        # "line" only: the device uses it (D-23); with the ruled-out pessimistic "digit" mapping the big fonts
        # would not fit and fall back (that mapping is still used as a worst case by the burn-in tests).
        for mapping in ("line",):
            fonts = [m.choose_time_font(s, mapping)[0] for s in m.SIZES]
            # Each size is a different font, so every option is really bigger than the previous one.
            self.assertEqual(len({f.name for f in fonts}), len(fonts), (mapping, [f.name for f in fonts]))

    def test_digit_height_grows_with_every_size(self):
        """The visible digit height (ink of "00"), not only the font box, must grow from size to size."""
        from PIL import Image, ImageDraw
        heights = []
        for s in m.SIZES:
            tf = m.choose_time_font(s, "line")[0]
            im = Image.new("L", (600, 400))
            tf.draw(ImageDraw.Draw(im), 10, 200, "00", "left", 255)
            box = im.getbbox()
            heights.append(box[3] - box[1])
        self.assertEqual(heights, sorted(set(heights)), heights)


if __name__ == "__main__":
    unittest.main()
