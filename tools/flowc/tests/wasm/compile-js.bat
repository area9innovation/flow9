set FL=%~n1.flow
set WASM=%~n1.wasm
set WASMHOST=%~n1.node.js
set WASMLISTING=%~n1.lst
shift
call flowc server=0 incremental=0 file=%FL% wasm=%WASM% wasmhost=%WASMHOST% wasmnodejs=1 wasmlisting=%WASMLISTING% %*
