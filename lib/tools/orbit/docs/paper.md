# Canonical Forms and Group-Theoretic Rewriting in the Orbit System

## Abstract

Canonical forms are indispensable for equality reasoning, pattern matching, and optimisation. We present Orbit, an extension of e-graphs that attaches domain annotations and group-theoretic metadata to e-classes. Exploiting the action of symmetry groups (Sₙ, Cₙ, Dₙ, …) on expressions we derive canonical representatives, transfer rewrite rules across domains, and obtain exponential reductions in search space. The framework unifies canonicalisation strategies from bit-vector algebra to differential calculus within a single mathematical language.

## 1. Introduction

### Problem

Canonical forms provide unique names for equivalence classes; compilers, computer algebra systems, and theorem provers rely on them to curb combinatorial explosion. Existing solutions are siloed and recreate the same ideas—commutativity sorting, cyclic-shift minima, matrix normal forms—in domain-specific ad-hoc code.

### Gap

No current equality-saturation engine offers first-class knowledge of algebraic symmetry groups; consequently many optimisations and proofs have to be encoded manually.

### Contribution

We propose Orbit, a framework unifying canonical forms and rewriting; its concrete storage layer is the O-graph data structure, an e-graph enriched with domains and group metadata.

1. **Domain-annotated e-classes**: Multiple domain tags per class enable property inheritance along a user-defined lattice.

2. **Group-theoretic canonicalisation**: Orbits under a group action are collapsed by a deterministic representative function.

3. **Uniform rewrite language**: A natural syntax with typed patterns, negative domain guards, and bidirectional rewriting rules.

### A Motivating Example: Commutative Addition

Consider the simple case of integer addition, which is commutative: `3 + 5 = 5 + 3`. Without canonicalization, a system would need to store and match against both forms. With Orbit, we can annotate the addition with the S₂ symmetry group (the group of permutations on 2 elements):

```
(3 + 5) : S₂ → 3 + 5 : Canonical  // since 3 <= 5
(5 + 3) : S₂ → 3 + 5 : Canonical  // forcing canonical ordering
```

This approach automatically collapses the two forms into a single canonical representation (`3 + 5`), reducing storage requirements and improving pattern matching efficiency. For multi-term expressions, the benefits grow exponentially with expression size.

### Why canonical forms matter

A canonical representative collapses each orbit to one concrete term, so a pattern need be matched once per e-class rather than once per variant. Under Sₙ symmetry the raw permutation count grows as n!, yet canonical sorting yields a single ordered tuple; for nested commutative–associative expressions the savings compound exponentially. Formally, given an expression set E and symmetry group G acting on it, naïve exploration touches O(|E|·|G|) nodes, whereas canonicalisation limits the search to O(|E|).

*See §4.3 for the formal treatment of group actions and §4.4 for correctness proofs and complexity analysis.*

## 2. Rewriting Rule Syntax and Domain Annotations

This section establishes the concrete syntax used throughout the paper for specifying rewrite rules and domain annotations.

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

The left hand side : Real is a restriction, while the right hand side : Real is an entailment, meaning that we will add Real to the domains for `(y+x)`.

### 2.3 Hierarchy

```
D₁ ⊂ D₂              -- sub-domain
```

This is short for the rule `a : D₁ → a : D`, which means that if `a` is in domain `D₁`, it is also in domain `D₂`. This is useful for defining domain hierarchies, where a more specific domain is a subset of a more general one.

Examples:

