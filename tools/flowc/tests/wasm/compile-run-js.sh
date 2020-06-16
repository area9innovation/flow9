#!/bin/bash

NAME=$(basename -- $1)
FLOW=$NAME.flow
WASM=$NAME.wasm
WASMHOST=$NAME.js

if [ -f "$WASM" ]; then
	rm $WASM
fi

bash compile-js.sh $@

if [ -f $WASM ]; then
	node --expose-wasm $NAME.node.js 
fi
