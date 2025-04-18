# Canonical Forms and Group-Theoretic Rewriting in the O-Graph System

## Abstract

This paper presents a unified approach to canonical forms and rewriting using group theory as the mathematical foundation. We introduce an extended e-graph implementation called o-graphs that represents equivalence classes while preserving domain annotations and group-theoretic properties. By formalizing the relationship between symmetry groups and canonical representations, we demonstrate how diverse computational domains can share canonicalization strategies through a common mathematical framework. The system achieves exponential reduction in equivalent expressions by leveraging group structures like symmetric groups (Sₙ), cyclic groups (Cₙ), and dihedral groups (Dₙ) to automatically derive canonical forms. Through detailed examples across various domains, we show how this approach bridges theoretical mathematics with practical program optimization.

## 1. Introduction

Canonical forms—unique representations of objects within equivalence classes—are fundamental to computational systems. They enable efficient equality testing, pattern matching, and transformational optimizations across domains from symbolic mathematics to program optimization. Traditional approaches to canonicalization often create domain-specific solutions that cannot be easily transferred between contexts.

Our approach addresses this limitation by leveraging group theory as a unifying framework, with three key innovations:

1. **Domain-annotated e-classes**: An extended e-graph implementation that supports domain annotations and hierarchies
2. **Group-theoretic canonicalization**: A systematic approach to deriving canonical forms using symmetry groups
3. **Cross-domain rewriting rules**: A powerful rule system that applies transformations based on algebraic structure

We demonstrate that many common symmetry patterns—commutativity, associativity, rotational invariance—can be represented using well-studied group structures that transcend specific domains, enabling knowledge transfer between mathematical structures and practical programming languages.

## 2. Group-Theoretic Foundations

### 2.1 Core Symmetry Groups

Our system formalizes several key symmetry groups that commonly arise in computation:

- **Symmetric Groups (Sₙ)**: Representing all possible permutations of n elements
  - S₁: Trivial group (identity only)
  - S₂: Group of order 2, represents commutativity (a + b = b + a)
  - S₃: Group of order 6, all permutations of 3 elements
  - Sₙ: Group of order n!, all permutations of n elements

- **Cyclic Groups (Cₙ)**: Representing rotational symmetry
  - C₁: Trivial group (identity only)
  - C₂: Group of order 2, represents 180° rotation
  - Cₙ: Group of order n, represents 360°/n rotations

- **Dihedral Groups (Dₙ)**: Representing rotational and reflectional symmetries
  - D₁: Group of order 2, represents reflection only
  - D₂: Group of order 4, represents 180° rotation and 2 reflections
  - Dₙ: Group of order 2n, represents 360°/n rotations and n reflections

### 2.2 Group Isomorphisms and Relationships

Many computational domains share underlying group structures. For example:

- C₂ ≅ S₂: The cyclic group of order 2 is isomorphic to the symmetric group S₂
- D₁ ≅ C₂: The dihedral group of order 2 is isomorphic to the cyclic group C₂
- D₃ ≅ S₃: The dihedral group D₃ is isomorphic to the symmetric group S₃

These relationships allow us to transfer canonicalization strategies between domains that share the same underlying symmetry group.

### 2.3 Group Actions and Orbits

Canonical forms are derived through group actions on expressions. When a group G acts on a set X, it partitions X into orbits. We select a canonical representative from each orbit using a consistent ordering criterion:

```
Orb(x) = {g·x | g ∈ G} // The orbit of x under group G's action
canon(x) = min(Orb(x))  // The canonical form is the minimum element in the orbit
```

This approach provides a systematic way to derive canonical forms for any data structure with a well-defined group action.

## 3. Canonicalization Strategies

### 3.1 Symmetric Group Canonicalization (Sₙ)

The symmetric group Sₙ represents permutation symmetry. Its canonical form is determined by sorting elements according to a total ordering relation:

```
fn canonicalize_symmetric(elements, comparator) (
	sort(elements, comparator)
)
```

#### Example: Commutative Operations (S₂)

```
// Canonicalizing a + b under commutativity (S₂)
(a + b) : S₂ => a + b : Canonical if a <= b;
(a + b) : S₂ => b + a : Canonical if b < a;

// Applied examples
(5 + 3) : S₂ => 3 + 5 : Canonical;  // 3 < 5, so swap
(x + y) : S₂ => x + y : Canonical;  // Assuming x <= y in the term ordering
```

#### Example: Set Canonicalization (Sₙ)

