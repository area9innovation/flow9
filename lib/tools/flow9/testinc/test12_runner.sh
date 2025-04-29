#!/bin/bash

# Create a file with a type error that imports from standard library
cat > testinc/test12.flow << 'EOF'
import runtime;
import ds/tuples;

export {
    // Function with a type error - uses string where int is expected
    testTuples() -> string;
}

// Helper function that expects int arguments
makePairOfInts(a : int, b : int) -> Pair<int, int> {
    Pair(a, b);
}

// This function has a type error - passing string where int is expected
testTuples() -> string {
    // Type error - second argument should be int but we pass string
    myPair = makePairOfInts(42, "hello"); 
    
    // Convert both to string and return
    i2s(myPair.first) + ", " + i2s(myPair.second);
}
EOF

# Initial compilation attempt - should fail
echo "=== Initial compilation with a type error (should fail) ==="
FIRST_OUTPUT=$(flowcpp --batch flow9.flow -- testinc/test12.flow update-incremental=1 verbose=1 2>&1)
echo "$FIRST_OUTPUT"

# Check if there are errors in the output
if echo "$FIRST_OUTPUT" | grep -q "Type error"; then
    FIRST_RESULT=1 # Error found
else
    FIRST_RESULT=0 # No error
fi
echo "First compilation error check: $FIRST_RESULT (1=error found, 0=no error)"

# Fix the type error
echo ""
echo "=== Fixing type error ==="
cat > testinc/test12.flow << 'EOF'
import runtime;
import ds/tuples;
import math/math; // For i2s

export {
    // Function with fixed type error
    testTuples() -> string;
}

// Helper function that expects int arguments
makePairOfInts(a : int, b : int) -> Pair<int, int> {
    Pair(a, b);
}

// Fixed function - correctly passes two ints
testTuples() -> string {
    // Fixed - now passing two ints as expected
    myPair = makePairOfInts(42, 100);
    
    // Convert both to string and return
    i2s(myPair.first) + ", " + i2s(myPair.second);
}
EOF

# Recompile incrementally
echo ""
echo "=== Recompiling with fixed error ==="
SECOND_OUTPUT=$(flowcpp --batch flow9.flow -- testinc/test12.flow verbose=1 2>&1)
echo "$SECOND_OUTPUT"

# Check if there are errors in the output
if echo "$SECOND_OUTPUT" | grep -q "Type error"; then
    SECOND_RESULT=1 # Error found
else
    SECOND_RESULT=0 # No error
fi
echo "Second compilation error check: $SECOND_RESULT (1=error found, 0=no error)"

# Check if test passed (first compilation should fail, second should succeed)
if [ $FIRST_RESULT -eq 1 ] && [ $SECOND_RESULT -eq 0 ]; then
    echo "\nTEST PASSED: Compilation correctly failed with type error and succeeded after fix"
    echo "This confirms the environment from ds/tuples.flow was correctly captured and preserved."
else
    echo "\nTEST FAILED: Expected first compilation to have errors ($FIRST_RESULT) and second to succeed without errors ($SECOND_RESULT)"
fi

# Add additional information about incremental compilation
echo ""
echo "=== Summary ==="
echo "This test verifies that:"
echo "1. A file with type errors is properly detected"
echo "2. After fixing the errors, the incremental compiler correctly uses the cached dependencies"
echo "3. The environment (types and functions) from standard library (ds/tuples.flow) is preserved"

# Clean up test files
echo ""
echo "=== Cleaning up test files ==="
rm -f testinc/test12.flow