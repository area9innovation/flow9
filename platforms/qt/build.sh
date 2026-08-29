#!/bin/bash

set -e

if [ `uname` == Darwin ]; then
    PLATFORM=mac
else
    PLATFORM=linux
    PLATFORM_OPTS=
fi

SCRIPT_DIR=$( cd "$( dirname "$0" )" && pwd -P )

# Locate qmake. Prefer qmake6: some distributions (e.g. Arch and derivatives)
# only ship the Qt 6 qmake under that name, and on systems with both Qt 5 and
# Qt 6 installed, plain `qmake` is often the Qt 5 one. Set QMAKE to override.
if [ -z "${QMAKE:-}" ]; then
    if command -v qmake6 > /dev/null 2>&1; then
        QMAKE=qmake6
    elif command -v qmake > /dev/null 2>&1; then
        QMAKE=qmake
    else
        echo "Error: neither 'qmake' nor 'qmake6' was found in your PATH." >&2
        echo "Install Qt 6 (Arch: 'pacman -S qt6-base'), or add the bin folder" >&2
        echo "of your Qt installation to PATH, or set QMAKE to the qmake binary." >&2
        exit 1
    fi
fi

# Generate the shaders include file
pushd "$SCRIPT_DIR/../common/cpp/gl-gui/shaders" && ./pack.pl
popd

cd "$SCRIPT_DIR/bin/$PLATFORM"
"$QMAKE" $PLATFORM_OPTS -o Makefile ../../QtByteRunner.pro

if [ `uname` == Darwin ]; then
    make && macdeployqt QtByteRunner.app
else
    make -j16 $FLOWCPP_MAKE_OPTS
fi