```
// Canonicalizing a set with n elements
fn canonicalize_set(set) (
	sort(remove_duplicates(set))
)

// Applied examples
{3, 1, 2} => {1, 2, 3};  // Ordered set representation
{x, z, y} => {x, y, z};  // Lexicographically ordered
```

### 3.2 Cyclic Group Canonicalization (Cₙ)

The cyclic group Cₙ represents rotational symmetry. Its canonical form is determined by finding the lexicographically minimal rotation:

```
fn canonicalize_cyclic(array) (
	min_rotation(array)
)

fn min_rotation(array) (
	let n = length(array);
	let min_rot = array;

	for (i in 1..n-1) {
		let rotation = concat(subarray(array, i, n), subarray(array, 0, i));
		if (rotation < min_rot) min_rot = rotation;
	}

	min_rot
)
```

#### Example: Cyclic Rotations (C₄)

```
// Canonicalizing rotations under C₄
(rotate90(x)) : C₄ => x : Canonical if is_min_rotation(x);
(rotate90(x)) : C₄ => rotate90(x) : Canonical if is_min_rotation(rotate90(x));
(rotate90(x)) : C₄ => rotate180(x) : Canonical if is_min_rotation(rotate180(x));
(rotate90(x)) : C₄ => rotate270(x) : Canonical if is_min_rotation(rotate270(x));

// Applied examples
rotate90([b, a, d, a]) => [a, b, a, d];  // Minimal rotation
rotate180([a, d, a, b]) => [a, b, a, d];  // Minimal rotation
```

#### Example: Modular Arithmetic (Cₙ)

```
// Canonicalizing expressions in Z/nZ (cyclic group of order n)
(a + b mod n) : Cₙ => (a + b) % n : Canonical;
(a * b mod n) : Cₙ => (a * b) % n : Canonical;

// Applied examples
(5 + 8 mod 10) : C₁₀ => 3 : Canonical;  // (5+8)%10 = 3
(3 * 4 mod 5) : C₅ => 2 : Canonical;    // (3*4)%5 = 2
```

### 3.3 Dihedral Group Canonicalization (Dₙ)

The dihedral group Dₙ represents rotational and reflectional symmetries. Its canonical form requires checking all rotations and the reflection of each rotation:

```
fn canonicalize_dihedral(array) (
	let n = length(array);
	let min_val = array;

	// Check all rotations
	for (i in 1..n-1) {
		let rotation = concat(subarray(array, i, n), subarray(array, 0, i));
		if (rotation < min_val) min_val = rotation;
	}

	// Check all reflections
	let reversed = reverse(array);
	for (i in 0..n-1) {
		let rotation = concat(subarray(reversed, i, n), subarray(reversed, 0, i));
		if (rotation < min_val) min_val = rotation;
	}

	min_val
)
```

#### Example: Square Symmetry (D₄)

```
// Canonicalizing expressions under square symmetry (D₄)
(rotate90(x)) : D₄ => canonicalize_dihedral(matrix_to_array(x)) : Canonical;
(reflect_h(x)) : D₄ => canonicalize_dihedral(matrix_to_array(x)) : Canonical;

// Applied example with matrix representation
reflect_h([[1, 2], [3, 4]]) : D₄ => [[1, 3], [2, 4]] : Canonical;
// The canonical form is the lexicographically minimal among all 8 symmetries
```

### 3.4 Matrix Canonicalization

Matrices have rich group-theoretic structures. Various matrix forms provide canonical representations:

```
// Row echelon form as canonical representative
(A) : Matrix => rref(A) : Canonical;

// Jordan canonical form for square matrices
(A) : SquareMatrix => jordan_form(A) : Canonical;

// SVD decomposition for general matrices
(A) : Matrix => svd(A) : Canonical;
```

#### Example: Matrix Congruence Class

```
// Matrices are equivalent under similarity transformation
(P⁻¹AP) : SimilarityClass => jordan_form(A) : Canonical;

// Applied example
[[4, 1], [3, 2]] : SimilarityClass => [[3, 0], [0, 3]] : Canonical;
// This example has eigenvalues 3, 3 and is diagonalizable
```

## 4. The O-Graph System

### 4.1 O-Graph Architecture

O-graphs extend traditional e-graphs to support domain annotations and group-theoretic properties:

1. **Domain membership**: Each e-class can belong to multiple domains via annotationz
2. **Root canonicalization**: The root of an e-class serves as the canonical representative
3. **Multiple e-node instances**: The system allows multiple instances of the same e-node with different e-classes

### 4.2 Domain Annotations

Domains are first-class entities in the system and can represent:

