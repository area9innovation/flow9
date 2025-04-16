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
let d : double = 3.14;
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

### Sequence Operations

Orbit provides two operators for sequencing expressions:

- Semicolon (`;`) - The traditional sequence operator
- Comma (`,`) - Alternative sequence operator that reduces the need for parentheses

```orbit
// Using semicolons with required parentheses
if a then (b; c; d) else (f; g; h); i

// Using commas without parentheses - more concise
if a then b, c, d else f, g, h; i
```

The comma operator makes code more readable by eliminating unnecessary parentheses while preserving the same execution sequence. Both operators perform the same function (executing statements in sequence), but the comma operator is particularly useful in control structures like if-then-else statements.

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
let increment = \x -> x + 1;

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

## 6. AST Manipulation, Evaluation, and Pretty Printing

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

### Evaluation

Orbit provides an `eval` function to evaluate AST expressions:

```orbit

// Create an AST without evaluating
fn quote(x : ast) = x;
let expr = quote(2 + 3 * 4);

// Evaluate the expression
let result = eval(expr);  // Returns 14
```

### Pretty Printing

The `prettyOrbit` function displays AST expressions in a readable format, which is invaluable for debugging and displaying results:

```orbit
// Create an AST expression
fn quote(x : ast) = x;
let expr = quote(a * (b + c));

// Print the expression
println("Expression: " + prettyOrbit(expr));
// Output: "Expression: a * (b + c)"
```

These three tools work together to provide a powerful system for symbolic computation:
1. AST manipulation allows you to transform expressions structurally
2. Evaluation computes final results when needed
3. Pretty printing displays expressions in a readable format

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
		var => true;
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
