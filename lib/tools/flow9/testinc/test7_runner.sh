#!/bin/bash

# Initial compilation with update-incremental=1
echo "=== Initial compilation test7b.flow with update-incremental=1 ==="
flowcpp --batch flow9.flow -- testinc/test7b.flow update-incremental=1 verbose=1

# Change function parameter type from int to double
echo ""
echo "=== Changing function parameter type from int to double in test7a.flow ==="
sed -i 's/processValue(x: int) -> string;/processValue(x: double) -> string;/' testinc/test7a.flow
sed -i 's/processValue(x: int) -> string {/processValue(x: double) -> string {/' testinc/test7a.flow
sed -i 's/i2s(x)/d2s(x)/' testinc/test7a.flow

# Recompile without update-incremental to see if changes are detected
echo ""
echo "=== Recompiling test7b.flow without update-incremental ==="
flowcpp --batch flow9.flow -- testinc/test7b.flow verbose=1

# Restore the original file
echo ""
echo "=== Restoring original file ==="
sed -i 's/processValue(x: double) -> string;/processValue(x: int) -> string;/' testinc/test7a.flow
sed -i 's/processValue(x: double) -> string {/processValue(x: int) -> string {/' testinc/test7a.flow
sed -i 's/d2s(x)/i2s(x)/' testinc/test7a.flow