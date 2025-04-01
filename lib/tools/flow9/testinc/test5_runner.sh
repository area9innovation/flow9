#!/bin/bash

# Initial compilation with update-incremental=1
echo "=== Initial compilation test5b.flow with update-incremental=1 ==="
flowcpp --batch flow9.flow -- testinc/test5b.flow update-incremental=1 verbose=1

# Modify the polymorphic container type
echo ""
echo "=== Changing polymorphic type (adding extra type parameter) in test5a.flow ==="
sed -i 's/Container<?> ::= Box<?>, Empty;/Container<?, ??> ::= Box<?>, NonEmpty<??>, Empty;/' testinc/test5a.flow
sed -i '/Empty();/a\\tNonEmpty(meta: ??);' testinc/test5a.flow

# Fix the getOrDefault function to match the new type
sed -i '/\tEmpty(): default;/a\\tNonEmpty(__): default;' testinc/test5a.flow

# Recompile without update-incremental to see if changes are detected
echo ""
echo "=== Recompiling test5b.flow without update-incremental ==="
flowcpp --batch flow9.flow -- testinc/test5b.flow verbose=1

# Restore the original file
echo ""
echo "=== Restoring original file ==="
sed -i 's/Container<?, ??> ::= Box<?>, NonEmpty<??>, Empty;/Container<?> ::= Box<?>, Empty;/' testinc/test5a.flow
sed -i '/\tNonEmpty(meta: ??);/d' testinc/test5a.flow
sed -i '/\tNonEmpty(__): default;/d' testinc/test5a.flow
