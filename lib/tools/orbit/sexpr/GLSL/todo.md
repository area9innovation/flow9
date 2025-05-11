# GLSL Interpreter TODO List

## Key Challenges

*   **Efficient AST Representation & Traversal:** Designing the binary AST (see `glsl_representation.md`) for compact storage and efficient random access and traversal in GLSL.
*   **GLSL State Management for Parallelism**: Correctly isolating each thread's operand stack, call stack, heap slice, and environment pointers within the GLSL execution model (see `glsl_evaluator_arch.md`).
*   **Function Calls & Closures**: Implementing these correctly with the AST evaluation model, including lexical scope capture and per-thread environment management.
*   **`eval` and Runtime `quasiquote`**: While the AST-based approach makes these more feasible than a bytecode model, their robust and efficient implementation in GLSL remains complex (see `glsl_evaluator_arch.md`).
*   **Debugging**: Debugging GLSL compute shaders, especially for a language interpreter, is notoriously difficult. Strategies will involve writing intermediate values to output buffers or using specialized GPU debugging tools if available.
*   **Performance**: The overhead of AST walking and interpretation in GLSL must be outweighed by the data parallelism of the Scheme programs being executed. Performance tuning of GLSL code and memory access patterns will be critical.
*   **Error Handling**: Implementing robust error reporting (e.g., type mismatches, unbound variables, division by zero) from within GLSL threads in a way that can be clearly communicated back to the host. The `error` built-in is a starting point.

## Phased Implementation Plan (AST-Based)

### Current Status

- **Flow Serializer**: ✅ IMPLEMENTED
  - Converts S-expressions to binary AST format
  - Generates constant pool for strings
  - Outputs GLSL-ready uniform data
  - Integrated with main S-expression interpreter

- **GLSL AST Evaluator**: IN PROGRESS
  - Not yet implemented

The following plan outlines the step-by-step approach to complete the interpreter:

### Phase 1: Core Data Types & Literal Evaluation
*   **Goal:** Serialize and evaluate basic Sexpr literals.
*   **Tasks:**
    *   Implement the [Flow Serializer](./flow_serializer.md) for `SSInt`, `SSDouble`, `SSBool`, `SSString`, `SSConstructor` and the constant pool. (Already ✅ IMPLEMENTED according to current status, but listed for completeness of phase goals if reviewed)
    *   Develop the [GLSL AST Evaluator](./glsl_evaluator_arch.md) core to load the binary AST and constant pool.
    *   Implement `evaluate_sexpr_node` in GLSL to identify and return (e.g., by pushing to an operand stack or directly outputting) these literal values.
    *   Setup for parallel input/output: each GLSL thread takes one input literal Sexpr and outputs it.

### Phase 2: Simple Expressions & Built-in Primitives
*   **Goal:** Evaluate simple function calls with basic arithmetic.
*   **Tasks:**
    *   Extend [Flow Serializer](./flow_serializer.md) for `SSList` nodes representing simple function calls (e.g., `(+ 1 2)`). (Already ✅ IMPLEMENTED according to current status, but listed for completeness of phase goals if reviewed)
    *   Enhance `evaluate_sexpr_node` in GLSL to handle `TAG_SSLIST` for function calls:
        *   Evaluate child nodes (which are literals from Phase 1).
    *   Implement a few core [Built-in Functions](./glsl_builtins.md) in GLSL (e.g., `+`, `-`, basic type predicates) that operate on Sexpr nodes from an operand stack.
    *   Implement dispatch to these built-ins based on `TAG_BUILTIN_FN`.
    *   Introduce the per-thread operand stack.

### Phase 3: Control Flow (`if`)
*   **Goal:** Implement conditional execution.
*   **Tasks:**
    *   Extend [Flow Serializer](./flow_serializer.md) for `SSSpecialForm` nodes representing `SIf`. (Already ✅ IMPLEMENTED according to current status, but listed for completeness of phase goals if reviewed)
    *   Add logic to `evaluate_sexpr_node` in GLSL for `SIf_ID`: evaluate condition child, then conditionally evaluate 'then' or 'else' AST branches.

