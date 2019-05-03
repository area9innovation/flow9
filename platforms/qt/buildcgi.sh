#!/bin/bash

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

qmake $PLATFORM_OPTS -o Makefile QtByteRunnerCgi.pro
make

strip QtByteRunner.fcgi
