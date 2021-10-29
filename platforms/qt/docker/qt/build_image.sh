#!/bin/bash

registry=""
if [ -n "$1" ]; then
  registry="$1/"
fi

docker build -t "${registry}area9/qt:aqt-5.12.11" .

