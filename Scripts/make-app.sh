#!/bin/bash
# Bungkus build release menjadi Waqtara.app (dist/Waqtara.app).
# UserNotifications hanya bekerja dari app ber-bundle, bukan executable polos.
set -euo pipefail
cd "$(dirname "$0")/.."

# Universal binary (Apple Silicon + Intel) agar jalan di semua Mac macOS 13+.
# Set WAQTARA_ARCH=arm64 untuk build satu-arsitektur yang lebih cepat saat development.
ARCHS="${WAQTARA_ARCH:---arch arm64 --arch x86_64}"
swift build -c release --product Waqtara $ARCHS
BIN=$(swift build -c release --product Waqtara $ARCHS --show-bin-path)

APP=dist/Waqtara.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN/Waqtara" "$APP/Contents/MacOS/Waqtara"
# Resource bundle SPM (cities.json dll.) — accessor mencarinya di Bundle.main.resourceURL.
cp -R "$BIN/Waqtara_WaqtaraCore.bundle" "$APP/Contents/Resources/"
cp -R "$BIN/Waqtara_WaqtaraApp.bundle" "$APP/Contents/Resources/"

# Ikon app (regenerasi bila belum ada)
if [ ! -f dist/AppIcon.icns ]; then
    swift Scripts/generate-icon.swift dist/AppIcon.iconset
    iconutil -c icns dist/AppIcon.iconset -o dist/AppIcon.icns
fi
cp dist/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Waqtara</string>
    <key>CFBundleIdentifier</key><string>com.wisbay.waqtara</string>
    <key>CFBundleName</key><string>Waqtara</string>
    <key>CFBundleDisplayName</key><string>Waqtara</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.4.0</string>
    <key>CFBundleVersion</key><string>4</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSUIElement</key><true/>
    <key>NSLocationWhenInUseUsageDescription</key><string>Waqtara memakai lokasi sekali saja untuk menghitung jadwal sholat di tempat Anda. Koordinat tidak pernah meninggalkan perangkat.</string>
    <key>NSHumanReadableCopyright</key><string>© 2026 awisbay</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "OK: $APP"
