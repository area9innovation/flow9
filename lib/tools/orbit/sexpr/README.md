# S-Expression-based Scheme-like Language

This is a simple Scheme-like language implemented in Flow9. It provides a minimal but powerful environment for working with S-expressions, supporting core Scheme features like pattern matching, quasiquotation, and functional programming principles.

## Running the Interpreter

```bash
flowcpp sexpr.flow -- tests/file.sexp
```

## Core Features

### Basic Values

```scheme
;; Numbers
42        ; integers
3.14      ; doubles

;; Booleans
true      ; true value
false     ; false value

;; Strings
"hello"   ; a string

;; Symbols
x         ; a variable
Point     ; a constructor (starts with uppercase)
+         ; an operator
```

### Special Forms

#### Define

Defines a variable in the current environment:

```scheme
(define x 10)
```

#### If

Conditional expression:

```scheme
(if condition then-expr else-expr)
```

#### Logical Operators

Short-circuit logical AND and OR operators:

```scheme
(&& expr1 expr2 ...)  ; Short-circuit AND - evaluates expressions from left to right
											; until one returns false or all are evaluated

(|| expr1 expr2 ...)  ; Short-circuit OR - evaluates expressions from left to right
											; until one returns true or all are evaluated
```

#### Quote

Prevents evaluation of an expression:

```scheme
'(1 2 3)  ; equivalent to (quote (1 2 3))
```

#### Lambda

Defines an anonymous function (closure):

```scheme
(lambda (param1 param2) body)
```
This creates a closure, capturing the surrounding environment's free variables.

#### Import

Imports definitions from another SEXP file:

```scheme
(import "path/to/file")
```

If no extension is provided, `.sexp` is appended. The interpreter searches the current directory and a predefined library path.

#### Eval

Evaluates an expression:

```scheme
(eval expression)
```

#### Match

Performs pattern matching against a value:

```scheme
(match value
	pattern1 result1
	pattern2 result2
	...)
```

Pattern matching supports:
- Variable binding (like `x` which binds to a value)
- Wildcard patterns (`_` which matches anything without binding)
- List patterns (like `(x y z)` which matches a list of exactly 3 items)
- Literal patterns (like numbers, strings, booleans that match only equal values)
- Constructor patterns (`ConstructorName`)

### Quasiquotation

Quasiquotation (backtick `\``) allows building templates with parts that are evaluated:

```scheme
`(1 2 ,x)       ; Comma (,) is replaced with $ in our implementation
`(1 2 $x)       ; x is evaluated in the template
`(1 ,@lst 3)    ; Comma-at (,@) is replaced with # in our implementation
`(1 #lst 3)     ; lst (if it's a list) is spliced into the template
```

Examples:

```scheme
(define x 10)
`(1 $x 3)   ; => (1 10 3)

