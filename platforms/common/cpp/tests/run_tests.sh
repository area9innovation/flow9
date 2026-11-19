#!/bin/bash

# Builds and runs the C++ unit tests with the address and undefined-behaviour sanitizers.
# Needs only g++ (or CXX=clang++); pass --qt to build with Qt 6 Core via pkg-config.

set -e

SCRIPT_DIR=$( cd "$( dirname "$0" )" && pwd -P )
CPP_DIR=$( dirname "$SCRIPT_DIR" )
WORK_DIR=$( mktemp -d )
trap 'rm -rf "$WORK_DIR"' EXIT

cxxflags=(-std=c++11)
libs=()
case "${1:-}" in
    --qt) cxxflags=(-std=c++17 -fPIC $(pkg-config --cflags Qt6Core))
          libs=($(pkg-config --libs Qt6Core)) ;;
    '') ;;
    *) echo "Usage: $0 [--qt]" >&2; exit 2 ;;
esac

# char_traits_fix.h uses memcpy without including <cstring>
"${CXX:-g++}" "${cxxflags[@]}" -g -O1 -Wall -fsanitize=address,undefined -include cstring \
    -I"$CPP_DIR" -I"$CPP_DIR/core" \
    "$CPP_DIR/core/Utf8.cpp" "$CPP_DIR/core/Utf32.cpp" \
    "$CPP_DIR/font/TextFont.cpp" "$SCRIPT_DIR/utf8_test.cpp" \
    -o "$WORK_DIR/utf8_test" "${libs[@]}"

"${CXX:-g++}" "${cxxflags[@]}" -g -O1 -Wall -fsanitize=address,undefined -include cstring \
    -I"$CPP_DIR" -I"$CPP_DIR/core" "$SCRIPT_DIR/flowstack_test.cpp" \
    -o "$WORK_DIR/flowstack_test" "${libs[@]}"

# Verify runtime guards with assertions disabled, like the release runner.
"${CXX:-g++}" -std=c++11 -g -O1 -DNDEBUG -fsanitize=address,undefined -include cstring \
    -I"$CPP_DIR" -I"$CPP_DIR/core" -I"$CPP_DIR/include" -pthread \
    "$CPP_DIR"/core/{ByteCodeRunner,ByteMemory,CodeMemory,GarbageCollector,HeapWalker,MemoryArea,Natives,Utf8}.cpp \
    "$CPP_DIR/utils/md5.cpp" "$SCRIPT_DIR/runtime_memory_test.cpp" \
    -o "$WORK_DIR/runtime_memory_test"

cd "$WORK_DIR"
./flowstack_test
export TMPDIR="$PWD/temp-雪"
mkdir "$TMPDIR"
./utf8_test
./runtime_memory_test
rmdir "$TMPDIR" # Neither named nor unnamed streams should leave files behind.
