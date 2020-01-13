#!/bin/bash

# Includes script-based language letters metrics (only implemented for Arabic) into fontconfig.json
# to make them available after compilation in MetaApps when working in browser (JS target).

SCRIPT_DIR=$( cd "$( dirname "$0" )" && pwd -P )
BASE_DIR=$( cd "$( dirname "$SCRIPT_DIR" )" && pwd -P )

pushd $BASE_DIR/resources/webfonts/src
npm install
popd
node $BASE_DIR/resources/webfonts/src/main.js ${1:-.}
