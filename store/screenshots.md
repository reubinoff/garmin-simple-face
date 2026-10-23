# Screenshot checklist

The store form's exact screenshot dimensions/count are **not documented in the sources used to build this project** (DECISIONS.md G-7). Check the form at
<https://developer.garmin.com/connect-iq/submit-an-app/> and match it.

Take them from the simulator (fenix9pro47mm) or the real watch, never from `docs/mockups/` (those are drawn with a stand-in font and labelled as mockups).

Suggested set:
1. Default (white time), high power, a realistic time such as 10:08, steps in the thousands.
2. One accent colour (e.g. cyan) to show the setting.
3. Always-on (low power) mode.
4. The settings page in Garmin Connect showing the colour list (phone screenshot).

Tips: use a time without many wide digits (10:08), set steps to e.g. 8432 in the simulator (*Simulation -> Set Activity Monitor Info*), and keep the launcher icon
(`resources/drawables/launcher_icon.png`, 65x65) as the store icon source if the form accepts it - larger icon art may be needed (see the form).
