# Orbit Language: A Comprehensive Introduction

## 1. What is Orbit?

Orbit is a domain-unified rewriting engine that bridges mathematical formalism and practical programming. It is a functional language designed to work with abstract syntax trees (ASTs) and transformation rules, making it particularly powerful for program analysis, mathematical rewriting, and cross-domain transformations.

Key features of Orbit include:
- Functional programming paradigm
- Pattern matching and rewriting
- First-class support for mathematical expressions
- Abstract syntax tree (AST) manipulation
- Equivalence graphs (e-graphs) for efficient rewriting
- Domain-crossing transformations

## 2. Basic Syntax and Features

### Variables and Expressions

Orbit follows a functional programming paradigm with immutable bindings:

```orbit
// Variable binding
let x = 42;
let y = "Hello";
let z = x * 2;

// Function definition
fn add(a : int, b : int) = a + b;

// Function application
let result = add(x, z);
```

### Types

Orbit has a strong, static type system:
TODO: Not yet.

```orbit
// Basic types
let i : int = 42;
let d : double = 3.14159;
let s : string = "Hello";
let b : bool = true;

// Function with type annotations
fn calculate(x : int, y : double) -> double = i2d(x) * y;
```

### Control Flow

Orbit uses functional control structures:

```orbit
// If expressions
let max = if a > b then a else b;

// Pattern matching
expr is (
	0 => "Zero";
	1 => "One";
	n => "Other: " + i2s(n);
)
```

## 3. Functional Programming in Orbit

### Immutability

All variables in Orbit are immutable - once bound, they cannot be changed:

```orbit
let x = 5;
// x = 6;  // ERROR: Cannot reassign to immutable binding
```

### Functions as First-Class Citizens

Functions can be stored in variables, passed as arguments, and returned from other functions:

```orbit
// Function stored in a variable
let increment = \x . x + 1;

// Higher-order function
fn apply(f, x) = f(x);
let result = apply(increment, 5);  // Returns 6
```

### Recursion

Orbit uses recursion instead of loops for iteration:

```orbit
// Sum the numbers from 1 to n
fn sum(n : int) -> int =
	if (n <= 0) 0
	else n + sum(n - 1);
```

## 4. Mathematical Expressions and Notation

Orbit supports rich mathematical notation, inspired by AsciiMath:

```orbit
// Standard arithmetic
let result = (x + y) * (z - w) / 2^n;

// Set operations
let union = A ∪ B;
let intersection = A ∩ B;

// Logic operations
let conjunction = p && q;  // Or p ∧ q
let disjunction = p || q;  // Or p ∨ q

// Quantifiers
let forallStatement = ∀ x, y: x + y = y + x;
let existsStatement = ∃ x: x^2 = 2;

// Function composition
let fog = f ∘ g;

// Domain navigation operators
// These operators allow working with the domain hierarchy and type paths
let leafPath = n ⋯ Type;     // Path from leaf type n up to Type domain (n binds to most specific type)
let upPath = n ⋰ Type;      // Move up from n in domain hierarchy to Type
let downPath = Type ⋱ n;    // Move down from Type in domain hierarchy to n

// Example: For value 1, the most specific leaf type is Int(32)
1 : n ⋯ Type;              // n binds to Int(32), which has path to Type via PrimitiveType
```

## 5. Pattern Matching and Rewriting

One of Orbit's most powerful features is its pattern matching and rewriting system:

```orbit
// Simple pattern matching
expr is (
	a + 0 => a;                 // Addition with zero
	a * 1 => a;                 // Multiplication by one
	a * 0 => 0;                 // Multiplication by zero
	a + b => b + a if a > b;    // Canonicalization (ordering terms)
	_ => expr;                  // Default case: unchanged
);

// Rewrite rules
a + b => b + a;               // Commutativity of addition
(a * b) * c => a * (b * c);   // Associativity of multiplication
```

## 6. AST Manipulation, Quoting, and Metaprogramming

### Working with AST

Orbit has first-class support for manipulating abstract syntax trees (ASTs), which is essential for program analysis, transformation, and rewriting:

```orbit
// Define a function that expects an AST
fn simplify(expr : ast) =
	expr is (
		a + 0 => a;
		0 + a => a;
		a * 1 => a;
		1 * a => a;
		a * 0 => 0;
		0 * a => 0;
		x => x;
	);

// Use with unevaluated expression
let result = simplify(x * 0);  // Returns 0 regardless of x's value
```

The `ast` annotation tells Orbit not to evaluate the argument before passing it to the function. This allows functions to operate on the syntactic structure rather than the evaluated value.

### S-Expression Compatible Quoting

Orbit supports S-expression compatible quoting syntax, which provides a powerful way to work with code as data:

```orbit
// Quote - prevents evaluation, returning the AST as data
let expr1 = '(x + y * z);

// Quasiquote - like quote but allows selective evaluation via unquote
let y = 5;
let expr2 = quasiquote (x + unquote y * z);
// Results in the AST for (x + 5 * z)

// Unquote-splicing - evaluates to a list and splices the results
let args = [a, b, c];
let expr3 = quasiquote (f(unquote-splicing args));
// Results in the AST for f(a, b, c)
```

