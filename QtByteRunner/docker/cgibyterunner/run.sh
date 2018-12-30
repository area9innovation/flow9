#!/bin/bash
FLOW_FOLDER=~/area9/copenhagen/flow
if [ ! -f $FLOW_FOLDER/QtByteRunner/buildcgi.sh ]; then
    echo "Could not find flow in $FLOW_FOLDER"
    echo "Either make a symlink or adjust path in this script"
else
    docker run --rm \
      -v $FLOW_FOLDER:/flow \
      -it area9/qt-byte-runner:cgi $1
    echo ""
    echo "Results will be in $FLOW_FOLDER/QtByteRunner/bin/cgi/linux/"
    echo "Do ./run.sh \"make clean\" to recompile from scratch"
fi

