#!/bin/bash

# Builds and runs the C++ unit tests with the address and undefined-behaviour sanitizers.
# Needs only g++ (or CXX=clang++); the test files are written in a temporary folder.

set -e

SCRIPT_DIR=$( cd "$( dirname "$0" )" && pwd -P )
CPP_DIR=$( dirname "$SCRIPT_DIR" )
WORK_DIR=$( mktemp -d )
trap 'rm -rf "$WORK_DIR"' EXIT

# char_traits_fix.h uses memcpy without including <cstring>
"${CXX:-g++}" -std=c++11 -g -O1 -Wall -fsanitize=address,undefined -include cstring \
    -I"$CPP_DIR" -I"$CPP_DIR/core" \
    "$CPP_DIR/core/Utf8.cpp" "$CPP_DIR/font/TextFont.cpp" "$SCRIPT_DIR/utf8_test.cpp" \
    -o "$WORK_DIR/utf8_test"

cd "$WORK_DIR"
./utf8_test
