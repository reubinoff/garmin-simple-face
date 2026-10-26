# DECISIONS.md

Every technical decision in this project, the official source it was checked against, and how far it has been verified.

**Rule used:** a decision is only recorded as *VERIFIED* when it is backed by a Garmin document, by a file in the
official SDK (`connectiq-sdk-lin-9.3.0-2026-10-20-95888f262.zip`), or by running an official tool.
Anything else is marked **UNVERIFIED** and listed in [Open gaps](#open-gaps). Nothing was guessed to fill a gap.

Status legend: **VERIFIED-DOC** (Garmin documentation), **VERIFIED-SDK** (file shipped in the SDK / official tool run),
**VERIFIED-ON-BOX** (run in this project's creation session), **UNVERIFIED** (see gaps).

URL base: `https://developer.garmin.com/connect-iq/`. The same pages ship inside the SDK under `doc/` (HTML),
which is what was actually read when the page itself is JavaScript-rendered.

---

## D-01 Target device: `fenix9pro47mm` (fēnix® 9 Pro 47mm)

*Extended by D-36: the manifest now lists 38 products; fenix9pro47mm stays the reference device (layout constants, default PRG and tests).*

| Fact | Value | Source |
|---|---|---|
| Product id (used in `manifest.xml`, `monkeyc -d`) | `fenix9pro47mm` | `device-reference/fenix9pro47mm/` (also `sdk/doc/docs/Device_Reference/fenix9pro47mm.html`) |
| Screen | round, **454 x 454** | same page, "Screen Shape / Screen Size" |
| Display colours | 65 536 (16-bit) | same page |
| Touch / buttons | touch, buttons enter, up, menu, down, esc | same page |
| Launcher icon size | **65 x 65** | same page |
| Memory limit, Watch Face | **131 072 bytes** | same page, "App Types" table |
| Languages | ara bul ces dan deu dut eng est fin fre gre **heb** hrv hun ind ita lav lit nob pol ron rus slo slv spa swe tur ukr zsm (plus vie, zhs/zht, jpn, kor, tha font groups) | same page |
| Fonts (px): XTINY 37, SMALL 53, NUMBER_MILD 113, NUMBER_MEDIUM 153, NUMBER_HOT 173, NUMBER_THAI_HOT 210 (Rajdhani); Noto Sans Hebrew present | | same page, "Fonts" |

Status: VERIFIED-DOC.
The 43 mm and 51 mm fēnix 9 Pro variants are separate products (`fenix9pro43mm`, `fenix9pro51mm` appear in the device list) and are
deliberately **not** targeted: the brief is the 47 mm model only, and layout/fonts are tuned from the 47 mm data above.

## D-02 SDK version: Connect IQ SDK 9.3.0

Latest release at the time of writing (2026-10-20): `connectiq-sdk-lin-9.3.0-2026-10-20-95888f262.zip`, downloaded from the
official SDK page `sdk/`. `monkeyc --version` prints `Connect IQ Compiler version: 9.3.0` (VERIFIED-ON-BOX).
Status: VERIFIED-SDK. `scripts/install-sdk.sh` pins `9.3.0` (override with `CIQ_SDK_VERSION`).

## D-03 SDK install in CI: community CLI instead of the official GUI SDK Manager  ⚠ DEVIATION

* Official route: the **Connect IQ SDK Manager** (GUI) - `connect-iq-basics/getting-started/` ("Press the Login button and enter the
  credentials of the Connect account"). The Linux build needs a desktop (WebKit etc.) and was not runnable headless.
* Used instead: `lindell/connect-iq-sdk-manager-cli` **v0.8.4** (Apache-2.0, third party, **not Garmin software**), pinned.
  It downloads the SDK and the device files from Garmin's servers with the same Garmin login. Commands and flags were taken from the
  tool's own `--help` output (note: the flag is `--agreement-hash`, not `--acceptance-hash` as its README says).
* Why it matters: you are giving a third-party binary your Garmin credentials in CI. If you do not want that, build locally with the
  official SDK Manager (README, "Option B").
Status: VERIFIED-ON-BOX end to end (2026-10-24): agreement accepted by hash, login, SDK 9.3.0, `device download -d fenix9pro47mm --include-fonts` (D-23).

## D-04 `minApiLevel="5.0.0"`

Manifest: `core-topics/manifest-and-permissions/` ("minApiLevel ... only the major and minor versions are considered").
Highest API level among the APIs used (from the API docs, "Since: API Level"):

| API | Since |
|---|---|
| `System.getDisplayMode()`, `System.DISPLAY_MODE_LOW_POWER` | **5.0.0** (listed as supported on fēnix® 9 Pro 47mm) |
| `Dc.setAntiAlias()` | 3.2.0 (listed as supported on fēnix® 9 Pro 47mm) |
| `AppBase.getSettingsView()` | 3.2.0 (listed as supported on fēnix® 9 Pro 47mm) |
| `WatchUi.Menu2`, `MenuItem`, `Menu2InputDelegate` (`addItem`, `findItemById`, `updateItem`, `getId`, `setSubLabel`, `onSelect`) | 3.0.0 (all three pages list fēnix® 9 Pro 47mm) |
| `Application.Properties.getValue()` / `setValue()` | 2.4.0 |
| `ActivityMonitor.getInfo()`, `Info.steps`, `Gregorian.info`, `System.getClockTime`, `Dc.getTextDimensions/getTextWidthInPixels/getFontHeight/drawText/fillCircle/setColor` | 1.0.0 |
| `DeviceSettings.requiresBurnInProtection` (not used in code; documents the rule) | 3.0.12 |

The device's own API level is stored in the device files (`compiler.json`), which are behind a Garmin login (gap G-1). The compiler checks
`minApiLevel` against the device and the strict type checker reports use of APIs above it ("Improve typecheck diagnostics when using APIs
that do not meet the target device's minimum API level" - SDK release notes). Status: VERIFIED-DOC for the number; compatibility with the device **VERIFIED-SDK**: the device files' `compiler.json` give `connectIQVersion` 6.0.3 (deviceGroup "API level 6.0"), and the strict device build passes (D-23).

## D-05 App type, manifest shape

* `type="watchface"`, `entry="NoirTimeApp"`, `launcherIcon="@Drawables.LauncherIcon"`, manifest `version="3"` - copied from the SDK's own
  template `sdk/bin/templates/watchface/settings/manifest.xml` and the shipped sample `samples/ConfigurableWatchFace/manifest.xml`.
* App id: random UUID v4 (`9399663f-6b22-455f-82d9-4c1ff991f0f2`), same format as the sample. Do not change after the first store upload.
* `<iq:languages>`: `eng` + `heb` (`resources-heb/` holds the Hebrew settings strings). Language codes are the ones the device page lists.
* `project.typecheck = strict` in `monkey.jungle` - same line as the shipped sample (`samples/ConfigurableWatchFace/monkey.jungle`); the build
  scripts additionally pass `-l 3` ("3 = strict", `monkey-c/compiler-options/`).
Status: VERIFIED-SDK.

## D-06 Permissions: `SensorHistory` only (was: none; changed by D-27)

The permission table in `core-topics/manifest-and-permissions/` lists Ant, AudioInput/Output, Background, BluetoothLowEnergy, Communications,
ComplicationProvider/Subscriber, DataFieldAlert, Fit, PersistedContent, Positioning, Sensor, SensorHistory, SensorLogging, UserProfile.
`ActivityMonitor`, `Time`, `System`, `Graphics`, `WatchUi`, `Application.Properties` are not in it. Since D-27 (Body Battery) the manifest declares
exactly one permission, `<iq:uses-permission id="SensorHistory"/>` (SDK `bin/projectInfo.xml`: id `SensorHistory`, "Permission to access historical
sensor data", module `SensorHistory`, listed for the `watchface` app type). No other permission is used. Status: VERIFIED-DOC + VERIFIED-SDK.

## D-07 Data sources (all permission-free, all API 1.0.0)

| Need | API | Notes (from the API docs) |
|---|---|---|
| Time | `System.getClockTime()` -> `ClockTime.hour/min` | local time |
| 12/24 h | `System.getDeviceSettings().is24Hour` | follows the watch setting |
| Date | `Time.Gregorian.info(Time.now(), Time.FORMAT_MEDIUM)` | `FORMAT_MEDIUM` gives localised short strings (day of week / month) |
| Steps | `ActivityMonitor.getInfo().steps` | "step count since midnight for the current day"; **may be null** -> shown as `--` |
Status: VERIFIED-DOC (`api-docs/Toybox/System.html`, `.../ActivityMonitor/Info.html`, `.../Time/Gregorian.html`, `.../System/DeviceSettings.html`).

## D-08 User settings: time size, hour colour, minute colour

* Schema follows `core-topics/properties-and-app-settings/` (<https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/>) and the
  SDK template `resources/settings/{properties,settings}.xml`. Three `number` properties, each shown as a `list` setting:

  | Property | Values | Default |
  |---|---|---|
  | `TimeSize` | 0 Small, 1 Medium, 2 Large, 3 X-Large, 4 XX-Large (D-24) | 1 (Medium) |
  | `HourColor` | 16 colours (D-25), `listEntry value` = `0xRRGGBB` | `0xFFFFFF` white |
  | `MinuteColor` | same 16 colours | `0xFFFFFF` white |

* Read with `Application.Properties.getValue(key)` and (on-device menu, D-16) written with `Properties.setValue(key, value)`; both API 2.4.0 and both throw
  if the key is not defined (<https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Properties.html>), so every key is in `properties.xml`.
  `source/NoirSettings.mc` is the single code-side definition (keys, values, labels); it falls back to the default if a stored value is not a `Number`.
* The value lists exist twice (settings.xml for the phone, `NoirSettings.mc` for the watch menu) because a settings list is not readable from code per the docs read;
  a check script compared both lists on the box (identical).
* Settings are **cached** in `NoirSettings` (read once, D-21). The cache is refreshed by `AppBase.onSettingsChanged()` (phone change; then `WatchUi.requestUpdate()`,
  as in the AppBase doc example), by the on-device menu right after its own `Properties.setValue`, and in `NoirTimeView.onShow()`. So a menu change is shown even if the
  system does not call `onSettingsChanged()` after an on-device change (not documented, G-12).
* The colours (8, extended to 16 in D-25) are my design choice (bright, saturated, readable on black). The display has 65 536 colours (D-01) so colours are quantised
  to RGB565 by the hardware; not viewed on a real screen.
* Simulator testing: "File > Edit Persistent Storage > Edit Application.Properties data" (documented in the same page, section "Testing App Settings").
* All `resources*/**/*.xml` validate against `sdk/bin/resources.xsd` (VERIFIED-ON-BOX, `lxml` XMLSchema).
Status: VERIFIED-DOC / VERIFIED-SDK; runtime behaviour **UNVERIFIED** (needs device/simulator).

## D-09 Always-on (low power) mode and AMOLED burn-in

Rules (primary sources):
* `DeviceSettings.requiresBurnInProtection` (`api-docs/Toybox/System/DeviceSettings.html`): at most **10 % of pixels** on at once; no pixel on for more than
  **3 update cycles at 1/min**; if violated "all screen pixels will be turned off until the device goes into high-power mode".
* AMOLED FAQ (`connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/`): from Venu 2 the rule is "less than 10 % of the screen's luminance"; recommends thin fonts,
  shifting the time every minute, no static marks; use `System.getDisplayMode()` to detect low power. The simulator has *File -> View Screen Heat Map* to test.
* `WatchFace` doc: in low power `onUpdate()` is called once a minute; `onEnterSleep()/onExitSleep()` mark transitions.
* The docs do not say which of the two rules (pixel-count or luminance) the fēnix 9 Pro applies, so the design satisfies **both**.

What the code does in low power: **superseded by D-19** (same size as active mode, outline-only digits, shift + rotating row mask).
The earlier design (time capped at `NUMBER_MILD` at 60 % brightness, `FONT_XTINY` date/steps) was replaced on the owner's request.
* `onPartialUpdate` is **not** implemented: the FAQ says per-second partial updates are "no longer allowed" on AMOLED (<https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/>).
Status: rules VERIFIED-DOC; compliance VERIFIED-ON-BOX in the real simulator (24-Hour burn-in simulation: no burn-in detected, D-23).

## D-10 Rendering approach

* All coordinates are derived from `dc.getWidth()/getHeight()` and font heights; nothing is hard-coded to 454.
* Time font: chosen from the size setting with a fit check against the round screen (D-17, D-20); cached and recomputed only when the size setting
  changes, and **identical in active and always-on mode** (D-19).
* The colon is drawn with two `fillCircle` calls: the docs do not state that the number-only fonts contain ":" (gap G-4), so it is not relied on.
* `dc.setAntiAlias(true)` for the circles (guarded with `has`, per the Dc doc); switched off for the AOD row mask (D-19).
* Colon is fixed at the screen centre; hours are right-aligned to it, minutes left-aligned, so the colon never jumps.
* Steps are shown as a number only (thousands separator) - design choice, in `NoirLayout.formatSteps()` (`--` when `steps` is null).
* The vertical position of the colon dots (`fontHeight * 14 %`) assumes the digits are vertically centred in the font box. This is **UNVERIFIED** (gap G-3); check in the simulator.
Status: API usage VERIFIED-DOC; visual result VERIFIED-ON-BOX in the simulator with the device fonts (`docs/screenshots/`, D-23): colon dots sit centred between the digits, outline glyphs are clean and hollow.

## D-11 Language / Hebrew

The device page lists `heb` and the font `Noto Sans Hebrew`. The date uses `Time.FORMAT_MEDIUM`, which returns the watch's language. Whether the day/month
render correctly in Hebrew (RTL ordering of `"$1$ $2$ $3$"`) is **UNVERIFIED** (gap G-5). Settings strings exist in English and Hebrew.

## D-12 Build, run, sign, export

| Step | Command | Source |
|---|---|---|
| Developer key (RSA 4096, DER) | `openssl genrsa -out developer_key.pem 4096` + `openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt` | `reference-guides/monkey-c-command-line-setup/` ; `connect-iq-basics/getting-started/` ("must be a RSA 4096 bit private key") |
| Build PRG | `monkeyc -d fenix9pro47mm -f monkey.jungle -o build/CleanAir.prg -y KEY -l 3 -w -r` | `monkey-c/compiler-options/` (`-d -f -o -y -l -w -r`) |
| Export for the store | `monkeyc -e -f monkey.jungle -o build/CleanAir.iq -y KEY -l 3 -w` | `-e / --package-app` ("IQ file for uploading to the app store"); the community CLI README uses the same form |
| Simulator | `connectiq` then `monkeydo build/x.prg fenix9pro47mm` | command-line setup page |
| Sideload | copy the `.prg` to the watch's `GARMIN/APPS` directory | `connect-iq-basics/your-first-app/` |
| Java | 11 or higher (docs); box run used Temurin 21 and `monkeyc` 9.3.0 started fine | command-line setup page; VERIFIED-ON-BOX |
| Linux | docs footnote: "Connect IQ only supports Ubuntu Linux distributions" -> CI uses Ubuntu (`ubuntu-24.04` for checks, `ubuntu-22.04` for the SDK job, D-22) | getting-started page |

Open point: the docs do not say whether the VS Code "Export Project" adds `-r`. The IQ build here omits `-r` (the documented form); compare file size / behaviour if the store rejects it (gap G-6).
Keep the developer key: "You will need to use the same key to sign updates to an existing app on the store. If you lose your original signing key you will not be able to update your app." (getting-started page).

## D-13 Store submission

* Flow: upload the `.iq` at "Submit an App" (`submit-an-app/`, `core-topics/publishing-to-the-store/`), fill description + screenshots; review "within 72 hours" typically.
* Guidelines (`app-review-guidelines/`): test before submitting; describe accurately; list supported devices accurately; no claim of Garmin partnership; own all IP in icons/images.
* Screenshot size/count requirements for the listing form are **not in the documentation I could read** (gap G-7): `store/` only contains suggestions.

## D-14 CI (GitHub Actions)

* Job `static-checks` (no secrets): XML well-formedness, `bash -n` on scripts, host tests (D-22), no key files tracked.
* Job `build` (skipped with a warning when secrets are missing): Java 21, Go (to `go install` the pinned CLI), `scripts/install-sdk.sh`, key from secret `CIQ_DEVELOPER_KEY_B64`, `scripts/build.sh`, Connect IQ unit tests under `xvfb`, upload `CleanAir.prg` and `CleanAir.iq` as an artifact.
* `CIQ_AGREEMENT_HASH` is read from `secrets` (it was `vars` before 2026-10-25). Job `build` runs in the GitHub Environment `publish` (`environment: publish`, added 2026-10-25): the owner stores `GARMIN_USERNAME`, `GARMIN_PASSWORD`, `CIQ_DEVELOPER_KEY_B64` as environment secrets there; `static-checks` has no environment.
* Garmin does not document a CI procedure; Garmin login in CI is therefore a **community pattern** (D-03). Risk: Garmin SSO may require MFA or block datacenter IPs (gap G-8).
* Action majors (`checkout@v7`, `setup-java@v6`, `setup-go@v7`, `upload-artifact@v7`) are the existing latest majors as of 2026-10-23 (checked via the GitHub API/tags).
* The workflow never prints the key or password; the key is written to `$RUNNER_TEMP` and is not uploaded.

---

## D-15 Separate hour and minute colours; colon colour

* Owner request: hours and minutes colourable separately. `drawTime()` already drew hours and minutes as two `drawText` calls (hours right-aligned to the colon,
  minutes left-aligned), so each simply gets its own `dc.setColor` (`Dc.setColor`, API 1.0.0, <https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html>).
* **Colon colour (design choice):** if hour colour == minute colour, the colon uses that colour (the default all-white face looks exactly as before);
  if they differ, the colon is the neutral grey of the date/steps text (`0xB0B0B0`), so it does not "belong" to either half. In always-on mode it is drawn as an outline ring (D-19).
* Same palette for both (16 colours since D-25). Status: API VERIFIED-DOC; look **UNVERIFIED** (mockups only).

## D-16 On-device settings: `AppBase.getSettingsView()` + `Menu2` (implemented); native watch face editor (evaluated, not implemented)

Doc findings:
* **`AppBase.getSettingsView()`** - "Since API level 3.2.0", "only applicable to watch faces and data fields"; returns `[Views] or [Views, InputDelegates] or Null`;
  the fēnix® 9 Pro 47mm is in its "Supported Devices" list. <https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html>
* Properties guide, section "On Device Watch Face and Data Field Settings" (since 3.2.0): watch faces may not accept input or push views themselves, but may implement
  `getSettingsView()`, which "functions similarly to `getInitialView()`"; "Watch face configuration is available to the user in the system Watch Face menu."
  <https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/>
* SDK sample `samples/Analog` (a watch face) implements `getSettingsView()` (a View + BehaviorDelegate whose `onMenu()` pushes a `Menu2`).
* **Native watch face editor / `WatchFaceConfig`** - "Since API level 5.1.0. The fēnix 8 and newer wearables have an on-device watch face editor"; a `<watchface-config>`
  resource defines styles, complications ("Data"), data colours and accent colours; read with `WatchFaceConfig.getSettings(null)`; editor hooks
  `WatchFaceDelegate.onTap / getComplicationDrawable / onWatchFaceConfigEdited` (5.1.0); up to four saved configurations per face.
  <https://developer.garmin.com/connect-iq/core-topics/editing-watch-faces-on-device/>, <https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/WatchFaceConfig.html>
  (the `WatchFaceConfig` page lists the fēnix® 9 Pro 47mm). All URLs above returned HTTP 200 on 2026-10-24.

Decision:
* **Implemented `getSettingsView()`** returning `[NoirTimeSettingsMenu (a WatchUi.Menu2), NoirTimeSettingsDelegate (a WatchUi.Menu2InputDelegate)]`.
  Types: `Menu2` inherits from `WatchUi.View`, and the SDK's `InputDelegates` typedef includes `Menu2InputDelegate` (WatchUi.html), so the pair matches the documented return type.
  I return the menu directly instead of the sample's "Press Menu for settings" screen - one less step, same documented types.
  Menu: `Menu2.initialize({:title})`, `addItem`, `findItemById`, `updateItem`; `MenuItem(label, subLabel, identifier, options)`, `getId`, `setSubLabel` (all API 3.0.0).
  <https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/Menu2.html>, <https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/MenuItem.html>,
  <https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/Menu2InputDelegate.html>
* Items: Time Size, Hour Color, Minute Color; each shows the current value as its sub-label. **Selecting an item cycles to the next value** and saves it with
  `Properties.setValue` (the same properties the phone edits, so phone and watch settings never disagree).
  Why cycling instead of sub-menus: `WatchUi.popView()` is documented to throw `OperationNotAllowedException` "if called from ... watch face app", and the guide says
  watch faces may not push views; whether that also applies inside the settings view is **not documented**. Cycling needs no `pushView`/`popView` at all.
  Back is left to the documented default: "If not overridden, `onBack()` will pop the active view."
* **Not implemented: `WatchFaceConfig`**. Reasons: (1) its model is styles / complication data / one data colour / one accent colour - hour colour, minute colour and
  size would have to be mapped onto "accent" and "data" colours and "styles", i.e. a re-interpretation of fields the docs define for other purposes; (2) it is a second,
  separate settings store (per saved configuration) next to the phone properties, and the docs do not say how the two interact; (3) the face has no complications;
  (4) it needs API 5.1.0, while the device's API level is not stated (G-9) and `minApiLevel` is 5.0.0. It can be added later behind `has` checks.
Status: VERIFIED-DOC; menu location on the watch and behaviour **UNVERIFIED** (G-11, G-12).

## D-17 Time size Small / Medium / Large, fit check (X-Large / XX-Large and the digit-box fit: D-24)

Font heights on the fēnix® 9 Pro 47mm (device reference page): `FONT_LARGE` 71, `NUMBER_MILD` 113, `NUMBER_MEDIUM` 153, `NUMBER_HOT` 173, `NUMBER_THAI_HOT` 210 px;
`FONT_SMALL` 53 and `FONT_XTINY` 37 px for date/steps.

| Setting | Candidates, first that fits (same in active and always-on mode, D-19) |
|---|---|
| Small | `NUMBER_MILD`, `LARGE` |
| Medium (default) | `NUMBER_MEDIUM`, `NUMBER_MILD` |
| Large | `NUMBER_HOT`, `NUMBER_MEDIUM`, `NUMBER_MILD` (since D-24; before: `THAI_HOT` first, which never fitted) |
| X-Large (D-24) | `NUMBER_THAI_HOT`, `NUMBER_HOT`, `NUMBER_MEDIUM`, `NUMBER_MILD` |
| XX-Large (D-24) | scalable `RobotoCondensedRegular` (fallback `BionicMedium`), largest px 240..180 that fits; else as X-Large |

* **Fit check** (`NoirLayout.blockFits()`, D-20): rows are stacked date / time / steps with 3 % spacing, so they never overlap by construction. A font is accepted only if
  the corners of the time box (`2 x width("00") + colon gap` wide, font height tall) and of the date and steps boxes are inside the circle of radius `width/2 - 12 px`.
  Widths are measured with `Dc.getTextWidthInPixels` and heights with `Dc.getFontHeight` (API 1.0.0) on the real device fonts at run time; integer maths only.
  The date box uses the sample "Wed 30 Sep" and the steps box "100,000"; a longer localised date could still be wider (G-13).
* So "Large" means "the largest that fits"; on this screen it may end up the same as Medium - the docs give heights but no glyph widths, so which one wins is not knowable before running (G-13).
* **Always-on** uses the same font as active mode (owner request, D-19); the 12 px edge margin covers the 8 px AOD shift plus the 3 px maximum outline (tested).
Status: API VERIFIED-DOC; actual sizes VERIFIED-ON-BOX (D-23; font names from the fit check with the device fonts, which reproduces the real glyph heights): Small = `FONT_NUMBER_MILD`, Medium = `FONT_NUMBER_MEDIUM`, Large = `FONT_NUMBER_HOT` (`FONT_NUMBER_THAI_HOT` did not fit with the full-line-height check; with the digit-box check of D-24 it fits and is X-Large), all distinct; a long Hebrew date is still open (G-13).

## D-18 Migration from `TimeColor`

* The old `TimeColor` property is removed; `HourColor` and `MinuteColor` default to its old default (white), so the default face is unchanged.
* No value migration code: the app has never been published or installed on a watch, so no user has a stored `TimeColor`. The docs read do not say
  what happens to stored values of a removed property after an app update, so if this matters later, keep the old key and copy it once (`Properties.getValue`/`setValue`).
Status: design decision; based on the project state, not on runtime behaviour.

## D-19 Always-on: same size as active mode, outline-only digits, shift + rotating row mask

Owner request: "in always-on everything stays the same size, only the digits are not filled but outlines only".

Limits that apply (primary sources):
* AMOLED FAQ <https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/>: "a pixel is considered on when rendering any color other than black"; "if more than 10% of the screen pixels are on or any pixel is on for
  longer than 3 minutes, the system will shut off the screen"; "Since the Venu 2, the rule for always-on is to use less than 10% of the screen's luminance";
  recommends a thin font and shifting the time every minute; test with *File -> View Screen Heat Map* (24 h simulation).
* UX guidelines, Watch Faces (<https://developer.garmin.com/connect-iq/user-experience-guidelines/watch-faces/>): always-on "will only update every minute, and each update
  is limited to using 10% of the available pixels".
* `DeviceSettings.requiresBurnInProtection` (<https://developer.garmin.com/connect-iq/api-docs/Toybox/System/DeviceSettings.html>).

How the outline is drawn (only documented API 1.0.0 calls, <https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html>):
* No outline/hollow system font is documented, and `Dc.setStroke` (4.0.0) is for primitives, so the outline is made with text: `setColor(colour, COLOR_TRANSPARENT)`,
  `drawText` at the 8 neighbour offsets x `w` px, then `drawText` once in **black** at the real position. This leaves a ring `w` px wide around each glyph and the glyph
  interior black. `w = clamp(fontHeight / 64, 2, 3)` (`NoirLayout.outlineWidth`). Colour = the user's hour/minute colour at full value (thin lines are already dim).
* Colon: `drawCircle` with `setPenWidth(w)` (API 1.0.0) instead of `fillCircle`.
* Date and steps: same `FONT_SMALL` size as active mode, filled, dimmer grey `0x6E6E6E` (active `0xB0B0B0`).
* Layout and font are **identical** to active mode (same `updateLayout()` result); the fit check includes the outline width (D-20).

Burn-in protection:
* Whole block shifted +/-8 px each minute on a 4-phase cycle (`NoirLayout.aodShift`, FAQ recommendation).
* **Row mask:** after drawing, every 3rd screen row (`y % 3 == minute % 3`, `NoirLayout.maskFirstRow`) is set black with 1 px `fillRectangle` over the whole width,
  anti-aliasing off. Every pixel is therefore black at least once in any 3 consecutive minutes **whatever the real glyph shapes are**. Reason: with the shift alone
  the host model found pixels on for 10 consecutive minutes (overlapping strokes of different digits / the date row). Cost: about 152 `fillRectangle` per minute.
* Model results (`docs/burn-in-report.md`, full 24 h, white/white = worst case; stand-in fonts, so **estimates**): max pixels on 2.7 % (Small) / 3.2 % (Medium) /
  3.4 % (Large) with the "line" font-size mapping, 4.0 % with the pessimistic "digit" mapping; max luminance 1.8 - 3.0 %; longest run 2 minutes. Limits: 10 %, 10 %, 3 min.
Status: rules VERIFIED-DOC; drawing API VERIFIED-DOC; numbers VERIFIED-ON-BOX in the real simulator and font-accurate model (D-23). A watch run is still advisable.

## D-20 Fit check includes the outline

`NoirLayout.blockFits(screen, timeHeight, digitHalf, digitsWidth, smallHeight, dateWidth, stepsWidth, pad)` (since D-24 with `digitHalf`, the half-height of the digit ink box): the time box is enlarged by `pad` = outline width on each side and
the corners must be inside the circle of radius `screen/2 - 12`. Same check for both modes, so always-on never needs a smaller font. Status: unit-tested (D-22).

## D-21 Battery

(Re-checked for X-Large / XX-Large and the 16-colour palette in D-26.)

Documented facts:
* Watch faces "run continuously ... A poorly designed watch face - one that takes too long to draw - can greatly degrade the battery life"; they "cannot access the compass,
  GPS, or other sensors" (<https://developer.garmin.com/connect-iq/connect-iq-basics/app-types/>).
* Update rate: sleep mode = updates "once each minute", no timers or animations; after a wrist raise `onUpdate` every second for "typically about ten seconds", then
  `onEnterSleep()` (same page and <https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFace.html>).
* AMOLED: "every pixel draws power ... you want to have as much black on screen as possible" (AMOLED FAQ <https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/>).
* "Watchdog Tripped: A Monkey C function has executed for too long" (<https://developer.garmin.com/connect-iq/monkey-c/exceptions-and-errors/>).
* Measuring: simulator *File -> View Profiler*; on the watch build with `-k`, the run writes `GARMIN\APPS\LOGS\<app>.PRF`, which the profiler can load
  (<https://developer.garmin.com/connect-iq/core-topics/profiling/>).

Review of this face:

| Item | Finding / change |
|---|---|
| Update frequency | Only the system-driven `onUpdate`; **no** `onPartialUpdate`, **no** `Timer`, no animation -> no per-second work in sleep. |
| Background / sensors / permissions | None (`<iq:permissions/>` empty, no background service, no sensor/GPS, no web requests). |
| Fonts / resources | System fonts only (`Graphics.FONT_*`); no `loadResource`, no custom font, no bitmap in the face. |
| Settings | **Changed:** were read with `Properties.getValue` 3x per `onUpdate`; now cached in `NoirSettings`, re-read only on `onSettingsChanged`, after a menu change and in `onShow`. |
| Layout | Font choice + metrics (`getFontHeight`, `getTextWidthInPixels`) computed once per size setting and cached. |
| Texts | **Changed:** date (`Gregorian.info`, `Lang.format`), hour/minute strings and the 12/24 h flag rebuilt once per minute; steps string only when the count changes. Per frame only `getClockTime`, `ActivityMonitor.getInfo()` (documented API; its cost is not documented) and the draw calls. |
| Active mode | ~6 draw calls per frame, about 10 frames after each wrist raise. |
| Always-on | 18 `drawText` (outline) + 2 `drawCircle` + 2 `drawText` + ~152 one-pixel `fillRectangle`, **once a minute**; 2.7 - 4 % of pixels lit (model), the rest black. |

Simulator profiler run (profiling build `-k`, Large white/white, about 11 min of mixed active and always-on, File > View Profiler; `docs/screenshots/profiler_large_white-white.png`):

| Measured (simulator, host CPU microseconds) | Value |
|---|---|
| `onUpdate` calls / total / average | 145 / 1,891,700 us / 13,046 us |
| Always-on frames (`drawRowMask`, `aodShift` calls) | 9; `drawOutlinedText` 18 calls, average 11,629 us -> about 28 ms per always-on minute |
| Active frames | 136; about 12 ms each |
| Text rebuilds (`Gregorian.info`, `formatHour`, `Lang.format`) | 9 each = once per minute, not per frame (cache works) |
| Settings reads | `ensureLoaded` 435 calls at 1.6 us (cached), no `Properties.getValue` per frame |
| `requestUpdate` / timers / background | 1 (settings) / none / none |
| Runtime memory (simulator status bar) | 11.4 kB of 123.8 kB |

So in always-on the face works about 28 ms per minute (< 0.05 % duty) and in active mode only during the documented ~10 s after a wrist raise. These are simulator times on the host CPU: Garmin does not document a conversion to watch time or battery percent, so the drain per day on the watch is still not measured (G-15, narrowed). No sign of anything that would drain the battery: no per-second work, no sensors, no network.
Status: rules VERIFIED-DOC; code review and simulator profile VERIFIED-ON-BOX; battery % per day on the watch **UNVERIFIED** (G-15).

## D-22 Tests and compile verification

* **Connect IQ unit tests** (`source/tests/NoirTests.mc`: `(:test)` functions taking a `Logger`, `Toybox.Test` asserts; Unit Testing guide
  <https://developer.garmin.com/connect-iq/core-topics/unit-testing/>): settings parsing (invalid/null -> defaults), palette/labels, index/cycle maths, a real
  `Properties.setValue` round trip, font candidates, fit maths, colon geometry/colour, outline width, AOD shift (incl. margin >= shift + outline), row mask, step and hour
  formatting incl. `null`. Build `monkeyc ... -t`, run `connectiq` + `monkeydo <prg> fenix9pro47mm -t` (`scripts/run-unit-tests.sh`). Tests are left out of normal builds
  (checked: no test names in the normal PRG).
* **Host tests** (`tests/host`, Python `unittest` + numpy/Pillow/lxml): resources vs. code (property keys, palette, sizes, defaults, en/heb string-id parity,
  used/defined ids, manifest), `resources.xsd` validation (when `CIQ_RESOURCES_XSD` is set), a Python port of `NoirLayout` that **re-runs the simple assertions from
  `NoirTests.mc`**, and the AOD harness (same size as active, hollow digits, < 10 % pixels, < 10 % luminance, no pixel on > 3 min).
* **CI:** host tests in `static-checks` (always); SDK build + unit tests (under `xvfb`) in `build`, only when the Garmin secrets exist, on `ubuntu-22.04` because the SDK
  simulator links `libwebkit2gtk-4.0` (`ldd sdk/bin/simulator`), which newer Ubuntu/Debian no longer ship.
* **Compile without device files:** `monkeyc -f monkey.jungle -o X.prg -y KEY -l 3 -w` (no `-d`) warns "Invalid device id found in the application manifest:
  'fenix9pro47mm'" and prints `BUILD SUCCESSFUL`. It runs the parser, symbol resolution and the strict type checker against the SDK API (checked by injecting an
  undefined symbol and a type error: both fail the build). It does **not** check device-specific things (device API level, memory limit, device fonts).
  `-d fenix9pro47mm` and `-e` fail with "Invalid device id specified" / "Device id 'fenix9pro47mm' listed in the manifest file is not recognized" until the device files are installed.
Status: host tests VERIFIED-ON-BOX (23 tests: 22 pass + 1 skipped without `CIQ_RESOURCES_XSD`, with stand-in and with device fonts); device build and simulator unit tests VERIFIED-ON-BOX (17/17 pass since D-24; 15/15 in D-23).

## D-23 Device build, simulator run, real screenshots and burn-in measurement (2026-10-24)

* **Device files:** `connect-iq-sdk-manager agreement accept --agreement-hash=...`, `login` (account from the environment, never stored in the repo),
  `sdk set 9.3.0`, `device download -d fenix9pro47mm --include-fonts`. The CLI keeps its token in `~/.Garmin/ConnectIQ/token.json` on the build machine only.
  `compiler.json`: connectIQVersion 6.0.3, watchFace memory 131072 bytes, 454 x 454 round AMOLED, 16 bpp. `simulator.json`: number fonts are
  `Bionic_Medium.ttf`, small/large `Roboto-Regular.ttf` (downloaded with `--include-fonts`; Garmin files, not committed).
* **Strict device build** `scripts/build.sh` (`monkeyc -d fenix9pro47mm ... -l 3 -w -r` and `monkeyc -e ... -l 3 -w`): `BUILD SUCCESSFUL`, no warnings.
  `--build-stats`: code 3994 B, data 1703 B, PRG 21116 B; `.iq` 16740 B. Simulator status bar at runtime: 11.4 kB used of 123.8 kB.
* **Unit tests:** `xvfb-run -a scripts/run-unit-tests.sh` -> `PASSED (passed=15, failed=0, errors=0)`. `monkeydo -t` exits 1 even when all tests pass (observed,
  not documented), so the script judges by the printed summary. The script now also stops the `simulator` child of `connectiq`.
* **Simulator on Debian 13 (box only, not needed on Ubuntu 22.04 CI):** `libwebkit2gtk-4.0-37` and its deps from Debian 12 into a private library dir,
  `libjpeg.so.8` built from libjpeg-turbo 3.0.4, and a FreeType 2.13.3 built with `-Wl,-Bsymbolic` because the `simulator` binary exports its own
  `TT_New_Context`/`FT_*` symbols and the system libfreetype crashed in `TT_New_Context` (gdb backtrace). The simulator also needs the device fonts:
  without `--include-fonts` it crashes as soon as a watch face draws text.
* **Always-on in the simulator:** *Settings > Display Mode > Always-On*. Screenshots (real simulator frames, 454 x 454 crop of the screen area, bezel
  corners visible outside the round screen): `docs/screenshots/active_*.png`, `aod_*.png`, `simulator_window_small.png`. Each colour/size variant was
  built with different property defaults (the app code is unchanged).
* **Burn-in, real:** pixels on 2.12 / 2.34 / 2.67 / 2.49 % and luminance 1.38 / 1.52 / 2.07 / 2.01 % (Small white/cyan, Medium white/orange, Large
  yellow/white, Large white/white). *File > View Screen Heat Map > 24-Hour Simulation*: "24-Hour simulation finished, no screen burn-in detected", peak
  luminance usage 1.19 / 1.51 / 1.82 / 1.98 % (`docs/screenshots/burnin24h_*.png`). Limits: AMOLED FAQ <https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/>.
* **Burn-in, font-accurate full day:** the host model with the device TTFs (`CIQ_DEVICE_FONTS`) matches the real frames within 0.1 percentage point and
  the "line" font-size mapping (identical glyph heights). Worst case over 1440 minutes, white/white, steps 88,888: 2.75 / 3.13 / 3.47 % pixels on,
  1.85 / 2.27 / 2.56 % luminance, no pixel on for more than 2 consecutive minutes (`docs/burn-in-report.md`). The "digit" mapping (old worst case 4.03 %) is ruled out.
* **Same size in always-on:** the time block is 57/77/87 px tall active and 62/82/91 px always-on (outline adds about 2 px each side): same font
  (`tests/host/test_screenshots.py`).
Status: VERIFIED-ON-BOX.

## D-24 Bigger sizes: X-Large and XX-Large (2026-10-24)

Owner request: "is it possible to have bigger sizes?". Two sizes added above Large; Small/Medium/Large look exactly as before.

| Setting (`TimeSize`) | Font | Source |
|---|---|---|
| 3 X-Large ("גדול מאוד") | `Graphics.FONT_NUMBER_THAI_HOT` - the largest system number font, 210 px (`Bionic_Medium`) | device reference font table <https://developer.garmin.com/connect-iq/device-reference/fenix9pro47mm/> |
| 4 XX-Large ("ענק") | scalable `RobotoCondensedRegular` via `Graphics.getVectorFont({:face => ["RobotoCondensedRegular", "BionicMedium"], :size => px})`, largest px from 240 down to 180 (step 4) that fits; on the simulator 208 px | Graphics API <https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics.html#getVectorFont-instance_function>, VectorFont <https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/VectorFont.html>, Core Topics "Scalable Fonts" <https://developer.garmin.com/connect-iq/core-topics/graphics/> |

Doc facts used:
* `getVectorFont(options)`: "Since API Level 4.2.1" (the Core Topics page says 4.2.2), returns `VectorFont or Null`; the fēnix® 9 Pro 47mm is in its supported-device list.
  The face may be an Array of names, "backup font faces that are acceptable ... in case the device doesn't support your preferred choice"; "Scalable fonts work with `Dc.drawText()`".
  Scalable faces must be "published in the Device Reference as Scalable Font entries": the fēnix 9 Pro 47mm page lists `RobotoCondensedRegular` (Roboto Condensed, Scalable) and `BionicMedium` (Scalable, `Bionic_Medium`).
  Device API level 6.0.3 (`compiler.json`) > 4.2.1, and the code still guards with `Graphics has :getVectorFont` and falls back to the X-Large list if it returns `null`.
* `FontType` includes `VectorFont`, so `getFontHeight`, `getTextWidthInPixels`, `Graphics.getFontAscent/Descent` and `drawText` take it (Graphics/Dc API pages).
* All URLs above returned HTTP 200 on 2026-10-24.

Why these fonts (measured on the box):
* The screen is width-limited: "00:00" must fit inside the round screen next to the date and steps rows. A Bionic vector font would only reach about 226 px
  (+7 % over THAI_HOT). Roboto Condensed is narrower per pixel of digit height: its digits fill ~62 % of the font height and "00" is 0.84 x the font height
  (1.35 x the digit height), Bionic ~50 % and 0.78 x (1.56 x the digit height). So its digits are the tallest that fit: **digit height ~ 128-130 px (XX-Large) vs. ~106 px (X-Large) and ~88 px (Large)** in the real simulator frames
  (`docs/screenshots/active_x*large_*.png`). Regular (not Bold) matches the thin Bionic look and keeps the always-on outline thin.
* **Fit check changed (D-17/D-20):** the old check used the full font line height for the time box. The digits only fill part of the box
  (measured from the device TTFs: Bionic_Medium ink top/bottom 27.5 % / 22.9 % of the font height around the centre; Roboto Condensed 32.3 % / 30 %),
  so THAI_HOT was rejected although its digits fit. `NoirLayout.blockFits()` now takes the digit half-height (`digitHalfHeight(fontHeight, 28 %)` for the
  number fonts, 33 % for Roboto Condensed, both rounded up and above the measured value) plus the outline pad for the time corners; rows are still stacked on the full
  font heights, so nothing can overlap. With this check, Small/Medium/Large still pick MILD/MEDIUM/HOT (Large's list no longer starts with THAI_HOT, which now belongs to X-Large).
* The vector-font search and all metrics run only when the size setting changes (`updateLayout` cache, D-21); it calls `getVectorFont` at most 16 times once.
* Memory: simulator status bar 12.2 kB (X-Large) / 12.3 kB (XX-Large) of 123.8 kB; `--build-stats`: code 4465 B, data 1990 B, PRG 22,268 B (limit for watch faces 131,072 B, `compiler.json`).
  Scalable fonts live in the graphics pool (`simulator.json` `graphicsResourcePoolSize` 3,145,728), not in the app heap.
* Always-on keeps the same font (D-19): the outline is 3 px for both new sizes (`outlineWidth`), the AOD shift/row mask are unchanged.
* Burn-in for the new sizes (real simulator, Always-On frames): X-Large 3.76 - 3.78 % pixels / 2.21 - 3.48 % luminance, XX-Large 3.66 - 3.93 % / 2.24 - 3.37 %;
  24-Hour Simulation (white/white, worst case) "no screen burn-in detected", peak luminance 3.22 % (X-Large) and 3.41 % (XX-Large) (`docs/screenshots/burnin24h_x*large_white-white.png`).
  Font-accurate full-day model (white/white, steps 88,888): X-Large 4.80 % pixels / 4.03 % luminance, XX-Large 5.01 % / 4.27 %, no pixel on > 2 consecutive minutes. Limits 10 % / 10 % / 3 min.
* Tests: `testFontCandidates`, `testXxlSearch`, `testVectorFontAvailable`, `testBlockFits` (simulator) and the host fit/monotonic/digit-height tests cover the new sizes.
Status: API VERIFIED-DOC; sizes, fit, burn-in and memory VERIFIED-ON-BOX (simulator with the device fonts); look on the real watch **UNVERIFIED**.

## D-25 Palette: 16 colours

* `HourColor` / `MinuteColor` now offer 16 named colours (English + Hebrew labels): White 0xFFFFFF, Silver 0xC8C8C8, Red 0xFF453A, Coral 0xFF7A5C, Orange 0xFF9500,
  Gold 0xFFB800, Yellow 0xFFD60A, Lime 0xB4F000, Green 0x30E060, Teal 0x00C9A7, Cyan 0x00D4FF, Light Blue 0x6FB8FF, Blue 0x2E6BFF, Purple 0xB388FF,
  Magenta 0xFF2BD6, Pink 0xFF4FA0. The 8 earlier values are unchanged, so stored settings stay valid. Same list in `settings.xml` (phone) and
  `NoirSettings.colorValues()` (watch menu), checked by a host test.
* Colour depth: `Dc.setColor()` takes "a 24-bit RRGGBB value" (Core Topics Graphics <https://developer.garmin.com/connect-iq/core-topics/graphics/>, Dc API
  <https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html>); the device reference lists "Display Colors 65536" and `compiler.json` 16 bits per pixel,
  so the display shows each colour quantised to RGB565. A host test checks all 16 values are valid non-zero 24-bit values **and still distinct after RGB565 quantisation**.
  Not documented: the exact rounding the device uses (the test assumes truncation to 5/6/5 bits).
* Always-on uses the chosen colour for the outline (D-19); see `docs/screenshots/aod_xlarge_lime-magenta.png`, `aod_xxlarge_gold-blue.png`.
* On-watch menu: selecting Hour/Minute Color still cycles to the next value (D-16), now through 16 values. A sub-menu would be quicker to use, but `pushView` from a watch
  face settings view is not clearly documented as allowed (D-16), so it was not changed.
Status: VERIFIED-DOC (24-bit API, 65,536 colours); on-watch colour appearance **UNVERIFIED**.

## D-26 Battery re-check for the new sizes and palette (2026-10-24)

Rules re-read (all HTTP 200 on 2026-10-24):
* Watch faces "run continuously ... A poorly designed watch face - one that takes too long to draw - can greatly degrade the battery life", and they
  "cannot access the compass, GPS, or other sensors" (<https://developer.garmin.com/connect-iq/connect-iq-basics/app-types/>).
* In sleep the face is updated "once each minute", no timers/animations; after a wrist raise every second for "typically about ten seconds"
  (<https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFace.html>). `onPartialUpdate` per-second updates are "no longer allowed" on AMOLED
  and every lit pixel draws power (AMOLED FAQ <https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/>).
* Measuring with the simulator profiler and `-k` builds (<https://developer.garmin.com/connect-iq/core-topics/profiling/>).

Code check (grep on `source/`, tests excluded): no `Timer`, no `onPartialUpdate`, no background service, no `Sensor`/`Position`/web request, no
`loadResource`; `<iq:permissions/>` empty; `Properties.getValue` only in `NoirSettings.reload()` (cached); `requestUpdate` only after a settings change
(phone or watch menu) and on enter/exit sleep (one redraw at each mode change). The palette change adds nothing at run time (a colour is a `Number`). The XX-Large vector font is looked up once per size change
(`chooseVectorFont` called once in the profile, 0.47 ms total), never per frame.

Simulator profiler (profiling builds `-k`, white/white = brightest, about 1 min active then about 7 min Always-On, *File > View Profiler*;
`docs/screenshots/profiler_xlarge_white-white.png`, `profiler_xxlarge_white-white.png`, `profiler_xxlarge_white-white_api.png`):

| Measured (simulator, host CPU) | Large (D-21) | X-Large | XX-Large |
|---|---|---|---|
| `onUpdate` calls / average | 145 / 13.0 ms | 63 / 14.8 ms | 64 / 19.8 ms |
| Always-on frames | 9 | 7 | 8 |
| Outline drawing per always-on frame (`drawOutlinedText` x 2) | 23 ms | 31 ms | 48 ms |
| Work per always-on minute (outline + row mask 1.9 ms + clear 2.5 ms + date/steps) | ~28 ms | ~38 ms | ~55 ms |
| Per active frame | ~12 ms | ~12 ms | ~15 ms |
| `Dc.drawText` average | - | - | 2.66 ms (384 calls) |
| Text rebuilds (`Gregorian.info`, `Lang.format`) | once per minute | once per minute | once per minute |
| Runtime memory (status bar) | 11.4 kB | 12.2 kB | 12.3 kB of 123.8 kB |

Reading: bigger glyphs cost more to draw, and the scalable font about twice the bitmap font in always-on (18 large `drawText` per minute for the outline).
Still about 55 ms per minute = < 0.1 % duty in always-on, nothing per second, no sensors, no radio. These are simulator (host CPU) times; Garmin documents no
conversion to watch time or battery %, so the daily drain on the watch is still **UNVERIFIED** (G-15). Smaller sizes stay as cheap as before.
Possible further saving, **not done** (changes the look, owner decision): draw the outline from 4 instead of 8 offsets (about 45 % fewer `drawText` in always-on,
slightly thinner diagonal edges); or choose Large/X-Large instead of XX-Large for the lowest always-on cost.
Status: rules VERIFIED-DOC; code check and profiles VERIFIED-ON-BOX; watch battery % UNVERIFIED.

## D-27 Body Battery: `SensorHistory.getBodyBatteryHistory` (2026-10-25)

* API: `Toybox.SensorHistory.getBodyBatteryHistory(options)`, "Since: API Level 3.3.0"; the fēnix® 9 Pro 47mm is in its Supported Devices list
  (<https://developer.garmin.com/connect-iq/api-docs/Toybox/SensorHistory.html>). The module needs the `SensorHistory` permission (D-06,
  <https://developer.garmin.com/connect-iq/core-topics/manifest-and-permissions/>).
* Returns a `SensorHistoryIterator`; `next()` gives a `SensorSample` or `null`
  (<https://developer.garmin.com/connect-iq/api-docs/Toybox/SensorHistory/SensorHistoryIterator.html>); `SensorSample.data` is `Number`, `Float` or `null`
  (<https://developer.garmin.com/connect-iq/api-docs/Toybox/SensorHistory/SensorSample.html>).
* Code (`source/NoirBodyBattery.mc`): guarded with `Toybox has :SensorHistory && SensorHistory has :getBodyBatteryHistory`; call
  `{:period => 1, :order => ORDER_NEWEST_FIRST}` = only the newest sample; `NoirLayout.parseBodyBattery` rounds a Float, drops values outside 0-100 and
  `null`, and the face shows `--` then. Read only when the field is shown and at most once per minute (not per frame, not per second).
* Alternative evaluated, not used: `Toybox.Complications` `COMPLICATION_TYPE_BODY_BATTERY` (API 4.2.0, fēnix 9 Pro supported,
  <https://developer.garmin.com/connect-iq/api-docs/Toybox/Complications.html>). It needs the `ComplicationSubscriber` permission and a subscription /
  callback; the history read is simpler and is a single call per minute.
* Simulator: unit test `testBodyBatteryApiOnDevice` read **88** from the simulator; screenshots show 88. Status: VERIFIED-DOC, VERIFIED-SDK, VERIFIED-ON-BOX (simulator);
  value on the real watch UNVERIFIED (G-18).

## D-28 Steps and Body Battery icons: vector drawing with `Dc` primitives; adaptive stats font (2026-10-25)

* Icons are drawn, not bitmaps: `fillEllipse`, `fillPolygon`, `drawRoundedRectangle`, `fillRectangle`, `setPenWidth` (all API 1.0.0,
  <https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html>; `fillPolygon` max 64 points, the bolt uses 6). Steps = two footprints
  (forefoot + heel ellipses), Body Battery = ~~battery outline with cap and a lightning bolt~~ (replaced by D-34: figure with raised arms in an open gauge ring). Size follows the row font
  (icon height 60 % of the font height), colour = the date/stats grey; no resource loads, nothing extra in memory.
* Always-on: the icons use the same grey and the same shift + row mask as the text (D-19).
* Both values in one row would have needed a smaller time font on XX-Large. So the time font is chosen against the smallest stats font (`FONT_XTINY`)
  and the toggles never change the time size; then the stats font is the largest of `FONT_SMALL`, `FONT_TINY`, `FONT_XTINY` that still fits
  (`NoirLayout.statsFontCandidates()`, `statsRowWidth()`, 9-argument `blockFits()`). Result (model + simulator): Small/Medium `FONT_SMALL`, Large
  `FONT_TINY`, X-Large `FONT_XTINY`, XX-Large `FONT_TINY`; with only steps shown, `FONT_SMALL` at every size. Status: VERIFIED-DOC, VERIFIED-ON-BOX.

## D-29 Show/hide toggles: `ShowSteps`, `ShowBodyBattery` (2026-10-25)

* Properties `ShowSteps` and `ShowBodyBattery`, `type="boolean"`, default `true`; phone settings `<settingConfig type="boolean"/>`
  (<https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/>). Titles EN "Show Steps" / "Show Body Battery", HE
  "הצג צעדים" / "הצג Body Battery".
* On the watch: two `WatchUi.ToggleMenuItem` (API 3.0.0, allowed in watch faces,
  <https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/ToggleMenuItem.html>) in the existing Menu2 (D-16), sub-labels On/Off
  (`{:enabled, :disabled}`); `onSelect` stores `isEnabled()` with `Properties.setValue` and redraws.
* A hidden field is not read at all (`ActivityMonitor.getInfo()` / `getBodyBatteryHistory` skipped). With both hidden the stats row disappears.
  If the watch has no Body Battery API the field is hidden automatically. A non-boolean stored value counts as `true` (`NoirSettings.parseFlag`).
* Tests: `testParseFlag`, `testToggleFlagsRoundTrip` (simulator), host `test_show_hide_toggles`, `test_toggles_do_not_change_time_font`.
  Status: VERIFIED-DOC, VERIFIED-ON-BOX (simulator); menu on the real watch UNVERIFIED (G-11/G-12).

## D-30 Battery re-check after the icons, Body Battery and toggles (2026-10-25)

Rules as in D-21 / D-26 (WatchFace update rate <https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFace.html>, AMOLED FAQ
<https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/>, profiler
<https://developer.garmin.com/connect-iq/core-topics/profiling/>).

What the new features add:
* Body Battery: one `getBodyBatteryHistory` call with `:period => 1`, at most once per minute and only when the field is shown. No sensor,
  no timer, no background, no `Complications` subscription.
* Hidden fields are not read at all.
* Icons are `Dc` primitives (no bitmap resources). The stats-row width is cached and rebuilt only when the text or layout changes.
* Unchanged from D-21 / D-26: no `onPartialUpdate`, no `Timer`; `ActivityMonitor.getInfo()` once per frame (about 0.02 ms).

Simulator profiler (`-k`, white/white = brightest, steps + Body Battery shown, about 1 min active then 5-6 min Always-On; screenshots
`docs/screenshots/profiler_large_white-white*.png`, `profiler_xxlarge_white-white*.png`):

| Measured (simulator, host CPU) | Large (D-26 → now) | XX-Large (D-26 → now) |
|---|---|---|
| `onUpdate` calls / average | 145 / 13.0 ms → 62 / 16.0 ms | 64 / 19.8 ms → 67 / 21.0 ms |
| `drawStatsRow` per frame (text + both icons) | - → 3.66 ms | - → 3.63 ms |
| of which `drawStepsIcon` / `drawBodyBatteryIcon` | - → 0.45 / 0.33 ms | - → 0.44 / 0.33 ms |
| `getBodyBatteryHistory` + `next()` | - → 7 calls in ~7 min, 0.011 + 0.007 ms | - → 7 calls, 0.013 + 0.006 ms |
| `Gregorian.info` / `Lang.format` | once per minute | once per minute |
| Work per always-on minute (outline + mask 1.8 ms + clear 2.4 ms + date/stats) | ~28 → ~29 ms | ~55 → ~66 ms |
| Per active frame | ~12 → ~14 ms | ~15 → ~16 ms |
| Runtime memory (status bar) | 11.4 → 15.3 kB | 12.3 → 15.5 kB of 123.8 kB |

How to read this: the new stats row adds about 3.6 ms per frame, which is about 4 ms per always-on minute, and most of that is the text, not the
icons (under 1 ms). XX-Large always-on goes from about 55 to about 66 ms per minute, still about 0.1 % duty cycle. Nothing runs per second,
there are no sensors and no radio. Memory is about 3 kB higher (new code; no bitmaps).

Hiding a field skips its drawing and its data read (screenshots `*_no-*`). These are simulator times on the host CPU; the battery % per day on
the watch is still **UNVERIFIED** (G-15).

Burn-in re-run, real simulator:
* Always-On frames, all sizes: 2.6-4.4 % pixels on, 1.6-3.9 % luminance.
* 24-hour heat map: Large white/white 2.15 %, XX-Large white/white 3.57 % peak luminance, "no screen burn-in detected" for both
  (`docs/burn-in-report.md`, `burnin24h_large_white-white.png`, `burnin24h_xxlarge_white-white.png`).

Status: VERIFIED-DOC (rules), VERIFIED-ON-BOX (profile, burn-in); watch battery UNVERIFIED.

## D-31 Store release: "Build store package" workflow, manual upload (2026-10-25)

* Garmin's publishing guide describes only uploading the `.iq` to the Connect IQ Store by hand, then adding description and screenshots, then
  review (<https://developer.garmin.com/connect-iq/submit-an-app/>). None of the Garmin pages or SDK files read for this project document an API or
  CLI for uploading or submitting. The Developer Dashboard <https://apps.garmin.com/developer/dashboard> is behind the Garmin login (it redirects to
  `sso.garmin.com`, checked 2026-10-25). So the workflow does **not** upload anything.
* `.github/workflows/release.yml` ("Build store package", `workflow_dispatch` with inputs `version` and `whats_new`, `permissions: contents: write`,
  job `package` on `ubuntu-22.04` in environment `publish`): it fails if a secret is missing, checks that the version matches `manifest.xml`,
  installs the SDK, writes the key to `$RUNNER_TEMP`, runs `scripts/build.sh` (strict `-l 3 -w`, `.prg` + `.iq`) and the unit tests under `xvfb`,
  makes the store images with `scripts/store-assets.sh` (warnings only), then runs `gh release create v<version>` with the `.iq`, `.prg` and
  images. It uses `gh` from the runner, not a third-party release action. The step summary has the manual upload checklist.
* Version guard: the SDK's own sample manifests carry `version="x.y.z"` on `<iq:application>` (e.g. `samples/*/manifest.xml` in SDK 9.3.0), so
  `version="1.0.0"` was added to `manifest.xml`; the build accepts it. The store asks for a version when you upload. The workflow stops if the
  input differs from the manifest or is longer than 20 characters. The 20-character limit comes from the owner's brief; I did not find it in the
  Garmin pages I read (G-20).
* Secrets: build.yml and release.yml read `GARMIN_USERNAME`, `GARMIN_PASSWORD`, `CIQ_AGREEMENT_HASH` (changed from a repository variable to a
  secret on 2026-10-25) and `CIQ_DEVELOPER_KEY_B64` from the `publish` environment. Inputs reach the shell only through `env`, never as
  `${{ }}` inside scripts. The key is never printed or uploaded.
* Checked here: YAML parses, every `run:` block passes `bash -n`, the version step was run against 1.0.0 / 1.0.1 / 21 chars
  (pass / fail / fail), and actionlint 1.7.7 is clean. Not run on GitHub (no push from here, G-17).
  Status: VERIFIED-DOC (manual submit), VERIFIED-ON-BOX (local checks); workflow run UNVERIFIED.

## D-32 Store images (2026-10-25)

* Garmin Connect IQ brand guidelines, "App Store Assets" (<https://developer.garmin.com/brand-guidelines/connect-iq>):
  - 500 x 500 px, sRGB, 10 px padding, centred, not stretched
  - no black or transparent background, a simple solid colour
  - no descriptive text, no Garmin branding
  - "For watch faces, using a preview of the watch face as the app icon often works best"
  - on-device icon 128 x 128; hero image 1440 x 720 (neither made here)
* `scripts/store-assets.sh` (ImageMagick 6 or 7):
  - `cover.png` is the round screen of the real `docs/screenshots/active_large_yellow-white.png`, masked to the circle so the simulator bezel
    is dropped, scaled to 480 px, centred on solid `#3A3F47` (not black, not a Garmin colour), with alpha removed
  - every real `active_*` / `aod_*` frame is saved as PNG, or as JPG with the quality stepped down if the PNG is over 150 KB
  - local run: cover 500x500 sRGB, about 38 KB; 26 screenshots, all PNG, 55-61 KB
  The 150 KB screenshot limit is the owner's target; the screenshot size and count of the store form are not in the pages read (G-7).
  Status: VERIFIED-DOC (cover spec), VERIFIED-ON-BOX (script output).

## D-33 Signing key: one key for the app's whole life (2026-10-25)

* "It's important you keep track of the key you use to sign app packages. You will need to use the same key to sign updates to an existing app on
  the store. If you lose your original signing key you will not be able to update your app." (Security,
  <https://developer.garmin.com/connect-iq/core-topics/security/>; also *Getting Started*,
  <https://developer.garmin.com/connect-iq/connect-iq-basics/getting-started/>).
* So CI never generates a key. It decodes the owner's key from `CIQ_DEVELOPER_KEY_B64` for each run. README and docs/DEVELOPMENT.md say to back it
  up and reuse it. Garmin's forum staff say a lost key means republishing under a new app id
  (<https://forums.garmin.com/developer/connect-iq/f/connect-iq-web-store/402228/developer-key-lost>; this is a forum post, not documentation).
  Status: VERIFIED-DOC.

## D-34 Body Battery icon redrawn in Garmin's Body Battery style; licence switched to GPL-3.0 (2026-10-25)

* Owner feedback: the D-28 icon (battery outline + bolt) looks like the *watch* battery and is misleading; Garmin's Body Battery
  symbol is something else.
* Garmin reference: the Body Battery page on garmin.com,
  <https://www.garmin.com/en-US/garmin-technology/health-science/body-battery/>, hero image
  <https://static.garmin.com/en_US/garmin_technology/health_science/59030-health_science-body_battery_energy_monitoring-D.jpg>
  (Body Battery glance on a watch): the symbol is a person with both arms raised inside a segmented gauge ring that is open at the
  bottom. Garmin's support FAQ on watch-face icons (<https://support.garmin.com/en-US/?faq=agZJiZRjhX2adgWkBVOHI9>) could not be read
  from the box (Cloudflare check). Status: VERIFIED-DOC (image looked at 2026-10-25).
* New glyph, own geometry from `Dc` primitives (not a copy of Garmin's bitmap): square box (`BODY_BATTERY_ICON_WIDTH_PERCENT` 56 -> 100);
  ring = `drawArc` 300 deg counter-clockwise from 300 to 240 (60 deg gap at 6 o'clock), pen `max(2, s/10)`; head = `fillCircle`
  (r 11 % of the box); body with raised arms = one 10-point `fillPolygon` ("Y": hands up and out, torso down through the ring's gap).
  `drawArc` is API 1.2.0 (<https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html>); the others are API 1.0.0.
  Single colour = the stats grey; same AOD shift + row mask (D-19). The steps footprints are unchanged.
* Effect of the wider icon on the stats font (both values shown; the time font is unchanged at every size, D-28): Medium
  `FONT_SMALL` -> `FONT_TINY`, XX-Large `FONT_TINY` -> `FONT_XTINY` (host model). With one value hidden nothing changes.
  Port + tests updated: `tests/host/face_model.py` `draw_body_battery_icon`, `source/tests/NoirTests.mc` `testStatsRowWidth`.
* Licence: at the owner's request the project licence changed from CC BY-NC 4.0 to **GPL-3.0** (a standard licence GitHub recognises;
  strict copyleft). `LICENSE` = the official text downloaded unchanged from <https://www.gnu.org/licenses/gpl-3.0.txt>
  (sha256 3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986); README and docs/DEVELOPMENT.md link
  <https://www.gnu.org/licenses/gpl-3.0.html>. The CC BY-NC / non-commercial wording is gone.
* Verified: strict build + `.iq` with `-l 3 -w`, 0 warnings; 23/23 simulator unit tests; 28 host tests OK; all 26 active/aod shots in
  `docs/screenshots/` regenerated in the simulator (same names; 11:29-11:39 Asia/Jerusalem). Always-on shots, lit pixels / luminance on the
  round screen, old -> new: Small 3.07 -> 3.00 % / 1.59 -> 1.49 %, Medium 3.52 -> 3.26 % / 1.84 -> 1.66 %, Large 3.41 -> 3.24 % /
  2.16 -> 1.98 %, XX-Large gold-blue 5.08 -> 4.81 % / 2.37 -> 2.12 % (different minutes, so the digits differ too); all far under 10 %.
  `docs/burn-in-report.md` (24-hour runs) was measured with the D-28 icon and was not re-run.

## D-35 SECURITY.md; robust simulator start for the unit tests in CI (2026-10-25)

* `SECURITY.md` (GitHub security policy): supported versions (1.0.0 / `main`), reports through GitHub private vulnerability reporting
  (Security tab -> *Report a vulnerability*,
  <https://docs.github.com/code-security/security-advisories/guidance-on-reporting-and-writing/privately-reporting-a-security-vulnerability>),
  what to include, acknowledgement within a few days, no SLA, scope (watch face, only the `SensorHistory` permission, no personal data off the
  device). No e-mail address is written; a marked placeholder comment is left for the owner. README links it.
* CI failure: the GitHub Actions unit-test step printed `Unable to connect to simulator` (the build passed). The script slept a fixed
  10 s after starting the simulator. `scripts/run-unit-tests.sh` now:
  * waits until the simulator has a TCP port in LISTEN state in 1234-1238 (read passively from `/proc/net/tcp*`; seen: 1235 and 1236 on
    the box with SDK 9.3.0), up to `CIQ_SIM_READY_TIMEOUT` = 60 s, then `CIQ_SIM_SETTLE` = 3 s more; stops early if the simulator exits;
  * runs `monkeydo -t`; with no `PASSED`/`FAILED` summary (e.g. `Unable to connect`) it kills the simulator, starts a new one and
    retries, up to `CIQ_SIM_ATTEMPTS` = 3;
  * re-runs itself under `xvfb-run -a -s "-screen 0 1280x1024x24"` when `$DISPLAY` is empty and under `dbus-run-session` when there is no
    session bus; sets `NO_AT_BRIDGE=1` (the AT-SPI / dbind warnings); simulator output goes to `build/simulator.log`;
  * keeps the verdict from the printed summary (`monkeydo -t` exits 1 even on a pass) and always stops the simulator it started.
* `build.yml` and `release.yml` test steps: also install `xauth dbus dbus-x11`, run
  `dbus-run-session -- xvfb-run -a -s "-screen 0 1280x1024x24" scripts/run-unit-tests.sh`, print `build/simulator.log` on failure,
  `timeout-minutes: 15`. The step stays fatal (no `continue-on-error`). Status: VERIFIED-ON-BOX (23/23 with and without a preset
  `$DISPLAY`); the GitHub runner is not run from here (G-17).

## D-36 Multi-device: every fēnix 8 / fēnix 9 model and the round Forerunners (2026-10-25)

Owner's question: can the face run on all fēnix 8 and 9 versions and on Forerunner watches. Answer: yes for 38 device IDs, all built,
12 of them unit-tested in the simulator.

**Sources.**
* Device list and names: Garmin's compatible devices table, <https://developer.garmin.com/connect-iq/compatible-devices/> (HTTP 200,
  2026-10-25). Several products share one device ID; e.g. `fenix847mm` = fēnix 8 47mm / 51mm, tactix 8, quatix 8; `fenix8pro47mm` = fēnix 8 Pro 47mm / 51mm / MicroLED, quatix 8 Pro.
* Per-device facts: the official device files downloaded by the SDK manager (`device list --download-all`, then
  `device download -d <id> --include-fonts`): `compiler.json` (`resolution`, `displayType`, `bitsPerPixel`, `palette`,
  `partNumbers[].connectIQVersion`, watch-face `memoryLimit`), `simulator.json`, and `<id>.api.debug.xml` (`VERIFIED-SDK`).
* API levels ("Since" in the SDK's API docs, `VERIFIED-DOC`): `Graphics.getVectorFont` 4.2.1, `System.getDisplayMode` 5.0.0,
  `SensorHistory.getBodyBatteryHistory` 3.3.0, `AppBase.getSettingsView` 3.2.0, `DeviceSettings.requiresBurnInProtection` 3.0.12
  (<https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics.html>, `.../Toybox/System.html`, `.../Toybox/SensorHistory.html`,
  `.../Toybox/Application/AppBase.html`, `.../Toybox/System/DeviceSettings.html`).
* Jungle: per-device `excludeAnnotations` and `resourcePath` (<https://developer.garmin.com/connect-iq/core-topics/build-configuration/>,
  <https://developer.garmin.com/connect-iq/reference-guides/jungle-reference/>).
* AMOLED vs MIP low power: <https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/>
  ("check `DeviceSettings.requiresBurnInProtection`") and the WatchFace page
  (<https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFace.html>: low power = `onUpdate` once a minute).

**Supported (manifest.xml, 38 IDs; resolution / display / CIQ API from `compiler.json`; watch-face memory 131072 B unless noted).**

| Group | Device ID | Product | Screen | Display | API |
|---|---|---|---|---|---|
| fēnix 8 | `fenix843mm` | fēnix 8 43mm | 416 | AMOLED | 6.0.3 |
| | `fenix847mm` | fēnix 8 47mm / 51mm, tactix 8, quatix 8 | 454 | AMOLED | 6.0.3 |
| | `fenix8pro47mm` | fēnix 8 Pro 47mm / 51mm / MicroLED, quatix 8 Pro | 454 | AMOLED | 6.0.3 |
| | `fenix8solar47mm` | fēnix 8 Solar 47mm | 260 | MIP | 6.0.3 |
| | `fenix8solar51mm` | fēnix 8 Solar 51mm, tactix 8 Solar 51mm | 280 | MIP | 6.0.3 |
| | `fenixe` | fēnix E | 416 | AMOLED | 6.0.3 |
| fēnix 9 | `fenix943mm` | fēnix 9 43mm | 416 | AMOLED | 6.0.3 |
| | `fenix947mm` | fēnix 9 47mm / 51mm | 454 | AMOLED | 6.0.3 |
| | `fenix9pro43mm` | fēnix 9 Pro 43mm | 416 | AMOLED | 6.0.3 |
| | `fenix9pro47mm` | fēnix 9 Pro 47mm | 454 | AMOLED | 6.0.3 |
| | `fenix9pro51mm` | fēnix 9 Pro 51mm | 466 | AMOLED | 6.0.3 |
| | `fenix9prosolar47mm` | fēnix 9 Pro Solar 47mm | 260 | MIP | 6.0.3 |
| | `fenix9prosolar51mm` | fēnix 9 Pro Solar 51mm | 280 | MIP | 6.0.3 |
| Forerunner | `fr165`, `fr165m` | 165, 165 Music | 390 | AMOLED | 5.2.0 |
| | `fr170`, `fr170m` | 170, 170 Music | 390 | AMOLED | 6.0.3 |
| | `fr70` | 70 | 390 | AMOLED | 6.0.3 |
| | `fr265` | 265 | 416 | AMOLED | 5.2.0 |
| | `fr265s` | 265S | 360 | AMOLED | 5.2.0 |
| | `fr57042mm` | 570 42mm | 390 | AMOLED | 6.0.3 |
| | `fr57047mm` | 570 47mm | 454 | AMOLED | 6.0.3 |
| | `fr965` | 965 | 454 | AMOLED | 5.2.0 |
| | `fr970` | 970 | 454 | AMOLED | 6.0.3 |
| | `fr255`, `fr255m` | 255, 255 Music | 260 | MIP | 5.2.0 |
| | `fr255s`, `fr255sm` | 255S, 255S Music | 218 | MIP | 5.2.0 |
| | `fr955` | 955 / Solar | 260 | MIP | 5.2.0 |
| | `fr245`, `fr245m`, `fr745`, `fr945` | 245, 245 Music, 745, 945 | 240 | MIP | 3.3.1 (98304 B) |
| | `fr945lte` | 945 LTE | 240 | MIP | 3.4.3 (98304 B) |
| | `fr55` | 55 | 208 | MIP, 8-colour palette | 3.4.2 (98304 B) |
| | `fr645`, `fr645m` | 645, 645 Music | 240 | MIP | 3.1.6 / 3.2.3 (98304 B) |
| | `fr935` | 935 | 240 | MIP | 3.1.6 (98304 B) |

**Excluded Forerunners (and why).** `fr230`, `fr235`, `fr630` (semi-round 215 x 180, API 1.4), `fr735xt` (semi-round, API 2.4),
`fr920xt` (rectangle 205 x 148, API 1.4), `fr45` (API 1.4, 49152 B watch-face memory). All are below API 3.0 (`WatchUi.Menu2`, used by
the on-device settings, is 3.0.0) and/or have a non-round screen; the layout and fit check are written for round screens
(`testDeviceScreen` asserts `SCREEN_SHAPE_ROUND`). Supporting them would need a second layout and a menu-less, properties-less code path.
Older fēnix models (fēnix 5/6/7) were not asked for and are not added.

**Code changes.**
* `manifest.xml`: 38 products (sorted), `minApiLevel` 5.0.0 -> **3.1.0** (lowest `connectIQVersion`: fr645 / fr935 3.1.6). Permission and
  languages unchanged.
* Annotations (strict `monkeyc` rejects a symbol a device lacks even behind a `has` check, e.g.
  `Value '$.Toybox.Graphics.getVectorFont' is not supported for device 'fr245'` - seen on the box):
  * `(:ciq4)` / `(:ciq3)` variants of `chooseVectorFont` and `isLowPower`. API 3.x devices get `chooseVectorFont() = false` (XX-Large
    falls back to the X-Large system font) and `isLowPower()` from `onEnterSleep`/`onExitSleep` (`_inLowPower`) instead of `getDisplayMode`.
  * `(:bodybattery)` / `(:nobodybattery)` variants in `NoirBodyBattery` (645 / 645 Music / 935 are below 3.3.0: Body Battery hidden).
  * `monkey.jungle`: `base.excludeAnnotations = ciq3;nobodybattery`; `ciq4;nobodybattery` for fr245/fr245m/fr745/fr945/fr945lte/fr55;
    `ciq4;bodybattery` for fr645/fr645m/fr935.
* Resolution independence: the layout was already proportional (percent of the screen). The one absolute value, the XX-Large vector
  font range 240..180 px, now scales with the width: `NoirLayout.xxlSizeMax/Min(w) = 240|180 * w / 454` (unchanged on 454).
* Burn-in style only where it is needed: `_burnIn = DeviceSettings.requiresBurnInProtection` (guarded by `has`, default true).
  Low power uses the outline / shift / row-mask style only when `_burnIn` is true; MIP screens keep the normal look in low power
  (they cannot burn in). Simulator logs: true on every AMOLED product tested, false on every MIP product.
* Launcher icons: the device files ask for 65 / 60 / 54 / 40 / 35 px; scaling the 65 px icon prints a warning (breaks `-w` zero
  warnings). `launcher-icons/<n>/drawables/` holds LANCZOS downscales of the 65 px icon, selected per device with
  `<id>.resourcePath = $(<id>.resourcePath);launcher-icons/<n>` (the later path overrides `LauncherIcon`; the base strings, settings
  and Hebrew resources are still included).
* Tests: `testXxlSizeScaling`, `testDeviceScreen` (round screen, logs size and burn-in flag), `testVectorFontAvailable` and
  `testBodyBatteryApiOnDevice` made device-aware; 25 tests. `scripts/run-unit-tests.sh` / `build.sh` take `CIQ_DEVICE`. Host test checks
  the product list, jungle device names and icon sizes. `scripts/install-sdk.sh` already downloads by `--manifest`, so CI now fetches
  the device files of all 38 products (slower first run).

**Status.**
* Strict build `monkeyc -d <id> -f monkey.jungle -l 3 -w -r` for **all 38** IDs: `BUILD SUCCESSFUL`, 0 warnings (`VERIFIED-ON-BOX`).
  `.iq` (`-e -l 3 -w`): `BUILDING FOR 52 DEVICES` (part numbers), `BUILD SUCCESSFUL`, 0 warnings.
* Simulator unit tests `PASSED (passed=25, failed=0, errors=0)` on 12 devices covering every resolution / display / API class:
  fenix9pro47mm (454), fenix9pro51mm (466), fenix843mm (416), fr165 (390), fr265s (360), fr970 (454, API 6), fenix9prosolar47mm
  (260 MIP), fenix8solar51mm (280 MIP), fr255s (218 MIP), fr245 (240 MIP, API 3.3), fr645 (240 MIP, API 3.1, no Body Battery), fr55
  (208, 8 colours). Simulator memory: ~16 of 124 kB (API 5/6), ~19 of 92 kB (98304 B devices).
* Screenshots (simulator window crops, downscaled to 640 px high, 256 colours): `docs/screenshots/devices/`. One MIP low-power shot
  with a temporary build forcing `_burnIn = true` shows that low power does engage on MIP in the simulator; the committed code keeps
  the normal look there.
* UNVERIFIED (G-21 - G-24): look on real MIP screens and the 466 px Pro 51mm, battery on each watch, palette mapping on MIP (64 colours)
  and fr55 (8 colours: several of the 16 colours collapse), on-device settings menu on fr645m (API 3.2) - fr645 / fr935 (API 3.1, no
  `getSettingsView`) have settings in Garmin Connect only.

## D-37 Store and README wording for the Sensor History permission (2026-10-25)

* `store/description.md` has a **Permissions** note: "The Sensor History permission is used only to display Body Battery. No other
  sensor data is read, and nothing ever leaves the watch." README has the same reassurance on the Body Battery feature line.
* Basis: the code. The only `SensorHistory` call is `getBodyBatteryHistory` in `source/NoirBodyBattery.mc` (`period: 1`); the manifest
  asks only for `SensorHistory` (<https://developer.garmin.com/connect-iq/core-topics/manifest-and-permissions/>), with no
  `Communications`/`Background`/`Positioning` permission, so the app cannot send data off the watch. `VERIFIED-SDK` (manifest + source
  read; host test checks the permission list).

## D-38 Own time font: Bebas Neue, embedded as bitmap fonts per screen (2026-10-25)

Owner's request: a face of his own (no third-party dependency) that looks better than *Pretty Simple*, whose
big digits he likes. The system number fonts (D-17 / D-24) are Garmin's and differ per device; an embedded font is the
only way to get one consistent, chosen look on all 38 products.

**Font: Bebas Neue Regular** by Ryoichi Tsunekawa / Dharma Type, SIL Open Font License 1.1, no Reserved Font Name
(<https://github.com/dharmatype/Bebas-Neue>, licence text in `assets/fonts/BebasNeue/OFL.txt`).
* Why: a tall, condensed, all-caps display face with flat terminals - the "big clean digits" look the owner asked for. Being
  condensed, the digits can be very tall in the same round screen (XX-Large on 454 px: 155 px digit height). Its digits are
  tabular (all ten have the same advance, e.g. 85 px in `resources-round-454x454/fonts/time4.fnt`), so the time does not jump
  left and right from minute to minute.
* Licence fit: OFL 1.1 allows embedding and redistributing the font in software, also commercially, as long as the font is not
  sold on its own and the licence goes with it (<https://openfontlicense.org/>). The FSF lists the OFL as a free licence
  compatible with the GPL for this use (<https://www.gnu.org/licenses/license-list.html#SILOFL>). The OFL text sits next to the
  TTF; README and store text name the font and the licence.
* Rejected: shipping a TTF (Connect IQ has no runtime TTF loading for apps); vector fonts by name (`getVectorFont` only offers the
  faces the device has, API 4.2.1+, not the API 3.x Forerunners).

**How it is embedded.**
* Connect IQ custom fonts are BMFont files (text `.fnt` + PNG page) declared in a `<fonts>` resource
  (<https://developer.garmin.com/connect-iq/core-topics/resources/> "Fonts"; FAQ "How do I use custom fonts").
  `scripts/make_fonts.py` (Pillow / FreeType, mypy-clean) writes them for every round resolution of the products
  (208, 218, 240, 260, 280, 360, 390, 416, 454, 466): five fonts per screen, `TimeFont0..4` = Small..XX-Large, digits `0-9` only
  (the colon is two squares drawn with `fillRectangle`), `antialias="true"`, 8-bit page <= 512 px wide.
* Sizing: the XX-Large digit height is the largest at which "00:00" (+ colon gap + always-on outline) fits inside the round
  screen minus `EDGE_MARGIN` - the same formula as `NoirLayout.blockFits`; the other sizes are 56 / 68 / 80 / 90 % of it.
  `lineHeight` = digit height + 2 (`TIME_LINE_EXTRA`) and glyphs are cropped to the digits, so `Dc.getFontHeight` is the digit
  height and the layout centres the ink, not an em box. The generator is deterministic (re-running gives identical files,
  checked) and shares `EDGE_MARGIN`, `OUTLINE_MAX`, `COLON_GAP_PERCENT` with the Monkey C code (host test).
* Selection: `resources-round-WxH/fonts/` qualifiers (<https://developer.garmin.com/connect-iq/core-topics/build-configuration/>),
  so every device builds only the fonts of its own screen.
* Loading: `WatchUi.loadResource(Rez.Fonts.TimeFontN)` in `updateLayout` only (size / field change). Starting at the selected size,
  smaller fonts are tried until the block fits with the smallest field-row font; only the chosen font stays referenced.
  From API 4.0.0 fonts load into the **graphics pool**, separate from the app heap, and are handed back as a reference
  (<https://developer.garmin.com/connect-iq/core-topics/graphics/> "Graphics Pool"); before 4.0.0 they load into the heap.
* Line heights (px, Small..XX-Large): 208: 37/45/53/59/66, 218: 40/48/56/63/70, 240: 44/53/62/70/78, 260: 49/59/69/77/86,
  280: 52/63/74/83/93, 360: 69/83/98/110/122, 390: 75/91/106/119/133, 416: 80/97/114/128/143, 454: 88/107/126/141/157,
  466: 91/110/129/144/161 (simulator unit test `testTimeFontsOnDevice` checks each on 10 devices).
* Memory: see D-41.

**Look changes that come with it.** Colon = two squares (`COLON_DOT_PERCENT` 15 % of the digit height, offset 22 %), which matches
Bebas's flat geometry better than the old circles; outlined squares in always-on. The always-on style (outline dilation, shift,
row mask, D-19) is unchanged and works the same with the bitmap font.

## D-39 Three configurable field slots (2026-10-25)

Replaces the two show/hide toggles of D-29. Three slots - **left**, **right** (row under the time) and **bottom** (second row) -
each show one field or nothing. The date stays above the time. If left and right are both empty, the bottom field moves up to
the first row. A second row shifts the whole block up (`NoirLayout.blockShift`) so it stays centred.

| id | field | API | since | permission | not on | default |
|---|---|---|---|---|---|---|
| 0 | None | - | - | - | - | bottom |
| 1 | Steps | `ActivityMonitor.Info.steps` | 1.0.0 | none | - | **left** |
| 2 | Body Battery | `SensorHistory.getBodyBatteryHistory` | 3.3.0 | SensorHistory | fr645, fr645m, fr935 | **right** |
| 3 | Heart rate | `Activity.Info.currentHeartRate`, else newest `ActivityMonitor.getHeartRateHistory` sample | 1.0.0 / 1.2.1 | none | - | off |
| 4 | Battery % | `System.Stats.battery` | 1.0.0 | none | - | off |
| 5 | Battery days | `System.Stats.batteryInDays` | 3.3.0 | none | API 3.x products (fr245/245m/745/945/945lte/55/645/645m/935) | off |
| 6 | Calories | `ActivityMonitor.Info.calories` | 1.0.0 | none | - | off |
| 7 | Floors | `ActivityMonitor.Info.floorsClimbed` | 2.1.0 | none | fr245, fr245m, fr55, fr70 | off |
| 8 | Intensity minutes (week) | `ActivityMonitor.Info.activeMinutesWeek.total` | 2.1.0 | none | - | off |
| 9 | Notifications | `System.DeviceSettings.notificationCount` | 1.2.0 | none | - | off |
| 10 | Stress | `SensorHistory.getStressHistory` | 3.3.0 | SensorHistory | fr645, fr645m, fr935 | off |
| 11 | Temperature | `Weather.getCurrentConditions().temperature` (°C, shown in the user's unit) | 3.2.0 | none | fr645, fr645m, fr935 | off |
| 12 | Distance (today) | `ActivityMonitor.Info.distance` (cm, shown in km / mi) | 1.0.0 | none | - | off |

Sources (`VERIFIED-DOC`, SDK 9.3.0 API docs, "Since" and "Supported Devices" checked for all 38 products):
<https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityMonitor/Info.html>,
<https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityMonitor.html>,
<https://developer.garmin.com/connect-iq/api-docs/Toybox/SensorHistory.html>,
<https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity/Info.html>,
<https://developer.garmin.com/connect-iq/api-docs/Toybox/System/Stats.html>,
<https://developer.garmin.com/connect-iq/api-docs/Toybox/System/DeviceSettings.html>,
<https://developer.garmin.com/connect-iq/api-docs/Toybox/Weather.html>,
permissions: <https://developer.garmin.com/connect-iq/core-topics/manifest-and-permissions/>.

* **No new permission.** Only Body Battery and stress need one (SensorHistory), which the app already had (D-27). Nothing that
  needs Positioning / Communications / UserProfile was added; no field is off "because of a permission". The Sensor History
  reassurance (D-37) now reads "only to display Body Battery and stress".
* **Unsupported = hidden.** Strict `monkeyc` rejects a symbol a device lacks even behind `has`, so the device-specific APIs are in
  annotated variants (`source/NoirSensors.mc`): `(:hist33)/(:nohist33)` (Body Battery, stress, weather - renamed from
  `bodybattery`), `(:ciq4)/(:ciq3)` (battery days), `(:floors)/(:nofloors)`. `monkey.jungle` `excludeAnnotations` (the variants
  DROPPED): base `ciq3;nohist33;nofloors`; fr245/fr245m/fr55 `ciq4;nohist33;floors`; fr745/fr945/fr945lte `ciq4;nohist33;nofloors`;
  fr645/fr645m/fr935 `ciq4;hist33;nofloors`; fr70 `ciq3;nohist33;floors`. At run time each also checks `has`. `NoirSettings.field(key)` returns None for
  an unsupported stored value, and the menu / phone list offers only supported fields on the watch menu
  (`NoirFields.supportedValues`); the phone list shows all 13 (Garmin Connect settings are not per device) and an unsupported
  choice simply leaves the slot empty.
* **Reading.** Values are read once per minute (and on wake), not per frame; null / invalid values show `--`.
  Steps, calories, intensity get thousands separators; temperature and distance follow `DeviceSettings.temperatureUnits` /
  `distanceUnits`.
* **Icons.** Steps and Body Battery icons kept (D-28 / D-34). New ones drawn with `Dc` primitives (API 1.0.0 / 1.2.0): heart, battery
  (level bar; battery days = three cells), flame, stairs, bolt, speech bubble, zig-zag (stress), thermometer, map pin.
* **Settings UX.** `properties.xml`: `FieldLeft` 1, `FieldRight` 2, `FieldBottom` 0 (number); `settings.xml`: three list settings
  ("Left field", "Right field", "Bottom field") with the 13 entries; on the watch, three Menu2 items that cycle through the supported
  fields with the current choice as sub-label (same pattern as size / colours, D-16). English + Hebrew strings. Old
  `ShowSteps` / `ShowBodyBattery` properties are no longer read (an upgrade starts from the defaults steps + Body Battery, which is
  what both toggles defaulted to).

## D-40 Companion text font: RobotoCondensed for the date and fields (2026-10-25)

* Date and field values use `Graphics.getVectorFont({:face => "RobotoCondensedRegular", :size => px})` (API 4.2.1,
  <https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics.html>): date at 10 % of the screen width, field rows at
  10 / 9 / 8 / 7 % (largest that fits). Measured in the simulator: `getFontHeight` = requested px (45 -> 45 on 454 px).
  A condensed face next to Bebas reads as one design and leaves room for two fields per row.
* The date is upper-case (`String.toUpper`, API 1.0.0) to match the all-caps digits, but only for languages whose month / day
  names are basic Latin (`NoirLayout.isBasicLatin`: eng, deu, fre, ita, spa, por, dut, dan, swe, nob, fin). Other languages
  (Hebrew, Russian, Chinese, ...) keep `FONT_SMALL` in the system's own case, because the coverage of the device's
  RobotoCondensed for those scripts is not documented.
* Fallback: no `getVectorFont` (API < 4.2.1, the `(:ciq3)` build) or a null font -> `FONT_SMALL` for the date and
  `FONT_SMALL / FONT_TINY / FONT_XTINY` for the rows (the D-28 behaviour).

## D-41 Memory and build check after D-38 - D-40 (2026-10-25)

Strict build `monkeyc -d <id> -f monkey.jungle -l 3 -w -r` for all 38 products of `manifest.xml`: **rc 0, 0 warnings, 0 errors on
every product**; `monkeyc -e` (store package, all products): 0 warnings, 1.85 MB. PRG sizes 30.7 kB (260 px MIP) - 53.8 kB
(fr70 / fr165); 46.4 kB on 454 px.

Memory (simulator status bar "used / available", watch-face app, active mode, fields shown in parentheses):

| tier | device (size, fields) | used / available | headroom |
|---|---|---|---|
| AMOLED 454, API 5 | fenix9pro47mm (XX-Large, steps + BB) | 22.7 / 123.8 kB | 101 kB |
| AMOLED 454, 3 fields | fenix9pro47mm (Large, calories / floors / temperature) | 22.8 / 123.8 kB | 101 kB |
| AMOLED 466 | fenix9pro51mm (XX-Large, steps + BB + HR) | 22.8 / 123.8 kB | 101 kB |
| AMOLED 416 | fenix843mm (XX-Large) | 22.7 / 123.8 kB | 101 kB |
| AMOLED 454 Forerunner | fr970 (Large, HR + battery) | 22.7 / 123.8 kB | 101 kB |
| AMOLED 390 | fr165 (Medium, 3 fields) | 22.6 / 123.8 kB | 101 kB |
| AMOLED 360 | fr265s (X-Large) | 22.5 / 123.8 kB | 101 kB |
| MIP 260 | fenix9prosolar47mm (XX-Large) | 22.8 / 123.8 kB | 101 kB |
| MIP 280 | fenix8solar51mm (Large, 3 fields) | 22.8 / 123.8 kB | 101 kB |
| MIP 218 | fr255s (XX-Large) | 22.2 / 123.8 kB | 102 kB |
| MIP 240, API 3.3 | fr245 (XX-Large) | 29.3 / 91.8 kB | 62.5 kB |
| MIP 240, API 3.1 | fr645 (Medium, steps + HR + calories) | 27.7 / 91.8 kB | 64.1 kB |
| MIP 208, API 3.4 | fr55 (Large) | 27.2 / 91.8 kB | 64.6 kB |

* On API 4+ the loaded `TimeFontN` lives in the graphics pool (D-38), so the app heap barely changes with the size; on the API 3.x
  products (91.8 kB limit) the font is in the heap: the simulator unit test `testTimeFontsOnDevice` measured
  `System.getSystemStats().usedMemory` deltas of +0.4 - 1.8 kB per loaded font (fr245 / fr645 TimeFont0-4: +1824 / +520 / +504 /
  +424 / +384 B; fr55: +968 / +144 / +384 / +200 / +632 B). Only ONE time font is referenced at a time, and only the device's own
  resolution is compiled in, so five sizes per screen cost flash (52 - 80 kB of font files per resolution, in the PRG/IQ), not RAM.
  Worst case seen: 29.3 kB of 91.8 kB (32 %), so no size had to be scaled down for memory.
* Simulator unit tests (`scripts/run-unit-tests.sh`, 26 tests incl. font loading, field lists, field settings per device):
  **PASSED 26/26** on fenix9pro47mm, fenix9pro51mm, fenix843mm, fenix9prosolar47mm, fr165, fr265s, fr970, fr245, fr55, fr645.
* Host tests: 34 tests OK, with and without `CIQ_DEVICE_FONTS` (+ XSD validation); `mypy tests/host scripts/make_fonts.py` clean;
  `ruff check tests/host scripts` - all checks passed (HEAD had 21 findings; none new, the touched files were cleaned).
* Always-on: real frames 2.5 - 3.6 % pixels on, 1.6 - 2.8 % luminance; full-day model worst case 4.3 % / 3.4 %, longest run
  2 min (`docs/burn-in-report.md`) - inside the < 10 % / 3 min limits of D-19.
* Screenshots (real simulator, SDK 9.3.0): `docs/screenshots/active_*.png` / `aod_*.png` (fenix9pro47mm, 454 px: five sizes, colour
  pairs, field configurations) and `docs/screenshots/devices/` (466 / 416 / 390 / 360 AMOLED with always-on, 280 / 260 / 240 / 218 /
  208 MIP); quantised to 256 colours, each < 31 kB. The old D-26 `burnin24h_*` / `profiler_*` frames were removed (old font).

## D-42 Battery re-check for the Bebas Neue font + configurable fields; battery check made a release step (2026-10-25)

Full write-up: **[docs/battery-report.md](docs/battery-report.md)**. Rules as in D-21 / D-26 (app types
<https://developer.garmin.com/connect-iq/connect-iq-basics/app-types/>, WatchFace update rate
<https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFace.html>, AMOLED FAQ
<https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/>, profiling
<https://developer.garmin.com/connect-iq/core-topics/profiling/>).

* **Lit pixels re-measured** (`CIQ_DEVICE_FONTS=~/.Garmin/ConnectIQ/Fonts python3 tests/host/burnin_report.py 1440`, device RobotoCondensed,
  white / white, 1440 always-on minutes): always-on max 2.98 / 3.38 / 3.74 / 4.03 / 4.31 % pixels on (Small - XX-Large, steps + Body Battery),
  3.30 / 3.69 / 4.06 / 4.33 / 4.33 % with a heart-rate row; max luminance 3.36 %; longest on-run 2 min. All under the 10 % / 3 min limits.
  Active frames (new table in `docs/burn-in-report.md`): 7.1 - 17.9 % pixels on.
* **Code audit** (docs/battery-report.md section 3): no `onPartialUpdate`, `Timer`, background, web, sensor listeners or animation;
  layout / font loading only on a size or field change; date / time strings and field values once per minute, only shown fields.
  14 draw calls per active frame and 185 per always-on minute with the default fields (152 of them the 1-px row mask).
* **Regression found and fixed:** D-39's `drawRow` allocated a width array and called `getTextWidthInPixels` for every shown field on
  every frame (D-30 had cached that width). Now `measureFields` measures once after the field texts change into a preallocated array
  (`_fieldWidths`, `_widthsValid`); `drawRow` allocates nothing. Pixel output unchanged (host tests 34 OK); strict builds
  (`-l 3 -w -r`) fenix9pro47mm and fr245 and the store export (`-e`, 52 of 52 devices) succeed with 0 warnings. The Connect IQ
  simulator unit tests were not run on the box (no simulator, see below); CI runs them.
* **No headless profiler:** the profiling guide documents only the simulator GUI (*File -> View Profiler*) and on-device `.PRF` files,
  `monkeydo` (SDK 9.3.0) has only `-n`, `-a`, `-t`, and the power-budget callback concerns only `onPartialUpdate`
  (<https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFaceDelegate.html>). The SDK 9.3.0 simulator does not start on the
  Debian 13 build box (needs libwebkit2gtk-4.0, libsoup-2.4, libjavascriptcoregtk-4.0, libjpeg8). So the profiler ms per minute stay open (G-31).
* **Release step:** `scripts/battery-audit.sh` (static audit of `source/` + manifest permissions) and `tests/host/test_burnin.py` run as a
  "Battery check" step in `build.yml` (every push) and `release.yml` (every store package, with the device fonts); the manual part is the
  "Battery check (required every release)" checklist in docs/DEVELOPMENT.md section 5.

Status: rules VERIFIED-DOC; lit pixels and code audit VERIFIED-ON-BOX; profiler and watch battery % UNVERIFIED (G-31, G-15).

## Open gaps

| # | Gap | Why | Resolution |
|---|---|---|---|
| G-1 | ~~No device build / simulator / unit tests / screenshots~~ **RESOLVED 2026-10-24** (D-23). | | |
| G-2 | ~~Burn-in only estimated~~ **RESOLVED** (D-23): real simulator 24-hour simulation, no burn-in; font-accurate model max 3.47 % | | a check on the watch is still advisable |
| G-3 | ~~Colon centring / font choice / spacing~~ **RESOLVED** (D-23, screenshots) | | |
| G-4 | Colon glyph in number fonts undocumented | docs silent | circles are used, no dependency |
| G-5 | Hebrew date rendering / RTL order unverified | not run in Hebrew yet | simulator *Settings > Language* Hebrew |
| G-6 | `-r` for the `.iq` export undocumented | VS Code extension behaviour not documented | omitted (documented form); the `.iq` builds; store acceptance not tried |
| G-7 | Store screenshot specs not documented in the sources read | listing form is behind the Garmin login | see the form when you submit; use `docs/screenshots/` (real), not `docs/mockups` |
| G-8 | CI login with Garmin account may hit MFA/IP blocking | undocumented third-party pattern | the box login worked; CI not run (G-17) |
| G-9 | ~~Device API level~~ **RESOLVED**: 6.0.3 (`compiler.json`, D-04) | | |
| G-10 | SDK licence | must be read and accepted by a person | accepted on the build box by hash; CI needs `CIQ_AGREEMENT_HASH` |
| G-11 | Exact place of the on-device settings on the fēnix 9 Pro | needs the watch | watch-face menu |
| G-12 | `getSettingsView()` next to the native editor; `onSettingsChanged()` after an on-device change; immediate sub-label refresh | not documented; not exercised in the simulator yet | test on the watch |
| G-13 | ~~Which font each size gets~~ **RESOLVED** (D-17/D-23); still open: long localised (Hebrew) dates | | check in Hebrew |
| G-14 | Hebrew in the menu sub-labels / phone settings list | needs device/phone | look with the language set to Hebrew |
| G-15 | Battery % per day on the watch | simulator profiler done (D-21: ~28 ms per always-on minute for Large; D-26: ~38 / ~55 ms for X-Large / XX-Large; D-30 with icons + Body Battery: ~29 / ~66 ms for Large / XX-Large); Garmin gives no conversion to watch battery | wear it a day; `-k` build writes `GARMIN\APPS\LOGS\<app>.PRF` |
| G-16 | ~~Hollow glyph rendering / `monkeydo -t` output~~ **RESOLVED** (D-23): clean hollow glyphs; summary `PASSED (passed=N, failed=0, errors=0)`, exit code 1 regardless | | |
| G-18 | Body Battery value / update rate on the real watch | simulator returns a fixed value (88) | wear it and compare with the Garmin widget |
| G-19 | Steps value in the screenshots is 0 | simulator *Activity Monitoring* dialog did not take a value in this session | real data on the watch; icon and layout are verified |
| G-20 | Store version format / 20-character limit | not in the Garmin pages read; the limit comes from the owner's brief | check the upload form |
| G-21 | Look of the face on real MIP (Solar, Forerunner 2xx/9xx) screens and on the 466 px fēnix 9 Pro 51mm | simulator only | check on a watch (D-36) |
| G-22 | Colour mapping: 64-colour MIP palette, 8-colour fr55 palette | some of the 16 colours map to the same device colour | look on the watch; consider a reduced list later |
| G-23 | On-device settings on fr645m (API 3.2); fr645 / fr935 (API 3.1) have no `getSettingsView` | not run in the simulator menu | phone settings work on all |
| G-24 | Battery cost on the other 37 products | profiler only run on fenix9pro47mm | wear it |
| G-25 | Coverage of the device's RobotoCondensed for every glyph of the 11 upper-case languages | simulator (English) only | look at the date in each language on a watch (D-40) |
| G-26 | Freshness of stress / temperature (newest history sample, Weather update rate) | API docs give no update interval | compare with the native widgets on a watch |
| G-27 | Heap cost of the bitmap time font on a real API 3.x watch (fr245 / fr645 / fr55) | simulator: +0.4 - 1.8 kB, 29.3 / 91.8 kB used | check with the profiler on a watch |
| G-28 | Whether a watch face needs the SensorHistory permission for Body Battery / stress at all | kept as in D-27 | none needed unless Garmin says otherwise |
| G-29 | Steps (and calories, distance) show 0 in the simulator frames | simulator activity data not set (as G-19) | set *Simulation -> Activity Data* or check on the watch |
| G-30 | No side-by-side comparison with *Pretty Simple* on the same watch | only its store pictures were seen | install both on the watch and compare |
| G-31 | **Narrowed 2026-10-25 (D-42):** lit-pixel / burn-in model and code audit RE-DONE for the Bebas Neue + fields build (always-on max 4.33 %, docs/battery-report.md). Still open: simulator GUI profiler ms per minute and the 24 h burn-in heat-map frames with the new font, and the real 24 h drain on the watch | the SDK 9.3.0 simulator GUI does not run on the Debian 13 build box; Garmin documents no headless profiler | profiler run on Ubuntu 22.04 / SDK Manager PC or a `-k` build on the watch (docs/battery-report.md section 5); 24 h comparison on the watch |
| G-32 | D-29's two show/hide toggles are superseded by D-39 | old `ShowSteps` / `ShowBodyBattery` values are ignored after the upgrade | none |
| G-17 | CI `build` job / `release.yml` (ubuntu-22.04 + apt packages for the simulator) not run | no secrets / no push from here | first run in GitHub Actions |

## What WAS verified in this session

* SDK 9.3.0 downloaded from Garmin's official link, `monkeyc` runs (version printed).
* All resource XML files validate against the SDK's `resources.xsd`; `manifest.xml` and workflow YAML are well-formed.
* Every API used exists in the SDK's own API documentation with the API level shown in D-04, and `getDisplayMode`/`setAntiAlias` list the fēnix® 9 Pro 47mm as supported.
* Shell scripts parse (`bash -n`).
* Launcher icon is 65 x 65 PNG (D-01).
* The colour list in `settings.xml` equals `NoirSettings.colorValues()`; every `Rez.Strings`/`@Strings` id used exists in both English and Hebrew strings (script check).
* All doc URLs cited in D-08, D-15 - D-17 returned HTTP 200 (2026-10-24).
* Strict (`-l 3 -w`) device-less builds of the normal, unit-test (`-t`) and profiling (`-k`) variants: `BUILD SUCCESSFUL` (D-22).
* Full-day AOD report in `docs/burn-in-report.md`.
* Garmin login with the SDK manager CLI: first attempt failed (wrong password); after the password was corrected, the single retry succeeded.
* Strict device build, `.iq` export, 15/15 simulator unit tests, real screenshots, 24-hour burn-in simulation, profiler (D-23, D-21).
* 22 host tests pass (with stand-in and with device fonts).
* After D-24/D-25 (sizes X-Large/XX-Large, 16 colours): strict device build + `.iq` without warnings, 17/17 simulator unit tests, 23 host tests (22 pass, 1 skipped), new real screenshots, 24-hour burn-in simulations and profiles (D-24, D-26).
* After D-27 - D-33 (2026-10-25): strict device build + `.iq` with `-l 3 -w`, no warnings. 23/23 simulator unit tests pass (`PASSED (passed=23, failed=0, errors=0)`;
  Body Battery read 88). 28 host tests pass with device fonts + XSD (27 + 1 skipped without the XSD). New real screenshots, including the
  hidden-field variants. Two 24-hour burn-in simulations and two profiles (D-30). Release workflow checked locally (D-31).
* After D-34/D-35 (2026-10-25): new Body Battery icon, GPL-3.0 licence, SECURITY.md, robust simulator start. Strict build + `.iq` with
  `-l 3 -w`, no warnings; 23/23 simulator unit tests through the new `scripts/run-unit-tests.sh` (with `$DISPLAY` set, and with no
  `$DISPLAY` / session bus so it started `xvfb-run` + `dbus-run-session` itself; the retry path checked with `CIQ_SIM_READY_TIMEOUT=0`);
  28 host tests OK; 26 screenshots regenerated.
* After D-36/D-37 (2026-10-25): 38 products. Strict build with `-l 3 -w -r` for each of the 38 IDs and the `.iq` (52 part numbers): no
  warnings. 25/25 simulator unit tests on 12 devices (D-36). 29 host tests pass (device fonts + XSD, including the `launcher-icons`
  XML); `mypy` clean; `ruff` reports no new findings (the 23 it lists with ruff's current defaults are in untouched lines). 15 device
  screenshots in `docs/screenshots/devices/`.
* After D-38 - D-41 (2026-10-25): Bebas Neue time fonts for 10 resolutions (deterministic generator), 13 field choices in 3 slots.
  Strict build with `-l 3 -w -r` for each of the 38 IDs and the `.iq`: no warnings, no errors. 26/26 simulator unit tests on 10
  devices. 34 host tests OK (device fonts + XSD, and without); `mypy` clean; `ruff` all checks passed. 54 new real screenshots
  (17 active + 17 always-on on 454 px, 20 on other devices) and a new burn-in report; memory per tier in D-41.
