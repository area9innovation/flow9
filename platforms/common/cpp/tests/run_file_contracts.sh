#!/bin/bash
# Run with a locally built JIT-enabled Qt runner (FLOWCPP=/absolute/path/to/QtByteRunner).
set -eu

here=$(cd "$(dirname "$0")" && pwd -P)
root=$(cd "$here/../../../.." && pwd -P)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$root"
"${CXX:-c++}" -std=c++11 "$here/publish_new_file_test.cpp" -o "$work/publish-new"
mkdir "$work/publication"
(cd "$work/publication" && "$work/publish-new" && [[ $(ls -A) == result && $(cat result) == first ]])
"$root/bin/flowc1" "$here/file_contracts.flow" bytecode="$work/test.bytecode"
"$root/bin/flowc1" "$here/local_file_contracts.flow" bytecode="$work/local.bytecode"
"$root/bin/flowc1" "$here/fixtures/legacy_copy.flow" bytecode="$work/copy.bytecode"
cp "$here/fixtures/legacy_copy.flowbc" "$work/legacy.bytecode"

check_preflight() (
    mode=$1; shift
    mkdir "permissions-$mode" && cd "permissions-$mode"
    mkdir -p plan-src/sub plan-src/empty copy-out move-out
    printf 'sibling' >plan-src/ordinary
    printf 'child' >plan-src/sub/item
    for out in copy-out move-out; do printf 'previous' >"$out/keep"; done

    # 0400: names visible, child metadata unavailable. 0100: listing denied.
    chmod "$mode" plan-src/sub
    trap 'if [[ -d plan-src/sub ]]; then chmod 700 plan-src/sub; fi' EXIT
    if [[ $mode == 0400 ]]; then
        [[ $(ls -A plan-src/sub) == item && ! -e plan-src/sub/item ]]
    else
        [[ -f plan-src/sub/item ]]
        if ls -A plan-src/sub >/dev/null 2>&1; then exit 1; fi
    fi
    "$@"
    chmod 700 plan-src/sub
    [[ $(cat plan-src/ordinary) == sibling && $(cat plan-src/sub/item) == child && -d plan-src/empty ]]
    for out in copy-out move-out; do
        [[ $(ls -A "$out") == keep && $(cat "$out/keep") == previous ]]
    done
    touch permissions-restored
    "$@"
    for out in copy-out move-out; do
        [[ $(cat "$out/plan-src/ordinary") == sibling && $(cat "$out/plan-src/sub/item") == child ]]
        [[ -d $out/plan-src/empty && -z $(ls -A "$out/plan-src/empty") && $(cat "$out/keep") == previous ]]
    done
    [[ ! -e plan-src ]]
)

check_local() {
    mkdir -p out/blocked.dat tree/sub copy-out referent linked-tree/sub/deep
    printf 'untouched referent' >referent/sentinel
    ln -s referent dir-link
    ln -s ../../../referent linked-tree/sub/deep/link
    printf 'keep sibling' >linked-tree/sub/.keep
    printf 'keep root file' >linked-tree/ordinary
    ln -s ../../referent/sentinel tree/sub/file-link
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
    cmp odd.dat copy-out/tree/sub/odd.dat
    [[ $(cat referent/sentinel) == 'untouched referent' && $(ls -A referent) == sentinel ]]
    for d in out copy-out; do
        cmp referent/sentinel "$d/tree/sub/file-link"
        [[ ! -L $d/tree/sub/file-link ]]
    done
    [[ $(readlink dir-link) == referent && $(readlink linked-tree/sub/deep/link) == ../../../referent ]]
    [[ $(cat linked-tree/sub/.keep) == 'keep sibling' && $(cat linked-tree/ordinary) == 'keep root file' ]]
    [[ ! -e out/dir-link && ! -L out/dir-link && ! -e out/linked-tree && ! -L out/linked-tree ]]
    [[ alias-src/item -ef hardlink-dir/item && $(cat alias-src/item) == 'same entry' ]]
    cmp alias-src/item out/item
    [[ -z $(ls -A alias-src/sub) && -z $(find . -name '.flowcopy*' -print -quit) ]]
    [[ ! -e large.dat && $(cat blocked.dat) == 'keep source' && $(cat out/blocked.dat/keep) == unchanged ]]
    [[ $(stat -c %a out/odd.dat) == 600 && $(stat -c %a out/empty.dat) == 644 && $(stat -c %a out/large.dat) == 640 ]]
    if (( EUID != 0 )); then
        check_preflight 0400 "$@"
        check_preflight 0100 "$@"
    else
        echo 'Skipping directory permission cases (requires unprivileged user)' >&2
    fi
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
    for image in copy legacy; do
        python3 "$here/run_staged_copy_tests.py" run "${runner[@]}" "$work/$image.bytecode"
    done
done

if [[ ${CHECK_JAVA:-0} == 1 ]]; then
    cd "$root"
    "$root/bin/flowc1" "$here/local_file_contracts.flow" jar="$work/local.jar"
    "$root/bin/flowc1" "$here/fixtures/legacy_copy.flow" jar="$work/copy.jar"
    mkdir "$work/java" && cd "$work/java"
    check_local java -jar "$work/local.jar"
    python3 "$here/run_staged_copy_tests.py" run java -XX:-UsePerfData -jar "$work/copy.jar"
fi
