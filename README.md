# Noir Time - Garmin fēnix® 9 Pro 47mm watch face

A very simple Connect IQ watch face: **black background, only the date, the time and today's steps.**
Settings (on the phone in Garmin Connect / Connect IQ, **or on the watch** from the Watch Face menu): time size (Small / Medium / Large),
hour colour and minute colour (8 colours each).

```
        Fri 23 Oct
          12:34        <- hours and minutes each in your colour
          8,432
```

* Target: `fenix9pro47mm` (454 x 454 round AMOLED) - nothing else.
* No permissions, no network, no background service.
* Always-on mode: **everything stays the same size**; the hour/minute digits and the colon are drawn as **outlines only**, date and steps dimmer.
  Shifted every minute plus a rotating 1-in-3 row mask for AMOLED burn-in protection (DECISIONS.md D-19/D-23; measured in the simulator 2.1 - 2.7 % of pixels lit, full-day worst case 3.5 %, simulator 24-hour burn-in check: no burn-in).
* Hebrew + English settings.
* Battery-minded: no timers, no partial updates, no sensors/background, settings and texts cached (D-21).

> ### Status - read this first
> * **Device build done:** strict (`-l 3 -w`) build for `fenix9pro47mm` with the real device files (API level 6.0.3), `NoirTime.prg` (21 KB) and
>   store `NoirTime.iq`, no warnings. Connect IQ unit tests in the simulator: **15/15 passed**; 22 host tests pass.
> * **Real simulator screenshots** in [`docs/screenshots/`](docs/screenshots/) (active Small/Medium/Large in two colours, always-on outline digits at
>   full size, 24-hour burn-in check, profiler). `docs/mockups/` are older drawings from the host model and are labelled as mockups.
> * **Still open:** a day on the real watch (battery %), Hebrew date in the simulator, on-watch settings menu behaviour, CI run (DECISIONS.md gaps).

Design decisions and the official source for every technical choice: **[DECISIONS.md](DECISIONS.md)**.

## Project layout

```
manifest.xml            app id, device (fenix9pro47mm), minApiLevel 5.0.0, no permissions, languages eng+heb
monkey.jungle           project.manifest + project.typecheck = strict
source/NoirTimeApp.mc   AppBase (settings change -> redraw, getSettingsView -> on-watch menu)
source/NoirSettings.mc  setting keys, values, labels (read/write helpers)
source/NoirTimeSettingsMenu.mc  on-watch settings menu (Menu2)
source/NoirTimeView.mc  the watch face (drawing only)
source/NoirLayout.mc    pure layout / AOD helpers (fit check, outline width, shift, row mask, formatting) - unit-tested
source/tests/           Connect IQ (:test) unit tests (excluded from normal builds)
tests/host/             host tests (Python): resources vs code, model of the drawing code, AOD burn-in harness; stand-in OFL fonts
resources/              strings, properties.xml (TimeSize, HourColor, MinuteColor), settings.xml (lists), launcher icon 65x65
resources-heb/          Hebrew settings strings
scripts/                keygen.sh, install-sdk.sh, build.sh, run-simulator.sh, run-unit-tests.sh
.github/workflows/      build.yml  (static checks + host tests; signed build + unit tests + artifacts)
store/                  store description, release notes, screenshot checklist
docs/mockups/           design mockups (NOT simulator screenshots) + docs/tools/make_mockups.py
docs/screenshots/       REAL simulator screenshots (SDK 9.3.0, device files + fonts)
docs/burn-in-report.md  real burn-in measurements + font-accurate full-day report (tests/host/burnin_report.py)
```

## 1. Build locally

