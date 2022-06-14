#!/bin/bash

qt_version="5.15.2"
ubuntu_version="focal"

registry=""
if [ -n "$1" ]; then
  registry="$1/"
fi

docker build --build-arg QT="${qt_version}" -t "${registry}area9/qt:aqt-${ubuntu_version}-${qt_version}" .

