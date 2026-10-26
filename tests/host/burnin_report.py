#!/usr/bin/env python3
"""Full-day always-on burn-in report: real simulator frames + host model.

* Real frames: every docs/screenshots/aod_*.png (fenix9pro47mm simulator, Settings > Display Mode > Always-On) and
  every docs/screenshots/devices/*_aod.png (other screen sizes). Pixels on and luminance are measured inside the
  round screen of the frame's own size and divided by the pixels of that circle (the conservative denominator; the
  docs do not define one for round screens, D-43).
* Host model: the 1440 one-minute low-power updates of a day for every size with the brightest colours
  (white / white), with the default fields (steps, Body Battery) and with two field rows (steps, Body Battery,
  heart rate). The time digits are the real embedded Bebas Neue fonts; the date / field text is RobotoCondensed
  (device file with CIQ_DEVICE_FONTS, else a stand-in).
* Active (high-power) frames, same fields and colours, sampled at every hour x minutes :00 :08 :18 :28 :38 :48 :58
  (168 frames per row), also per circle: lit pixels matter less there (about ten seconds after a wrist raise) but are reported for the
  battery report (docs/battery-report.md).

  CIQ_DEVICE_FONTS=~/.Garmin/ConnectIQ/Fonts python3 tests/host/burnin_report.py [minutes]
"""
import glob
import os
import sys

import face_model as m
import numpy as np
from PIL import Image

minutes = int(sys.argv[1]) if len(sys.argv) > 1 else 1440
SHOTS = os.path.join(m.ROOT, "docs", "screenshots")


def real_frame(path):
    """(screen size, pixels on, mean luminance) of a simulator frame, both per circle of the frame's own size."""
    a = np.array(Image.open(path).convert("RGB")).astype(float)
    size = a.shape[0]
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    inside = (xx - size / 2 + 0.5) ** 2 + (yy - size / 2 + 0.5) ** 2 <= (size / 2) ** 2   # same circle as the model
    a[~inside] = 0   # the round screen only, not the bezel
    circle = int(inside.sum())
    y = (0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]) / 255.0
    return size, int((a.max(axis=2) > 0).sum()) / circle, float(y.sum() / circle)


real = [("fenix9pro47mm " + os.path.basename(p)[4:-4],) + real_frame(p)
        for p in sorted(glob.glob(os.path.join(SHOTS, "aod_*.png")))]
real += [(os.path.basename(p)[:-8].replace("_", " ", 1),) + real_frame(p)
         for p in sorted(glob.glob(os.path.join(SHOTS, "devices", "*_aod.png")))]
CONFIGS = {"steps + Body Battery": (1, 2, 0), "steps + Body Battery / heart rate": (1, 2, 3)}
ACTIVE_TIMES = [(h, mm) for h in range(24) for mm in (0, 8, 18, 28, 38, 48, 58)]


def active_max(size, cfg, texts):
    lay = m.choose_layout(size, *cfg)
    lit = lum = 0.0
    for h, mm in ACTIVE_TIMES:
        arr = m.render(size, 0xFFFFFF, 0xFFFFFF, False, hour=h, minute=mm, layout=lay, texts=texts)
        lit = max(lit, m.lit_fraction(arr)[1])
        lum = max(lum, m.luminance_fraction(arr))
    return lit, lum


rows = []
active_rows = []
for label, cfg in CONFIGS.items():
    for size in m.SIZES:
        lay = m.choose_layout(size, *cfg)
        texts = dict(m.DEFAULT_TEXTS)
        texts[m.F["STEPS"]] = "88,888"
        lit, lum, run = m.burn_in_run(size, 0xFFFFFF, 0xFFFFFF, 0, minutes, *cfg, texts=texts)
        rows.append((label, m.SIZE_NAMES[size], lay.time_font.name, lit, lum, run))
        print(rows[-1], flush=True)
        a_lit, a_lum = active_max(size, cfg, texts)
        active_rows.append((label, m.SIZE_NAMES[size], lay.time_font.name, a_lit, a_lum))
        print(active_rows[-1], flush=True)

out = os.path.join(m.ROOT, "docs", "burn-in-report.md")
with open(out, "w", encoding="utf-8") as fh:
    fh.write("# Always-on burn-in report\n\n")
    fh.write("Limits (AMOLED FAQ / UX guidelines): < 10 % of pixels on, < 10 % luminance (Venu 2 and later), "
             "no pixel on for more than 3 minutes.\n\n")
    fh.write("Every percentage is a share of the ROUND screen (pixels inside the circle), the conservative denominator: "
             "neither the AMOLED FAQ (\"10% of the screen pixels\") nor `DeviceSettings.requiresBurnInProtection` "
             "(\"ten-percent of the total available screen pixels\") defines it for round screens (DECISIONS.md D-43).\n\n")
    fh.write("## Real simulator frames (SDK 9.3.0)\n\n")
    fh.write("Every `docs/screenshots/aod_*.png` (fenix9pro47mm) and `docs/screenshots/devices/*_aod.png`, measured by "
             "`tests/host/burnin_report.py`. The frames show the current always-on look (D-43: 4 px minute-of-day shift, "
             "digits at 70 %) with simulated activity data (7,432 steps, 3 notifications).\n\n")
    fh.write("| frame | screen | pixels on | mean luminance |\n|---|---|---|---|\n")
    for name, size, lit, lum in real:
        fh.write(f"| {name} | {size} px | {100 * lit:.2f} % | {100 * lum:.2f} % |\n")
    worst: dict[int, float] = {}
    for name, size, lit, lum in real:
        worst[size] = max(worst.get(size, 0.0), lit)
    fh.write("\nWorst pixels on per screen size: " + ", ".join(
        f"{size} px {100 * lit:.2f} %" for size, lit in sorted(worst.items())) + " (limit 10 %).\n")
    kind = "font-accurate" if m.DEVICE_FONTS else "date / field text ESTIMATED with a stand-in font"
    fh.write(f"\n## Full day, host model ({kind})\n\n")
    fh.write(f"Generated by `python3 tests/host/burnin_report.py {minutes}` with {m.FONT_SOURCE}: {minutes} consecutive "
             "one-minute low-power updates from 00:00, hour and minute colour white (worst case; drawn at 70 % in always-on, D-43), "
             "steps 88,888, 24 h clock, 4 px shift.\n\n")
    fh.write("| fields | size | time font | max pixels on | max luminance | longest run (min) |\n")
    fh.write("|---|---|---|---|---|---|\n")
    for label, size, name, lit, lum, run in rows:
        fh.write(f"| {label} | {size} | {name} | {100 * lit:.2f} % | {100 * lum:.2f} % | {run} |\n")
    fh.write("\n## Active (high-power) frames, host model\n\n")
    fh.write(f"Same fields, colours and fonts; {len(ACTIVE_TIMES)} active frames per row (every hour at :00 :08 :18 :28 :38 :48 :58). "
             "Active mode lasts about ten seconds after a wrist raise (WatchFace API doc), so this is for reference; the burn-in "
             "limits apply to always-on only.\n\n")
    fh.write("| fields | size | time font | max pixels on | max luminance |\n|---|---|---|---|---|\n")
    for label, size, name, lit, lum in active_rows:
        fh.write(f"| {label} | {size} | {name} | {100 * lit:.2f} % | {100 * lum:.2f} % |\n")
print("written", out)
