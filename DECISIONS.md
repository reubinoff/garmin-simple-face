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
Status: tool VERIFIED-ON-BOX (runs, help output read). End-to-end use **UNVERIFIED** (needs a Garmin login, gap G-1).

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
that do not meet the target device's minimum API level" - SDK release notes). Status: VERIFIED-DOC for the number; compatibility with the device **UNVERIFIED until the first build**.

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
  | `TimeSize` | 0 Small, 1 Medium, 2 Large | 1 (Medium) |
  | `HourColor` | 8 colours, `listEntry value` = `0xRRGGBB` | `0xFFFFFF` white |
  | `MinuteColor` | same 8 colours | `0xFFFFFF` white |

* Read with `Application.Properties.getValue(key)` and (on-device menu, D-16) written with `Properties.setValue(key, value)`; both API 2.4.0 and both throw
  if the key is not defined (<https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Properties.html>), so every key is in `properties.xml`.
  `source/NoirSettings.mc` is the single code-side definition (keys, values, labels); it falls back to the default if a stored value is not a `Number`.
* The value lists exist twice (settings.xml for the phone, `NoirSettings.mc` for the watch menu) because a settings list is not readable from code per the docs read;
  a check script compared both lists on the box (identical).
* `AppBase.onSettingsChanged()` calls `WatchUi.requestUpdate()` (same as the AppBase doc example). The view also reads the properties on every `onUpdate()`, so a
  change made in the on-device menu is shown even without that callback (whether the system calls `onSettingsChanged()` after an on-device change is not documented).
* The 8 colours are my design choice (bright, saturated, readable on black). The display has 65 536 colours (D-01) so colours are quantised
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

What the code does in low power (`DISPLAY_MODE_LOW_POWER`):
* time at 60 % brightness, at most `FONT_NUMBER_MILD` (113 px) whatever the size setting (Small uses `FONT_LARGE`, 71 px; see D-17); date and steps in `FONT_XTINY` (37 px) dark grey -> far less lit area than high-power mode;
* whole block shifted +/-8 px on a 4-minute cycle (`min % 4`), so consecutive minutes differ by 16 px; stroke widths are below that, so a pixel is not
  lit in two consecutive minutes;
* nothing static is drawn (no ticks, no labels); background pure black;
* `onPartialUpdate` is **not** implemented: the FAQ says AMOLED watch faces must not use per-second partial updates.
* An estimate with a stand-in font (`docs/mockups/mockup_always_on.png`, DejaVu Bold, heavier than Rajdhani) lit ~5.7 % of the pixels (Medium/Large) and ~2.8 % (Small) - `docs/mockups/mockup_always_on_sizes.png`. That is an estimate with a different font, **not a measurement**.
Status: rules VERIFIED-DOC; compliance **UNVERIFIED** until checked with the simulator heat map or on the watch (gap G-2).

## D-10 Rendering approach

* All coordinates are derived from `dc.getWidth()/getHeight()` and font heights; nothing is hard-coded to 454.
* Time font: chosen from the size setting with a fit check against the round screen (D-17); cached and recomputed only when the size setting or the power
  mode changes, so the size does not change between minutes.
* The colon is drawn with two `fillCircle` calls: the docs do not state that the number-only fonts contain ":" (gap G-4), so it is not relied on.
* `dc.setAntiAlias(true)` for the circles (guarded with `has`, per the Dc doc).
* Colon is fixed at the screen centre; hours are right-aligned to it, minutes left-aligned, so the colon never jumps.
* Steps are shown as a number only (thousands separator) - design choice, easy to change in `stepsText()`.
* The vertical position of the colon dots (`fontHeight * 14 %`) assumes the digits are vertically centred in the font box. This is **UNVERIFIED** (gap G-3); check in the simulator.
Status: API usage VERIFIED-DOC; visual result **UNVERIFIED**.

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
| Linux | docs footnote: "Connect IQ only supports Ubuntu Linux distributions" -> CI uses `ubuntu-24.04` | getting-started page |

Open point: the docs do not say whether the VS Code "Export Project" adds `-r`. The IQ build here omits `-r` (the documented form); compare file size / behaviour if the store rejects it (gap G-6).
Keep the developer key: "You will need to use the same key to sign updates to an existing app on the store. If you lose your original signing key you will not be able to update your app." (getting-started page).

