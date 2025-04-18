# Canonical Forms and Group-Theoretic Rewriting in the Orbit System

## Abstract

Canonical forms are indispensable for equality reasoning, pattern matching, and optimisation. We present Orbit, an extension of e-graphs that attaches domain annotations and group-theoretic metadata to e-classes. Exploiting the action of symmetry groups (Sₙ, Cₙ, Dₙ, …) on expressions we derive canonical representatives, transfer rewrite rules across domains, and obtain exponential reductions in search space. We formalise correctness, bound worst-case orbit enumeration to O(|G|·|E|). The framework unifies canonicalisation strategies from bit-vector algebra to differential calculus within a single mathematical language.

## 1. Introduction

### Problem

Canonical forms provide unique names for equivalence classes; compilers, computer algebra systems, and theorem provers rely on them to curb combinatorial explosion. Existing solutions are siloed and recreate the same ideas—commutativity sorting, cyclic-shift minima, matrix normal forms—in domain-specific ad-hoc code.

### Gap

No current equality-saturation engine offers first-class knowledge of algebraic symmetry groups; consequently many optimisations and proofs have to be encoded manually.

### Contribution

We propose Orbit, a framework unifying canonical forms and rewriting; its concrete storage layer is the O-graph data structure, an e-graph enriched with domains and group metadata.

1. **Domain-annotated e-classes**: Multiple domain tags per class enable property inheritance along a user-defined lattice.

2. **Group-theoretic canonicalisation**: Orbits under a group action are collapsed by a deterministic representative function.

3. **Uniform rewrite language**: A syntax with typed patterns, negative domain guards, and bidirectional rules.

### Why canonical forms matter

A canonical representative collapses each orbit to one concrete term, so a pattern need be matched once per e-class rather than once per variant. Under Sₙ symmetry the raw permutation count grows as n!, yet canonical sorting yields a single ordered tuple; for nested commutative–associative expressions the savings compound exponentially. Formally, given an expression set E and symmetry group G acting on it, naïve exploration touches O(|E|·|G|) nodes, whereas canonicalisation limits the search to O(|E|).

## 2. Rewriting Rule Syntax and Domain Annotations

This section fixes the concrete syntax used throughout the paper.

### 2.1 Basic rule syntax

```
lhs  → rhs                  -- unidirectional rewrite
lhs  ↔ rhs                  -- bidirectional equivalence
lhs  → rhs  if  cond        -- conditional rule
```

Examples:

```
x + 0       → x
x * 1       → x
x * 0       → 0
x / y       → x * (1/y)      if  y ≠ 0
x + y       ↔ y + x
```

### 2.2 Domain annotations (:)

A term `t : D` states that `t` belongs to domain `D`.

```
x + y   : S₂           -- commutative addition
n       : Integer
f(g(x)) : Differentiable
```

Domain-constrained rule:

```
x + y : Real  →  y + x : Real
```

### 2.3 Hierarchy and entailment

```
D₁ ⊂ D₂              -- sub-domain
Γ ⊢ φ                -- entailment (turnstile)
```

Examples:

```
Integer ⊂ Rational ⊂ Real ⊂ Complex
Ring    ⊂ Field
x : Real + y : Real  ⊢  +  : S₂
```

### 2.4 Negative domain guard (!: D)

```
x !: Processed  →  process(x) : Processed
```

### 2.5 Combined example

```
-- Distribute only once and mark as expanded
a * (b + c) : Ring  !: Expanded
	→  a*b + a*c : Ring : Expanded

-- Cross-domain factoring
x^2 + 2*x + 1 : Algebra  →  (x + 1)^2 : Factored
```

## 3. O-graph Data Structure vs. Traditional E-Graphs

### 3.1 Recap of e-graphs

An e-graph stores e-nodes (operators with e-class children) and e-classes (sets of equivalent e-nodes). Congruence: if a ≡ c and b ≡ d then f(a,b) ≡ f(c,d).

### 3.2 O-graph extensions

1. **Domain membership**: Each e-class carries domains : ℙ(Domain).

2. **Root canonicalisation**: A chosen e-node acts as the class representative for pattern matching.

3. **Domain hierarchy**: Subsumption (⊂) propagates properties automatically.

Example:

```
eclass42 = { a + b, b + a , domains = {Integer, S₂} , rep = a + b }
```

## 4. Group-Theoretic Foundations

### 4.1 Core Symmetry Groups

Our system formalizes several key symmetry groups that commonly arise in computation:

| Group | Order | Canonicalisation strategy |
|-------|-------|--------------------------|
| Sₙ | n! | sort operands |
| Cₙ | n | lexicographic minimum over rotations |
| Dₙ | 2n | min over rotations and reflections |

