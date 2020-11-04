@echo off
set flow_file=%1
set js_file=%~n1.js
call flowc1 %flow_file% es6=%js_file% nodejs=1

REM A trick to ignore the file itself, but send the rest of the args
node %js_file% ignoreparameter=%*
