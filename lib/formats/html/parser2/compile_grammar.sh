#!/bin/bash

# Run from the current directory
cd ../../..

gringo file=formats/html/parser2/html.gringo compile=1 types=1 type-prefix=PlainHtml master-type=PlainHtmlAst