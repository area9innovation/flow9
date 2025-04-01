#!/bin/bash

# Create the dependent file with type error
cat > testinc/test11a.flow << 'EOF'
import runtime;

export {
    // Function with type error - wrong return type specified
    brokenFunction(x : int) -> string { x + 1 };
}
EOF

# Create the main file that depends on the broken file
cat > testinc/test11b.flow << 'EOF'
import runtime;
import math/math; // Import for i2s
import testinc/test11a;

export {
    // This function tries to use the broken dependency
    mainFunction() -> void;
}

mainFunction() -> void {
    // Uses the broken function - should fail due to dependency error
    value = brokenFunction(42);
    println("Value: " + i2s(value));
}
EOF

# Initial compilation attempt - should fail due to type error in dependency
echo "=== Initial compilation with a type error in dependency (should fail) ==="
FIRST_OUTPUT=$(flowcpp --batch flow9.flow -- testinc/test11b.flow update-incremental=1 verbose=1 2>&1)
echo "$FIRST_OUTPUT"

# Check if there are errors in the output
if echo "$FIRST_OUTPUT" | grep -q "No viable type alternatives"; then
    FIRST_RESULT=1 # Error found
else
    FIRST_RESULT=0 # No error
fi
echo "First compilation error check: $FIRST_RESULT (1=error found, 0=no error)"

# Fix the type error in the dependency
echo ""
echo "=== Fixing type error in dependency file ==="
cat > testinc/test11a.flow << 'EOF'
import runtime;

export {
    // Fixed function - return type now matches implementation
    brokenFunction(x : int) -> int { x + 1 };
}
EOF

# Recompile without update-incremental to verify it works now
echo ""
echo "=== Recompiling with fixed dependency ==="
SECOND_OUTPUT=$(flowcpp --batch flow9.flow -- testinc/test11b.flow verbose=1 2>&1)
echo "$SECOND_OUTPUT"

# Check if there are errors in the output
if echo "$SECOND_OUTPUT" | grep -q "No viable type alternatives"; then
    SECOND_RESULT=1 # Error found
else
    SECOND_RESULT=0 # No error
fi
echo "Second compilation error check: $SECOND_RESULT (1=error found, 0=no error)"

# Check if test passed (first compilation should fail, second should succeed)
if [ $FIRST_RESULT -eq 1 ] && [ $SECOND_RESULT -eq 0 ]; then
    echo "\nTEST PASSED: Compilation correctly failed with type error and succeeded after fix"
else
    echo "\nTEST FAILED: Expected first compilation to have errors ($FIRST_RESULT) and second to succeed without errors ($SECOND_RESULT)"
fi

# Clean up test files
echo ""
echo "=== Cleaning up test files ==="
rm -f testinc/test11a.flow testinc/test11b.flow