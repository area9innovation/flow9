# S-Expression-based Scheme-like Language

This is a simple Scheme-like language implemented in Flow9. It provides a minimal but powerful environment for working with S-expressions, supporting core Scheme features like pattern matching, quasiquotation, and functional programming principles.

## Running the Interpreter

```bash
flowcpp sexpr.flow -- tests/file.sexp
```

## Core Features

| Syntax Pattern                                     | Surface Syntax Example |
|-----------------------------------------------------|-------------------------|
| `(if test then else)`                               | `(if (> x 0) x (- x))`   |
| `(lambda (param*) body...)`                         | `(lambda (x) (+ x 1))`   |
| `(set! name exp)`                                   | `(set! x 10)`            |
| `(begin exp1 exp2 ...)`                             | `(begin (println "A") (println "B"))` |
| `(and exp1 exp2 ...)`                               | `(and (> x 0) (< x 10))` |
| `(or exp1 exp2 ...)`                                | `(or (= x 0) (= x 1))`   |
| `(let ((name1 exp1) (name2 exp2) ...) body...)`      | `(let ((x 1) (y 2)) (+ x y))` |
| `(letrec ((name1 exp1) (name2 exp2) ...) body...)`   | `(letrec ((f (lambda (n) (if (= n 0) 1 (* n (f (- n 1))))))) (f 5))` |
| `(quote exp)`                                       | `(quote 1+2)`                  |
| `(quasiquote exp)`                                  | `(quasiquote +(1 (unquote a)))`   |
| `(unquote exp)`                                     | `(unquote a)`                  |
| `(unquote-splicing exp)`                            | `(unquote-splicing ls)`    |
| `(match value pattern1 result1 pattern2 result2 ...)` | `(match x 0 'zero 1 'one else 'other)` |
| `(match value ((pattern condition) result) ...)` | `(match x ((n 0 (> n 5)) 'big) n 'small)` |
| `(define name exp)` <br> `(define (name param*) body...)` | `(define x 42)` <br> `(define (f x) (+ x 1))` |

## Differences from Scheme

We use `//` and `/* ... */` for comments, and not `;`.
We use words for quotations, and not the shorthand syntax.
We do not have a sequence at the top level, so you have to wrap with `(begin ...)` or similar.

TODO: Scheme have these as well. Not sure if we need them.
| Syntax Pattern                                     | Surface Syntax Example |
|-----------------------------------------------------|-------------------------|
| `(let* ((name1 exp1) (name2 exp2) ...) body...)`     | `(let* ((x 1) (y (+ x 2))) y)` |
| `(cond (test exp...) (test exp...) ... [else exp...])` | `(cond [(> x 0) 'pos] [(< x 0) 'neg] [else 'zero])` |
| `(case key ((val1 val2 ...) exp...) ... [else exp...])` | `(case x [(1 2) 'small] [(3 4) 'large] [else 'unknown])` |
| `(do ((var1 init1 step1) (var2 init2 step2) ...) (test expr...) body...)` | `(do ((i 0 (+ i 1))) ((= i 10) 'done) (display i))` |

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

;; Arrays
[1 2 3]   ; an array of numbers
["a" "b"] ; an array of strings

;; Symbols
x         ; a variable
Point     ; a constructor (starts with uppercase)
+         ; an operator
```

### Special Forms

#### Define

Defines a variable in the global environment:

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
(and expr1 expr2 ...)  ; Short-circuit AND - evaluates expressions from left to right
											; until one returns false or all are evaluated

(or expr1 expr2 ...)  ; Short-circuit OR - evaluates expressions from left to right
											; until one returns true or all are evaluated
```

#### Quote

Prevents evaluation of an expression:

```scheme
(quote (1 2 3))
```

#### Lambda

Defines an anonymous function (closure):

```scheme
(lambda (param1 param2) body)
```
This creates a closure, capturing the surrounding environment's free variables.

```scheme
(closure ((x 2)(y 3)) (lambda () (+ x y))) ; => 5
```

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

Conditional pattern matching is also supported by using a list of three elements where:
- First element is the pattern to match
- Second element is ignored (reserved for future use)
- Third element is a condition to evaluate after binding the variables

```scheme
(match value
	;; Pattern with condition: only matches if x > 5 after binding
	((x 0 (> x 5)) "x is greater than 5")
	;; Regular pattern without condition
	x "x is 5 or less")
```

If a pattern doesn't have a condition (not a list with 3 elements), it's treated as implicitly having a `true` condition.

