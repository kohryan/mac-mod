#!/bin/bash
set -euo pipefail
mac_mod_root="$(cd "$(dirname "$0")/.." && pwd)"
mac_mod_app="$mac_mod_root/output/MacMod.app"
mkdir -p "$mac_mod_app/Contents/MacOS" "$mac_mod_app/Contents/Resources"
xcrun swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos13.0" \
  "$mac_mod_root/Sources/Metrics.swift" "$mac_mod_root/Sources/CalendarModel.swift" "$mac_mod_root/Sources/PrayerTimes.swift" "$mac_mod_root/Sources/Widgets.swift" "$mac_mod_root/Sources/Notch.swift" "$mac_mod_root/Sources/main.swift" \
  -o "$mac_mod_app/Contents/MacOS/MacMod"
cp "$mac_mod_root/assets/wallpapers/gundam-hangar.png" "$mac_mod_app/Contents/Resources/"
cat > "$mac_mod_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.kohryan.mac-mod</string>
<key>CFBundleName</key><string>MacMod</string>
<key>CFBundleExecutable</key><string>MacMod</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.3.1</string>
<key>CFBundleVersion</key><string>4</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier local.kohryan.mac-mod "$mac_mod_app"
printf 'Built: %s\n' "$mac_mod_app"
