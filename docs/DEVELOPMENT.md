# Clean Air - developer guide

Everything that does not fit on the short [README](../README.md): project layout, building, testing, battery,
sideloading, CI and publishing. Every technical decision and its official Garmin source: **[DECISIONS.md](../DECISIONS.md)**.

## Project layout

```
manifest.xml            app id, 38 products (fēnix 8 / fēnix 9 / Forerunner, D-36), minApiLevel 3.1.0, permission SensorHistory (Body Battery, stress), languages eng+heb
monkey.jungle           project.manifest + project.typecheck = strict
source/NoirTimeApp.mc   AppBase (settings change -> redraw, getSettingsView -> on-watch menu)
source/NoirSettings.mc  setting keys, values, labels (read/write helpers)
source/NoirTimeSettingsMenu.mc  on-watch settings menu (Menu2)
source/NoirTimeView.mc  the watch face (drawing only, incl. the field icons drawn with Dc primitives)
source/NoirFields.mc    field ids, labels, support check, value text (NoirFormat) - D-39
source/NoirSensors.mc   device-specific readers in annotated variants: Body Battery, stress, weather, battery days, floors
source/NoirLayout.mc    pure layout / AOD helpers (fit check, colon geometry, outline width, shift, row mask) - unit-tested
source/tests/           Connect IQ (:test) unit tests (excluded from normal builds)
tests/host/             host tests (Python): resources vs code, model of the drawing code, AOD burn-in harness; stand-in OFL font
resources/              strings, properties.xml (TimeSize, HourColor, MinuteColor, FieldLeft, FieldRight, FieldBottom), settings.xml, launcher icon 65x65
resources-round-WxH/    generated Bebas Neue time fonts per screen (scripts/make_fonts.py, D-38)
assets/fonts/BebasNeue/ source TTF + SIL OFL 1.1 licence
resources-heb/          Hebrew settings strings
scripts/                keygen.sh, install-sdk.sh, build.sh, run-simulator.sh, run-unit-tests.sh, store-assets.sh, make_fonts.py, battery-audit.sh
.github/workflows/      build.yml  (static checks + host tests; signed build + unit tests + artifacts)
                        release.yml  ("Build store package": manual; signed .iq + store images on a GitHub Release)
store/                  store description, release notes, screenshot checklist
docs/screenshots/       REAL simulator screenshots (SDK 9.3.0, device files + fonts)
docs/burn-in-report.md  real always-on frames + full-day model report (tests/host/burnin_report.py)
docs/battery-report.md  battery report: method, lit pixels, code audit, per-minute work, what is still open (redo every release)
```

## 1. Build locally

### Option A - SDK installed with the community CLI (headless, what CI uses)
```bash
# one-time: read the licence, then note the hash it prints
connect-iq-sdk-manager agreement view         # see scripts/install-sdk.sh for how to install this tool
export CIQ_AGREEMENT_HASH=<hash printed above, only after you have read and agree to the agreement>
export GARMIN_USERNAME=... GARMIN_PASSWORD=...
scripts/install-sdk.sh                         # SDK 9.3.0 + device files of all manifest products; prints the PATH line to add
scripts/keygen.sh                              # creates ~/.connectiq-keys/developer_key.der (BACK IT UP)
scripts/build.sh                               # build/CleanAir.prg + build/CleanAir.iq, strict type check
```

### Option B - official SDK Manager (GUI)
1. Download the SDK Manager from <https://developer.garmin.com/connect-iq/sdk/>, log in with your Garmin account, download **SDK 9.3.0** and the **fēnix® 9 Pro 47mm** device, "Use as SDK".
2. Put the SDK `bin` on `PATH` (Linux: ``export PATH=$PATH:`cat $HOME/.Garmin/ConnectIQ/current-sdk.cfg`/bin``). Java 11+ is required.
3. `scripts/keygen.sh` then `scripts/build.sh` (or use the VS Code "Monkey C" extension: *Monkey C: Build for Device*).

Both scripts only call `monkeyc`; see DECISIONS.md D-12 for the exact flags (`-d fenix9pro47mm -l 3 -w -y <key>`).
**A clean build means: no errors and no warnings from `monkeyc ... -l 3 -w`.** If the strict type checker flags something, fix it before publishing.

