# Screenshot checklist

The store form's exact screenshot dimensions/count are **not documented in the sources used to build this project** (DECISIONS.md G-7). Check the form at
<https://developer.garmin.com/connect-iq/submit-an-app/> and match it.

Take them from the simulator (fenix9pro47mm) or the real watch.
Real simulator frames are in `docs/screenshots/` (454 x 454 crops; the bezel shows in the corners outside the round screen, mask or crop before uploading if the form wants only the screen).

Suggested set:
1. Default (white time, Medium), high power, a realistic time such as 10:08, steps in the thousands.
2. Two colours (e.g. white hours, cyan minutes) to show the separate colours.
3. Small and XX-Large size, and field choices (e.g. `docs/screenshots/active_medium_white-white_steps-bb-hr.png`, `active_large_white-white_calories-floors-temperature.png`) (real frames: `docs/screenshots/active_*_*.png`).
4. Always-on (low power) mode: same size, outline-only digits.
5. The on-watch settings menu (Time Size / Hour Color / Minute Color / Left / Right / Bottom field) - from the simulator or the watch.
6. The settings page in Garmin Connect (phone screenshot).

Tips: use a time without many wide digits (10:08), set steps to e.g. 8432 in the simulator (*Simulation -> Activity Data*), and keep the launcher icon
(`resources/drawables/launcher_icon.png`, 65x65) as the store icon source if the form accepts it - larger icon art may be needed (see the form).

## Ready-made store images

`store/all-assets/` holds every image the Developer Dashboard asks for, with `INDEX.md` (pixel size, byte size, where each file goes).
Regenerate:

- `python3 scripts/make_icons.py` writes the two 128x128 on-device store icons to `store/icons/`: a preview of the face, "10:08" in Bebas Neue with the square colon, on a round black screen. `icon_24bit_128.png` is 24-bit RGB. `icon_64color_128.png` is an 8-bit palette image that uses only the 64-colour palette (channel levels 00/55/AA/FF). Neither has a black or transparent background.
- `python3 scripts/make_hero.py` writes `store/hero/hero_1440x720.png`.
- `scripts/collect-store-assets.sh` builds the cover and screenshots via `scripts/store-assets.sh` and rebuilds `store/all-assets/` and its `INDEX.md`.

The simulator frames in `docs/screenshots/` were captured with *Simulation -> Activity Monitor* data: 7,432 steps (goal 10,000), 1,840 kcal, 9 floors, 32 intensity minutes and 3 phone notifications. Body Battery 88 and heart rate 80 are simulator defaults. The simulator's "Distance (cm)" column is applied ×100: entering 5620 gives 562,000 cm, which displays as 3.4 mi.
