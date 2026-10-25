# Battery report

Build: `main` after D-38 (embedded Bebas Neue bitmap time font), D-39 - D-41 (three configurable field slots, RobotoCondensed
companion text) and D-42 (field widths cached). Date: 2026-10-25. Re-run this report for **every release**
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
  3 minutes (AMOLED FAQ <https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/>, D-19).
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
stand-in, and the numbers would be estimates), the AOD outline, shift and rotating row mask. Worst case colours white / white,
steps `88,888`, 24 h clock.

## 2. Lit pixels (current build, run 2026-10-25, font-accurate)

`python3 tests/host/burnin_report.py 1440` with `CIQ_DEVICE_FONTS=~/.Garmin/ConnectIQ/Fonts` (device RobotoCondensed-Regular present),
fenix9pro47mm screen (454 x 454). Share of all 454 x 454 pixels.

| fields | size | time font | AOD max pixels on | AOD max luminance | AOD longest on-run | active max pixels on | active max luminance |
|---|---|---|---|---|---|---|---|
| steps + Body Battery (default) | Small | TimeFont0 | 2.98 % | 2.14 % | 2 min | 7.12 % | 7.41 % |
| steps + Body Battery (default) | Medium | TimeFont1 | 3.38 % | 2.46 % | 2 min | 9.53 % | 10.42 % |
| steps + Body Battery (default) | Large | TimeFont2 | 3.74 % | 2.84 % | 2 min | 12.53 % | 14.13 % |
| steps + Body Battery (default) | X-Large | TimeFont3 | 4.03 % | 3.09 % | 2 min | 15.07 % | 17.39 % |
| steps + Body Battery (default) | XX-Large | TimeFont4 | 4.31 % | 3.36 % | 2 min | 17.88 % | 20.68 % |
| steps + Body Battery / heart rate | Small | TimeFont0 | 3.30 % | 2.29 % | 2 min | 7.60 % | 7.78 % |
| steps + Body Battery / heart rate | Medium | TimeFont1 | 3.69 % | 2.61 % | 2 min | 10.00 % | 10.79 % |
| steps + Body Battery / heart rate | Large | TimeFont2 | 4.06 % | 2.99 % | 2 min | 13.00 % | 14.50 % |
| steps + Body Battery / heart rate | X-Large | TimeFont3 | 4.33 % | 3.24 % | 2 min | 15.54 % | 17.75 % |
| steps + Body Battery / heart rate | XX-Large | TimeFont3 * | 4.33 % | 3.24 % | 2 min | 15.54 % | 17.75 % |

\* With two field rows the XX-Large font does not fit inside the circle, so the fit check (D-38) falls back to TimeFont3.
AOD: 1440 consecutive one-minute updates; active: 168 frames per row (every hour at :00 :08 :18 :28 :38 :48 :58).

* **Every always-on figure is under the 10 % budget**: worst case 4.33 % pixels on, 3.36 % luminance, no pixel on for more than 2
  consecutive minutes (limit 3).
* The 17 real simulator always-on frames (`docs/screenshots/aod_*.png`, taken with the Bebas Neue build, D-41) measure 2.52 - 3.55 %
  pixels on and 1.59 - 2.82 % luminance (`docs/burn-in-report.md`).
* The AOD numbers are identical to the `docs/burn-in-report.md` of commit `bc1a983` (the D-38 - D-41 build), i.e. that report was
  already current; it now also has the active-frame table.
* Active mode lights 7 - 18 % of the pixels in white / white (no limit is documented for high power; it lasts about ten seconds after a
  wrist raise). Darker colours and smaller sizes light fewer pixels.

## 3. Code audit (current `source/`, tests excluded)

`scripts/battery-audit.sh` checks the first block automatically (comments stripped); everything else was read in the code.

