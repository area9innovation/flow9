#!/bin/bash

# Initial compilation with update-incremental=1
echo "=== Initial compilation test8b.flow with update-incremental=1 ==="
flowcpp --batch flow9.flow -- testinc/test8b.flow update-incremental=1 verbose=1

# Change function return type from int to string
echo ""
echo "=== Changing function return type from int to string in test8a.flow ==="
sed -i 's/getValue() -> int;/getValue() -> string;/' testinc/test8a.flow
sed -i 's/getValue() -> int {/getValue() -> string {/' testinc/test8a.flow
sed -i 's/42/"42"/' testinc/test8a.flow

# Recompile without update-incremental to see if changes are detected
echo ""
echo "=== Recompiling test8b.flow without update-incremental ==="
flowcpp --batch flow9.flow -- testinc/test8b.flow verbose=1

# Restore the original file
echo ""
echo "=== Restoring original file ==="
sed -i 's/getValue() -> string;/getValue() -> int;/' testinc/test8a.flow
sed -i 's/getValue() -> string {/getValue() -> int {/' testinc/test8a.flow
sed -i 's/"42"/42/' testinc/test8a.flow