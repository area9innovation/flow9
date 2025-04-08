# Group-Theoretic Foundations for Domain-Unified Rewriting

## Introduction to Group Theory in Rewriting Systems

This document extends the Domain-Unified Rewriting Engine with deeper group-theoretic foundations. Group theory provides powerful abstractions for expressing symmetries, transformations, and canonical forms in computational domains.

## Core Group-Theoretic Concepts

### 1. Symmetry Groups for Canonicalization

Operations in most domains exhibit natural symmetries that can be formalized as groups:

```
// Addition has symmetric group of order 2 (Su2082) canonicalization
+ : Su2082                      // Commutativity: a+b = b+a

// Multiplication also has Su2082 symmetry
* : Su2082                      // Commutativity: a*b = b*a

// Rotation operations have cyclic group structure
rotate : Cyclic(n)          // Rotation symmetry: rotating n times = identity
```

By explicitly representing these symmetries in the rewrite system, we can:
1. Automatically derive canonical forms for expressions
2. Avoid the exponential blowup that would result from enumerating all equivalent permutations
3. Share optimization rules across different domains that exhibit the same symmetry groups

### 2. Group Hierarchies and Action Representation

```
// Group hierarchy expressed using subset notation
Su2081 u2282 Su2082 u2282 Su2083 u2282 Su2084       // Symmetric groups form a hierarchy
Cu2082 u2282 Cu2084 u2282 Cu2088           // Cyclic groups form a hierarchy
Abelian u2282 Group         // Type hierarchies based on properties

// More interesting group hierarchies
Du2083 u2282 Du2084 u2282 Du2085           // Dihedral groups (rotations and reflections)
Au2084 u2282 Su2084                  // Alternating group is subgroup of symmetric group
Qu2088 u2282 SO(3)                // Quaternion group as subgroup of 3D rotations
```

### 3. Group Actions on Expressions

Groups act on expressions via canonical transformation patterns:

```
// Su2082 acts by swapping elements
action(Su2082, [a, b]) => [b, a]

// Cyclic group acts by rotation
action(Cu2084, arr) => arr[n:] + arr[:n]

// Dihedral group combines rotations and reflections
action(Du2084, arr) => rotate_and_possibly_reflect(arr)

// Group composition follows group laws
action(Su2082, action(Su2082, arr)) => arr  // Double swap is identity
action(Cu2084, action(Cu2084, action(Cu2084, action(Cu2084, arr)))) => arr  // Four rotations is identity
```

## Implementation: Symmetry-Based Canonicalization

To avoid exponential blowup due to commutative properties, we define symmetry groups for each domain. This allows us to canonicalize expressions based on their symmetry properties:

```
@algebra<> = @make_pattern<algebra_expr, uid, domain_expr>;

@rewrite_system<@algebra, @algebra, math, ";">(
	// Define that addition is commutative (belongs to Su2082 group)
	(a : Abelian) + (b : Abelian)  u22a2  + : Su2082;

	// Su2082 symmetry (commutativity) with explicit ordering
	(a + b) : Su2082 => a + b : Canonical if a <= b;
	(a + b) : Su2082 => b + a : Canonical if b < a;

	// For Su2083 symmetry (associative operators with 3 arguments)
	a * b * c : Su2083 => ordered3(a, b, c);

	// Helper function that implements the explicit ordering
	ordered3(a, b, c) => a * b * c : Canonical if a <= b && b <= c;
	ordered3(a, b, c) => a * c * b : Canonical if a <= c && c <= b;
	ordered3(a, b, c) => b * a * c : Canonical if b <= a && a <= c;
	ordered3(a, b, c) => b * c * a : Canonical if b <= c && c <= a;
	ordered3(a, b, c) => c * a * b : Canonical if c <= a && a <= b;
	ordered3(a, b, c) => c * b * a : Canonical if c <= b && b <= a;
);
```

