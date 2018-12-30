set flow_file=%1
set js_file=%2
call flowcompiler file=%flow_file% es6=%js_file% readable=1
nwjs\nw . %js_file%
