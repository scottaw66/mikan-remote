#!/usr/bin/env bash
# scripts/make-dmg.sh — package a notarized MikanRemoteServer.app into a drag-to-/Applications
# DMG, then sign, notarize, and staple the DMG itself so a downloaded copy passes
# Gatekeeper without warnings. release.sh calls it as its last step; it can also be
# run on its own at any time.
#
# A DMG is a build that leaves this Mac, so it must carry a version that has never
# shipped (see "Versioning" in ~/Brain/Areas/Apps/CLAUDE.md). Before doing any work it
# exits with status 3 if the tree is dirty, if tag mikanremote-v<version> is already on
# another commit, or if the build number isn't above every earlier release's;
# release.sh treats 3 as "skip the DMG", not as a failure. After the DMG is
# notarized it tags HEAD mikanremote-v<version> and pushes the tag to origin.
#
# It packages, it does not build. The app comes from the argument if given, else
# build/Export (release.sh's fresh output), else the installed /Applications copy.
# Whichever it is must already be notarized+stapled, and its version must match
# project.yml at HEAD (it's tagged as HEAD). Uses the same "bluedragonfly-notary"
# notarytool profile as release.sh (override with MIKAN_NOTARY_PROFILE=<name>).
#
# Copied from TZed's make-dmg.sh on 2026-10-16 (TZed's came from cmdtab's). The tag
# prefix is "mikanremote" (the repo also holds the iPhone app; the one tag before
# this script, v1.1.0, was bare). project.yml is MikanRemoteServer/project.yml, so
# git paths below are written ./project.yml (relative to this directory).
#
# Finally (since 1.2.0, its first version) it runs publish-update.sh, which uploads the zip, DMG
# and appcast.json for the app's updater to the unlisted release folder on
# mikansoftware.app.
#
# Usage: ./scripts/make-dmg.sh [path/to/MikanRemoteServer.app]
# Output: dist/MikanRemoteServer-<version>.dmg (outside build/, which release.sh wipes on every
# run, so a shipped DMG survives later day-to-day installs). Once the new DMG is
# notarized and tagged, older dist/MikanRemoteServer-*.dmg files are deleted; every shipped
# version stays recoverable from its mikanremote-v<version> tag.

set -euo pipefail

APP_NAME="MikanRemoteServer"
TAG_NAME="mikanremote"
TEAM_ID="RP42XZ2CW9"
NOTARY_PROFILE="${MIKAN_NOTARY_PROFILE:-bluedragonfly-notary}"

BUILD_DIR="build"
STAGING="$BUILD_DIR/dmg-staging"
DIST_DIR="dist"

cd "$(dirname "$0")/.."

