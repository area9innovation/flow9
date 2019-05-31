#!/bin/bash
set -e

docker build \
  -f Dockerfile.ffmpeg \
  -t area9/flowcpp:ffmpeg .

