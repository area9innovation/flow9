@echo off

set BASE_DIR=%~dp0..\..

echo.
echo Compiling 'Flowc_lsp'
echo =====================
echo.

pushd %BASE_DIR%

if exist platforms\java\com\area9innovation\flow\*.class del platforms\java\com\area9innovation\flow\*.class
SET PATH=%JAVA_HOME%\bin;%PATH%
call flowc1 jar=tools\flowc_lsp\flowc_lsp.jar tools\flowc_lsp\flowc_lsp.flow

java bin\check_java_version.java
if errorlevel 1 pause

popd