## 2. Test in the simulator
```bash
scripts/run-simulator.sh        # builds a debug PRG, starts `connectiq`, runs `monkeydo` on fenix9pro47mm
CIQ_DEVICE=fr255s scripts/run-unit-tests.sh   # unit tests on another product (any id in manifest.xml)
```
Check, and take real screenshots into [`screenshots/`](screenshots/):
1. Time/date/fields centred, nothing cut off by the round edge.
2. Change `TimeSize`, `HourColor`, `MinuteColor` and `FieldLeft` / `FieldRight` / `FieldBottom` (0 - 12, see `source/NoirFields.mc`) with **File > Edit Persistent Storage > Edit Application.Properties data** (documented in the Properties guide) and confirm the face updates. Check all 5 sizes in high power and always-on: nothing may overlap or touch the round edge.
   On-watch menu: the docs say watch-face settings are opened from the system Watch Face menu; check that *Clean Air* offers its settings there, that selecting an item cycles its value, and that Back closes the menu.
3. Always-on: digits must be the same size as in step 2, hollow (outline only); switch to always-on with **Settings > Display Mode > Always-On** (SDK 9.3.0 simulator) and use **File -> View Screen Heat Map** ("Screen Burn-in Simulation", documented in the AMOLED FAQ; enabled only for devices that support burn-in protection).
4. 12h/24h: change the simulated time format.
5. Fields: the docs name **Simulation -> Activity Data** for simulated activity data; check steps with 0, 999, 1 000, 12 345 and 100 000+, and every field id in each slot (two rows: the block moves up and stays inside the circle). A field the device lacks must leave its slot empty.
6. Set the language to Hebrew and look at the date.

## Tests
```bash
python3 -m unittest discover -s tests/host -v          # host tests, no SDK needed (numpy, Pillow, lxml)
CIQ_RESOURCES_XSD=<sdk>/bin/resources.xsd python3 -m unittest discover -s tests/host -v   # + schema validation
CIQ_DEVICE_FONTS=~/.Garmin/ConnectIQ/Fonts python3 tests/host/burnin_report.py   # font-accurate full day + active frames -> docs/burn-in-report.md
scripts/battery-audit.sh                               # static battery audit of source/ + manifest permissions (CI + release)
scripts/run-unit-tests.sh                              # Connect IQ unit tests: monkeyc -t, connectiq, monkeydo -t
                                                       # headless: with no $DISPLAY it starts xvfb-run (+ dbus-run-session) itself;
                                                       # waits up to 60 s for the simulator port, 3 attempts (D-35;
                                                       # CIQ_SIM_READY_TIMEOUT, CIQ_SIM_ATTEMPTS). Simulator needs libwebkit2gtk-4.0 (Ubuntu 22.04)
```
The host model draws the time with the real embedded Bebas Neue fonts. For the date / field text it uses a stand-in OFL font by default; with `CIQ_DEVICE_FONTS` pointing at the fonts the SDK manager downloads
(`device download -d fenix9pro47mm --include-fonts`; not in the repo) it uses the device's own RobotoCondensed-Regular.ttf.
`tests/host/test_screenshots.py` checks the real screenshots (< 10 % pixels/luminance, same digit size in always-on).
Last run: `PASSED (passed=26, failed=0, errors=0)` on 10 devices (D-41); note that `monkeydo -t` exits 1 even then, the script reads the summary.

## Battery
**Full report: [docs/battery-report.md](battery-report.md)** (method, lit-pixel table, code audit with file:line evidence, per-minute work,
what is still open). Battery testing is a **required step of every release** (section 5, "Battery check").

