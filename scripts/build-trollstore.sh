#!/bin/bash
# Run on macOS with Xcode, XcodeGen and ldid installed.
set -euo pipefail
cd "$(dirname "$0")/.."
for tool in xcodegen xcodebuild ldid; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done
python3 scripts/configure-google.py
xcodegen generate
# A new output folder avoids reusing an older app or IPA after a failed build.
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/nourish-build.XXXXXX")"
xcodebuild -project CalorieTracker.xcodeproj -scheme CalorieTracker \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  IPHONEOS_DEPLOYMENT_TARGET=15.0 ARCHS=arm64 build
APP="$BUILD_DIR/DerivedData/Build/Products/Release-iphoneos/CalorieTracker.app"
test -d "$APP"
EXECUTABLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")
MINIMUM=$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$APP/Info.plist")
test "$MINIMUM" = '15.0'
# Verify the branded icon and compiled asset catalog are present in the actual app.
ICON_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName' "$APP/Info.plist")
test "$ICON_NAME" = 'AppIcon'
test -f "$APP/Assets.car"
# Verify the public OAuth client and reversed callback made it into the built app.
python3 - "$APP/Info.plist" <<'PYGOOGLE'
import json, os, plistlib, sys
from pathlib import Path
expected = os.environ.get("GOOGLE_IOS_CLIENT_ID") or json.loads(Path("Config/GoogleSignIn.json").read_text())["iosClientID"]
with open(sys.argv[1], "rb") as file:
    info = plistlib.load(file)
assert info.get("GIDClientID", "") == expected, "Built app has the wrong Google client ID"
if expected:
    reversed_id = ".".join(reversed(expected.split(".")))
    schemes = [scheme for entry in info.get("CFBundleURLTypes", []) for scheme in entry.get("CFBundleURLSchemes", [])]
    assert reversed_id in schemes, "Built app is missing the Google callback scheme"
print("Verified Google OAuth configuration in packaged app.")
PYGOOGLE
# TrollStore-specific signing: keep credentials in one stable, app-only group.
# XcodeGen regenerates this file, so validate it before signing and after extraction.
python3 scripts/verify-entitlements.py CalorieTracker/CalorieTracker.entitlements --info-plist "$APP/Info.plist"
ldid -SCalorieTracker/CalorieTracker.entitlements "$APP/$EXECUTABLE"
ldid -e "$APP/$EXECUTABLE" > "$BUILD_DIR/embedded-entitlements.plist"
python3 scripts/verify-entitlements.py "$BUILD_DIR/embedded-entitlements.plist" --info-plist "$APP/Info.plist"
mkdir -p "$BUILD_DIR/package/Payload" dist
cp -R "$APP" "$BUILD_DIR/package/Payload/"
(cd "$BUILD_DIR/package" && /usr/bin/zip -qry "$BUILD_DIR/Nourish.ipa" Payload)
unzip -t "$BUILD_DIR/Nourish.ipa"
mv "$BUILD_DIR/Nourish.ipa" dist/Nourish.ipa
echo "Built dist/Nourish.ipa (minimum iOS $MINIMUM)"
