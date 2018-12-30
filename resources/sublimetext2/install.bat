@echo off
setlocal

set SUBLIME_ROOT=

rem Trying to get it from registry
for /f "usebackq tokens=2 delims=)" %%a in (`reg query HKEY_CURRENT_USER\Software\Classes\Applications\sublime_text.exe\shell\open\command /ve ^| findstr /v HKEY_CURRENT_USER ^| findstr /i sublime`) do (
 call :get_root %%a
)


rem For Sublime Text 3
set SUBLIME_3=%APPDATA%\Sublime Text 3\
if not exist "%PACKAGES%" set PACKAGES=%SUBLIME_3%Packages

set SUBLIME_ROAM=%APPDATA%\Sublime Text 2\

rem For Portable Sublime
if not exist "%PACKAGES%" set PACKAGES=%SUBLIME_ROOT%Data\Packages
rem For installable Sublime
if not exist "%PACKAGES%" set PACKAGES=%SUBLIME_ROAM%Packages

echo Assuming Packages under "%PACKAGES%"


set DEST=%PACKAGES%\Flow\
echo.
echo Installing Flow under %DEST%
if not exist "%DEST%" mkdir "%DEST%"
copy Flow\*.* "%DEST%"


set DEST=%PACKAGES%\Haxe\
echo Installing Haxe under %DEST%
if not exist "%DEST%" mkdir "%DEST%"
copy Haxe\*.* "%DEST%"

set DEST=%PACKAGES%\Lingo\
if not exist "%DEST%" mkdir "%DEST%"
copy Lingo\*.* "%DEST%"

set DEST=%PACKAGES%\SublimeGDB\
if not exist "%DEST%" mkdir "%DEST%"
copy SublimeGDB\*.* "%DEST%"

set DEST=%PACKAGES%\Math\
if not exist "%DEST%" mkdir "%DEST%"
copy Math\*.* "%DEST%"

set LINT=%PACKAGES%\SublimeLinter\lint\
echo.
echo Updating Lint under %LINT%
copy flow.py "%LINT%\flow.py"

copy lingo.py "%LINT%\lingo.py"

rem pause

goto :eof

rem Extracts full path to Sublime
:get_root
if '%1'=='' goto :eof
if not '%SUBLIME_ROOT%'=='' goto :eof
if exist %1 (
 set SUBLIME_ROOT=%~dp1
) else (
 shift
 goto :get_root
)
goto :eof

