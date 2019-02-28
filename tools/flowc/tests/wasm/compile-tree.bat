@echo off
REM This batch will compile flow file and prints AST to console.
REM All outputs performs to appropriate [name]_out.txt file
call compile.bat %* wasmast=%1_out.txt 
echo Done