# Builds QtByteRunner against the Qt 6 packaged by Ubuntu, without installing
# qmake and a toolchain on the host. The checkout is mounted, not copied; see
# build.sh next to this file.
#
# Pinned to noble on purpose: its Qt 6.4 is the floor. A Qt binary loads on the
# same or a newer Qt minor, never an older one, so a runner built here starts
# on Ubuntu 24.04 and newer, while one built against a newer Qt would not start
# on 24.04. 22.04 packages Qt 6.2, which is too old. Other distributions also
# need noble's glibc, libstdc++ and libjpeg.so.8; see ../readme.md.
FROM ubuntu:noble

# The Qt list mirrors doc/linux.markdown and bin/setup-linux - keep them in step.
# perl is for the shaders pack.pl. libqt6sql6-mysql is not needed to build, it
# is there so the built runner can be tried in the container with --batch.
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    perl \
    qt6-base-dev \
    qt6-base-dev-tools \
    qt6-declarative-dev \
    qt6-multimedia-dev \
    qt6-webchannel-dev \
    qt6-websockets-dev \
    qt6-webengine-dev \
    qt6-positioning-dev \
    libqt6sql6-mysql \
    libgl-dev \
    libglu1-mesa-dev \
    zlib1g-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype-dev \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# No user is baked in: build.sh runs the container as the calling user, so the
# build output belongs to whoever ran it. HOME has to be writable for anyone.
ENV HOME=/tmp
ENV FLOW=/flow
WORKDIR /flow
