#!/bin/bash
set -e

# Not doing clean up because it's multi-stage build and this stage we abandon.
# QMAKE_RPATHDIR adds additional folder to make it easier to use sqldrivers next
# to the actual app that needs them. Quotes are important.
# List of libs is from ldd minus everything glibc
# Note that libmysqlclient is dynamically linked so we bundle the library too.
qt_src_path="$1"
qt_full_path="$2"

cd ${qt_src_path}/qtbase/src/plugins/sqldrivers

# setting up rpath to bundle the driver separetely from qt
qmake 'QMAKE_RPATHDIR += "../lib"'
make
# QT has invented a perversive system of json configuration inheriting from each
# other and using tools to figure out which mysql library to include. I don't 
# want to learn it, I just want a statically compiled driver.
# So abusing the fact that make above has created mysql/Makefile and replacing
# the libraries in it manually.

# This is done because there is a bug in recent versions of mysqlclient that 
# causes segfault on repeated connections to the database. It is still present in ubuntu 18.
tar xzf mysql.tar.gz
cp mysql-5.6.36-linux-glibc2.5-x86_64/lib/libmysqlclient.a mysql/
rm -rf mysql-5.6.36-linux-glibc2.5-x86_64
rm mysql.tar.gz

# comment above and uncomment below to try os provided sql
# taking os provided static mysql lib
#cp /usr/lib/x86_64-linux-gnu/libmysqlclient.a mysql/
# There's no test case, just try to open and close DB connection twice in succession.

sed -i 's/-lmysqlclient /libmysqlclient.a -ldl -lpthread -lz/' mysql/Makefile
pushd mysql
make clean
make
popd

cp ${qt_src_path}/qtbase/src/plugins/sqldrivers/plugins/sqldrivers/libqsqlmysql.so ${qt_full_path}/plugins/sqldrivers/libqsqlmysql.so

cd ${qt_full_path}/plugins/sqldrivers \

# This is also to bundle the driver without qt
mkdir ../lib
cp -L \
  /lib/x86_64-linux-gnu/libgcc_s.so.1 \
  /lib/x86_64-linux-gnu/libz.so.1 \
  ${qt_full_path}/lib/libicudata.so.56 \
  ${qt_full_path}/lib/libicui18n.so.56 \
  ${qt_full_path}/lib/libicuuc.so.56 \
  ${qt_full_path}/lib/libQt5Core.so.5 \
  ${qt_full_path}/lib/libQt5Sql.so.5 \
  /usr/lib/x86_64-linux-gnu/libglib-2.0.so.0 \
  /usr/lib/x86_64-linux-gnu/libgthread-2.0.so.0 \
  /usr/lib/x86_64-linux-gnu/libstdc++.so.6 \
  ../lib

