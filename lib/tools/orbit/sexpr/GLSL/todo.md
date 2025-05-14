# GLSL Interpreter TODO List

## Current Implementation Status

Key components already implemented:

* `@exports glsl_generator.flow` - Generates GLSL code from S-expressions ✅
* `@exports glsl_representation.flow` - Defines binary format type tags ✅
* `@exports glsl_serializer.flow` - Serializes S-expressions to binary format ✅
* `@include run_sexp_glsl_test.sh` - Testing infrastructure ✅

Components in progress:
* `@include interpreter.glsl` - GLSL interpreter (partial implementation)
* `@include host.cpp` - Vulkan host application (basic functionality working)

## Streamlined Roadmap

0.
Change AST representatino to be uniform 4 ints per node.

### 1. Core Evaluation Engine
**Goal**: Evaluate basic arithmetic expressions like `(+ 1 2)` and `(- 100 58)`

* Implement core `evaluate_sexpr_node` function in GLSL
* Add operand stack mechanism for each thread
* Implement numeric operations (+, -, *, /, etc.)
* Add simple type conversion functions

### 2. Control Flow & Variables
**Goal**: Support `if` expressions and variable bindings

* Implement conditional evaluation in GLSL
* Add environment frame structure for variable storage
* Implement variable lookup mechanism
* Support basic predicates (equal?, <, >, etc.)

### 3. Functions & Recursion
**Goal**: Enable user-defined functions with proper scoping

* Implement call stack for tracking function calls
* Add support for global function definitions
* Implement parameter binding
* Support basic recursion

### 4. Data Structures
**Goal**: Support lists, vectors and basic operations

* Implement heap allocation for each thread
* Add support for list construction and access (cons, car, cdr)
* Implement vector operations
* Support quoted expressions

### 5. Advanced Features
**Goal**: Complete the language implementation with advanced features

* Implement proper lexical closures
* Add error handling mechanisms
* Support additional built-in functions
* Implement basic string operations
* Add optional support for eval and quasiquote

## Testing Strategy

* Create small, focused test cases for each feature
* Implement GLSL debugging output for troubleshooting
* Compare GLSL evaluation results with reference implementation
* Build test suite covering all language features

## Performance Considerations

* Optimize memory access patterns for GPU
* Minimize divergent execution paths
* Balance thread workloads for parallel evaluation
* Profile and identify bottlenecks

## Deferred Features

* Runtime `import` functionality
* Advanced string manipulation
* Garbage collection (using bump allocation instead)
* Complex macro systems
