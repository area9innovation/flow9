# S-expression Representation in GLSL Memory

Scheme AST nodes (which are also the runtime values) will be represented as numbers or small groups of numbers that GLSL can handle. This binary AST is the "program" that the GLSL threads will evaluate, and new AST nodes created at runtime (e.g., by `cons`) will use the same representation on a per-thread heap.

## 2.1. Sexpr Node Representation (Used for Global Program AST and Per-Thread Heap)

A `vec2` or `vec4` can be used per node, with one component as the primary type tag. All values manipulated by the Scheme program are Sexpr nodes.

*   **Primary Type Tags (Mapping to `Sexpr` ADT from `sexpr_types.flow`):**
    *   `TAG_SSBOOL`: e.g., 1.0
    *   `TAG_SSCONSTRUCTOR`: e.g., 2.0
    *   `TAG_SSDOUBLE`: e.g., 3.0
    *   `TAG_SSINT`: e.g., 4.0
    *   `TAG_SSLIST`: e.g., 5.0 (used for function calls in AST, and for list data)
    *   `TAG_SSOPERATOR`: e.g., 6.0 (typically part of an `SSList` representing a call)
    *   `TAG_SSSPECIALFORM`: e.g., 7.0
    *   `TAG_SSSTRING`: e.g., 8.0
    *   `TAG_SSVARIABLE`: e.g., 9.0 (for variable references in AST)
    *   `TAG_SSVECTOR`: e.g., 10.0
    *   `TAG_NIL`: e.g., 11.0 (representing the empty list, distinct from an empty `SSList` node if needed, or `SSList` with 0 children can be nil)
    *   `TAG_UNDEFINED`: e.g., 0.0 (for errors or uninitialized)

*   **Runtime-Specific Structures (also represented as or composed of Sexpr nodes):**
    *   **Closure**: `TAG_CLOSURE` (e.g., 12.0). Data: `[TAG_CLOSURE, ptr_to_SLambda_SSSpecialForm_AST_node, ptr_to_captured_env_SSList_node]`. The captured environment itself is an S-expression (e.g., an association list like `(SSList ((var1 val1) (var2 val2) ...))`) stored on the thread's heap.
    *   **Built-in Function ID**: `TAG_BUILTIN_FN` (e.g., 13.0). Data: `[TAG_BUILTIN_FN, builtin_function_id]`

*   **Sexpr Node Data Structure Examples (Global Program AST & Per-Thread Heap):**
    *   `SSBool(b)`: `[TAG_SSBOOL, (b ? 1.0 : 0.0)]`
    *   `SSDouble(d)`: `[TAG_SSDOUBLE, d]`
    *   `SSInt(i)`: `[TAG_SSINT, float(i)]`
    *   `SSString("str")`: `[TAG_SSSTRING, const_pool_idx_for_str, strlen("str")]`
    *   `SSConstructor("ConsName")`: `[TAG_SSCONSTRUCTOR, const_pool_idx_for_ConsName]`
    *   `SSVariable("varName")`: `[TAG_SSVARIABLE, const_pool_idx_for_varName]`
    *   `SSList([child1, child2, ...])` / `SSVector([child1, child2, ...])`:
        *   `[TAG_SSLIST_OR_SSVECTOR, child_array_start_idx, num_children]`
        *   `child_array_start_idx` points to an array of pointers: `[ptr_to_child1_node, ptr_to_child2_node, ...]`. These pointers reference other Sexpr nodes either in the global AST or on the per-thread heap.
    *   `SSSpecialForm(form_enum, [child1, ...])`:
        *   `[TAG_SSSPECIALFORM, special_form_enum_id, child_array_start_idx, num_children]`
        *   `special_form_enum_id` maps to `SIf`, `SLambda`, etc.

A separate **Constant Pool** (flat numerical array) will store all unique strings (for variable names, constructors, string literals). This pool is global and read-only.