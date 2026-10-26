#!/usr/bin/env bash
# Runs the debug build in the Connect IQ simulator (needs a desktop session; on a headless box use xvfb-run).
#   scripts/run-simulator.sh [--key /path/developer_key.der]
# Commands follow "Using Monkey C from the Command Line":
#   https://developer.garmin.com/connect-iq/reference-guides/monkey-c-command-line-setup/
set -euo pipefail
cd "$(dirname "$0")/.."
KEY="${CIQ_DEVELOPER_KEY_PATH:-$HOME/.connectiq-keys/developer_key.der}"
if [ "${1:-}" = "--key" ]; then KEY="$2"; fi
mkdir -p build
monkeyc -d fenix9pro47mm -f monkey.jungle -o build/CleanAir-debug.prg -y "$KEY" -l 3 -w
connectiq &
sleep 8   # give the simulator time to start
monkeydo build/CleanAir-debug.prg fenix9pro47mm
