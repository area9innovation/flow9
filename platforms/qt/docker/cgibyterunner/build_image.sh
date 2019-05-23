#!/bin/bash
set -e

export QT_VERSION=5.12.0
export QT="$FLOW/platforms/qt"
export SRC="$FLOW/platforms/common"

rm -rf qbr/
mkdir -p qbr/platforms
rsync -art "$QT/" "qbr/platforms/qt/" --exclude bin --exclude docker
rsync -art "$SRC/" "qbr/platforms/common/" --exclude haxe
# we've excluded bin above to speed things up, so creating it manually here
mkdir -p qbr/platforms/qt/bin/cgi/linux

sed "s|%QT_VERSION%|${QT_VERSION}|" Dockerfile.template > Dockerfile
docker build \
  --build-arg qt_version=$QT_VERSION \
  -t area9/qt-byte-runner:cgi .

