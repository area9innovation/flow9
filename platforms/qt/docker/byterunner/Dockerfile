FROM area9/qt:aqt-5.12.11

# vim and less are just for convenience
RUN apt-get update -y \
  && apt-get install -y --no-install-recommends \
    build-essential \
    libglu1-mesa-dev \
    zlib1g-dev \
    libjpeg8-dev \
    libpng-dev \
    libpulse-dev \
    libglib2.0-dev \
    libasound2 \
    libxdamage1 \
    libxcomposite1 \
    libnss3 \
    libfontconfig1 \
    libxcursor1 \
    libxi6 \
    libxrender1 \
    libxtst6 \
    libfcgi-dev \
    vim less


# This is for convenience so that resulting files will belong to regular user
# instead of root. Will be useless on multi-user systems.
ARG uid=1000
ARG gid=1000
RUN addgroup --gid=${gid} flow \
  && useradd --uid=${uid} \
             --gid=${gid} \
             --no-create-home \
             --home=/flow \
             --shell=/bin/bash \
             flow

# Expecting flow here
USER flow
VOLUME /flow
ENV FLOW="/flow"

WORKDIR /flow/platforms/qt
