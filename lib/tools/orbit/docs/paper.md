# Canonical Forms and Group-Theoretic Rewriting in the Orbit System

## Abstract

Canonical forms are indispensable for equality reasoning, pattern matching, and optimisation. We present Orbit, an extension of e-graphs that attaches domain annotations and group-theoretic metadata to e-classes. Exploiting the action of symmetry groups (Sₙ, Cₙ, Dₙ, …) on expressions we derive canonical representatives, transfer rewrite rules across domains, and obtain exponential reductions in search space. The framework unifies canonicalisation strategies from bit-vector algebra to differential calculus within a single mathematical language. Our implementation builds on a minimal Scheme-like foundation, using n-ary S-expressions for associative/commutative operations and combining natural mathematical syntax with powerful functional programming abstractions.

<!-- TODO: Add a concrete performance improvement or example domain to immediately convey practical benefits -->

## 1. Introduction

### Problem

Canonical forms provide unique names for equivalence classes; compilers, computer algebra systems, and theorem provers rely on them to curb combinatorial explosion. Existing solutions are siloed and recreate the same ideas—commutativity sorting, cyclic-shift minima, matrix normal forms—in domain-specific ad-hoc code.

### Gap

No current equality-saturation engine offers first-class knowledge of algebraic symmetry groups; consequently many optimisations and proofs have to be encoded manually.

<!-- TODO: Clarify explicitly how Orbit differs fundamentally from existing approaches (such as standard e-graphs) and highlight the exact novelty compared to other group-aware canonicalisation approaches -->

### Contribution

We propose Orbit, a framework unifying canonical forms and rewriting; its concrete storage layer is the O-Graph data structure, an e-graph enriched with domains and group metadata.

1.  **Domain-annotated e-classes**: Multiple domain tags per class enable property inheritance along a user-defined lattice.
2.  **Group-theoretic canonicalisation**: Orbits under a group action are collapsed by selecting a representative via deterministic algorithms.
3.  **Uniform rewrite language**: A natural syntax with typed patterns, negative domain guards, and bidirectional rewriting rules.

### A Motivating Example: Commutative Addition

Consider the simple case of integer addition, which is commutative: `3 + 5 = 5 + 3`. Without canonicalisation, a system would need to store and match against both forms. With Orbit, we can annotate the addition operator with the Sₙ symmetry group (where n is the number of operands) and provide a canonicalising rule that sorts the operands. When `3 + 5` is added, it might be internally represented as `(+ 3 5)`. Adding `5 + 3` results in the same internal representation `(+ 3 5)` after sorting, or the two nodes are merged.

```orbit
// Canonicalisation rule based on sorting arguments for S_n symmetry
// This rule would be applied internally during O-Graph operations
// or triggered by a rule like: `+`(args...) : S_n → `+`(sort(args...));

// Applied examples during saturation
addOGraph(g, 5 + 3); // Internally becomes `+`(3, 5) after sorting
addOGraph(g, 3 + 5); // Also becomes `+`(3, 5) after sorting
// Both expressions map to the same e-class with `+`(3, 5) as the representative.
```

This approach automatically collapses equivalent forms into a single representative in the O-Graph, reducing storage and improving matching efficiency. For multi-term expressions like `a + b + c + d` (internally `(+ a b c d)`), sorting handles `S₄` symmetry directly in O(n log n) time.

### Why canonical forms matter

A canonical representative collapses each orbit to one concrete term, so a pattern need be matched once per e-class rather than once per variant. Under Sₙ symmetry the raw permutation count grows as n!, yet canonical sorting yields a single ordered list of arguments; for nested commutative–associative expressions the savings compound exponentially because the n-ary representation avoids nesting issues. Formally, given an expression set E and symmetry group G acting on it, naïve exploration touches O(|E|·|G|) nodes, whereas canonicalisation limits the search to O(|E|) plus the time required to establish the canonical form (e.g., O(n log n) for Sₙ sorting).