These quoting forms align directly with S-expression semantics:

1. `'expr` is equivalent to `(quote expr)` in Scheme
2. \`expr or `quasiquote expr` is equivalent to the quasiquote in Scheme
3. `$ expr` or `unquote expr` is equivalent to unquote in Scheme
4. `$* expr` or `unquote-splicing expr` is equivalent to unquote-splicing in Scheme

### Evaluation

Orbit provides an `eval` function to evaluate AST expressions:

```orbit
// Quote an expression
let expr = '(2 + 3 * 4);

// Evaluate the expression
let result = eval(expr);  // Returns 14
```

### Pretty Printing

The `prettyOrbit` function displays AST expressions in a readable format, which is invaluable for debugging and displaying results:

```orbit
// Create an AST expression using quote
let expr = '(a * (b + c));

// Print the expression
println("Expression: " + prettyOrbit(expr));
// Output: "Expression: a * (b + c)"
```

### Metaprogramming Example

```orbit
// Generate a function that computes the n-th power of x
fn make_power_function(n : int) -> ast =
	if (n == 0) '
		(\x -> 1)
	else if (n == 1) '
		(\x -> x)
	else
		quasiquote
			(\x -> x * unquote (make_power_function(n - 1)) (x));

// Create a function that computes x³
let cube = eval(make_power_function(3));

// Use the generated function
let result = cube(4);  // Returns 64
```

These tools work together to provide a powerful system for symbolic computation and metaprogramming:
1. Quoting allows you to capture code as data
2. Quasiquoting with unquote enables template-based code generation
3. Evaluation lets you execute dynamically generated code
4. Pretty printing displays expressions in a readable format

## 7. OGraphs: Equivalence Graphs

Orbit includes a powerful OGraph system for working with equivalence graphs:

```orbit
// Create a new ograph
let graph = makeOGraph("my_graph");

// Add nodes to the graph
let nodeId1 = addNodeToOGraph(graph, "math", x + y);
let nodeId2 = addNodeToOGraph(graph, "math", y + x);

// Merge nodes to establish equivalence
let merged = mergeOGraphNodes(graph, nodeId1, nodeId2);

// Add domain annotations
addDomainToNode(graph, nodeId1, "Commutative");

// Get domains that a node belongs to
let domains = getONodeBelongsTo(graph, nodeId1);  // Returns [domainId1, domainId2, ...]

// Extract a node
let expr = extractOGraphNode(graph, nodeId1);

// Print the graph
printOGraph(graph);
```

OGraphs allow you to:
1. Represent multiple equivalent expressions efficiently
2. Cross domain boundaries (e.g., between mathematical notation and programming language syntax)
3. Apply rewrite rules across an entire equivalence class
4. Extract optimal representations based on cost models
5. Track and query domain memberships to understand semantic properties of nodes

## 8. Example: Symbolic Differentiation

Here's a complete example that demonstrates the power of Orbit for symbolic mathematics:

```orbit
// Symbolic differentiation function
fn diff(expr : ast, x : ast) -> ast =
	expr is (
		// Constants differentiate to zero
		n => 0 if !containsVar(n, x);

		// The derivative of x with respect to x is 1
		x => 1;

		// Sum rule: d/dx(u + v) = d/dx(u) + d/dx(v)
		a + b => diff(a, x) + diff(b, x);

		// Sum rule (generalized): d/dx(u + v + w + ...) = d/dx(u) + d/dx(v) + d/dx(w) + ...
		`+`(terms, ...) => `+`(map(terms, \t -> diff(t, x)), ...);

		// Product rule: d/dx(u * v) = u * d/dx(v) + v * d/dx(u)
		a * b => a * diff(b, x) + b * diff(a, x);

		// Power rule: d/dx(u^n) = n * u^(n-1) * d/dx(u)
		a ^ n => n * (a ^ (n - 1)) * diff(a, x) if !containsVar(n, x);

		// Default: can't differentiate
		_ => error("Cannot differentiate: " + prettyOrbit(expr));
	);

// Helper function to check if an expression contains a variable
fn containsVar(expr : ast, var : ast) -> bool =
	expr is (
		var => is_var(var);
		a + b => containsVar(a, var) || containsVar(b, var);
		a * b => containsVar(a, var) || containsVar(b, var);
		a ^ b => containsVar(a, var) || containsVar(b, var);
		_ => false;
	);

// Example usage
let f = x^2 + 3*x + 5;
let df_dx = diff(f, x);
println("f(x) = " + prettyOrbit(f));
println("f'(x) = " + prettyOrbit(df_dx));

// f(x) = x^2 + 3*x + 5
// f'(x) = 2*x^1 + 3
```

## Conclusion

Orbit provides a powerful platform for working with symbolic expressions, mathematical rewriting, and cross-domain transformations. Its combination of functional programming, pattern matching, and first-class AST support makes it uniquely suited for tasks like:

- Symbolic mathematics
- Program transformation and optimization
- Domain-specific language implementation
- Formal verification
- Mathematical theorem proving

By bridging the gap between mathematical formalism and practical programming, Orbit enables new approaches to challenging computational problems.
