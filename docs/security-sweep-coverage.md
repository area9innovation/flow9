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

### 2026-10-29 — slice 2: document-fed markup, URL and MIME decoders; the font curve helper

- `lib/formats/css/parse_css.flow`
- `lib/formats/comap.flow`
- `lib/formats/comap2.flow`
- `lib/formats/html/form2html.flow`
- `lib/formats/html/html.flow`
- `lib/formats/html/html2md.flow`
- `lib/formats/html/html2text.flow`
- `lib/formats/html/html_node.flow`
- `lib/formats/html/html_parse.flow`
- `lib/formats/html/parser/html_parser.flow`
- `lib/formats/json/json_utils.flow`
- `lib/formats/mathml.flow`
- `lib/formats/mime/mime_types.flow`
- `lib/formats/svg/svg.flow`
- `lib/formats/svg/svgpath.flow`
- `lib/formats/uri/uri.flow`
- `lib/formats/uri2/uri2.flow`
- `lib/formats/uri3/uri3.flow`
- `lib/formats/webvtt/webvtt.flow`
- `lib/text/gringo/dcode_lib.flow`
- `platforms/common/cpp/font/BezierUtils.cpp`
- `platforms/common/cpp/font/BezierUtils.h`
- `platforms/common/cpp/font/TextFont.h`
- `platforms/java/com/area9innovation/flow/FlowRuntime.java`
- `platforms/java/com/area9innovation/flow/Struct.java`

Read in part, only where the files above led into them, and so **not**
counted as covered — a later slice takes them whole:
`platforms/java/com/area9innovation/flow/Native.java`,
`platforms/common/cpp/core/Natives.cpp`,
`lib/formats/html/html2form.flow`, `lib/net/url.flow`.

### 2026-11-05 — slice 3: area 2, the bytecode loader, the JIT and the core runtime

The whole of `platforms/common/cpp/core/`, taken as one slice because the
loader, the interpreter, the allocator, the collector and the JIT read the
same lengths and indices and only make sense read together.

- `platforms/common/cpp/core/ByteCodeRunner.cpp`
- `platforms/common/cpp/core/ByteCodeRunner.h`
- `platforms/common/cpp/core/ByteMemory.cpp`
- `platforms/common/cpp/core/ByteMemory.h`
- `platforms/common/cpp/core/char_traits_fix.h`
- `platforms/common/cpp/core/CodeMemory.cpp`
- `platforms/common/cpp/core/CodeMemory.h`
- `platforms/common/cpp/core/CommonTypes.h`
- `platforms/common/cpp/core/GarbageCollector.cpp`
- `platforms/common/cpp/core/GarbageCollector.h`
- `platforms/common/cpp/core/HeapWalker.cpp`
- `platforms/common/cpp/core/HeapWalker.h`
- `platforms/common/cpp/core/JitProgram.cpp`
- `platforms/common/cpp/core/JitProgram.h`
- `platforms/common/cpp/core/MemoryArea.cpp`
- `platforms/common/cpp/core/MemoryArea.h`
- `platforms/common/cpp/core/nativefunction.h`
- `platforms/common/cpp/core/Natives.cpp`
- `platforms/common/cpp/core/NativeProgram.h`
- `platforms/common/cpp/core/opcodes.h`
- `platforms/common/cpp/core/RunnerMacros.h`
- `platforms/common/cpp/core/STLHelpers.h`
- `platforms/common/cpp/core/Utf32.cpp`
- `platforms/common/cpp/core/win_mman.c`
- `platforms/common/cpp/core/win_mman.h`

`platforms/common/cpp/core/Utf8.cpp` was covered in slice 1; parts of it were
read again here where this slice led into them, and it stays covered.

## Next

66 of roughly 350 files in the listed surface are covered. Area 2 is done.

Remaining in area 1: the rest of `lib/formats/**` (the latex, wasm, dom and
php sub-trees, `lsp.flow`, the `uri2` parser tables), `lib/formats/html/html2form.flow`,
`lib/formats/unicode/unidecode.flow`, and the UTF-8 and binary decoders in
`platforms/java`. Then area 3, the browser runtime under `platforms/js/**`.
