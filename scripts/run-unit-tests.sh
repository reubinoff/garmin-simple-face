#!/usr/bin/env bash
# Builds the (:test) functions in source/tests/ and runs them in the Connect IQ simulator (Run No Evil).
#   scripts/run-unit-tests.sh [--key /path/developer_key.der]
# Needs monkeyc/connectiq/monkeydo on PATH, the fenix9pro47mm device files (scripts/install-sdk.sh) and a display;
# on a headless machine run it under xvfb:  xvfb-run -a scripts/run-unit-tests.sh
# Commands from "Unit Testing" (https://developer.garmin.com/connect-iq/core-topics/unit-testing/) and
# "Using Monkey C from the Command Line" (monkeydo ... -t).
set -euo pipefail
cd "$(dirname "$0")/.."
KEY="${CIQ_DEVELOPER_KEY_PATH:-$HOME/.connectiq-keys/developer_key.der}"
if [ "${1:-}" = "--key" ]; then KEY="$2"; fi
DEVICE="fenix9pro47mm"
mkdir -p build
monkeyc -d "$DEVICE" -f monkey.jungle -o build/NoirTime-test.prg -y "$KEY" -l 3 -w -t
connectiq &
SIM=$!
trap 'kill $SIM 2>/dev/null || true' EXIT
sleep "${CIQ_SIM_WAIT:-10}"   # the simulator must be running before monkeydo connects
monkeydo build/NoirTime-test.prg "$DEVICE" -t | tee build/unit-tests.log
# The simulator prints a summary "PASSED (passed=N, ...)" or "FAILED (...)" (strings in SDK 9.3.0 bin/simulator;
# the exact layout is not documented). Pass only on a PASSED summary and no FAILED.
if grep -q "FAILED" build/unit-tests.log || ! grep -q "PASSED" build/unit-tests.log; then
  echo "Connect IQ unit tests failed" >&2; exit 1
fi
