#!/bin/bash

set -e

if [ `uname` == Darwin ]; then
    PLATFORM=mac
else
    PLATFORM=linux
    PLATFORM_OPTS=
fi

SCRIPT_DIR=$( cd "$( dirname "$0" )" && pwd -P )

# Generate the shaders include file
pushd ../common/cpp/gl-gui/shaders && ./pack.pl
popd

cd "$SCRIPT_DIR/bin/$PLATFORM"
qmake $PLATFORM_OPTS -o Makefile ../../QtByteRunner.pro

if [ `uname` == Darwin ]; then
    make && macdeployqt QtByteRunner.app
else
    make -j16 $FLOWCPP_MAKE_OPTS
fi
