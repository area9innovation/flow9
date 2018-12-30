#!/bin/bash
cd /flow/QtByteRunner/bin/linux

qmake ../../QtByteRunner.pro
make -j $(nproc)

