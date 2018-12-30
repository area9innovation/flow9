@ECHO OFF
set SECONDARYPATH=c:\flowapps

@%~dp0..\flowtools\bin\windows\flow.exe --root . -I %~dp0..\lib  -I %SECONDARYPATH% --sublime %1
