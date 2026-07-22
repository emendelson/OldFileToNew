#!/bin/bash
#
# sign-and-notarize.sh — Developer ID sign, notarize, and staple OldFileToNew.app.
#
# Signs the bundled wpft2odf tool and the app bundle with your Developer ID Application
# certificate (with the Hardened Runtime, which notarization requires), submits the app to
# Apple's notary service, waits, and staples the ticket.
#
# ─────────────────────────────────────────────────────────────────────────────
# ONE-TIME SETUP
#   1. Find your identity:   security find-identity -v -p codesigning
#   2. Store notary creds:   xcrun notarytool store-credentials "notary" \
#                              --apple-id "you@example.com" --team-id "AB12CD34EF" \
#                              --password "abcd-efgh-ijkl-mnop"   # app-specific password
#   3. Fill in DEV_ID / KEYCHAIN_PROFILE below (or pass as environment variables).
#
# USAGE
#   ./sign-and-notarize.sh                 # build, sign, notarize, staple
#   ./sign-and-notarize.sh path/to/App.app # process a single existing bundle
#   SIGN_ONLY=1 ./sign-and-notarize.sh     # sign only (skip notarize/staple)
#   INSTALL=1 ./sign-and-notarize.sh       # also copy the finished app to /Applications
#
set -euo pipefail

DEV_ID="${DEV_ID:-Developer ID Application: Edward Mendelson (533UMV53L8)}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-notary}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

sign_app() {
    local app="$1"
    echo "▸ Signing the bundled converter (wpft2odf)…"
    codesign --force --options runtime --timestamp \
        --sign "$DEV_ID" "$app/Contents/Resources/Files/wpft2odf"
    echo "▸ Signing the app bundle…"
    codesign --force --options runtime --timestamp --sign "$DEV_ID" "$app"
    codesign --verify --strict --verbose=2 "$app"
}

notarize_app() {
    local app="$1"
    local zip="${app%.app}.zip"
    echo "▸ Zipping: $(basename "$zip")"
    rm -f "$zip"
    /usr/bin/ditto -c -k --keepParent "$app" "$zip"
    echo "▸ Submitting to Apple's notary service (a few minutes)…"
    xcrun notarytool submit "$zip" --keychain-profile "$KEYCHAIN_PROFILE" --wait
    echo "▸ Stapling…"
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
    spctl -a -vvv --type execute "$app"
    rm -f "$zip"
}

install_app() {
    [[ "${INSTALL:-0}" == "1" ]] || return 0
    local app="$1" base dest src
    base="$(basename "$app")"
    dest="/Applications/$base"
    src="$(cd "$app" && pwd -P)"
    if [[ "$src" == "$dest" ]]; then
        echo "  $base is already in /Applications - nothing to install."
        return 0
    fi
    echo "  Installing $base to /Applications ..."
    pkill -f "$base/Contents/MacOS" 2>/dev/null || true
    rm -rf "$dest"
    cp -R "$app" "$dest"                  # plain copy - never re-sign a notarized app
    "$LSREGISTER" -f "$dest" 2>/dev/null || true
}

if [[ $# -ge 1 ]]; then
    APP="$1"
else
    echo "▸ Building a fresh bundle with make_app.sh…"
    "$ROOT/make_app.sh" >/dev/null
    APP="$ROOT/build/OldFileToNew.app"
fi

[[ -d "$APP" ]] || { echo "✗ Not found: $APP"; exit 1; }
echo
echo "════════════════════════════════════════════════════════════════"
echo "  $(basename "$APP")"
echo "════════════════════════════════════════════════════════════════"
sign_app "$APP"
if [[ "${SIGN_ONLY:-0}" == "1" ]]; then
    spctl -a -vvv --type execute "$APP" || true   # "rejected" until notarized — expected
    install_app "$APP"
    echo "✓ Signed (notarization skipped: SIGN_ONLY=1)."
else
    notarize_app "$APP"
    install_app "$APP"
    echo "✓ $(basename "$APP") signed, notarized, and stapled."
fi
