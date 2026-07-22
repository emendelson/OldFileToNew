#!/bin/bash
# 05-build-app.sh — bundle the freshly built wpft2odf into the app, compile the
# Swift app universally, assemble OldFileToNew.app, and ad-hoc (local) codesign it.
set -euo pipefail
source "$(dirname "$0")/common.sh"

# The repository root is the parent of build-from-source/.
PROJ="$(cd "$(dirname "$0")/.." && pwd)"

msg "Bundling wpft2odf into the app resources"
install -m 0755 "$PREFIX/bin/wpft2odf" "$PROJ/Sources/OldFileToNew/Resources/Files/wpft2odf"

msg "Building + assembling OldFileToNew.app (universal, ad-hoc signed)"
( cd "$PROJ" && ./make_app.sh )

echo
echo "✓ built: $PROJ/build/OldFileToNew.app  (ad-hoc / locally signed)"
echo "  First launch: right-click → Open (ad-hoc apps aren't notarized)."
echo "  To distribute, sign with your own Developer ID: ./sign-and-notarize.sh"
