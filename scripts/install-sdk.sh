#!/usr/bin/env bash
# Installs the Connect IQ SDK and the device files of every product in manifest.xml (38, D-36) WITHOUT the GUI SDK Manager,
# using the community CLI https://github.com/lindell/connect-iq-sdk-manager-cli (pinned, Apache-2.0).
# This is NOT an official Garmin tool - see DECISIONS.md D-03. On a desktop you can use the official
# SDK Manager instead (https://developer.garmin.com/connect-iq/sdk/) and skip this script.
#
# Required environment:
#   GARMIN_USERNAME / GARMIN_PASSWORD  - Garmin account (device files are only served to logged-in users)
#   CIQ_AGREEMENT_HASH                 - hash printed by `connect-iq-sdk-manager agreement view`
#                                        AFTER YOU HAVE READ THE AGREEMENT. Running this script accepts it
#                                        on your behalf.
# Optional: CIQ_SDK_VERSION (default 9.3.0), CIQ_SDK_MANAGER_VERSION (default v0.8.4)
set -euo pipefail
SDK_VERSION="${CIQ_SDK_VERSION:-9.3.0}"
MGR_VERSION="${CIQ_SDK_MANAGER_VERSION:-v0.8.4}"
: "${GARMIN_USERNAME:?set GARMIN_USERNAME}"
: "${GARMIN_PASSWORD:?set GARMIN_PASSWORD}"
: "${CIQ_AGREEMENT_HASH:?set CIQ_AGREEMENT_HASH (see README)}"
cd "$(dirname "$0")/.."

if ! command -v connect-iq-sdk-manager >/dev/null; then
  GOBIN="${GOBIN:-$HOME/go/bin}" go install "github.com/lindell/connect-iq-sdk-manager-cli@${MGR_VERSION}"
  # The module installs a binary named after the module path.
  if [ -x "${GOBIN:-$HOME/go/bin}/connect-iq-sdk-manager-cli" ]; then
    ln -sf "${GOBIN:-$HOME/go/bin}/connect-iq-sdk-manager-cli" "${GOBIN:-$HOME/go/bin}/connect-iq-sdk-manager"
  fi
  export PATH="${GOBIN:-$HOME/go/bin}:$PATH"
fi

connect-iq-sdk-manager agreement accept --agreement-hash "$CIQ_AGREEMENT_HASH"
connect-iq-sdk-manager login            # reads GARMIN_USERNAME / GARMIN_PASSWORD from the environment
connect-iq-sdk-manager sdk set "$SDK_VERSION"
SDK_BIN="$(connect-iq-sdk-manager sdk current-path --bin)"
export PATH="$SDK_BIN:$PATH"
# --include-fonts: the simulator crashes when a watch face draws text without the device fonts (DECISIONS D-23)
connect-iq-sdk-manager device download --manifest=manifest.xml --include-fonts
echo "SDK bin: $SDK_BIN"
echo "Add to PATH:  export PATH=\"$SDK_BIN:\$PATH\""
if [ -n "${GITHUB_PATH:-}" ]; then echo "$SDK_BIN" >> "$GITHUB_PATH"; fi
