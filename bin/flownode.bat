@echo off
set flow_file=%1
set js_file=%~n1.js
call flowc1 %flow_file% es6=%js_file% nodejs=1 debug=1

REM A trick to ignore the file itself, but send the rest of the args
node --max-old-space-size=4096 %js_file% ignoreparameter=%*
