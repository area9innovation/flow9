#!/bin/bash

#
# Builds the FlowFontConvertor binary
# (invoked by ${FLOWDIR}/tools/fontprocessor/fontprocessor.flow)
#

set -e

if [ `uname` == Darwin ]; then
    READLINK=greadlink
    PLATFORM=mac
    PLATFORM_OPTS="-spec macx-g++"
else
    READLINK=readlink
    PLATFORM=linux
    PLATFORM_OPTS=
fi

SCRIPT_DIR=$(dirname "$($READLINK -e "$0")")

cd "$SCRIPT_DIR/bin/$PLATFORM"
qmake $PLATFORM_OPTS -o Makefile ../../FontConvertor.pro
make
