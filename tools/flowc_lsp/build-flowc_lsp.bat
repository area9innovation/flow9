@echo off

set BASE_DIR=%~dp0..\..

echo.
echo Compiling 'Flowc_lsp'
echo =====================
echo.

pushd %BASE_DIR%
SET PATH=%JAVA_HOME%\bin;%PATH%
call flowc1 jar=tools\flowc_lsp\flowc_lsp.jar tools\flowc_lsp\flowc_lsp.flow
popd
