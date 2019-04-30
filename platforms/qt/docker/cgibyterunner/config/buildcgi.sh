#!/bin/bash
set -e

# prepare dist
cd /flow/platforms/qt

# copy libraries required by mysql driver and driver itself
mkdir -p bin/cgi/linux/sqldrivers
mkdir -p bin/cgi/linux/lib
cp $QT_FULL_PATH/plugins/sqldrivers/* bin/cgi/linux/sqldrivers/
cp $QT_FULL_PATH/plugins/lib/* bin/cgi/linux/lib/

cp -L \
   /usr/lib/libfcgi.so.0 \
   $QT_FULL_PATH/lib/libQt5Sql.so.5 \
   $QT_FULL_PATH/lib/libQt5Network.so.5 \
   $QT_FULL_PATH/lib/libQt5Core.so.5 \
   bin/cgi/linux/lib/

qmake QtByteRunnerCgi.pro
make -j$(nproc)
mv QtByteRunner.fcgi bin/cgi/linux/ 

