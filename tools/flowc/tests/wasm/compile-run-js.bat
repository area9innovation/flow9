@echo off
del %~n1.wasm
call compile-js.bat %1 %2 %3
if exist "%~n1.wasm" (
    node --expose-wasm %~n1.node.js 
)