## D-13 Store submission

* Flow: upload the `.iq` at "Submit an App" (`submit-an-app/`, `core-topics/publishing-to-the-store/`), fill description + screenshots; review "within 72 hours" typically.
* Guidelines (`app-review-guidelines/`): test before submitting; describe accurately; list supported devices accurately; no claim of Garmin partnership; own all IP in icons/images.
* Screenshot size/count requirements for the listing form are **not in the documentation I could read** (gap G-7): `store/` only contains suggestions.

## D-14 CI (GitHub Actions)

* Job `static-checks` (no secrets): XML well-formedness, `bash -n` on scripts, no key files tracked.
* Job `build`: Java 21, Go (to `go install` the pinned CLI), `scripts/install-sdk.sh`, key from secret `CIQ_DEVELOPER_KEY_B64`, `scripts/build.sh`, upload `NoirTime.prg` and `NoirTime.iq` as an artifact.
* Garmin does not document a CI procedure; Garmin login in CI is therefore a **community pattern** (D-03). Risk: Garmin SSO may require MFA or block datacenter IPs (gap G-8).
* Action majors (`checkout@v7`, `setup-java@v6`, `setup-go@v7`, `upload-artifact@v7`) are the existing latest majors as of 2026-10-23 (checked via the GitHub API/tags).
* The workflow never prints the key or password; the key is written to `$RUNNER_TEMP` and is not uploaded.

---

## D-15 Separate hour and minute colours; colon colour

* Owner request: hours and minutes colourable separately. `drawTime()` already drew hours and minutes as two `drawText` calls (hours right-aligned to the colon,
  minutes left-aligned), so each simply gets its own `dc.setColor` (`Dc.setColor`, API 1.0.0, <https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html>).
* **Colon colour (design choice):** if hour colour == minute colour, the colon uses that colour (the default all-white face looks exactly as before);
  if they differ, the colon is the neutral grey of the date/steps text (`0xB0B0B0`), so it does not "belong" to either half. In always-on mode it is dimmed like the rest.
* Same 8-colour palette for both. Status: API VERIFIED-DOC; look **UNVERIFIED** (mockups only).

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

## D-17 Time size Small / Medium / Large, fit check

Font heights on the fēnix® 9 Pro 47mm (device reference page): `FONT_LARGE` 71, `NUMBER_MILD` 113, `NUMBER_MEDIUM` 153, `NUMBER_HOT` 173, `NUMBER_THAI_HOT` 210 px;
`FONT_SMALL` 53 and `FONT_XTINY` 37 px for date/steps.

| Setting | High power (first that fits) | Always-on (first that fits) |
|---|---|---|
| Small | `NUMBER_MILD`, `LARGE` | `LARGE` |
| Medium (default) | `NUMBER_MEDIUM`, `NUMBER_MILD` | `NUMBER_MILD`, `LARGE` |
| Large | `NUMBER_THAI_HOT`, `NUMBER_HOT`, `NUMBER_MEDIUM`, `NUMBER_MILD` | `NUMBER_MILD`, `LARGE` |

* **Fit check** (`fits()` in `NoirTimeView.mc`): rows are stacked date / time / steps with 3 % spacing, so they never overlap by construction. A font is accepted only if
  the corners of the time box (`2 x width("00") + colon gap` wide, font height tall) and of the date and steps boxes are inside the circle of radius `width/2 - 12 px`.
  Widths are measured with `Dc.getTextWidthInPixels` and heights with `Dc.getFontHeight` (API 1.0.0) on the real device fonts at run time; integer maths only.
  The date box uses the sample "Wed 30 Sep" and the steps box "100,000"; a longer localised date could still be wider (G-13).
* So "Large" means "the largest that fits"; on this screen it may end up the same as Medium - the docs give heights but no glyph widths, so which one wins is not knowable before running (G-13).
* **Always-on** is capped at `NUMBER_MILD` for all sizes to keep the lit area within the burn-in limits (D-09); Small uses the 71 px `FONT_LARGE` so the setting still has a visible effect. The 12 px edge margin also covers the 8 px AOD shift.
Status: API VERIFIED-DOC; actual sizes **UNVERIFIED**.

