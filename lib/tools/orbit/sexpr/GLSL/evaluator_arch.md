# GLSL AST Evaluator Architecture

The GLSL compute shader is the core of the runtime execution. It evaluates the binary S-expression AST provided by the Flow serializer. Each GLSL thread (invocation) runs independently, processing the same program AST but with potentially different input data and maintaining its own isolated execution state (stacks, heap slice).

## 4.1. Core Components for Each GLSL Thread

Each GLSL thread requires the following components, managed within its execution context:

*   **Program AST Access (Global, Read-Only):**
    *   Access to the `binary_program_ast` array (containing the serialized S-expression nodes).
    *   Access to the `constant_pool` array (containing all unique strings).
    *   These are typically provided via Uniform Buffer Objects (UBOs), Shader Storage Buffer Objects (SSBOs), or textures, accessible by all threads.

*   **Operand Stack (Per-Thread):**
    *   A private GLSL array (e.g., `float stack[MAX_STACK_SIZE]`).
    *   Used to hold intermediate Sexpr node values (or pointers/indices to them) during the evaluation of complex expressions. For example, when evaluating `(+ a b)`, `a` and `b` would be evaluated, their resulting Sexpr nodes pushed to this stack, and then the `+` built-in would consume them from the stack.

*   **Call Stack (Per-Thread):**
    *   A private GLSL array used to manage Scheme function calls (both user-defined and potentially some complex built-ins if they require recursive evaluation logic).
    *   Each frame on the call stack might store:
        *   A pointer/index to the Sexpr AST node to evaluate *after* the current function call returns (the continuation point).
        *   A pointer/index to the calling function's environment, to be restored upon return.
        *   Optionally, a pointer to the previous frame pointer for stack unwinding.
    *   This explicit call stack is necessary because GLSL's native function call capabilities are limited and not designed for deep recursion typical in Scheme.

*   **Evaluation Pointer/State (Per-Thread):**
    *   One or more variables that keep track of the current Sexpr node being evaluated. This might be an index into the `binary_program_ast` or into the thread's local heap (if evaluating a dynamically created Sexpr).
    *   May also include state related to the current phase of evaluation for a complex node (e.g., "evaluating operator," "evaluating arg 1," etc.).

*   **Current Environment Pointer (Per-Thread):**
    *   A pointer/index to the Sexpr node representing the current lexical environment. This environment is typically an association list (a list of lists, e.g., `((var1 . val1) (var2 . val2) ... parent_env_ptr)`), stored on the thread's heap.

*   **Per-Thread Heap Slice & Allocator:**
    *   A designated region within a larger global heap buffer (e.g., an SSBO) is assigned to each thread.
    *   Each thread manages its own heap slice using a simple bump allocator (incrementing a pointer for each allocation).
    *   All new Sexpr nodes created at runtime (e.g., by `cons`, list construction, closure environment copies) are allocated in this thread-local heap slice.
    *   There is no cross-thread memory allocation or access to other threads' heap slices, ensuring isolation.
    *   No garbage collection is planned; programs operate within their allocated heap slice.

*   **Input Data Access (Per-Thread):**
    *   Each thread receives its specific input data, typically as an Sexpr node (or a pointer to one in a global input buffer). This could be passed via an SSBO indexed by `gl_GlobalInvocationID`.

*   **Output Data Storage (Per-Thread):**
    *   Each thread writes its final Sexpr node result to a designated location in an output buffer (e.g., an SSBO indexed by `gl_GlobalInvocationID`).

## 4.2. GLSL AST Evaluation Logic (Conceptual)

The heart of the evaluator is a recursive (or iterative with an explicit stack) function, let's call it `evaluate_sexpr_node(node_ref, current_env_ref)`.

*   `node_ref`: A reference (index/pointer) to the Sexpr node to be evaluated. This node can be in the global `binary_program_ast` or on the current thread's heap.
*   `current_env_ref`: A reference to the Sexpr node representing the current lexical environment.

The function's behavior is determined by the type tag of the `node_ref`:

1.  **Literals (`TAG_SSINT`, `TAG_SSDOUBLE`, `TAG_SSBOOL`, `TAG_SSSTRING`, `TAG_SSCONSTRUCTOR`, `TAG_NIL`):**
    *   These nodes evaluate to themselves. The function returns a reference to the literal node itself.

2.  **`TAG_SSVARIABLE`:**
    *   Look up the variable (identified by its constant pool index) in the `current_env_ref`.
    *   This involves traversing the association list representing the environment.
    *   Return a reference to the Sexpr node bound to the variable. If not found, an error Sexpr node should be returned.