Pattern matching supports:
- Variable binding (like `x` which binds to a value)
- Wildcard patterns (`_` which matches anything without binding)
- List patterns (like `(x y z)` which matches a list of exactly 3 items)
- Literal patterns (like numbers, strings, booleans that match only equal values)
- Constructor patterns (`ConstructorName`)
- Conditional patterns as described above

### Conditional Pattern Matching

The `match` form supports conditional pattern matching, where a pattern can specify an additional condition that must be satisfied after the pattern successfully matches and variables are bound:

```scheme
;; Match a value and apply conditions to the bound variables
(define classify-number
	(lambda (n)
		(match n
			;; Pattern with condition: only matches if n > 100
			(n (> n 100) "large number")
			;; Pattern with condition: only matches if n is even
			(n (even n) "even number")
			;; Pattern with condition: only matches if n is odd
			(n (odd n) "odd number")
			;; Default pattern (no condition needed)
			(n "other number"))))

(classify-number 120)  ; => "large number"
(classify-number 42)   ; => "even number"
(classify-number 7)    ; => "odd number"
(classify-number -5)   ; => "odd number"
```

Conditional patterns use the following format: `(pattern condition result)`

With this format:
1. The first element is the pattern to match against the value
2. The second element is the condition to evaluate after binding variables
3. The third element is the result to return if both the pattern matches AND the condition is true

When using conditional patterns:
- The pattern is first matched against the value, binding any variables
- If pattern matching succeeds, the condition is evaluated in an environment containing the bound variables
- If the condition evaluates to `true`, the result is evaluated and returned
- If the condition evaluates to `false`, evaluation continues with the next pattern

Regular (non-conditional) patterns use the format: `(pattern result)`

You can mix conditional and non-conditional patterns in the same `match` expression:

```scheme
;; Complex pattern matching with conditions on different types
(define complex-match
	(lambda (val)
		(match val
			;; Match strings with specific condition
			(s (and (isString s) (= (strlen s) 5)) "5-letter string")
			;; Match lists with specific length
			(lst (and (isArray lst) (= (length lst) 2)) "2-element list")
			;; Match numbers in specific range
			(n (and (isInt n) (> n 0) (< n 100)) "positive number < 100")
			;; Default
			(x (+ "other: " (astname x))))))

(complex-match "hello")    ; => "5-letter string"
(complex-match "hi")       ; => "other: String"
(complex-match (list 1 2)) ; => "2-element list"
(complex-match 42)         ; => "positive number < 100"
(complex-match 200)        ; => "other: Int"
(complex-match true)       ; => "other: Bool"
```

This feature significantly enhances the expressiveness of pattern matching in SEXP, allowing for more complex conditional logic to be expressed in a concise and readable form.

### Quasiquotation

Quasiquotation allows building templates with parts that are evaluated:

```scheme
(quasiquote 1 2 (unquote x))  ;
(quasiquote 1 2 (unquote x))       ; x is evaluated in the template
(quasiquote 1 (unquote-splicing lst) 3)    ; Comma-at (,@) is replaced with # in our implementation
```

TODO: Add examples

## Standard Library (`sexpr_stdlib.flow`)

The language includes an extensive set of built-in functions imported from the Orbit runtime:

@import `sexpr_stdlib.flow`

### Arithmetic and Mathematical Functions

- Basic operators: `+`, `-`, `*`, `/`, `=`, `!=`, `<`, `<=`, `>`, `>=`
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

- Basic I/O: `println`
- File operations: `getFileContent`, `setFileContent`

### Logic Operations

- Boolean logic: `not`, `and` (short-circuit AND), `or` (short-circuit OR)

### Utility Functions

- Reflection: `astname` (returns the type of an expression), `varname` (extracts name from variables/constructors)
- Formatting: `prettySexpr` (formats S-expressions as readable strings)
- Parsing: `parseSexpr` (parses S-expressions from strings)
- Command line: `getCommandLineArgs` (returns command-line arguments as a list)
- Unique IDs: `uid` (generates unique IDs with prefixes)

## Integration with OGraph

S-expressions can be integrated with OGraph (Orbit Graph) data structures for symbolic computation and optimization. The two main operations are:

1. Converting S-expressions to OGraph nodes (`sexp2OGraphWithSubstitution`)
2. Converting OGraph nodes back to S-expressions (`ograph2Sexpr`)

### Adding S-expressions to OGraph

The protocol for adding an S-expression to an OGraph is defined in `sexp2OGraphWithSubstitution`:

```flow
sexp2OGraphWithSubstitution(graph : OGraph, expr : Sexpr, varToEclass : Tree<string, int>) -> int
```

This function:
- Takes an OGraph to add the expression to
- Takes an S-expression to convert
- Takes a mapping from variable names to existing eclass IDs for substitution
- Returns the eclass ID of the added expression

