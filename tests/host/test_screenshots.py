"""Checks on the REAL simulator screenshots in docs/screenshots (SDK 9.3.0 simulator, fenix9pro47mm)."""
import glob
import os
import unittest

import numpy as np
from PIL import Image

import face_model as m

SHOTS = os.path.join(m.ROOT, "docs", "screenshots")


def load(name):
    a = np.array(Image.open(os.path.join(SHOTS, name)).convert("RGB")).astype(float)
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    a[(xx - 226.5) ** 2 + (yy - 226.5) ** 2 > 227 ** 2] = 0  # keep only the round screen, not the bezel
    return a


def time_block_height(img):
    """Longest run of consecutive rows containing bright (time digit) pixels; the AOD row mask blanks every 3rd
    row, so gaps of up to 2 rows are bridged."""
    bright = (img.max(axis=2) > 150).any(axis=1)
    best = run = gap = 0
    for b in bright:
        if b:
            run, gap = run + 1 + gap, 0
        elif run and gap < 2:
            gap += 1
        else:
            run, gap = 0, 0
        best = max(best, run)
    return best


class RealScreenshotTests(unittest.TestCase):
    def test_present(self):
        for size in ("small", "medium", "large", "xlarge", "xxlarge"):
            self.assertTrue(glob.glob(os.path.join(SHOTS, "active_%s_*.png" % size)), size)
            self.assertTrue(glob.glob(os.path.join(SHOTS, "aod_%s_*.png" % size)), size)

    def test_aod_within_amoled_limits(self):
        for path in glob.glob(os.path.join(SHOTS, "aod_*.png")):
            a = load(os.path.basename(path))
            on = (a.max(axis=2) > 0).sum() / (454 * 454)
            self.assertLess(on, 0.10, path)
            self.assertLess(m.luminance_fraction(a), 0.10, path)

    def test_aod_lights_fewer_pixels_than_active(self):
        for path in glob.glob(os.path.join(SHOTS, "aod_*.png")):
            name = os.path.basename(path)
            act = load(name.replace("aod_", "active_", 1))
            aod = load(name)
            self.assertLess((aod.max(axis=2) > 0).sum(), (act.max(axis=2) > 0).sum(), name)

    def test_same_digit_height_in_both_modes(self):
        """Owner requirement: always-on keeps the size. Height of the bright time band, active vs AOD."""
        for path in glob.glob(os.path.join(SHOTS, "aod_*.png")):
            name = os.path.basename(path)
            heights = []
            for img in (load(name.replace("aod_", "active_", 1)), load(name)):
                heights.append(time_block_height(img))
            self.assertLessEqual(abs(heights[0] - heights[1]), 2 * 4 + 2, (name, heights))  # outline pad + shift

    def test_hidden_fields(self):
        """Toggles: hiding a field lights fewer pixels and never changes the time size (D-28, D-29)."""
        pairs = [("large_white-white_no-bodybattery", "large_white-white"),
                 ("medium_white-orange_no-steps", "medium_white-orange"),
                 ("xlarge_white-cyan_no-stats", "xlarge_white-cyan")]
        for hidden, full in pairs:
            for mode in ("active_", "aod_"):
                h, f = load(mode + hidden + ".png"), load(mode + full + ".png")
                self.assertLess((h.max(axis=2) > 0).sum(), (f.max(axis=2) > 0).sum(), mode + hidden)
                self.assertLessEqual(abs(time_block_height(h) - time_block_height(f)), 2 * 4 + 2, mode + hidden)


if __name__ == "__main__":
    unittest.main()