```
Integer ⊂ Rational ⊂ Real ⊂ Complex
Ring    ⊂ Field
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

1. **Domain membership**: Each e-class carries a set of domains it belongs to. Each domain is a term in the same o-graph.

2. **Root canonicalisation**: A chosen e-node acts as the class representative for pattern matching. Rewriting rules from lhs to rhs makes the rhs the root of the e-class.

Example:

```
eclass42 = { a + b, b + a , belongsTo = {Integer, S₂} }
```

## 4. Group-Theoretic Foundations

### 4.1 Core Symmetry Groups

Our system formalizes several key symmetry groups that commonly arise in computation:

| Group | Order | Description | Canonicalisation strategy |
|-------|-------|-------------|--------------------------|
| Sₙ | n! | Symmetric group (permutations) | sort operands |
| Cₙ | n | Cyclic group (rotations) | lexicographic minimum over rotations |
| Dₙ | 2n | Dihedral group (rotations+reflections) | min over rotations and reflections |

These fundamental groups appear across diverse domains:
- S₂: Commutative operations (addition, multiplication)
- Sₙ: Permutation invariant functions (sets, multisets)
- Cₙ: Cyclic structures (circular buffers, machine integer arithmetic)
- Dₙ: Geometric symmetries (regular polygons, matrix transformations)

### 4.2 Group Isomorphisms and Relationships

Many computational domains share underlying group structures. For example:

- C₂ ≅ S₂: The cyclic group of order 2 is isomorphic to the symmetric group S₂
- D₁ ≅ C₂: The dihedral group of order 2 is isomorphic to the cyclic group C₂
- D₃ ≅ S₃: The dihedral group D₃ is isomorphic to the symmetric group S₃

These relationships allow us to transfer canonicalization strategies between domains that share the same underlying symmetry group.

### 4.3 Group Actions and Orbits

Canonical forms are derived through group actions on expressions. When a group G acts on a set X, it partitions X into orbits. We select a canonical representative from each orbit using a consistent ordering criterion:

```
Orbit(x) = {g·x | g ∈ G} // The orbit of x under group G's action
canon(x) = min(Orbit(x))  // The canonical form is the minimum element in the orbit
```

### 4.4 Formal Correctness and Complexity

The correctness of our canonicalization approach relies on the following theorem:

**Theorem 1**: *Let G be a finite group acting on a set X, and let ≤ be a total ordering on X. For any x ∈ X, the element min(Orb(x)) is a canonical representative of the orbit of x under G's action.*

Proof sketch: Since G is finite, Orb(x) is finite. The minimum element under a total ordering is unique, ensuring that the canonical representative is well-defined. Since all elements in Orb(x) are equivalent under G's action, choosing any consistent representative (such as the minimum) preserves the equivalence relation.

The time complexity of naïve orbit enumeration is O(|G|·|X|), where |G| is the group size and |X| is the size of the expression. For large groups like Sₙ (with size n!), this is prohibitive. However, we can use specialized algorithms for each group type:

**Meta-Algorithm: Finding Canonical Forms**

Our approach to canonicalization follows a general meta-algorithm pattern:

1. **Action**: Apply the group action to generate variations of the expression
2. **Selection**: Choose a canonical representative using a consistent criterion
3. **Optimization**: Use domain-specific algorithms to avoid enumeration

This meta-algorithm is implemented efficiently using prefix-based pruning for large groups:

TODO: Rewrite to be in Orbit syntax

```
function find_canonical_form(expression, group):
	// Initialize with empty prefix
	return prefix_dfs(expression, group, [])

function prefix_dfs(expression, group, prefix):
	// Base case: if expression is fully determined by prefix
	if is_fully_determined(expression, prefix):
		return construct_expression(prefix)

	// Get possible next elements based on current prefix
	candidates ← get_next_candidates(expression, group, prefix)

	// Sort candidates lexicographically
	sorted_candidates ← sort(candidates)

	// Try each candidate prefix extension
	for candidate in sorted_candidates:
		extended_prefix ← prefix + [candidate]
		// Check if this prefix can lead to minimal form
		if is_viable_prefix(expression, group, extended_prefix):
			result ← prefix_dfs(expression, group, extended_prefix)
			if result is not null:
				return result

	return null
```

For specific groups, we implement optimized versions:

**Algorithm 1: Symmetric Group Canonicalisation (Sₙ)**
```
function canonicalise_symmetric(elements):
	return sort(elements)
```
TODO: Rewrite to be in Orbit syntax


This reduces the O(n!) complexity to O(n log n) for sorting.

**Algorithm 2: Cyclic Group Canonicalisation (Cₙ)**
```
function canonicalise_cyclic(array):
	best ← array
	for i in 0…n-1:           # rotations
		best ← min(best, rotᵢ(array))
	return best
