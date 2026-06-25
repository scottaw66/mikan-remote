#!/usr/bin/env bash
# scripts/release.sh — produce a Developer ID-signed, notarized MikanBar.app and
# install it to /Applications. Notarizing is what stops macOS XProtect's
# behavioral engine from flagging this hidden-UI / system-access app as malware.
#
# Requires (one-time): Xcode signed into your Apple ID, the paid Developer
# Program (team CK52C8CDVM), and a notarytool credential profile. Defaults to
# the "mikanremote" profile; override with MIKAN_NOTARY_PROFILE=<name>.
#
# Usage: ./scripts/release.sh

set -euo pipefail

PROJECT="MikanRemoteServer.xcodeproj"
SCHEME="MikanRemoteServer"
APP_NAME="MikanRemoteServer"
TEAM_ID="CK52C8CDVM"
NOTARY_PROFILE="${MIKAN_NOTARY_PROFILE:-mikanremote}"

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

step "Installing to $INSTALL_DIR/$APP_NAME.app"
pkill -x "$APP_NAME" 2>/dev/null || true
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$APP_PATH" "$INSTALL_DIR/"
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$INSTALL_DIR/$APP_NAME.app" >/dev/null 2>&1 || true

step "Verifying installed bundle"
xcrun stapler validate "$INSTALL_DIR/$APP_NAME.app"
spctl -a -vvv -t exec "$INSTALL_DIR/$APP_NAME.app"
printf "\n\033[1;32m✓ %s notarized, stapled, installed.\033[0m\n" "$APP_NAME"
