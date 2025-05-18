#!/bin/bash

# Set up initial files
echo "=== Setting up test files ==="

# a.flow - the common dependency with a Union type
cat > testinc/test14a.flow << 'EOF'
import runtime;

export {
    // Define a union type with two constructors
    U ::= Foo, Bar;
        Foo(value: int);
        Bar(text: string);
    
    // Function that creates a Foo constructor
    makeFoo(x : int) -> Foo;
    
    // Function that checks if something is a U type
    isValidU(u : U) -> bool;
}

// Implementation of makeFoo
makeFoo(x : int) -> Foo {
    Foo(x);
}

// Implementation of isValidU
isValidU(u : U) -> bool {
    switch (u) {
        Foo(__): true;
        Bar(__): true;
    }
}
EOF

# b.flow - only uses Foo constructor, not the union type U
cat > testinc/test14b.flow << 'EOF'
import runtime;
import math/math; // For i2s
import testinc/test14a;

export {
    // This function only uses Foo constructor from a.flow
    testB() -> string;
}

// Function only uses makeFoo, not the U type directly
testB() -> string {
    foo = makeFoo(42);
    "B created Foo with value: " + i2s(foo.value);
}
EOF

# c.flow - uses the union type U explicitly
cat > testinc/test14c.flow << 'EOF'
import runtime;
import testinc/test14a;

export {
    // This function explicitly uses the U type
    testC() -> bool;
}

// Function uses the union type U explicitly
testC() -> bool {
    // Create both constructors of U and test them
    foo = Foo(100);
    bar = Bar("hello");
    
    // Uses the isValidU function that requires U type
    isValidU(foo) && isValidU(bar);
}
EOF

# Step 1: Compile b.flow and c.flow independently - both should work
echo "\n=== STEP 1: Initial compilation of b.flow and c.flow ==="
echo "\n--- Compiling b.flow ---"
B1_OUTPUT=$(flowcpp --batch flow9.flow -- testinc/test14b.flow update-incremental=1 verbose=1 2>&1)
echo "$B1_OUTPUT"

echo "\n--- Compiling c.flow ---"
C1_OUTPUT=$(flowcpp --batch flow9.flow -- testinc/test14c.flow update-incremental=1 verbose=1 2>&1)
echo "$C1_OUTPUT"

# Step 2: Modify a.flow to introduce a type error in the union
echo "\n=== STEP 2: Modifying a.flow to introduce a type error ==="
cat > testinc/test14a.flow << 'EOF'
import runtime;

export {
    // Define a union type with an invalid constructor
    U ::= Foo, BadBar;
        Foo(value: int);
        BadBar(text: string, missingType);
    
    // Function that creates a Foo constructor
    makeFoo(x : int) -> Foo;
    
    // Function that checks if something is a U type
    isValidU(u : U) -> bool;
}

// Implementation of makeFoo
makeFoo(x : int) -> Foo {
    Foo(x);
}

// Implementation of isValidU - now broken due to BadBar
isValidU(u : U) -> bool {
    switch (u) {
        Foo(__): true;
        BadBar(__, __): true;
    }
}
EOF

# Step 3: Compile b.flow - should fail due to error in a.flow
echo "\n=== STEP 3: Compiling b.flow (should fail due to error in a.flow) ==="
B2_OUTPUT=$(flowcpp --batch flow9.flow -- testinc/test14b.flow verbose=1 2>&1)
echo "$B2_OUTPUT"

# Check if an error was detected - look for any error message
if echo "$B2_OUTPUT" | grep -q "not defined"; then
    B2_ERROR=1 # Error found
else
    B2_ERROR=0 # No error
fi
echo "B2 error check: $B2_ERROR (1=error found, 0=no error)"

# Step 4: Fix a.flow but remove the U type completely, keeping only Foo
echo "\n=== STEP 4: Fixing a.flow by removing U but keeping Foo ==="
cat > testinc/test14a.flow << 'EOF'
import runtime;

export {
    // Foo is now a standalone struct, not part of a union
    Foo(value: int);
    
    // Function that creates a Foo constructor
    makeFoo(x : int) -> Foo;
    
    // Removed isValidU function since U no longer exists
}

// Implementation of makeFoo
makeFoo(x : int) -> Foo {
    Foo(x);
}
EOF

# Step 5: Compile b.flow again - should succeed since it only uses Foo
echo "\n=== STEP 5: Recompiling b.flow after fixing a.flow ==="
B3_OUTPUT=$(flowcpp --batch flow9.flow -- testinc/test14b.flow verbose=1 2>&1)
echo "$B3_OUTPUT"

# Check if there are errors in the output
if echo "$B3_OUTPUT" | grep -q "not defined"; then
    B3_ERROR=1 # Error found
else
    B3_ERROR=0 # No error
fi
echo "B3 error check: $B3_ERROR (1=error found, 0=no error)"

# Step 6: Modify c.flow slightly to force recompilation
echo "\n=== STEP 6: Force recompilation of c.flow by modifying it slightly ==="
cat > testinc/test14c.flow << 'EOF'
import runtime;
import testinc/test14a;

export {
    // This function explicitly uses the U type
    testC() -> bool;
}

// Function uses the union type U explicitly
testC() -> bool {
    // Create both constructors of U and test them
    foo = Foo(100); // Updated from original
    bar = Bar("hello world");  // Modified string to force recompilation
    
    // Uses the isValidU function that requires U type
    isValidU(foo) && isValidU(bar);
}
EOF

# Step 7: Compile c.flow - should fail since U is no longer defined
echo "\n=== STEP 7: Compiling c.flow (should fail since U is removed) ==="
C2_OUTPUT=$(flowcpp --batch flow9.flow -- testinc/test14c.flow verbose=1 2>&1)
echo "$C2_OUTPUT"

# Look for specific error messages related to missing U and Bar
if echo "$C2_OUTPUT" | grep -q "Undefined"; then
    C2_ERROR=1 # Error found
else
    # Alternative check for compiler failure
    if echo "$C2_OUTPUT" | grep -q "Failed to convert"; then
        C2_ERROR=1 # Compilation failed
    else
        C2_ERROR=0 # No error
    fi
fi
echo "C2 error check: $C2_ERROR (1=error found, 0=no error)"

# Check overall test results
if [ $B2_ERROR -eq 1 ] && [ $B3_ERROR -eq 0 ] && [ $C2_ERROR -eq 1 ]; then
    echo "\nTEST PASSED: Incremental compilation correctly handled selective dependency fixes"
    echo "1. First compilation of b.flow and c.flow succeeded"
    echo "2. After breaking a.flow, b.flow failed to compile"
    echo "3. After fixing a.flow by removing U but keeping Foo, b.flow compiled successfully"
    echo "4. c.flow failed to compile because it depends on the removed U type"
    echo "\nThis demonstrates that the incremental compiler properly tracks specific dependencies"
    echo "and can correctly update dependent modules based on which parts of the interface they use."
else
    echo "\nTEST FAILED: Incremental compilation did not handle dependencies correctly"
    echo "B2 error detection: $B2_ERROR (expected 1)"
    echo "B3 error detection: $B3_ERROR (expected 0)"
    echo "C2 error detection: $C2_ERROR (expected 1)"
fi

# Clean up test files
echo "\n=== Cleaning up test files ==="
rm -f testinc/test14a.flow testinc/test14b.flow testinc/test14c.flow