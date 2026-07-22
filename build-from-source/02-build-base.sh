#!/bin/bash
# 02-build-base.sh — the core libwpd-family libraries (incl. the patched libwpd)
# plus the small support libraries, all universal-static into $PREFIX.
set -euo pipefail
source "$(dirname "$0")/common.sh"

msg "librevenge";                         ( cd "$SRC/librevenge" && autogen_build )
msg "libwpd (PATCHED: WP6 cross-refs + WP5 page numbering)"
                                          ( cd "$SRC/libwpd"     && autogen_build )
msg "libwpg";                             ( cd "$SRC/libwpg"     && autogen_build )
msg "libodfgen";                          ( cd "$SRC/libodfgen"  && autogen_build )

msg "lcms2 (color engine, for CorelDRAW/FreeHand)"
( cd "$SRC/lcms2-2.16"   && autobuild --without-jpeg --without-tiff )
msg "libpng (for Zoner)"
( cd "$SRC/libpng-1.6.43" && autobuild )

msg "mdds 2.1 headers (for iWork/etonyek)"
( cd "$SRC/mdds-2.1.1" && CXXFLAGS="-std=gnu++17 $ARCHS -O2" ./configure --prefix="$PREFIX" >/dev/null && make install >/dev/null )
cp "$PREFIX/share/pkgconfig/mdds-2.1.pc" "$PREFIX/lib/pkgconfig/" 2>/dev/null || true

msg "glm headers (for iWork/etonyek)"
GLM_H="$(find "$SRC/glm-0.9.9.8" -name glm.hpp -path '*/glm/glm.hpp' | head -1)"
[ -n "$GLM_H" ] || { echo "glm.hpp not found"; exit 1; }
rm -rf "$PREFIX/include/glm"; cp -R "$(dirname "$GLM_H")" "$PREFIX/include/glm"

echo "✓ base + support libraries installed into $PREFIX"
