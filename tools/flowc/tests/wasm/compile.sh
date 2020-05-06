#!/bin/bash

NAME=$(basename -- $1)
FLOW=$NAME.flow
WASM=$NAME.wasm
WASMHOST=$NAME.js

flowc1 file="$FLOW" wasm="$WASM" wasmhost="$WASMHOST" ${@:2}
