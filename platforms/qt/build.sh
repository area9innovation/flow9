#!/bin/bash

set -e

if [ `uname` == Darwin ]; then
    READLINK=greadlink
    PLATFORM=mac
else
    READLINK=readlink
    PLATFORM=linux
    PLATFORM_OPTS=
fi

SCRIPT_DIR=$(dirname "$($READLINK -e "$0")")

# Generate the shaders include file
pushd ../common/cpp/gl-gui/shaders && ./pack.pl
popd

cd "$SCRIPT_DIR/bin/$PLATFORM"
qmake $PLATFORM_OPTS -o Makefile ../../QtByteRunner.pro

if [ `uname` == Darwin ]; then
    make && macdeployqt QtByteRunner.app
else
    make $FLOWCPP_MAKE_OPTS
fi
