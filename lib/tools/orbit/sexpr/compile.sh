#!/bin/bash

# Compile the S-expression grammar
flowcpp --batch ../../mango/mango.flow -- grammar=sexpr.mango types=2 typeprefix=S prefix=sexpr_ compile=1 vscode=1 vsname="S-Expression" extension=sexp

echo "Compilation complete. Run package-vscode.sh to update VS Code plugin."

# Run the packaging script automatically if requested
if [ "$1" = "--package" ]; then
  echo "Running VS Code extension packaging script..."
  ./package-vscode.sh
fi