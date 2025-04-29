#!/bin/bash

# Compile the orbit grammar
flowcpp --batch tools/mango/mango.flow -- grammar=orbit.mango types=2 typeprefix=Or prefix=orbit_ compile=1 vscode=1 vsname="Orbit" extension=orb

echo "Compilation complete. Run package-vscode.sh to update VS Code plugin."

# Run the packaging script automatically if requested
if [ "$1" = "--package" ]; then
  echo "Running VS Code extension packaging script..."
  ./package-vscode.sh
fi

# Compile the orbit S-expression grammar
cd sexpr
flowcpp --batch tools/mango/mango.flow -- grammar=sexpr.mango types=2 typeprefix=S prefix=sexpr_ compile=1 vscode=1 vsname="SExpr" extension=sexpr
cd ..