```
// Domain annotations examples
a + b : S₂;       // Addition has S₂ symmetry (commutativity)
a + (b + c) : S₃;  // Nested addition has S₃ symmetry
matrix : GL(n,R);  // Matrix belongs to general linear group
[1,2,3] : C₃;     // Array has C₃ symmetry (cyclic rotations)
square : D₄;      // Square has D₄ symmetry (rotations and reflections)
```

### 4.3 Domain Hierarchy

Domains can be organized into hierarchies that reflect mathematical structures:

```
// Mathematical domain hierarchy
AbelianGroup ⊂ Ring ⊂ Field;
Integer ⊂ Rational ⊂ Real ⊂ Complex;

// Symmetry group hierarchy
S₁ ⊂ S₂ ⊂ S₃ ⊂ ... ⊂ Sₙ;
C₁ ⊂ C₂ ⊂ C₄ ⊂ ... ⊂ Cₙ;
```

These hierarchies enable rules defined at more abstract levels to automatically apply to concrete instances.

## 5. Rewrite Rules with Group-Theoretic Patterns

### 5.1 Basic Rewrite Rules

The system provides a powerful language for expressing rewrite rules with domain constraints:

```
// Simple rewrite rules
a + 0 => a : Canonical;               // Identity element elimination
a * 1 => a : Canonical;               // Identity element elimination
a * 0 => 0 : Canonical;               // Annihilator property

// Rules with domain constraints
a + b : S₂ => b + a : S₂ if a > b;     // Order terms by some criterion

// Rules with bidirectional equivalence
x * (y + z) : Ring <=> (x * y) + (x * z) : Ring;  // Distributivity in rings
```

### 5.2 Group-Specific Rewrite Rules

Rewrite rules can explicitly leverage group-theoretic properties:

```
// S₂ (commutativity) rules
(a + b) : S₂ => ordered(a, b) : Canonical;  // Ensure operands are ordered
(a * b) : S₂ => ordered(a, b) : Canonical;  // Same for multiplication

// C₄ (cyclic symmetry) rules
(rotate(x, n)) : C₄ => rotate(x, n % 4) : Canonical;  // Normalize rotation amount
rotate(rotate(x, a), b) : C₄ => rotate(x, (a+b) % 4) : Canonical;  // Compose rotations

// D₄ (dihedral symmetry) rules
(reflect(rotate(x, n))) : D₄ => rotate(reflect(x), -n) : D₄;  // Reflection commutation law
```

### 5.3 Cross-Domain Rewrite Rules

The power of the approach emerges when rules cross domain boundaries:

```
// Integer to bit operations
(a * 2) : Integer => (a << 1) : BitOps : Canonical;  // Multiply by power of 2
(a / 2) : Integer => (a >> 1) : BitOps : Canonical if (a % 2 == 0);  // Divide by power of 2

// Algebra to computing
(a + a + ... + a) : Algebra => (n * a) : Algebra : Canonical if repetitions(a) = n;  // n occurrences
(a * a * ... * a) : Algebra => (a ^ n) : Algebra : Canonical if repetitions(a) = n;  // n occurrences

// Analytical to numerical
(integral(f, a, b)) : Analysis => (numerical_quadrature(f, a, b)) : Numerical : Canonical;
```

## 6. Extended Examples

### 6.1 Polynomial Canonicalization

Polynomials benefit from multiple group-theoretic canonicalizations:

```
// Define polynomial canonicalization rules
let poly_rules = (
	// Commutativity (S₂)
	a + b : Polynomial => ordered(a, b) : Canonical;
	a * b : Polynomial => ordered(a, b) : Canonical;

	// Associativity reorganization
	(a + b) + c : Polynomial => a + (b + c) : Canonical;
	(a * b) * c : Polynomial => a * (b * c) : Canonical;

	// Distributivity
	a * (b + c) : Polynomial => (a * b) + (a * c) : Canonical;

	// Monomial ordering (using graded lexicographic order)
	x^a * y^b * z^c : Polynomial => ordered_monomial(x, y, z, [a, b, c]) : Canonical;

	// Combining like terms
	a*x^n + b*x^n : Polynomial => (a+b)*x^n : Canonical;
);

// Applied examples
(x*y + y*x) : Polynomial => (2*x*y) : Canonical;  // Like terms combined
(x*(y+z) + x*y) : Polynomial => (x*z + 2*x*y) : Canonical;  // Distributed and combined
(x^2*y + y*x^2) : Polynomial => (2*x^2*y) : Canonical;  // Like terms with powers
```

