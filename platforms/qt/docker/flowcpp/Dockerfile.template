# Requires docker >=17.05 for multistage builds
FROM area9/qt:%QT_VERSION% as qt

FROM ubuntu:xenial

# All libs required to run qt byte runner
RUN apt-get update \
  && apt-get install -y \
    ca-certificates \
    libasound2 \
    libdbus-1-3 \
    libegl1-mesa \
    libfontconfig1 \
    libfreetype6 \
    libglib2.0-0 \
    libglu1-mesa \
    libjpeg8 \
    libnspr4 \
    libnss3 \
    libpng12-0 \
    libpulse0 \
    libpulse-mainloop-glib0 \
    libssl1.0.0 \
    libxcomposite1 \
    libxcursor1 \
    libxi6 \
    libxml2 \
    libxrandr2 \
    libxrender1 \
    libxslt1.1 \
    libxss1 \
    libxtst6 \
    xvfb \
    zlib1g

# these are default versions, they are changed in build_image.sh
ARG qt_version=5.9.2
ARG qt_path=/opt/Qt${qt_version}
ARG qt_full_path=${qt_path}/${qt_version}/gcc_64

COPY --from=qt $qt_full_path $qt_full_path

COPY flow /flow
env FLOW=/flow
env PATH=$PATH:$FLOW/bin

