#!/bin/bash

qt_version=5.15.2

registry=""
if [ -n "$1" ]; then
  registry="$1/"
fi

docker build --build-arg QT="${qt_version}" -t "${registry}area9/qt:aqt-${qt_version}" .

