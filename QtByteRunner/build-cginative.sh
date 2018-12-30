#!/bin/sh

qmake-qt4 QtNativeCgi.pro
nice make all
strip -d QtNativeCgi