### Option A - SDK installed with the community CLI (headless, what CI uses)
```bash
# one-time: read the licence, then note the hash it prints
connect-iq-sdk-manager agreement view         # see scripts/install-sdk.sh for how to install this tool
export CIQ_AGREEMENT_HASH=<hash printed above, only after you have read and agree to the agreement>
export GARMIN_USERNAME=... GARMIN_PASSWORD=...
scripts/install-sdk.sh                         # SDK 9.3.0 + fenix9pro47mm device files; prints the PATH line to add
scripts/keygen.sh                              # creates ~/.connectiq-keys/developer_key.der (BACK IT UP)
scripts/build.sh                               # build/NoirTime.prg + build/NoirTime.iq, strict type check
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
```
Check, and take real screenshots into `docs/screenshots/`:
1. Time/date/steps centred, nothing cut off by the round edge.
2. Change `TimeSize`, `HourColor` and `MinuteColor` with **File > Edit Persistent Storage > Edit Application.Properties data** (documented in the Properties guide) and confirm the face updates. Check all 3 sizes in high power and always-on: nothing may overlap or touch the round edge.
   On-watch menu: the docs say watch-face settings are opened from the system Watch Face menu; check that *Noir Time* offers its settings there, that selecting an item cycles its value, and that Back closes the menu.
3. Always-on: digits must be the same size as in step 2, hollow (outline only); switch to always-on with **Settings > Display Mode > Always-On** (SDK 9.3.0 simulator) and use **File -> View Screen Heat Map** ("Screen Burn-in Simulation", documented in the AMOLED FAQ; enabled only for devices that support burn-in protection).
4. 12h/24h: change the simulated time format.
5. Steps: the docs name **Simulation -> Activity Data** for simulated activity data; check the steps text with 0, 999, 1 000, 12 345 and 100 000+ values.
6. Set the language to Hebrew and look at the date.

## Tests
```bash
python3 -m unittest discover -s tests/host -v          # host tests, no SDK needed (numpy, Pillow, lxml)
CIQ_RESOURCES_XSD=<sdk>/bin/resources.xsd python3 -m unittest discover -s tests/host -v   # + schema validation
CIQ_DEVICE_FONTS=~/.Garmin/ConnectIQ/Fonts python3 tests/host/burnin_report.py   # font-accurate full day -> docs/burn-in-report.md
scripts/run-unit-tests.sh                              # Connect IQ unit tests: monkeyc -t, connectiq, monkeydo -t
xvfb-run -a scripts/run-unit-tests.sh                  # same, headless (simulator needs libwebkit2gtk-4.0, e.g. Ubuntu 22.04)
```
The host model uses stand-in OFL fonts by default. With `CIQ_DEVICE_FONTS` pointing at the fonts the SDK manager downloads
(`device download -d fenix9pro47mm --include-fonts`; not in the repo) it uses the device's own TTFs and matches real simulator frames within 0.1 %.
`tests/host/test_screenshots.py` checks the real screenshots (< 10 % pixels/luminance, same digit size in always-on).
Last run: `PASSED (passed=15, failed=0, errors=0)`; note that `monkeydo -t` exits 1 even then, the script reads the summary.

## Battery
What the face does to keep the drain low (details and doc links: DECISIONS.md D-21): no `onPartialUpdate`, no timers, no background service,
no sensors, no permissions, system fonts only; settings cached and re-read only when they change; date/time strings rebuilt once a minute,
the steps string only when the count changes; in always-on it draws once a minute with 2.1 - 2.7 % of the pixels lit (simulator; full-day worst case 3.5 %).
Simulator profiler (D-21): about 28 ms of work per always-on minute, about 12 ms per active frame, date/time texts rebuilt once a minute,
no timers or background; 11.4 kB of memory used. The battery % per day on the watch has not been measured.
How to measure it yourself:
1. Simulator: **File -> View Profiler**, *Start*, let it run through active and always-on minutes, *Stop*; look at `onUpdate` total/average time.
2. Watch: build with `-k` (`monkeyc -d fenix9pro47mm -f monkey.jungle -o build/NoirTime-prof.prg -y KEY -l 3 -w -k`), sideload, use it, then load
   `GARMIN/APPS/LOGS/NoirTime.PRF` with the profiler's *Load* button (Profiling guide).
