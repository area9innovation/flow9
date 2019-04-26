#!/bin/bash
cd /flow9/platforms/qt

# Generate the shaders include file
pushd ../common/cpp/gl-gui/shaders && ./pack.pl
popd

cd bin/linux
qmake -o Makefile ../../QtByteRunner.pro
make -j$(nproc)

