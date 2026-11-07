#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="${VERSION:-0.1.0}"
identity="${SIGNING_IDENTITY:--}"
/usr/bin/swift build -c release --arch arm64
binary_dir="$(/usr/bin/swift build -c release --arch arm64 --show-bin-path)"
stage="$(mktemp -d "${TMPDIR:-/tmp}/halfbook-build.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
app="$stage/HalfBook.app"
mkdir -p dist
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/HeadlessMac" "$app/Contents/MacOS/HeadlessMac"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.alxcrt.HalfBook</string>
<key>CFBundleName</key><string>HalfBook</string>
<key>CFBundleDisplayName</key><string>HalfBook</string>
<key>CFBundleExecutable</key><string>HeadlessMac</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$version</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Copyright 2026 HalfBook contributors. MIT license.</string>
</dict></plist>
PLIST
/usr/bin/swift scripts/make-icon.swift "$app/Contents/Resources/AppIcon.icns"
/usr/bin/plutil -lint "$app/Contents/Info.plist"
/usr/bin/xattr -cr "$app"
/usr/bin/codesign --force --options runtime --sign "$identity" "$app"
/usr/bin/codesign --verify --deep --strict "$app"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "dist/HalfBook-$version-arm64.zip"
mkdir -p "$stage/dmg"
/usr/bin/ditto --norsrc "$app" "$stage/dmg/HalfBook.app"
ln -s /Applications "$stage/dmg/Applications"
/usr/bin/hdiutil create -quiet -volname HalfBook -srcfolder "$stage/dmg" -format UDZO -ov "dist/HalfBook-$version-arm64.dmg"
(cd dist && /usr/bin/shasum -a 256 "HalfBook-$version-arm64.zip" "HalfBook-$version-arm64.dmg" > SHA256SUMS.txt)
if [ -d dist/HalfBook.app ]; then
    mv dist/HalfBook.app "$stage/previous-HalfBook.app"
fi
/usr/bin/ditto --norsrc "$app" "dist/HalfBook.app"
/usr/bin/xattr -cr dist/HalfBook.app
/usr/bin/codesign --verify --deep --strict dist/HalfBook.app
mkdir -p "$stage/verify-zip"
/usr/bin/ditto -x -k "dist/HalfBook-$version-arm64.zip" "$stage/verify-zip"
/usr/bin/codesign --verify --deep --strict "$stage/verify-zip/HalfBook.app"
/usr/bin/hdiutil verify "dist/HalfBook-$version-arm64.dmg" >/dev/null
printf 'Built %s\n' "dist/HalfBook.app"
