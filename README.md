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
* Always-on mode: smaller, dimmer, and shifted every minute for AMOLED burn-in protection.
* Hebrew + English settings.
* Always-on keeps the time at most `NUMBER_MILD` size whatever the size setting (burn-in limits).

> ### Status - read this first
> The code, resources, scripts and CI were written against the official SDK 9.3.0 documentation, template and sample projects, and
> all resource XML validates against the SDK's schema. **The project has not been compiled yet**: Garmin only serves the
> `fenix9pro47mm` device files to a logged-in Garmin account, and none was available when this was created. So there is
> **no build result and no simulator screenshot yet**, only design mockups in `docs/mockups/` (they are labelled as mockups).
> Your first build is therefore the real test; see [DECISIONS.md](DECISIONS.md) "Open gaps". Everything is set up so that this first build is one command (or one push).

Design decisions and the official source for every technical choice: **[DECISIONS.md](DECISIONS.md)**.

## Project layout

```
manifest.xml            app id, device (fenix9pro47mm), minApiLevel 5.0.0, no permissions, languages eng+heb
monkey.jungle           project.manifest + project.typecheck = strict
source/NoirTimeApp.mc   AppBase (settings change -> redraw, getSettingsView -> on-watch menu)
source/NoirSettings.mc  setting keys, values, labels (read/write helpers)
source/NoirTimeSettingsMenu.mc  on-watch settings menu (Menu2)
source/NoirTimeView.mc  the watch face
resources/              strings, properties.xml (TimeSize, HourColor, MinuteColor), settings.xml (lists), launcher icon 65x65
resources-heb/          Hebrew settings strings
scripts/                keygen.sh, install-sdk.sh, build.sh, run-simulator.sh
.github/workflows/      build.yml  (static checks + signed build + artifacts)
store/                  store description, release notes, screenshot checklist
docs/mockups/           design mockups (NOT simulator screenshots) + docs/tools/make_mockups.py
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
3. Always-on: switch the simulated display to low power (menu not named in the docs I used) and use **File -> View Screen Heat Map** ("Screen Burn-in Simulation", documented in the AMOLED FAQ; enabled only for devices that support burn-in protection).
4. 12h/24h: change the simulated time format.
5. Steps: the docs name **Simulation -> Activity Data** for simulated activity data; check the steps text with 0, 999, 1 000, 12 345 and 100 000+ values.
6. Set the language to Hebrew and look at the date.

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
The `static-checks` job needs no secrets.
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
* Size -> font mapping and the fit check: `timeFontCandidates()` / `fits()` in `source/NoirTimeView.mc` (DECISIONS.md D-17).
* Colon colour rule: `onUpdate()` (D-15).
* Layout constants: top of `source/NoirTimeView.mc`.
* Steps label, 12/24h handling: `stepsText()`, `drawTime()`.

## Licence
No licence file is included; add one that suits you before making the repository public. Third-party: Garmin Connect IQ SDK (Garmin licence), `lindell/connect-iq-sdk-manager-cli` (Apache-2.0, used only in CI).