The key innovation here is using explicit ordering conditions with group theoretic properties to determine canonical representations. Instead of having to define all possible permutations of operations, we simply annotate operations with their symmetry groups and define canonicalization based on a total ordering.

## Rich Group-Theoretic Rewriting Rules

Beyond simple isomorphisms like Su2082 u21d4 Cu2082, more interesting group-theoretic rewrites enable powerful optimizations:

```
@rewrite_system<@group, @group, group_expr, ";">(
	// Direct product of groups
	Su2082 u00d7 Su2082 u21d4 Du2082;    // Product of two swaps is equivalent to dihedral group of order 2
	Su2082 u00d7 Cu2084 u21d4 Du2084;    // Product of swap and 4-cycle is dihedral group of order 4

	// Semidirect product for more complex group structures
	Cu2082 u22bb Cu2082 u21d4 Du2084;    // Semidirect product representing dihedral transformations

	// Homomorphism relations
	u03c6 : Cu2096 u2192 Cu2082 u22a2 u03c6(gu207f) = u03c6(g)^n mod 2;  // Group homomorphism property

	// Quotient groups
	Su2084 / Au2084 u21d4 Cu2082;     // Quotient of symmetric by alternating group is cyclic

	// Group action identities
	action(G, action(H, x)) = action(G u22bb H, x);  // Action compatibility with semidirect product
);
```

## Inferring Functional Properties Through Group Theory

A powerful application is automatically detecting algebraic properties of higher-order functions:

```
@functional<> = @make_pattern<func_expr, uid, domain_expr>;

@rewrite_system<@functional, @functional, functional_expr, ";">(
	// Detect commutativity in lambda expressions
	u03bb(a, b).op(a, b) u22a2 u03bb : Su2082 if op : Su2082;  // Lambda inherits commutativity from its operation

	// Detect associativity in lambda expressions
	u03bb(a, b).op(a, b) u22a2 u03bb : Associative if op : Associative;

	// Detect idempotence
	u03bb(x).op(x, x) u22a2 u03bb : Idempotent;

	// Detect distributivity
	u03bb(a, b, c).op1(op2(a, b), c) u21d4 u03bb(a, b, c).op2(op1(a, c), op1(b, c)) u22a2 u03bb : Distributive;
);
```

Based on these inferred properties, we can apply deep optimizations to functional patterns:

```
@rewrite_system<@functional, @functional, functional_expr, ";">(
	// Map fusion when function composition is detected
	map(f, map(g, xs)) => map(u03bb(x).f(g(x)), xs);

	// Filter fusion when predicates have certain properties
	filter(p, filter(q, xs)) => filter(u03bb(x).p(x) && q(x), xs);

	// Map-filter interchange when f preserves predicate satisfaction
	map(f, filter(p, xs)) => filter(u03bb(x).p(fu207bu00b9(x)), map(f, xs)) if f : Bijective;

	// Map distribution over concatenation
	map(f, xs ++ ys) => map(f, xs) ++ map(f, ys);

	// Fold-map fusion
	fold(op, init, map(f, xs)) => fold(u03bb(acc, x).op(acc, f(x)), init, xs) if op : Associative;
);
```

## Advanced Group-Theoretic Optimizations

### 1. Optimizing Through Combined Group Structures

Detecting complex group structures enables sophisticated optimizations:

```
@rewrite_system<@functional, @functional, functional_expr, ";">(
	// Detect when map and filter operations commute
	map(f, filter(p, xs)) u22a2 Commute(map(f), filter(p)) if independent(f, p);

	// Apply commutativity to reorder operations for better performance
	map(f, filter(p, xs)) => filter(p, map(f, xs)) if Commute(map(f), filter(p));

	// Optimize operations that form a dihedral group (e.g., transpose + rotate)
	action(Du2084, img) => optimized_dihedral_transform(img);

	// When we have both associativity and commutativity (commutative monoid)
	fold(op, id, xs) => parallel_fold(op, id, xs) if op : CommutativeMonoid;
);
```

