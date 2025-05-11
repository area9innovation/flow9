# Scheme-to-GLSL: AST-Based Parallel Interpreter Plan

## 1. Overview

This document outlines a plan to create an interpreter for a Scheme-variant, enabling its execution on GPUs using GLSL compute shaders. The primary goal is to run the same Scheme program in parallel across many data inputs, with each instance isolated. The result of evaluating any part of the program is itself an S-expression AST node.

The main components of this plan are detailed in the following documents:
*   [S-expression Representation in GLSL](./glsl_representation.md): Describes how Scheme AST nodes and runtime values are represented in GLSL memory.
*   [Flow Serializer](./flow_serializer.md): Details the Flow9 utility that converts S-expression ASTs into the binary format for GPU execution - ✅ IMPLEMENTED
*   [GLSL AST Evaluator Architecture](./glsl_evaluator_arch.md): Explains the architecture of the GLSL compute shader that evaluates the binary AST.
*   [Built-in Functions for GLSL](./glsl_builtins.md): Lists the built-in functions that will be implemented in GLSL.
*   [TODO List](./todo.md): Detailed tasks for completing the GLSL interpreter.

This approach makes runtime `eval` and `quasiquote` more feasible as the code structure (AST) is directly available to the GLSL evaluator, and values are already in AST form.

## 2. Workflow (Simplified)

1.  **Scheme Code Authoring:** Write the Scheme program (e.g., `program.scm` or `program.sexp`).
2.  **Parsing & Serialization with the S-expression Interpreter:** ✅ IMPLEMENTED
    ```bash
	flowcpp sexpr.flow program.sexp glsl=program.glsl
```
    This will:
    * Parse the Scheme code into a standard `Sexpr` AST in Flow9
    * Evaluate the program (for verification)
    * Serialize the AST to a GPU-friendly binary format
    * Generate a GLSL file containing:
      - `u_program_ast`: A flat numerical array representing the entire S-expression AST
      - `u_constant_pool`: A flat numerical array storing all unique strings
      - Type tag definitions and constants

3.  **GPU Data Loading:**
    *   Include the generated GLSL file in your shader
    *   Load per-thread input data (each input being an Sexpr node itself) into a GPU buffer accessible by the compute shaders.

4.  **GLSL Compute Shader Execution:**
    *   Launch N GLSL compute shader threads, where N is the number of input data items.
    *   Each thread:
        *   Reads its specific input Sexpr node.
        *   Evaluates the shared `u_program_ast` using its private state (stacks, heap slice, environment), as described in the [GLSL AST Evaluator Architecture](./glsl_evaluator_arch.md).
        *   Utilizes the [Built-in Functions](./glsl_builtins.md) as needed.
        *   Writes its final Sexpr node result to a per-thread location in an output buffer.

5.  **Result Retrieval:** Read the output buffer (containing result Sexpr nodes) from the GPU back to the host system.

## 5. S-Expression AST to GLSL Considerations

The translation from `sexpr_types.flow` structures (the parser's output) to the binary `program_ast` array is a direct mapping, guided by the [S-expression Representation in GLSL](./glsl_representation.md). The GLSL `evaluate_sexpr_node` function will effectively be a large interpreter dispatch loop, switching on Sexpr node type tags to execute the appropriate logic for evaluation, environment manipulation, and control flow. The key is that both the "program" and the "data" share the same Sexpr node representation.
