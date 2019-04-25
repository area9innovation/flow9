#!/bin/bash

docker run -it --rm \
  --network=host \
  -e "DISPLAY=unix:0.0" \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v $FLOW:/flow \
  --privileged \
  area9/flowcpp:gui $1

