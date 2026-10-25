#!/usr/bin/env bash
# Builds the watch face for the fenix 9 Pro 47mm with strict type checking (-l 3) and warnings (-w).
#
#   scripts/build.sh [--key /path/developer_key.der] [--out build]
#
# Needs: Connect IQ SDK 9.3.0 `monkeyc` on PATH (see scripts/install-sdk.sh), Java 11+,
#        the device files for the products in manifest.xml (downloaded by install-sdk.sh), a developer key.
# Produces: <out>/NoirTime.prg   (release build, for sideloading to GARMIN/APPS)
#           <out>/NoirTime.iq    (store package, `monkeyc -e`)
set -euo pipefail
cd "$(dirname "$0")/.."
KEY="${CIQ_DEVELOPER_KEY_PATH:-$HOME/.connectiq-keys/developer_key.der}"
OUT="build"
DEVICE="${CIQ_DEVICE:-fenix9pro47mm}"   # PRG for one product; the .iq has every product in manifest.xml (D-36)
while [ $# -gt 0 ]; do
  case "$1" in
    --key) KEY="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
command -v monkeyc >/dev/null || { echo "monkeyc not on PATH. Run scripts/install-sdk.sh first." >&2; exit 1; }
[ -f "$KEY" ] || { echo "Developer key not found: $KEY (create it with scripts/keygen.sh)" >&2; exit 1; }
mkdir -p "$OUT"
monkeyc --version
# -d device, -f jungle, -o output, -y key, -l 3 strict typecheck, -w warnings, -r no debug info
# (https://developer.garmin.com/connect-iq/monkey-c/compiler-options/)
monkeyc -d "$DEVICE" -f monkey.jungle -o "$OUT/NoirTime.prg" -y "$KEY" -l 3 -w -r
# -e = package for the store (IQ file with binaries for every product in manifest.xml)
monkeyc -e -f monkey.jungle -o "$OUT/NoirTime.iq" -y "$KEY" -l 3 -w
ls -l "$OUT"
