@echo off
pushd .
cd ../../..
call flowcpp lingo/pegcode/pegcompiler.flow -- file=tools/flowc/unify/unify.lingo out=tools/flowc/unify/unify_pegops.flow parsetype=Unify
popd
pause
