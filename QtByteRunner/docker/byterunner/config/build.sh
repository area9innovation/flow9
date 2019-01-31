#!/bin/bash
cd /flow

qmake QtByteRunner.pro
make -j$(nproc)