*See §5.3 for the formal treatment of group actions and §5.4 for correctness proofs and complexity analysis.*

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
0 + x       → x             // Additive identity (matches `+`(0, x))
1 * x       → x             // Multiplicative identity (matches `*`(1, x))
0 * x       → 0             // Multiplicative zero (matches `*`(0, x))
x / y       → x * y⁻¹       if  y ≠ 0 // Use inverse explicitly
x + y       ↔ y + x          if y < x // Rule triggering S_2 sorting manually
```

### 2.2 Domain annotations (:)

A term `t : D` states that `t` belongs to domain `D`.

```orbit
`+`(args...) : Sₙ        // commutative n-ary addition (annotation on operator/expression)
n           : Integer    // n belongs to the Integer domain
f(g(x))     : Differentiable // Expression belongs to Differentiable domain
```

Domain-constrained rule:

```orbit
x + y : Real  →  y + x : Real
```

The left hand side `: Real` is a restriction (match only if the expression is already known to be `Real`), while the right hand side `: Real` is an entailment (assert that the result is also `Real`).

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
Magma                     // Binary operation
Semigroup ⊂ Magma         // Add associativity
Monoid ⊂ Semigroup        // Add identity element
Group ⊂ Monoid            // Add inverse
AbelianGroup ⊂ Group      // Add commutativity (implies Sₙ symmetry for op)

// Ring-like structures (two operations: +, *)
Semiring                  // Additive Monoid, Multiplicative Monoid + distributivity
Ring ⊂ Semiring           // Extends Additive AbelianGroup
CommutativeRing ⊂ Ring    // Add multiplicative commutativity (*) - implies * : Sₙ
Field ⊂ CommutativeRing   // Add multiplicative inverse for non-zero

// Concrete domains inheriting structure
Integer ⊂ CommutativeRing
Rational ⊂ Field
Real ⊂ Field
Complex ⊂ Field
BitVector<N> ⊂ Ring       // Ring Modulo 2^N
Set ⊂ DistributiveLattice // Set operations form a lattice
```

A rule defined for a higher-level structure applies automatically to any subdomain. For example:

```orbit
// Associativity is inherent in the n-ary S-expression representation for Semigroup ops like +,*
// Commutativity defined once for AbelianGroup using Sₙ symmetry
`+`(args...) : AbelianGroup → `+`(sort(args...)) : AbelianGroup : Sₙ
```

These general rules are then automatically applicable to Integers, Reals, BitVectors, etc., wherever they are declared as subdomains of `AbelianGroup`. This hierarchical approach significantly reduces rule duplication. The group-theoretic canonicalisation (e.g., `: Sₙ` for commutativity via sorting) ensures consistent representation regardless of the specific domain. Section 7 provides further examples demonstrating this cross-domain rule application.

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

## 3. Implementation Architecture

The implementation of Orbit follows a multi-layered approach with a functional core.

### 3.1 Scheme-based Foundation

Orbit's implementation begins with a minimal Scheme-like language that serves as the system's functional core, called S-Expressions.

1. **Functional foundation**: We leverage the expressive power of a Lisp-like language, including higher-order functions, lexical scope, and recursion.
2. **Pattern matching**: Native support for symbolic pattern matching forms the basis of our rewrite system.
3. **Quasiquotation**: We use Scheme's powerful quasiquotation machinery (template expressions with unquoted components) to efficiently construct and manipulate ASTs.
4. **Minimalism**: The core language is intentionally small, focusing on essential functional programming features.
5. **N-ary Representation**: S-expressions naturally support n-ary structures like `(+ 1 2 3)`, which directly represent flattened associative/commutative operations.

This Scheme-like layer provides a clean, functional foundation that simplifies the implementation of the rest of the system while naturally supporting symbolic computation patterns central to term rewriting.

### 3.2 Representation Pipeline

Orbit maintains multiple coordinated representations that allow for both natural syntax and efficient computation:

```
Orbit Math Notation ⟷ S-Expression AST ⟷ O-Graph Structure
```

These representations are connected through a bidirectional conversion pipeline with the following operations:

| Operation | Description |
|-----------|-------------|
| `parseSExpr(string)` | Parse S-expression string to AST |
| `prettySExpr(SExpr)` | Render AST as S-expression string |
| `addOGraph(SExpr)` | Add S-expression to O-Graph, returns node ID |
| `extractOGraph(int)` | Extract S-expression from O-Graph node |
| `parseOrbit(string)` | Parse Orbit math notation to AST |
| `prettyOrbit(OrbitMath)` | Render AST as Orbit math notation |
| `sexpr2orbit(SExpr)` | Convert S-expression to Orbit math AST |
| `orbit2sexpr(OrbitMath)` | Convert Orbit math AST to S-expression |

