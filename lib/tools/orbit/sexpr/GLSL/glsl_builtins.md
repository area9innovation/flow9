# Built-in Functions for GLSL Context

The GLSL AST evaluator will include a set of built-in functions. These functions are hardcoded in GLSL. When the evaluator encounters a function call where the operator evaluates to a `TAG_BUILTIN_FN` Sexpr node, it dispatches to the corresponding GLSL implementation.

All built-in functions operate on Sexpr nodes (passed as arguments, which are themselves references/pointers to Sexpr nodes) and produce a new Sexpr node (allocated on the current thread's heap slice) as their result.

The following is a list of essential built-in functions planned for the GLSL context. Special forms like `if`, `lambda`, `define`, `quote`, etc., are not listed here as they are handled by distinct logic within the main `evaluate_sexpr_node` function based on `TAG_SSSPECIALFORM`.

*   **Arithmetic & Comparison:**
    *   `+` (name in Scheme: `+`): Variadic.
        *   If all args are `SSInt`, result is `SSInt`.
        *   If any arg is `SSDouble`, all args are coerced to double, result is `SSDouble`.
        *   Type errors if non-numeric args are encountered (returns an error Sexpr).
    *   `-` (name in Scheme: `-`): Variadic (unary negate or binary subtract). Similar type rules to `+`.
    *   `*` (name in Scheme: `*`): Variadic. Similar type rules to `+`.
    *   `/` (name in Scheme: `/`): Variadic (unary invert or binary divide). Result is always `SSDouble` to handle fractional results, even with integer inputs. Handles division by zero by returning an error Sexpr.
    *   `=` (name in Scheme: `=`): Takes two Sexpr arguments. Performs structural equality check if arguments are lists/vectors. For literals, checks for type and value equality. Returns `SSBool`.
    *   `!=` (name in Scheme: `!=`): Takes two Sexpr arguments. Opposite of `=`. Returns `SSBool`.
    *   `<`, `>`, `<=`, `>=` (names in Scheme: `<`, `>`, `<=`, `>=`): Take two numeric Sexpr arguments (`SSInt` or `SSDouble`). Coerce to common type if necessary. Return `SSBool`. Type error for non-numeric.

*   **List/Vector Operations:**
    *   `list` (name in Scheme: `list`): Variadic. Takes any number of Sexpr arguments and constructs a new `SSList` Sexpr node on the heap containing references to these arguments.
    *   `car` (name in Scheme: `car`): Takes one argument, an `SSList` or `SSVector`. Returns a reference to its first element Sexpr. Error Sexpr if not a list/vector or if empty.
    *   `cdr` (name in Scheme: `cdr`): Takes one argument, an `SSList` or `SSVector`. Returns a new `SSList` or `SSVector` Sexpr on the heap containing references to all elements except the first. Error Sexpr if not a list/vector or if empty.
    *   `cons` (name in Scheme: `cons`): Takes two Sexpr arguments, `elem` and `lst`. Prepends `elem` to `lst` (if `lst` is an `SSList` or `SSVector`), returning a new `SSList` or `SSVector` on the heap. If `lst` is not a list/vector, standard Scheme behavior might be to create a dotted pair; for simplicity, this might initially be restricted or error.
    *   `concat` (name in Scheme: `concat`): Variadic. Takes multiple `SSList` or `SSVector` Sexprs. Returns a new `SSList` or `SSVector` on the heap containing all elements from the input collections.
    *   `length` (name in Scheme: `length`): Takes one Sexpr argument (`SSList`, `SSVector`, or `SSString`). Returns an `SSInt` node with the number of elements or characters.
    *   `index` (alternate names: `list-ref`, `vector-ref`): Takes an `SSList`/`SSVector` and an `SSInt` (index). Returns the Sexpr element at that index. Error Sexpr for out-of-bounds.
    *   `subrange` (alternate names: `list-subsequence`, `vector-subsequence`): Takes `SSList`/`SSVector`, `SSInt` (start), `SSInt` (count). Returns a new `SSList`/`SSVector` Sexpr from the specified subrange.
    *   `reverse` (name in Scheme: `reverse`): Takes an `SSList`/`SSVector`. Returns a new, reversed `SSList`/`SSVector` Sexpr on the heap.

*   **Type Predicates (all return `SSBool`):**
    *   `isBool` (e.g., `boolean?`)
    *   `isInt` (e.g., `integer?`)
    *   `isDouble` (e.g., `real?` or `float?`)
    *   `isString` (e.g., `string?`)
    *   `isList` (e.g., `list?`, specifically for `SSList` type)
    *   `isVector` (e.g., `vector?`)
    *   `isConstructor` (e.g., `constructor?` for `SSConstructor`)
    *   `isSymbol` (e.g., `symbol?` for `SSVariable`)
    *   `isPair` (e.g., `pair?`): Checks if an `SSList` or `SSVector` is non-empty.
    *   `isNil` (e.g., `null?`): Checks if an `SSList` or `SSVector` is empty, or if the node is `TAG_NIL`.

*   **Type Conversions:**
    *   `i2s` (`integer->string`): `SSInt` to `SSString`.
    *   `d2s` (`real->string`): `SSDouble` to `SSString`.
    *   `s2i` (`string->integer`): `SSString` to `SSInt`. Error Sexpr if conversion fails.
    *   `s2d` (`string->real`): `SSString` to `SSDouble`. Error Sexpr if conversion fails.
    *   `i2b` (`integer->boolean`): `SSInt` to `SSBool` (0 is false, non-zero is true).
    *   `b2i` (`boolean->integer`): `SSBool` to `SSInt` (false is 0, true is 1).

*   **String Operations:**
    *   `string-append` (name in Scheme: `string-append`): Variadic. Takes multiple `SSString` nodes. Returns a new `SSString` node on the heap.
    *   `substring` (name in Scheme: `substring`): Takes `SSString`, `SSInt` (start), `SSInt` (count). Returns a new `SSString` node. This new node might reference a segment of an existing string in the constant pool if feasible, or it might require allocating new character data on the heap if substrings of runtime-generated strings are common (heap allocation for string chars is generally undesirable in GLSL).
    *   `string->list` (name in Scheme: `string->list`): Takes `SSString`. Returns an `SSList` of `SSInt` nodes, where each `SSInt` is a character code.
    *   `list->string` (name in Scheme: `list->string`): Takes an `SSList` of char-code `SSInt`s. Returns a new `SSString` on the heap.

*   **Math Functions (operate on `SSDouble` or `SSInt` Sexprs, return Sexpr of same numeric type unless specified):**
    *   `abs`, `iabs`
    *   `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2` (all operate on/return `SSDouble`)
    *   `sqrt`, `exp`, `log`, `log10` (all operate on/return `SSDouble`)
    *   `floor`, `ceil`, `round` (take `SSDouble`, return `SSInt`)
    *   `dfloor`, `dceil`, `dround` (take `SSDouble`, return `SSDouble`)
    *   `sign` (takes `SSDouble`, returns `SSDouble` -1, 0, or 1)
    *   `isign` (takes `SSInt`, returns `SSInt` -1, 0, or 1)
    *   `even`, `odd` (take `SSInt`, return `SSBool`)
    *   `gcd`, `lcm` (take two `SSInt`, return `SSInt`)
    *   `mod`, `dmod` (take two `SSInt`/`SSDouble`, return `SSInt`/`SSDouble`)

*   **Boolean Logic:**
    *   `not` (name in Scheme: `not`): Takes one `SSBool` Sexpr, returns its negation as an `SSBool`.

*   **Reflection/Utilities (GPU Context Specific):**
    *   `astname` (name in Scheme: `astname`): Takes any Sexpr node. Returns an `SSString` representing its primary type tag (e.g., `"SSInt"`, `"SSList"`). Useful for debugging or type-driven logic.
    *   `prettySexpr` (name in Scheme: `prettySexpr`): Takes any Sexpr node. Formats it into a human-readable `SSString` Sexpr. This is primarily for debugging output. Its implementation in GLSL will be challenging and likely limited in formatting quality.
    *   `error` (name in Scheme: `error`): Takes one `SSString` Sexpr (the error message). Halts the execution of the current GLSL thread and ensures the error message Sexpr is written to a designated part of the thread's output buffer.

This list covers a functional core. More built-ins can be added as needed, but each adds to the GLSL shader size and complexity. The selection prioritizes operations that are fundamental or commonly used in functional programming and data manipulation. OGraph and host OS interaction functions (like file I/O from the original `sexpr_stdlib.flow`) are omitted as they don't fit the GLSL execution model.