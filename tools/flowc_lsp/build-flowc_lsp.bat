@echo off

set BASE_DIR=%~dp0

echo.
echo Compiling 'Flowc_lsp'
echo =====================
echo.

pushd %BASE_DIR%
call flowc1 jar=flowc_lsp.jar flowc_lsp.flow
popd