This pipeline allows us to provide a natural math-like syntax to users while leveraging the power of n-ary S-expressions for efficient internal canonicalisation and pattern matching.

### 3.3 Syntax Transformation

A key insight in our implementation is that Orbit's mathematical notation can be systematically translated to and from S-expressions. For example, the Orbit expression:

```orbit
(a + b + c) : S₃ // Assuming '+' is A/C
```

Is internally represented as the S-expression:

```scheme
(: (+ a b c) S₃)
```

A rewrite rule like:

```orbit
`+`(args...) : Sₙ → `+`(sort(args...));
```

Is represented internally as:

```scheme
(rule (: (+ args ...) Sₙ) (+ (call sort (variable args))))
```

This translation preserves the semantics while making the expression amenable to manipulation using standard functional programming techniques. The rule application logic can be elegantly expressed using pattern matching on these S-expressions.

### 3.4 Term Rewriting via Pattern Matching

Pattern matching and quasiquotation from the Scheme foundation provide powerful mechanisms for implementing term rewriting on the S-expression representation.

```scheme
(define (apply-rule expr)
	(match expr
	; Pattern for a commutative n-ary operation with Sₙ symmetry
	(annotate (?op (?args ...)) Sₙ)
	  ; Canonicalise by sorting args
	  (let ([sorted-args (sort args)])
		; Only rewrite if args weren't already sorted
		(if (not (equal? args sorted-args))
			`(,op ,@sorted-args)
			expr))
	; Default case: return unchanged
	_ expr))