(define lst '(2 3))
`(1 #lst 4) ; => (1 2 3 4)
```

## Standard Library (`sexpr_stdlib.flow`)

The language includes an extensive set of built-in functions imported from the Orbit runtime:

@import `sexpr_stdlib.flow`

### Arithmetic and Mathematical Functions

- Basic operators: `+`, `-`, `*`, `/`, `=`
- Mathematical functions: `abs`, `iabs`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`
- More math: `sqrt`, `exp`, `log`, `log10`
- Rounding: `floor`, `ceil`, `round`, `dfloor`, `dceil`, `dround`
- Number properties: `sign`, `isign`, `even`, `odd`, `mod`, `dmod`, `gcd`, `lcm`

### List Operations

- Core list functions: `list`, `car`, `cdr`, `cons`
- Advanced list manipulation: `length`, `index`, `subrange`, `reverse`
- Higher-order functions defined in `lib/array.sexp`: `map`, `filter`, `fold`, `mapi`, `filteri`, `foldi`, `take`, `tail`, `tailFrom`, `contains`, `exists`, `forall`, `arrayPush`, `removeFirst`, `removeIndex`.

### String Operations

- Basic string functions: `strlen`, `substring`, `strIndex`, `strContainsAt`
- String transformations: `parseHex`, `unescape`, `escape`, `strGlue`, `capitalize`, `decapitalize`

### Type Conversions

- Convert between types: `i2s`, `d2s`, `i2b`, `b2i`, `s2i`, `s2d`

### Type Checking

- Type predicates: `isBool`, `isInt`, `isDouble`, `isString`, `isArray`

### I/O Operations

- Basic I/O: `print`, `println`
- File operations: `getFileContent`, `setFileContent`

### Logic Operations

- Boolean logic: `not`, `&&` (short-circuit AND), `||` (short-circuit OR)

### Utility Functions

- Reflection: `astname` (returns the type of an expression), `varname` (extracts name from variables/constructors)
- Formatting: `prettySexpr` (formats S-expressions as readable strings)
- Parsing: `parseSexpr` (parses S-expressions from strings)
- Command line: `getCommandLineArgs` (returns command-line arguments as a list)
- Unique IDs: `uid` (generates unique IDs with prefixes)

## Architecture and Implementation

This interpreter is built using Flow9 and follows functional programming principles.

### Core Components

*   **Parser (`sexpr.mango`, `sexpr_compiled_parser.flow`):**
    *   Defines the S-expression grammar using Mango.
    *   `sexpr.mango`: The human-readable grammar definition.
    *   `sexpr_compiled_parser.flow`: The efficient, compiled Flow9 parser generated from `sexpr.mango`. It parses input text into an `Sexpr` Abstract Syntax Tree (AST). Used by `sexpr_stdlib.parseSexpr`.
*   **AST Types (`sexpr_types.flow`):**
    *   Defines the `Sexpr` algebraic data type (ADT) which represents all possible nodes in the S-expression syntax tree (e.g., `SSInt`, `SSList`, `SSVariable`, `SSQuote`). This structure is generated based on the Mango grammar.
    @exports(/home/alstrup/area9/flow9/lib/tools/orbit/sexpr/sexpr_types.flow)
*   **Evaluation Environment (`env.flow`):**
    *   Defines the `SExpEnv` structure used during evaluation. It holds the current variable bindings (`Tree<string, Sexpr>`), a registry of runtime functions (`Tree<string, RuntimeFn>`), and the result of the last evaluation step.
    *   Also defines `RuntimeFn` (arity and implementation of built-ins) and `FnArgResult` (result of evaluating function arguments).
    @exports(/home/alstrup/area9/flow9/lib/tools/orbit/sexpr/env.flow)
*   **Evaluator (`eval_sexpr.flow`):**
    *   The core recursive evaluation logic resides in `evalSexpr`. It traverses the `Sexpr` AST and interprets its meaning based on the current `SExpEnv`.
    *   Handles basic values, variable lookups, special forms (`define`, `if`, `lambda`, `quote`, `eval`, `match`, `import`, `&&`, `||`), and function calls (both built-in and user-defined).
    @import(/home/alstrup/area9/flow9/lib/tools/orbit/sexpr/eval_sexpr.flow)
*   **Standard Library (`sexpr_stdlib.flow`):**
    *   Implements all the built-in functions (like `+`, `car`, `strlen`, `getFileContent`).
    *   Provides `getRuntimeEnv()` to create the initial environment populated with standard functions.
    *   Includes `invokeRuntimeFn` to handle arity checking and execution of built-ins.
    *   Contains the `parseSexpr` function which utilizes the compiled Mango parser.
*   **Pattern Matching (`sexpr_pattern.flow`):**
    *   Implements the logic for the `match` special form.
    *   `matchPattern` recursively attempts to match a pattern against a value, potentially binding variables to the environment.
    *   `evalMatch` orchestrates the matching process for a `match` expression.
    @exports(/home/alstrup/area9/flow9/lib/tools/orbit/sexpr/sexpr_pattern.flow)
*   **Quasiquotation (`sexpr_quasi.flow`):**
    *   Implements the logic for quasiquote (`\``), unquote (`$`), and unquote-splicing (`#`).
    *   `evalQuasiQuote` recursively traverses a quasiquoted expression, evaluating unquoted parts using a provided evaluation function.
    @exports(/home/alstrup/area9/flow9/lib/tools/orbit/sexpr/sexpr_quasi.flow)
*   **Closure Support (`sexpr_free.flow`):**
    *   Essential for implementing `lambda`.
    *   `findFreeSexprVars` analyzes an expression (like a lambda body) to determine which variables are "free" (used but not defined locally or as parameters).
    *   `createSexprBindings` creates the necessary bindings to capture the values of these free variables from the environment where the lambda is defined.
    @exports(/home/alstrup/area9/flow9/lib/tools/orbit/sexpr/sexpr_free.flow)
*   **Utilities (`utils.flow`, `pretty_sexpr.flow`):**
    *   `utils.flow`: Provides helper functions (`getSInt`, `getSBool`, etc.) for safely extracting typed values from `Sexpr` nodes during evaluation and in the standard library.
    @exports(/home/alstrup/area9/flow9/lib/tools/orbit/sexpr/utils.flow)
    *   `pretty_sexpr.flow`: Contains `prettySexpr` to convert an `Sexpr` AST back into a human-readable string representation.
    @exports(/home/alstrup/area9/flow9/lib/tools/orbit/sexpr/pretty_sexpr.flow)
*   **Main Executable (`sexpr.flow`):**
    *   The entry point (`main` function).
    *   Parses command-line arguments.
    *   Reads specified `.sexp` files.
    *   Calls `parseSexpr` to get the AST.
    *   Calls `evalSexpr` to evaluate the AST within an environment.
    *   Prints the final result using `prettySexpr`.
    @import(/home/alstrup/area9/flow9/lib/tools/orbit/sexpr/sexpr.flow)

### Code Structure