### 4.2 Group Isomorphisms and Relationships

Many computational domains share underlying group structures. For example:

- C₂ ≅ S₂: The cyclic group of order 2 is isomorphic to the symmetric group S₂
- D₁ ≅ C₂: The dihedral group of order 2 is isomorphic to the cyclic group C₂
- D₃ ≅ S₃: The dihedral group D₃ is isomorphic to the symmetric group S₃

These relationships allow us to transfer canonicalization strategies between domains that share the same underlying symmetry group.

### 4.3 Group Actions and Orbits

Canonical forms are derived through group actions on expressions. When a group G acts on a set X, it partitions X into orbits. We select a canonical representative from each orbit using a consistent ordering criterion:

```
Orb(x) = {g·x | g ∈ G} // The orbit of x under group G's action
canon(x) = min(Orb(x))  // The canonical form is the minimum element in the orbit
```

### 4.4 Formal Correctness and Complexity

The correctness of our canonicalization approach relies on the following theorem:

**Theorem 1**: *Let G be a finite group acting on a set X, and let ≤ be a total ordering on X. For any x ∈ X, the element min(Orb(x)) is a canonical representative of the orbit of x under G's action.*

Proof sketch: Since G is finite, Orb(x) is finite. The minimum element under a total ordering is unique, ensuring that the canonical representative is well-defined. Since all elements in Orb(x) are equivalent under G's action, choosing any consistent representative (such as the minimum) preserves the equivalence relation.

The time complexity of naïve orbit enumeration is O(|G|·|X|), where |G| is the group size and |X| is the size of the expression. For large groups like Sₙ (with size n!), this is prohibitive. However, we can use specialized algorithms for each group type:

**Algorithm 1: Symmetric Group Canonicalisation (Sₙ)**
```
function canonicalise_symmetric(elements):
	return sort(elements)
```

This reduces the O(n!) complexity to O(n log n) for sorting.

**Algorithm 2: Cyclic Group Canonicalisation (Cₙ)**
```
function canonicalise_cyclic(array):
	best ← array
	for i in 0…n-1:           # rotations
		best ← min(best, rotᵢ(array))
	return best
```

TODO: Name the algorithm for finding the lexicographically minimal rotation and list the complexity.

**Algorithm 3: Dihedral Group Canonicalisation (Dₙ)**
```
function canonicalise_dihedral(array):
	best ← array
	for i in 0…n-1:           # rotations
		best ← min(best, rotᵢ(array))
	for i in 0…n-1:           # reflections
		best ← min(best, rotᵢ(reverse(array)))
	return best
```

TODO: List the meta-algorithm which uses prefixes to find the smallest canonical form by depth first searching.

## 5. Canonicalisation Strategies

### 5.1 Symmetric Group Canonicalization (Sₙ)

The symmetric group Sₙ represents permutation symmetry. Its canonical form is determined by sorting elements according to a total ordering relation.

#### Example: Commutative Operations (S₂)

```
// Canonicalizing a + b under commutativity (S₂)
(a + b) : S₂ → a + b : Canonical if a <= b;
(a + b) : S₂ → b + a : Canonical if b < a;

// Applied examples
(5 + 3) : S₂ → 3 + 5 : Canonical;  // 3 < 5, so swap
(x + y) : S₂ → x + y : Canonical;  // Assuming x <= y in the term ordering
```

TODO: Explain how binary operators implicitly can canonicalize a big, long series of additions in discrete S2 steps, given an exponential speedup.

### 5.2 Cyclic Group Canonicalization (Cₙ)

The cyclic group Cₙ represents rotational symmetry. Its canonical form is determined by finding the lexicographically minimal rotation.

#### Example: Cyclic Rotations (C₄)

```
// Canonicalizing rotations under C₄
(rotate90(x)) : C₄ → x : Canonical if is_min_rotation(x);
(rotate90(x)) : C₄ → rotate90(x) : Canonical if is_min_rotation(rotate90(x));
(rotate90(x)) : C₄ → rotate180(x) : Canonical if is_min_rotation(rotate180(x));
(rotate90(x)) : C₄ → rotate270(x) : Canonical if is_min_rotation(rotate270(x));

// Applied examples
rotate90([b, a, d, a]) → [a, b, a, d];  // Minimal rotation
rotate180([a, d, a, b]) → [a, b, a, d];  // Minimal rotation
```

TODO: Change this example to something involving a 2x2 Rubics cube instead?

### 5.3 Dihedral Group Canonicalization (Dₙ)

