# Building OldFileToNew from source

These five scripts build the entire toolchain — 15 legacy-format import libraries,
the `wpft2odf` converter that ties them together, and the macOS app — from nothing,
and produce a locally (ad-hoc) codesigned `OldFileToNew.app`.

Everything is built **universal** (Apple Silicon + Intel) and, crucially, so the
finished converter links **only `/usr/lib` system libraries** — it can be handed to
any Mac with no Homebrew and no other dependencies.

## Prerequisites

- macOS 12+ (Tahoe 26 recommended — needed only to *render* the Liquid Glass icon).
- **Xcode command-line tools:** `xcode-select --install`
- **Homebrew** (<https://brew.sh>), then the build-time tools and headers:

  ```sh
  brew install autoconf automake libtool pkg-config gettext boost icu4c
  ```

  `boost` and `icu4c` are used for their **headers only** — nothing from Homebrew is
  linked into the finished binary (see "Why it's distributable" below).
  (Optional, only to regenerate the icon: `brew install librsvg`.)

## Build

```sh
cd build-from-source
./01-fetch.sh              # clone the library forks + download import-lib tarballs
./02-build-base.sh         # librevenge, the PATCHED libwpd, libwpg, libodfgen, + deps
./03-build-importers.sh    # the 13 legacy-format import libraries
./04-build-writerperfect.sh# the universal wpft2odf dispatcher
./05-build-app.sh          # bundle wpft2odf, build + assemble + ad-hoc sign the app
```

The finished app is `../build/OldFileToNew.app`. First launch: right-click → **Open**
(ad-hoc-signed apps aren't notarized). To ship it, sign with your own Developer ID
via `../sign-and-notarize.sh`.

Sources and the install prefix land in `~/oldfiletonew-build` by default; override with
`OFTN_ROOT=/some/path`.

## Why it's distributable (the libicucore trick)

Six of the import libraries (CorelDRAW, Publisher, QuarkXPress, Visio, Zoner, e-book —
plus FreeHand) need ICU. Rather than build and ship ICU, we exploit that they use only
ICU's stable **C API** (`ucnv_*` charset conversion, `ucsdet_*` detection, `uloc_*`),
every symbol of which Apple's system `/usr/lib/libicucore.A.dylib` already exports —
**unversioned**. So we compile against icu4c's *headers* with `-DU_DISABLE_RENAMING=1`
(which makes the header declarations unversioned too) and link `-licucore`. The symbols
match Apple's system library, nothing ICU is bundled, and the app stays dependency-free.

The other tricks the scripts encode: `mdds` needs C++17 while Apple's `g++` defaults to
gnu++14 (`-std=gnu++17`); several `.pc` files declare pkg-config modules we bypassed and
must be patched (`fix_icu_pc`); `libfreehand` needs a one-line source fix for modern ICU
macros; `libe-book` needs `-Wno-register` and `-DTRUE=1 -DFALSE=0`; and `wpft2odf`'s
object must be removed before relinking so its per-format `#ifdef` guards recompile.

## The patched libwpd

`libwpd` here is a fork with added **WP6 cross-references + WP5 page-numbering** import
support (branch `oldfiletonew`):
<https://github.com/emendelson/libwpd/tree/oldfiletonew>. `01-fetch.sh` clones that
branch. Everything else is stock upstream.

## Licensing

The import libraries and `writerperfect` are **LGPL 2.1+ / MPL 2.0**; `lcms2`, `mdds`,
and `glm` are MIT; `libpng` uses the PNG license. Because `OldFileToNew.app` links this
LGPL code statically, this repository (source + build scripts + the patched-libwpd
branch) is what makes relinking possible, as the LGPL requires. See the top-level
`README.md` for the full component list and links.
