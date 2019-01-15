wat2wasm --debug-names %~n1.wat -o %~n1.wasm
if exist "%~n1.wasm" (
    node --expose-wasm %~n1.node.js 
)
