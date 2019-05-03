#!/bin/bash

set -e

if [ `uname` == Darwin ]; then
    PLATFORM=mac
    PLATFORM_OPTS="-spec macx-g++"
else
    PLATFORM=linux
    PLATFORM_OPTS=
fi

SCRIPT_DIR=$( cd "$( dirname "$0" )" && pwd -P )

qmake $PLATFORM_OPTS -o Makefile QtByteRunnerCgi.pro
make

strip QtByteRunner.fcgi
