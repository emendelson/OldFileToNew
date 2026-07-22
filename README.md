# OldFileToNew

A small macOS universal app that converts **old documents to modern formats**, 
based on and inspired by the Intel-only **anyOSX by Laurent Alonso** 
(https://sourceforge.net/projects/libmwaw/files/).

Drag one or more
legacy files onto the OldFileToNew window (or use **File ▸ Open…**) and each is converted and saved
next to the original — no need to identify the file type; it's detected automatically.

**[⬇ Download OldFileToNew 1.0](https://github.com/emendelson/OldFileToNew/releases/latest)** — notarized, universal, macOS 12+. Or [build it from source](build-from-source/).

By default it writes **OpenDocument** files (`.odt`, `.ods`, `.odp`, `.odg`), which open
in LibreOffice, Microsoft Office, Apple's iWork apps, and most modern software. In
**Settings…** you can pick more familiar per-category output formats (Word, RTF, HTML,
plain text via macOS's built-in tools; Excel, PowerPoint, PDF, or images if you have the
free LibreOffice installed), and set the input text encoding.

It is universal (Apple Silicon + Intel) and links only system libraries — no runtime
dependencies.

## Supported formats

OldFileToNew is built on the **libwpd / writerperfect** family of import libraries, giving
it wide coverage across four eras of software:

| Category | Reads (examples) |
|---|---|
| Word processors | MacWrite, WriteNow, Nisus, Word for Mac 1–5.1, ClarisWorks/AppleWorks, WordPerfect, Microsoft Works, AbiWord, StarOffice, iWork Pages |
| Spreadsheets | ClarisWorks/AppleWorks, Microsoft Works, iWork Numbers, (Lotus/Quattro via libwps) |
| Presentations | PowerPoint for Mac 1–4, iWork Keynote |
| Drawings & layout | MacDraw and other classic Mac drawing apps, CorelDRAW, Visio, Publisher, QuarkXPress, PageMaker, FreeHand, Zoner Draw |

Plus various e-book formats. A full, per-application list is in the app's **Help** window.
(Old Mac Excel is not currently supported.)

## Build it yourself

Everything needed to build the whole project from source — the 15 import libraries, the
`wpft2odf` converter, and the app — is in **[`build-from-source/`](build-from-source/)**,
as five numbered scripts with a README. Short version:

```sh
brew install autoconf automake libtool pkg-config gettext boost icu4c
cd build-from-source && ./01-fetch.sh && ./02-build-base.sh && \
  ./03-build-importers.sh && ./04-build-writerperfect.sh && ./05-build-app.sh
```

The result, `build/OldFileToNew.app`, is ad-hoc (locally) codesigned. To distribute it,
use your own Developer ID with `sign-and-notarize.sh`.

## Repository layout

- `Sources/OldFileToNew/` — the Swift/AppKit app (no third-party Swift dependencies).
- `Info.plist`, `make_app.sh`, `sign-and-notarize.sh` — packaging & signing.
- `Icons/` — icon source art (SVG + Icon Composer `.icon`); `Assets.car` (Liquid Glass)
  and `OldFileToNew.icns` (classic fallback) are under `Sources/.../Resources/`.
- `build-from-source/` — the from-scratch build scripts.
- The bundled `wpft2odf` binary is **not** checked in; it is produced by the build.

## Credits & licensing

Built on the excellent open-source work of the **libwpd / writerperfect** project,
including **libmwaw** by Laurent Alonso (whose supported-formats catalog informed the
Help page).

Component licenses: `librevenge`, `libwpd`, `libwpg`, `libodfgen`, `writerperfect`,
`libmwaw`, `libwps`, `libstaroffice`, `libpagemaker`, `libabw`, `libetonyek`,
`libfreehand`, `libcdr`, `libmspub`, `libqxp`, `libvisio`, `libzmf`, `libe-book` are
**LGPL 2.1+ / MPL 2.0**; `lcms2`, `mdds`, `glm` are MIT; `libpng` uses the PNG license.

`libwpd` is a fork with added WP6 cross-reference and WP5 page-numbering import support:
<https://github.com/emendelson/libwpd/tree/oldfiletonew>.

Because the app links this LGPL code statically, this repository — source plus the build
scripts that let anyone rebuild and relink it — is provided to satisfy the LGPL. The Swift
application code is © Edward Mendelson.
