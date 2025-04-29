#!/bin/bash

# Initial compilation with update-incremental=1
echo "=== Initial compilation test6b.flow with update-incremental=1 ==="
flowcpp --batch flow9.flow -- testinc/test6b.flow update-incremental=1 verbose=1

# Change the union definition (adding a new variant)
echo ""
echo "=== Adding a new variant to DataType union in test6a.flow ==="
sed -i 's/DataType ::= IntData, StringData;/DataType ::= IntData, StringData, BoolData;/' testinc/test6a.flow
sed -i '/StringData(value: string);/a\	BoolData(value: bool);' testinc/test6a.flow
sed -i '/StringData(v): v;/a\		BoolData(v): b2s(v);' testinc/test6a.flow

# Recompile without update-incremental to see if changes are detected
echo ""
echo "=== Recompiling test6b.flow without update-incremental ==="
flowcpp --batch flow9.flow -- testinc/test6b.flow verbose=1

# Restore the original file
echo ""
echo "=== Restoring original file ==="
sed -i 's/DataType ::= IntData, StringData, BoolData;/DataType ::= IntData, StringData;/' testinc/test6a.flow
sed -i '/BoolData(value: bool);/d' testinc/test6a.flow
sed -i '/BoolData(v): b2s(v);/d' testinc/test6a.flow