#!/usr/bin/env python3
"""Regression test for the flowc `env=name=value` compile-time constants.

Checks that
  - global constants of all four supported types are replaced by literals,
  - local bindings which happen to carry the same name are left alone,
  - names without a global definition are ignored,
  - changing a value invalidates no incremental (.module) file.

Run it with no setup at all:  python3 runtest.py

It finds flow9/bin next to itself, so neither `flowc` nor `flowcpp` needs to be on the
PATH. By default it uses `flowc`, which runs the compiler source under flowcpp and so
picks up edits to tools/flowc with no rebuild. Set FLOWC=flowc1 to test the built jar
instead, or FLOWC=/some/other/flowc to point somewhere else entirely.
"""

import os
import shutil
import subprocess
import sys

OBJ = "objc"
JS = "test_env.js"
BAD_BYTECODE = "test_env_badtype.bytecode"

HERE = os.path.dirname(os.path.abspath(__file__))
# .../flow9/tools/flowc/tests/compile_time_env -> .../flow9/bin
FLOW_BIN = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", "bin"))
# flowc execs `flowcpp`, and flowc1 is a sibling, so putting bin first covers both.
SUBPROC_ENV = dict(os.environ, PATH=FLOW_BIN + os.pathsep + os.environ.get("PATH", ""))
FLOWC = os.environ.get("FLOWC", "flowc")

ENV = ",".join([
    "A9_S=SUBST_S",
    "A9_I=4242",
    "A9_D=3.75",
    "A9_B=true",
    # Globals shadowed by a local of the same name in test_env.flow.
    "A9_ARG=BAD_ARG",
    "A9_LET=SUBST_LET",
    # Names bound only locally, with no global definition anywhere.
    "A9_CASE=BAD_CASE",
    "A9_NO_GLOBAL=BAD_NO_GLOBAL",
])

# The generated code must contain these ...
EXPECTED = {
    '"SUBST_S"': 1,      # global string
    "4242": 1,           # global int
    "3.75": 1,           # global double
    '"SUBST_LET"': 2,    # the two global reads around the shadowing `let`
    '"arg-value"': 1,    # the argument of the function whose parameter shadows A9_ARG
    '"lambda-arg-value"': 1,
    '"let-value"': 1,    # the shadowing `let`
    '"case-value"': 1,   # the switch case binding
    '"local-only-value"': 1,
}

# ... and none of these.
FORBIDDEN = [
    "BAD_ARG",        # a function/lambda argument must never be substituted
    "BAD_CASE",       # nor a switch case binding
    "BAD_NO_GLOBAL",  # nor a `let` with no global of that name
    "default-s",      # the defaults must have been replaced
    "global-arg",
    "global-let",
]


def clean():
    if os.path.isdir(OBJ):
        shutil.rmtree(OBJ)
    for f in (JS, BAD_BYTECODE, "flowc.debug", "flowc.bytecode"):
        if os.path.isfile(f):
            os.remove(f)


def run_compiler(env, extra=()):
    """Compiles test_env.flow. Returns (generated js, compiler log), or (None, log)."""
    args = [FLOWC, "server=0", "obj=" + OBJ, "js=" + JS, "file=test_env.flow"] + list(extra)
    if env:
        args.append("env=" + env)
    res = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         universal_newlines=True, env=SUBPROC_ENV)
    if res.returncode != 0:
        print("FAILED: `%s` exited with %d\n%s" % (" ".join(args), res.returncode, res.stdout))
        return (None, res.stdout)
    with open(JS, encoding="utf8") as f:
        return (f.read(), res.stdout)


def compile(env):
    return run_compiler(env)[0]


def test_substitution():
    js = compile(ENV)
    if js is None:
        return False
    ok = True
    for marker, times in EXPECTED.items():
        seen = js.count(marker)
        if seen != times:
            print("FAILED: expected %s %d time(s) in %s, saw %d" % (marker, times, JS, seen))
            ok = False
    for marker in FORBIDDEN:
        if marker in js:
            print("FAILED: %s must not appear in %s" % (marker, JS))
            ok = False
    if ok:
        print("PASSED: env values replace globals only, never local bindings")
    return ok


def test_cache_is_not_invalidated():
    """Changing an env value must not invalidate a single module.

    Asserted from flowc's own incremental bookkeeping at verbose=1, the way
    tests/string_import/runtest.py does it, rather than by comparing the .module bytes:
    a module written twice from identical sources is not byte-identical, so a byte
    comparison only ever shows whether the files were rewritten, and reports any
    unrelated rebuild - a changed compiler, say - as a failure of this feature.
    """
    # Warm the cache, then change only the env value.
    js, _ = run_compiler(ENV, extra=["verbose=1"])
    if js is None:
        return False
    js, log = run_compiler(ENV.replace("A9_S=SUBST_S", "A9_S=OTHER_S"), extra=["verbose=1"])
    if js is None:
        return False
    if '"OTHER_S"' not in js:
        print("FAILED: the new value did not reach the generated code")
        return False

    saved = [l.split("Saving incremental for ", 1)[1].strip()
             for l in log.splitlines() if "Saving incremental for " in l]
    outdated = [l.split("Deleting outdated incremental for ", 1)[1].strip()
                for l in log.splitlines() if "Deleting outdated incremental for " in l]
    loaded = [l for l in log.splitlines() if "Loaded incremental for " in l]
    if not loaded:
        print("FAILED: no module was loaded from the cache, so this proves nothing\n" + log)
        return False
    if saved or outdated:
        print("FAILED: changing an env value invalidated modules")
        for label, ns in (("recompiled", saved), ("discarded", outdated)):
            if ns:
                print("  %s: %s" % (label, ", ".join(ns)))
        return False
    print("PASSED: changing an env value invalidates nothing (%d modules reused)" % len(loaded))
    return True


def test_unsupported_type_is_refused():
    """A global of an unsupported type reports an error instead of being substituted.

    The subject of a switch has to stay a variable - fiMapExpArgs fails hard if a mapping
    turns it into something else - so this is the position where refusing matters. Before
    the globals-only change the subject was never visited and this file compiled silently,
    while the very same name used anywhere else already produced this error.
    """
    args = [FLOWC, "server=0", "obj=" + OBJ, "bytecode=" + BAD_BYTECODE, "file=test_env_badtype.flow",
            "env=A9_BAD_TYPE=whatever"]
    res = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         universal_newlines=True, env=SUBPROC_ENV)
    if res.returncode == 0:
        print("FAILED: an unsupported type should not compile silently\n" + res.stdout)
        return False
    if "Compile-time constant cannot be of type: Mode" not in res.stdout:
        print("FAILED: expected the unsupported-type error, got:\n" + res.stdout)
        return False
    print("PASSED: an unsupported type is refused with a clear error, not substituted")
    return True


def test_without_env():
    js = compile(None)
    if js is None:
        return False
    if "default-s" not in js:
        print("FAILED: without env= the global must keep its own default")
        return False
    print("PASSED: without env= the globals keep their defaults")
    return True


if __name__ == "__main__":
    os.chdir(HERE)
    print("Using compiler: %s (flow9/bin at %s)" % (FLOWC, FLOW_BIN))
    clean()
    # The list is built first, so every case runs and reports, even after a failure.
    passed = all([test_substitution(), test_cache_is_not_invalidated(),
                  test_unsupported_type_is_refused(), test_without_env()])
    clean()
    sys.exit(0 if passed else 1)