#### Type Annotations

The function handles type annotations in the form `(: expr Domain)` by:
1. Processing the expression and getting its eclass ID
2. Processing the domain and getting its eclass ID
3. Adding the domain to the "belongs to" field of the expression's node using `addBelongsToONode`

#### S-expression Type Mapping

Different S-expression types are mapped to different OGraph node types:

| S-expression Type | OGraph Node Type | Notes |
|-------------------|------------------|-------|
| SSList (general)  | "List"           | Each child is processed recursively |
| SSList with ":"  | Special handling | Processed as type annotation |
| SSVariable        | "Identifier"     | May be substituted based on varToEclass |
| SSConstructor     | "Constructor"    | Value stored as string |
| SSOperator        | "Operator"       | Value stored as string |
| SSInt             | "Int"            | Value stored as OrbitInt |
| SSDouble          | "Double"         | Value stored as OrbitDouble |
| SSString          | "String"         | Value stored as OrbitString |
| SSBool            | "Bool"           | Value stored as OrbitBool |
| SSVector          | "Vector"         | Each child is processed recursively |
| SSSpecialForm     | "SpecialForm"    | Form name added as first child |

### Extracting S-expressions from OGraph

To convert an OGraph node back to an S-expression, use:

```flow
ograph2Sexpr(graph : OGraph, nodeId : int) -> Sexpr
```

Or to extract from a registered OGraph:

```flow
extractOGraphSexpr(graphName : string, nodeId : int, tracing : bool) -> Sexpr
```

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

## OGraph Quasiquote Implementation Roadmap

Our current `evaluateOGraphQuasiquote` implementation in `ograph_sexpr_quasi.flow` only provides a partial implementation of quasiquotation. The current features supported are:

- `(unquote ...)` evaluation
- Constant sub-expression folding in operator calls
- Basic (non-functional) stubs for `let` and `define`
- Simple identifier lookups in the existing environment

The following is a structured plan to implement the remaining features needed for full quasiquotation support in the OGraph representation:

### 1. Quasiquote Proper
- [ ] Implement top-level `(quasiquote ...)` detection
- [ ] Create a quasiquote depth tracker that increments/decrements appropriately
- [ ] Only evaluate unquotes at the correct depth (depth=1)

### 2. Unquote-Splicing
- [ ] Complete the implementation of `(unquote-splicing ...)`
- [ ] Correctly splice evaluated lists into parent lists/vectors
- [ ] Handle nested splicing operations

### 3. Quote
- [ ] Implement `(quote ...)` to prevent evaluation of its contents
- [ ] Preserve quoted expressions as literal syntax

### 4. Control Flow Special Forms
- [✅] Implement `evaluateIfNode` with proper condition evaluation and branch selection
- [✅] Implement `evaluateAndNode` with short-circuit semantics
- [✅] Implement `evaluateOrNode` with short-circuit semantics
- [✅] Implement `evaluateBeginNode` to evaluate expressions in sequence

### 5. Local Bindings
- [ ] Update `evaluateLetNode` to properly extend the environment
- [ ] Implement `let*` with sequential bindings
- [ ] Implement `letrec` with mutually recursive bindings
- [ ] Fix `evaluateDefineNode` to actually update the environment

### 6. Lambda & Closures
- [ ] Preserve lambda syntax inside quasiquote
- [ ] Properly handle nested unquotes within lambda bodies
- [ ] Support closure creation and variable capture

### 7. Pattern Matching
- [ ] Implement `evaluateMatchNode` to call the real matcher
- [ ] Convert match expressions to/from Sexpr for evaluation
- [ ] Handle pattern evaluation and condition testing

### 8. Import & Eval
- [ ] Implement `evaluateImportNode` to load external files
- [ ] Implement `evaluateEvalNode` for runtime evaluation
- [ ] Properly convert between OGraph and Sexpr representations

### 9. Type Annotations
- [ ] Handle `(: expr Domain)` syntax
- [ ] Evaluate both the expression and domain
- [ ] Set up proper `belongsTo` relationships in the OGraph

### 10. User-Defined Functions
- [ ] Allow evaluation of identifiers that resolve to closures
- [ ] Support function application of user-defined functions
- [ ] Handle argument evaluation and environment extension

### 11. Testing & Validation
- [ ] Create test cases for each special form
- [ ] Validate against standard Sexpr quasiquote implementation
- [ ] Add tracing support for debugging complex cases
- [ ] Document known limitations and edge cases

Implementing these features will provide full quasiquotation capabilities in the OGraph representation, matching the semantics of our standalone S-expression evaluator. Each task should be implemented incrementally, with testing between steps to ensure correct behavior.
