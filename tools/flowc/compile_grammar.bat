@echo off
pushd .
cd ../..
call flowcpp --batch lingo/pegcode/pegcompiler.flow -- file=tools/flowc/flow.lingo flowparser=tools/flowc/flow_parser flowparserast=tools/flowc/flow_ast.flow flowparserdebug=1 >out.txt
popd