*   `/`: Contains the core Flow9 implementation files (`.flow`, `.mango`).
*   `lib/`: Contains standard library extensions written in SEXP itself (e.g., `array.sexp`).
*   `tests/`: Contains example `.sexp` files demonstrating language features.

**Important Files:**

*   `sexpr.flow`: Main program entry point.
*   `sexpr.mango`: Grammar definition.
*   `sexpr_types.flow`: AST definition.
*   `eval_sexpr.flow`: Core evaluation logic.
*   `sexpr_stdlib.flow`: Built-in function implementations.
*   `env.flow`: Environment structure definition.

**Entry Point and Execution Flow:**

1.  Execution starts in `sexpr.flow::main()`.
2.  Command-line arguments (expected to be `.sexp` file paths) are processed.
3.  An initial environment is created using `sexpr_stdlib.getRuntimeEnv()`.
4.  For each input file:
    a.  The file content is read (`getFileContent`).
    b.  The content is parsed into an `Sexpr` AST using `sexpr_stdlib.parseSexpr` (which uses `sexpr_compiled_parser.flow`).
    c.  If parsing succeeds, the AST is evaluated using `eval_sexpr.evalSexpr`, updating the environment.
    d.  The result of the evaluation is printed using `pretty_sexpr.prettySexpr`.
5.  The `import` special form within `eval_sexpr.flow` recursively triggers steps 4a-4c for imported files.

### Key Abstractions

*   **`Sexpr` ADT:** The fundamental data structure representing code and data uniformly, enabling metaprogramming capabilities (like `eval`).
*   **`SExpEnv`:** Represents the evaluation context, mapping names to values and holding runtime function definitions. It's passed through and updated during recursive evaluation.
*   **Closures:** Implemented via `lambda`. When a `lambda` is evaluated, `sexpr_free.flow` identifies free variables, and `eval_sexpr.flow` creates a special `SSList` structure `(closure bindings params body)` where `bindings` stores the captured values of free variables. When the closure is called, `applyFunction` in `eval_sexpr.flow` reconstructs the captured environment before evaluating the body.
*   **Runtime Functions (`RuntimeFn`):** Built-in functions are stored in the environment's `runtime` tree, allowing them to be looked up and called efficiently with arity checking (`invokeRuntimeFn` in `sexpr_stdlib.flow`).

### Dependencies and Integration Points

*   **Flow9 Standard Libraries:** Uses `ds/tree`, `string`, `math/math`, `fs/filesystem`, `text/blueprint`, `net/url_parameter`, `runtime`.
*   **Mango Parser:** Relies on `tools/mango/mcode_lib` and the compiled parser (`sexpr_compiled_parser.flow`).
*   **File System:** Interacts via the `import` special form and the `getFileContent`/`setFileContent` standard library functions.
*   **Command Line:** Reads arguments via `net/url_parameter` in `sexpr.flow` and provides access via `getCommandLineArgs`.

### Control Flow

*   **Recursion:** Evaluation (`evalSexpr`), pattern matching (`matchPattern`), quasiquote expansion (`evalQuasiQuote`), and free variable analysis (`findFreeSexprVars`) are all implemented recursively. Many standard library functions also use recursion (e.g., list functions defined in `array.sexp`).
*   **Evaluation Strategy:** Mostly applicative order (arguments are evaluated before function application), except for special forms which control their argument evaluation (e.g., `if`, `&&`, `||`, `lambda`, `define`, `quote`).
*   **Error Handling:** Primarily done via `println` statements for reporting issues like undefined variables, type mismatches, arity errors, or file not found. Evaluation typically continues with a default value (often `SSList([])` or `false`) after an error.

### Observations and Notes

*   The interpreter is purely functional, leveraging Flow9's features like ADTs and recursion.
*   State (the environment) is managed explicitly by passing `SExpEnv` through evaluation functions and returning updated versions.
*   Closures are correctly implemented by capturing free variables at definition time.
*   Pattern matching and quasiquotation provide significant expressive power.
*   Error handling is rudimentary; a more robust system might use `Maybe` types or dedicated error structures.
*   The standard library is extensive, providing good compatibility with common Scheme operations.

## Extending the Language

This implementation is intentionally minimal but can be extended with:

- More data types (pairs, vectors, etc.)
- Additional special forms (let, let\*, letrec, cond, etc.)
- Tail call optimization (TCO) for proper recursive function calls without stack overflow.
- Macros for compile-time code generation.

### Adding New Functions

To add a new *built-in* function (implemented in Flow9):
1. Define the function's implementation logic in `sexpr_stdlib.flow`, taking `FnArgResult` and returning `Sexpr`.
2. Add a `Pair` containing the function's SEXP name and a `RuntimeFn` record (specifying arity and the implementation function) to the `functionPairs` list within `getRuntimeFunctions()` in `sexpr_stdlib.flow`.
3. Add the function name to `addStandardFns` if it should be directly available in the global environment.
4. The centralized arity checking (`invokeRuntimeFn`) will be applied automatically.
