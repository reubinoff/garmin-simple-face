# Battery report

Build: `main` after D-38 (embedded Bebas Neue bitmap time font), D-39 - D-41 (three configurable field slots, RobotoCondensed
companion text), D-42 (field widths cached) and D-43 (4 px always-on shift, digits at 70 %, `DISPLAY_MODE_OFF`, live heart rate in
high power, settings copied only on a change). Date: 2026-10-26 (lit-pixel figures re-run, per circle; code audit re-done). Re-run this report for **every release**
([DEVELOPMENT.md](DEVELOPMENT.md#5-publish-to-the-connect-iq-store), "Battery check").

What drives the battery of a watch face, per Garmin's own documentation:

* Watch faces "run continuously ... a poorly designed watch face - one that takes too long to draw - can greatly degrade the battery
  life"; in sleep mode "execution is restricted to updates once each minute, and cannot use timers or animations"
  (<https://developer.garmin.com/connect-iq/connect-iq-basics/app-types/>).
* After a gesture the face runs in high power "for a short period", with full-screen `onUpdate()` every second, "typically about ten
  seconds", then `onEnterSleep()` (<https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFace.html>).
  `onPartialUpdate()` is the only per-second path in low power and is limited by a power budget (same page;
  `WatchFaceDelegate.onPowerBudgetExceeded`, <https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFaceDelegate.html>).
* AMOLED: every lit pixel draws power; keep the always-on screen mostly black - under 10 % of pixels on, no pixel on for more than
  3 minutes (AMOLED FAQ <https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/>, D-19);
  "Avoid using much white or blue. Consider using light gray instead" and "consider moving elements up to four pixels in any direction
  every minute while in always-on mode" (UX guidelines, Watch Faces, <https://developer.garmin.com/connect-iq/user-experience-guidelines/watch-faces/>, D-43).
* Measuring execution time: simulator *File -> View Profiler*, or a `-k` build on the watch that writes `GARMIN\APPS\LOGS\<app>.PRF`
  (<https://developer.garmin.com/connect-iq/core-topics/profiling/>).

## 1. Method

| Check | Tool | Where it runs |
|---|---|---|
| Static audit (no per-second updates, timers, background, web, sensor listeners, animation; one permission; font load only in the layout cache) | `scripts/battery-audit.sh` | box, CI `static-checks`, `release.yml` |
| AOD burn-in / lit-pixel limits, all 5 sizes x 2 field configurations, 40 min across an hour change | `tests/host/test_burnin.py` (host model of `onUpdate`) | box, CI `static-checks`, `release.yml` |
| Full day (1440 always-on minutes) + active frames, lit pixels / luminance / longest on-run | `CIQ_DEVICE_FONTS=~/.Garmin/ConnectIQ/Fonts python3 tests/host/burnin_report.py 1440` -> `docs/burn-in-report.md` | box (about 5 min) |
| Code audit: what `onUpdate` does per frame and per minute (section 3) | reading `source/` | by hand, every release |
| Execution time per frame / per always-on minute | simulator *File -> View Profiler* | **CI runner (ubuntu-22.04) desktop or a developer PC with the SDK** - not on this box, see section 5 |
| Battery % per day | the watch | **real device**, see section 6 |

The host model (`tests/host/face_model.py`) draws exactly what `NoirTimeView.onUpdate` draws: the real embedded Bebas Neue `.fnt`/`.png`
time fonts glyph by glyph, the date and fields in the device's own RobotoCondensed-Regular (with `CIQ_DEVICE_FONTS`; otherwise a
stand-in, and the numbers would be estimates), the AOD outline, 4 px shift, 70 % digit colour and rotating row mask. Worst case
colours white / white (drawn as `0xB2B2B2` in always-on), steps `88,888`, 24 h clock.

**Denominator (changed 2026-10-26, D-43):** every percentage is now a share of the **round** screen (pixels inside the circle of the
frame's own size), not of the W x H square. Neither the AMOLED FAQ ("10% of the screen pixels") nor
`DeviceSettings.requiresBurnInProtection` ("ten-percent of the total available screen pixels") says which one the system uses on a round
screen; the circle is the smaller denominator, so the figures are the conservative ones. Pixel shares are therefore 4/pi (about 1.27 x)
higher than the D-42 numbers for the same picture; luminance was already per circle.

## 2. Lit pixels (current build, run 2026-10-26, font-accurate, per circle)

`python3 tests/host/burnin_report.py 1440` with `CIQ_DEVICE_FONTS=~/.Garmin/ConnectIQ/Fonts` (device RobotoCondensed-Regular present),
fenix9pro47mm screen (454 x 454). Share of the pixels inside the 454 px circle.

| fields | size | time font | AOD max pixels on | AOD max luminance | AOD longest on-run | active max pixels on | active max luminance |
|---|---|---|---|---|---|---|---|
| steps + Body Battery (default) | Small | TimeFont0 | 3.79 % | 1.66 % | 2 min | 9.07 % | 7.41 % |
| steps + Body Battery (default) | Medium | TimeFont1 | 4.30 % | 1.89 % | 2 min | 12.13 % | 10.42 % |
| steps + Body Battery (default) | Large | TimeFont2 | 4.75 % | 2.15 % | 2 min | 15.95 % | 14.13 % |
| steps + Body Battery (default) | X-Large | TimeFont3 | 5.12 % | 2.33 % | 2 min | 19.18 % | 17.39 % |
| steps + Body Battery (default) | XX-Large | TimeFont4 | 5.47 % | 2.52 % | 2 min | 22.77 % | 20.68 % |
| steps + Body Battery / heart rate | Small | TimeFont0 | 4.19 % | 1.82 % | 2 min | 9.68 % | 7.78 % |
| steps + Body Battery / heart rate | Medium | TimeFont1 | 4.69 % | 2.05 % | 2 min | 12.73 % | 10.79 % |
| steps + Body Battery / heart rate | Large | TimeFont2 | 5.15 % | 2.30 % | 2 min | 16.56 % | 14.50 % |
| steps + Body Battery / heart rate | X-Large | TimeFont3 | 5.50 % | 2.48 % | 2 min | 19.79 % | 17.75 % |
| steps + Body Battery / heart rate | XX-Large | TimeFont3 * | 5.50 % | 2.48 % | 2 min | 19.79 % | 17.75 % |

\* With two field rows the XX-Large font does not fit inside the circle, so the fit check (D-38) falls back to TimeFont3.
AOD: 1440 consecutive one-minute updates; active: 168 frames per row (every hour at :00 :08 :18 :28 :38 :48 :58).

* **Every always-on figure is under the 10 % budget**: worst case **5.50 % pixels on per circle** (4.33 % of the square), 2.52 %
  luminance, no pixel on for more than 2 consecutive minutes (limit 3).
* Luminance fell from 3.36 % (D-42) to 2.52 % because the always-on digits are drawn at 70 % (D-43); the pixel count does not change
  with the colour (any non-black pixel is "on").
* **Real simulator always-on frames, per circle of each frame's own size** (`docs/burn-in-report.md`; frames taken before D-43, so 8 px
  shift and full-brightness digits - the pixel count is representative, the luminance is overstated): worst pixels on per screen size
  **360 px 5.28 %** (fr265s, X-Large white / white), **390 px 4.37 %** (fr165), **416 px 4.67 %** (fenix843mm), **454 px 4.52 %**
  (fenix9pro47mm, X-Large + heart rate + battery), **466 px 4.00 %** (fenix9pro51mm); luminance 1.59 - 3.20 %.
* Active mode lights 9 - 23 % of the circle in white / white (no limit is documented for high power; it lasts about ten seconds after a
  wrist raise). Darker colours and smaller sizes light fewer pixels.

## 3. Code audit (current `source/`, tests excluded)

`scripts/battery-audit.sh` checks the first block automatically (comments stripped); everything else was read in the code.

| Item | Finding | Evidence |
|---|---|---|
| Per-second updates | **None.** No `onPartialUpdate`, so the face never runs per second in low power and has no power budget to exceed. | grep / `battery-audit.sh` |
| Timers / animation | **None** (`Timer`, `WatchUi.animate`, `Attention` absent). | grep |
| Background / temporal events / web | **None** (`Background`, `registerForTemporalEvent`, `ServiceDelegate`, `makeWebRequest`, `Communications` absent). | grep |
| Sensors switched on | **None** (`Sensor.enableSensorEvents` / `setEnabledSensors` / listeners, `Position.enableLocationEvents`, `Complications` subscriptions absent). Only passive reads of values the system already keeps. | grep |
| Permissions | `SensorHistory` only (Body Battery, stress history; required by the SensorHistory API page, D-06). | `manifest.xml:47` |
| Redraw requests | `requestUpdate` only on a settings change and once at each sleep/wake transition. | `NoirTimeApp.mc:33`, `NoirTimeSettingsMenu.mc:43`, `NoirTimeView.mc:572`, `:578` |
| Display off | `System.getDisplayMode() == DISPLAY_MODE_OFF` (API 5.0.0, "Display is off"): `onUpdate` clears and returns - no settings, layout, text or field work, no drawing (as the AMOLED FAQ example's empty `case System.DISPLAY_MODE_OFF`). `(:ciq4)` only; API 3.x has no such mode. Whether the system calls `onUpdate` at all while the display is off is not documented. | `NoirTimeView.mc:104-108`, `:584-593` |
| Settings | Read from `Properties` once into a cache (`reload`, which bumps a generation counter), re-read only on settings change / `onShow`. **Per frame: one generation compare** (`updateSettings`); size, the three resolved field ids (unsupported -> None), colours, colon colour and the dimmed always-on colours are copied into view fields only when the generation changed (D-43). | `NoirSettings.mc:92-107`, `NoirTimeView.mc:511-528` |
| Layout / fonts | `updateLayout` returns at once unless the size or a field slot changed (`key == _layoutKey`); `WatchUi.loadResource` of the Bebas Neue font and `getVectorFont` only there. Only the chosen time font stays referenced. `onShow` resets the key (the date font depends on the system language). | `NoirTimeView.mc:395-441`, `:94-99` |
| Date / time strings, AOD shift | Rebuilt only when the minute changes (`Gregorian.info`, `Lang.format`, `toUpper`, `formatHour`, `format`); the always-on offset is two `Number` lookups (`aodShiftX/Y`) stored in fields, no array per frame (D-43). | `NoirTimeView.mc:536-549`, `NoirLayout.mc:251-257` |
| Field values | Read once per minute (and after a layout or settings change, `onShow` or a wrist raise), and **only for the slots that are shown** (`readFields(_row1/_row2)`); hidden or unsupported fields are never read. | `NoirTimeView.mc:550-554`, `:564-568` |
| **Heart rate in high power (new, D-43)** | If heart rate is shown, each **high-power** frame (about 10 per wrist raise, WatchFace doc) re-reads it (`NoirFields.text(HEART_RATE)`: `Activity.getActivityInfo()`, `getHeartRateHistory(1, true).next()` only if that is null, then a `format` string) and, only if the text changed, re-measures that one field (1 `getTextWidthInPixels`). Not in low power, not when heart rate is not shown, no sensor switched on (passive read). Cost: up to ~10 extra short reads + small strings per wrist raise, in exchange for a live value. | `NoirTimeView.mc:555-561`, `:166-170`, `NoirFields.mc:156-167` |
| Sensor reads | Body Battery / stress: one `SensorHistory.get...History({:period => 1, :order => NEWEST_FIRST})` + one `next()`; heart rate: `Activity.getActivityInfo()`, then only if that is null one `getHeartRateHistory(1, true).next()`; temperature: `Weather.getCurrentConditions()` (cached phone data); steps / calories / floors / intensity / distance: one `ActivityMonitor.getInfo()`. | `NoirSensors.mc:38`, `:53`, `:68`; `NoirFields.mc:113`, `:156-167` |
| Low power path | `onEnterSleep` / `onExitSleep` only set a flag and request one redraw; in always-on the face draws once a minute (system). On AMOLED it draws outlines (digits at 70 %, D-43) + row mask (more draw calls, far fewer lit pixels); MIP keeps the active look. | `NoirTimeView.mc:570-579`, `:118-133` |
| **Per-frame allocation in the field rows (regression, fixed)** | D-39 replaced D-30's cached stats-row width with `drawRow`, which on **every frame** allocated a `widths` array and called `getTextWidthInPixels` once per shown field (up to 3 per frame, ~10 frames per wrist raise, + 1 per AOD minute). **Fixed in D-42:** widths are measured once after the field texts change (`measureFields`) into a preallocated array; `drawRow` no longer allocates a width array (its icons still build their polygon point arrays, next row). Pixel output unchanged (host tests pass). | `NoirTimeView.mc:161-176`, `:185-212` |
| Remaining per-frame work and allocation | `getDisplayMode()`, `getClockTime()` (returns a new `ClockTime` object), the generation and layout-key compares, `has :setAntiAlias`, and the draw calls below. **Not allocation-free** (corrected 2026-10-26; D-42 said "no allocation"): each icon `fillPolygon` builds its point array literal (`[[x, y], ...]`, 1 - 3 per shown icon per frame, e.g. heart, Body Battery, bolt) and the stress icon builds two 6-element `xs` / `ys` arrays; plus whatever the draw calls do internally (not documented). These are a few small short-lived arrays per frame - kept, because caching per-size polygons would cost permanent heap on the 92 kB devices for ~10 frames per wrist raise. The old per-frame `aodShift` array is gone. | `NoirTimeView.mc:101-181`, `:230-272`, `:336` |

### Draw calls per `onUpdate` (454 px screen)

| | active frame | always-on frame (AMOLED) |
|---|---|---|
| `clear` | 1 | 1 |
| time (Bebas Neue bitmap font) | 2 `drawText` | 18 `drawText` (8 offsets + 1 black, x 2) |
| colon | 2 `fillRectangle` | 4 `fillRectangle` |
| date | 1 `drawText` | 1 `drawText` |
| field: steps | 1 `drawText` + 4 `fillEllipse` | same |
| field: Body Battery | 1 `drawText` + `drawArc` + `fillCircle` + `fillPolygon` | same |
| field: heart rate (bottom slot) | 1 `drawText` + 2 `fillCircle` + `fillPolygon` | same |
| row mask | - | 151 - 152 one-pixel `fillRectangle` (every 3rd row) |
| **total, default (steps + Body Battery)** | **14** | **185** (= 33 + 152 mask rows) |
| **total, steps + Body Battery + heart rate** | **18** | **189** |

Other icons: 1 - 5 primitives each (stress = 5 `drawLine`). `getTextWidthInPixels`: 2 - 3 per minute (after the fix), not per frame;
plus 1 in a high-power frame where the shown heart rate changed (D-43). The draw-call counts are unchanged by D-43 (4 px shift and
70 % colour change only coordinates and colours).

## 4. Per-minute work estimate

Worst case (XX-Large or the 3-field layout, AMOLED, always-on):

* **Once per minute:** 1 `onUpdate` with 185 - 189 draw calls (above), of which the expensive part is the 18 big-glyph `drawText` of the
  outline; the text rebuild (`Gregorian.info`, `Lang.format`, 2 small `format`s) and up to 3 field reads (1 - 2 system calls each) plus
  2 - 3 `getTextWidthInPixels`.
* **After a wrist raise:** about 10 active frames x 14 - 18 draw calls; the field values are re-read once at wake (`onExitSleep`);
  a shown heart rate is re-read on each of these frames (D-43).
* **Display off** (`DISPLAY_MODE_OFF`, API 5.0.0 devices): if `onUpdate` is called at all, only `clear` + `getDisplayMode`.
* **Never:** anything per second in sleep, timers, background, radio, sensors switched on.

**Historical figures** - the milliseconds below were measured with an older build (simulator host-CPU times, taken **before** D-38 /
D-39 / D-43, system fonts, no configurable fields) and do **not** describe the current code; they are kept only as an order of
magnitude until the section 5 run replaces them:
D-26 about 28 / 38 / 55 ms per always-on minute (Large / X-Large / XX-Large), D-30 (with the steps + Body Battery row) about 29 ms (Large)
and 66 ms (XX-Large), 14 - 16 ms per active frame.

What changed since then, qualitatively (no new milliseconds can be measured on this box, section 5):
* Same structure: still 18 time-font `drawText` per always-on minute; colon 4 `fillRectangle` instead of 2 circles; same row mask.
* The time font is now an embedded bitmap font at every size. D-26 measured the scalable XX-Large font at about twice the cost of a
  bitmap font in always-on, so XX-Large is expected to be **no worse** than D-30. The glyph sizes per setting are not the old ones,
  and a bigger glyph means more pixels per `drawText`, so per-size costs can shift either way (unmeasured).
* Fields: with the D-42 fix the field row costs what D-30's stats row cost (D-30 measured about 3.6 ms per frame for the steps +
  Body Battery row, mostly the text); a third field adds 1 `drawText` + 2 - 5 primitives per frame and 1 - 2 system calls per minute.
* So the expected order stays tens of milliseconds per always-on minute (about 0.1 % duty cycle or less). This is an estimate, **not a
  measurement** - the profiler run in section 5 replaces it.

## 5. Simulator profiler (GUI) - CI runner / developer PC, not this box

The Connect IQ profiler is part of the simulator GUI (File -> View Profiler) or reads a `.PRF` written by a `-k` build on the watch;
the profiling guide documents **no command-line or headless profiling mode** (<https://developer.garmin.com/connect-iq/core-topics/profiling/>,
checked 2026-10-25), and `monkeydo` in SDK 9.3.0 only offers `-n`, `-a`, `-t`. The power-budget report (`WatchFaceDelegate.onPowerBudgetExceeded`)
only concerns `onPartialUpdate`, which this face does not use. So no profiler is faked in CI.

The SDK 9.3.0 simulator binary needs libwebkit2gtk-4.0 / libsoup-2.4 / libjavascriptcoregtk-4.0 / libjpeg8, which Debian 13 (this
build box) no longer ships; it runs on Ubuntu 22.04 (the CI runner image used by `build.yml` / `release.yml`) or a developer PC with
the SDK Manager. Steps (as in [DEVELOPMENT.md](DEVELOPMENT.md#battery)):

1. Build a profiling PRG: `monkeyc -d fenix9pro47mm -f monkey.jungle -o build/CleanAir-prof.prg -y KEY -l 3 -w -k`.
2. Start the simulator, run the PRG (`monkeydo build/CleanAir-prof.prg fenix9pro47mm`), set white / white, XX-Large, steps + Body Battery
   (+ heart rate for the 2-row case).
3. **File -> View Profiler**, *Start*; about 1 min active, then **Settings > Display Mode > Always-On** for 5+ minutes; *Stop*.
4. Record `onUpdate` calls / average, `drawOutlinedText` total / calls, `drawRow`, `measureFields` (must be called about once per
   minute, not per frame), `updateLayout` (body only on a change), `Gregorian.info` (once per minute). Compare with section 4.
5. On the watch: sideload the `-k` build, wear it, load `GARMIN/APPS/LOGS/CleanAir.PRF` with the profiler's *Load* button.

## 6. Still open

* **GUI profiler ms per minute** for the Bebas Neue + fields build (G-31): needs the simulator GUI (CI ubuntu-22.04 runner with a desktop,
  or a developer PC), section 5.
* **Real drain** (G-15, G-24): charge to 100 %, wear the watch 24 h with a native Garmin face, then 24 h with Clean Air (same always-on
  setting, same activity), compare the battery %. Garmin documents no conversion from profiler time to battery %.
