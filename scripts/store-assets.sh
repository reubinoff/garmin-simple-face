#!/usr/bin/env bash
# Builds store images from the REAL simulator screenshots in docs/screenshots/.
#
#   scripts/store-assets.sh [out_dir]      (default: store-assets)
#
# * cover.png: 500 x 500 px, sRGB, no transparency, 10 px padding, solid non-black background, no text or branding
#   (Garmin Connect IQ brand guidelines, "App Store Assets": https://developer.garmin.com/brand-guidelines/connect-iq).
#   For watch faces Garmin suggests a preview of the face; the round screen of the Large yellow/white shot is used.
# * screenshot_*: every docs/screenshots/active_* and aod_* frame, PNG if under 150 KB, else JPG (quality stepped down).
# * hero_1440x720.png, icon_64color_128.png, icon_24bit_128.png: copied unchanged from store/hero and store/icons.
# Needs ImageMagick (`magick` 7 or `convert` 6). Problems are reported as warnings; the script exits 0 on image problems.
set -uo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-store-assets}"
IM=$(command -v magick || command -v convert) || { echo "::warning::ImageMagick not found - no store images"; exit 0; }
LIMIT=$((150 * 1024))
BG='#3A3F47'   # solid dark slate: not black, not transparent, not a Garmin brand colour
SRC=docs/screenshots/active_large_yellow-white.png
mkdir -p "$OUT"
warn() { echo "::warning::$*"; }

# Cover: keep only the round screen (radius 227 around the centre of the 454 x 454 frame), 480 px + 10 px padding.
if [ -f "$SRC" ]; then
  MASK=$(mktemp --suffix=.png)
  "$IM" -size 454x454 xc:black -fill white -draw "circle 227,227 227,0" "$MASK"
  "$IM" -size 454x454 "xc:$BG" "$SRC" "$MASK" -composite -resize 480x480 -background "$BG" -gravity center -extent 500x500 \
    -alpha remove -alpha off -colorspace sRGB -strip "PNG24:$OUT/cover.png" || warn "cover.png could not be made"
  rm -f "$MASK"
else
  warn "$SRC missing - no cover image"
fi

for f in docs/screenshots/active_*.png docs/screenshots/aod_*.png; do
  [ -f "$f" ] || continue
  n=$(basename "$f" .png)
  "$IM" "$f" -alpha remove -alpha off -colorspace sRGB -strip -define png:compression-level=9 "PNG24:$OUT/screenshot_$n.png" || { warn "$n failed"; continue; }
  if [ "$(stat -c %s "$OUT/screenshot_$n.png")" -gt "$LIMIT" ]; then
    rm -f "$OUT/screenshot_$n.png"
    for q in 92 85 75 65; do
      "$IM" "$f" -alpha remove -alpha off -colorspace sRGB -strip -quality $q "$OUT/screenshot_$n.jpg"
      [ "$(stat -c %s "$OUT/screenshot_$n.jpg")" -le "$LIMIT" ] && break
    done
    [ "$(stat -c %s "$OUT/screenshot_$n.jpg")" -le "$LIMIT" ] || warn "$n.jpg is still over 150 KB"
  fi
done

# Committed store assets ride along with every release: hero image (1440 x 720, store limit 2048 KB) and the two
# 128 x 128 device icons (64-color and 24-bit). They are copied as-is; a missing or failed copy is only a warning.
for a in store/hero/hero_1440x720.png store/icons/icon_64color_128.png store/icons/icon_24bit_128.png; do
  if [ -f "$a" ]; then cp "$a" "$OUT"/ || warn "$(basename "$a") could not be copied"
  else warn "$a missing - not attached to the release"; fi
done

for f in "$OUT"/*; do
  [ -f "$f" ] || continue
  sz=$(stat -c %s "$f")
  case "$f" in */cover.png|*/hero_*.png|*/icon_*.png) ;; *) [ "$sz" -le "$LIMIT" ] || warn "$(basename "$f") is $sz bytes (> 150 KB)";; esac
  echo "$(basename "$f")  $("$IM" identify -format '%wx%h %[colorspace] alpha=%A' "$f" 2>/dev/null || identify -format '%wx%h %[colorspace] alpha=%A' "$f")  $sz bytes"
done
exit 0