### Phase 4: Variables & Basic Environments (Input Scope)
*   **Goal:** Introduce variable lookup, initially for input parameters.
*   **Tasks:**
    *   Extend [Flow Serializer](./flow_serializer.md) for `SSVariable` nodes. (Already ✅ IMPLEMENTED according to current status, but listed for completeness of phase goals if reviewed)
    *   Implement per-thread environments in GLSL (e.g., an association list stored on the thread's heap slice).
    *   Enhance `evaluate_sexpr_node` for `TAG_SSVARIABLE` to look up variables in the current environment.
    *   Modify initial GLSL thread setup to bind input data (as Sexpr nodes) to predefined variable names in the initial environment.

### Phase 5: User-Defined Functions (Global `define`) & Call Stack
*   **Goal:** Support simple, globally defined Scheme functions.
*   **Tasks:**
    *   Extend [Flow Serializer](./flow_serializer.md) for `SSSpecialForm` for `SDefine` (global functions only) and `SLambda` (serializing its structure). (Already ✅ IMPLEMENTED according to current status, but listed for completeness of phase goals if reviewed)
    *   Implement a mechanism in GLSL to register/find globally defined functions (mapping a name/ID to the AST node of its `SLambda`).
    *   Implement the per-thread call stack in GLSL.
    *   Logic for `evaluate_sexpr_node` when calling a user-defined function:
        *   Evaluate arguments.
        *   Create a new environment frame (parameters bound to argument values, parent is the global/defining environment).
        *   Push return information (continuation AST node, old environment) to the call stack.
        *   Call `evaluate_sexpr_node` on the function's body AST with the new environment.
        *   Handle function return by popping from the call stack and restoring state.

### Phase 6: Lexical Scoping and Closures
*   **Goal:** Implement proper lexical closures.
*   **Tasks:**
    *   Refine `evaluate_sexpr_node` for `SLambda_ID`: when a lambda is evaluated, create a `TAG_CLOSURE` Sexpr node on the thread's heap. This closure stores a pointer to the lambda's code (its `SLambda` AST node) and a pointer to the current lexical environment (captured at definition time).
    *   When a `TAG_CLOSURE` Sexpr is called: the new environment for the call has its parent link pointing to the closure's captured environment.

### Phase 7: Heap-Allocated Data Structures (`cons`, `list`, `vector`) & `quote`
*   **Goal:** Enable runtime creation of lists and vectors.
*   **Tasks:**
    *   Implement [Built-in Functions](./glsl_builtins.md) like `cons`, `list`, `vector` (and related accessors like `car`, `cdr`, `vector-ref`). These allocate new `SSList` or `SSVector` Sexpr nodes on the current thread's heap slice.
    *   Implement `evaluate_sexpr_node` for `SQuote_ID`: traverse the quoted AST structure (from global program memory) and deep-copy it into new Sexpr nodes on the current thread's heap.

### Phase 8: `eval` and Runtime `quasiquote` (Advanced)
*   **Goal:** Implement dynamic evaluation capabilities if required.
*   **Tasks:**
    *   **`eval`**: Extend `evaluate_sexpr_node` to handle an `eval` special form. The argument to `eval` is first evaluated to an Sexpr node (which should represent data in AST form); then, `evaluate_sexpr_node` is called again on this data-AST.
    *   **Runtime `quasiquote`**: If needed, implement the logic to traverse a quasiquoted Sexpr structure, evaluate `unquote`d parts, splice `unquote-splicing` parts, and construct the final Sexpr structure on the heap.

### Phase 9: Broader Built-in Function Set & Error Handling
*   **Goal:** Expand utility and robustness.
*   **Tasks:**
    *   Implement the remaining [Built-in Functions](./glsl_builtins.md) (type conversions, more math, string ops).
    *   Improve error handling: ensure built-ins and evaluator logic robustly create and propagate error Sexpr nodes. Implement the `error` built-in.

### Deferred/Excluded
*   Runtime `import` (all code is assumed to be serialized into one binary AST).
*   Advanced string manipulation beyond the essentials (due to GLSL limitations).
*   Garbage Collection (rely on per-thread bump allocation and isolated execution).
