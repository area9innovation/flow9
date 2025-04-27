# S-Expression-based Scheme-like Language

This is a simple Scheme-like language implemented in Flow9. It provides a minimal but powerful environment for working with S-expressions, supporting core Scheme features like pattern matching, quasiquotation, and functional programming principles.

## Running the Interpreter

```bash
flowcpp sexpr_driver.flow
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
Point     ; a constructor
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

Defines an anonymous function:

```scheme
(lambda (param1 param2) body)
```

#### Eval

Evaluates an expression:

```scheme
(eval expression)
```

### Pattern Matching

One of the most powerful features is pattern matching, which allows decomposing data structures and binding parts to variables:

```scheme
(match value
	pattern1 result1
	pattern2 result2
	...)
```

Example:

```scheme
(match '(1 2 3)
	(x y z) (+ x y z))  ; => 6
```

Pattern matching supports:
- Variable binding (like `x` which binds to a value)
- Wildcard patterns (`_` which matches anything without binding)
- List patterns (like `(x y z)` which matches a list of exactly 3 items)
- Literal patterns (like numbers, strings, booleans that match only equal values)

### Quasiquotation

Quasiquotation (backtick) allows building templates with parts that are evaluated:

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

## Standard Library

The language includes an extensive set of built-in functions imported from the Orbit runtime:

### Arithmetic and Mathematical Functions

- Basic operators: `+`, `-`, `*`, `/`, `=`
- Mathematical functions: `abs`, `iabs`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`
- More math: `sqrt`, `exp`, `log`, `log10`
- Rounding: `floor`, `ceil`, `round`, `dfloor`, `dceil`, `dround`
- Number properties: `sign`, `isign`, `even`, `odd`, `mod`, `dmod`, `factorial`, `gcd`, `lcm`

### List Operations

- Core list functions: `list`, `car`, `cdr`, `cons`
- Advanced list manipulation: `length`, `index`, `subrange`, `reverse`

### String Operations

- Basic string functions: `strlen`, `substring`, `strIndex`, `strContainsAt`
- String transformations: `parseHex`, `unescape`, `escape`, `strGlue`, `capitalize`, `decapitalize`

### Type Conversions

- Convert between types: `i2s`, `d2s`, `i2b`, `b2i`, `s2i`, `s2d`

### Type Checking

- Type predicates: `isBool`, `isInt`, `isDouble`, `isString`, `isArray`

### I/O Operations

- Basic I/O: `print`

### Logic Operations

- Boolean logic: `not`, `&&` (short-circuit AND), `||` (short-circuit OR)

## Implementation Details

### First-Class Functions

All functions in the standard library can be used as first-class values, meaning they can be passed as arguments to other functions.

### Runtime Function Registry

Functions are centrally registered with their arity in a runtime function registry, allowing for:
- Consistent arity checking
- Easy extension with new functions
- Simplified evaluation logic

### Utility Functions

A set of utility functions provide standardized type extraction and conversion:
- `getSBool`: Extract a boolean value from any S-expression
- `getSInt`: Extract an integer value from any S-expression
- `getSDouble`: Extract a double value from any S-expression
- `getSString`: Extract a string value from any S-expression

## Extending the Language

This implementation is intentionally minimal but can be extended with:

- More data types (pairs, vectors, etc.)
- Additional special forms (let, cond, etc.)
- Full lambda support with closures
- Tail call optimization
- Macros

### Adding New Functions

To add a new function to the standard library:
1. Define the function in `sexpr_stdlib.flow`
2. Add it to the runtime function registry in `getRuntimeFunctions()`
3. The centralized arity checking will be applied automatically