```

This approach allows complex rewrite rules operating on n-ary structures to be expressed concisely.

### 3.5 O-Graph Integration

The final layer in our architecture is the O-Graph, which stores the canonicalized terms and their relationships. By converting Orbit expressions to S-expressions, we can easily integrate with the O-Graph structure:

1. Parse Orbit math notation to an AST.
2. Convert to S-expression representation (flattening associative ops).
3. Apply the S-expression to the O-Graph.
4. Perform canonicalisation (e.g., sorting argument lists for `Sₙ`) based on group-theoretic properties.
5. Extract results (potentially reconstructing binary trees for display) and convert back to Orbit notation as needed.

This layered approach gives us the best of both worlds: a natural mathematical syntax for human interaction and a powerful, functional core leveraging n-ary S-expressions for efficient term manipulation and rewriting.

## 4. O-Graph Data Structure vs. Traditional E-Graphs

<!-- TODO: Add illustrative example comparing e-graph vs O-Graph with n-ary forms -->

### 4.1 Recap of e-graphs

An e-graph stores e-nodes (operators with e-class children) and e-classes (sets of equivalent e-nodes). Equality saturation repeatedly applies rewrite rules until no new equivalent terms can be added. Congruence Closure ensures that if `a = c` and `b = d`, then `f(a,b) = f(c,d)` for any operator `f`.

### 4.2 O-Graph extensions

1.  **Domain membership**: Each e-class carries a set of domains it belongs to (e.g., `Integer`, `Ring`, `Sₙ`). Domains are terms, enabling hierarchical relations (§2.3).
2.  **Group metadata**: Group domains (`Sₙ`, `C₄`) trigger canonicalisation algorithms (e.g., sorting argument lists for `Sₙ`).
3.  **Root Representative**: Each e-class has a designated **representative (root)** e-node. The `mergeOGraphNodes(root_id, other_id)` operation establishes `root_id` as this representative. Rewrite rules are applied repeatedly during saturation. This process drives the representative node towards the unique canonical form defined by the system's group-theoretic rules and ordering criteria.

Example:

```
eclass42 = {
	// Nodes represent S-expressions
	nodes = { (+ 5 3), (+  3 5) },
	belongsTo = { Integer, CommutativeRing, Sₙ }, // Domain membership
	representative = (+ 3 5) // Designated root, result of Sₙ sorting
}
```

**Canonical Forms vs. Cost Function:** Unlike traditional e-graphs that rely on cost functions to extract the "best" expression, Orbit uses canonical forms driven by domain annotations. The representative node *is* the canonical form. Different domains might define different canonical forms, allowing extraction based on desired properties (e.g., extract a form optimized for size vs. speed).

## 5. Group-Theoretic Foundations

### 5.1 Core Symmetry Groups

Our system formalises several key symmetry groups that commonly arise in computation:

| Group | Order | Description                     | Canonicalisation strategy (in S-Expr context) | Example Use Case                  |
|-------|-------|---------------------------------|-----------------------------------------------|-----------------------------------|
| Sₙ    | n!    | Symmetric group (permutations)  | Sort argument list of n-ary S-expression    | Commutative ops (`+`, `*`), Sets  |
| Cₙ    | n     | Cyclic group (rotations)        | Lexicographic minimum over rotations (Booth)  | Modular arithmetic, bit rotations |
| Dₙ    | 2n    | Dihedral (rotations+reflections) | Min over rotations and reflections         | Geometric symmetry, bit patterns  |

These fundamental groups appear across diverse domains:
- Sₙ: Commutative operations (addition, multiplication, AND, OR) represented as n-ary S-expressions.
- Cₙ: Cyclic structures (circular buffers, machine integer arithmetic).
- Dₙ: Geometric symmetries (regular polygons, matrix transformations).

### 5.2 Group Isomorphisms and Relationships

Many computational domains share underlying group structures. For example:

- C₂ ≅ S₂: The cyclic group of order 2 is isomorphic to the symmetric group S₂
- D₁ ≅ C₂: The dihedral group of order 2 is isomorphic to the cyclic group C₂
- D₃ ≅ S₃: The dihedral group D₃ is isomorphic to the symmetric group S₃

These relationships allow us to transfer canonicalisation strategies between domains that share the same underlying symmetry group. An operation identified with `C₂` symmetry can reuse the canonicalisation logic developed for `S₂`.

### 5.3 Group Actions and Orbits

Canonical forms are derived through group actions on expressions. When a group G acts on a set X, it partitions X into orbits. We select a canonical representative from each orbit using a consistent ordering criterion (e.g., lexicographical minimum):

```
Orbit(x) = {g • x | g ∈ G} // The orbit of x under group G's action
canon(x) = min(Orbit(x))  // The canonical form is the minimum element in the orbit
```
The O-Graph stores only the canonical representative `canon(x)` explicitly, while recognizing that all elements in `Orbit(x)` belong to the same e-class.

### 5.4 Formal Correctness and Complexity

The correctness of our canonicalisation approach relies on the following theorem:

**Theorem 1**: *Let G be a finite group acting on a set X, and let ≤ be a total ordering on X. For any x ∈ X, the element min(Orbit(x)) is a unique canonical representative of the orbit of x under G's action.*

Proof sketch: Since G is finite, Orbit(x) is finite. The minimum element under a total ordering ≤ is unique, ensuring that the canonical representative is well-defined and consistent. Since all elements in Orbit(x) are equivalent under G's action (by definition of an orbit), choosing any consistent representative (such as the minimum) preserves the equivalence relation.

Example: Consider the internal S-expressions `(+ 5 3)` and `(+ 3 5)`. The orbit under `S₂` action (argument swapping) is {`(+ 5 3)`, `(+ 3 5)`}. With standard argument ordering (based on node IDs or values), `min(Orbit((+ 5 3)))` is uniquely `(+ 3 5)`.

### 5.4.1 N-ary S-Expression Representation for Associative Operations

To efficiently handle associative and commutative operations, we natively use n-ary S-expressions in the backend representation, rather than nested binary operators.

**Definition**: *For an associative operation ⊗ (like `+`, `*`, `∧`, `∨`), we represent expressions `x₁ ⊗ x₂ ⊗ ... ⊗ xₙ` directly as the S-expression `(op x₁ x₂ ... xₙ)`.*

Example: The expression `a + b + c + d` is represented internally as `(+ a b c d)`.

This n-ary representation allows for:
1. Direct application of `Sₙ` group actions (sorting) on the argument list.
2. Efficient pattern matching on the flattened structure.
3. Single-pass sorting O(n log n) for canonicalisation under commutativity.
4. Simplified rule application without tree traversal for associativity.

**Meta-Algorithm: Finding Canonical Forms**

Our approach to canonicalisation follows a general meta-algorithm pattern:

1.  **Identification**: Recognize the symmetry group G associated with an expression node `x` (e.g., `Sₙ` for `(+ ...)`).
2.  **Action**: Understand the group action `g • x` (e.g., permuting arguments for `Sₙ`).
3.  **Selection**: Efficiently compute `canon(x) = min(Orbit(x))` using group-specific algorithms applied directly to the n-ary S-expression structure (e.g., sorting the argument list for `Sₙ`).
4.  **Optimization**: Use domain-specific algorithms (sorting for Sₙ, Booth's for Cₙ, etc.) to find the minimum efficiently.

### 5.4.2 Pattern Matching within S-Expression Lists

The n-ary S-expression representation enables efficient pattern matching within the argument lists using syntax extensions:

| Pattern Example (Conceptual) | Description | Matches in `(+ a b c d e)` |
|------------------------------|-------------|--------------------------|
| `(+ a b c)`                  | Match exact arguments (arity 3) | No |
| `(+ 1 2 args...)`             | Match prefix | `(+ 1 2 c d e)` (if a=1, b=2) |
| `(+ ... x y z)`              | Match suffix | `(+ a b c d e)` (if c=x, d=y, e=z) |
| `(+ ... x y ...)`            | Match subsequence | `(+ a b c d e)` (e.g., if b=x, c=y) |
| `(+ args...)`                 | Match all arguments | `(+ a b c d e)` (binds `args` to `(a b c d e)`) |

This pattern matching is particularly powerful for rewrite rules.

**Example**: A rule matching `x+y+z` where `y` is a constant can efficiently find all such patterns in a large sum without needing to consider all binary partitions of the expression.

This approach combines naturally with the S-expression foundation described in §3.1, as pattern matching on arrays maps directly to pattern matching on S-expression lists.

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
		let sorted_candidates = sort(candidates, λ(a, b).compare(a, b));

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
		λ(a, b).(a <=> b) // Assumes a built-in comparison operator
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
	let f = map(range(0, 2*n), λ_.(-1));

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
This runs in O(n) time, dominated by the efficient cyclic canonicalisation steps.


## 6. Evaluating S-Expressions in the O-Graph

(TODO: Explain this section based on the final implementation)

## 7. Canonicalisation Strategies

### 7.1 Symmetric Group Canonicalisation (Sₙ)

Used for permutation symmetry. The canonical form is achieved by **sorting the argument list** of the n-ary S-expression representation based on a canonical ordering of the arguments (e.g., by node ID or structural comparison).

#### Exponential Speedup Through Canonicalisation

Consider `a + b + c + d`, represented internally as `(+ a b c d)`. Without canonicalisation, matching a pattern like `x + y` against all possible binary groupings is complex. With the n-ary form canonicalized by sorting (e.g., `(+ a b c d)` assuming a<b<c<d), matching becomes simpler. A pattern matching `x + y` needs to be adapted to the n-ary structure (e.g., matching adjacent elements `... x y ...` or binding specific arguments). The primary gain is representing the *entire equivalence class* (all permutations and associations) with a single, sorted n-ary node, drastically reducing the size of the O-Graph and the number of nodes rules need to consider.

### 7.2 Cyclic Group Canonicalisation (Cₙ)

Used for rotational symmetry (e.g., bit rotations, modular arithmetic). The canonical form is the lexicographically minimal rotation.

#### Example: Bit Rotation (C₈ for 8-bit byte)

```orbit
// Let x be an 8-bit value
// rotate_left(x, k) performs a cyclic left shift by k bits.
// This operation has C₈ symmetry.

