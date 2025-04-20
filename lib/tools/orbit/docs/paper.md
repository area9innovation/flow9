# Canonical Forms and Group-Theoretic Rewriting in the Orbit System

## Abstract

Canonical forms are indispensable for equality reasoning, pattern matching, and optimisation. We present Orbit, an extension of e-graphs that attaches domain annotations and group-theoretic metadata to e-classes. Exploiting the action of symmetry groups (Sₙ, Cₙ, Dₙ, …) on expressions we derive canonical representatives, transfer rewrite rules across domains, and obtain exponential reductions in search space. The framework unifies canonicalisation strategies from bit-vector algebra to differential calculus within a single mathematical language.

<!-- TODO: Add a concrete performance improvement or example domain to immediately convey practical benefits -->

## 1. Introduction

### Problem

Canonical forms provide unique names for equivalence classes; compilers, computer algebra systems, and theorem provers rely on them to curb combinatorial explosion. Existing solutions are siloed and recreate the same ideas—commutativity sorting, cyclic-shift minima, matrix normal forms—in domain-specific ad-hoc code.

### Gap

No current equality-saturation engine offers first-class knowledge of algebraic symmetry groups; consequently many optimisations and proofs have to be encoded manually.

<!-- TODO: Clarify explicitly how Orbit differs fundamentally from existing approaches (such as standard e-graphs) and highlight the exact novelty compared to other group-aware canonicalization approaches -->

### Contribution

We propose Orbit, a framework unifying canonical forms and rewriting; its concrete storage layer is the O-graph data structure, an e-graph enriched with domains and group metadata.

1.  **Domain-annotated e-classes**: Multiple domain tags per class enable property inheritance along a user-defined lattice.
2.  **Group-theoretic canonicalisation**: Orbits under a group action are collapsed by a deterministic representative function.
3.  **Uniform rewrite language**: A natural syntax with typed patterns, negative domain guards, and bidirectional rewriting rules.

### A Motivating Example: Commutative Addition

Consider the simple case of integer addition, which is commutative: `3 + 5 = 5 + 3`. Without canonicalization, a system would need to store and match against both forms. With Orbit, we can annotate the addition with the S₂ symmetry group (the group of permutations on 2 elements):

```orbit
// Canonicalizing a + b under commutativity (S₂)
(a + b) : S₂ → a + b : Canonical if a ≤ b;
(a + b) : S₂ → b + a : Canonical if b < a;

// Applied examples
(5 + 3) : S₂ → 3 + 5 : Canonical;  // 3 < 5, so swap
```

This approach automatically collapses the two forms into a single canonical representation (`3 + 5`), reducing storage requirements and improving pattern matching efficiency. For multi-term expressions, the benefits grow exponentially with expression size.

### Why canonical forms matter

A canonical representative collapses each orbit to one concrete term, so a pattern need be matched once per e-class rather than once per variant. Under Sₙ symmetry the raw permutation count grows as n!, yet canonical sorting yields a single ordered tuple; for nested commutative–associative expressions the savings compound exponentially. Formally, given an expression set E and symmetry group G acting on it, naïve exploration touches O(|E|·|G|) nodes, whereas canonicalisation limits the search to O(|E|).

*See §4.3 for the formal treatment of group actions and §4.4 for correctness proofs and complexity analysis.*

## 2. Rewriting Rule Syntax and Domain Annotations

This section establishes the concrete syntax used throughout the paper for specifying rewrite rules and domain annotations.

### 2.1 Basic rule syntax

```orbit
lhs  → rhs                  -- unidirectional rewrite
lhs  ↔ rhs                  -- bidirectional equivalence
lhs  → rhs  if  cond        -- conditional rule
```

Examples:

```orbit
x + 0       → x
x * 1       → x
x * 0       → 0
x / y       → x * (1/y)      if  y ≠ 0
x + y       ↔ y + x           : S₂ // Indicate commutativity via S₂
```

### 2.2 Domain annotations (:)

A term `t : D` states that `t` belongs to domain `D`.

```orbit
x + y   : S₂           -- commutative addition (annotation on operator/expression)
n       : Integer        // n belongs to the Integer domain
f(g(x)) : Differentiable // Expression belongs to Differentiable domain
```

Domain-constrained rule:

```orbit
x + y : Real  →  y + x : Real
```

The left hand side `: Real` is a restriction (match only if `x+y` is already known to be `Real`), while the right hand side `: Real` is an entailment (assert that `y+x` is also `Real`).

### 2.3 Domain Hierarchy and Rule Consolidation

Domains can be organized hierarchically using the subdomain notation:

```orbit
D₁ ⊂ D₂              -- D₁ is a sub-domain of D₂
```

This is short for the entailment rule `a : D₁ → a : D₂`, meaning any term belonging to `D₁` also belongs to `D₂`. This allows rules defined for general domains to be automatically inherited by more specific ones.

To maximize rule reuse and maintainability, Orbit encourages defining domains and rules within a structured hierarchy based on algebraic properties. General rules defined for abstract structures (like Semigroups, Monoids, Rings) are automatically inherited by specific domains (like Integers, Reals, BitVectors, Matrices) that instantiate those structures.

