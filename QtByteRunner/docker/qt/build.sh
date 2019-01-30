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
#MYSQL_TAR=mysql-5.6.36-linux-glibc2.5-x86_64.tar.gz

#DOWNLOADS=downloads
#mkdir -p $DOWNLOADS
#pushd $DOWNLOADS

#if [ ! -f $MYSQL_TAR ]; then
#  wget https://dev.mysql.com/get/Downloads/MySQL-5.6/$MYSQL_TAR
#fi
#popd

sed "s|%QT_VERSION%|${QT_VERSION}|" Dockerfile.build.template > Dockerfile.build
docker build \
  --build-arg qt_version=$QT_VERSION \
  -f Dockerfile.build \
  -t area9/qt:${QT_VERSION}-full .

sed "s|%QT_VERSION%|${QT_VERSION}|" Dockerfile.trimmed.template > Dockerfile.trimmed
docker build \
  --build-arg qt_version=$QT_VERSION \
  -f Dockerfile.trimmed \
  -t area9/qt:${QT_VERSION} .

