# Flow Serializer (Scheme S-expression -> GPU-Optimized AST)

The utility in Flow9 will be responsible for converting the standard S-expression AST (as defined by `sexpr_types.flow`) into a GPU-friendly binary format. This binary format is a flattened representation of the AST, optimized for read-only access by many GLSL threads.

The key tasks of the Flow serializer are:

1.  **AST Traversal:**
    *   Recursively traverse the input `Sexpr` AST provided by the parser.

2.  **Constant Pool Generation:**
    *   Identify all unique strings within the `Sexpr` AST. This includes:
        *   String literals (`SSString`).
        *   Variable names (`SSVariable`).
        *   Constructor names (`SSConstructor`).
        *   Operator names (`SSOperator`), if they are to be stored as strings.
    *   Collect these unique strings into a list or tree.
    *   Assign a unique integer index to each string. This index will be used in the binary AST to refer to the string.
    *   Serialize this collection of unique strings into a flat numerical array (the "Constant Pool"). This could be an array of floats where each character is represented by its ASCII/UTF-8 code, or a more complex packed format if space is critical. The GLSL side will need a corresponding way to access these strings.

3.  **S-expression Node Serialization:**
    *   Convert each node in the `Sexpr` AST into its binary representation as defined in `glsl_representation.md` (Section 2.1).
    *   This involves:
        *   Assigning the correct primary type tag (e.g., `TAG_SSINT`, `TAG_SSLIST`).
        *   Storing literal values directly (e.g., the float value for `SSDouble`, the integer for `SSInt` cast to float).
        *   For `SSString`, `SSVariable`, `SSConstructor`, store the index into the Constant Pool.
        *   For `SSList`, `SSVector`, and `SSSpecialForm`:
            *   Recursively serialize their children.
            *   Store pointers (indices within the final binary AST array) to these children. This typically involves a two-step process: first, determine the layout and size of all nodes to calculate final indices, then write the nodes with correct pointers.
            *   Store the count of children.
            *   For `SSSpecialForm`, store the specific `special_form_enum_id`.

4.  **Output Format:**
    *   The primary output is the "binary program AST" – a flat numerical array (e.g., `[float]` or `[int]`) containing all serialized S-expression nodes. All internal pointers (e.g., from a list node to its children, or from a closure to its code body) are indices into this array.
    *   The secondary output is the "Constant Pool" array.
    *   These arrays are then loaded into GPU memory (e.g., UBOs, SSBOs, or textures) for the GLSL evaluator to access.

5.  **Handling of `lambda`:**
    *   An `SLambda` node within an `SSSpecialForm` is serialized like any other special form. Its body and parameter list are themselves S-expressions and will be serialized recursively as part of the overall AST. The GLSL evaluator will create a runtime `TAG_CLOSURE` object that points back to this serialized `SLambda` structure within the global program AST.

6.  **No Bytecode Generation:**
    *   It is crucial to note that this process does **not** generate bytecode or a linear instruction stream. It produces a direct, albeit flattened and numerically encoded, representation of the S-expression tree structure.

This Flow9 utility acts as a compiler backend, translating the high-level `Sexpr` ADT into a low-level data format suitable for the custom GLSL execution engine.