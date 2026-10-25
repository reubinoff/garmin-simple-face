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