### 2. Concrete Example: Optimizing Matrix Operations

```
@matrix<> = @make_pattern<matrix_expr, uid, domain_expr>;

@rewrite_system<@matrix, @matrix, matrix_expr, ";">(
	// Matrix transposition forms an involution (group of order 2)
	transpose : Su2082;
	transpose(transpose(A)) => A;

	// Matrix multiplication forms a monoid
	matmul : Monoid;
	matmul(A, matmul(B, C)) => matmul(matmul(A, B), C);

	// Transposition distributes over addition (homomorphism)
	transpose(A + B) => transpose(A) + transpose(B);

	// Transpose reverses order of multiplication
	transpose(matmul(A, B)) => matmul(transpose(B), transpose(A));

	// Infer group structure of composed operations
	transpose u2218 rotate90 u22a2 (transpose u2218 rotate90) : Du2084;  // Forms dihedral group

	// Optimize based on combined group properties
	transpose(rotate90(transpose(rotate90(img)))) => rotate180(img);
);
```

### 3. Example: Inferring Properties of Fold Operations

```
@fold<> = @make_pattern<fold_expr, uid, domain_expr>;

@rewrite_system<@fold, @fold, fold_expr, ";">(
	// Recognize when a fold can be parallelized
	fold(op, id, xs) u22a2 fold : Parallelizable if op : Associative && op : Commutative;

	// Apply optimization based on inferred property
	fold : Parallelizable => parallel_reduce;

	// Detect when fold with map can be fused
	fold(op, id, map(f, xs)) => fold_map(op, f, id, xs);

	// Special case: sum of mapped values with constant factor
	fold(+, 0, map(u03bb(x).c * f(x), xs)) => c * fold(+, 0, map(f, xs)) if c : Constant;

	// Chain of folds with associative operations can be composed
	fold(op1, id1, fold(op2, id2, xs)) => fold_composed(op1, op2, id1, id2, xs)
		if op1 : Associative && op2 : Associative;
);
```

## Practical Application: Stream Processing Optimization

Group theory lets us optimize stream processing pipelines by recognizing algebraic structures:

```
@stream<> = @make_pattern<stream_expr, uid, domain_expr>;

@rewrite_system<@stream, @stream, stream_expr, ";">(
	// Stream operations often form a monoid
	stream.map(f).map(g) => stream.map(u03bb(x).g(f(x)));

	// Filtering forms a semilattice (idempotent and commutative)
	stream.filter(p).filter(q) => stream.filter(u03bb(x).p(x) && q(x));

	// Group operation on streams
	stream.groupBy(key).map(f) => stream.map(f).groupBy(key) if independent(f, key);

	// Detect when operations form a group and can be simplified
	stream.map(f).map(fu207bu00b9) => stream if f : Bijective;

	// Infer properties of stream transformation chains
	stream.map(f).filter(p).map(g) u22a2 transformation : ReorderedChain if commutes(map(f), filter(p));

	// Apply optimization based on inferred chain property
	transformation : ReorderedChain => stream.map(f).map(g).filter(pu2218fu207bu00b9);
);
```

## Theoretical Foundations

This approach unifies several powerful mathematical frameworks:

1. **Group Theory**: For capturing symmetries and canonical forms
2. **Category Theory**: For formalizing transformations between domains
3. **Order Theory**: For determining canonical representatives
4. **Universal Algebra**: For detecting properties like associativity and commutativity

By representing symmetry groups explicitly in the e-graph structure, we achieve:

1. Exponential reduction in the number of equivalent expressions that need to be represented
2. Automatic discovery of optimizations that exploit symmetry
3. Transfer of optimizations across domains with isomorphic group structures
4. Inference of algebraic properties that enable non-trivial optimizations

This group-theoretic foundation significantly enhances the Domain-Unified Rewriting Engine's ability to perform deep algebraic reasoning and cross-domain optimization.