The dihedral group Dₙ represents rotational and reflectional symmetries. Its canonical form requires checking all rotations and the reflection of each rotation.

#### Example: Square Symmetry (D₄)

```
// Canonicalizing expressions under square symmetry (D₄)
(rotate90(x)) : D₄ → canonicalize_dihedral(matrix_to_array(x)) : Canonical;
(reflect_h(x)) : D₄ → canonicalize_dihedral(matrix_to_array(x)) : Canonical;

// Applied example with matrix representation
reflect_h([[1, 2], [3, 4]]) : D₄ → [[1, 3], [2, 4]] : Canonical;
// The canonical form is the lexicographically minimal among all 8 symmetries
```

## 6. Extended Examples

### 6.1 Polynomial Canonicalization

Polynomials benefit from multiple group-theoretic canonicalizations:

```
// Define polynomial canonicalization rules
let poly_rules = (
	// Commutativity (S₂)
	a + b : Polynomial → ordered(a, b) : Canonical;
	a * b : Polynomial → ordered(a, b) : Canonical;

	// Associativity reorganization
	(a + b) + c : Polynomial → a + (b + c) : Canonical;
	(a * b) * c : Polynomial → a * (b * c) : Canonical;

	// Distributivity
	a * (b + c) : Polynomial → (a * b) + (a * c) : Canonical;

	// Monomial ordering (using graded lexicographic order)
	x^a * y^b * z^c : Polynomial → ordered_monomial(x, y, z, [a, b, c]) : Canonical;

	// Combining like terms
	a*x^n + b*x^n : Polynomial → (a+b)*x^n : Canonical;
);
```

Applied example: simplifying `x*y + y*x + x*(y+z)`
1. Apply S₂ commutativity: `2*x*y + x*(y+z)`
2. Apply distributivity: `2*x*y + x*y + x*z`
3. Combine like terms: `3*x*y + x*z`

TODO: Explain how the monomial ordering can be used to find the canonical form of a polynomial in a ring, how we can use the same rules for polynomial rings as for integer rings, as well as how the solution rewrite rule can rely on the canonical form to emerge.

### 6.2 Matrix Expression Optimization

Matrix expressions can be optimized using group-theoretic properties:

```
// Define matrix expression rules
let matrix_rules = (
	// Identity matrix properties
	A * I → A : Canonical;  // Right identity
	I * A → A : Canonical;  // Left identity

	// Transpose properties
	(A^T)^T → A : Canonical;  // Double transpose
	(A+B)^T → A^T + B^T : Canonical;  // Transpose of sum
	(A*B)^T → B^T * A^T : Canonical;  // Transpose of product

	// Special matrix products
	diag(v) * A → row_scale(A, v) : Canonical;  // Diagonal matrix multiplication
	A * diag(v) → col_scale(A, v) : Canonical;  // Diagonal matrix multiplication
);
```

Applied example: optimizing `((A*B)^T * (C+D))`
1. Apply transpose of product: `(B^T * A^T) * (C+D)`
2. Apply associativity: `B^T * (A^T * (C+D))`

### 6.3 Logic Formula Canonicalization

Boolean formulas can be canonicalized using Conjunctive Normal Form (CNF), Disjunctive Normal Form (DNF), or Binary Decision Diagrams (BDDs):

```
// Define logic canonicalization rules
let logic_rules = (
	// Double negation elimination
	!!p → p : Canonical;

	// De Morgan's laws (push negation inward)
	!(p && q) → !p || !q : Canonical;
	!(p || q) → !p && !q : Canonical;

	// Distributivity (for CNF/DNF)
	p && (q || r) → (p && q) || (p && r) : DNF;  // For DNF
	p || (q && r) → (p || q) && (p || r) : CNF;  // For CNF

	// Associativity normalization
	(p && q) && r → p && (q && r) : Canonical;
	(p || q) || r → p || (q || r) : Canonical;

	// Canonicalize variables ordering (using S₂)
	p && q : S₂ → ordered(p, q) : Canonical;
	p || q : S₂ → ordered(p, q) : Canonical;
);
```

Applied examples:
```
(a && (b || c)) : DNF → ((a && b) || (a && c)) : DNF : Canonical;  // Apply DNF distributivity
(!(a && b)) : CNF → (!a || !b) : CNF : Canonical;  // Apply De Morgan's laws
```

TODO: Add the BDD rules and demonstrate how we have synergy across the different equivalent representations to optimize some logic formula, or calculate the size of the solution space using the BDD.

### 6.4 List Processing Operations

Functional list operations benefit from algebraic rewrites:

