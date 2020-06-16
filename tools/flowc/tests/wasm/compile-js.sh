#!/bin/bash

NAME=$(basename -- $1)
FLOW=$NAME.flow
WASM=$NAME.wasm
WASMHOST=$NAME.node.js
WASMLISTING=$NAME.lst

flowc1 file="$FLOW" wasm="$WASM" wasmhost="$WASMHOST" wasmnodejs=1 wasmlisting="$WASMLISTING" ${@:2}