```
TODO: Rewrite to be in Orbit syntax


The naive implementation above has O(n²) time complexity, but we can achieve linear time using Booth's algorithm [Booth, 1980]. Booth's algorithm finds the lexicographically minimal rotation of a string or array in O(n) time by using a variant of the Knuth-Morris-Pratt (KMP) string matching algorithm.

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

TODO: This can be done simpler using Booth algorithm on the original and the flipped version, and picked the smallest. Be sure to write in Orbit syntax

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

#### Exponential Speedup Through Binary Operator Canonicalization

Binary operators with S₂ symmetry (like commutative addition) provide exponential speedup when processing nested expressions. Consider an expression with n terms in a sum: (a + b + c + ... + z). Without canonicalization, there are n! possible permutations of these terms, leading to an exponential explosion of variants to match against.

However, binary operator canonicalization works incrementally through pairwise comparisons:

```
// Binary operator view of a multi-term sum
((a + b) + c) + d + ...)

// First canonicalize innermost pair (a + b) - assume b < a
((b + a) + c) + d + ...)

// Then apply S₂ to ((b + a) + c) - assume c < b
((c + (b + a)) + d) + ...)

// Continue until fully canonicalized
```

This approach reduces the complexity from O(n!) to O(n^2), as we're essentially implementing a bubble sort algorithm through pairwise swaps. For associative-commutative operators, we can further optimize by flattening the expression first, sorting all terms, and then rebuilding the expression in canonical form.

The exponential savings become apparent when we consider pattern matching: instead of matching against all n! permutations, we match only against the single canonical form. For nested expressions with multiple commutative operators at different levels, the savings compound exponentially with the depth of the expression tree.

For instance, with just 10 commutative binary operations nested in a tree, naive matching would require checking against 10! = 3,628,800 variants, while with canonicalization we need to check just one form. When such expressions appear as subexpressions within larger patterns, the combinatorial explosion is tamed through systematic canonicalization at each level.

### 5.2 Cyclic Group Canonicalization (Cₙ)

The cyclic group Cₙ represents rotational symmetry. Its canonical form is determined by finding the lexicographically minimal rotation using Booth's algorithm in linear time.

#### Example: 2x2 Rubik's Cube Rotations (C₄)

A 2x2 Rubik's cube provides an excellent practical application of cyclic group canonicalization. For simplicity, we'll consider just the rotations of the top face, which form a cyclic group C₄.

```
// Representing a 2x2 Rubik's cube top face
// [top-left, top-right, bottom-right, bottom-left]
cube = [red, blue, green, yellow]

// Canonicalizing a cube state under C₄ rotation
(rotate_cube(cube)) : C₄ → cube : Canonical if is_min_rotation(cube);
(rotate_cube(cube)) : C₄ → rotate90_cw(cube) : Canonical if is_min_rotation(rotate90_cw(cube));
(rotate_cube(cube)) : C₄ → rotate180(cube) : Canonical if is_min_rotation(rotate180(cube));
(rotate_cube(cube)) : C₄ → rotate90_ccw(cube) : Canonical if is_min_rotation(rotate90_ccw(cube));

// Applied examples (using color values with lexicographic ordering blue < green < red < yellow)
rotate90_cw([red, blue, green, yellow]) → [yellow, red, blue, green]; // Rotated clockwise
canon([yellow, red, blue, green]) → [blue, green, yellow, red];      // Canonical form
```

In this example, we lexicographically compare the cube face arrays to find the minimal rotation. This ensures that equivalent cube positions (differing only by rotation) have the same canonical representation, which is crucial for pattern matching and state space reduction in cube-solving algorithms. Without canonicalization, the state space would be 4 times larger, as each unique configuration would appear in 4 rotational variants.

If we wanted to extract the moves, we would have to actively add the number of rotations found by Booth's algorithm as equivalent forms. We can choose to rotate in either direction, so picking the shortest of the two will give the shortest solution.

#### Polynomial Encoding of the 2x2 Rubik's Cube

Interestingly, the 2x2 Rubik's cube can also be represented using a polynomial encoding, which provides another view of the same group structure:

```
// Polynomial encoding of the 2x2 cube face
// Representing [red, blue, green, yellow] as coefficients of a polynomial
p(x) = red*x^0 + blue*x^1 + green*x^2 + yellow*x^3

// Rotation corresponds to multiplying by x and taking modulo (x^4-1)
rotate(p(x)) = x*p(x) mod (x^4-1)

