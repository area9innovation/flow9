#!/bin/bash

set -e

docker build -t flow9_byterunner .

if [ -z "$FLOW" ]; then
    echo "\$FLOW is undefined. It should point to the flow9 folder"
    exit
fi

# starting a shell instead of straight building because it's useful for debug
echo
echo
echo // HI THERE! //
echo
echo "Here is a shell inside the docker container with all dependencies."
echo "Run ./build.sh if you just want to build the byterunner in this folder."
echo "Otherwise run"
echo "qmake QtByteRunner.pro && make"
echo
echo "For CGI byte runner it's ./buildcgi.sh or"
echo "qmake QtByteRunnerCgi.pro && make"
echo
echo "Mind that building cgi runner after regular one may confuse the linker."
echo "Clean up the intermediate files just in case."
echo
echo

docker run -it --rm \
  -v "$FLOW"/:/flow \
  flow9_byterunner \
  bash 

