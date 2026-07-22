#!/bin/bash
# 03-build-importers.sh — the 13 legacy-format import libraries.
#
# The ICU-tier libraries (cdr/mspub/qxp/visio/zmf/e-book, and freehand) use only
# ICU's C API (ucnv_*/ucsdet_*/uloc_*), all of which Apple's system
# /usr/lib/libicucore.A.dylib exports UNVERSIONED. So instead of building ICU we
# compile against icu4c HEADERS with -DU_DISABLE_RENAMING=1 (unversioned symbol
# names) and link -licucore. Nothing ICU ships — the result stays distributable.
set -euo pipefail
source "$(dirname "$0")/common.sh"

# --- librevenge-only importers -------------------------------------------------
for d in libmwaw-0.3.23 libwps-0.4.14 libstaroffice-0.0.7; do
  msg "$d"; ( cd "$SRC/$d" && autobuild )
done

# --- Boost-header importers ----------------------------------------------------
for d in libpagemaker-0.0.4 libabw-0.1.3; do
  msg "$d"; ( cd "$SRC/$d" && CXXFLAGS="$ARCHS -O2 -I$BOOST_INC" CPPFLAGS="-I$BOOST_INC" autobuild )
done

# --- iWork: Boost + glm + mdds; needs C++17; liblangtag disabled ---------------
msg "libetonyek (iWork Pages/Keynote/Numbers)"
( cd "$SRC/libetonyek-0.1.12"
  CXXFLAGS="-std=gnu++17 $ARCHS -O2 -I$BOOST_INC -I$PREFIX/include" \
  CPPFLAGS="-I$BOOST_INC -I$PREFIX/include" \
  autobuild --without-liblangtag )
# the installed .pc lists liblangtag even though we built without it — strip it:
perl -0pi -e 's/^(Requires\.private:.*?)\s*\bliblangtag\b/$1/mg;' "$PREFIX/lib/pkgconfig/libetonyek-0.1.pc"

# --- FreeHand 0.1.1: SDK ICU headers + system libicucore + lcms2 ---------------
msg "libfreehand (Adobe FreeHand)"
# modern ICU's U16_NEXT is a do/while(0) macro and needs a trailing ';':
perl -pi -e 's/^(\s*U16_NEXT\(s, j, length, c\))\s*$/$1;/' \
  "$SRC/libfreehand-0.1.1/src/lib/libfreehand_utils.cpp"
( cd "$SRC/libfreehand-0.1.1"
  ICU_CFLAGS=' ' ICU_LIBS='-licucore' \
  CXXFLAGS="$ARCHS -O2 -I$BOOST_INC" CPPFLAGS="-I$BOOST_INC" \
  autobuild )
fix_icu_pc libfreehand-0.1.pc

# --- ICU-tier: link Apple's system libicucore (no ICU build) -------------------
build_icu() {  # <srcdir> <pcname> [extra configure args...]
  local dir="$1" pc="$2"; shift 2
  msg "$dir"
  ( cd "$SRC/$dir"
    ICU_CFLAGS="-DU_DISABLE_RENAMING=1 -I$ICU4C_INC" ICU_LIBS="-licucore" \
    CXXFLAGS="-std=gnu++17 $ARCHS -O2 -I$BOOST_INC" CPPFLAGS="-I$BOOST_INC" \
    autobuild "$@" )
  fix_icu_pc "$pc"
}
build_icu libcdr-0.1.7   libcdr-0.1.pc      # CorelDRAW (uses lcms2)
build_icu libmspub-0.1.4 libmspub-0.1.pc    # Microsoft Publisher
build_icu libqxp-0.0.2   libqxp-0.0.pc      # QuarkXPress
build_icu libvisio-0.1.7 libvisio-0.1.pc    # Microsoft Visio (uses libxml2)
build_icu libzmf-0.0.2   libzmf-0.0.pc      # Zoner Draw (uses libpng)

# e-book: icu4c 78 headers vs older code need two extra shims
msg "libe-book"
( cd "$SRC/libe-book-0.1.3"
  ICU_CFLAGS="-DU_DISABLE_RENAMING=1 -I$ICU4C_INC" ICU_LIBS="-licucore" \
  CXXFLAGS="-std=gnu++17 -Wno-register $ARCHS -O2 -I$BOOST_INC" \
  CPPFLAGS="-I$BOOST_INC -DTRUE=1 -DFALSE=0" \
  autobuild --without-liblangtag )
fix_icu_pc libe-book-0.1.pc

echo "✓ all 13 import libraries installed into $PREFIX"
