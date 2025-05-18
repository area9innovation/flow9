#!/bin/bash

# Initial compilation with update-incremental=1
echo "=== Initial compilation test2b.flow with update-incremental=1 ==="
flowcpp --batch flow9.flow -- testinc/test2b.flow update-incremental=1 verbose=1

# Modify the type definition
echo ""
echo "=== Changing type definition (adding a field) === in test2a.flow"
sed -i 's/SimpleStruct(value: int);/SimpleStruct(value: int, name: string);/' testinc/test2a.flow

# Recompile without update-incremental to see if changes are detected
echo ""
echo "=== Recompiling test2b.flow without update-incremental ==="
flowcpp --batch flow9.flow -- testinc/test2b.flow verbose=1

# Restore the original file
echo ""
echo "=== Restoring original file ==="
sed -i 's/SimpleStruct(value: int, name: string);/SimpleStruct(value: int);/' testinc/test2a.flow