3.  **`TAG_SSLIST` (Function Call / Data List):**
    *   This is the most complex case. The first element of the list determines if it's a call.
    *   **Evaluate the Operator:** Recursively call `evaluate_sexpr_node` on the first child of the list (the operator/function position).
    *   The result of evaluating the operator should be either a `TAG_CLOSURE` Sexpr node or a `TAG_BUILTIN_FN` Sexpr node.
    *   **Evaluate Arguments:** Recursively call `evaluate_sexpr_node` for each subsequent child of the list (the arguments). Collect references to these resulting Sexpr argument values.
    *   **Apply Function:**
        *   **If `TAG_CLOSURE`:**
            1.  Retrieve the pointer to the lambda's SLambda AST node (`lambda_code_ptr`) and the pointer to its captured environment (`captured_env_ref`) from the closure Sexpr object.
            2.  Create a new environment for the call: Extend the `captured_env_ref` by creating a new frame that binds the lambda's parameters (from `lambda_code_ptr`) to the evaluated argument Sexpr nodes. This new environment is allocated on the thread's heap.
            3.  Push necessary information (e.g., continuation AST node, current environment) onto the per-thread call stack.
            4.  Recursively call `evaluate_sexpr_node` on the body of the lambda (from `lambda_code_ptr`) with the newly created environment.
            5.  Upon return, pop from the call stack and resume.
        *   **If `TAG_BUILTIN_FN`:**
            1.  Extract the `builtin_function_id`.
            2.  Execute the corresponding hardcoded GLSL function for that built-in, passing the evaluated argument Sexpr nodes.
            3.  The built-in function will construct a new Sexpr node on the thread's heap as its result (e.g., `(+ 1 2)` results in a new `SSInt(3)` node). Return a reference to this new result node.
    *   If the `SSList` is not a function call (e.g., it's quoted data or the operator doesn't evaluate to a function), it might evaluate to itself or be part of a `quote` operation.

4.  **`TAG_SSSPECIALFORM`:**
    *   Extract the `special_form_enum_id`.
    *   **`SIf_ID`**:
        1.  Evaluate the condition child (child 0).
        2.  If the resulting Sexpr node is true (e.g., `SSBool(true)`), evaluate the 'then' branch child (child 1).
        3.  Otherwise, evaluate the 'else' branch child (child 2).
        4.  Return the result of the evaluated branch.
    *   **`SLambda_ID`**:
        1.  This AST node itself represents the code and parameter list of a lambda.
        2.  Create a new `TAG_CLOSURE` Sexpr node on the thread's heap.
        3.  This closure node stores:
            *   A pointer to this `SLambda_ID` node (or specifically its body/params part) in the global `binary_program_ast`.
            *   A pointer to the `current_env_ref` (capturing the lexical environment at definition time).
        4.  Return a reference to this new closure Sexpr node.
    *   **`SDefine_ID`**:
        1.  Evaluate the value child (child 1).
        2.  Get the variable name (from constant pool index in child 0).
        3.  Modify the `current_env_ref` (or the frame it points to) to bind the variable name to the evaluated Sexpr value. This might involve creating a new environment frame if `define` is used in a way that extends the current scope rather than mutating it (Scheme's `define` can be complex). For simplicity, it might initially only work at the top level of a lambda or global scope.
        4.  Return a special Sexpr node indicating success (e.g., `TAG_NIL` or the variable name).
    *   **`SQuote_ID`**:
        1.  The child (child 0) is the S-expression to be quoted.
        2.  Traverse this child AST structure (which is part of the global `binary_program_ast`).
        3.  For each node in the quoted structure, create an equivalent Sexpr node *on the current thread's heap*. This means deep-copying the quoted structure from read-only program memory into mutable runtime memory. For example, `(quote (1 "foo"))` would result in a new `SSList` on the heap, containing new `SSInt(1)` and `SSString("foo")` nodes (also on the heap, though the string content itself might still reference the constant pool).
        4.  Return a reference to the root of this newly created heap-allocated Sexpr data structure.
    *   Other special forms (`SLet`, `SLetRec`, `SAnd`, `SOr`, `SBegin`, etc.) are implemented with similar evaluation strategies, often desugaring into simpler operations or managing environment extensions.

**Iterative Evaluation:**
To avoid deep GLSL recursion for `evaluate_sexpr_node` itself (which can lead to stack overflow even with GLSL's own limited call stack), an iterative approach using an explicit evaluation work-stack can be used. This work-stack would manage AST nodes to visit and their evaluation state.

## 4.5. Handling `eval` and Runtime `quasiquote`

*   **`eval (expr)`:**
    1.  Call `evaluate_sexpr_node` on `expr`. The result should be an Sexpr node that represents a valid piece of AST (likely constructed via `quote` or runtime `quasiquote`).
    2.  Call `evaluate_sexpr_node` again, this time passing the *resulting Sexpr node from step 1* as the `node_ref` to be evaluated. The current environment is typically used.
    *   This is feasible because both code and data are Sexpr nodes. The `eval`ed Sexpr must conform to the same binary representation rules.

*   **Runtime `quasiquote`:**
    *   If `(quasiquote template)` is encountered at runtime (e.g., inside an `eval`):
        1.  Traverse the `template` Sexpr node (which is data).
        2.  When an `(unquote ...)` form is found within the template, call `evaluate_sexpr_node` on its argument in the current environment. Replace the `unquote` form with the resulting Sexpr value.
        3.  When an `(unquote-splicing ...)` form is found, evaluate its argument (which should result in an `SSList` Sexpr). Splice the elements of this resulting list into the parent structure.
        4.  Construct a new Sexpr data structure on the heap representing the fully expanded template.
    *   This is complex due to the need to distinguish template structure from evaluable parts and to correctly build new structures on the heap.

It's highly recommended to have the Flow serializer handle as much of `quasiquote` as possible at compile time if the template and its unquoted variables are known then.