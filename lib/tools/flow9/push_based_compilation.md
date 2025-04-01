# Push-Based Incremental Compilation System

## Overview

The Flow9 compiler uses a push-based incremental compilation system where changes are actively propagated to dependent modules. This document explains how the system works and the key components involved.

## Core Components

### Compilation States

Modules can be in the following states during compilation:

- `CompileNotSeen`: Module has not been processed yet
- `CompileInProgress`: Currently being compiled
- `CompileParsed`: Successfully parsed but not yet typechecked
- `CompileTyped`: Successfully parsed and typechecked
- `CompileNeedsRecheck`: Previously typed but needs rechecking due to dependency changes
- `CompileFailure`: Compilation failed with errors

### Key Data Structures

1. `CompileState`: Central data structure containing:
   - `compileStatus`: Maps file paths to their compilation status
   - `parseQueue` and `typeQueue`: Queues of files to be processed
   - `dependencies`: Tracks which modules depend on which (module → dependencies)
   - `reverseDependencies`: Tracks which modules are imported by which (module → dependents)

2. `DModule`: Represents a compiled module with:
   - Exports, imports, type environment, content hash, and timestamp
   - Used for both final compilation output and incremental caching

## Incremental Compilation Process

### 1. Module Parsing

When a module is parsed (`parseFlow9`), the system:

1. Checks if an up-to-date incremental version exists
2. If available and valid, loads it and skips parsing
3. If not available or outdated:
   - Loads the old incremental file for comparison (if it exists)
   - Parses the source file
   - Compares old and new versions to identify changed identifiers
   - Propagates these changes to dependent modules
   - Only after comparison removes the old incremental file

### 2. Dependency Tracking

Dependencies are tracked in two ways:

1. Forward dependencies (`dependencies`): Which modules a module depends on
   - Used to determine compilation order
   - Ensures all dependencies are compiled before a module

2. Reverse dependencies (`reverseDependencies`): Which modules depend on a module
   - Updated via `updateReverseDependencies` when imports are processed
   - Used for change propagation to dependent modules

### 3. Change Propagation

When a module changes, the system:

1. Identifies changed identifiers by comparing old and new module versions
2. Uses `propagateChanges` to notify dependent modules
3. Marks dependent modules as `CompileNeedsRecheck` with the list of changed identifiers
4. Adds affected modules to the typecheck queue

If specific changes cannot be identified, the system treats it as if all exports changed.

### 4. Module Rechecking

When a module needs rechecking (`CompileNeedsRecheck`):

1. The module is forced to be fully recompiled regardless of its incremental cache status
2. Incremental cache is invalidated to ensure fresh compilation
3. The system performs a full typecheck with the latest dependency information
4. Changes detected during typechecking are further propagated

## Optimizations

1. **Selective Rechecking**: Only modules affected by changes are recompiled
2. **Change Identification**: Specific changed identifiers are tracked to potentially enable more targeted rechecking
3. **Memory Efficiency**: Incremental modules store only the necessary information (exports, types) for change detection

## Testing

The system is tested with various scenarios in the `testinc/` folder:

1. **Function Name Change**: Tests if renaming a function forces re-typechecking of dependent functions
2. **Type Structure Change**: Tests if changing a struct's fields forces re-typechecking of dependent code
3. **Variable Type Change**: Tests if changing a constant's type forces re-typechecking of dependent code
4. **Multi-level Dependency Chain**: Tests propagation of changes through multiple layers of dependencies
5. **Polymorphic Type Change**: Tests handling of changes to polymorphic type definitions

See `testinc/README.md` for detailed information on each test case.

## Key Functions

- `parseFlow9`: Parses a module, potentially using incremental cache
- `typecheckFlow9`: Typechecks a module after parsing
- `propagateChanges`: Notifies dependent modules of changes
- `updateReverseDependencies`: Updates the reverse dependency graph
- `markDependentModulesForRecheck`: Explicitly marks modules for rechecking
- `preloadDIncrementalModule`: Attempts to load a cached module if valid
- `loadOldIncrementalModule`: Loads previous module version for comparison
- `getChangedIdsFromModules`: Identifies changed identifiers between module versions

## Future Improvements

- Fine-grained rechecking that only retypechecks parts of a module affected by changes
- Dependency graph pruning to optimize memory usage
- Performance optimizations for large codebases
- Further identification of specific change impacts (e.g., type changes vs. implementation changes)