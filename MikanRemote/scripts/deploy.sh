#!/usr/bin/env bash
# scripts/deploy.sh — build MikanRemote (iOS) for a connected iPhone and install it.
#
# iOS apps are NOT notarized — they're signed with a development provisioning
# profile and installed directly to a paired device. `-allowProvisioningUpdates`
# auto-registers the device and provisions the app + Share-extension App Group.
#
# Usage:
#   ./scripts/deploy.sh                 # auto-pick the first available iPhone
#   ./scripts/deploy.sh <device-udid>   # target a specific device
#   MIKAN_DEVICE='みかん' ./scripts/deploy.sh   # match a device by name

set -euo pipefail

SCHEME="MikanRemote"
PROJECT="MikanRemote.xcodeproj"
BUNDLE_ID="blue.dragonfly.MikanRemote"
CONFIG="Release"
DERIVED="build/derived"

cd "$(dirname "$0")/.."

step() { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }
fail() { printf "\n\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

# ── Resolve target device ────────────────────────────────────────────────────
UDID="${1:-}"
if [ -z "$UDID" ]; then
  LIST=$(xcrun devicectl list devices 2>/dev/null)
  if [ -n "${MIKAN_DEVICE:-}" ]; then
    UDID=$(printf '%s\n' "$LIST" | awk -v n="$MIKAN_DEVICE" '$0 ~ n && /available/ {print $(NF-3); exit}')
  else
    # first available iPhone
    UDID=$(printf '%s\n' "$LIST" | awk '/iPhone/ && /available/ {print $(NF-3); exit}')
  fi
fi
[ -n "$UDID" ] || fail "No available iPhone found. Plug in / unlock the device, or pass a UDID. See: xcrun devicectl list devices"
step "Target device: $UDID"

step "Regenerating project"
command -v xcodegen >/dev/null || fail "xcodegen not installed (brew install xcodegen)."
xcodegen generate

step "Building $SCHEME ($CONFIG) for device"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
  -destination "platform=iOS,id=$UDID" \
  -derivedDataPath "$DERIVED" -allowProvisioningUpdates build

APP="$DERIVED/Build/Products/$CONFIG-iphoneos/$SCHEME.app"
[ -d "$APP" ] || fail "Built app not found at $APP."

step "Installing to device"
xcrun devicectl device install app --device "$UDID" "$APP"

step "Launching"
xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" || \
  echo "  (launch skipped — open it from the Home Screen if needed)"

printf "\n\033[1;32m✓ %s installed and launched on %s.\033[0m\n" "$SCHEME" "$UDID"
