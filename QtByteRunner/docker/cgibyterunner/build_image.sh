#!/bin/bash
export QT_VERSION=5.10.0

sed "s|%QT_VERSION%|${QT_VERSION}|" Dockerfile.template > Dockerfile
docker build \
  --build-arg qt_version=$QT_VERSION \
  -t area9/qt-byte-runner:cgi .