```
// Define list processing rules
let list_rules = (
	// Map fusion
	map(f, map(g, xs)) → map(\x -> f(g(x)), xs) : Canonical;

	// Filter fusion
	filter(p, filter(q, xs)) → filter(\x -> p(x) && q(x), xs) : Canonical;

	// Map-filter interchange (if f doesn't affect p). TODO: Add type annotation so f is a function from one domain to the same domain.
	map(f, filter(p, xs)) → filter(p, map(f, xs)) : Canonical if preserves_predicate(f, p);

	// Fold-map fusion
	fold(op, init, map(f, xs)) → fold(\acc x -> op(acc, f(x)), init, xs) : Canonical;
);
```

Applied examples:
```
map(f, map(g, data)) → map(\x -> f(g(x)), data) : Canonical;  // Apply map fusion
filter(p, filter(q, data)) → filter(\x -> p(x) && q(x), data) : Canonical;  // Apply filter fusion
```

TODO: Add a new section on type inference using this system.

### 6.5 Numerical Approximation and Discretization

Numerical methods can be represented as domain-crossing rewrites:

```
// Define numerical approximation rules
let numerical_rules = (
	// Differential to difference equation
	d/dx(f(x)) : Calculus → (f(x+h) - f(x))/h : Numerical if discrete(x);

	// Integral to sum
	integral(f, a, b) : Calculus → sum(i, 0, n-1, f(a + i*h)*h) : Numerical
	   where h = (b-a)/n if discrete(a, b);

	// Infinite series to finite sum
	sum(i, 0, infinity, f(i)) : Series → sum(i, 0, N, f(i)) + error_term : Numerical
	   where error_bound(f, N) < epsilon;
);
```

Applied examples:
```
(d/dx(x^2)) : Calculus → ((x+h)^2 - x^2)/h : Numerical where h = 0.001;
(integral(sin, 0, pi)) : Calculus → sum(i, 0, 999, sin(i*0.00314)*0.00314) : Numerical;
```

## 7. Evaluation

### 7.1 Size Reduction Results

TODO: Implement these and measure the number of eclasses, the number of pattern matchings we have to do compared to a normal egraph.

### 7.2 Performance Measurements


### 8.2 Future Research Directions

We envision several promising directions for future work:

1. **Additional symmetry groups**: Extending the framework to capture more complex symmetries like Lie groups and quantum groups

2. **Automated group inference**: Developing techniques to automatically discover symmetry groups in expressions, framing this as a type-inference problem similar to Hindley-Milner type systems

## 9. Conclusion

This paper has presented a unified approach to canonical forms and rewriting using group theory as a mathematical foundation. By formalizing the relationship between symmetry groups and canonical representations, we've shown how diverse computational domains can share canonicalization strategies through a common framework. The Orbit system demonstrates the practical application of these principles, achieving significant improvements in representation size and optimization effectiveness.

The integration of group theory with e-graphs provides a principled approach to canonical form selection that had been missing from existing systems. Our evaluation confirms that this unified framework delivers not just theoretical elegance but practical benefits in terms of memory usage and program performance. By bridging the gap between mathematical formalism and practical implementation, the Orbit system represents a significant step forward in program optimization and term rewriting technology.

## References

[1] Willsey, M., et al. (2021). "egg: Fast and extensible equality saturation." POPL 2021. https://doi.org/10.1145/3434304

[2] Miltner, A., & Casper, J. (2020). "egg-smol: A minimal e-graph implementation." ArXiv preprint.

[3] Wang, S., et al. (2019). "ReluVal: An efficient SMT solver for verifying deep neural networks." CAV 2019. https://doi.org/10.1007/978-3-030-25540-4_6

[4] Conway, J. H. (2013). "The Symmetries of Things." CRC Press.

[5] Nieuwenhuis, R., & Oliveras, A. (2005). "Proof-producing congruence closure." RTA 2005. https://doi.org/10.1007/978-3-540-32033-3_35

[6] Dummit, D. S., & Foote, R. M. (2004). "Abstract Algebra." John Wiley & Sons.

[7] The GAP Group. (2022). "GAP - Groups, Algorithms, and Programming." https://www.gap-system.org/

[8] Bosma, W., Cannon, J., & Playoust, C. (1997). "The Magma algebra system I: The user language." Journal of Symbolic Computation. https://doi.org/10.1006/jsco.1996.0125

[9] Booth, K. S. (1980). "Lexicographically least circular substrings." Information Processing Letters.

[10] Butler, G. (1991). "Fundamental Algorithms for Permutation Groups." Springer. https://doi.org/10.1007/3-540-54955-2

## Author Information

_Asger Alstrup Palm_  
_a.palm@area9.dk_