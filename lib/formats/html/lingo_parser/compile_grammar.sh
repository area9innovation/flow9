#!/bin/bash

# Run from the current directory
cd ../../..

flowcpp --batch lingo/pegcode/pegcompiler.flow -- flowparser=formats/html/lingo_parser/parser.flow flowparserast=formats/html/lingo_parser/ast.flow file=formats/html/lingo_parser/html.lingo prefix_rules=html
