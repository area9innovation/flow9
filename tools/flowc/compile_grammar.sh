#!/bin/bash
pushd .
cd ../..
flowcpp --batch lingo/pegcode/pegcompiler.flow -- file=tools/flowc/flow.lingo flowparser=tools/flowc/flow_parser flowparserast=tools/flowc/flow_ast.flow > out.txt
popd
