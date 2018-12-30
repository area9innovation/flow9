#!/bin/bash

export QT_VERSION=5.10.0

sed "s|%QT_VERSION%|${QT_VERSION}|" Dockerfile.template > Dockerfile

rm -rf qbr/
rsync -art ../../../QtByteRunner/ qbr/ --exclude bin --exclude docker --exclude ios
# we've excluded bin above to speed things up, so creating it manually here
mkdir -p qbr/bin/linux

docker build \
  --build-arg qt_version=$QT_VERSION \
  -t area9/qt-byte-runner:desktop .