// Canonicalizing using Algorithm 2 (efficient version)
rotate_left(x, k) : C₈ → canonicalise_cyclic_efficient(to_bit_array(x), k);

// Example: x = 11001000 (binary)
rotate_left(x, 3) = 01000110
rotate_left(x, 5) = 00011001

// Assume 00011001 is the lexicographically smallest rotation
canon(11001000) = 00011001 // Found via Algorithm 2
canon(01000110) = 00011001

// Rule using the canonicalization function:
op(y) : C₈ → canonical_form(y, C₈);
```
All byte values reachable via rotation from `11001000` will map to the same canonical form `00011001`.

#### Polynomial Encoding and Groebner Bases

Cyclic symmetry can sometimes be modeled algebraically. For Cₙ, rotations correspond to multiplication by `x` modulo `xⁿ - 1` in a polynomial ring. Canonicalisation can then, in principle, be achieved via Gröbner basis computation relative to the ideal `⟨xⁿ - 1⟩`, although direct algorithms like Booth's are usually far more efficient for the pure cyclic group case. Groebner bases offer a more general tool for canonicalizing polynomial expressions under algebraic constraints beyond simple rotations.

```orbit
// Conceptual Groebner Basis approach for C₄
// Expression: [a,b,c,d] -> p(x) = a + bx + cx² + dx³
// Ideal: I = ⟨x⁴ - 1⟩
// Canonical form: normal_form(p(x), groebner_basis(I))
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

