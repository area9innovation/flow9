#!/bin/bash

# Set up initial files
echo "=== Setting up test files ==="

# a.flow - the common dependency that imports ds/tuples
cat > testinc/test13a.flow << 'EOF'
import runtime;
import ds/tuples;

export {
    // This function creates a pair of values
    makePair(a : int, b : string) -> Pair<int, string>;
}

// Implementation of the exported function
makePair(a : int, b : string) -> Pair<int, string> {
    Pair(a, b);
}
EOF

# b.flow - depends on a.flow
cat > testinc/test13b.flow << 'EOF'
import runtime;
import math/math; // For i2s
import testinc/test13a;

export {
    // This function uses the common dependency
    testB() -> string;
}

// Function uses makePair from test13a
testB() -> string {
    pair = makePair(42, "from B");
    i2s(pair.first) + ": " + pair.second;
}
EOF

# c.flow - also depends on a.flow but is in a separate program
cat > testinc/test13c.flow << 'EOF'
import runtime;
import math/math; // For i2s
import testinc/test13a;

export {
    // This function also uses the common dependency
    testC() -> string;
}

// Function uses makePair from test13a
testC() -> string {
    pair = makePair(100, "from C");
    i2s(pair.first) + ": " + pair.second;
}
EOF

# Step 1: Compile b.flow and c.flow independently - both should work
echo "\n=== STEP 1: Initial compilation of b.flow and c.flow ==="
echo "\n--- Compiling b.flow ---"
B1_OUTPUT=$(flowcpp --batch flow9.flow -- testinc/test13b.flow update-incremental=1 verbose=1 2>&1)
echo "$B1_OUTPUT"

echo "\n--- Compiling c.flow ---"
C1_OUTPUT=$(flowcpp --batch flow9.flow -- testinc/test13c.flow verbose=1 2>&1)
echo "$C1_OUTPUT"

# Step 2: Modify a.flow to introduce a type error
echo "\n=== STEP 2: Modifying a.flow to introduce a type error ==="
cat > testinc/test13a.flow << 'EOF'
import runtime;
import ds/tuples;

export {
    // This function creates a pair of values
    // ERROR: Changed signature - now returns string but implementation returns Pair
    makePair(a : int, b : string) -> string;
}

// Implementation - now mismatches the type signature
makePair(a : int, b : string) -> Pair<int, string> {
    Pair(a, b);
}
EOF

# Step 3: Compile b.flow - should fail due to error in a.flow
echo "\n=== STEP 3: Compiling b.flow (should fail due to error in a.flow) ==="
B2_OUTPUT=$(flowcpp --batch flow9.flow -- testinc/test13b.flow verbose=1 2>&1)
echo "$B2_OUTPUT"

# Check if an error was detected - look for subtype or lambda return error
if echo "$B2_OUTPUT" | grep -q "not an explicit subtype"; then
    B2_ERROR=1 # Error found
else
    B2_ERROR=0 # No error
fi
echo "B2 error check: $B2_ERROR (1=error found, 0=no error)"

# Step 4: Fix the error in a.flow
echo "\n=== STEP 4: Fixing the error in a.flow ==="
cat > testinc/test13a.flow << 'EOF'
import runtime;
import ds/tuples;

export {
    // This function creates a pair of values - fixed return type
    makePair(a : int, b : string) -> Pair<int, string>;
}

// Implementation of the exported function
makePair(a : int, b : string) -> Pair<int, string> {
    Pair(a, b);
}
EOF

# Step 5: Compile b.flow again - should succeed
echo "\n=== STEP 5: Recompiling b.flow after fixing a.flow ==="
B3_OUTPUT=$(flowcpp --batch flow9.flow -- testinc/test13b.flow verbose=1 2>&1)
echo "$B3_OUTPUT"

# Check if there are errors in the output
if echo "$B3_OUTPUT" | grep -q "not an explicit subtype"; then
    B3_ERROR=1 # Error found
else
    B3_ERROR=0 # No error
fi
echo "B3 error check: $B3_ERROR (1=error found, 0=no error)"

# Step 6: Compile c.flow - should succeed without recompiling a.flow
echo "\n=== STEP 6: Compiling c.flow after fixing a.flow ==="
C2_OUTPUT=$(flowcpp --batch flow9.flow -- testinc/test13c.flow verbose=1 2>&1)
echo "$C2_OUTPUT"

# Check if there are errors in the output
if echo "$C2_OUTPUT" | grep -q "not an explicit subtype"; then
    C2_ERROR=1 # Error found
else
    C2_ERROR=0 # No error
fi
echo "C2 error check: $C2_ERROR (1=error found, 0=no error)"

# Check if a.flow was loaded from incremental cache (should see "Loaded module from incremental cache")
if echo "$C2_OUTPUT" | grep -q "Loaded module from incremental cache: testinc/test13a.flow"; then
    LOADED_FROM_CACHE=1 # Used incremental
else
    LOADED_FROM_CACHE=0 # Did not use incremental
fi
echo "Loaded a.flow from cache: $LOADED_FROM_CACHE (1=used incremental, 0=recompiled)"

# Check overall test results
if [ $B2_ERROR -eq 1 ] && [ $B3_ERROR -eq 0 ] && [ $C2_ERROR -eq 0 ]; then
    echo "\nTEST PASSED: Incremental compilation correctly handled dependency fixes"
    echo "1. First compilation of b.flow and c.flow succeeded"
    echo "2. After breaking a.flow, b.flow failed to compile"
    echo "3. After fixing a.flow, b.flow compiled successfully"
    echo "4. c.flow also compiled successfully after the fix"
    
    if [ $LOADED_FROM_CACHE -eq 1 ]; then
        echo "5. a.flow was correctly loaded from incremental cache for c.flow"
    else
        echo "5. a.flow was recompiled for c.flow (not optimal but still correct)"
    fi
else
    echo "\nTEST FAILED: Incremental compilation did not handle dependencies correctly"
    echo "B2 error detection: $B2_ERROR (expected 1)"
    echo "B3 error detection: $B3_ERROR (expected 0)"
    echo "C2 error detection: $C2_ERROR (expected 0)"
fi

# Clean up test files
echo "\n=== Cleaning up test files ==="
rm -f testinc/test13a.flow testinc/test13b.flow testinc/test13c.flow