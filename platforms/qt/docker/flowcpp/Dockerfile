ARG QT=5.15.2
FROM area9/qt:aqt-${QT}

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    xvfb

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

