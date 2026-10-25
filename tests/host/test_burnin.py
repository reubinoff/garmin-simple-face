"""Always-on (AOD) checks on the host model: same size as active mode, hollow digits, and the documented AMOLED
burn-in limits (AMOLED FAQ + DeviceSettings.requiresBurnInProtection): < 10 % of pixels on, < 10 % luminance
(Venu 2+ rule), no pixel on for more than 3 consecutive one-minute updates. The time digits are the real embedded
fonts; the date / field text uses RobotoCondensed (device file with CIQ_DEVICE_FONTS, else a stand-in)."""
import unittest

import face_model as m
import numpy as np

WHITE, CYAN = 0xFFFFFF, 0x00D4FF
BUSY = (m.F["STEPS"], m.F["BODY_BATTERY"], m.F["HEART_RATE"])   # most lit pixels: two field rows


def bbox(mask):
    ys, xs = np.where(mask)
    return xs.min(), xs.max(), ys.min(), ys.max()


def time_row(arr, lay):
    """Pixels of the time row only (date / field rows blanked)."""
    out = arr.max(axis=2) > 0
    c = m.SCREEN // 2 - lay.shift
    band = lay.time_font.height // 2 + 6
    out[: c - band, :] = False
    out[c + band:, :] = False
    return out


def unshift(arr, minute):
    dx, dy = m.aod_shift(minute)
    return np.roll(np.roll(arr, -dy, axis=0), -dx, axis=1)


class BurnInTest(unittest.TestCase):
    def test_limits_every_size(self):
        # 40 minutes across an hour change (all minute digits + hour digit change), brightest colours.
        for size in m.SIZES:
            for cfg in ((1, 2, 0), BUSY):
                lit, lum, run = m.burn_in_run(size, WHITE, WHITE, 9 * 60 + 40, 40, *cfg)
                with self.subTest(size=size, cfg=cfg):
                    self.assertLess(lit, 0.10)
                    self.assertLess(lum, 0.10)
                    self.assertLessEqual(run, 3)

    def test_same_size_as_active_mode(self):
        for size in m.SIZES:
            lay = m.choose_layout(size)
            active = time_row(m.render(size, WHITE, CYAN, False, minute=8, layout=lay), lay)
            aod = time_row(unshift(m.render(size, WHITE, CYAN, True, minute=8, layout=lay), 8), lay)
            a, b = bbox(active), bbox(aod)
            ow = m.outline_width(lay.time_font.height)
            with self.subTest(size=size):
                self.assertAlmostEqual((b[1] - b[0]) - (a[1] - a[0]), 2 * ow, delta=3)
                self.assertAlmostEqual((b[3] - b[2]) - (a[3] - a[2]), 2 * ow, delta=3)

    def test_digits_are_hollow(self):
        for size in m.SIZES:
            lay = m.choose_layout(size)
            active_img = m.render(size, WHITE, WHITE, False, minute=8, layout=lay)
            active = time_row(active_img, lay)
            aod_img = unshift(m.render(size, WHITE, WHITE, True, minute=8, layout=lay), 8)
            aod = time_row(aod_img, lay)
            overlap = (active & aod).sum() / active.sum()
            with self.subTest(size=size):
                self.assertLess(overlap, 0.25)   # only anti-aliased edges overlap
                full = active & (active_img.max(axis=2) >= 250)
                core = full.copy()               # fully covered glyph pixels at least 1 px inside the glyph
                for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    core &= np.roll(np.roll(full, dy, axis=0), dx, axis=1)
                bright = aod_img.max(axis=2) > 64   # ignore anti-aliasing residue of the black fill
                self.assertEqual((core & aod & bright).sum(), 0)


if __name__ == "__main__":
    unittest.main()
