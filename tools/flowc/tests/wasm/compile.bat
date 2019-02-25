set FL=%~n1.flow
set WASM=%~n1.wasm
set WASMHOST=%~n1.js
shift
call flowc server=0 incremental=0 verify-types=1 file=%FL% wasm=%WASM% wasmhost=%WASMHOST% %*