#!/bin/bash

echo "When switching between QT versions, you have to manually clean up downloads folder."

# We can only hope that adjusting versions here will be enough to upgrade
# QT. Too many variables are at play
# - url of the installer may change
# - names of QT libraries may change
# - installer may start putting QT into different folder internally
# - Some libraries may become deprecated and get removed
# - libmysqlclient may get fixed rendering manual mysql driver compiling obsolete
QT_VERSION=5.12.0
QT_MAJOR_VERSION=5.12
QT_INSTALLER=qt-opensource-linux-x64-${QT_VERSION}.run

DOWNLOADS=downloads
mkdir -p $DOWNLOADS
pushd $DOWNLOADS

if [ ! -f $QT_INSTALLER ]; then
  wget http://download.qt.io/archive/qt/$QT_MAJOR_VERSION/$QT_VERSION/$QT_INSTALLER 
fi

popd

docker build \
  --build-arg qt_version=$QT_VERSION \
  -f Dockerfile.install \
  -t area9/qt:${QT_VERSION}-install .

