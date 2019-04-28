#!/bin/bash
set -e

if [ -z "$FLOW" ]; then
    echo "\$FLOW is not defined, can't find sources to use"
    echo "Use git to clone flow repo and then point \$FLOW environment variable to it with export \$FLOW ..."
    exit 1
fi

export QT_VERSION=5.12.0
export SRC="$FLOW/platforms/common"
export QT="$FLOW/platforms/qt"

sed "s|%QT_VERSION%|${QT_VERSION}|" Dockerfile.template > Dockerfile

rm -rf qbr/
mkdir -p qbr/platforms
rsync -art "$QT/" "qbr/platforms/qt/" --exclude bin --exclude docker
rsync -art "$SRC/" "qbr/platforms/common/" --exclude haxe
# we've excluded bin above to speed things up, so creating it manually here
mkdir -p qbr/platforms/qt/bin/linux

docker build \
  --build-arg qt_version=$QT_VERSION \
  -t area9/qt-byte-runner:desktop .

