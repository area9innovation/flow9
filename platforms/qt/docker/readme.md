A container image for building the Qt byte runner. It is not published to any
registry and is meant to be built locally when needed. Both docker and podman
(through its docker shim) work.

# runner-build

Builds `QtByteRunner` against the Qt 6 packaged by Ubuntu 24.04, so neither
qmake nor a compiler has to be installed on the host. The checkout is mounted,
and the result lands in `QtByteRunner-build-release/` at its root, which
`bin/flowcpp` uses before the committed binary.

```bash
git submodule update --init platforms/common/cpp/asmjit
mise run flowcpp:docker-build
```

The task runs `runner-build/build.sh`, which also works without mise. Extra
arguments are passed to qmake, e.g. `mise run flowcpp:docker-build CONFIG+=debug`,
and `mise run flowcpp:docker-shell` (`build.sh --shell`) gives a shell in the
container instead. The build directory is reused, so a debug build lands in
`QtByteRunner-build-release/` too; changing the arguments, or building there on
the host in between, starts a clean build.

The result runs on hosts that have:

- the Qt 6 runtime libraries, 6.4 or newer;
- glibc 2.38 and libstdc++ from GCC 13 or newer;
- `libjpeg.so.8`.

That covers Ubuntu 24.04 and newer, and Arch. Debian and
Fedora ship `libjpeg.so.62` instead, so the result does not start there,
whatever their Qt. Without the Qt 6 runtime libraries `bin/flowcpp` fails to
start, because it prefers the build over the committed binary. Remove
`QtByteRunner-build-release/` to go back to the committed one.

# Qt from qt.io

There used to be an image here that installed Qt 5.12 from qt.io with
[aqtinstall](https://github.com/miurahr/aqtinstall), plus a custom-built MySQL
driver. Distribution packages made both unnecessary. Should a Qt version the
distributions do not ship ever be needed, aqtinstall is the scriptable way to
get one; the old image is in the Git history.
