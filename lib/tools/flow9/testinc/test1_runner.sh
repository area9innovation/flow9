#!/bin/bash

# Initial compilation with update-incremental=1
echo "=== Initial compilation test1b.flow with update-incremental=1 ==="
flowcpp --batch flow9.flow -- testinc/test1b.flow update-incremental=1 verbose=1

# Modify the function name
echo ""
echo "=== Changing function name from 'originalFunction' to 'renamedFunction' in test1a.flow ==="
sed -i 's/originalFunction/renamedFunction/g' testinc/test1a.flow
echo ""

# Recompile without update-incremental to see if changes are detected
echo ""
echo "=== Recompiling test1b.flow without update-incremental ==="
flowcpp --batch flow9.flow -- testinc/test1b.flow verbose=1

# Restore the original file
echo ""
echo "=== Restoring original file ==="
sed -i 's/renamedFunction/originalFunction/g' testinc/test1a.flow