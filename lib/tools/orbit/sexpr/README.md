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

### Built-in Functions

- Arithmetic: `+`, `-`, `*`, `/`
- Comparison: `=`
- List operations: `list`, `car`, `cdr`, `cons`
- I/O: `print`

## Extending the Language

This implementation is intentionally minimal but can be extended with:

- More data types (pairs, vectors, etc.)
- Additional special forms (let, cond, etc.)
- Full lambda support with closures
- Tail call optimization
- Macros
- A standard library