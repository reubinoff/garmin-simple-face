# Clean Air — Connect IQ Store images

Everything the Garmin Developer Dashboard asks for, in one place. All files are PNG, sRGB.

Where to upload (Developer Dashboard → your app → Edit / Upload new version):

- **Hero image** (optional, max 2048 KB): `hero_1440x720.png`
- **Cover image / app icon for the store listing** (500×500, no transparency): `cover_500x500.png`
- **Screenshots** (each under 150 KB): any of the `screenshot_*.png` files — `active_*` = normal mode, `aod_*` = always-on (low-power) mode
- **Device icons** (128×128): `icon_64color_128x128.png` (64-colour devices) and `icon_24bit_128x128.png` (full-colour AMOLED devices)

| File | Pixels | Size | What it's for |
|---|---|---|---|
| `hero_1440x720.png` | 1440×720 | 119,375 B (116.6 KB) | Store hero banner — title "CLEAN AIR" (Bebas Neue) + real simulator screenshot |
| `cover_500x500.png` | 500×500 | 36,885 B (36.0 KB) | Store cover image (round screen of active_large_yellow-white on slate background, no text) |
| `icon_64color_128x128.png` | 128×128 | 1,930 B (1.9 KB) | Device icon, 64-colour palette |
| `icon_24bit_128x128.png` | 128×128 | 7,880 B (7.7 KB) | Device icon, 24-bit colour |
| `screenshot_active_large_white-white.png` | 454×454 | 55,644 B (54.3 KB) | Screenshot, active mode — large, white-white |
| `screenshot_active_large_white-white_calories-floors-temperature.png` | 454×454 | 55,787 B (54.5 KB) | Screenshot, active mode — large, white-white, calories-floors-temperature |
| `screenshot_active_large_white-white_no-fields.png` | 454×454 | 54,010 B (52.7 KB) | Screenshot, active mode — large, white-white, no-fields |
| `screenshot_active_large_yellow-white.png` | 454×454 | 55,858 B (54.5 KB) | Screenshot, active mode — large, yellow-white |
| `screenshot_active_medium_silver-teal_intensity-notifications-distance.png` | 454×454 | 55,949 B (54.6 KB) | Screenshot, active mode — medium, silver-teal, intensity-notifications-distance |
| `screenshot_active_medium_white-orange.png` | 454×454 | 55,891 B (54.6 KB) | Screenshot, active mode — medium, white-orange |
| `screenshot_active_medium_white-orange_steps-only.png` | 454×454 | 54,914 B (53.6 KB) | Screenshot, active mode — medium, white-orange, steps-only |
| `screenshot_active_medium_white-white.png` | 454×454 | 55,532 B (54.2 KB) | Screenshot, active mode — medium, white-white |
| `screenshot_active_medium_white-white_batterydays-stress.png` | 454×454 | 55,171 B (53.9 KB) | Screenshot, active mode — medium, white-white, batterydays-stress |
| `screenshot_active_medium_white-white_steps-bb-hr.png` | 454×454 | 56,707 B (55.4 KB) | Screenshot, active mode — medium, white-white, steps-bb-hr |
| `screenshot_active_small_white-cyan.png` | 454×454 | 55,266 B (54.0 KB) | Screenshot, active mode — small, white-cyan |
| `screenshot_active_xlarge_lime-magenta.png` | 454×454 | 56,443 B (55.1 KB) | Screenshot, active mode — xlarge, lime-magenta |
| `screenshot_active_xlarge_white-cyan.png` | 454×454 | 55,745 B (54.4 KB) | Screenshot, active mode — xlarge, white-cyan |
| `screenshot_active_xlarge_white-cyan_hr-battery.png` | 454×454 | 57,129 B (55.8 KB) | Screenshot, active mode — xlarge, white-cyan, hr-battery |
| `screenshot_active_xxlarge_gold-blue.png` | 454×454 | 56,180 B (54.9 KB) | Screenshot, active mode — xxlarge, gold-blue |
| `screenshot_active_xxlarge_white-cyan.png` | 454×454 | 56,637 B (55.3 KB) | Screenshot, active mode — xxlarge, white-cyan |
| `screenshot_active_xxlarge_white-white.png` | 454×454 | 56,706 B (55.4 KB) | Screenshot, active mode — xxlarge, white-white |
| `screenshot_aod_large_white-white.png` | 454×454 | 55,209 B (53.9 KB) | Screenshot, always-on (AOD) mode — large, white-white |
| `screenshot_aod_large_white-white_calories-floors-temperature.png` | 454×454 | 55,780 B (54.5 KB) | Screenshot, always-on (AOD) mode — large, white-white, calories-floors-temperature |
| `screenshot_aod_large_white-white_no-fields.png` | 454×454 | 53,891 B (52.6 KB) | Screenshot, always-on (AOD) mode — large, white-white, no-fields |
| `screenshot_aod_large_yellow-white.png` | 454×454 | 55,326 B (54.0 KB) | Screenshot, always-on (AOD) mode — large, yellow-white |
| `screenshot_aod_medium_silver-teal_intensity-notifications-distance.png` | 454×454 | 56,171 B (54.9 KB) | Screenshot, always-on (AOD) mode — medium, silver-teal, intensity-notifications-distance |
| `screenshot_aod_medium_white-orange.png` | 454×454 | 55,456 B (54.2 KB) | Screenshot, always-on (AOD) mode — medium, white-orange |
| `screenshot_aod_medium_white-orange_steps-only.png` | 454×454 | 54,649 B (53.4 KB) | Screenshot, always-on (AOD) mode — medium, white-orange, steps-only |
| `screenshot_aod_medium_white-white.png` | 454×454 | 54,879 B (53.6 KB) | Screenshot, always-on (AOD) mode — medium, white-white |
| `screenshot_aod_medium_white-white_batterydays-stress.png` | 454×454 | 54,447 B (53.2 KB) | Screenshot, always-on (AOD) mode — medium, white-white, batterydays-stress |
| `screenshot_aod_medium_white-white_steps-bb-hr.png` | 454×454 | 55,606 B (54.3 KB) | Screenshot, always-on (AOD) mode — medium, white-white, steps-bb-hr |
| `screenshot_aod_small_white-cyan.png` | 454×454 | 54,885 B (53.6 KB) | Screenshot, always-on (AOD) mode — small, white-cyan |
| `screenshot_aod_xlarge_lime-magenta.png` | 454×454 | 55,781 B (54.5 KB) | Screenshot, always-on (AOD) mode — xlarge, lime-magenta |
| `screenshot_aod_xlarge_white-cyan.png` | 454×454 | 56,040 B (54.7 KB) | Screenshot, always-on (AOD) mode — xlarge, white-cyan |
| `screenshot_aod_xlarge_white-cyan_hr-battery.png` | 454×454 | 56,302 B (55.0 KB) | Screenshot, always-on (AOD) mode — xlarge, white-cyan, hr-battery |
| `screenshot_aod_xxlarge_gold-blue.png` | 454×454 | 55,793 B (54.5 KB) | Screenshot, always-on (AOD) mode — xxlarge, gold-blue |
| `screenshot_aod_xxlarge_white-cyan.png` | 454×454 | 56,252 B (54.9 KB) | Screenshot, always-on (AOD) mode — xxlarge, white-cyan |
| `screenshot_aod_xxlarge_white-white.png` | 454×454 | 55,338 B (54.0 KB) | Screenshot, always-on (AOD) mode — xxlarge, white-white |

Regenerate: `python3 scripts/make_hero.py` (hero) and `scripts/store-assets.sh <dir>` (cover + screenshots, from docs/screenshots/).
