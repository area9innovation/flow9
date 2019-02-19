@echo off
del %~n1.wasm
call compile-js.bat %*
if exist "%~n1.wasm" (
    node --expose-wasm %~n1.node.js 
)