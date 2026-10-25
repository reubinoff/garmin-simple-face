#!/usr/bin/env bash
# Builds the (:test) functions in source/tests/ and runs them in the Connect IQ simulator (Run No Evil).
#   scripts/run-unit-tests.sh [--key /path/developer_key.der]
# Needs monkeyc/connectiq/monkeydo on PATH and the fenix9pro47mm device files (scripts/install-sdk.sh).
# Headless (CI): with no $DISPLAY the script re-runs itself under `xvfb-run -a`, and with no D-Bus session bus under
# `dbus-run-session` (the simulator is a GTK app and logs AT-SPI / dbind errors without one).
# Commands from "Unit Testing" (https://developer.garmin.com/connect-iq/core-topics/unit-testing/) and
# "Using Monkey C from the Command Line" (monkeydo ... -t).
# Tunables: CIQ_SIM_READY_TIMEOUT (s, default 60), CIQ_SIM_ATTEMPTS (default 3), CIQ_SIM_SETTLE (s after the port opens, default 3).
set -euo pipefail
cd "$(dirname "$0")/.."

# --- headless environment ------------------------------------------------------------------------------------------
if [ -z "${DISPLAY:-}" ] && [ -z "${CIQ_NO_XVFB:-}" ] && command -v xvfb-run >/dev/null; then
  exec env CIQ_NO_XVFB=1 xvfb-run -a -s "-screen 0 1280x1024x24" "$0" "$@"
fi
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -z "${CIQ_NO_DBUS:-}" ] && command -v dbus-run-session >/dev/null; then
  exec env CIQ_NO_DBUS=1 dbus-run-session -- "$0" "$@"
fi
export NO_AT_BRIDGE=1   # GTK: do not look for the accessibility bus

KEY="${CIQ_DEVELOPER_KEY_PATH:-$HOME/.connectiq-keys/developer_key.der}"
if [ "${1:-}" = "--key" ]; then KEY="$2"; fi
DEVICE="fenix9pro47mm"
READY_TIMEOUT="${CIQ_SIM_READY_TIMEOUT:-60}"
ATTEMPTS="${CIQ_SIM_ATTEMPTS:-3}"
SETTLE="${CIQ_SIM_SETTLE:-3}"
mkdir -p build
monkeyc -d "$DEVICE" -f monkey.jungle -o build/NoirTime-test.prg -y "$KEY" -l 3 -w -t

SIM=""
stop_sim() {
  # connectiq starts bin/simulator as a child; stop both or the simulator keeps the pipe open and the script never ends
  if [ -n "$SIM" ]; then
    pkill -P "$SIM" 2>/dev/null || true
    kill "$SIM" 2>/dev/null || true
    wait "$SIM" 2>/dev/null || true
    SIM=""
  fi
}
trap stop_sim EXIT

# The simulator's listening TCP port (seen: 1235 with SDK 9.3.0; monkeydo's shell tries a small range from 1234). Read
# passively from /proc/net/tcp (state 0A = LISTEN) so no probe connection disturbs the simulator.
sim_listening() {
  # ports 1234-1238 = hex 04D2-04D6; plain awk/grep only (Ubuntu's default awk is mawk)
  awk 'NR > 1 && $4 == "0A" { print $2 }' /proc/net/tcp /proc/net/tcp6 2>/dev/null | grep -qiE ':04D[2-6]$'
}

start_sim() {
  local build_log="build/simulator.log"
  connectiq >> "$build_log" 2>&1 &
  SIM=$!
  local waited=0
  while ! sim_listening; do
    if ! kill -0 "$SIM" 2>/dev/null; then echo "simulator exited during start-up (see $build_log)" >&2; return 1; fi
    if [ "$waited" -ge "$READY_TIMEOUT" ]; then echo "simulator not listening after ${READY_TIMEOUT}s" >&2; return 1; fi
    sleep 1; waited=$((waited + 1))
  done
  sleep "$SETTLE"   # port open before the device window is ready; give it a moment
  echo "simulator ready after $((waited + SETTLE))s"
}

: > build/simulator.log
rm -f build/unit-tests.log
result=""
for attempt in $(seq 1 "$ATTEMPTS"); do
  echo "unit tests: attempt $attempt/$ATTEMPTS"
  stop_sim
  if ! start_sim; then continue; fi
  # monkeydo -t exits 1 even when every test passes (observed with SDK 9.3.0, not documented), so the verdict
  # comes from the printed summary below, not from its exit code.
  monkeydo build/NoirTime-test.prg "$DEVICE" -t 2>&1 | tee build/unit-tests.log || true
  if grep -q "PASSED\|FAILED" build/unit-tests.log; then result=done; break; fi
  if grep -qi "unable to connect\|connection refused" build/unit-tests.log; then
    echo "monkeydo could not connect to the simulator; restarting it" >&2
  else
    echo "no test summary from monkeydo; restarting the simulator" >&2
  fi
done
stop_sim
# The simulator prints a summary "PASSED (passed=N, ...)" or "FAILED (...)" (strings in SDK 9.3.0 bin/simulator;
# the exact layout is not documented). Pass only on a PASSED summary and no FAILED.
if [ -z "$result" ] || grep -q "FAILED" build/unit-tests.log || ! grep -q "PASSED" build/unit-tests.log; then
  echo "Connect IQ unit tests failed" >&2; exit 1
fi
