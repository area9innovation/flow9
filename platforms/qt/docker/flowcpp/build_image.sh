#!/bin/bash
set -e

export QT_VERSION=5.12.0

if [ -z "$FLOW" ]; then
    echo "\$FLOW is not defined, can't find QtByteRunner to use"
    echo "Use git to clone flow repo and then point \$FLOW environment variable to it with export \$FLOW ..."
    exit 1
fi

echo "Goind to use ${FLOW}/QtByteRunner/bin/linux/QtByteRunner"
echo 

# Consecutive docker cp creates weird folder structure if some files already exist.
# So performing clean up and cd to script folder for safety
cd $(dirname $(readlink -f $0))
if [ -e flow ]; then
  echo "Want to remove `pwd`/flow"
  echo "Agree if path above is correct, otherwise CTRL+C now"
  rm -rI flow
fi

mkdir -p flow/QtByteRunner/bin/linux
mkdir -p flow/bin
cp ${FLOW}/QtByteRunner/bin/linux/QtByteRunner flow/QtByteRunner/bin/linux/QtByteRunner
cp ${FLOW}/bin flow/ -r

sed "s|%QT_VERSION%|${QT_VERSION}|" Dockerfile.template > Dockerfile

docker build \
  --build-arg qt_version=$QT_VERSION \
  -t area9/flowcpp .

