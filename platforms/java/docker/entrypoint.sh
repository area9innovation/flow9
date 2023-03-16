#!/bin/bash

set -e

cd /app

xmx="2048m"
if [ -n "$JAVA_XMX" ]; then
  xmx="$JAVA_XMX"
fi

xss="128m"
if [ -n "$JAVA_XSS" ]; then
  xss="$JAVA_XSS"
fi

if [ -z "$JAR" ]; then
  echo "Usage: docker run -e JAR=filename.jar container_name"
  echo ""
  exit 1
fi

# collect all environment variables with flow_ prefix and pass them to the jar
# trying to preserve quoting and stripping the flow_ prefix
flow_args=()
# mapfile -t flow_args < <(printenv | grep "^flow_" | sed 's/flow_\(.*\)\(=\)\(.*\)/\1="\3"/')
mapfile -t flow_args < <(printenv | grep "^flow_" | sed 's/flow_\(.*\)\(=\)\(.*\)/\1=\3/')

# Important for -jar to go after all the args but before --
# Technically, -- is also treated as a parameter and is not required, but it serves as a nice separator.
exec java "-Xmx${xmx}" "-Xss${xss}" \
  $JAVA_ARGS \
  -jar "$JAR" \
  -- \
  "${flow_args[@]}"
