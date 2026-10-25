#!/usr/bin/env bash
# Static battery audit of the watch-face code (docs/battery-report.md, DECISIONS.md D-42). Runs in CI and before every release.
# Fails when source/ (tests excluded, comments stripped) uses an API that makes a watch face do work outside the
# system's own once-a-minute / ~10 s-after-a-wrist-raise onUpdate calls, or that switches on a sensor or the radio:
#   onPartialUpdate (per-second updates)      WatchFace: https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFace.html
#   Timer / animations (not allowed in sleep)  App types:  https://developer.garmin.com/connect-iq/connect-iq-basics/app-types/
#   Background / temporal events, web requests, Sensor / Position listeners, Attention (backlight, vibration)
# and when manifest.xml asks for a permission other than SensorHistory (Body Battery / stress history, D-06, D-27).
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
files=$(find source -name '*.mc' -not -path 'source/tests/*' | sort)
patterns=(
  'onPartialUpdate'
  'Timer\.'
  'Background\.'
  'registerForTemporalEvent'
  'ServiceDelegate'
  'makeWebRequest'
  'Communications\.'
  'Sensor\.(enableSensorEvents|setEnabledSensors|registerSensorDataListener|enableSensorType)'
  'Position\.enableLocationEvents'
  'Attention\.'
  'WatchUi\.animate'
  'Complications\.(subscribeToUpdates|registerComplicationChangeCallback)'
)
for f in $files; do
  stripped=$(sed -e 's://.*$::' "$f")
  for p in "${patterns[@]}"; do
    if hits=$(printf '%s\n' "$stripped" | grep -nE "$p"); then
      echo "::error file=$f::battery audit: '$p' found:"; echo "$hits"; fail=1
    fi
  done
done

perms=$(grep -oE '<iq:uses-permission id="[^"]+"' manifest.xml | sed -E 's/.*id="([^"]+)"/\1/' | sort -u | tr '\n' ' ')
if [ "$perms" != "SensorHistory " ]; then
  echo "::error file=manifest.xml::battery audit: permissions are '$perms', expected only SensorHistory"; fail=1
fi

# loadResource (font loading) only in the layout cache, never in the per-frame path.
lr=$(sed -e 's://.*$::' source/NoirTimeView.mc | grep -c 'loadResource' || true)
if [ "$lr" != "1" ]; then
  echo "::error file=source/NoirTimeView.mc::battery audit: expected exactly one loadResource (in updateLayout), found $lr"; fail=1
fi

if [ "$fail" = 0 ]; then
  echo "battery audit OK: no per-second updates, timers, background, web, sensor/position listeners, attention or animation;"
  echo "permissions: ${perms}; one loadResource (layout cache only). Files: $(echo $files | wc -w)"
fi
exit $fail
