# Runtime security sweep — coverage

The weekly runtime security sweep reads a bounded slice of the standing
runtime and library code, so that over months the exposed surface is
covered once and then kept.

This file is a record of **which paths were read and when**. It holds paths
and dates only. It never records what was found: this repository is public,
and a list of suspected defects with file and line is a map. Anything the
sweep finds goes to the run log of the routine instead, and a fix waits for
a person's decision in its own pull request.

The surface is read highest-exposure first:

1. input fed by the network or a document — binary and text decoders,
   `lib/formats/**`, image and font loaders;
2. the bytecode loader and the JIT;
3. the browser runtime, `platforms/js/**`;
4. server natives and libraries;
5. the PHP files under `www/`, the compile server and the LSP.

## Covered

### 2026-10-20 — slice 1: binary, text and image decoders fed by network or document

- `lib/text/binary.flow`
- `lib/formats/base64.flow`
- `lib/formats/ini.flow`
- `lib/formats/csv.flow`
- `lib/formats/xml.flow`
- `lib/formats/json/json.flow`
- `lib/formats/json/json_parse.flow`
- `lib/formats/json/json_compact.flow`
- `lib/formats/email/email.flow`
- `platforms/common/cpp/utils/base64.cpp`
- `platforms/common/cpp/utils/base64.h`
- `platforms/common/cpp/core/Utf8.cpp`
- `platforms/common/cpp/gl-gui/ImageLoader.cpp`
- `platforms/common/cpp/gl-gui/ImageLoader.h`
- `platforms/common/cpp/font/TextFont.cpp`
- `platforms/js/JSBinflowBuffer.hx`

Read in part, only where the files above led into them, and so **not**
counted as covered — a later slice takes them whole:
`platforms/common/cpp/gl-gui/GLRenderer.cpp`,
`platforms/common/cpp/utils/AbstractHttpSupport.cpp`,
`platforms/common/haxe/HaxeRuntime.hx`, `platforms/js/Native.hx`,
`platforms/js/HttpSupport.hx`, `lib/string.flow`.

## Next

Remaining in area 1: the rest of `lib/formats/**`, the JSON and UTF-8
decoders in `platforms/java`, and the font loaders under
`platforms/common/cpp/font`. Then area 2, the bytecode loader and the JIT.
