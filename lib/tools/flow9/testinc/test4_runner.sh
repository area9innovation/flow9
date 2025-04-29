#!/bin/bash

# Initial compilation with update-incremental=1
echo "=== Initial compilation test4c.flow with update-incremental=1 ==="
flowcpp --batch flow9.flow -- testinc/test4c.flow update-incremental=1 verbose=1

# Modify the base type definition
echo ""
echo "=== Changing base type definition (adding field) in test4a.flow ==="
sed -i 's/BaseStruct(id: int);/BaseStruct(id: int, name: string);/' testinc/test4a.flow

# Recompile without update-incremental to see if all dependent files are recompiled
echo ""
echo "=== Recompiling test4c.flow without update-incremental ==="
flowcpp --batch flow9.flow -- testinc/test4c.flow verbose=1

# Restore the original file
echo ""
echo "=== Restoring original file ==="
sed -i 's/BaseStruct(id: int, name: string);/BaseStruct(id: int);/' testinc/test4a.flow