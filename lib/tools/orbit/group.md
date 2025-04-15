# Group-Theoretic Foundations for Orbit's Rewriting Engine

## Introduction to Group Theory in Rewriting Systems

This document outlines how group theory concepts are incorporated into Orbit's native rewriting engine. Group theory provides powerful abstractions for expressing symmetries, transformations, and canonical forms in computational domains.

## Core Group-Theoretic Concepts

### 1. Symmetry Groups for Canonicalization

Operations in most domains exhibit natural symmetries that can be formalized as groups:

```orbit
fn quote(e : ast) = e;

// Define symmetry properties using domain annotations
let symmetryRules = quote(
	// Addition has symmetric group of order 2 (S₂)
	a : Real + b : Real ⊢ + : S₂;  // The + operation belongs to the S₂ symmetry group

	// Multiplication also has S₂ symmetry
	a : Real * b : Real ⊢ * : S₂;  // The * operation belongs to the S₂ symmetry group

	// Rotation operations have cyclic group structure
	rotate : C₄;  // Rotation operation belongs to cyclic group of order 4
	rotate(rotate(rotate(rotate(arr, 1), 1), 1), 1) => arr;  // Four rotations is identity
);
```

By explicitly representing these symmetries in the rewrite system, we can:
1. Automatically derive canonical forms for expressions
2. Avoid exponential blowup from enumerating all equivalent permutations
3. Share optimization rules across different domains with the same symmetry groups

### 2. Domain Hierarchies

Domains form a hierarchy that allows rule inheritance:

```orbit
let domainHierarchyRules = quote(
	// Domain hierarchy declarations using subset relation
	Integer ⊂ Rational ⊂ Real ⊂ Complex;  // Number domains form a hierarchy
	Group ⊂ AbelianGroup;  // Algebraic structure hierarchy

	// Domain hierarchy implementated as rules
	x : Integer => x : Rational;  // If x is an Integer, then x is also a Rational
	x : Rational => x : Real;     // If x is a Rational, then x is also a Real

	// Group hierarchy relationships
	S₂ ⊂ SymmetricGroup;  // Symmetric group of order 2
	C₄ ⊂ CyclicGroup;     // Cyclic group of order 4
	D₄ ⊂ DihedralGroup;   // Dihedral group of order 4
);
```

### 3. Canonicalization with Ordering

To achieve deterministic canonicalization with symmetry groups:

```orbit
let canonicalizationRules = quote(
	// S₂ symmetry (commutativity) with explicit ordering
	(a + b) : S₂ => a + b : Canonical if a <= b;
	(a + b) : S₂ => b + a : Canonical if b < a;

	// For S₃ symmetry (associative operators with 3 arguments)
	(a * b * c) : S₃ => ordered3(a, b, c);

	// Helper function that implements the explicit ordering
	ordered3(a, b, c) => a * b * c : Canonical if a <= b && b <= c;
	ordered3(a, b, c) => a * c * b : Canonical if a <= c && c <= b;
	ordered3(a, b, c) => b * a * c : Canonical if b <= a && a <= c;
	ordered3(a, b, c) => b * c * a : Canonical if b <= c && c <= a;
	ordered3(a, b, c) => c * a * b : Canonical if c <= a && a <= b;
	ordered3(a, b, c) => c * b * a : Canonical if c <= b && b <= a;
);
```

## Domain Annotations in Pattern Matching

Domain annotations serve dual purposes: constraining matches and asserting domain membership:

```orbit
let domainPatternRules = quote(
	// In patterns (LHS), domain annotations constrain matches
	a : Integer + b : Integer => a + b : Integer;  // Applies only to integers

	// In results (RHS), domain annotations add domain membership
	a : Real * b : Real => (a * b) : Real;  // Result is still a Real

	// Both constraining and asserting
	a : Field + b : Field => (a + b) : Field : Commutative;  // Asserts result has two domains

	// Negative domain match (!:) - match only if NOT in the domain
	expr !: Simplified => simplify(expr) : Simplified;  // Apply only to unsimplified expressions

	// Pattern match with entailment
	a : Prime + b : Prime ⊢ (a + b) : EvenInteger if a != 2 && b != 2;  // Sum of primes except 2 is even
);
```

## Group Action Representation

Groups act on expressions via canonical transformation patterns:

```orbit
let groupActionRules = quote(
	// S₂ acts by swapping elements
	action(S₂, [a, b]) => [b, a];

	// Cyclic group acts by rotation
	action(C₄, arr) => arr[n:] + arr[:n];

	// Dihedral group combines rotations and reflections
	action(D₄, arr) => rotate_or_reflect(arr);

	// Group composition follows group laws
	action(S₂, action(S₂, arr)) => arr : Identity;  // Double swap is identity
	action(C₄, action(C₄, action(C₄, action(C₄, arr)))) => arr : Identity;  // Four rotations is identity
);
```

## Advanced Group-Theoretic Optimizations

### 1. Functional Properties Through Group Theory

