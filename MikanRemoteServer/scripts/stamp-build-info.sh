#!/bin/sh
# Embed the source revision in the built app before code signing (a
# postBuildScripts phase in project.yml; Xcode signs after every build phase).
# Settings shows it beside the version (BuildInfo.swift). Copied from
# TZed's on 2026-10-16 (TZed's came from claude-usage's). A build from a tree with uncommitted changes
# gets "-dirty"; release builds can't (make-dmg.sh refuses a dirty tree).
set -eu
REVISION=$(git -C "$SRCROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
if [ -n "$(git -C "$SRCROOT" status --porcelain 2>/dev/null)" ]; then
    REVISION="${REVISION}-dirty"
fi
DESTINATION="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
mkdir -p "$DESTINATION"
printf '{"commit":"%s"}\n' "$REVISION" > "$DESTINATION/build-info.json"
