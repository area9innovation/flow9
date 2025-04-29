# Incremental Compilation Test Suite

This directory contains tests for the incremental compiler, focusing on verifying that changes to identifiers are properly tracked and dependent functions are re-typechecked appropriately.

## Test Structure

Each test follows a similar pattern:

1. Initial compilation with `update-incremental=1` to create baseline incremental data
2. Modification of a key identifier (function name, type structure, variable type, etc.)
3. Recompilation without explicit `update-incremental` to test if changes are detected
4. Restoration of original files

## Test Cases

1. **Function Name Change**: Tests if renaming a function forces re-typechecking of dependent functions
2. **Type Structure Change**: Tests if changing a struct's fields forces re-typechecking of dependent code
3. **Variable Type Change**: Tests if changing a constant's type forces re-typechecking of dependent code
4. **Multi-level Dependency Chain**: Tests propagation of changes through multiple layers of dependencies
5. **Polymorphic Type Change**: Tests handling of changes to polymorphic type definitions
6. **Union Type Change**: Tests if changing a union type forces re-typechecking of dependent code
7. **Function Parameter Type Change**: Tests if changing a function's parameter type forces re-typechecking of callers
8. **Return Type Change**: Tests if changing a function's return type forces re-typechecking of dependent code
9. **Recursive Type Definition Change**: Tests handling of changes to recursively defined types
10. **Type Alias Change**: Tests if changing a type alias forces re-typechecking of dependent code

## Running Tests

To run all tests:

```
./testinc/run_all_tests.sh
```

To run an individual test:

```
./testinc/test1_runner.sh
```

## Expected Results

For a correctly functioning incremental compiler:

1. Initial compilation with `update-incremental=1` should succeed for all files
2. After changing IDs, recompilation should detect the changes and re-typecheck dependent files
3. Appropriate error messages should appear when identifiers are changed to incompatible values

## Debugging

When the incremental compiler isn't correctly tracking dependencies:

- Check if IDs are properly tracked at the definition level
- Verify that all dependent files are invalidated when an ID changes
- Use `verbose=1` to see details about which files are being processed