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
    "maskFirstRow": m.mask_first_row,
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
            for size in (0, 1, 2):
                tf, sf = m.choose_time_font(size, mapping)
                self.assertTrue(m.block_fits(m.SCREEN, tf.height, tf.width("00"), sf.height,
                                             sf.width(m.L["SAMPLE_DATE"]), sf.width(m.L["SAMPLE_STEPS"]),
                                             m.outline_width(tf.height)), (mapping, size, tf.name))

    def test_sizes_are_monotonic(self):
        for mapping in ("line", "digit"):
            h = [m.choose_time_font(s, mapping)[0].height for s in (0, 1, 2)]
            self.assertTrue(h[0] <= h[1] <= h[2], (mapping, h))


if __name__ == "__main__":
    unittest.main()
