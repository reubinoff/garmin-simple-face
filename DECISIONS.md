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

## D-06 Permissions: none

The permission table in `core-topics/manifest-and-permissions/` lists Ant, AudioInput/Output, Background, BluetoothLowEnergy, Communications,
ComplicationProvider/Subscriber, DataFieldAlert, Fit, PersistedContent, Positioning, Sensor, SensorHistory, SensorLogging, UserProfile.
`ActivityMonitor`, `Time`, `System`, `Graphics`, `WatchUi`, `Application.Properties` are not in it, so `<iq:permissions/>` is empty.
Benefit: no permission prompt, nothing to justify to reviewers. Status: VERIFIED-DOC.

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
| Build PRG | `monkeyc -d fenix9pro47mm -f monkey.jungle -o build/NoirTime.prg -y KEY -l 3 -w -r` | `monkey-c/compiler-options/` (`-d -f -o -y -l -w -r`) |
| Export for the store | `monkeyc -e -f monkey.jungle -o build/NoirTime.iq -y KEY -l 3 -w` | `-e / --package-app` ("IQ file for uploading to the app store"); the community CLI README uses the same form |
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
* Job `build` (skipped with a warning when secrets are missing): Java 21, Go (to `go install` the pinned CLI), `scripts/install-sdk.sh`, key from secret `CIQ_DEVELOPER_KEY_B64`, `scripts/build.sh`, Connect IQ unit tests under `xvfb`, upload `NoirTime.prg` and `NoirTime.iq` as an artifact.
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
| G-15 | Battery % per day on the watch | simulator profiler done (D-21: ~28 ms per always-on minute for Large; D-26: ~38 / ~55 ms for X-Large / XX-Large); Garmin gives no conversion to watch battery | wear it a day; `-k` build writes `GARMIN\APPS\LOGS\<app>.PRF` |
| G-16 | ~~Hollow glyph rendering / `monkeydo -t` output~~ **RESOLVED** (D-23): clean hollow glyphs; summary `PASSED (passed=N, failed=0, errors=0)`, exit code 1 regardless | | |
| G-17 | CI `build` job (ubuntu-22.04 + apt packages for the simulator) not run | no secrets / no push from here | first run in GitHub Actions |

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
