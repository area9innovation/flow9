@echo off
set IRFAN=%~dp0..\QtByteRunner\bin\fontconvertor\\i_view32.exe
pushd .
cd %1
"%IRFAN%" %2 /convert=%3
popd