| Item | Finding | Evidence |
|---|---|---|
| Per-second updates | **None.** No `onPartialUpdate`, so the face never runs per second in low power and has no power budget to exceed. | grep / `battery-audit.sh` |
| Timers / animation | **None** (`Timer`, `WatchUi.animate`, `Attention` absent). | grep |
| Background / temporal events / web | **None** (`Background`, `registerForTemporalEvent`, `ServiceDelegate`, `makeWebRequest`, `Communications` absent). | grep |
| Sensors switched on | **None** (`Sensor.enableSensorEvents` / `setEnabledSensors` / listeners, `Position.enableLocationEvents`, `Complications` subscriptions absent). Only passive reads of values the system already keeps. | grep |
| Permissions | `SensorHistory` only (Body Battery, stress history). | `manifest.xml:47` |
| Redraw requests | `requestUpdate` only on a settings change and once at each sleep/wake transition. | `NoirTimeApp.mc:33`, `NoirTimeSettingsMenu.mc:43`, `NoirTimeView.mc:502`, `:508` |
| Settings | Read from `Properties` once into a cache (`reload`), re-read only on settings change / `onShow`; per frame only the cached getters (`ensureLoaded`). | `NoirSettings.mc:89-103`, `NoirTimeView.mc:73` |
| Layout / fonts | `updateLayout` returns at once unless the size or a field slot changed (`key == _layoutKey`); `WatchUi.loadResource` of the Bebas Neue font and `getVectorFont` only there. Only the chosen time font stays referenced. | `NoirTimeView.mc:357-360`, `:384`, `:409-439` (`getVectorFont`) |
| Date / time strings | Rebuilt only when the minute changes (`Gregorian.info`, `Lang.format`, `toUpper`, `formatHour`, `format`). | `NoirTimeView.mc:474-485` |
| Field values | Read once per minute (and after a layout change, `onShow` or a wrist raise), and **only for the slots that are shown** (`readFields(_row1/_row2)`); hidden or unsupported fields are never read. | `NoirTimeView.mc:486-498`, `NoirSettings.mc:130` |
| Sensor reads | Body Battery / stress: one `SensorHistory.get...History({:period => 1, :order => NEWEST_FIRST})` + one `next()`; heart rate: `Activity.getActivityInfo()`, then only if that is null one `getHeartRateHistory(1, true).next()`; temperature: `Weather.getCurrentConditions()` (cached phone data); steps / calories / floors / intensity / distance: one `ActivityMonitor.getInfo()`. | `NoirSensors.mc:38`, `:53`, `:68`; `NoirFields.mc:113`, `:157-167` |
| Low power path | `onEnterSleep` / `onExitSleep` only set a flag and request one redraw; in always-on the face draws once a minute (system). On AMOLED it draws outlines + row mask (more draw calls, far fewer lit pixels); MIP keeps the active look. | `NoirTimeView.mc:500-509`, `:93` |
| **Per-frame allocation in the field rows (regression, fixed)** | D-39 replaced D-30's cached stats-row width with `drawRow`, which on **every frame** allocated a `widths` array and called `getTextWidthInPixels` once per shown field (up to 3 per frame, ~10 frames per wrist raise, + 1 per AOD minute). **Fixed in D-42:** widths are measured once after the field texts change (`measureFields`) into a preallocated array; `drawRow` now allocates nothing. Pixel output unchanged (host tests pass). | `NoirTimeView.mc:133-137`, `:152-176`, `:490` |
| Remaining per-frame work | `getClockTime()`, three cached setting getters + `isSupported` (`has` checks), the layout-key compare, `has :setAntiAlias`, and the draw calls below. No allocation except what the draw calls do internally (not documented). | `NoirTimeView.mc:79-147` |

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

Other icons: 1 - 5 primitives each (stress = 5 `drawLine`). `getTextWidthInPixels`: 2 - 3 per minute (after the fix), not per frame.

## 4. Per-minute work estimate

Worst case (XX-Large or the 3-field layout, AMOLED, always-on):

* **Once per minute:** 1 `onUpdate` with 185 - 189 draw calls (above), of which the expensive part is the 18 big-glyph `drawText` of the
  outline; the text rebuild (`Gregorian.info`, `Lang.format`, 2 small `format`s) and up to 3 field reads (1 - 2 system calls each) plus
  2 - 3 `getTextWidthInPixels`.
* **After a wrist raise:** about 10 active frames x 14 - 18 draw calls; the field values are re-read once at wake (`onExitSleep`).
* **Never:** anything per second in sleep, timers, background, radio, sensors switched on.

Compared with the last profiler references (simulator host-CPU times, taken **before** D-38 / D-39, so not current):
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

1. Build a profiling PRG: `monkeyc -d fenix9pro47mm -f monkey.jungle -o build/NoirTime-prof.prg -y KEY -l 3 -w -k`.
2. Start the simulator, run the PRG (`monkeydo build/NoirTime-prof.prg fenix9pro47mm`), set white / white, XX-Large, steps + Body Battery
   (+ heart rate for the 2-row case).
3. **File -> View Profiler**, *Start*; about 1 min active, then **Settings > Display Mode > Always-On** for 5+ minutes; *Stop*.
4. Record `onUpdate` calls / average, `drawOutlinedText` total / calls, `drawRow`, `measureFields` (must be called about once per
   minute, not per frame), `updateLayout` (body only on a change), `Gregorian.info` (once per minute). Compare with section 4.
5. On the watch: sideload the `-k` build, wear it, load `GARMIN/APPS/LOGS/NoirTime.PRF` with the profiler's *Load* button.

## 6. Still open

* **GUI profiler ms per minute** for the Bebas Neue + fields build (G-31): needs the simulator GUI (CI ubuntu-22.04 runner with a desktop,
  or a developer PC), section 5.
* **Real drain** (G-15, G-24): charge to 100 %, wear the watch 24 h with a native Garmin face, then 24 h with Noir Time (same always-on
  setting, same activity), compare the battery %. Garmin documents no conversion from profiler time to battery %.
