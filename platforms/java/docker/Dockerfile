FROM openjdk:18-slim

# This container can be used as is or as base for flow applications
# compiled into jar files.

# curl is nice to have for healthchecks.
# procps is nice to have to autorestart the java process during development.
RUN apt-get update \
  && apt-get install curl procps -y

# using non root user
RUN useradd -s /bin/bash --uid 1000 app

COPY entrypoint.sh /usr/local/bin/entrypoint
COPY passthrough.sh /usr/local/bin/passthrough

# need to chown for non root user to have access
RUN mkdir /app \
  && chown app:app /app

USER app

CMD ["entrypoint"]

ENTRYPOINT ["passthrough"]
