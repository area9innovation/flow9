#!/bin/bash
# Run with a locally built JIT-enabled Qt runner (FLOWCPP=/absolute/path/to/QtByteRunner).
set -eu

here=$(cd "$(dirname "$0")" && pwd -P)
root=$(cd "$here/../../../.." && pwd -P)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$root"
"$root/bin/flowc1" "$here/file_contracts.flow" bytecode="$work/test.bytecode"

for mode in jit interpreter; do
    mkdir "$work/$mode"
    cd "$work/$mode"
    args=()
    if [[ $mode == interpreter ]]; then args+=(--no-jit); fi
    FLOW="$root" XDG_CONFIG_HOME="$PWD/config" "${FLOWCPP:-$root/bin/flowcpp}" \
        --batch --max-heap 384 "${args[@]}" "$work/test.bytecode"
    for src in odd.dat even.dat large.dat empty.dat; do cmp "$src" "$src.copy"; done
done
