#!/bin/bash

# Initial compilation with update-incremental=1
echo "=== Initial compilation test10b.flow with update-incremental=1 ==="
flowcpp --batch flow9.flow -- testinc/test10b.flow update-incremental=1 verbose=1

# Change the type alias from int to string
echo ""
echo "=== Changing UserID type alias from int to string in test10a.flow ==="
sed -i 's/UserID : int;/UserID : string;/' testinc/test10a.flow
sed -i 's/id > 0 && id < 1000000/strlen(id) > 0 && strlen(id) < 10/' testinc/test10a.flow

# Recompile without update-incremental to see if changes are detected
echo ""
echo "=== Recompiling test10b.flow without update-incremental ==="
flowcpp --batch flow9.flow -- testinc/test10b.flow verbose=1

# Restore the original file
echo ""
echo "=== Restoring original file ==="
sed -i 's/UserID : string;/UserID : int;/' testinc/test10a.flow
sed -i 's/strlen(id) > 0 && strlen(id) < 10/id > 0 && id < 1000000/' testinc/test10a.flow