#/bin/sh

DST=~/Library/Application\ Support/Sublime\ Text\ 2/Packages

if [ ! -d "$DST" ]; then
    echo Directory does not exist: $DST
    exit 1
fi
#ls "$DST"
cp -rp Flow Lingo "$DST"
