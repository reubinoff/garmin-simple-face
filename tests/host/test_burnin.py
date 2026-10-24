"""Always-on (AOD) checks on the host model: same size as active mode, hollow digits, and the documented AMOLED
burn-in limits (AMOLED FAQ + DeviceSettings.requiresBurnInProtection): < 10 % of pixels on, < 10 % luminance
(Venu 2+ rule), no pixel on for more than 3 consecutive one-minute updates. Stand-in fonts -> estimates."""
import unittest

import numpy as np

import face_model as m

WHITE, CYAN = 0xFFFFFF, 0x00D4FF


def bbox(mask):
    ys, xs = np.where(mask)
    return xs.min(), xs.max(), ys.min(), ys.max()


def time_row(arr, tf):
    """Pixels of the time row only (date/steps rows blanked)."""
    out = arr.max(axis=2) > 0
    c = m.SCREEN // 2
    band = tf.height // 2 + 12
    out[: c - band, :] = False
    out[c + band:, :] = False
    return out


class BurnInTest(unittest.TestCase):
    def test_limits_every_size_both_mappings(self):
        # 40 minutes across an hour change (all minute digits + hour digit change), brightest colours.
        for mapping in ("line", "digit"):
            for size in m.SIZES:
                lit, lum, run = m.burn_in_run(size, WHITE, WHITE, 9 * 60 + 40, 40, mapping=mapping)
                with self.subTest(mapping=mapping, size=size):
                    self.assertLess(lit, 0.10)
                    self.assertLess(lum, 0.10)
                    self.assertLessEqual(run, 3)

    def test_same_size_as_active_mode(self):
        for size in m.SIZES:
            fonts = m.choose_time_font(size, "line")
            tf = fonts[0]
            active = time_row(m.render(size, WHITE, CYAN, False, minute=8, fonts=fonts), tf)
            # minute 8 -> phase 0 -> shift (-8, -8); undo the shift to compare boxes
            aod = m.render(size, WHITE, CYAN, True, minute=8, fonts=fonts)
            aod = np.roll(np.roll(aod, 8, axis=0), 8, axis=1)
            aod_row = time_row(aod, tf)
            a, b = bbox(active), bbox(aod_row)
            ow = m.outline_width(tf.height)
            with self.subTest(size=size):
                self.assertAlmostEqual((b[1] - b[0]) - (a[1] - a[0]), 2 * ow, delta=3)
                self.assertAlmostEqual((b[3] - b[2]) - (a[3] - a[2]), 2 * ow, delta=3)

    def test_digits_are_hollow(self):
        for size in m.SIZES:
            fonts = m.choose_time_font(size, "line")
            tf = fonts[0]
            active = time_row(m.render(size, WHITE, WHITE, False, minute=8, fonts=fonts), tf)
            aod = np.roll(np.roll(m.render(size, WHITE, WHITE, True, minute=8, fonts=fonts), 8, axis=0), 8, axis=1)
            aod_row = time_row(aod, tf)
            overlap = (active & aod_row).sum() / active.sum()
            with self.subTest(size=size):
                # interior of the glyphs is black (only anti-aliased edges overlap); the thinner strokes of the
                # condensed XX-Large face have relatively more edge, hence the higher bound there
                self.assertLess(overlap, 0.30 if tf.condensed else 0.25)
                full = active & (m.render(size, WHITE, WHITE, False, minute=8, fonts=fonts).max(axis=2) >= 250)
                core = full.copy()                 # fully covered glyph pixels at least 1 px inside the glyph
                for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    core &= np.roll(np.roll(full, dy, axis=0), dx, axis=1)
                bright = np.roll(np.roll(m.render(size, WHITE, WHITE, True, minute=8, fonts=fonts), 8, axis=0),
                                 8, axis=1).max(axis=2) > 64   # ignore anti-aliasing residue of the black fill
                c, r = m.SCREEN // 2, m.colon_radius(tf.height) + m.outline_width(tf.height) + 1
                core[:, c - r:c + r + 1] = False   # the colon ring (drawCircle, pen centred on r) is checked by size
                self.assertEqual((core & aod_row & bright).sum(), 0)


if __name__ == "__main__":
    unittest.main()
