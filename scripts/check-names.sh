#!/usr/bin/env bash
# Fails if the old product name "NoirTime" / "Noir Time" reappears anywhere users can see it (build and release
# artifact names, store text, README, docs). The app is "Clean Air" (resources/strings/strings.xml AppName).
# Allowed: the internal Monkey C class names NoirTimeApp / NoirTimeView / NoirTimeSettingsMenu / NoirTimeSettingsDelegate
# (used in source/, the manifest entry="NoirTimeApp", and in docs/tests that refer to those classes or their .mc files).
# They are never shown to the user, and renaming them would only churn history.
set -euo pipefail
cd "$(dirname "$0")/.."

# -I skips binary files (PNG, fonts). The script itself is excluded because it has to spell the forbidden names.
bad=$(git grep -n -I -P 'NoirTime(?!App\b|View\b|SettingsMenu\b|SettingsDelegate\b)|Noir[ _-]Time' \
        -- . ':!scripts/check-names.sh' || true)
if [ -n "$bad" ]; then
  echo "$bad"
  echo "::error::Old name NoirTime / Noir Time found in user-facing text or artifact names (use CleanAir / Clean Air)."
  exit 1
fi
echo "name check OK: no user-facing NoirTime / Noir Time (only the internal class names remain)"