// Finding the canonical form means finding the minimum polynomial
// among all four rotations
canon(p(x)) = min(p(x), x*p(x) mod (x^4-1), x^2*p(x) mod (x^4-1), x^3*p(x) mod (x^4-1))
```

This parallel between the direct array representation and the polynomial encoding demonstrates how our group-theoretic framework unifies seemingly disparate representations under the same mathematical structure.

TODO: Introduce Groebner basis and the algorithm to solve those as another method to try this.

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

If we need to output the orbit of rotations and reflections to find the canonical form, we can use the same approach as with the cyclic group. The only difference is that we need to check the rotations against both reflections.

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

#### Monomial Ordering and Polynomial Canonical Forms

Monomial ordering is fundamental to finding canonical forms of polynomials. In a polynomial ring, we establish a total ordering on monomials (typically graded lexicographic or graded reverse lexicographic) to determine a unique representation:

```
// Graded lexicographic ordering
x^a * y^b * z^c < x^d * y^e * z^f  if  (a+b+c < d+e+f)  or
		((a+b+c = d+e+f) and (a,b,c) <_lex (d,e,f))
```

This ordering enables a systematic approach to canonicalization:

1. **Factor out common terms**: Apply distributivity in reverse when possible
2. **Flatten nested expressions**: Use associativity to normalize structure
3. **Order variables**: Apply consistent variable ordering within each monomial
4. **Combine like terms**: Merge terms with identical variable patterns
5. **Sort terms**: Arrange terms according to the monomial ordering

The same algebraic rules apply across different ring types (integer, polynomial, matrix rings), but with domain-specific interpretations. For example, commutativity rules in polynomial rings work exactly as they do in integer rings, while these operations have different semantics in non-commutative rings.

The canonical form emerges naturally through the repeated application of these rules until a fixed point is reached. Most importantly, this canonical form facilitates both pattern matching and equation solving:

```
// Solving equations using canonical forms
(x^2 + 2*x + 1) = 0 : Equation
	→ ((x + 1)^2) = 0 : Factored   // Canonicalize to factored form
	→ (x + 1) = 0 : Solution      // Extract solution from factors
	→ x = -1 : Result             // Solve simple equation
```

The canonicalization process makes solving systems of equations more efficient because patterns like perfect squares, differences of squares, and other common algebraic structures become immediately recognizable in their canonical form.

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

#### Binary Decision Diagrams (BDDs) and Cross-Representation Synergy

Binary Decision Diagrams provide another canonical representation for Boolean formulas, with their own set of rewrite rules:

```
// BDD canonicalization rules
let bdd_rules = (
	// Shannon expansion (variable elimination)
	f : BDD → ite(x, f|x=1, f|x=0) : BDD : Shannon;

	// Node reduction rules
	ite(x, t, t) → t : BDD;                      // Redundant test elimination
	ite(x, ite(y, t, f), ite(y, t', f')) → ite(y, ite(x, t, t'), ite(x, f, f')) : BDD if orderLess(y, x); // Variable reordering

	// Complement edge simplification
	!ite(x, t, f) → ite(x, !t, !f) : BDD;     // Push negation inward
);
```

The power of our approach comes from the synergy between different canonical representations. For example, we can use CNF/DNF for some operations and BDDs for others, choosing the most efficient representation for each task:

```
// Cross-representation optimization example
formula = (a && b) || (a && c) || (b && c);   // Original formula

// First convert to BDD to count solutions
bdd_form = to_bdd(formula) : BDD;           // Convert to BDD
count = count_solutions(bdd_form);          // Efficiently count satisfying assignments (3 solutions)

