#!/bin/bash
# x86-64 JIT unit tests. Requires the repository's asmjit submodule. Pass a
# freshly built QtByteRunner to also run the Flow smoke test in both modes.
set -euo pipefail

if [[ $# -gt 1 ]]; then
    echo "Usage: $0 [QtByteRunner]" >&2
    exit 2
fi

here=$(cd "$(dirname "$0")" && pwd)
asmjit="$here/../asmjit/src/asmjit"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

"${CXX:-g++}" -std=c++17 -DASMJIT_STATIC -DASMJIT_DISABLE_COMPILER \
    -I"$here/.." -I"$asmjit/.." "$here/jit_metadata_test.cpp" \
    "$asmjit"/{base,x86}/*.cpp -pthread -o "$work/jit_metadata_test"
"$work/jit_metadata_test"

if [[ $# -eq 1 ]]; then
    runner=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
    (cd "$here/../../../.." && bin/flowc1 server=0 "bytecode=$work/smoke.bytecode" tests/jit_metadata_test.flow)
    cd "$work"
    "$runner" --batch --verbose smoke.bytecode | tee jit.out
    grep -Fxq 'JIT metadata smoke test passed' jit.out
    test -s flowjit.asmlog
    "$runner" --batch --no-jit smoke.bytecode | tee interp.out
    grep -Fxq 'JIT metadata smoke test passed' interp.out
fi
