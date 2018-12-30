#!/bin/bash
pushd .
cd ../../..
flowcpp lingo/pegcode/pegcompiler.flow -- file=lib/formats/uri2/uri2.lingo flowparser=lib/formats/uri2/uri2_parser flowparserast=lib/formats/uri2/uri2_ast.flow > out.txt
popd
