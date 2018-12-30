@echo off
REM This batch will compile flow file and prints AST to console.
REM All outputs performs to appropriate [name]_out.txt file
call flowc server=0 file=%1.flow wasm=%1 wasmhost=%1.html dce=0 wasmast=%1_out.txt
echo Done