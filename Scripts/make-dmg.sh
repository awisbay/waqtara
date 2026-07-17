#!/bin/bash
# Buat installer .dmg: Waqtara.app + shortcut Applications (drag-and-drop install).
set -euo pipefail
cd "$(dirname "$0")/.."

./Scripts/make-app.sh

VERSION=$(defaults read "$PWD/dist/Waqtara.app/Contents/Info" CFBundleShortVersionString)
DMG="dist/Waqtara-$VERSION.dmg"
STAGE=dist/dmg-stage

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R dist/Waqtara.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "Waqtara $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
echo "OK: $DMG"