```orbit
let functionalGroupRules = quote(
	// Detect commutativity in lambda expressions
	(λ(a, b).op(a, b)) ⊢ λ : S₂ if op : S₂;  // Lambda inherits commutativity from its operation

	// Detect associativity in lambda expressions
	(λ(a, b).op(a, b)) ⊢ λ : Associative if op : Associative;

	// Map fusion when function composition is detected
	map(f, map(g, xs)) => map(λ(x).f(g(x)), xs);

	// Filter fusion when predicates have certain properties
	filter(p, filter(q, xs)) => filter(λ(x).p(x) && q(x), xs);

	// Map-filter interchange when f preserves predicate satisfaction
	map(f, filter(p, xs)) : Commutable => filter(p, map(f, xs)) if independent(f, p);
);
```

### 2. Matrix Operation Optimization

```orbit
let matrixGroupRules = quote(
	// Matrix transposition forms an involution (group of order 2)
	transpose : S₂;  // Transpose has S₂ symmetry
	transpose(transpose(A)) => A;

	// Matrix multiplication forms a monoid
	matmul : Monoid;  // Matrix multiplication has monoid structure
	matmul(A, matmul(B, C)) => matmul(matmul(A, B), C);

	// Transposition distributes over addition (homomorphism)
	transpose(A + B) => transpose(A) + transpose(B);

	// Transpose reverses order of multiplication
	transpose(matmul(A, B)) => matmul(transpose(B), transpose(A));

	// Infer group structure of composed operations
	transpose ∘ rotate90 ⊢ (transpose ∘ rotate90) : D₄;  // Forms dihedral group

	// Optimize based on combined group properties
	transpose(rotate90(transpose(rotate90(img)))) : D₄ => rotate180(img);
);
```

### 3. Optimizing Collection Operations

```orbit
let collectionRules = quote(
	// Recognize when a fold can be parallelized
	fold(op, id, xs) ⊢ fold : Parallelizable if op : Associative && op : Commutative;

	// Apply optimization based on inferred property
	fold : Parallelizable => parallel_reduce;

	// Fold-map fusion
	fold(op, init, map(f, xs)) => fold(λ(acc, x).op(acc, f(x)), init, xs);

	// Special case: sum of mapped values with constant factor
	fold(+, 0, map(λ(x).c * f(x), xs)) : Distributive => c * fold(+, 0, map(f, xs)) if c : Constant;

	// Stream operations
	stream.map(f).map(g) => stream.map(λ(x).g(f(x)));
	stream.filter(p).filter(q) => stream.filter(λ(x).p(x) && q(x));
);
```

## Using Orbit for Optimization with Group Theory

```orbit
fn main() (
	// Define a cost function that considers algebraic properties
	fn costWithGroups(expr : ast) -> double (
		expr is (
			// Operations with symmetry groups can be reordered
			a + b : S₂ => 1.0 + min(costWithGroups(a), costWithGroups(b)) + max(costWithGroups(a), costWithGroups(b))/2.0;
			a * b : S₂ => 1.2 + min(costWithGroups(a), costWithGroups(b)) + max(costWithGroups(a), costWithGroups(b))/2.0;

			// Nested associative operations
			(a + b) + c : Associative => 0.8 + costWithGroups(a) + costWithGroups(b) + costWithGroups(c);
			a + (b + c) : Associative => 0.8 + costWithGroups(a) + costWithGroups(b) + costWithGroups(c);

			// Default costing
			_ => 1.0;
		)
	)

	// Define algebraic rewrite rules with domain annotations
	let algebraRules = quote(
		// Commutativity with domain constraints
		a : Real + b : Real <=> b : Real + a : Real;
		a : Real * b : Real <=> b : Real * a : Real;

		// Associativity with domain constraints
		(a : Real + b : Real) + c : Real <=> a : Real + (b : Real + c : Real);
		(a : Real * b : Real) * c : Real <=> a : Real * (b : Real * c : Real);

		// Domain-specific optimizations
		a : Real * (b : Real + c : Real) <=> (a : Real * b : Real) + (a : Real * c : Real);

		// Domain annotations through entailment
		a : Integer + b : Integer ⊢ (a + b) : Integer;
		a : Integer * b : Integer ⊢ (a * b) : Integer;
	);

	// Example expression with domain annotations
	let expr = quote((2 : Integer * (x : Real + y : Real)) + (3 : Integer * (y : Real + x : Real)));

	// Apply optimization
	let optimized = orbit(algebraRules, costWithGroups, expr);

	// Expected result: 5 : Integer * (x : Real + y : Real)
	println("Original: " + prettyOrbit(expr));
	println("Optimized: " + prettyOrbit(optimized));
)
```

## Theoretical Foundations

Orbit's group-theoretic approach unifies several powerful mathematical frameworks:

1. **Group Theory**: For capturing symmetries and canonical forms
2. **Category Theory**: For formalizing transformations between domains  
3. **Order Theory**: For determining canonical representatives
4. **Universal Algebra**: For detecting properties like associativity and commutativity

By representing symmetry groups explicitly in the ograph structure (via domain annotations), we achieve:

1. Exponential reduction in equivalent expressions that need representation
2. Automatic discovery of optimizations that exploit symmetry
3. Transfer of optimizations across domains with isomorphic group structures
4. Inference of algebraic properties that enable non-trivial optimizations

This group-theoretic foundation significantly enhances Orbit's ability to perform deep algebraic reasoning and optimization.