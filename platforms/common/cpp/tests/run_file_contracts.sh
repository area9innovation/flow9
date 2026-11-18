#!/bin/bash
# Run with a locally built JIT-enabled Qt runner (FLOWCPP=/absolute/path/to/QtByteRunner).
set -eu

here=$(cd "$(dirname "$0")" && pwd -P)
root=$(cd "$here/../../../.." && pwd -P)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$root"
"$root/bin/flowc1" "$here/file_contracts.flow" bytecode="$work/test.bytecode"
"$root/bin/flowc1" "$here/local_file_contracts.flow" bytecode="$work/local.bytecode"
cp "$here/fixtures/legacy_copy.flowbc" "$work/legacy.bytecode"

check_local() {
    mkdir -p out/blocked.dat tree/sub
    mkdir -p alias-src/sub hardlink-dir
    printf 'same entry' >alias-src/item
    ln -s alias-src alias-parent
    ln -s alias-parent/sub alias-child
    ln alias-src/item hardlink-dir/item
    ln -s out alias-out
    printf 'previous' >out/odd.dat
    chmod 0600 out/odd.dat
    printf 'previous' >out/empty.dat
    chmod 0644 out/empty.dat
    printf 'unchanged' >out/blocked.dat/keep
    printf 'keep source' >blocked.dat
    printf 'A\000\377' >odd.dat
    cp odd.dat tree/sub/odd.dat
    : >empty.dat
    head -c 150003 /dev/zero | tr '\000' '\377' >large.dat
    cp large.dat expected
    "$@"
    cmp odd.dat out/odd.dat && cmp empty.dat out/empty.dat && cmp expected out/large.dat || return 1
    cmp odd.dat out/tree/sub/odd.dat
    [[ alias-src/item -ef hardlink-dir/item && $(cat alias-src/item) == 'same entry' ]]
    cmp alias-src/item out/item
    [[ -z $(ls -A alias-src/sub) && -z $(find . -name '.flowcopy*' -print -quit) ]]
    [[ ! -e large.dat && $(cat blocked.dat) == 'keep source' && $(cat out/blocked.dat/keep) == unchanged ]]
    [[ $(stat -c %a out/odd.dat) == 600 && $(stat -c %a out/empty.dat) == 644 && $(stat -c %a out/large.dat) == 640 ]]
}

umask 027
for mode in jit interpreter; do
    mkdir "$work/$mode"
    cd "$work/$mode"
    args=()
    if [[ $mode == interpreter ]]; then args+=(--no-jit); fi
    export FLOW="$root" XDG_CONFIG_HOME="$PWD/config"
    runner=("${FLOWCPP:-$root/bin/flowcpp}" --batch --max-heap 384 "${args[@]}")
    "${runner[@]}" "$work/test.bytecode"
    for src in odd.dat even.dat large.dat empty.dat; do cmp "$src" "$src.copy"; done
    # The same two packed code units represent both ABC and ABC\0.
    printf 'ABC\0' >trailing-zero
    printf 'private' >legacy.dst
    chmod 0600 legacy.dst
    for src in odd.dat trailing-zero even.dat large.dat empty.dat; do
        cp "$src" legacy.src
        "${runner[@]}" "$work/legacy.bytecode"
        cmp legacy.src legacy.dst
        [[ $(stat -c %a legacy.dst) == 600 ]]
    done
    rm legacy.src
    printf 'previous' >legacy.dst
    if "${runner[@]}" "$work/legacy.bytecode"; then exit 1; fi
    [[ $(cat legacy.dst) == previous ]]
    check_local "${runner[@]}" "$work/local.bytecode"
done

if [[ ${CHECK_JAVA:-0} == 1 ]]; then
    cd "$root"
    "$root/bin/flowc1" "$here/local_file_contracts.flow" jar="$work/local.jar"
    mkdir "$work/java" && cd "$work/java"
    check_local java -jar "$work/local.jar"
fi