### 7.3 Dihedral Group Canonicalisation (Dₙ)

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
transform(x) : D₄ → canonicalise_dihedral(x);
```
Any of the 8 states related by rotation/reflection map to the same canonical form `[1, 2, 4, 3]`.

## 8. Extended Examples

This section illustrates how the core concepts apply across various domains, leveraging the domain hierarchy (§2.3) and group-theoretic canonicalisation.

### 8.1 Polynomial Canonicalisation

Polynomials form a Ring, inheriting rules for `+` (AbelianGroup) and `*` (Monoid, often Commutative).

```orbit
// Inherited Ring Rules:
a + b : Polynomial ↔ b + a : Polynomial : S₂ // From AbelianGroup (+)
(a + b) + c : Polynomial ↔ a + (b + c) : Polynomial // From AbelianGroup (+) - A for Associativity implied by n-ary form
a * (b + c) : Polynomial → (a * b) + (a * c) : Polynomial // From Ring (Distributivity)
// ... other Ring rules ...

// Array-based representation for associative operations
// For addition (terms of a polynomial)
+([term1, term2, ..., termN]) : Polynomial → +([sorted_terms])

// For multiplication (factors in a monomial)
*([factor1, factor2, ..., factorN]) : Monomial → *([sorted_factors]) : S₂

// Polynomial-Specific Rules:
// Monomial ordering (e.g., graded lex order) ensures canonical term order
// x^a * y^b : Monomial → ordered_monomial(x,y, [a,b])
term1 + term2 : Polynomial → ordered_sum(term1, term2) if compare_terms(term1, term2) <= 0 // Sort terms
term1 + term2 : Polynomial → ordered_sum(term2, term1) if compare_terms(term1, term2) > 0

// Graded lexicographic (glex) ordering for monomials using array representation
*([x^a, y^b, z^c, ...]) : Monomial : GradedLex →
	glex_ordered_monomial(*([x^a, y^b, z^c, ...]))
	where total_degree = a + b + c + ...

// Combine like terms (relies on + being AbelianGroup, * being Commutative Monoid)
coeff1 * term + coeff2 * term : Polynomial → (coeff1 + coeff2) * term

// Define Polynomial ⊂ Ring
Polynomial ⊂ CommutativeRing
```

#### Efficient Graded Lexicographic Ordering

The n-ary S-expression representation enables O(n log n) sorting of terms for GLEX ordering, directly applied to the argument list of the `+` node.

Applied example: simplifying `3*x*y + 2*y*x + x*(y+z)`
1.  Internal S-expression: `+`(`*`(3, x, y), `*`(2, y, x), `*`(x, `+`(y, z)))`
2.  Canonicalize `*` terms (sort args): `+`(`*`(3, x, y), `*`(2, x, y), `*`(x, `+`(y, z)))`
3.  Apply distributivity: `+`(`*`(3, x, y), `*`(2, x, y), `*`(x, y), `*`(x, z))`
4.  Combine like terms (operates on list): `+`(`*`(6, x, y), `*`(x, z))`
5.  Sort terms by GLEX: `+`(`*`(6, x, y), `*`(x, z))` (assuming xy > xz)
    Final Canonical Form (S-expr): `(+ (* 6 x y) (* x z))`

### 8.2 Matrix Expression Optimization

Matrices (over a Ring/Field T) form a Ring (generally non-commutative).

```orbit
// Matrix<N, T> ⊂ Ring // (Potentially NonCommutativeRing)

// Inherited Ring Rules:
A + B : Matrix ↔ B + A : Matrix : S₂ // Addition is commutative
(A + B) + C : Matrix ↔ A + (B + C) : Matrix // Associativity handled by n-ary form
A * (B + C) : Matrix → A*B + A*C : Matrix // Distributivity
// ... etc ...

// Matrix-Specific Rules:
A * I → A // Multiplicative Identity (if I exists)
I * A → A
(Aᵀ)ᵀ → A // Transpose Involution
(A + B)ᵀ → Aᵀ + Bᵀ // Transpose Distribution over +
(A * B)ᵀ → Bᵀ * Aᵀ // Transpose of Product (order reversed!)

// Special matrix properties
// Requires domains like DiagonalMatrix, OrthogonalMatrix(O(n)), SL(n) etc.
M : O(n) → canonical_orthogonal_form(M) if Mᵀ * M = I
M : SL(n) → canonical_SL_form(M) if det(M) = 1
```