What the face does to keep the drain low (details and doc links: DECISIONS.md D-21, D-42): no `onPartialUpdate`, no timers, no background service,
no sensor listeners, one bitmap time font (graphics pool on API 4+) and the system RobotoCondensed, looked up only when the size or a field changes; settings cached and re-read only when they change; date/time and field strings rebuilt once a minute, field widths measured once a minute (D-42), only shown fields read; in always-on it draws once a minute with at most 4.33 % of the pixels lit (full-day model, all sizes, default and two-row fields; real frames 2.5 - 3.6 %; docs/burn-in-report.md).
Simulator profiler (D-21, D-26, D-30; measured BEFORE the D-38 font / D-39 fields, not re-measured - the GUI simulator does not run on the Debian 13 build box, gap G-31): about 28 / 38 / 55 ms of work per always-on minute for Large / X-Large / XX-Large (D-30 with the stats row: ~29 / ~66 ms Large / XX-Large), about 12 - 16 ms per active frame,
date/time texts rebuilt once a minute, no timers or background; memory now: see D-41. The battery % per day on the watch has not been measured.
How to measure it yourself:
1. Simulator: **File -> View Profiler**, *Start*, let it run through active and always-on minutes, *Stop*; look at `onUpdate` total/average time.
2. Watch: build with `-k` (`monkeyc -d fenix9pro47mm -f monkey.jungle -o build/CleanAir-prof.prg -y KEY -l 3 -w -k`), sideload, use it, then load
   `GARMIN/APPS/LOGS/CleanAir.PRF` with the profiler's *Load* button (Profiling guide).
3. Real drain: charge to 100 %, wear the watch 24 h with a native face, then 24 h with Clean Air (same always-on setting and activity), compare the battery %.

## 3. Install on your watch (sideload)
Per the "Your First App" guide: build the PRG (`build/CleanAir.prg`), connect the watch with USB, and copy it to the watch's `GARMIN/APPS` folder. Eject the watch,
then select *Clean Air* as the watch face using the watch's normal watch-face picker. The Properties/Settings doc says app settings can be changed in the Connect IQ Store app,
the Garmin Connect app or Garmin Express; whether a **sideloaded** app shows its settings there is not stated in the docs I read - check this on your watch. Test on the real watch for a day, especially always-on mode
(the review guidelines say apps must be tested before submission).

## 4. GitHub Actions
`.github/workflows/build.yml` runs on every push to `main`, on tags `v*`, on PRs, and manually.

The `build` job runs in the GitHub Environment **`publish`** (`environment: publish`). Configure once in the repo: create the environment under
**Settings -> Environments -> publish** and store these four as its *environment secrets* (the release workflow uses the same environment):

| Kind | Name | Value |
|---|---|---|
| Secret | `CIQ_AGREEMENT_HASH` | the hash printed by `connect-iq-sdk-manager agreement view` **after you have read the Garmin SDK licence** (at the time of writing: `CC737BBBA104D7740D5BBCF27D0F6382`; check it yourself). Setting it makes CI accept the licence on your behalf. |
| Secret | `GARMIN_USERNAME` | your Garmin account e-mail |
| Secret | `GARMIN_PASSWORD` | its password (consider a dedicated Garmin account) |
| Secret | `CIQ_DEVELOPER_KEY_B64` | contents of `~/.connectiq-keys/developer_key.der.b64` (created by `scripts/keygen.sh`) |

The `build` job installs SDK 9.3.0 + device files, builds with `-l 3 -w`, and uploads `CleanAir.prg` (fenix9pro47mm) and `CleanAir.iq` (all products) as the artifact **CleanAir-fenix9pro47mm**.
The `static-checks` job needs no secrets and also runs the host tests and the **battery check** (`scripts/battery-audit.sh` + `tests/host/test_burnin.py`). The `build` job runs the Connect IQ unit tests under `xvfb`; without the secrets it is skipped with a warning.
Caveats (DECISIONS.md D-03, D-14, gap G-8): the CLI is a third-party tool, and Garmin SSO may require MFA or block CI IPs. If CI login fails, build locally (section 1).

