del json_pegop.flow
call flowcpp lingo/pegcode/pegcompiler.flow -- "file=../../../lib/formats/json/json.lingo" out=json_pegop.flow
call flowcpp lingo/pegcode/pegcompiler.flow -- "file=json.lingo,strictjson.lingo" out=json_strict_pegop.flow
pause
