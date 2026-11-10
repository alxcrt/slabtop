#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="${VERSION:-0.1.2}"
identity="${SIGNING_IDENTITY:--}"
/usr/bin/swift build -c release --arch arm64
binary_dir="$(/usr/bin/swift build -c release --arch arm64 --show-bin-path)"
stage="$(mktemp -d "${TMPDIR:-/tmp}/slabtop-build.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
app="$stage/Slabtop.app"
mkdir -p dist
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/HeadlessMac" "$app/Contents/MacOS/HeadlessMac"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.alxcrt.HalfBook</string>
<key>CFBundleName</key><string>Slabtop</string>
<key>CFBundleDisplayName</key><string>Slabtop</string>
<key>CFBundleExecutable</key><string>HeadlessMac</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$version</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Copyright 2026 Slabtop contributors. MIT license.</string>
</dict></plist>
PLIST
/usr/bin/swift scripts/make-icon.swift "$app/Contents/Resources/AppIcon.icns"
/usr/bin/plutil -lint "$app/Contents/Info.plist"
/usr/bin/xattr -cr "$app"
/usr/bin/codesign --force --options runtime --sign "$identity" "$app"
/usr/bin/codesign --verify --deep --strict "$app"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "dist/Slabtop-$version-arm64.zip"
mkdir -p "$stage/dmg"
/usr/bin/ditto --norsrc "$app" "$stage/dmg/Slabtop.app"
ln -s /Applications "$stage/dmg/Applications"
/usr/bin/hdiutil create -quiet -volname Slabtop -srcfolder "$stage/dmg" -format UDZO -ov "dist/Slabtop-$version-arm64.dmg"
(cd dist && /usr/bin/shasum -a 256 "Slabtop-$version-arm64.zip" "Slabtop-$version-arm64.dmg" > SHA256SUMS.txt)
if [ -d dist/Slabtop.app ]; then
    mv dist/Slabtop.app "$stage/previous-Slabtop.app"
fi
/usr/bin/ditto --norsrc "$app" "dist/Slabtop.app"
/usr/bin/xattr -cr dist/Slabtop.app
/usr/bin/codesign --verify --deep --strict dist/Slabtop.app
mkdir -p "$stage/verify-zip"
/usr/bin/ditto -x -k "dist/Slabtop-$version-arm64.zip" "$stage/verify-zip"
/usr/bin/codesign --verify --deep --strict "$stage/verify-zip/Slabtop.app"
/usr/bin/hdiutil verify "dist/Slabtop-$version-arm64.dmg" >/dev/null
printf 'Built %s\n' "dist/Slabtop.app"
