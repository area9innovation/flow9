#!/bin/bash

registry=""
if [ -n "$1" ]; then
  registry="$1/"
fi

qt_version="5.12.11"

docker build --build-arg QT=$qt_version -t "${registry}area9/qt:aqt-${qt_version}" .

