ARG QT=5.12.11
ARG QT_MODULES=qtwebengine 
ARG QT_HOST=linux
ARG QT_TARGET=desktop
ARG QT_ARCH=gcc_64
ARG QT_PATH="/opt/Qt${QT}/${QT}/${QT_ARCH}"
FROM ubuntu:focal as base
ARG QT
ARG QT_MODULES
ARG QT_HOST
ARG QT_TARGET
ARG QT_ARCH
ARG QT_PATH

RUN apt-get -y update \
  && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    libglib2.0-0 \
    libmysqlclient21 \
    python3-pip

# using community qt installer because default one is not very scriptable
RUN pip3 install aqtinstall

RUN aqt install-qt --outputdir /opt/Qt${QT} ${QT_HOST} ${QT_TARGET} ${QT} ${QT_ARCH} -m ${QT_MODULES}

# this is to allow using qmake and qt libraries in derived images
RUN echo "/opt/Qt${QT}/${QT}/${QT_ARCH}/lib" > /etc/ld.so.conf.d/qt.conf \
  && ldconfig

ENV PATH="${QT_PATH}/bin:${PATH}"

# we need qt installed to build mysql driver
FROM base as mysql
ARG QT
ARG QT_MODULES
ARG QT_HOST
ARG QT_TARGET
ARG QT_ARCH
ARG QT_PATH
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    libmysqlclient-dev \
    libglib2.0-dev \
    libssl-dev

RUN aqt install-src linux desktop "${QT}" -O /src

# add ../lib to RPATH to make it easier to use runner with a subset of QT libraries
RUN cd /src/${QT}/Src/qtbase/src/plugins/sqldrivers \
  && qmake \
  && cd mysql \
  && qmake 'QMAKE_RPATHDIR += "../lib"' \
  && make

# back to base
FROM base
ARG QT
ARG QT_PATH

COPY --from=mysql /src/${QT}/Src/qtbase/src/plugins/sqldrivers/plugins/sqldrivers/libqsqlmysql.so /${QT_PATH}/plugins/sqldrivers/