### 6.2 Matrix Expression Optimization

Matrix expressions can be optimized using group-theoretic properties:

```
// Define matrix expression rules
let matrix_rules = (
	// Identity matrix properties
	A * I => A : Canonical;  // Right identity
	I * A => A : Canonical;  // Left identity

	// Transpose properties
	(A^T)^T => A : Canonical;  // Double transpose
	(A+B)^T => A^T + B^T : Canonical;  // Transpose of sum
	(A*B)^T => B^T * A^T : Canonical;  // Transpose of product

	// Special matrix products
	diag(v) * A => row_scale(A, v) : Canonical;  // Diagonal matrix multiplication
	A * diag(v) => col_scale(A, v) : Canonical;  // Diagonal matrix multiplication

	// Matrix trace properties
	tr(A+B) => tr(A) + tr(B) : Canonical;  // Trace of sum
	tr(A*B) => tr(B*A) : Canonical;  // Trace invariant under cyclic permutation
);

// Applied examples
((A*B)^T * (C+D)) : Matrix => ((B^T*A^T) * (C+D)) : Canonical;  // Apply transpose of product
(diag([a,b,c]) * A) : Matrix => row_scale(A, [a,b,c]) : Canonical;  // Optimize diagonal product
```

### 6.3 Logic Formula Canonicalization

Boolean formulas can be canonicalized using CNF, DNF, or BDDs:

```
// Define logic canonicalization rules
let logic_rules = (
	// Double negation elimination
	!!p => p : Canonical;

	// De Morgan's laws (push negation inward)
	!(p && q) => !p || !q : Canonical;
	!(p || q) => !p && !q : Canonical;

	// Distributivity (for CNF/DNF)
	p && (q || r) => (p && q) || (p && r) : DNF;  // For DNF
	p || (q && r) => (p || q) && (p || r) : CNF;  // For CNF

	// Associativity normalization
	(p && q) && r => p && (q && r) : Canonical;
	(p || q) || r => p || (q || r) : Canonical;

	// Canonicalize variables ordering (using S₂)
	p && q : S₂ => ordered(p, q) : Canonical;
	p || q : S₂ => ordered(p, q) : Canonical;
);

// Applied examples
(a && (b || c)) : DNF => ((a && b) || (a && c)) : DNF : Canonical;  // Apply DNF distributivity
(!(a && b)) : CNF => (!a || !b) : CNF : Canonical;  // Apply De Morgan's laws
```

### 6.4 List Processing Operations

Functional list operations benefit from algebraic rewrites:

```
// Define list processing rules
let list_rules = (
	// Map fusion
	map(f, map(g, xs)) => map(\x -> f(g(x)), xs) : Canonical;

	// Filter fusion
	filter(p, filter(q, xs)) => filter(\x -> p(x) && q(x), xs) : Canonical;

	// Map-filter interchange (if f doesn't affect p)
	map(f, filter(p, xs)) => filter(p, map(f, xs)) : Canonical if preserves_predicate(f, p);

	// Fold-map fusion
	fold(op, init, map(f, xs)) => fold(\acc x -> op(acc, f(x)), init, xs) : Canonical;

	// Identity element for fold
	fold(op, id, []) => id : Canonical;

	// Single element fold
	fold(op, id, [x]) => op(id, x) : Canonical;
);

// Applied examples
map(f, map(g, data)) => map(\x -> f(g(x)), data) : Canonical;  // Apply map fusion
filter(p, filter(q, data)) => filter(\x -> p(x) && q(x), data) : Canonical;  // Apply filter fusion
```

### 6.5 Numerical Approximation and Discretization

Numerical methods can be represented as domain-crossing rewrites:

```
// Define numerical approximation rules
let numerical_rules = (
	// Differential to difference equation
	d/dx(f(x)) : Calculus => (f(x+h) - f(x))/h : Numerical if discrete(x);

	// Integral to sum
	integral(f, a, b) : Calculus => sum(i, 0, n-1, f(a + i*h)*h) : Numerical
	   where h = (b-a)/n if discrete(a, b);

	// Infinite series to finite sum
	sum(i, 0, infinity, f(i)) : Series => sum(i, 0, N, f(i)) + error_term : Numerical
	   where error_bound(f, N) < epsilon;

	// Exact to approximate equality
	(a == b) : Exact => (abs(a - b) < epsilon) : Approximate;
);

// Applied examples
(d/dx(x^2)) : Calculus => ((x+h)^2 - x^2)/h : Numerical where h = 0.001;
(integral(sin, 0, pi)) : Calculus => sum(i, 0, 999, sin(i*0.00314)*0.00314) : Numerical;
```

