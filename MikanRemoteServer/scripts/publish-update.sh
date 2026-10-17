#!/usr/bin/env bash
# scripts/publish-update.sh — publish a notarized, stapled MikanRemoteServer.app so installed
# copies update to it (see MikanRemoteServer/Updater.swift). Copied from TZed's on
# 2026-10-16 (TZed's came from VOB's, VOB's from Claude Usage's); same server,
# same account, its own folder.
# make-dmg.sh runs it after the DMG is notarized and tagged; it can also be run
# on its own.
#
# Releases live on Scott's own server (mikansoftware.app), in an unlisted
# folder: an unguessable path that no page links to and Apache won't list
# (the plan of record for every app with an updater, Scott 2026-10-15).
# The path is Updater.releasePath, read from Updater.swift so the two can't
# drift. The site's deploy.sh excludes /u/ so a site deploy never deletes
# these files.
#
# Steps:
#   1. zip the app (ditto) as MikanRemoteServer-<version>.zip and write appcast.json
#      (version, build, zip URL, SHA-256, notes, minimum macOS);
#   2. rsync the zip and DMG to the server, then appcast.json last, so the
#      feed never names a zip that isn't there yet;
#   3. download the feed and zip back through the public URL and check them.
# Step 2 connects to the server over SSH, so run this only when Scott has
# asked for a release. Destination: MIKAN_PUBLISH_DEST, the site's
# docroot as an rsync target; defaults to mikansoftware:/var/www/mikansoftware/public_html.
#
# Usage: ./scripts/publish-update.sh path/to/MikanRemoteServer.app path/to/MikanRemoteServer-<version>.dmg
# Notes: MIKAN_RELEASE_NOTES="…" overrides the default one-liner.

set -euo pipefail
cd "$(dirname "$0")/.."

SITE="https://mikansoftware.app"
TEAM_ID="RP42XZ2CW9"
MIN_MACOS="14.0"   # project.yml deploymentTarget
# Default: the mikansoftware account on Scott's server (~/.ssh/config Host
# mikansoftware), which owns only this site's docroot; set up 2026-10-11 so
# releases no longer upload as root.
DEST="${MIKAN_PUBLISH_DEST:-mikansoftware:/var/www/mikansoftware/public_html}"

APP_PATH="${1:?usage: publish-update.sh path/to/app path/to/dmg}"
APP_PATH="${APP_PATH%/}"
DMG_PATH="${2:?usage: publish-update.sh path/to/app path/to/dmg}"

