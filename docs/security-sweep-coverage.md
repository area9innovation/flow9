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

### 2026-11-20 — slice 4: the rest of the document-fed decoders and emitters in `lib/formats/**`

This slice closes area 1 on the flow side: the parsers, the generated parser
tables and the string emitters that a document or a network peer reaches.

- `lib/formats/css/css.flow`
- `lib/formats/css/css_pegop.flow`
- `lib/formats/css/cssterm.flow`
- `lib/formats/css/stylesheet.flow`
- `lib/formats/dom/conversion/css2string.flow`
- `lib/formats/dom/conversion/element2xml.flow`
- `lib/formats/dom/conversion/xml2string.flow`
- `lib/formats/email/domain_pegop.flow`
- `lib/formats/email/email_pegop.flow`
- `lib/formats/html/html2form.flow`
- `lib/formats/json/flow2json.flow`
- `lib/formats/json/json_pegop.flow`
- `lib/formats/json/ppjson.flow`
- `lib/formats/latex/latex.flow`
- `lib/formats/latex/latex_compiled_parser.flow`
- `lib/formats/latex/latex_types.flow`
- `lib/formats/lsp.flow`
- `lib/formats/php/php_ast.flow`
- `lib/formats/unicode/unidecode.flow`
- `lib/formats/uri/uri_pegop.flow`
- `lib/formats/uri2/uri2_ast.flow`
- `lib/formats/uri2/uri2_parser.flow`
- `lib/formats/wabt.flow`
- `lib/formats/webvtt/webvtt_pegop.flow`
- `lib/formats/webvtt/webvtt_types.flow`

Read in part, only where the files above led into them, and so **not**
counted as covered — a later slice takes them whole:
`lib/lingo/compiler/syntaxtree_types.flow`, `lib/text/blueprint.flow`,
`lib/formats/dom/css.flow`, `lib/formats/dom/element.flow`,
`lib/formats/xml.flow` (covered in slice 1; its escaping helpers were read
again here and it stays covered).

### 2026-11-27 — slice 5: the rest of `lib/formats/**` on the flow side, and the Java binary and protocol decoders

This slice closes area 1 for `lib/formats/**`: what was left there is the DOM
dialect and its lowering to HTML, the typed layer of the HTML parser, the WASM
encoder and the generated URI mnemonics. Only test files remain under
`lib/formats/`. The slice then starts on the Java runtime, taking the string
and UTF-8 decoders in `Native.java`, the FastCGI protocol reader, and the file
and archive natives.

- `lib/formats/dom/assign.flow`
- `lib/formats/dom/css.flow`
- `lib/formats/dom/dom.flow`
- `lib/formats/dom/element.flow`
- `lib/formats/dom/event_handlers.flow`
- `lib/formats/dom/mathml.flow`
- `lib/formats/dom/render.flow`
- `lib/formats/dom/svg.flow`
- `lib/formats/dom/svgcss.flow`
- `lib/formats/dom/xml.flow`
- `lib/formats/dom/conversion/dom2element.flow`
- `lib/formats/dom/conversion/event_handler2elementevent.flow`
- `lib/formats/dom/conversion/svg2element.flow`
- `lib/formats/dom/conversion/svgcss2string.flow`
- `lib/formats/html/parser/html_parse_typed.flow`
- `lib/formats/html/parser/html_types.flow`
- `lib/formats/html/parser/html_types2dsl.flow`
- `lib/formats/uri2/uri2_ast_mnemonics.flow`
- `lib/formats/wasm/wasm_encode.flow`
- `lib/formats/wasm/wasm_types.flow`
- `platforms/java/com/area9innovation/flow/FastCgi.java`
- `platforms/java/com/area9innovation/flow/FastCgiMessage.java`
- `platforms/java/com/area9innovation/flow/FlowFileSystem.java`
- `platforms/java/com/area9innovation/flow/FlowHash.java`
- `platforms/java/com/area9innovation/flow/Native.java`

Read in part, only where the files above led into them, and so **not**
counted as covered — a later slice takes them whole:
`lib/tools/dsl/dsl_util.flow`, `lib/formats/dom/conversion/css2string.flow`
and `lib/formats/dom/conversion/xml2string.flow` (both covered in slice 4;
their escaping and emission were read again here and they stay covered),
`lib/formats/xml.flow` (covered in slice 1, same).

## Next

116 of roughly 350 files in the listed surface are covered. Areas 1 and 2 are
done: area 1 holds nothing further under `lib/formats/` but test files, and the
Java string and UTF-8 decoders it reaches are read.

Remaining: area 3, the browser runtime under `platforms/js/**` — `Native.hx`,
`HttpSupport.hx`, the DOMPurify use, postMessage, URL and cookie handling and
WebClip — and then the rest of area 4, the server natives and libraries in
`platforms/java` (http, websocket, `Database.java`, `FlowJwt`, `FlowCrypto`,
`FlowPassword`) and in `lib/server/**`, `lib/net/**`, `lib/fs/**`,
`lib/sys/process.flow`, `lib/jwt.flow`, `lib/crypto_aes.flow`,
`lib/password.flow` and `lib/webauthn`. Area 5 last.
