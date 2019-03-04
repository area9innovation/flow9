#!/bin/bash
cd /flow

# Generate the shaders include file
pushd gl-gui/shaders && ./pack.pl
popd

cd bin/linux
qmake -o Makefile ../../QtByteRunner.pro
make -j$(nproc)

