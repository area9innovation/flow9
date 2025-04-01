#!/bin/bash

# Initial compilation with update-incremental=1
echo "=== Initial compilation test3b.flow with update-incremental=1 ==="
flowcpp --batch flow9.flow -- testinc/test3b.flow update-incremental=1 verbose=1 debug-incremental=1

# Change the constant value (keeping the same name but changing type)
echo ""
echo "=== Changing constant type from int to string in test3a.flow ==="
sed -i 's/constantValue : int = 42;/constantValue : string = "42";/' testinc/test3a.flow
sed -i 's/constantValue : int;/constantValue : string;/' testinc/test3a.flow

# Recompile without update-incremental to see if changes are detected
echo ""
echo "=== Recompiling test3b.flow without update-incremental ==="
flowcpp --batch flow9.flow -- testinc/test3b.flow verbose=1 debug-incremental=1

# Restore the original file
echo ""
echo "=== Restoring original file ==="
sed -i 's/constantValue : string = "42";/constantValue : int = 42;/' testinc/test3a.flow
sed -i 's/constantValue : string;/constantValue : int;/' testinc/test3a.flow
