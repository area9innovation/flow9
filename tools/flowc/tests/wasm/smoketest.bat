@echo off
call :cleanup

set FILE_LIST=test28 test28-fallbacks test32 test34 test_md5 test5
REM set FILE_LIST=test28 test28-fallbacks test32 test34 test_md5 test5

echo ***********************************************************
echo testing: %FILE_LIST%

for %%i in (%FILE_LIST%) do call :compile %%i

echo ***********************************************************

for %%i in (%FILE_LIST%) do call :run_test %%i

call :cleanup

echo ********** Finished ********************

exit /b

:compile
echo ************ Compiling %1 ******************
call compile-js.bat %1
if not exist %1.wasm goto :compilation_failed
exit /b

:compilation_failed
echo COMPILATION OF %1 FAILED!!!!!
exit /b

:run_test
echo ********** Running %1... ********************
node --expose-wasm %1.node.js
exit /b

:cleanup
del /q test*.js test*.lst test*.wasm test*.wat test*.debug test*.bytecode test*.html >nul 2>&1
exit /b
