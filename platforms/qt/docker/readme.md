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

# Getting the result to run on more hosts

Neither of these is done; they are notes from trying.

## Static libjpeg

`libjpeg.so.8` is the only non-Qt library whose soname differs between
distributions; libpng, freetype, zlib and GLU match everywhere. Ubuntu's
`libjpeg-turbo8-dev` ships `libjpeg.a`, so on Linux `-ljpeg` in
`QtByteRunner.pro` could become `-l:libjpeg.a` (its licences allow static
linking). Fedora and Debian 13 meet the other requirements, so that alone
would let the result start there. Debian 12 would still be out, because of its
glibc and libstdc++. Not built or tested.

## Bundling Qt with an rpath

The binary can carry an rpath to a `lib/` next to it, through the qmake
arguments `build.sh` passes on:

```bash
mise run flowcpp:docker-build 'QMAKE_RPATHDIR+=$ORIGIN/lib' QMAKE_LFLAGS+=-Wl,--disable-new-dtags
```

Copying the libraries `ldd` lists from the build image into `lib/` gave a
runner that ran a `--batch` program on a host with Qt 6.12, using the bundled
Qt 6.4 instead. Things learned on the way:

- The single quotes keep `$ORIGIN` literal; qmake escapes it for make itself.
- `--disable-new-dtags` makes the linker write RPATH instead of RUNPATH. The
  loader ignores the executable's RUNPATH when it looks for the dependencies of
  other libraries, so the bundled Qt could not find the bundled ICU. The
  alternative is setting an rpath on every bundled library with `patchelf`,
  which is what linuxdeploy does.
- Qt has to be bundled complete. Qt modules use each other's private API, which
  is versioned per build, so a single bundled module fails against the host's
  other modules.
- Not only Qt: ICU and two WebEngine dependencies whose sonames had moved on
  on that host (`libvpx.so.9`, `libxml2.so.2`). Another distribution will miss
  different ones, so a real bundle should take everything except glibc, GL and
  the X/Wayland libraries, as AppImage's exclude list does.
- That came to 24 libraries and 228 MB, most of it WebEngine. A working
  `no_gui` build would need only Core, Network, Sql, WebSockets and ICU.
- The bundled libraries still need Ubuntu 24.04's glibc.
- GUI mode is untested. It also needs the platform plugins, a `qt.conf`, and
  `QtWebEngineProcess` with its resources. linuxdeploy's Qt plugin automates
  that part.

# Qt from qt.io

There used to be an image here that installed Qt 5.12 from qt.io with
[aqtinstall](https://github.com/miurahr/aqtinstall), plus a custom-built MySQL
driver. Distribution packages made both unnecessary. Should a Qt version the
distributions do not ship ever be needed, aqtinstall is the scriptable way to
get one; the old image is in the Git history.
