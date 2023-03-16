#!/bin/bash
set -e

registry=""
if [ -n "$1" ]; then
  registry="$1/"
fi

if [ -z "$FLOW" ]; then
    echo "\$FLOW is not defined, can't find QtByteRunner to use"
    echo "Use git to clone flow repo and then point \$FLOW environment variable to it with export \$FLOW ..."
    exit 1
fi

echo "Goind to use ${FLOW}/platforms/qt/bin/linux/QtByteRunner"
echo 

# Consecutive docker cp creates weird folder structure if some files already exist.
# So performing clean up and cd to script folder for safety
cd "$(dirname "$(readlink -f "$0")")"
if [ -e flow ]; then
  echo "Want to remove $(pwd)/flow"
  echo "Agree if path above is correct, otherwise CTRL+C now"
  rm -rI flow
fi

mkdir -p flow/platforms/qt/bin/linux
mkdir -p flow/bin
mkdir -p flow/resources/fonts
cp "${FLOW}/platforms/qt/bin/linux/QtByteRunner" flow/platforms/qt/bin/linux/QtByteRunner
cp "${FLOW}/bin" flow/ -r
cp "${FLOW}/resources/fonts" flow/ -r

docker build \
  -t "${registry}area9/flowcpp" .

