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

SCRIPT_FN=`$READLINK -e "$0"`
SCRIPT_DIR=`dirname "$SCRIPT_FN"`

cd "$SCRIPT_DIR/bin/$PLATFORM"
qmake $PLATFORM_OPTS -o Makefile ../../FontConvertor.pro
make
