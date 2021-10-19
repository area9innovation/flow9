#!/bin/bash
echo "Usage:"
echo "./run.sh absolute/path/to/compile/bytecode"

docker run --rm \
   -v $1:/flow/runme.bc \
   --name flow9 \
   -w /flow \
   -it area9/flowcpp \
   flowcpp --batch runme.bc

