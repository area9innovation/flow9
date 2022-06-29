#!/bin/bash
set -e

registry=""
if [ -n "$1" ]; then
  registry="$1/"
fi

docker build \
  -t "${registry}area9/flowjar" .

