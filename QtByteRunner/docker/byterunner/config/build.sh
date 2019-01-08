#!/bin/bash
cd /flow9/QtByteRunner/bin/linux

qmake ../../QtByteRunner.pro
make -j $(nproc)

