#!/bin/bash
# common.sh — shared configuration + helpers for the OldFileToNew toolchain build.
# Sourced by the numbered scripts (01–05); not meant to be run on its own.
set -euo pipefail

# --- where sources and the install prefix live (override via OFTN_ROOT) --------
export OFTN_ROOT="${OFTN_ROOT:-$HOME/oldfiletonew-build}"
export SRC="$OFTN_ROOT/src"
export PREFIX="$OFTN_ROOT/_prefix"
mkdir -p "$SRC" "$PREFIX"

# --- universal (Apple Silicon + Intel), optimized, built against the macOS SDK -
export ARCHS="-arch arm64 -arch x86_64"
export CFLAGS="${CFLAGS:-} $ARCHS -O2"
export CXXFLAGS="${CXXFLAGS:-} $ARCHS -O2"

# pkg-config finds the libraries we build here (mdds installs into share/pkgconfig).
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"

# Homebrew supplies BUILD-TIME headers only (Boost; and ICU headers for the icu4c
# path). Nothing from Homebrew is linked at runtime — the finished wpft2odf links
# only /usr/lib system libraries. See build-from-source/README.md ("Distributable").
BREW="$( (command -v brew >/dev/null && brew --prefix) || echo /opt/homebrew )"
export BOOST_INC="$BREW/include"
export ICU4C_INC="$BREW/opt/icu4c/include"

NCPU="$(sysctl -n hw.ncpu)"

msg() { printf '\n\033[1;34m▸ %s\033[0m\n' "$*"; }

# autobuild [configure-args...] — run from inside a source dir. Universal static
# install into $PREFIX. Honors any CXXFLAGS/ICU_* env the caller exports first.
autobuild() {
  ./configure --prefix="$PREFIX" --enable-static --disable-shared --disable-werror --disable-tests "$@"
  make -j"$NCPU"
  make install
}

# autogen_build [configure-args...] — same, for git checkouts that ship no
# ./configure yet (runs autogen.sh once to generate it).
autogen_build() {
  [ -x ./configure ] || { [ -x ./autogen.sh ] && NOCONFIGURE=1 ./autogen.sh; }
  autobuild "$@"
}

# fix_icu_pc <name.pc> — the ICU-tier libraries' installed .pc files declare a
# pkg-config module (icu-i18n / icu-uc, and sometimes liblangtag) that does not
# exist in our prefix, because we bypassed it (ICU_LIBS=-licucore, or built
# --without-liblangtag). pkg-config would then fail to resolve the library and
# writerperfect would report it "no". Strip the phantom requirement, and make
# -licucore explicit so downstream static linking still pulls Apple's system ICU.
fix_icu_pc() {
  local pc="$PREFIX/lib/pkgconfig/$1"
  [ -f "$pc" ] || return 0
  perl -0pi -e 's/^(Requires\.private:.*?)\s*\bicu-(i18n|uc)\b/$1/mg;
                s/^(Requires\.private:.*?)\s*\bliblangtag\b/$1/mg;' "$pc"
  grep -q '^Libs.private:' "$pc" \
    && perl -pi -e 's/^Libs\.private:(?!.*-licucore)/Libs.private: -licucore/' "$pc" \
    || printf 'Libs.private: -licucore\n' >> "$pc"
}
