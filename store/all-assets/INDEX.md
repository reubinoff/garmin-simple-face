# Clean Air — Connect IQ Store images

Everything the Garmin Developer Dashboard asks for, in one place. All files are PNG, sRGB, no transparency.

Where to upload (Developer Dashboard → your app → Edit / Upload new version → *Cover Image & Icons* / *Screenshots*):

- **Hero image** (optional, max 2048 KB): `hero_1440x720.png`
- **Cover image** (500×500, sRGB, no transparency): `cover_500x500.png`
- **Screenshots** (each under 150 KB): any of the `screenshot_*.png` files — `active_*` = normal mode, `aod_*` = always-on (low-power) mode
- **On-device store icons** (128×128, answer *Yes* to the on-device icon option): `icon_64color_128x128.png` → 64-colour icon, `icon_24bit_128x128.png` → 24-bit icon

Screenshots: real Connect IQ simulator frames (SDK 9.3.0, fēnix 9 Pro 47mm) with simulated activity data (7,432 steps, 3 notifications); the always-on frames show the current always-on look (digits at 70 %, 4 px minute-of-day shift).

| File | Pixels | Size | What it's for |
|---|---|---|---|
| `hero_1440x720.png` | 1440×720 | 123,263 B (120.4 KB) | Hero image (optional, max 2048 KB): title "CLEAN AIR" in Bebas Neue + real simulator screenshot |
| `cover_500x500.png` | 500×500 | 39,045 B (38.1 KB) | Cover image: round screen of active_large_yellow-white on a slate background, no text |
| `icon_64color_128x128.png` | 128×128 | 1,513 B (1.5 KB) | On-device store icon, low-colour (MIP) devices: 8-bit palette, only 64-colour palette entries |
| `icon_24bit_128x128.png` | 128×128 | 8,244 B (8.1 KB) | On-device store icon, full-colour (AMOLED) devices: 24-bit RGB |
| `screenshot_active_large_white-white.png` | 454×454 | 56,566 B (55.2 KB) | Screenshot, active mode — large, white-white |
| `screenshot_active_large_white-white_calories-floors-temperature.png` | 454×454 | 57,040 B (55.7 KB) | Screenshot, active mode — large, white-white, calories-floors-temperature |
| `screenshot_active_large_white-white_no-fields.png` | 454×454 | 54,019 B (52.8 KB) | Screenshot, active mode — large, white-white, no-fields |
| `screenshot_active_large_yellow-white.png` | 454×454 | 56,911 B (55.6 KB) | Screenshot, active mode — large, yellow-white |
| `screenshot_active_medium_silver-teal_intensity-notifications-distance.png` | 454×454 | 56,993 B (55.7 KB) | Screenshot, active mode — medium, silver-teal, intensity-notifications-distance |
| `screenshot_active_medium_white-orange.png` | 454×454 | 56,298 B (55.0 KB) | Screenshot, active mode — medium, white-orange |
| `screenshot_active_medium_white-orange_steps-only.png` | 454×454 | 55,033 B (53.7 KB) | Screenshot, active mode — medium, white-orange, steps-only |
| `screenshot_active_medium_white-white.png` | 454×454 | 56,348 B (55.0 KB) | Screenshot, active mode — medium, white-white |
| `screenshot_active_medium_white-white_batterydays-stress.png` | 454×454 | 55,686 B (54.4 KB) | Screenshot, active mode — medium, white-white, batterydays-stress |
| `screenshot_active_medium_white-white_steps-bb-hr.png` | 454×454 | 57,653 B (56.3 KB) | Screenshot, active mode — medium, white-white, steps-bb-hr |
| `screenshot_active_small_white-cyan.png` | 454×454 | 56,002 B (54.7 KB) | Screenshot, active mode — small, white-cyan |
| `screenshot_active_xlarge_lime-magenta.png` | 454×454 | 56,775 B (55.4 KB) | Screenshot, active mode — xlarge, lime-magenta |
| `screenshot_active_xlarge_white-cyan.png` | 454×454 | 56,873 B (55.5 KB) | Screenshot, active mode — xlarge, white-cyan |
| `screenshot_active_xlarge_white-cyan_hr-battery.png` | 454×454 | 56,259 B (54.9 KB) | Screenshot, active mode — xlarge, white-cyan, hr-battery |
| `screenshot_active_xxlarge_gold-blue.png` | 454×454 | 56,444 B (55.1 KB) | Screenshot, active mode — xxlarge, gold-blue |
| `screenshot_active_xxlarge_white-cyan.png` | 454×454 | 57,056 B (55.7 KB) | Screenshot, active mode — xxlarge, white-cyan |
| `screenshot_active_xxlarge_white-white.png` | 454×454 | 56,776 B (55.4 KB) | Screenshot, active mode — xxlarge, white-white |
| `screenshot_aod_large_white-white.png` | 454×454 | 56,223 B (54.9 KB) | Screenshot, always-on (AOD) mode — large, white-white |
| `screenshot_aod_large_white-white_calories-floors-temperature.png` | 454×454 | 56,790 B (55.5 KB) | Screenshot, always-on (AOD) mode — large, white-white, calories-floors-temperature |
| `screenshot_aod_large_white-white_no-fields.png` | 454×454 | 53,764 B (52.5 KB) | Screenshot, always-on (AOD) mode — large, white-white, no-fields |
| `screenshot_aod_large_yellow-white.png` | 454×454 | 55,895 B (54.6 KB) | Screenshot, always-on (AOD) mode — large, yellow-white |
| `screenshot_aod_medium_silver-teal_intensity-notifications-distance.png` | 454×454 | 56,489 B (55.2 KB) | Screenshot, always-on (AOD) mode — medium, silver-teal, intensity-notifications-distance |
| `screenshot_aod_medium_white-orange.png` | 454×454 | 55,918 B (54.6 KB) | Screenshot, always-on (AOD) mode — medium, white-orange |
| `screenshot_aod_medium_white-orange_steps-only.png` | 454×454 | 54,792 B (53.5 KB) | Screenshot, always-on (AOD) mode — medium, white-orange, steps-only |
| `screenshot_aod_medium_white-white.png` | 454×454 | 55,345 B (54.0 KB) | Screenshot, always-on (AOD) mode — medium, white-white |
| `screenshot_aod_medium_white-white_batterydays-stress.png` | 454×454 | 55,531 B (54.2 KB) | Screenshot, always-on (AOD) mode — medium, white-white, batterydays-stress |
| `screenshot_aod_medium_white-white_steps-bb-hr.png` | 454×454 | 56,422 B (55.1 KB) | Screenshot, always-on (AOD) mode — medium, white-white, steps-bb-hr |
| `screenshot_aod_small_white-cyan.png` | 454×454 | 55,323 B (54.0 KB) | Screenshot, always-on (AOD) mode — small, white-cyan |
| `screenshot_aod_xlarge_lime-magenta.png` | 454×454 | 56,183 B (54.9 KB) | Screenshot, always-on (AOD) mode — xlarge, lime-magenta |
| `screenshot_aod_xlarge_white-cyan.png` | 454×454 | 56,406 B (55.1 KB) | Screenshot, always-on (AOD) mode — xlarge, white-cyan |
| `screenshot_aod_xlarge_white-cyan_hr-battery.png` | 454×454 | 55,932 B (54.6 KB) | Screenshot, always-on (AOD) mode — xlarge, white-cyan, hr-battery |
| `screenshot_aod_xxlarge_gold-blue.png` | 454×454 | 56,106 B (54.8 KB) | Screenshot, always-on (AOD) mode — xxlarge, gold-blue |
| `screenshot_aod_xxlarge_white-cyan.png` | 454×454 | 56,882 B (55.5 KB) | Screenshot, always-on (AOD) mode — xxlarge, white-cyan |
| `screenshot_aod_xxlarge_white-white.png` | 454×454 | 56,048 B (54.7 KB) | Screenshot, always-on (AOD) mode — xxlarge, white-white |

Regenerate: `python3 scripts/make_icons.py` (icons), `python3 scripts/make_hero.py` (hero), then `scripts/collect-store-assets.sh` (cover + screenshots via `scripts/store-assets.sh`, this folder and INDEX.md).
