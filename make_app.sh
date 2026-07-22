#!/bin/bash
# Build OldFileToNew in release mode and assemble the distributable bundle:
#   • OldFileToNew.app  — id org.wpdos.oldfiletonew  (universal: arm64 + x86_64)
# Usage: ./make_app.sh [output-directory]   (defaults to ./build)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$ROOT/build}"
NAME="OldFileToNew"
RES="$ROOT/Sources/OldFileToNew/Resources"

echo "▸ Building release binary (universal)…"
swift build -c release --arch arm64 --arch x86_64 --product OldFileToNew >/dev/null
BIN="$(swift build -c release --arch arm64 --arch x86_64 --product OldFileToNew --show-bin-path)/OldFileToNew"

APP="$OUT/$NAME.app"
echo "▸ Assembling: $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Files"

cp "$BIN" "$APP/Contents/MacOS/$NAME"          # executable name == app name
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Bundle the single universal, system-lib-only converter and the help page.
cp "$RES/Files/wpft2odf" "$APP/Contents/Resources/Files/wpft2odf"
cp "$RES/Help.html"      "$APP/Contents/Resources/Help.html"
chmod +x "$APP/Contents/Resources/Files/"*
# App icon: classic .icns (CFBundleIconFile, older macOS) + Liquid Glass Assets.car
# (CFBundleIconName, Tahoe). Both named "OldFileToNew".
cp "$RES/OldFileToNew.icns" "$APP/Contents/Resources/OldFileToNew.icns"
cp "$RES/Assets.car"        "$APP/Contents/Resources/Assets.car"

echo "  ad-hoc signing…"
codesign --force --sign - "$APP/Contents/Resources/Files/wpft2odf"
codesign --force --sign - "$APP/Contents/MacOS/$NAME"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP" && echo "  signature OK"

echo "✓ Done. Bundle: $APP"
echo "  Move it to /Applications and open once to register with Launch Services."