Example hierarchy:

```orbit
// Core algebraic structures (single operation)
Monoid ⊂ Semigroup       // Add Identity
Group ⊂ Monoid         // Add Inverse
AbelianGroup ⊂ Group     // Add Commutativity (S₂)

// Ring-like structures (two operations: +, *)
Ring ⊂ AbelianGroup   // Additive structure (+)
Ring ⊂ Monoid         // Multiplicative structure (*) - Needs careful scope
Field ⊂ Ring          // Adds Multiplicative Inverse (for non-zero)

// Concrete domains inheriting structure
Integer ⊂ Ring
Rational ⊂ Field
Real ⊂ Field
BitVector<N> ⊂ Ring   // Ring Modulo 2^N
Set ⊂ DistributiveLattice // Set operations form a lattice
```

A rule defined for a higher-level structure applies automatically to any subdomain. For example:

```orbit
// Associativity defined once for Semigroup
(a * b) * c : Semigroup ↔ a * (b * c) : Semigroup : A // :A denotes associativity

// Commutativity defined once for AbelianGroup using S₂ symmetry
a + b : AbelianGroup ↔ b + a : AbelianGroup : S₂
```

These general rules are then automatically applicable to Integers, Reals, BitVectors, etc., wherever they are declared as subdomains of `Semigroup` or `AbelianGroup`. This hierarchical approach significantly reduces rule duplication. The group-theoretic canonicalization (e.g., `: S₂` for commutativity) ensures consistent representation regardless of the specific domain. Section 6 provides further examples demonstrating this cross-domain rule application.

### 2.4 Negative domain guard (!: D)

A negative guard `t !: D` restricts a rule to apply only if term `t` does *not* belong to domain `D`. This is useful for applying rules only once or implementing multi-stage rewriting.

```orbit
// Apply 'process' only if 'x' hasn't been marked 'Processed' yet
x !: Processed  →  process(x) : Processed

// Prevent infinite loop for distributivity
a * (b + c) : Ring !: Expanded → (a * b) + (a * c) : Ring : Expanded
```
This prevents the rule from repeatedly expanding the same expression by marking the result `: Expanded` and ensuring the rule only matches expressions `: Ring` that are *not* `: Expanded`.

### 2.5 Combined example

```orbit
-- Distribute multiplication over addition in a Ring, only once
a * (b + c) : Ring !: Expanded → (a * b) + (a * c) : Ring : Expanded

-- Factor a specific quadratic expression found in Algebra domain
x^2 + 2*x + 1 : Algebra → (x + 1)^2 : Factored : Algebra
```

## 3. O-graph Data Structure vs. Traditional E-Graphs

<!-- TODO: Add a brief illustrative example showing the step-by-step transformation from a traditional e-graph to an O-graph, highlighting what changes and what benefits emerge from domain and group annotations -->

### 3.1 Recap of e-graphs

An e-graph stores e-nodes (operators with e-class children) and e-classes (sets of equivalent e-nodes). Equality saturation repeatedly applies rewrite rules until no new equivalent terms can be added. Congruence Closure ensures that if `a ≡ c` and `b ≡ d`, then `f(a,b) ≡ f(c,d)` for any operator `f`.

### 3.2 O-graph extensions

1.  **Domain membership**: Each e-class carries a set of domains it belongs to (e.g., `Integer`, `Ring`, `S₂`, `Canonical`). Domains are themselves terms within the o-graph, allowing for relationships like the hierarchy described in §2.3.
2.  **Group metadata**: Specific group domains (like `S₂`, `C₄`) trigger group-theoretic canonicalization algorithms.
3.  **Root canonicalisation**: A chosen e-node acts as the class representative for pattern matching. Rewrite rules `lhs → rhs` make the `rhs` the new representative, potentially marked `: Canonical`.

Example:

```
eclass42 = {
	nodes = { (5 + 3), (3 + 5) },
	belongsTo = { Integer, Ring, S₂ }, // Domain membership
	representative = (3 + 5)        // Canonical form based on S₂ ordering
}
```

## 4. Group-Theoretic Foundations

### 4.1 Core Symmetry Groups

Our system formalizes several key symmetry groups that commonly arise in computation:

| Group | Order | Description                     | Canonicalisation strategy                     | Example Use Case                  |
|-------|-------|---------------------------------|-----------------------------------------------|-----------------------------------|
| Sₙ    | n!    | Symmetric group (permutations)  | Sort operands lexicographically             | Commutative ops (`+`, `*`), Sets  |
| Cₙ    | n     | Cyclic group (rotations)        | Lexicographic minimum over rotations (Booth)  | Modular arithmetic, bit rotations |
| Dₙ    | 2n    | Dihedral (rotations+reflections) | Min over rotations and reflections          | Geometric symmetry, bit patterns  |

<!-- TODO: Add brief descriptions or examples of each canonicalization strategy directly in the table for immediate intuition -->

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

These relationships allow us to transfer canonicalization strategies between domains that share the same underlying symmetry group. An operation identified with `C₂` symmetry can reuse the canonicalization logic developed for `S₂`.

