# Agent guidance

flow9 is the flow programming language, its compiler (`flowc`), its runtimes and
its standard library. **This repository is public.** Nothing in a commit, a pull
request or a comment names an internal host, a path on a machine, an account, a
customer or an internal URL, and no security defect is described in a way that
hands someone an attack.

## Compiling and checking

- `bin/flowc1 <file.flow>` typechecks and compiles with the committed Java
  compiler (`tools/flowc/flowc.jar`, Java 21+). It exits 1 on any error and
  needs no native build. `bin/flowc1 lint=1 <file.flow>` runs the linter.
- Entry points that cover most of the tree: `tools/flowc/flowc.flow` (the
  compiler) and `lib/material/material.flow` (the UI library and most of `lib/`).
- The native runner (`bin/flowcpp`) needs `bin/setup-linux`: Qt 6, git LFS and
  the asmjit submodule. Most checks do not need it.
- `tools/flowc/flowc.jar` is rebuilt with `bin/build-flowc` and committed by a
  person. Fix compiler sources; never commit a rebuilt jar unless asked.
- `flowc1 unittests=1 outfolder=1` is not a test gate: it writes an untracked
  `tools/flowc/tests/out/` into the tree and exits 0 whatever it finds. Compile
  entry points directly and read the exit code. Fixtures under
  `tools/flowc/tests/` include files that are meant not to compile.

## Language rules

- Bindings are immutable. No `while`, `for` or `return`: the last expression of
  a block is its value.
- Unused parameters are `__`, never `_` (reserved for translation).
- Struct names start with an upper-case letter; no underscores in names (the
  linter enforces it); filenames are lower-case.
- Imports are transitive and written without a suffix: `import ds/set;`.
- `doc/gpt4.md` is the language primer.

## Working here

- Never commit, push or create a branch unless explicitly asked.
- `metamind_routines.yaml` declares the unattended maintenance a Dev Box may run
  on this repository. It is read from `origin/master` only.
