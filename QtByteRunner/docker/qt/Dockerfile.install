# REQUIRES DOCKER >= 17.05 for multi-stage builds
# This is meant to create qt installation for use with other images.
# Use FROM and then COPY to get QT out of resulting image. You'll have to manually
# adjust PATH and probably ldconfig depending on your needs.

# When QT version changes, you'll have to adjust it throught this file and in
# config/install.qs too.

# You may want to read through and alter some things first depending on your goals.
FROM ubuntu:bionic as build

# packages are in alphabetical order
# dbus, fontconfig and xvfb are required to run the installer
# libglib and libglu are required to run it without crashes.
RUN apt-get update \
  && apt-get install -y \
    build-essential \
    ca-certificates \
    libdbus-1-3 \
    libfontconfig1 \
    libglib2.0-0 \
    libglu1-mesa \
    libglu1-mesa-dev \
    mesa-common-dev \
    xvfb

# Changing these only works for minor version upgrades.
# 5.7 to 5.9 for example will fail.
ARG qt_version=5.9.2
ARG qt_path=/opt/Qt${qt_version}
ARG qt_full_path=${qt_path}/${qt_version}/gcc_64
ARG qt_src_path=${qt_path}/${qt_version}/Src

RUN echo ${qt_version}

COPY downloads/qt-opensource-linux-x64-${qt_version}.run /root/installer

# Mind that installation location is compiled into binaries through rpath
# and thus have to be the same between build and running environments unless
# you change rpath yourself.
COPY config/install.qs /root/install.qs

WORKDIR /root
# somehow it does not work without verbose!?
RUN mkdir ${qt_path} \
  && chmod u+x installer \
  && sed -i "s|%INSTALL_PATH%|${qt_path}|" install.qs \
  && xvfb-run ./installer --verbose --script install.qs \
  && rm -rf ${qt_path}/Docs \
  && rm -rf ${qt_path}/Examples \
  && rm -rf ${qt_path}/Tools

ENV PATH="${PATH}:${qt_full_path}/bin"

