# REQUIRES DOCKER >= 17.05 for multi-stage builds
# This is meant to create qt installation for use with other images.
# Use FROM and then COPY to get QT out of resulting image. You'll have to manually
# adjust PATH and probably ldconfig depending on your needs.

# When QT version changes, you'll have to adjust it throught this file and in
# config/install.qs too.

# You may want to read through and alter some things first depending on your goals.
FROM area9/qt:%QT_VERSION%-install as build

# packages are in alphabetical order
# build-essential libmysqlclient-dev libssl-dev are for mysql driver
RUN apt-get update \
  && apt-get install -y \
    build-essential \
    libmysqlclient-dev \
    libssl-dev

ARG qt_version=5.9.2
ARG qt_path=/opt/Qt${qt_version}
ARG qt_full_path=${qt_path}/${qt_version}/gcc_64
ARG qt_src_path=${qt_path}/${qt_version}/Src

RUN echo "Using version ${qt_version}"

WORKDIR ${qt_src_path}/qtbase/src/plugins/sqldrivers
COPY downloads/mysql-5.6.36-linux-glibc2.5-x86_64.tar.gz mysql.tar.gz

COPY config/build_mysql_driver.sh ${qt_src_path}/qtbase/src/plugins/sqldrivers
RUN ./build_mysql_driver.sh $qt_src_path $qt_full_path

FROM ubuntu:xenial
COPY --from=build ${qt_path} ${qt_path}
ENV PATH="${PATH}:${qt_full_path}/bin"