## D-18 Migration from `TimeColor`

* The old `TimeColor` property is removed; `HourColor` and `MinuteColor` default to its old default (white), so the default face is unchanged.
* No value migration code: the app has never been published or installed (it has never been compiled, G-1), so no user has a stored `TimeColor`. The docs read do not say
  what happens to stored values of a removed property after an app update, so if this matters later, keep the old key and copy it once (`Properties.getValue`/`setValue`).
Status: design decision; based on the project state, not on runtime behaviour.

## Open gaps

| # | Gap | Why | Resolution |
|---|---|---|---|
| G-1 | **Project has never been compiled; no simulator run; no real screenshots.** | The device files for `fenix9pro47mm` are served only to a logged-in Garmin account (`api.gcs.garmin.com/ciq-product-onboarding/devices` -> HTTP 401). No credentials were available and none were guessed or bypassed; no device files were fabricated. `monkeyc` cannot build without them. | Run `scripts/install-sdk.sh` (or the official SDK Manager) with your Garmin account, then `scripts/build.sh`. Fix any compiler message - strict mode may flag small typing details I could not test. |
| G-2 | Burn-in compliance not measured | needs simulator heat map / watch | Simulator: *File -> View Screen Heat Map*; also watch for 10+ min in always-on |
| G-3 | Glyph centring of the colon dots, final font choice and spacing not seen with real fonts | needs simulator | adjust `dotOffset` (14 %) in `drawTime` |
| G-4 | Colon glyph in number fonts undocumented | docs silent | circles are used, no dependency |
| G-5 | Hebrew date rendering / RTL order unverified | needs device language Hebrew | test in simulator with language set to Hebrew |
| G-6 | `-r` for the `.iq` export undocumented | VS Code extension behaviour not documented | omit (documented form) |
| G-7 | Store screenshot specs not documented in the sources read | listing form is behind the Garmin login | see the form when you submit; `docs/mockups` are NOT usable as screenshots |
| G-8 | CI login with Garmin account may hit MFA/IP blocking | undocumented third-party pattern | fall back to building locally (README "Option B") |
| G-9 | Device's API level not stated in the device page | stored in login-gated device files | the first build tells you (compiler error if `minApiLevel` is too high) |
| G-10 | SDK licence | The agreement must be read and accepted by you (a person) | `connect-iq-sdk-manager agreement view`, then set the repo variable `CIQ_AGREEMENT_HASH` |
| G-11 | Exact place of the on-device settings on the fēnix 9 Pro | docs only say "the system Watch Face menu"; no fēnix 9 manual was checked | look in the watch-face menu (where faces are chosen/edited) |
| G-12 | Coexistence of `getSettingsView()` with the native editor on fēnix 8+/9; whether `onSettingsChanged()` fires after an on-device change; whether `MenuItem.setSubLabel` + `Menu2.updateItem` refresh the visible menu immediately | not documented | test on the simulator/watch; the face re-reads properties each update anyway |
| G-13 | Which font each size really gets; long localised dates (e.g. Hebrew) wider than the sample "Wed 30 Sep" | font widths not documented; needs device files | check all 3 sizes x 2 modes in the simulator, also in Hebrew |
| G-14 | Hebrew in the menu sub-labels / phone settings list | needs device/phone | look at both with the language set to Hebrew |

## What WAS verified in this session

* SDK 9.3.0 downloaded from Garmin's official link, `monkeyc` runs (version printed).
* All resource XML files validate against the SDK's `resources.xsd`; `manifest.xml` and workflow YAML are well-formed.
* Every API used exists in the SDK's own API documentation with the API level shown in D-04, and `getDisplayMode`/`setAntiAlias` list the fēnix® 9 Pro 47mm as supported.
* Shell scripts parse (`bash -n`).
* Launcher icon is 65 x 65 PNG (D-01).
* The colour list in `settings.xml` equals `NoirSettings.colorValues()`; every `Rez.Strings`/`@Strings` id used exists in both English and Hebrew strings (script check).
* All doc URLs cited in D-08, D-15 - D-17 returned HTTP 200 (2026-10-24).