Applied example: optimizing `((A*B)ᵀ * (C+D))`
1. Apply transpose of product rule: `(Bᵀ * Aᵀ) * (C+D)`
2. Apply distributivity (from Ring): `(Bᵀ * Aᵀ) * C + (Bᵀ * Aᵀ) * D`
3. (Optional) If matrix multiplication is associative (it is): `Bᵀ * (Aᵀ * C) + Bᵀ * (Aᵀ * D)`

### 8.3 Logic Formula Canonicalisation

Boolean logic forms a Boolean Algebra (a specific type of Ring and Distributive Lattice).

```orbit
// Boolean ⊂ DistributiveLattice
// Boolean ⊂ Ring // (Using XOR for +, AND for *)

// Inherited Lattice/Ring Rules:
p ∨ q : Boolean ↔ q ∨ p : Boolean : S₂ // OR commutativity
p ∧ q : Boolean ↔ q ∧ p : Boolean : S₂ // AND commutativity
(p ∨ q) ∨ r : Boolean ↔ p ∨ (q ∨ r) : Boolean // OR associativity (n-ary)
(p ∧ q) ∧ r : Boolean ↔ p ∧ (q ∧ r) : Boolean // AND associativity (n-ary)
p ∨ (q ∧ r) : Boolean ↔ (p ∨ q) ∧ (p ∨ r) : Boolean // Distributivity
p ∧ (q ∨ r) : Boolean ↔ (p ∧ q) ∨ (p ∧ r) : Boolean // Distributivity
p ∨ false ↔ p : Boolean // OR identity
p ∧ true ↔ p : Boolean // AND identity
p ∨ true ↔ true : Boolean // OR annihilation
p ∧ false ↔ false : Boolean // AND annihilation
p ∨ p ↔ p : Boolean // Idempotence
p ∧ p ↔ p : Boolean // Idempotence

// Boolean-Specific Rules (Negation):
¬¬p ↔ p : Boolean // Double Negation
¬(p ∨ q) ↔ ¬p ∧ ¬q : Boolean // De Morgan's
¬(p ∧ q) ↔ ¬p ∨ ¬q : Boolean // De Morgan's
p ∨ ¬p ↔ true : Boolean // Excluded Middle
p ∧ ¬p ↔ false : Boolean // Contradiction

// Canonical Forms (e.g., NNF, DNF, CNF, BDD)
// Rules to convert to specific forms, often using negative guards.
// Example DNF Rule (pushes AND inwards):
p ∧ (q ∨ r) : Boolean !: DNF_Expanded → (p ∧ q) ∨ (p ∧ r) : Boolean : DNF_Expanded

// Example BDD Rule (Shannon Expansion):
f : Boolean → ite(v, substitute(f, v, true), substitute(f, v, false)) : BDD if v = choose_variable(f)
```

#### Binary Decision Diagrams (BDDs) and Cross-Representation Synergy

BDDs offer a canonical form for Boolean functions based on a fixed variable ordering. Orbit can manage multiple representations (e.g., standard logic, CNF, BDD) within the same e-class.

```orbit
// BDD specific reduction rules:
ite(v, t, t) → t : BDD                             // Redundant test
ite(v, true, false) → v : BDD                       // Direct variable
ite(v, false, true) → ¬v : BDD                      // Negated variable
ite(v, t, f) : BDD → ite(v, f, t) : BDD if compare_nodes(f,t) < 0 // Ensure unique child order for non-terminal nodes

// Cross-representation:
expr : Boolean → to_bdd(expr) : BDD // Convert to BDD representation
expr : BDD → to_cnf(expr) : CNF     // Convert BDD to CNF
```
This allows leveraging the best representation for a given task (e.g., BDDs for satisfiability counting, CNF for SAT solving) by rewriting between forms within the O-Graph.

### 8.4 List Processing Operations

Functional list operations have algebraic properties often related to Monoids or Functors.