fail() { printf "\n\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }
step() { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }

[ -n "$DEST" ] || fail "Set MIKAN_PUBLISH_DEST to the site docroot (e.g. mikansoftware:/var/www/mikansoftware/public_html)."
RELEASE_PATH=$(sed -n 's/^ *static let releasePath = "\(.*\)"$/\1/p' MikanRemoteServer/Updater.swift)
[[ "$RELEASE_PATH" =~ ^u/[0-9a-f]{24}/mikanremote$ ]] || fail "Couldn't read Updater.releasePath from Updater.swift."
BASE_URL="$SITE/$RELEASE_PATH"

step "Checking $APP_PATH"
plist="$(cd "$(dirname "$APP_PATH")" && pwd)/$(basename "$APP_PATH")/Contents/Info.plist"
VERSION=$(defaults read "$plist" CFBundleShortVersionString)
BUILD=$(defaults read "$plist" CFBundleVersion)
[[ "$BUILD" =~ ^[0-9]+$ ]] || fail "Build number '$BUILD' isn't an integer; the updater compares it as one."
xcrun stapler validate "$APP_PATH" >/dev/null || fail "$APP_PATH isn't notarized and stapled."
spctl -a -t exec "$APP_PATH" 2>/dev/null || fail "Gatekeeper rejects $APP_PATH."
# Capture first: `codesign | grep -q` under pipefail fails at random when grep
# exits early and codesign dies of SIGPIPE (hit publishing 1.1.2).
signature=$(codesign -dv "$APP_PATH" 2>&1)
grep -q "^TeamIdentifier=$TEAM_ID$" <<<"$signature" || fail "$APP_PATH isn't signed by team $TEAM_ID."
xcrun stapler validate "$DMG_PATH" >/dev/null || fail "$DMG_PATH isn't notarized and stapled."
[[ "$(basename "$DMG_PATH")" == "MikanRemoteServer-$VERSION.dmg" ]] || fail "$DMG_PATH isn't MikanRemoteServer-$VERSION.dmg."

# Never go backwards: the live feed must name a lower build than this one.
live_build=$(curl -fsS "$BASE_URL/appcast.json" 2>/dev/null | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["build"])' 2>/dev/null || echo 0)
[ "$BUILD" -gt "$live_build" ] || fail "The live feed already offers build $live_build; this is build $BUILD."

OUT="build/publish-$VERSION"
rm -rf "$OUT"; mkdir -p "$OUT/files"
ZIP_NAME="MikanRemoteServer-$VERSION.zip"
DMG_NAME="MikanRemoteServer-$VERSION.dmg"
step "Zipping $ZIP_NAME"
ditto -c -k --keepParent "$APP_PATH" "$OUT/files/$ZIP_NAME"
cp "$DMG_PATH" "$OUT/files/$DMG_NAME"
SHA=$(shasum -a 256 "$OUT/files/$ZIP_NAME" | awk '{print $1}')

NOTES="${MIKAN_RELEASE_NOTES:-MikanRemoteServer $VERSION.}"
python3 -I - "$OUT/appcast.json" "$VERSION" "$BUILD" "$BASE_URL/$ZIP_NAME" "$SHA" "$NOTES" "$MIN_MACOS" <<'EOF'
import json, sys
path, version, build, url, sha, notes, minimum = sys.argv[1:]
with open(path, "w") as f:
    json.dump({"version": version, "build": int(build), "url": url, "sha256": sha,
               "notes": notes, "minimumSystemVersion": minimum}, f, indent=2)
    f.write("\n")
EOF
cat "$OUT/appcast.json"

step "Uploading to $DEST/$RELEASE_PATH"
[[ "$DEST" == *:/* ]] || fail "MIKAN_PUBLISH_DEST must look like host:/absolute/docroot."
remote_dir="${DEST#*:}/$RELEASE_PATH"
chmod 644 "$OUT/files/"* "$OUT/appcast.json"
# macOS's rsync (openrsync) has no --mkpath; the remote side makes the folder.
RSYNC=(rsync -rt --perms --rsync-path="mkdir -p '$remote_dir' && chmod 755 '$remote_dir' && rsync")
"${RSYNC[@]}" "$OUT/files/" "$DEST/$RELEASE_PATH/"
"${RSYNC[@]}" "$OUT/appcast.json" "$DEST/$RELEASE_PATH/appcast.json"

step "Checking the public URLs"
feed=$(curl -fsS -H 'Cache-Control: no-cache' "$BASE_URL/appcast.json") || fail "$BASE_URL/appcast.json doesn't load."
[ "$(python3 -I -c 'import json,sys; print(json.load(sys.stdin)["build"])' <<<"$feed")" = "$BUILD" ] \
  || fail "The public feed doesn't show build $BUILD (a cache in front of the server?)."
[ "$(curl -fsS "$BASE_URL/$ZIP_NAME" | shasum -a 256 | awk '{print $1}')" = "$SHA" ] || fail "The public zip doesn't match."
curl -fsSI "$BASE_URL/$DMG_NAME" >/dev/null || fail "The public DMG doesn't load."
[ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/")" != 200 ] || fail "$BASE_URL/ is listable; turn off directory listing."

printf "\n\033[1;32m✓ Published %s (%s). Installed copies will offer it within a day.\033[0m\n" "$VERSION" "$BUILD"
echo "  DMG to share by hand: $BASE_URL/$DMG_NAME"