3. Real drain: charge to 100 %, wear the watch 24 h with a native face, then 24 h with Noir Time (same always-on setting and activity), compare the battery %.

## 3. Install on your watch (sideload)
Per the "Your First App" guide: build the PRG (`build/NoirTime.prg`), connect the watch with USB, and copy it to the watch's `GARMIN/APPS` folder. Eject the watch,
then select *Noir Time* as the watch face using the watch's normal watch-face picker. The Properties/Settings doc says app settings can be changed in the Connect IQ Store app,
the Garmin Connect app or Garmin Express; whether a **sideloaded** app shows its settings there is not stated in the docs I read - check this on your watch. Test on the real watch for a day, especially always-on mode
(the review guidelines say apps must be tested before submission).

## 4. GitHub Actions
`.github/workflows/build.yml` runs on every push to `main`, on tags `v*`, on PRs, and manually.

Configure once in the repo (**Settings -> Secrets and variables -> Actions**):

| Kind | Name | Value |
|---|---|---|
| Variable | `CIQ_AGREEMENT_HASH` | the hash printed by `connect-iq-sdk-manager agreement view` **after you have read the Garmin SDK licence** (at the time of writing: `CC737BBBA104D7740D5BBCF27D0F6382`; check it yourself). Setting it makes CI accept the licence on your behalf. |
| Secret | `GARMIN_USERNAME` | your Garmin account e-mail |
| Secret | `GARMIN_PASSWORD` | its password (consider a dedicated Garmin account) |
| Secret | `CIQ_DEVELOPER_KEY_B64` | contents of `~/.connectiq-keys/developer_key.der.b64` (created by `scripts/keygen.sh`) |

The `build` job installs SDK 9.3.0 + device files, builds with `-l 3 -w`, and uploads `NoirTime.prg` and `NoirTime.iq` as the artifact **NoirTime-fenix9pro47mm**.
The `static-checks` job needs no secrets and also runs the host tests. The `build` job runs the Connect IQ unit tests under `xvfb`; without the secrets it is skipped with a warning.
Caveats (DECISIONS.md D-03, D-14, gap G-8): the CLI is a third-party tool, and Garmin SSO may require MFA or block CI IPs. If CI login fails, build locally (section 1).

## 5. Publish to the Connect IQ Store
1. Back up `developer_key.der` - **the same key is needed for every future update**; if lost, the app cannot be updated.
2. Take real simulator/device screenshots (see `store/screenshots.md`).
3. Use the `.iq` file (`build/NoirTime.iq`, from CI artifact or `scripts/build.sh`).
4. Go to <https://developer.garmin.com/connect-iq/submit-an-app/>, click *Submit an App*, upload the `.iq`, paste the text from `store/description.md`, add screenshots/icon, submit.
5. Review typically takes up to 72 hours; you can preview/download the pending app yourself for testing.
Uploading and accepting the developer agreement is an action only you can do under your Garmin developer account.

## Changing things
* Colours / sizes: `resources/settings/settings.xml` (phone) **and** `source/NoirSettings.mc` (watch menu) - keep both lists identical; labels in `resources*/strings/strings.xml`.
  Defaults in `resources/properties/properties.xml` must be one of the list values.
* Size -> font mapping and the fit check: `fontCandidates()` / `blockFits()` in `source/NoirLayout.mc` (DECISIONS.md D-17, D-20).
* Colon colour rule: `NoirLayout.colonColor()` (D-15).
* Layout / AOD constants: top of `source/NoirLayout.mc` (run the tests after changing them).
* Steps label, 12/24h handling: `NoirLayout.formatSteps()`, `formatHour()`.

## Licence
No licence file is included; add one that suits you before making the repository public. Third-party: Garmin Connect IQ SDK (Garmin licence), `lindell/connect-iq-sdk-manager-cli` (Apache-2.0, used only in CI); test fonts Rajdhani and Roboto (SIL OFL, `tests/host/fonts/`).