if [ $# -gt 0 ]; then
  APP_PATH="${1%/}"
elif [ -d "$BUILD_DIR/Export/$APP_NAME.app" ]; then
  APP_PATH="$BUILD_DIR/Export/$APP_NAME.app"
else
  APP_PATH="/Applications/$APP_NAME.app"
fi

step() { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }
fail() { printf "\n\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

step "Pre-flight"
[ -d "$APP_PATH" ] || fail "No app at $APP_PATH — run ./scripts/release.sh first."
echo "Packaging $APP_PATH"
# Never package an app that isn't already notarized+stapled.
xcrun stapler validate "$APP_PATH" >/dev/null || fail "$APP_PATH has no notarization ticket — run ./scripts/release.sh first."
IDENTITY=$(security find-identity -v -p codesigning | sed -n "s/.*\"\(Developer ID Application: .*($TEAM_ID)\)\".*/\1/p" | head -1)
[ -n "$IDENTITY" ] || fail "No 'Developer ID Application' identity for team $TEAM_ID in the keychain."
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  fail "notarytool profile '$NOTARY_PROFILE' missing (see release.sh header)."
fi

VERSION=$(defaults read "$(cd "$(dirname "$APP_PATH")" && pwd)/$(basename "$APP_PATH")/Contents/Info.plist" CFBundleShortVersionString)
BUILD_NUMBER=$(defaults read "$(cd "$(dirname "$APP_PATH")" && pwd)/$(basename "$APP_PATH")/Contents/Info.plist" CFBundleVersion)
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
TAG="$TAG_NAME-v$VERSION"

step "Checking $TAG (build $BUILD_NUMBER) has never shipped"
skip() { printf "\n\033[1;33m⚠ No DMG: %s\033[0m\n" "$*" >&2; exit 3; }
[ -z "$(git status --porcelain)" ] || skip "uncommitted changes. A DMG is tagged as HEAD, so commit first."
HEAD_YML=$(git show HEAD:./project.yml)
yml_value() { sed -n "s/^ *$1: \"\(.*\)\"/\1/p" | head -1; }
[ "$(yml_value MARKETING_VERSION <<<"$HEAD_YML")" = "$VERSION" ] && [ "$(yml_value CURRENT_PROJECT_VERSION <<<"$HEAD_YML")" = "$BUILD_NUMBER" ] \
  || fail "$APP_PATH is $VERSION ($BUILD_NUMBER) but project.yml at HEAD isn't. It wasn't built from HEAD; run ./scripts/release.sh."
git fetch -q origin --tags || fail "Couldn't fetch tags from origin to check earlier releases."
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  [ "$(git rev-parse "$TAG^{commit}")" = "$(git rev-parse HEAD)" ] \
    || skip "$VERSION already shipped as $TAG. Bump MARKETING_VERSION and CURRENT_PROJECT_VERSION in project.yml."
fi
for t in $(git tag -l "$TAG_NAME-v*"); do
  [ "$t" = "$TAG" ] && continue
  b=$(git show "$t:./project.yml" 2>/dev/null | yml_value CURRENT_PROJECT_VERSION)
  [ "$BUILD_NUMBER" -gt "$b" ] || skip "build $BUILD_NUMBER isn't above $t's build $b. Raise CURRENT_PROJECT_VERSION in project.yml."
done

step "Staging DMG contents"
rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING" "$DIST_DIR"
ditto "$APP_PATH" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

step "Creating $DMG_PATH"
# Built by hand (blank read-write image → mount → copy → compress) rather than
# `hdiutil create -srcfolder`, which started failing on this Mac on 2026-09-27 with
# "create failed - Resource busy" for every source folder, even a fresh one in /tmp,
# while creating and mounting a blank image kept working. Cause not found.
#
# Mount in a temp dir, NOT under build/: observed 2026-09-27, an image mounted at
# build/dmg-mount could not be unmounted afterward (even `diskutil unmount force`
# failed, and no user process had files open on it), while the same contents
# mounted under the scratch temp dir unmounted cleanly. Presumably a system-level
# watcher/scanner of the project tree holds it; not confirmed.
RW_DMG="$BUILD_DIR/$APP_NAME-rw.dmg"
MOUNT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/mikanremote-dmg.XXXXXX")
rm -f "$RW_DMG"
SIZE_MB=$(( $(du -sm "$STAGING" | cut -f1) + 20 ))
hdiutil create -size "${SIZE_MB}m" -fs APFS -volname "$APP_NAME" "$RW_DMG" >/dev/null
hdiutil attach "$RW_DMG" -nobrowse -noautoopen -mountpoint "$MOUNT_DIR" >/dev/null
# Detach even if the copy fails, so a failed run never leaves the volume mounted.
trap 'hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true' EXIT
ditto "$STAGING" "$MOUNT_DIR"
hdiutil detach "$MOUNT_DIR" -quiet
trap - EXIT
hdiutil convert "$RW_DMG" -format UDZO -o "$DMG_PATH" >/dev/null
rm -rf "$STAGING" "$RW_DMG"
rmdir "$MOUNT_DIR"

step "Signing DMG"
codesign --sign "$IDENTITY" "$DMG_PATH"

step "Notarizing DMG (submitting to Apple, may take a few minutes)"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

step "Stapling ticket to DMG"
xcrun stapler staple "$DMG_PATH"

step "Verifying Gatekeeper acceptance"
spctl -a -vvv -t open --context context:primary-signature "$DMG_PATH"

step "Tagging $TAG"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || git tag -a "$TAG" -m "$APP_NAME $VERSION (build $BUILD_NUMBER)"
git push -q origin "$TAG"

step "Removing older DMGs"
for old in "$DIST_DIR"/"$APP_NAME"-*.dmg; do
    [[ -e "$old" && "$old" != "$DMG_PATH" ]] || continue
    rm -f "$old" && echo "removed $old"
done

printf "\n\033[1;32m✓ %s ready, tagged %s.\033[0m\n" "$DMG_PATH" "$TAG"

# Hand the release to the updater (since 1.2.0): upload zip, DMG and
# appcast.json to the server; see publish-update.sh.
./scripts/publish-update.sh "$APP_PATH" "$DMG_PATH"
