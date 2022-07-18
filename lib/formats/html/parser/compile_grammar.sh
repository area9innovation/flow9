#!/bin/bash

# Run from the current directory
cd ../../..

flowcpp --batch lingo/pegcode/pegcompiler.flow -- flowparser=formats/html/parser/parser.flow flowparserast=formats/html/parser/ast.flow file=formats/html/parser/html.lingo prefix_rules=html