## 5. Publish to the Connect IQ Store
**Build store package** (`.github/workflows/release.yml`, manual *Run workflow* with inputs `version` and `whats_new`): checks the four secrets
(error if one is missing), writes `version` (max 20 characters) into the `version` attribute of `<iq:application>` in `manifest.xml`,
installs the SDK, runs the **battery check** (`scripts/battery-audit.sh` + the AOD burn-in limits test with the device fonts), builds with `scripts/build.sh`, runs the unit tests under `xvfb`, makes store images with `scripts/store-assets.sh`
(`cover.png` 500 x 500 sRGB without transparency on a solid non-black background with 10 px padding, plus every real `docs/screenshots/active_*` / `aod_*`
frame under 150 KB) and creates the GitHub Release `v<version>` with `CleanAir.iq`, `CleanAir.prg` and the images. The run summary has the
upload checklist. It does **not** upload to the store - Garmin documents no API or CLI for that (DECISIONS.md D-31).

### Battery check (required every release)
Do this for **every** release, before uploading the `.iq`, and update [docs/battery-report.md](battery-report.md) with the results:
- [ ] `CIQ_DEVICE_FONTS=~/.Garmin/ConnectIQ/Fonts python3 tests/host/burnin_report.py 1440` - re-run the host burn-in model (about 5 min); commit the regenerated `docs/burn-in-report.md`.
- [ ] Confirm every always-on figure is **< 10 % pixels on** and < 10 % luminance, longest on-run <= 3 min (all sizes, default and two-row fields).
- [ ] `scripts/battery-audit.sh` passes, and re-read the code audit of docs/battery-report.md section 3 for every changed file (no new per-frame allocation, string building or sensor read; reads only for shown fields, once a minute).
- [ ] On a machine where the simulator GUI runs (Ubuntu 22.04 / the SDK Manager on a PC) or on the watch: **File -> View Profiler** run (section "Battery" above, docs/battery-report.md section 5); compare ms per always-on minute with the last release.
- [ ] Before a big change ships: 24 h real-drain comparison on the watch (docs/battery-report.md section 6).

The automatic part (audit + AOD limits) also runs in `build.yml` (every push) and `release.yml` (every store package); a failure stops the release.

By hand:
1. Back up `developer_key.der` - **the same key is needed for every future update**; if lost, the app cannot be updated.
2. Take real simulator/device screenshots (see `store/screenshots.md`).
3. Use the `.iq` file (from the *Build store package* release, the CI artifact or `scripts/build.sh`).
4. Open the Developer Dashboard <https://apps.garmin.com/developer/dashboard> (guide: <https://developer.garmin.com/connect-iq/submit-an-app/>), click *Submit an App* (or upload a new version), type the same version as in `manifest.xml`, upload the `.iq`, paste the text from `store/description.md`, add screenshots/icon, submit.
5. Review typically takes up to 72 hours; you can preview/download the pending app yourself for testing.
Uploading and accepting the developer agreement is an action only you can do under your Garmin developer account.

## Changing things
* Colours / sizes: `resources/settings/settings.xml` (phone) **and** `source/NoirSettings.mc` (watch menu) - keep both lists identical; labels in `resources*/strings/strings.xml`.
  Defaults in `resources/properties/properties.xml` must be one of the list values.
* Time font: edit `SIZE_PERCENT` etc. in `scripts/make_fonts.py`, run `python3 scripts/make_fonts.py` (rewrites `resources-round-*/fonts/`), keep `EDGE_MARGIN` / `OUTLINE_MAX` / `COLON_GAP_PERCENT` equal to `source/NoirLayout.mc` (host test). Fit check: `blockFits()` (D-38).
* Fields: append a new id in `source/NoirFields.mc` (never renumber), add the label strings (English + Hebrew), the list entry in all three field settings, an icon in `NoirTimeView.drawIcon`, and a `sampleText` width (D-39).
* Colon colour rule: `NoirLayout.colonColor()` (D-15).
* Layout / AOD constants: top of `source/NoirLayout.mc` (run the tests after changing them).
* Number formats, 12/24h handling: `NoirFormat` in `source/NoirFields.mc`, `NoirLayout.formatHour()`.

## Licence
[GPL-3.0](../LICENSE) (GNU General Public License v3.0). Third-party: Garmin Connect IQ SDK (Garmin licence), `lindell/connect-iq-sdk-manager-cli` (Apache-2.0, used only in CI); time font Bebas Neue (SIL OFL 1.1, `assets/fonts/BebasNeue/`); test font Roboto (SIL OFL, `tests/host/fonts/`).