## 7. Implementation in O-Graph

The o-graph system provides a comprehensive API for applying these group-theoretic rewritings:

```
// Create an o-graph
let graph = makeOGraph("my_graph");

// Add expressions with domain annotations
let exprId = addOGraph(graph, a + b);
let domainId = addOGraph(graph, S₂);
addDomainToNode(graph, exprId, domainId);

// Define and apply rewrite rules
let rules = quote(
	// Rules here
	a + b : S₂ => ordered(a, b) : Canonical;
	a * 0 => 0 : Canonical;
	a + 0 => a : Canonical;
	a * (b + c) : Ring => (a * b) + (a * c) : Canonical;
);

// Apply rules until saturation
applyRulesToSaturation(graph, rules);

// Extract optimized result
let result = extractOGraph(graph, rootId);
```

The implementation effectively performs e-graph rewriting with domain-aware pattern matching and group-theoretic canonicalization.

## 8. Applications

### 8.1 Compiler Optimization

Compiler optimizations leverage group-theoretic properties for code transformation:

```
// Algebraic simplifications
a * 0 => 0;  // Any multiplication by zero is zero
(a * 2) => (a << 1);  // Multiply by power of 2 becomes shift
a + a => 2 * a;  // Repeated addition becomes multiplication

// Loop optimizations
for (i = 0; i < n; i++) {
	for (j = 0; j < m; j++) {
		A[i][j] = expr;
	}
}
=> // Loop interchange using symmetry properties
for (j = 0; j < m; j++) {
	for (i = 0; i < n; i++) {
		A[i][j] = expr;
	}
}
```

### 8.2 Computer Algebra Systems

Computer algebra systems use canonicalization for effective pattern matching:

```
// Canonical forms enable matching and replacement
sin(x)^2 + cos(x)^2 => 1;  // Trigonometric identity

// Complex expression simplification
exp(a*log(x)) => x^a;  // Algebraic simplification

// Integrate based on pattern matching of canonical forms
integrate(x^n) => x^(n+1)/(n+1) + C if n != -1;
integrate(1/x) => log(abs(x)) + C;
```

### 8.3 Program Synthesis

Program synthesis can leverage canonical forms to reduce the search space:

```
// Equivalent expressions have the same canonical form
(x * 4) ≡ (x << 2) ≡ (x + x + x + x);  // All have same behavior

// Choose most efficient implementation based on context
synthesis(x * 4) => (x << 2);  // Most efficient for integers
synthesis(x * 4.0) => (x + x + x + x);  // For floating point if FMA not available
```

## 9. Conclusion and Future Work

This paper has presented a unified approach to canonical forms and rewriting using group theory as a mathematical foundation. By formalizing the relationship between symmetry groups and canonical representations, we've shown how diverse computational domains can share canonicalization strategies through a common framework. The o-graph system demonstrates the practical application of these principles through comprehensive examples across multiple domains.

Future work will focus on:

1. **Additional symmetry groups**: Extending the framework to capture more complex symmetries like Lie groups and quantum groups
2. **Automated group inference**: Developing techniques to automatically discover symmetry groups in expressions
3. **Optimization heuristics**: Creating domain-specific cost models that guide the selection of canonical forms
4. **Verification**: Formal verification of the correctness of group-based transformations
5. **Performance improvements**: Enhancing the efficiency of orbit generation and canonical form selection

The vision is a general-purpose system that can reason about canonical forms and equivalence across the full spectrum of computational domains, from low-level bit manipulation to high-level mathematical abstractions.

## References

[1] Nelson, M. (2022). "eggs: A new approach to equality saturation." PLDI 2022.

[2] Miltner, A., & Casper, J. (2020). "egg-smol: A minimal e-graph implementation." ArXiv preprint.

[3] Willsey, M., et al. (2021). "egg: Fast and extensible equality saturation." POPL 2021.

[4] Conway, J. H. (2013). "The Symmetries of Things." CRC Press.

[5] Nieuwenhuis, R., & Oliveras, A. (2005). "Proof-producing congruence closure." RTA 2005.

[6] Dummit, D. S., & Foote, R. M. (2004). "Abstract Algebra." John Wiley & Sons.

## Acknowledgments

The author would like to thank colleagues who contributed to the development of the o-graph architecture and the group-theoretic rewriting approach.

---

_Asger Alstrup Palm_  
_a.palm@area9.dk_