```orbit
// Functor Laws (map):
map(id, xs) → xs
map(f, map(g, xs)) → map(λx.(f(g(x))), xs) // Map fusion (Associativity of composition)

// Monoid Laws (append/concat ++):
xs ++ [] → xs
[] ++ xs → xs
(xs ++ ys) ++ zs → xs ++ (ys ++ zs) // Associativity handled by n-ary form

// Other common list rules:
filter(p, filter(q, xs)) → filter(λx.(p(x) ∧ q(x)), xs) // Filter fusion
fold(op, init, map(f, xs)) → fold(λacc x.(op(acc, f(x))), init, xs) // Fold-map fusion
reverse(reverse(xs)) → xs
length(xs ++ ys) → length(xs) + length(ys)
```

### 8.5 Type Inference Integration

While Orbit primarily focuses on term rewriting, its domain system can represent types. Type inference and checking can interact with the rewriting process.

```orbit
// Type inference rules
let type_rules = (
	// Type variable introduction
	expr !: Typed → expr : α : Typed;

	// Function application typing
	apply(f : α → β, x : α) → apply(f, x) : β : Typed;

	// Type unification (via group-theoretic canonicalisation)
	unify(t, t) → t;
	unify(α, t) → subst(α, t) if !occurs_in(α, t);
	unify(t, α) → subst(α, t) if !occurs_in(α, t);

	// Complex type constructors (with S₂ symmetry for product types)
	pair(a : α, b : β) → pair(a, b) : α × β : Typed;
	tuple(elems...) : S₂ → sorted_tuple(elems...); // For records with symmetry
);
```

The key insight is that we can treat type variables and concrete types as members of the same e-graph, with unification being a process of finding a canonical form under substitution. This approach handles polymorphism naturally:

```orbit
// Type inference example
let id = λx.x;               // Identity function
let f = λx.(x + 1);            // Int -> Int function
let pair = (id, f);            // Polymorphic pair

// Application inference
apply(id, 5) : Int;            // Infer id : Int → Int in this context
apply(id, "hello") : String;    // Infer id : String → String in this context

// Type inference recognizes that pair has type: (α → α, Int → Int)
```

Types that exhibit symmetry properties can be canonicalized using the same group-theoretic machinery. For example, record types in structural typing systems often have field ordering symmetry that can be handled by S₂ canonicalization:

```orbit
// Record type canonicalization
typeof({x: Int, y: String}) = typeof({y: String, x: Int})  // By S₂ canonicalization
```

This integration enables more flexible and powerful type systems while maintaining sound semantics, and demonstrates how the Orbit framework provides a unifying approach across seemingly disparate domains like term rewriting and type checking.

### 8.6 Numerical Approximation and Discretization

Rewriting can represent transformations between continuous (Calculus) and discrete (Numerical) domains.

```orbit
// Define domains: Calculus, Numerical
Calculus ⊂ Field // Calculus operates on Reals/Complex (Fields)

// Rules crossing domains:
diff(f, x) : Calculus → (f(x+h) - f(x))/h : Numerical : FiniteDifference if is_small(h) // Forward difference
integrate(f, x, a, b) : Calculus → summation(λi.(f(a + i*h)*h), i, 0, n-1) : Numerical : RiemannSum where h = (b-a)/n // Riemann sum
```

## 9. Evaluation

<draft>
Later: We plan to evaluate Orbit by implementing a representative set of rules from diverse domains (algebra, bitvectors, calculus, logic) and measuring:
1.  **O-Graph Size**: Compare the number of e-classes and e-nodes required with and without group-theoretic canonicalisation and domain hierarchies. We expect significant reductions due to collapsing equivalent forms.
2.  **Rewrite Rule Application Count**: Measure the total number of rule applications needed to reach saturation. Canonicalisation should reduce redundant matches.
3.  **Query Time**: Evaluate the time taken for equivalence checks (`find`) between terms. Smaller, canonicalized e-graphs should yield faster queries.
4.  **Case Studies**: Apply Orbit to specific optimization problems (e.g., simplifying floating-point expressions, optimizing bitvector logic) and compare the results against standard techniques or domain-specific tools.
This work is in progress.
</draft>

## 10. Deriving the FFT

TODO: Explain how we derive the FFT from the DFT.

## 11. Conclusion

This paper has presented Orbit, a framework extending e-graphs with domain annotations and group-theoretic canonicalisation. By formalizing the relationship between symmetry groups, domain hierarchies, and canonical representations, we provide a unified approach to rewriting that spans diverse computational areas. Orbit achieves significant representational compression and accelerates equality saturation by leveraging algebraic structure and symmetry directly on flattened representations.

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
