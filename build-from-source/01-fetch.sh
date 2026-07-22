#!/bin/bash
# 01-fetch.sh — clone the base-library forks and download the import-library
# release tarballs. Everything lands in $OFTN_ROOT/src (default ~/oldfiletonew-build/src).
set -euo pipefail
source "$(dirname "$0")/common.sh"

msg "Base libraries (git). libwpd is the PATCHED fork used by the app."
clone() {  # <url> <dir> [branch]
  local url="$1" dir="$2" br="${3:-}"
  if [ -d "$SRC/$dir/.git" ]; then echo "  have $dir"; return; fi
  echo "  clone $dir${br:+  ($br)}"
  git clone --depth 1 ${br:+--branch "$br"} "$url" "$SRC/$dir"
}
clone https://github.com/emendelson/librevenge    librevenge
clone https://github.com/emendelson/libwpd        libwpd         oldfiletonew   # <-- patched
clone https://git.code.sf.net/p/libwpg/code       libwpg
clone https://github.com/emendelson/libodfgen     libodfgen
clone https://github.com/emendelson/writerperfect writerperfect

msg "Support + import libraries (release tarballs, pinned)"
BASE="https://dev-www.libreoffice.org/src"
get() {  # <url>
  local out; out="$(basename "$1")"
  [ -f "$SRC/$out" ] && { echo "  have $out"; return; }
  echo "  fetch $out"; curl -fsSL -o "$SRC/$out" "$1"
}
get "$BASE/lcms2-2.16.tar.gz"
get "$BASE/libpng-1.6.43.tar.xz"
get "$BASE/mdds-2.1.1.tar.xz"
get "$BASE/glm-0.9.9.8.zip"
for t in libmwaw-0.3.23 libwps-0.4.14 libstaroffice-0.0.7 libpagemaker-0.0.4 \
         libabw-0.1.3 libetonyek-0.1.12 libcdr-0.1.7 libmspub-0.1.4 \
         libqxp-0.0.2 libvisio-0.1.7 libzmf-0.0.2 libe-book-0.1.3; do
  get "$BASE/$t.tar.xz"
done
get "$BASE/libfreehand/libfreehand-0.1.1.tar.xz"   # 0.1.1 — 0.1.2 hard-links libicuuc

msg "Unpacking archives"
for tb in "$SRC"/*.tar.*; do
  d="$(basename "$tb")"; d="${d%.tar.*}"
  [ -d "$SRC/$d" ] || { echo "  unpack $d"; tar -C "$SRC" -xf "$tb"; }
done
[ -d "$SRC/glm-0.9.9.8" ] || { echo "  unpack glm-0.9.9.8"; unzip -q "$SRC/glm-0.9.9.8.zip" -d "$SRC"; }

echo "✓ all sources in $SRC"
