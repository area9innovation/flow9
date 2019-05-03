#!/bin/bash

#
# Builds the FlowFontConvertor binary
# (invoked by ${FLOWDIR}/tools/fontprocessor/fontprocessor.flow)
#

set -e

if [ `uname` == Darwin ]; then
    PLATFORM=mac
    PLATFORM_OPTS="-spec macx-g++"
else
    PLATFORM=linux
    PLATFORM_OPTS=
fi

SCRIPT_DIR=$( cd "$( dirname "$0" )" && pwd -P )

cd "$SCRIPT_DIR/bin/$PLATFORM"
qmake $PLATFORM_OPTS -o Makefile ../../FontConvertor.pro
make
