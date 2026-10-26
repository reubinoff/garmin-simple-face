#!/usr/bin/env bash
# Collects every Connect IQ Store image into one folder (default store/all-assets/) with an INDEX.md that lists each
# file's pixel size, byte size and where it is uploaded in the Developer Dashboard.
#
#   scripts/collect-store-assets.sh [out_dir]
#
# Inputs (regenerate them first if the face changed):
#   python3 scripts/make_icons.py   -> store/icons/icon_64color_128.png, icon_24bit_128.png
#   python3 scripts/make_hero.py    -> store/hero/hero_1440x720.png (uses docs/screenshots/active_xlarge_white-cyan.png)
#   docs/screenshots/active_*.png, aod_*.png (real simulator frames)
# cover.png and the screenshot_* files are made by scripts/store-assets.sh (size limits checked there).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-store/all-assets}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
scripts/store-assets.sh "$TMP" >/dev/null
rm -rf "$OUT"; mkdir -p "$OUT"
cp "$TMP/hero_1440x720.png" "$OUT/hero_1440x720.png"
cp "$TMP/cover.png" "$OUT/cover_500x500.png"
cp "$TMP/icon_64color_128.png" "$OUT/icon_64color_128x128.png"
cp "$TMP/icon_24bit_128.png" "$OUT/icon_24bit_128x128.png"
cp "$TMP"/screenshot_* "$OUT"/
python3 - "$OUT" <<'PY'
import os, sys
from PIL import Image
out = sys.argv[1]
def kb(n): return f"{n:,} B ({n / 1024:.1f} KB)"
fixed = [
    ("hero_1440x720.png", "Hero image (optional, max 2048 KB): title \"CLEAN AIR\" in Bebas Neue + real simulator screenshot"),
    ("cover_500x500.png", "Cover image: round screen of active_large_yellow-white on a slate background, no text"),
    ("icon_64color_128x128.png", "On-device store icon, low-colour (MIP) devices: 8-bit palette, only 64-colour palette entries"),
    ("icon_24bit_128x128.png", "On-device store icon, full-colour (AMOLED) devices: 24-bit RGB"),
]
shots = sorted(f for f in os.listdir(out) if f.startswith("screenshot_"))
rows = []
for name, what in fixed + [(f, None) for f in shots]:
    p = os.path.join(out, name)
    im = Image.open(p)
    if what is None:
        stem = os.path.splitext(name)[0][len("screenshot_"):]
        mode, rest = stem.split("_", 1)
        what = ("Screenshot, active mode" if mode == "active" else "Screenshot, always-on (AOD) mode") + " — " + rest.replace("_", ", ")
    rows.append(f"| `{name}` | {im.size[0]}×{im.size[1]} | {kb(os.path.getsize(p))} | {what} |")
with open(os.path.join(out, "INDEX.md"), "w", encoding="utf-8") as fh:
    fh.write("""# Clean Air — Connect IQ Store images

Everything the Garmin Developer Dashboard asks for, in one place. All files are PNG, sRGB, no transparency.

Where to upload (Developer Dashboard → your app → Edit / Upload new version → *Cover Image & Icons* / *Screenshots*):

- **Hero image** (optional, max 2048 KB): `hero_1440x720.png`
- **Cover image** (500×500, sRGB, no transparency): `cover_500x500.png`
- **Screenshots** (each under 150 KB): any of the `screenshot_*.png` files — `active_*` = normal mode, `aod_*` = always-on (low-power) mode
- **On-device store icons** (128×128, answer *Yes* to the on-device icon option): `icon_64color_128x128.png` → 64-colour icon, `icon_24bit_128x128.png` → 24-bit icon

Screenshots: real Connect IQ simulator frames (SDK 9.3.0, fēnix 9 Pro 47mm) with simulated activity data (7,432 steps, 3 notifications); the always-on frames show the current always-on look (digits at 70 %, 4 px minute-of-day shift).

| File | Pixels | Size | What it's for |
|---|---|---|---|
""")
    fh.write("\n".join(rows) + "\n")
    fh.write("""
Regenerate: `python3 scripts/make_icons.py` (icons), `python3 scripts/make_hero.py` (hero), then `scripts/collect-store-assets.sh` (cover + screenshots via `scripts/store-assets.sh`, this folder and INDEX.md).
""")
print(f"{len(rows)} files + INDEX.md in {out}")
PY
