FROM area9/qt:aqt-5.12.11

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    libglu1-mesa \
    libasound2 \
    libpulse0 \
    libpulse-mainloop-glib0 \
    libglib2.0-0 \
    libxcomposite1 \
    libfontconfig1 \
    libjpeg8 \
    libpng16-16 \
    libnss3 \
    libxrender1 \
    libxtst6 \
    libxcursor1 \
    libxi6 \
    libxdamage1 \
    xvfb \
    zlib1g

ARG uid=1000
ARG gid=1000
RUN addgroup --gid=${gid} flow \
  && useradd --uid=${uid} \
             --gid=${gid} \
             --no-create-home \
             --home=/flow \
             --shell=/bin/bash \
             flow

COPY --chown=flow:flow flow /flow
COPY --chown=flow:flow xflowcpp /flow/bin/

USER flow
WORKDIR /flow

env FLOW=/flow
env PATH=$PATH:$FLOW/bin