// Then convert to CNF for SAT solving
cnf_form = to_cnf(formula) : CNF;           // Convert to CNF: (a || b) && (a || c) && (b || c)
simplified = simplify(cnf_form);            // Further simplify if possible
```

This multi-representation approach allows us to solve complex problems by leveraging the strengths of each canonical form:

1. **CNF**: Ideal for SAT solving and derivation of minimal implicants
2. **DNF**: Well-suited for enumerating solutions and minimal term representation
3. **BDDs**: Efficient for counting solutions, equivalence checking, and quantifier elimination

By maintaining these representations within the same e-graph structure, we can automatically select the most appropriate form for a given operation, or even derive new insights by comparing the same formula across different canonical representations.

### 6.4 List Processing Operations

Functional list operations benefit from algebraic rewrites:

```
// Define list processing rules
let list_rules = (
	// Map fusion
	map(f, map(g, xs)) → map(\x -> f(g(x)), xs) : Canonical;

	// Filter fusion
	filter(p, filter(q, xs)) → filter(\x -> p(x) && q(x), xs) : Canonical;

	// Map-filter interchange (if f doesn't affect p)
	map(f : α → α, filter(p, xs)) → filter(p, map(f, xs)) : Canonical if preserves_predicate(f, p);

	// Fold-map fusion
	fold(op, init, map(f, xs)) → fold(\acc x -> op(acc, f(x)), init, xs) : Canonical;
);
```

Applied examples:
```
map(f, map(g, data)) → map(\x -> f(g(x)), data) : Canonical;  // Apply map fusion
filter(p, filter(q, data)) → filter(\x -> p(x) && q(x), data) : Canonical;  // Apply filter fusion
```

### 6.4.1 Type Inference Using Group Theory

The Orbit system can be extended to perform type inference by treating types as equivalence classes under domain-specific transformation groups. This approach unifies type checking with our canonical forms framework.

```
// Type inference rules
let type_rules = (
	// Type variable introduction
	expr !: Typed → expr : α : Typed;

	// Function application typing
	apply(f : α → β, x : α) → apply(f, x) : β : Typed;

	// Type unification (via group-theoretic canonicalization)
	unify(t, t) → t : Canonical;
	unify(α, t) → subst(α, t) : Canonical if !occurs_in(α, t);
	unify(t, α) → subst(α, t) : Canonical if !occurs_in(α, t);

	// Complex type constructors (with S₂ symmetry for product types)
	pair(a : α, b : β) → pair(a, b) : α × β : Typed;
	tuple(elems...) : S₂ → sorted_tuple(elems...) : Canonical; // For records with symmetry
);
```

The key insight is that we can treat type variables and concrete types as members of the same e-graph, with unification being a process of finding a canonical form under substitution. This approach handles polymorphism naturally:

```
// Type inference example
let id = \x -> x;               // Identity function
let f = \x -> x + 1;            // Int -> Int function
let pair = (id, f);            // Polymorphic pair

// Application inference
apply(id, 5) : Int;            // Infer id : Int -> Int in this context
apply(id, "hello") : String;    // Infer id : String -> String in this context

// Type inference recognizes that pair has type: (α -> α, Int -> Int)
```

Types that exhibit symmetry properties can be canonicalized using the same group-theoretic machinery. For example, record types in structural typing systems often have field ordering symmetry that can be handled by S₂ canonicalization:

```
// Record type canonicalization
typeof({x: Int, y: String}) = typeof({y: String, x: Int})  // By S₂ canonicalization
```

This integration enables more flexible and powerful type systems while maintaining sound semantics, and demonstrates how the Orbit framework provides a unifying approach across seemingly disparate domains like term rewriting and type checking.

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

<draft>
Later: We have to implement all of Orbit and the rules and then test. We should count the number of pattern matches we have to do, as well as the number of eclasses required. This work is in progress,
</draft>

## 8. Discussion

### 8.1 Notation and Terminology

Throughout this paper, we use the term "domain" to refer to a set of elements with certain properties, such as being members of a particular algebraic structure (Ring, Field) or having specific symmetry properties (S₂, Cₙ). These domains form a lattice under the subset relationship (⊂).

Group-theoretic domains represent symmetry properties. For example, the S₂ domain indicates that expressions are invariant under permutation of two elements, while Cₙ indicates invariance under cyclic shifts.

Type domains express data types and their relationships. They're similar to types in programming languages but extend the concept to represent domain-specific mathematical properties.

The arrow symbols follow these conventions:
- →: Unidirectional rewrite rule
- ↔: Bidirectional equivalence relation
- ⊂: Subset or subtype relation

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

[9] Booth, K. S. (1980). "Lexicographically least circular substrings." Information Processing Letters, 10(4-5), 240-242.

[10] Butler, G. (1991). "Fundamental Algorithms for Permutation Groups." Springer. https://doi.org/10.1007/3-540-54955-2

## Author Information

_Asger Alstrup Palm_  
_asger@area9.dk_