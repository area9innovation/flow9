@echo _____________________________________________
@echo Compile...
@echo _____________________________________________

set FLOWDIR=../../../../
set WASEDIR=../wase/
set TESTDIR=tests/flow/


cd %FLOWDIR%
call flowc wise=%WASEDIR%%TESTDIR% I=%WASEDIR%%TESTDIR% %WASEDIR%%TESTDIR%%1.flow

cd %WASEDIR%
call flowcpp -I .. --batch ../wise/wise.flow -- I=..,../flow9/ %TESTDIR%%1.wise

@echo _____________________________________________
@echo Execute...
@echo _____________________________________________

call wasmer %TESTDIR%%1.wasm

