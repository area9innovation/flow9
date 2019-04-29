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

SCRIPT_FN=`$READLINK -e "$0"`
SCRIPT_DIR=`dirname "$SCRIPT_FN"`

qmake $PLATFORM_OPTS -o Makefile QtByteRunnerCgi.pro
make

strip QtByteRunner.fcgi
