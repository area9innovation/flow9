#!/bin/bash

cd `dirname $0`

function download() {
    [ -d $1 ] || git clone https://android.googlesource.com/platform/external/$1.git
}

download freetype
download jpeg
download libpng
