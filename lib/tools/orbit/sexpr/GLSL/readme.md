# Scheme-to-GLSL: AST-Based Parallel Interpreter Plan

## 1. Overview

This document outlines a plan to create an interpreter for a Scheme-variant, enabling its execution on GPUs using GLSL compute shaders. The primary goal is to run the same Scheme program in parallel across many data inputs, with each instance isolated. The result of evaluating any part of the program is itself an S-expression AST node.

The main components of this plan are detailed in the following documents:
*   [S-expression Representation in GLSL](./glsl_representation.md): Describes how Scheme AST nodes and runtime values are represented in GLSL memory.
*   [Flow Serializer](./flow_serializer.md): Details the Flow9 utility that converts S-expression ASTs into the binary format for GPU execution.
*   [GLSL AST Evaluator Architecture](./glsl_evaluator_arch.md): Explains the architecture of the GLSL compute shader that evaluates the binary AST.
*   [Built-in Functions for GLSL](./glsl_builtins.md): Lists the built-in functions that will be implemented in GLSL.

This approach makes runtime `eval` and `quasiquote` more feasible as the code structure (AST) is directly available to the GLSL evaluator, and values are already in AST form.

## 2. Workflow (Simplified)

1.  **Scheme Code Authoring:** Write the Scheme program (e.g., `program.scm`).
2.  **Parsing (Existing Tools):** Use the existing Mango parser (`sexpr.mango`) to parse the Scheme code into a standard `Sexpr` AST in Flow9.
3.  **Serialization (Flow9 Utility):**
    *   A dedicated Flow9 program (detailed in [Flow Serializer](./flow_serializer.md)) takes the `Sexpr` AST.
    *   It generates two primary outputs:
        1.  `binary_program_ast`: A flat numerical array representing the entire S-expression AST, optimized for GPU access.
        2.  `constant_pool`: A flat numerical array storing all unique strings (variable names, string literals, constructor names).
4.  **GPU Data Loading:**
    *   Transfer the `binary_program_ast` and `constant_pool` to GPU global read-only memory (e.g., UBOs, SSBOs, or textures).
    *   Load per-thread input data (each input being an Sexpr node itself) into a GPU buffer accessible by the compute shaders.
5.  **GLSL Compute Shader Execution:**
    *   Launch N GLSL compute shader threads, where N is the number of input data items.
    *   Each thread:
        *   Reads its specific input Sexpr node.
        *   Evaluates the shared `binary_program_ast` using its private state (stacks, heap slice, environment), as described in the [GLSL AST Evaluator Architecture](./glsl_evaluator_arch.md).
        *   Utilizes the [Built-in Functions](./glsl_builtins.md) as needed.
        *   Writes its final Sexpr node result to a per-thread location in an output buffer.
6.  **Result Retrieval:** Read the output buffer (containing result Sexpr nodes) from the GPU back to the host system.

## 3. Key Challenges

*   **Efficient AST Representation & Traversal:** Designing the binary AST ([see `glsl_representation.md`](./glsl_representation.md)) for compact storage and efficient random access and traversal in GLSL.
*   **GLSL State Management for Parallelism**: Correctly isolating each thread's operand stack, call stack, heap slice, and environment pointers within the GLSL execution model ([see `glsl_evaluator_arch.md`](./glsl_evaluator_arch.md)).
*   **Function Calls & Closures**: Implementing these correctly with the AST evaluation model, including lexical scope capture and per-thread environment management.
*   **`eval` and Runtime `quasiquote`**: While the AST-based approach makes these more feasible than a bytecode model, their robust and efficient implementation in GLSL remains complex ([see `glsl_evaluator_arch.md`](./glsl_evaluator_arch.md)).
*   **Debugging**: Debugging GLSL compute shaders, especially for a language interpreter, is notoriously difficult. Strategies will involve writing intermediate values to output buffers or using specialized GPU debugging tools if available.
*   **Performance**: The overhead of AST walking and interpretation in GLSL must be outweighed by the data parallelism of the Scheme programs being executed. Performance tuning of GLSL code and memory access patterns will be critical.
*   **Error Handling**: Implementing robust error reporting (e.g., type mismatches, unbound variables, division by zero) from within GLSL threads in a way that can be clearly communicated back to the host. The `error` built-in is a starting point.

## 4. Phased Implementation Plan (AST-Based)

This plan outlines a step-by-step approach to build the interpreter:

### Phase 1: Core Data Types & Literal Evaluation
*   **Goal:** Serialize and evaluate basic Sexpr literals.
*   **Tasks:**
    *   Implement the [Flow Serializer](./flow_serializer.md) for `SSInt`, `SSDouble`, `SSBool`, `SSString`, `SSConstructor` and the constant pool.
    *   Develop the [GLSL AST Evaluator](./glsl_evaluator_arch.md) core to load the binary AST and constant pool.
    *   Implement `evaluate_sexpr_node` in GLSL to identify and return (e.g., by pushing to an operand stack or directly outputting) these literal values.
    *   Setup for parallel input/output: each GLSL thread takes one input literal Sexpr and outputs it.

### Phase 2: Simple Expressions & Built-in Primitives
*   **Goal:** Evaluate simple function calls with basic arithmetic.
*   **Tasks:**
    *   Extend [Flow Serializer](./flow_serializer.md) for `SSList` nodes representing simple function calls (e.g., `(+ 1 2)`).
    *   Enhance `evaluate_sexpr_node` in GLSL to handle `TAG_SSLIST` for function calls:
        *   Evaluate child nodes (which are literals from Phase 1).
    *   Implement a few core [Built-in Functions](./glsl_builtins.md) in GLSL (e.g., `+`, `-`, basic type predicates) that operate on Sexpr nodes from an operand stack.
    *   Implement dispatch to these built-ins based on `TAG_BUILTIN_FN`.
    *   Introduce the per-thread operand stack.

### Phase 3: Control Flow (`if`)
*   **Goal:** Implement conditional execution.
*   **Tasks:**
    *   Extend [Flow Serializer](./flow_serializer.md) for `SSSpecialForm` nodes representing `SIf`.
    *   Add logic to `evaluate_sexpr_node` in GLSL for `SIf_ID`: evaluate condition child, then conditionally evaluate 'then' or 'else' AST branches.

### Phase 4: Variables & Basic Environments (Input Scope)
*   **Goal:** Introduce variable lookup, initially for input parameters.
*   **Tasks:**
    *   Extend [Flow Serializer](./flow_serializer.md) for `SSVariable` nodes.
    *   Implement per-thread environments in GLSL (e.g., an association list stored on the thread's heap slice).
    *   Enhance `evaluate_sexpr_node` for `TAG_SSVARIABLE` to look up variables in the current environment.
    *   Modify initial GLSL thread setup to bind input data (as Sexpr nodes) to predefined variable names in the initial environment.

### Phase 5: User-Defined Functions (Global `define`) & Call Stack
*   **Goal:** Support simple, globally defined Scheme functions.
*   **Tasks:**
    *   Extend [Flow Serializer](./flow_serializer.md) for `SSSpecialForm` for `SDefine` (global functions only) and `SLambda` (serializing its structure).
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

## 5. S-Expression AST to GLSL Considerations

The translation from `sexpr_types.flow` structures (the parser's output) to the binary `program_ast` array is a direct mapping, guided by the [S-expression Representation in GLSL](./glsl_representation.md). The GLSL `evaluate_sexpr_node` function will effectively be a large interpreter dispatch loop, switching on Sexpr node type tags to execute the appropriate logic for evaluation, environment manipulation, and control flow. The key is that both the "program" and the "data" share the same Sexpr node representation.
