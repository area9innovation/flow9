#!/bin/bash

# Compile the orbit grammar
flowcpp --batch tools/mango/mango.flow -- grammar=orbit.mango types=2 typeprefix=Or prefix=orbit_ compile=1 vscode=1 vsname="Orbit"

echo "Compilation complete. Run package-vscode.sh to update VS code plugin."

# Run the packaging script automatically if requested
if [ "$1" = "--package" ]; then
  echo "Running VS Code extension packaging script..."
  ./package-vscode.sh
fi
