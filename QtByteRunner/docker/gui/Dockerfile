FROM area9/flowcpp

# QT is weird. And having incompatible versions of openssl on one machine is hard.
# This image tries to dockerize gui flowcpp so that libssl from the container will be used instead.

# It will only work on Ubuntu. Additionally, if you have a graphics card, drivers have to match
# between host and container, so you may have to replace nvidia-384 with whatever you have.
# For that reason it's best not to push that image to the registry. It's too machine specific.
RUN export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get install -yq --no-install-recommends libasound2 libdbus-1-3 libegl1-mesa libfontconfig1 \
   libfreetype6 libglib2.0-0 \
   libglu1-mesa libjpeg8 libnspr4 libnss3 libpng12-0 libpulse0 libxcomposite1 \
   libxcursor1 libxi6 libxml2 libxrender1 libxslt1.1 libxtst6 zlib1g nvidia-384

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

RUN chown ${uid}:${gid} -R /flow

USER flow
ENV HOME /flow

CMD /flow9/bin/flowcpp
