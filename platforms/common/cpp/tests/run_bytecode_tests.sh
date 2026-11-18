#!/bin/bash

# Release-mode validator and interpreter tests. No Qt or JIT is needed.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
CPP_DIR=$(dirname "$SCRIPT_DIR")
ROOT=$(cd "$CPP_DIR/../../.." && pwd -P)
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# char_traits_fix.h uses memcpy without including <cstring>.
"${CXX:-g++}" -std=c++11 -O1 -DNDEBUG -pthread -include cstring -I"$CPP_DIR" -I"$CPP_DIR/core" \
    "$SCRIPT_DIR/bytecode_validation_test.cpp" \
    "$CPP_DIR/core/"{ByteCodeRunner,ByteMemory,CodeMemory,GarbageCollector,HeapWalker,MemoryArea,Natives,Utf8,Utf32}.cpp \
    "$CPP_DIR/utils/"{AbstractHttpSupport,FileSystemInterface,FileLocalStore,flowfilestruct,base64,md5}.cpp \
    -o "$WORK_DIR/bytecode_validation_test"

cd "$ROOT"
bin/flowc1 platforms/common/cpp/tests/bytecode_validation.flow "bytecode=$WORK_DIR/valid.bytecode" debug=1
"$WORK_DIR/bytecode_validation_test" "$WORK_DIR/valid.bytecode" "$WORK_DIR/coverage" > "$WORK_DIR/actual"
for run in 1 2 3 4; do printf 'true\nFlow ✓\n'; done > "$WORK_DIR/expected"
diff -u "$WORK_DIR/expected" "$WORK_DIR/actual"
