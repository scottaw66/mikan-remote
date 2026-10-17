#!/usr/bin/env bash
# scripts/release.sh — produce a Developer ID-signed, notarized MikanRemoteServer.app,
# install it to /Applications and relaunch it (unless MIKAN_SKIP_INSTALL=1), then
# package a DMG and publish it to the updater feed via make-dmg.sh when the version
# in project.yml hasn't shipped yet. Notarizing is what stops macOS XProtect's
# behavioral engine from flagging this hidden-UI / system-access app as malware.
#
# Requires (one-time): Xcode signed into the BlueDragonfly LLC account (team
# RP42XZ2CW9; Local.xcconfig sets DEVELOPMENT_TEAM to match), and a notarytool
# credential profile. Defaults to the team's shared "bluedragonfly-notary"
# profile; override with MIKAN_NOTARY_PROFILE=<name>.
#
# Usage: ./scripts/release.sh

set -euo pipefail

PROJECT="MikanRemoteServer.xcodeproj"
SCHEME="MikanRemoteServer"
APP_NAME="MikanRemoteServer"
TEAM_ID="RP42XZ2CW9"
NOTARY_PROFILE="${MIKAN_NOTARY_PROFILE:-bluedragonfly-notary}"

BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/Export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
INSTALL_DIR="/Applications"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

cd "$(dirname "$0")/.."

step() { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }
fail() { printf "\n\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

step "Pre-flight"
command -v xcodegen >/dev/null || fail "xcodegen not installed (brew install xcodegen)."
# Local.xcconfig (gitignored) picks the signing team for the archive; it must be
# the team this script exports and notarizes as, or the export fails late.
grep -Eq "^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*$TEAM_ID[[:space:]]*$" Local.xcconfig 2>/dev/null \
  || fail "Local.xcconfig must set DEVELOPMENT_TEAM = $TEAM_ID (and BUNDLE_PREFIX = com.bluedragonfly)."
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  fail "notarytool profile '$NOTARY_PROFILE' missing. Create with:
  xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id 'you@example.com' --team-id $TEAM_ID --password 'app-specific-pw'"
fi

step "Regenerating project"
xcodegen generate

rm -rf "$BUILD_DIR"; mkdir -p "$BUILD_DIR"

step "Archiving (Release)"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$BUILD_DIR/derived" -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates archive

step "Exporting Developer ID-signed app"
cat > "$BUILD_DIR/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
EOF
xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" -allowProvisioningUpdates
[ -d "$APP_PATH" ] || fail "Exported app not found at $APP_PATH."

step "Notarizing (submitting to Apple, may take a few minutes)"
ditto -c -k --keepParent "$APP_PATH" "$BUILD_DIR/notarize.zip"
xcrun notarytool submit "$BUILD_DIR/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait

step "Stapling ticket"
xcrun stapler staple "$APP_PATH"

step "Verifying Gatekeeper acceptance"
spctl -a -vvv -t exec "$APP_PATH"

# MIKAN_SKIP_INSTALL=1 publishes without installing here, so the copy already
# in /Applications takes the release through its own updater (Scott installs
# that way from 1.2.0 on, as with TZed, VOB and Claude Usage). Off by default,
# so a plain run still installs and relaunches.
if [ "${MIKAN_SKIP_INSTALL:-0}" = 1 ]; then
  step "Skipping install (MIKAN_SKIP_INSTALL=1): the installed copy updates itself"
else
  step "Installing to $INSTALL_DIR/$APP_NAME.app"
  pkill -x "$APP_NAME" 2>/dev/null || true
  rm -rf "$INSTALL_DIR/$APP_NAME.app"
  cp -R "$APP_PATH" "$INSTALL_DIR/"
  [ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$INSTALL_DIR/$APP_NAME.app" >/dev/null 2>&1 || true

  step "Verifying installed bundle"
  xcrun stapler validate "$INSTALL_DIR/$APP_NAME.app"
  spctl -a -vvv -t exec "$INSTALL_DIR/$APP_NAME.app"

  step "Relaunching $APP_NAME"
  # The install step pkills the running instance; without this the user is left
  # running nothing (or a stale build if the kill failed).
  open "$INSTALL_DIR/$APP_NAME.app"
fi

# Package a drag-to-/Applications DMG (signed, notarized, stapled) at
# dist/MikanRemoteServer-<version>.dmg, tagged mikanremote-v<version>, and publish
# it to the updater feed (make-dmg.sh → publish-update.sh, since 1.2.0).
# make-dmg.sh exits 3 when this version already shipped (or the tree is dirty):
# that's reported, not a failure.
step "Creating DMG"
dmg_status=0
./scripts/make-dmg.sh || dmg_status=$?
[ "$dmg_status" -eq 0 ] || [ "$dmg_status" -eq 3 ] || exit "$dmg_status"
printf "\n\033[1;32m✓ %s notarized and stapled%s%s.\033[0m\n" "$APP_NAME" "$([ "${MIKAN_SKIP_INSTALL:-0}" = 1 ] || echo ", installed, relaunched")" "$([ "$dmg_status" -eq 0 ] && echo "; DMG built and published" || echo " (no DMG, see above)")"