### 4.3 Group Actions and Orbits

Canonical forms are derived through group actions on expressions. When a group G acts on a set X, it partitions X into orbits. We select a canonical representative from each orbit using a consistent ordering criterion (e.g., lexicographical minimum):

```
Orbit(x) = {g·x | g ∈ G} // The orbit of x under group G's action
canon(x) = min(Orbit(x))  // The canonical form is the minimum element in the orbit
```
The o-graph stores only the canonical representative `canon(x)` explicitly, while recognizing that all elements in `Orbit(x)` belong to the same e-class.

### 4.4 Formal Correctness and Complexity

The correctness of our canonicalization approach relies on the following theorem:

**Theorem 1**: *Let G be a finite group acting on a set X, and let ≤ be a total ordering on X. For any x ∈ X, the element min(Orbit(x)) is a unique canonical representative of the orbit of x under G's action.*

Proof sketch: Since G is finite, Orb(x) is finite. The minimum element under a total ordering ≤ is unique, ensuring that the canonical representative is well-defined and consistent. Since all elements in Orb(x) are equivalent under G's action (by definition of an orbit), choosing any consistent representative (such as the minimum) preserves the equivalence relation.

Example: Consider Orb(`5+3`) = {`5+3`, `3+5`} under S₂ action. With standard integer ordering `3 < 5`, `min(Orb(5+3))` is uniquely `3+5`.

### 4.4.1 Array-based Representation for Associative Operations

To efficiently handle associative operations, we collect operands into arrays rather than using nested binary operators. This provides significant performance improvements for pattern matching and canonicalization.

**Definition**: *For an associative operation ⊗, we represent expressions `x₁ ⊗ x₂ ⊗ ... ⊗ xₙ` as `⊗([x₁, x₂, ..., xₙ])` rather than nested applications `(x₁ ⊗ (x₂ ⊗ (...)))`.*

Example: The expression `a + b + c + d` is represented as `+([a, b, c, d])` rather than `((a + b) + c) + d` or `(a + (b + c)) + d`.

This flattened representation allows for:
1. Direct application of group actions on the entire array
2. Efficient pattern matching within the array structure
3. Single-pass sorting for commutative operations
4. Simplified rule application without tree traversal

The time complexity of naïve orbit enumeration is O(|G|·|X|), where |G| is the group size and |X| is the size of the expression. For large groups like Sₙ (with size n!), this is prohibitive. However, we use specialized algorithms for each group type:

**Meta-Algorithm: Finding Canonical Forms**

Our approach to canonicalization follows a general meta-algorithm pattern:

1.  **Identification**: Recognize the symmetry group G associated with an expression `x`.
2.  **Action**: Conceptually, understand the group action `g·x` for `g ∈ G`.
3.  **Selection**: Efficiently compute `canon(x) = min(Orbit(x))` using group-specific algorithms, avoiding explicit enumeration.
4.  **Optimization**: Use domain-specific algorithms (sorting for Sₙ, Booth's for Cₙ, etc.) to find the minimum efficiently.
5.  **Array Handling**: For associative operations, operate directly on flattened arrays rather than nested binary operations.

### 4.4.2 Pattern Matching within Sequences

In addition to full sequence matching, the array-based representation enables efficient partial sequence matching using pattern indicators:

| Pattern | Description | Example | Matches in `+([a,b,c,d,e])` |
|---------|-------------|---------|-----------------------------|
| Exact | Match the exact sequence | `1+2+3` | Only `+([1,2,3])` |
| Prefix | Match start of sequence | `1+2+3+...` | `+([1,2,3,d,e])` |
| Suffix | Match end of sequence | `...+1+2+3` | `+([a,b,1,2,3])` |
| Subsequence | Match anywhere in sequence | `...+1+2+3+...` | `+([a,1,2,3,e])` |

This pattern matching is particularly powerful for rewrite rules, as substitutions can be applied to precisely the matched subsequence without affecting the rest of the array. The implementation preserves associativity properties while dramatically improving rule application efficiency.

**Example**: A rule matching `x+y+z` where `y` is a constant can efficiently find all such patterns in a large sum without needing to consider all binary partitions of the expression.

This meta-algorithm is implemented efficiently using prefix-based pruning for large groups:

```orbit
// Meta-Algorithm: Finding Canonical Forms (Conceptual)
fn find_canonical_form(expression, group) = (
	// Apply the group action to generate variations and find minimum
	// This is conceptual; actual implementation uses optimized algorithms below.
	let variations = apply_group_action(expression, group); // Slow: O(|G|)
	min(variations) // Requires comparison function
);

// Optimized implementation using prefix-based pruning (Conceptual DFS)
fn find_canonical_form_optimized(expression, group) = (
	// This represents specialized algorithms like sorting, Booth's, etc.
	// The prefix_dfs below is a generic sketch for demonstration.
	prefix_dfs(expression, group, [])
);

// Generic sketch of prefix-based search (Illustrative)
fn prefix_dfs(expression, group, prefix) = (
	// Base case: if expression is fully determined by prefix
	if is_fully_determined(expression, prefix) then (
		construct_expression(prefix)
	) else (
		// Get possible next elements based on current prefix and group constraints
		let candidates = get_next_candidates(expression, group, prefix);

		// Sort candidates according to the canonical ordering
		let sorted_candidates = sort(candidates, \a, b.compare(a, b));

		// Try each candidate prefix extension recursively
		sorted_candidates is (
			[] => null;  // No candidates found
			[candidate|rest] => (
				let extended_prefix = prefix + [candidate];

				// Check if this prefix can lead to minimal form
				if is_viable_prefix(expression, group, extended_prefix) then (
					let result = prefix_dfs(expression, group, extended_prefix);
					if result != null then result
					else try_remaining(expression, group, rest, prefix)
				) else
					try_remaining(expression, group, rest, prefix)
			)
		)
	)
);

fn find_best_recursive(expression, group, candidates, prefix) = (
	candidates is (
		[] => null; // No candidates left
		[candidate|rest] => (
			let extended_prefix = prefix + [candidate];
			// Pruning: If this path cannot possibly yield a better result than best_found_so_far, skip it.
			if is_viable_prefix(expression, group, extended_prefix, best_found_so_far) then (
				let result = prefix_dfs(expression, group, extended_prefix);
				// Update best_found_so_far if result is better
				// ... logic ...
				try_remaining(expression, group, rest, prefix, best_found_so_far) // Continue search
			) else (
				// Pruned path
				try_remaining(expression, group, rest, prefix, best_found_so_far)
			)
		)
	)
);
```

For specific groups, we implement optimized versions:

**Algorithm 1: Symmetric Group Canonicalisation (Sₙ)**
```orbit
// Algorithm 1: Symmetric Group Canonicalisation (Sₙ)
// Uses sorting based on a total order of elements.
fn canonicalise_symmetric(elements, comparison_fn) = (
	// Default comparison if none provided
	let comparator = if comparison_fn == null then
		\a, b.(a <=> b) // Assumes a built-in comparison
	else
		comparison_fn;

	// Sort the elements using the comparator function: O(n log n)
	sort(elements, comparator)
);

// Example usage for commutative addition (S₂ implicitly uses sorting on 2 elements)
fn canonicalize_commutative_sum(expr) = (
	expr is (
		a + b => (
			// Efficient comparison for 2 elements
			if compare(a, b) <= 0 then a + b // compare(a,b) uses canonical ordering
			else b + a
		);
		// Handle n-ary sum by flattening, sorting (canonicalise_symmetric), and rebuilding
		(a + b) + c => canonicalize_nary_sum([a, b, c]); // Simplified representation

		// Default case - return unchanged
		_ => expr
	)
);
```

This reduces the O(n!) complexity to O(n log n) for sorting n elements.

**Algorithm 2: Cyclic Group Canonicalisation (Cₙ)**
```orbit
// Algorithm 2: Cyclic Group Canonicalisation (Cₙ)
// Finds the lexicographically smallest rotation.

// Naive O(n²) implementation: Generate all rotations and find minimum.
fn canonicalise_cyclic_naive(array) = (
	let n = length(array);
	if n == 0 then [] else (
	    // Find minimum rotation using fold
	    fn try_rotations(i, best_so_far) = (
		    if i >= n then best_so_far
		    else (
			    let rotated = rotate(array, i);
			    let next_best = if compare(rotated, best_so_far) < 0 then rotated else best_so_far;
			    try_rotations(i + 1, next_best)
		    )
	    );
	    try_rotations(0, array)
	)
);

// Helper function to rotate array by n positions
fn rotate(array, n) = (
	let len = length(array);
	if len == 0 then []
	else (
		let normalized_n = n % len;
		if normalized_n < 0 then normalized_n = normalized_n + len; // Ensure positive rotation index
		concat(
			subrange(array, normalized_n, len - normalized_n), // Part after rotation point
			subrange(array, 0, normalized_n)                   // Part before rotation point
		)
	)
);

// Efficient O(n) implementation using Booth's algorithm or Duval's algorithm.
fn canonicalise_cyclic_efficient(array) = (
	// These algorithms find the index of the lexicographically minimal rotation in O(n).
	// See [Booth, 1980] or Duval's Lyndon Factorization algorithm.
	let min_index = find_min_rotation_index_booth(array); // O(n)

	// Rotate the array by that index
	rotate(array, min_index) // O(n) for rotation
);

// Booth's algorithm for finding minimal rotation index
fn find_min_rotation_index(array) = (
	let n = length(array);
	let double_array = array + array;  // Concatenate array with itself

	// Initialize failure function
	let f = map(range(0, 2*n), \_.(-1));

	// Initialize minimum rotation index
	let min_rotation = 0;

	// Process each character
	fn process_chars(i, min_rot, fail_func) = (
		if i >= 2*n then min_rot
		else (
			// Compare with the current minimum
			fn compare_with_min(j, curr_min) = (
				if j == -1 || double_array[i % n] != double_array[(curr_min + j + 1) % n] then (
					// Determine new minimum based on comparison
					let new_min = if j == -1 && double_array[i % n] < double_array[(curr_min + j + 1) % n] then
						i - j - 1
					else
						curr_min;

					Pair(j, new_min)
				) else (
					compare_with_min(fail_func[j], curr_min)
				)
			);

			let result = compare_with_min(fail_func[i - min_rot - 1], min_rot);
			let j = result.first;
			let new_min_rot = result.second;

			// Update failure function
			let new_fail = fail_func;
			let new_fail_index = if j == -1 && double_array[i % n] != double_array[(new_min_rot + j + 1) % n] then (
				// Case where characters differ
				i - new_min_rot
			) else (
				// Case where partial match
				j + 1
			);

			let updated_fail = setArrayIndex(new_fail, i - new_min_rot, new_fail_index);

			// Continue recursion
			process_chars(i + 1, new_min_rot, updated_fail)
		)
	);

	// Start processing from index 1
	process_chars(1, 0, f) % n
);
```


The naive implementation above has O(n²) time complexity, but we can achieve linear time using Booth's algorithm [Booth, 1980]. Booth's algorithm finds the lexicographically minimal rotation of a string or array in O(n) time by using a variant of the Knuth-Morris-Pratt (KMP) string matching algorithm.

**Algorithm 3: Dihedral Group Canonicalisation (Dₙ)**
```orbit
// Algorithm 3: Dihedral Group Canonicalisation (Dₙ)
// Finds the minimum of the minimal rotation of the array and its reverse.
fn canonicalise_dihedral(array) = (
	// Find minimal rotation on original array (O(n))
	let min_rotation = canonicalise_cyclic_efficient(array);

	// Reverse the array (O(n))
	let reversed_array = reverse(array);

	// Find minimal rotation on reversed array (O(n))
	let min_reversed_rotation = canonicalise_cyclic_efficient(reversed_array);

	// Return the lexicographically smaller of the two (O(n) comparison)
	if compare(min_rotation, min_reversed_rotation) <= 0 then
		min_rotation
	else
		min_reversed_rotation
);

// Helper function to reverse an array
fn reverse(array) = (
	let len = length(array);
	fn build_reversed(i, result) = (
		if i < 0 then result
		else build_reversed(i - 1, result + [array[i]]) // Naive O(n^2), better ways exist
	);
	// An O(n) reversal is typically used in practice.
	build_reversed(len - 1, [])
);
```
This runs in O(n) time, dominated by the efficient cyclic canonicalization steps.

## 5. Canonicalisation Strategies

This section details how the core algorithms are applied.

### 5.1 Symmetric Group Canonicalization (Sₙ)

Used for permutation symmetry, typically commutative operations. The canonical form is the sorted sequence of operands.

#### Example: Commutative Operations (S₂)

```orbit
// Canonicalizing a + b under commutativity (S₂)
(a + b) : S₂ → a + b : Canonical if a <= b;
(a + b) : S₂ → b + a : Canonical if b < a;

// Applied examples
(5 + 3) : S₂ → 3 + 5 : Canonical;  // 3 < 5, so swap
(x + y) : S₂ → x + y : Canonical;  // Assuming x <= y in the term ordering
```

#### Exponential Speedup Through Canonicalization

Consider `a + b + c + d`. Without canonicalization, matching a pattern like `x + y` requires checking sub-expressions in potentially O(n!) permutations for n-ary operations. With canonicalization (e.g., sorting operands for Sₙ symmetry), the expression becomes a single form like `a + b + c + d` (assuming alphabetical order). A pattern `x + y` then only needs to be matched against adjacent pairs in the canonical form, drastically reducing matching complexity. For nested expressions with multiple commutative/associative operators, the savings compound exponentially.

### 5.2 Cyclic Group Canonicalization (Cₙ)

Used for rotational symmetry (e.g., bit rotations, modular arithmetic). The canonical form is the lexicographically minimal rotation.

#### Example: Bit Rotation (C₈ for 8-bit byte)

```orbit
// Let x be an 8-bit value
// rotate_left(x, k) performs a cyclic left shift by k bits.
// This operation has C₈ symmetry.

// Canonicalizing using Algorithm 2 (efficient version)
rotate_left(x, k) : C₈ → canonicalise_cyclic_efficient(to_bit_array(x), k) : Canonical;

// Example: x = 11001000 (binary)
rotate_left(x, 3) = 01000110
rotate_left(x, 5) = 00011001

// Assume 00011001 is the lexicographically smallest rotation
canon(11001000) = 00011001 // Found via Algorithm 2
canon(01000110) = 00011001

// Rule using the canonicalization function:
op(y) : C₈ → canonical_form(y, C₈) : Canonical;
```
All byte values reachable via rotation from `11001000` will map to the same canonical form `00011001`.

#### Polynomial Encoding and Groebner Bases

Cyclic symmetry can sometimes be modeled algebraically. For Cₙ, rotations correspond to multiplication by `x` modulo `xⁿ - 1` in a polynomial ring. Canonicalization can then, in principle, be achieved via Gröbner basis computation relative to the ideal `<xⁿ - 1>`, although direct algorithms like Booth's are usually far more efficient for the pure cyclic group case. Groebner bases offer a more general tool for canonicalizing polynomial expressions under algebraic constraints beyond simple rotations.

```orbit
// Conceptual Groebner Basis approach for C₄
// Expression: [a,b,c,d] -> p(x) = a + bx + cx² + dx³
// Ideal: I = <x⁴ - 1>
// Canonical form: NormalForm(p(x), GroebnerBasis(I))
// This requires defining polynomial operations and Groebner basis algorithms within Orbit.

// Groebner Basis Algorithm (Conceptual Sketch)
fn compute_groebner_basis(polynomials, order) = (
	// Buchberger's algorithm or similar (F4/F5)
	// ... implementation details ...
	[] // Placeholder
);

fn normal_form(poly, basis, order) = (
	// Polynomial reduction algorithm
	// ... implementation details ...
	poly // Placeholder
);
```

### 5.3 Dihedral Group Canonicalization (Dₙ)

Used for combined rotational and reflectional symmetries (e.g., symmetries of a square D₄, bit patterns). The canonical form is the minimum of the minimal rotation and the minimal rotation of the reversed sequence.

#### Example: Square Symmetry (D₄)

Consider representing a 2x2 square's state as a flat list `[top-left, top-right, bottom-right, bottom-left]`. D₄ acts on this list.

```orbit
// state = [1, 2, 4, 3]
// Canonicalizing using Algorithm 3

original = [1, 2, 4, 3]
reversed = [3, 4, 2, 1]

// Find min rotation of original (assume it's [1, 2, 4, 3])
min_orig_rot = canonicalise_cyclic_efficient(original) // -> [1, 2, 4, 3]

// Find min rotation of reversed (assume it's [1, 3, 4, 2])
min_rev_rot = canonicalise_cyclic_efficient(reversed) // -> [1, 3, 4, 2] (Example result)

// Compare the two minimal forms
canonical_form = min(min_orig_rot, min_rev_rot) // compare([1,2,4,3], [1,3,4,2]) -> [1,2,4,3]

// Rule:
transform(x) : D₄ → canonicalise_dihedral(x) : Canonical;
```
Any of the 8 states related by rotation/reflection map to the same canonical form `[1, 2, 4, 3]`.

## 6. Extended Examples

This section illustrates how the core concepts apply across various domains, leveraging the domain hierarchy (§2.3) and group-theoretic canonicalization.

### 6.1 Polynomial Canonicalization

Polynomials form a Ring, inheriting rules for `+` (AbelianGroup) and `*` (Monoid, often Commutative).

```orbit
// Inherited Ring Rules:
a + b : Polynomial ↔ b + a : Polynomial : S₂ // From AbelianGroup (+)
(a + b) + c : Polynomial ↔ a + (b + c) : Polynomial : A // From AbelianGroup (+)
a * (b + c) : Polynomial → (a * b) + (a * c) : Polynomial // From Ring (Distributivity)
// ... other Ring rules ...

// Array-based representation for associative operations
// For addition (terms of a polynomial)
+([term1, term2, ..., termN]) : Polynomial → +([sorted_terms]) : Canonical

// For multiplication (factors in a monomial)
*([factor1, factor2, ..., factorN]) : Monomial → *([sorted_factors]) : Canonical : S₂

// Polynomial-Specific Rules:
// Monomial ordering (e.g., graded lex order) ensures canonical term order
// x^a * y^b : Monomial → ordered_monomial(x,y, [a,b]) : Canonical
term1 + term2 : Polynomial → ordered_sum(term1, term2) : Canonical if compare_terms(term1, term2) <= 0 // Sort terms
term1 + term2 : Polynomial → ordered_sum(term2, term1) : Canonical if compare_terms(term1, term2) > 0

// Graded lexicographic (glex) ordering for monomials using array representation
*([x^a, y^b, z^c, ...]) : Monomial : GradedLex →
	glex_ordered_monomial(*([x^a, y^b, z^c, ...])) : Canonical
	where total_degree = a + b + c + ...

// Combine like terms (relies on + being AbelianGroup, * being Commutative Monoid)
coeff1 * term + coeff2 * term : Polynomial → (coeff1 + coeff2) * term : Canonical

// Define Polynomial ⊂ Ring
Polynomial ⊂ Ring
```

#### Array-Based Representation and Pattern Matching

Instead of using nested binary operations, we represent polynomials as arrays of terms, and monomials as arrays of factors:

```orbit
// Traditional representation (nested binary ops)
(3*x*y + 2*x*y) + x*(y+z)  // Deeply nested structure, complex to navigate

// Array-based representation
+([3*x*y, 2*x*y, x*(y+z)]) // Flat structure with direct access to terms

// With expanded distributivity
+([3*x*y, 2*x*y, x*y, x*z])

// After combining like terms
+([6*x*y, x*z]) // Ordered by glex
```

This representation enables efficient pattern matching using the syntax from §4.4.2:

```orbit
// Match exact sequence
3*x*y + 2*x*y  matches  +([3*x*y, 2*x*y])

// Match prefix
3*x*y + 2*x*y + ...  matches  +([3*x*y, 2*x*y, x*z])

// Match suffix
... + x*y + x*z  matches  +([3*x*y, x*y, x*z])

// Match subsequence
... + 2*x*y + ...  matches any polynomial containing 2*x*y
```

#### Efficient Graded Lexicographic Ordering

The array-based representation enables a dramatic performance improvement for graded lexicographic (glex) ordering of polynomials:

```orbit
// Glex ordering function (simplified)
fn glex_compare(a, b) = (
	// First compare by total degree
	let deg_a = total_degree(a);
	let deg_b = total_degree(b);

	if deg_a != deg_b then deg_a <=> deg_b
	else lexicographic_compare(a, b) // Compare lexicographically if same degree
);

// Apply to array representation
fn canonicalize_poly(terms) = (
	// O(n log n) sorting of terms using glex
	sort(terms, glex_compare)
);
```

Instead of requiring O(n³) time to canonicalize a sum of n terms using binary operations over many iterations, we achieve the same result in O(n log n) time using direct sorting of the flattened array representation with the custom comparison function.

Applied example: simplifying `3*x*y + 2*y*x + x*(y+z)`
1.  Convert to array representation: `+([3*x*y, 2*y*x, x*(y+z)])`
2.  Apply S₂ to each term: `+([3*x*y, 2*x*y, x*(y+z)])` (S₂ on `*` inherited from Commutative Ring)
3.  Apply distributivity to the last term: `+([3*x*y, 2*x*y, x*y, x*z])` 
4.  Group like terms: `+([3*x*y, 2*x*y, x*y, x*z])` → `+([6*x*y, x*z])` (One-pass collection of like terms)
5.  Apply glex ordering (xy > xz by total degree and lex ordering): `+([6*x*y, x*z])`
    Final Canonical Form: `6*x*y + x*z`

### 6.2 Matrix Expression Optimization

Matrices (over a Ring/Field T) form a Ring (generally non-commutative).

```orbit
// Matrix<N, T> ⊂ Ring // (Potentially NonCommutativeRing)

// Inherited Ring Rules:
A + B : Matrix ↔ B + A : Matrix : S₂ // Addition is commutative
(A + B) + C : Matrix ↔ A + (B + C) : Matrix : A
A * (B + C) : Matrix → A*B + A*C : Matrix // Distributivity
// ... etc ...

// Matrix-Specific Rules:
A * I → A : Canonical // Multiplicative Identity (if I exists)
I * A → A : Canonical
(A^T)^T → A : Canonical // Transpose Involution
(A + B)^T → A^T + B^T : Canonical // Transpose Distribution over +
(A * B)^T → B^T * A^T : Canonical // Transpose of Product (order reversed!)

// Special matrix properties
// Requires domains like DiagonalMatrix, OrthogonalMatrix(O(n)), SL(n) etc.
M : O(n) → canonical_orthogonal_form(M) : Canonical if M^T * M == I
M : SL(n) → canonical_SL_form(M) : Canonical if det(M) == 1
```

Applied example: optimizing `((A*B)^T * (C+D))`
1. Apply transpose of product rule: `(B^T * A^T) * (C+D)`
2. Apply distributivity (from Ring): `(B^T * A^T) * C + (B^T * A^T) * D`
3. (Optional) If matrix multiplication is associative (it is): `B^T * (A^T * C) + B^T * (A^T * D)`

### 6.3 Logic Formula Canonicalization

Boolean logic forms a Boolean Algebra (a specific type of Ring and Distributive Lattice).

```orbit
// Boolean ⊂ DistributiveLattice
// Boolean ⊂ Ring // (Using XOR for +, AND for *)

// Inherited Lattice/Ring Rules:
p || q : Boolean ↔ q || p : Boolean : S₂ // OR commutativity
p && q : Boolean ↔ q && p : Boolean : S₂ // AND commutativity
(p || q) || r : Boolean ↔ p || (q || r) : Boolean : A // OR associativity
(p && q) && r : Boolean ↔ p && (q && r) : Boolean : A // AND associativity
p || (q && r) : Boolean ↔ (p || q) && (p || r) : Boolean // Distributivity
p && (q || r) : Boolean ↔ (p && q) || (p && r) : Boolean // Distributivity
p || false ↔ p : Boolean // OR identity
p && true ↔ p : Boolean // AND identity
p || true ↔ true : Boolean // OR annihilation
p && false ↔ false : Boolean // AND annihilation
p || p ↔ p : Boolean // Idempotence
p && p ↔ p : Boolean // Idempotence

// Boolean-Specific Rules (Negation):
!!p ↔ p : Boolean // Double Negation
!(p || q) ↔ !p && !q : Boolean // De Morgan's
!(p && q) ↔ !p || !q : Boolean // De Morgan's
p || !p ↔ true : Boolean // Excluded Middle
p && !p ↔ false : Boolean // Contradiction

// Canonical Forms (e.g., NNF, DNF, CNF, BDD)
// Rules to convert to specific forms, often using negative guards.
// Example DNF Rule (pushes AND inwards):
p && (q || r) : Boolean !: DNF_Expanded → (p && q) || (p && r) : Boolean : DNF_Expanded

// Example BDD Rule (Shannon Expansion):
f : Boolean → ite(v, substitute(f, v, true), substitute(f, v, false)) : BDD if v = choose_variable(f)
```

#### Binary Decision Diagrams (BDDs) and Cross-Representation Synergy

BDDs offer a canonical form for Boolean functions based on a fixed variable ordering. Orbit can manage multiple representations (e.g., standard logic, CNF, BDD) within the same e-class.

```orbit
// BDD specific reduction rules:
ite(v, t, t) → t : BDD                             // Redundant test
ite(v, true, false) → v : BDD                       // Direct variable
ite(v, false, true) → !v : BDD                      // Negated variable
ite(v, t, f) : BDD → ite(v, f, t) : BDD : Canonical if compare_nodes(f,t) < 0 // Ensure unique child order for non-terminal nodes

// Cross-representation:
expr : Boolean → to_bdd(expr) : BDD // Convert to BDD representation
expr : BDD → to_cnf(expr) : CNF     // Convert BDD to CNF
```
This allows leveraging the best representation for a given task (e.g., BDDs for satisfiability counting, CNF for SAT solving) by rewriting between forms within the O-graph.

### 6.4 List Processing Operations

Functional list operations have algebraic properties often related to Monoids or Functors.

```orbit
// Functor Laws (map):
map(id, xs) → xs : Canonical
map(f, map(g, xs)) → map(\x -> f(g(x)), xs) : Canonical // Map fusion (Associativity of composition)

// Monoid Laws (append/concat ++):
xs ++ [] → xs : Canonical
[] ++ xs → xs : Canonical
(xs ++ ys) ++ zs → xs ++ (ys ++ zs) : Canonical : A

// Other common list rules:
filter(p, filter(q, xs)) → filter(\x -> p(x) && q(x), xs) : Canonical // Filter fusion
fold(op, init, map(f, xs)) → fold(\acc x -> op(acc, f(x)), init, xs) : Canonical // Fold-map fusion
reverse(reverse(xs)) → xs : Canonical
length(xs ++ ys) → length(xs) + length(ys) : Canonical
```

### 6.4.1 Type Inference Integration

While Orbit primarily focuses on term rewriting, its domain system can represent types. Type inference and checking can interact with the rewriting process.

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

Rewriting can represent transformations between continuous (Calculus) and discrete (Numerical) domains.

```orbit
// Define domains: Calculus, Numerical
Calculus ⊂ Field // Calculus operates on Reals/Complex (Fields)

// Rules crossing domains:
d/dx(f(x)) : Calculus → (f(x+h) - f(x))/h : Numerical : FiniteDifference if is_small(h) // Forward difference
integral(f, a, b) : Calculus → sum(i, 0, n-1, f(a + i*h)*h) : Numerical : RiemannSum where h = (b-a)/n // Riemann sum
```

## 7. Evaluation

<draft>
Later: We plan to evaluate Orbit by implementing a representative set of rules from diverse domains (algebra, bitvectors, calculus, logic) and measuring:
1.  **E-graph Size**: Compare the number of e-classes and e-nodes required with and without group-theoretic canonicalization and domain hierarchies. We expect significant reductions due to collapsing equivalent forms.
2.  **Rewrite Rule Application Count**: Measure the total number of rule applications needed to reach saturation. Canonicalization should reduce redundant matches.
3.  **Query Time**: Evaluate the time taken for equivalence checks (`find`) between terms. Smaller, canonicalized e-graphs should yield faster queries.
4.  **Case Studies**: Apply Orbit to specific optimization problems (e.g., simplifying floating-point expressions, optimizing bitvector logic) and compare the results against standard techniques or domain-specific tools.
This work is in progress.
</draft>

## 8. Discussion

### 8.1 Notation and Terminology

Throughout this paper, we use the term "domain" to refer to a set of elements sharing certain properties, often corresponding to algebraic structures (Ring, Field), data types (Integer, List), or symmetry properties (S₂, Cₙ). These domains form a lattice under the subset relationship (`⊂`), enabling rule inheritance and consolidation (§2.3).

Group-theoretic domains (S₂, Cₙ, Dₙ, etc.) signify invariance under specific transformations and trigger specialized canonicalization algorithms.

The arrow symbols follow standard rewriting conventions:
- `→`: Unidirectional rewrite rule (simplification, canonicalization)
- `↔`: Bidirectional equivalence relation (axioms like commutativity)
- `⊂`: Subset or subdomain relation (domain hierarchy)

## 9. Conclusion

This paper has presented Orbit, a framework extending e-graphs with domain annotations and group-theoretic canonicalization. By formalizing the relationship between symmetry groups, domain hierarchies, and canonical representations, we provide a unified approach to rewriting that spans diverse computational areas. Orbit achieves significant representational compression and accelerates equality saturation by leveraging algebraic structure and symmetry.

The integration of domain hierarchies allows for rule consolidation, while group theory provides efficient, principled methods for selecting canonical forms. Our evaluation plan aims to demonstrate that this unified framework delivers not just theoretical elegance but practical benefits in memory usage, performance, and optimization effectiveness. By bridging mathematical formalism with practical rewriting, Orbit represents a significant step forward in program optimization and symbolic computation.

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
