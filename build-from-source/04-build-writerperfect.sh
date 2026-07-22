#!/bin/bash
# 04-build-writerperfect.sh — build the single universal wpft2odf dispatcher,
# which links every import library present in $PREFIX and auto-detects each file.
set -euo pipefail
source "$(dirname "$0")/common.sh"

msg "writerperfect → wpft2odf"
( cd "$SRC/writerperfect"
  [ -x ./configure ] || NOCONFIGURE=1 ./autogen.sh
  CXXFLAGS="$ARCHS -O2 -I$BOOST_INC" CPPFLAGS="-I$BOOST_INC" \
    ./configure --prefix="$PREFIX" --enable-static --disable-shared

  # GOTCHA: wpft2odf.cxx gates each format behind a compile-time #ifdef. Its object
  # can cache stale guards across reconfigures, silently dispatching to nothing.
  # Removing it forces a clean recompile with every importer enabled. (Harmless on
  # a first build; essential if you ever re-run after adding a library.)
  rm -f src/conv/odf/wpft2odf-wpft2odf.o src/conv/odf/wpft2odf

  make -j"$NCPU"
  make install )

echo "✓ wpft2odf installed"
lipo -info "$PREFIX/bin/wpft2odf" | sed 's/^/  /'
echo "  distributability check (must be empty):"
otool -L "$PREFIX/bin/wpft2odf" | tail -n +2 | awk '{print $1}' \
  | grep -iE "/opt/homebrew|/usr/local" | sed 's/^/    LEAK: /' \
  || echo "    none — links only /usr/lib system libraries ✓"
