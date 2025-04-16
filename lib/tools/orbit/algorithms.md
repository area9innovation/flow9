# Canonicalization Algorithms and Approaches

## Introduction to Canonical Forms

A canonical form is a unique representation of an object within an equivalence class. In other words, it's a standardized way to represent objects that should be considered "the same" under some defined equivalence relation. Finding canonical forms is crucial for:

1. **Equality testing**: Two objects are equivalent if and only if their canonical forms are identical
2. **Deduplication**: Storing only canonical representatives reduces redundancy
3. **Optimization**: Enabling pattern matching and rule application across equivalent expressions
4. **Simplification**: Presenting expressions in their most comprehensible form

This document outlines the algorithms and approaches for finding canonical forms across various data structures using group theory as a unifying framework.

## Group Theory and Canonicalization

### Core Concepts

- **Group**: A set G with an operation • that satisfies closure, associativity, identity, and inverse properties
- **Group Action**: A function that maps a group element g ∈ G and a set element x to another set element g•x
- **Orbit**: The set of all elements reachable from x by applying group actions: Orb(x) = {g•x | g ∈ G}
- **Canonical Form**: The representative chosen from the orbit according to some ordering criterion

**Canonical Form Selection Principle**: From the orbit of equivalent elements, we consistently select one representative (typically the lexicographically smallest) to serve as the canonical form.

## Canonicalization by Data Structure

### Symmetric Groups (Sₙ)

For symmetric groups, which represent all possible permutations of n elements, the canonical form is the stable sorted version.

**Algorithm**:
1. Sort elements according to a consistent ordering criterion
2. For compound structures, recursively canonicalize elements before sorting

```
function canonicalize_symmetric(elements, comparator):
	return sort(elements, comparator)
```

**Example**:
```
// Original: [5, 3, 8, 1]
// Canonical: [1, 3, 5, 8]

// For nested structures, canonicalize recursively:
// Original: [[3, 1], [2, 1]]
// Canonical: [[1, 3], [1, 2]]
```

### Cyclic Groups (Cₙ)

For cyclic groups, which represent rotational symmetry, we need to find the lexicographically minimal rotation. Booth's algorithm efficiently solves this problem in O(n) time.

**Booth's Algorithm for Minimum Rotation**:

```python
def least_rotation(s: str) -> int:
	"""Booth's lexicographically minimal string rotation algorithm."""
	n = len(s)
	f = [-1] * (2 * n)
	k = 0
	for j in range(1, 2 * n):
		i = f[j - k - 1]
		while i != -1 and s[j % n] != s[(k + i + 1) % n]:
			if s[j % n] < s[(k + i + 1) % n]:
				k = j - i - 1
			i = f[i]
		if i == -1 and s[j % n] != s[(k + i + 1) % n]:
			if s[j % n] < s[(k + i + 1) % n]:
				k = j
			f[j - k] = -1
		else:
			f[j - k] = i + 1
	return k
```

A simpler but less efficient O(n²) algorithm for finding the minimum rotation:

```
function min_rotation(array):
	n = length(array)
	min_array = array
	for i from 1 to n-1:
		rotation = array[i:] + array[:i]
		if rotation < min_array:  # lexicographic comparison
			min_array = rotation
	return min_array
```

**Example**:
```
// Original: [b, a, d, a]
// Rotations: [b,a,d,a], [a,d,a,b], [d,a,b,a], [a,b,a,d]
// Canonical (lexicographically minimal): [a,b,a,d]
```

### Dihedral Groups (Dₙ)

Dihedral groups represent rotations and reflections. The canonical form requires checking all rotations and the reflection of each rotation to find the lexicographically minimal form.

**Algorithm**:
```
function canonicalize_dihedral(array):
	n = length(array)
	min_array = array

	// Check all rotations
	for i from 1 to n-1:
		rotation = array[i:] + array[:i]
		if rotation < min_array:
			min_array = rotation

	// Check all rotations of the reflection
	reflected = reverse(array)
	for i from 0 to n-1:
		rotation = reflected[i:] + reflected[:i]
		if rotation < min_array:
			min_array = rotation

	return min_array
```

**Example**:
```
// Original: [3, 1, 4, 2]
// Rotations: [3,1,4,2], [1,4,2,3], [4,2,3,1], [2,3,1,4]
// Reflections: [2,4,1,3], [3,1,4,2], [1,4,2,3], [4,2,3,1]
// Canonical: [1,4,2,3]
```

### Bags and Multisets

A bag (multiset) allows multiple occurrences of elements. The canonical form of a bag is simply a sorted array.

**Algorithm**:
```
function canonicalize_bag(bag):
	return sort(bag)
```

**Example**:
```
// Original bag: [3, 1, 3, 2, 1]
// Canonical form: [1, 1, 2, 3, 3]
```

### Sets

A set has no duplicates and no defined order. The canonical form of a set is a sorted array with duplicates removed.

**Algorithm**:
```
function canonicalize_set(set):
	return sort(remove_duplicates(set))
```

**Example**:
```
// Original set: {3, 1, 3, 2, 1}
// After removing duplicates: {1, 2, 3}
// Canonical form: [1, 2, 3]
```

### Binary Trees

For binary trees, we can use a recursive approach to canonicalize:

**Algorithm**:
```
function canonicalize_binary_tree(node):
	if node is null:
		return null

	// Recursively canonicalize left and right subtrees
	left = canonicalize_binary_tree(node.left)
	right = canonicalize_binary_tree(node.right)

	// Make smaller subtree the left child
	if compare(right, left) < 0:
		return new Node(node.value, right, left)
	else:
		return new Node(node.value, left, right)
```

**Example**:
```
// Original tree:    5
//                  / \
//                 3   7
//                / \
//               1   4

// Canonicalized:   5
//                 / \
//                3   7
//               / \
//              1   4
// (Already canonical in this case, since left subtrees are "smaller" than right)
```

### Tries

A trie (prefix tree) can be canonicalized by ensuring children at each node are ordered:

**Algorithm**:
```
function canonicalize_trie(node):
	if node is leaf:
		return node

	// Canonicalize all children
	for each child in node.children:
		child = canonicalize_trie(child)

	// Sort children by their edge labels
	node.children = sort(node.children, by=edge_label)

	return node
```

### Undirected Graphs

Canonicalizing undirected graphs is a complex problem equivalent to the graph isomorphism problem. The nauty algorithm is commonly used:

**High-level Algorithm**:
1. Compute vertex invariants (degree, neighbor properties)
2. Partition vertices based on invariants
3. Refine partitions iteratively
4. Generate canonical labeling through backtracking search

```
function canonicalize_undirected_graph(graph):
	// Using nauty or similar algorithm
	return compute_canonical_form(graph)
```

**Example**:
```
// Original graph: A--B--C--D (path graph)
//                      |
//                      E

// Canonical representation often uses adjacency matrix with
// optimal vertex ordering for uniqueness:
// 0 1 0 0 0
// 1 0 1 0 1
// 0 1 0 1 0
// 0 0 1 0 0
// 0 1 0 0 0
```

### Directed Graphs

Directed graphs require considering edge directions during canonicalization:

**Algorithm**:
1. Compute vertex invariants including in-degree and out-degree
2. Perform similar partitioning and refinement as with undirected graphs
3. Consider edge directions when comparing vertex neighborhoods

```
function canonicalize_directed_graph(graph):
	// Similar to undirected graphs but with direction considered
	return compute_canonical_directed_form(graph)
```

### Polynomials

For polynomials, we need to establish a consistent term ordering:

#### Monomial Orders

1. **Lexicographic (lex)**: Compare by first differing exponent
2. **Graded Lexicographic (grlex)**: First compare total degree, then lex
3. **Graded Reverse Lexicographic (grevlex)**: First total degree, then reverse lex on last differing exponent

**Algorithm**:
```
function canonicalize_polynomial(poly, order_type):
	// Combine like terms
	terms = combine_like_terms(poly)

	// Sort terms according to selected monomial order
	sorted_terms = sort(terms, by=order_type)

	return sorted_terms
```

**Example**:
```
// Original: 2x^2y + yz^2 + 3x^2y + x^4
// Combined: 5x^2y + yz^2 + x^4

// Using grlex:
// Degrees: x^2y (3), yz^2 (3), x^4 (4)
// Canonical: 5x^2y + yz^2 + x^4
```

### Sets of Polynomials (Ideals)

For sets of polynomials, we need Buchberger's algorithm to compute a Gröbner basis:

**Buchberger's Algorithm**:
1. Start with ideal generators G = {g₁, ..., gₖ}
2. For each pair (gᵢ, gⱼ), compute their S-polynomial
3. Reduce S-polynomial with respect to G. If not zero, add to G
4. Repeat until all S-polynomial reductions are zero

```
function compute_groebner_basis(polynomials, order):
	G = polynomials
	pairs = all_pairs(G)

	while pairs is not empty:
		(f, g) = remove_pair(pairs)
		s = s_polynomial(f, g)
		r = reduce(s, G)

		if r != 0:
			pairs.extend([(r, g) for g in G])
			G.append(r)

	return G
```

**Example**:
```
// Original ideal generators: {x² - y, y² - x}
// Gröbner basis (with lex order x > y): {x² - y, xy - x, y² - x}
// Now polynomial division yields unique remainders
```

## Differential Calculus and Automatic Differentiation

Differential calculus deals with rates of change and slopes of curves. Automatic differentiation (AD) is a computational technique to efficiently calculate exact derivatives.

### Derivative Canonicalization

To canonicalize derivatives, we apply the standard rules of calculus in a consistent order:

```
function canonicalize_derivative(expr):
	// Apply chain rule for composite functions
	if expr is d/dx(f(g(x))):
		return canonicalize((d/df(f))(g(x)) * (d/dx(g(x))))

	// Apply product rule
	if expr is d/dx(f * g):
		return canonicalize(f * (d/dx(g)) + (d/dx(f)) * g)

	// Apply quotient rule
	if expr is d/dx(f / g):
		return canonicalize(((d/dx(f)) * g - f * (d/dx(g))) / (g^2))

	// Apply sum/difference rule
	if expr is d/dx(f + g):
		return canonicalize((d/dx(f)) + (d/dx(g)))
	if expr is d/dx(f - g):
		return canonicalize((d/dx(f)) - (d/dx(g)))

	// Apply power rule
	if expr is d/dx(x^n) where n is constant:
		return canonicalize(n * x^(n-1))

	// Apply standard function derivatives
	if expr is d/dx(sin(x)):
		return canonicalize(cos(x))
	if expr is d/dx(cos(x)):
		return canonicalize(-sin(x))
	if expr is d/dx(e^x):
		return canonicalize(e^x)
	if expr is d/dx(ln(x)):
		return canonicalize(1/x)

	// Handle higher-order derivatives recursively
	if expr is d²/dx²(f):
		return canonicalize(d/dx(d/dx(f)))

	return expr
```

### Automatic Differentiation Algorithms

Automatic differentiation comes in two main forms: forward mode and reverse mode.

#### Forward Mode AD

Forward mode AD tracks derivatives alongside values using dual numbers:

```
function forward_ad(f, x, ẋ):
	// Create dual number (value, derivative)
	dual_x = Dual(x, ẋ)

	// Evaluate function with dual arithmetic rules
	dual_result = f(dual_x)  // Using overloaded operators for duals

	// Extract and return value and derivative
	return dual_result.value, dual_result.derivative
```

**Example**:
```
// Consider f(x) = x² + sin(x)
// At x = 2 with ẋ = 1 (derivative with respect to x):

// Create dual number: dual_x = Dual(2, 1)
// Compute f(dual_x):
//   x² = Dual(2, 1)² = Dual(4, 4)  // Power rule: derivative of x² is 2x
//   sin(x) = Dual(sin(2), cos(2))  // Chain rule
//   f(x) = Dual(4, 4) + Dual(sin(2), cos(2)) = Dual(4+sin(2), 4+cos(2))

// Result: value = 4+sin(2), derivative = 4+cos(2)
```

#### Reverse Mode AD

Reverse mode AD is more efficient for functions with many inputs and few outputs:

```
function reverse_ad(f, x):
	// Forward pass: compute function and build computational graph
	y, tape = forward_with_recording(f, x)

	// Initialize adjoints (partial derivatives)
	adjoints = {y: 1.0}  // Initialize output adjoints

	// Backward pass: propagate adjoints backward through the graph
	for node in reverse(tape):
		// Get current node's adjoint
		node_adjoint = adjoints[node]

		// Distribute adjoint to input nodes based on local derivatives
		for input_node, local_gradient in node.inputs_with_gradients():
			if input_node in adjoints:
				adjoints[input_node] += node_adjoint * local_gradient
			else:
				adjoints[input_node] = node_adjoint * local_gradient

	// Return gradient with respect to inputs
	return [adjoints.get(input_var, 0.0) for input_var in x]
```

### Multivariate Differentiation

For multivariate functions, we need to handle partial derivatives:

```
function canonicalize_partial_derivative(expr):
	// For constants with respect to the variable
	if expr is ∂/∂xᵢ(c) and c is constant with respect to xᵢ:
		return 0

	// For variables
	if expr is ∂/∂xᵢ(xⱼ):
		return 1 if i == j else 0

	// Sum rule
	if expr is ∂/∂xᵢ(f + g):
		return canonicalize(∂/∂xᵢ(f) + ∂/∂xᵢ(g))

	// Product rule
	if expr is ∂/∂xᵢ(f * g):
		return canonicalize(f * ∂/∂xᵢ(g) + ∂/∂xᵢ(f) * g)

	// Mixed partial derivatives (equal for smooth functions)
	if expr is ∂²f/∂xᵢ∂xⱼ and is_smooth(f):
		return canonicalize(∂²f/∂xⱼ∂xᵢ)

	return expr
```

## Matrix and Linear Algebra Canonicalization

Matrices and linear algebraic structures require specialized canonicalization approaches that respect their mathematical properties.

### Basic Matrix Canonicalization

```
function canonicalize_matrix(matrix):
	// Handle special cases based on matrix properties
	if is_diagonal(matrix):
		return canonicalize_diagonal_matrix(matrix)

	if is_symmetric(matrix):
		return canonicalize_symmetric_matrix(matrix)

	if is_triangular(matrix):
		return canonicalize_triangular_matrix(matrix)

	// For general matrices, use row echelon form
	if need_canonical_representation:
		return row_echelon_form(matrix)

	return matrix
```

### Matrix Decomposition-Based Canonicalization

Matrix decompositions provide powerful tools for canonicalization:

```
function canonicalize_via_decomposition(matrix):
	// Singular Value Decomposition (SVD)
	if svd_is_appropriate(matrix):
		U, Σ, V_T = svd(matrix)
		// Ensure uniqueness of decomposition
		U, Σ, V_T = make_unique_svd(U, Σ, V_T)
		return (U, Σ, V_T)  // Canonical triplet representation

	// Eigendecomposition for diagonalizable matrices
	if is_diagonalizable(matrix):
		P, D = eigendecomposition(matrix)
		// Sort eigenvalues and corresponding eigenvectors
		P, D = sort_eigen(P, D)
		return (P, D)  // Canonical pair representation

	// QR decomposition
	if qr_is_appropriate(matrix):
		Q, R = qr_decomposition(matrix)
		// Ensure uniqueness (e.g., positive diagonal in R)
		Q, R = make_unique_qr(Q, R)
		return (Q, R)  // Canonical pair representation

	// LU decomposition
	if lu_is_appropriate(matrix):
		L, U = lu_decomposition(matrix)
		return (L, U)  // Canonical pair representation

	// Cholesky for positive definite matrices
	if is_positive_definite(matrix):
		L = cholesky_decomposition(matrix)  // Lower triangular
		return L  // Canonical representation

	return matrix
```

### Structured Matrix Canonicalization

```
function canonicalize_symmetric_matrix(matrix):
	// Ensure the matrix is exactly symmetric
	n = matrix.rows
	for i from 0 to n-1:
		for j from i+1 to n-1:
			matrix[i,j] = matrix[j,i] = (matrix[i,j] + matrix[j,i])/2

	return matrix

function canonicalize_triangular_matrix(matrix):
	// For upper triangular, zero out below diagonal
	if is_upper_triangular(matrix):
		for i from 1 to n-1:
			for j from 0 to i-1:
				matrix[i,j] = 0

	// For lower triangular, zero out above diagonal
	if is_lower_triangular(matrix):
		for i from 0 to n-2:
			for j from i+1 to n-1:
				matrix[i,j] = 0

	return matrix
```

### Matrix Multiplication Canonicalization

```
function canonicalize_matrix_multiplication(expr):
	// Associative property: (AB)C = A(BC)
	if expr is (A*B)*C:
		// Choose canonical grouping based on dimensions
		if A.cols*B.cols + A.cols*C.cols < A.cols*B.cols + B.cols*C.cols:
			return canonicalize(A*(B*C))
		else:
			return canonicalize((A*B)*C)

	// Identity elimination
	if expr is A*I:
		return canonicalize(A)
	if expr is I*A:
		return canonicalize(A)

	// Special case: diagonal matrix multiplication
	if is_diagonal(A) and is_diagonal(B):
		return canonicalize_diagonal_product(A, B)

	return expr
```

## Enhanced Polynomial Systems and Gröbner Basis

Polynomial systems and Gröbner bases provide a powerful framework for solving systems of polynomial equations and finding canonical forms in polynomial rings.

### Detailed Buchberger's Algorithm

```
function buchberger_algorithm(F):
	// Input: Set of polynomials F = {f₁, ..., fₘ}
	// Output: Gröbner basis G for the ideal generated by F

	G = F
	B = {{f, g} for each pair f,g in G}  // Pairs to process

	while B is not empty:
		select and remove a pair {f, g} from B

		// Compute S-polynomial
		s = s_polynomial(f, g)

		// Reduce S-polynomial with respect to G
		r = reduce(s, G)

		if r ≠ 0:
			// Add new pairs to B
			B = B ∪ {{r, h} for each h in G}

			// Add r to the basis
			G = G ∪ {r}

	// Minimize and reduce the basis (optional optimization)
	G = minimize_grobner_basis(G)
	G = reduce_grobner_basis(G)

	return G

function s_polynomial(f, g):
	// Compute the S-polynomial of f and g
	lt_f = leading_term(f)
	lt_g = leading_term(g)
	lcm_term = least_common_multiple(lt_f, lt_g)

	return (lcm_term/lt_f) * f - (lcm_term/lt_g) * g

function reduce(p, G):
	// Reduce polynomial p with respect to set G
	r = 0
	q = p

	while q ≠ 0:
		divisible = false

		for g in G:
			lt_g = leading_term(g)
			lt_q = leading_term(q)

			if lt_g divides lt_q:
				divisible = true
				q = q - (lt_q/lt_g) * g
				break

		if not divisible:
			r = r + leading_term(q)
			q = q - leading_term(q)

	return r
```

### Polynomial Reduction and Normal Forms

```
function normal_form(f, G):
	// Compute the normal form of f with respect to Gröbner basis G
	// This is a unique representative of f in the ideal generated by G

	return reduce(f, G)

function ideal_membership_test(f, G):
	// Test if polynomial f belongs to the ideal generated by G
	nf = normal_form(f, G)

	return nf == 0  // f is in the ideal if and only if its normal form is zero

function polynomial_canonicalization(f, I):
	// Canonicalize a polynomial f with respect to an ideal I
	// by reducing it modulo a Gröbner basis for I

	G = compute_grobner_basis(I)
	return normal_form(f, G)
```

### Monomial Ordering

```
function compare_monomials(m1, m2, order_type):
	// Compare two monomials based on the specified ordering
	if order_type is "lex":
		return lexicographic_comparison(m1, m2)

	if order_type is "grlex":
		// First compare total degree
		deg1 = total_degree(m1)
		deg2 = total_degree(m2)

		if deg1 != deg2:
			return deg1 - deg2

		// If same degree, use lexicographic comparison
		return lexicographic_comparison(m1, m2)

	if order_type is "grevlex":
		// First compare total degree
		deg1 = total_degree(m1)
		deg2 = total_degree(m2)

		if deg1 != deg2:
			return deg1 - deg2

		// If same degree, use reversed lexicographic comparison
		return reverse_lexicographic_comparison(m1, m2)
```

## Tensor Canonicalization

Tensors generalize vectors and matrices to higher dimensions and require specialized canonicalization techniques.

### Basic Tensor Canonicalization

```
function canonicalize_tensor(tensor):
	// Handle tensor symmetry properties
	if has_index_symmetry(tensor):
		tensor = apply_symmetry_constraints(tensor)

	// Rename free indices to canonical names
	tensor = rename_free_indices(tensor)

	// Rename dummy (repeated) indices canonically
	tensor = rename_dummy_indices(tensor)

	// Apply tensor contractions where possible
	tensor = apply_contractions(tensor)

	return tensor
```

### Index Canonicalization

```
function rename_free_indices(tensor):
	// Identify free indices (those appearing exactly once)
	free_indices = find_free_indices(tensor)

	// Sort free indices based on position and rename to canonical names
	sorted_indices = sort_by_position(free_indices)

	// Create mapping from original indices to canonical names
	mapping = {sorted_indices[i]: canonical_name(i) for i in range(len(sorted_indices))}

	// Apply renaming
	return rename_indices(tensor, mapping)

function rename_dummy_indices(tensor):
	// Identify pairs of dummy indices (those appearing exactly twice)
	dummy_pairs = find_dummy_pairs(tensor)

	// Sort pairs based on position and rename to canonical names
	sorted_pairs = sort_by_position(dummy_pairs)

	// Create mapping from original indices to canonical names
	mapping = {}
	for i, (idx1, idx2) in enumerate(sorted_pairs):
		dummy_name = canonical_dummy_name(i)
		mapping[idx1] = dummy_name
		mapping[idx2] = dummy_name

	// Apply renaming
	return rename_indices(tensor, mapping)
```

### Symmetry Application

```
function apply_symmetry_constraints(tensor):
	// Get tensor symmetry properties
	symmetries = get_tensor_symmetries(tensor)

	// Apply each symmetry type
	for symmetry in symmetries:
		if symmetry.type == "symmetric":
			tensor = symmetrize(tensor, symmetry.indices)

		if symmetry.type == "antisymmetric":
			tensor = antisymmetrize(tensor, symmetry.indices)

		if symmetry.type == "cyclic":
			tensor = cyclically_symmetrize(tensor, symmetry.indices)

	return tensor

function symmetrize(tensor, indices):
	// Average over all permutations of the specified indices
	result = zero_tensor_like(tensor)
	perms = all_permutations(indices)

	for perm in perms:
		result += permute_indices(tensor, indices, perm)

	return result / len(perms)

function antisymmetrize(tensor, indices):
	// Average over all permutations of the specified indices with sign
	result = zero_tensor_like(tensor)
	perms = all_permutations(indices)

	for perm in perms:
		sign = permutation_sign(perm)
		result += sign * permute_indices(tensor, indices, perm)

	return result / len(perms)
```

## Finite Automata and Regular Expressions

Finite automata and regular expressions are fundamental to computation theory and string processing. Canonicalization in this domain focuses on finding minimal representations.

### DFA Minimization

```
function minimize_dfa(dfa):
	// Step 1: Remove unreachable states
	reachable = find_reachable_states(dfa.start_state, dfa.transitions)
	dfa = restrict_to_states(dfa, reachable)

	// Step 2: Partition states by equivalence
	// Initial partition: accepting vs non-accepting states
	partition = [dfa.accepting_states, dfa.states - dfa.accepting_states]

	// Refine partition until it stabilizes
	changed = true
	while changed:
		changed = false
		new_partition = []

		for block in partition:
			// Try to split block based on transitions
			splits = {}

			for state in block:
				signature = []
				for symbol in dfa.alphabet:
					target = dfa.transitions[state][symbol]
					target_block = find_block_containing(target, partition)
					signature.append(target_block)

				signature_key = tuple(signature)
				if signature_key not in splits:
					splits[signature_key] = []
				splits[signature_key].append(state)

			// If block was split, update partition
			if len(splits) > 1:
				changed = true
				for split_states in splits.values():
					new_partition.append(split_states)
			else:
				new_partition.append(block)

		partition = new_partition

	// Step 3: Construct minimized DFA
	minimized_dfa = construct_dfa_from_partition(dfa, partition)
	return minimized_dfa
```

### Regular Expression Canonicalization

```
function canonicalize_regex(regex):
	// Convert to NFA
	nfa = regex_to_nfa(regex)

	// Convert NFA to DFA
	dfa = nfa_to_dfa(nfa)

	// Minimize DFA
	min_dfa = minimize_dfa(dfa)

	// Convert back to regex (if needed)
	canonical_regex = dfa_to_regex(min_dfa)

	return canonical_regex

function regex_algebraic_simplification(regex):
	// Apply algebraic laws to simplify regex
	// Idempotence
	if regex matches (r|r):
		return simplify(r)

	// Empty string laws
	if regex matches (rε):
		return simplify(r)

	// Empty set laws
	if regex matches (r|∅):
		return simplify(r)

	// Distributivity
	if regex matches (r(s|t)):
		return simplify(rs|rt)

	// Kleene star laws
	if regex matches ((r*)*):
		return simplify(r*)

	return regex
```

## Loop Transformations and Polyhedral Model

Loop transformations are critical for optimizing computation-intensive programs. The polyhedral model provides a mathematical framework for these transformations.

### Loop Transformations

```
function canonicalize_loop_nest(loop_nest):
	// Normalize loop bounds to start at 0 with step 1
	normalized = normalize_loops(loop_nest)

	// Apply canonical loop ordering based on data access patterns
	ordered = reorder_loops(normalized)

	return ordered

function normalize_loops(loop_nest):
	result = loop_nest

	for loop in loop_nest.loops:
		// Transform: for(i=a; i<b; i+=c) → for(i'=0; i'<(b-a)/c; i'+=1)
		normalized_loop = normalize_loop(loop)
		result = replace_loop(result, loop, normalized_loop)

	return result

function reorder_loops(loop_nest):
	// Analyze data dependencies
	deps = analyze_dependencies(loop_nest)

	// Determine legal loop ordering
	ordering = compute_legal_ordering(loop_nest.loops, deps)

	// Apply reordering
	return reorder_by(loop_nest, ordering)
```

### Loop Fusion and Tiling

```
function fuse_loops(loop1, loop2):
	// Check if loops can be legally fused
	if not can_legally_fuse(loop1, loop2):
		return [loop1, loop2]

	// Create fused loop
	fused = create_fused_loop(loop1, loop2)

	return [fused]

function tile_loop(loop, tile_size):
	// Transform single loop into nested tile+intra-tile loops
	// for(i=0; i<N; i++) → for(ii=0; ii<N; ii+=T) for(i=ii; i<min(ii+T,N); i++)

	outer_loop = create_tile_loop(loop, tile_size)
	inner_loop = create_intra_tile_loop(loop, tile_size)

	// Replace inner loop body with original loop body
	inner_loop.body = loop.body

	// Set inner loop as body of outer loop
	outer_loop.body = inner_loop

	return outer_loop
```

### Polyhedral Model

```
function polyhedral_canonicalization(loop_nest):
	// Extract polyhedral representation
	domain = extract_iteration_domain(loop_nest)
	schedule = extract_schedule(loop_nest)
	accesses = extract_access_functions(loop_nest)

	// Optimize schedule while preserving semantics
	optimized_schedule = optimize_schedule(domain, schedule, accesses)

	// Generate loop nest from optimized schedule
	optimized_loops = generate_loops(domain, optimized_schedule, accesses)

	return optimized_loops

function optimize_schedule(domain, schedule, accesses):
	// Find schedule that minimizes cost function (e.g., data locality)
	dependencies = compute_dependencies(domain, accesses)

	// Create schedule optimization problem
	problem = create_scheduling_problem(domain, dependencies)

	// Solve for optimal schedule coefficients
	solution = solve_scheduling_problem(problem)

	// Construct new schedule from solution
	new_schedule = construct_schedule(solution)

	return new_schedule
```

## Interval Arithmetic

Interval arithmetic operates on intervals rather than precise values, providing bounded guarantees for numerical computations.

### Interval Operations

```
function canonicalize_interval(interval):
	// Handle degenerate cases
	if interval.lower > interval.upper:
		return empty_interval()  // Empty interval

	if interval.lower == interval.upper:
		return point_interval(interval.lower)  // Point interval

	// Canonical form: [a, b] where a ≤ b
	return Interval(interval.lower, interval.upper)

function interval_add(a, b):
	// [a_lo, a_hi] + [b_lo, b_hi] = [a_lo + b_lo, a_hi + b_hi]
	return Interval(a.lower + b.lower, a.upper + b.upper)

function interval_subtract(a, b):
	// [a_lo, a_hi] - [b_lo, b_hi] = [a_lo - b_hi, a_hi - b_lo]
	return Interval(a.lower - b.upper, a.upper - b.lower)

function interval_multiply(a, b):
	// [a_lo, a_hi] * [b_lo, b_hi] = [min(products), max(products)]
	products = [
		a.lower * b.lower,
		a.lower * b.upper,
		a.upper * b.lower,
		a.upper * b.upper
	]

	return Interval(min(products), max(products))

function interval_divide(a, b):
	// Division by an interval containing zero
	if b.lower <= 0 and b.upper >= 0:
		throw Error("Division by interval containing zero")

	// [a_lo, a_hi] / [b_lo, b_hi] = [a_lo, a_hi] * [1/b_hi, 1/b_lo]
	return interval_multiply(a, Interval(1.0/b.upper, 1.0/b.lower))
```

### Interval Set Operations

```
function interval_intersection(a, b):
	// [a_lo, a_hi] ∩ [b_lo, b_hi] = [max(a_lo, b_lo), min(a_hi, b_hi)]
	lower = max(a.lower, b.lower)
	upper = min(a.upper, b.upper)

	if lower <= upper:
		return Interval(lower, upper)
	else:
		return empty_interval()  // Empty intersection

function interval_hull(a, b):
	// Hull (smallest interval containing both a and b)
	// [a_lo, a_hi] ∪ [b_lo, b_hi] = [min(a_lo, b_lo), max(a_hi, b_hi)]
	return Interval(min(a.lower, b.lower), max(a.upper, b.upper))
```

## Effect System Canonicalization

Effect systems track computational effects like state mutation, I/O, and exceptions. Canonicalization in effect systems organizes code to make effects explicit and well-structured.

### Effect Analysis and Canonicalization

```
function infer_effects(expr):
	// Recursively infer effects in expressions
	if expr is literal or constant:
		return Pure  // No effects

	if expr is variable_reference:
		return Pure  // Reading a variable has no effect

	if expr is assignment(var, value):
		value_effect = infer_effects(value)
		return combine_effects(value_effect, State)  // Assignment affects state

	if expr is function_call(f, args):
		arg_effects = [infer_effects(arg) for arg in args]
		function_effect = get_function_effect(f)
		return combine_all_effects([function_effect] + arg_effects)

	if expr is if_statement(cond, then_branch, else_branch):
		cond_effect = infer_effects(cond)
		then_effect = infer_effects(then_branch)
		else_effect = infer_effects(else_branch)
		return combine_all_effects([cond_effect, then_effect, else_effect])

	if expr is sequence(expr1, expr2):
		effect1 = infer_effects(expr1)
		effect2 = infer_effects(expr2)
		return combine_effects(effect1, effect2)

	return Unknown  // Default case
```

### Effect-Based Code Transformation

```
function canonicalize_with_effects(expr):
	// Analyze effects
	effects = infer_effects(expr)

	// Separate pure from effectful code
	pure_parts, effectful_parts = separate_by_effects(expr, effects)

	// Hoist pure computations
	result = hoist_pure_computations(pure_parts, effectful_parts)

	// Ensure consistent ordering of effects
	result = order_effects(result)

	return result

function separate_by_effects(expr, effects):
	// Separate expression into pure and effectful parts
	if effects == Pure:
		return expr, None

	if expr is sequence(expr1, expr2):
		pure1, effectful1 = separate_by_effects(expr1, infer_effects(expr1))
		pure2, effectful2 = separate_by_effects(expr2, infer_effects(expr2))

		pure = combine_pure(pure1, pure2)
		effectful = combine_effectful(effectful1, effectful2)

		return pure, effectful

	// Default case: consider the whole expression effectful if it has effects
	return None, expr
```

### Effect Commutativity

```
function order_effects(expr):
	// Order effects based on commutativity properties
	if expr is sequence(expr1, expr2):
		effect1 = infer_effects(expr1)
		effect2 = infer_effects(expr2)

		if are_commutative(effect1, effect2):
			// Use canonical ordering for commutative effects
			if should_swap(expr1, expr2):
				return sequence(expr2, expr1)

		// Recursively order subexpressions
		return sequence(order_effects(expr1), order_effects(expr2))

	return expr

function are_commutative(effect1, effect2):
	// Check if two effects commute (can be reordered)
	if effect1 == Pure or effect2 == Pure:
		return true  // Pure effects commute with anything

	if effect1 == ReadOnly and effect2 == ReadOnly:
		return true  // Multiple reads commute

	// Specific effect commutativity rules
	if effect1 == Print and effect2 == Print:
		return false  // Print effects don't commute (order matters)

	return false  // Default: assume effects don't commute
```

## General Approach for Any Data Structure

For any data structure with a defined group action, the general approach is:

1. **Identify the symmetry group** (Sₙ, Cₙ, Dₙ, etc.)
2. **Define the group action** on your data structure
3. **Generate the orbit** or use a specialized algorithm
4. **Select the canonical representative** (usually the lexicographically smallest)

```
function find_canonical_form(object, group, action):
	if has_specialized_algorithm(group):
		return apply_specialized_algorithm(object, group)

	// General case - generate orbit and find minimum
	canonical = object
	for each g in group:
		transformed = action(g, object)
		if transformed < canonical:  // Using consistent comparison
			canonical = transformed

	return canonical
```

## Implementation in Orbit System

In the Orbit system, canonicalization is integrated through:

1. **Data Structure Registration**:
   Each major structure registers its symmetry group(s) and canonicalization action:
   ```
	 register_structure(array, symmetric_group, sort_array)
	 register_structure(cyclic_array, cyclic_group, min_rotation)
```

2. **Canonicalization Algorithms**:
   - For Sₙ: Sort elements
   - For Cₙ: Use Booth's algorithm
   - For Dₙ: Try all rotations and reflections
   - For polynomials: Sort monomials, apply monomial order
   - For graphs: Use nauty or custom algorithms

3. **General Framework**:
   For structures without specialized algorithms:
   - Enumerate the orbit by applying all group elements
   - Store or hash each transformed result
   - Select the canonical representative (e.g., minimal by lex)

4. **Action Library**:
   Orbit provides implementations for common group actions:
   - Permutation (Sₙ)
   - Rotation (Cₙ)
   - Reflection (Dₙ)
   - Matrix conjugation (GL(n))

5. **E-Graph Integration**:
   After canonicalization, congruent elements are merged into the same e-class

6. **Extensibility**:
   Users can register custom structures and group actions for domain-specific objects

## Table: Canonicalization Across Data Structures via Group Actions

| Data Structure / Object | Symmetry (Group) | Fast Canonicalization Algorithm | Group (Notation) | Example Actions | Typical Orbit Size |
|-------------------------|------------------|--------------------------------|-----------------|----------------|-------------------|
| Array (fully symmetric) | Permutations | Sort array by comparator | Symmetric (Sₙ) | All n! permutations | n! (if all elements unique) |
| Array (cyclic) | Rotational symmetry | Booth's algorithm (min rotation) | Cyclic (Cₙ) | n rotations | n |
| Array (dihedral) | Rotations + reflection | Min over all rotations & reversals | Dihedral (Dₙ) | n rotations, n reversals | 2n |
| Array (antisymmetric/Aₙ) | Even permutations, sign | Sort, count swaps for sign | Alternating (Aₙ) | All even permutations | n!/2 |
| Bag/Multiset | Permutations | Sort | Symmetric (Sₙ) | All permutations | n! |
| Set | Permutations | Sort (after deduplication) | Symmetric (Sₙ) | All permutations | n! |
| Binary Tree | Left-right swaps | Recursive canonicalization | (ℤ₂)ⁿ | Subtree swaps | 2^(number of nodes) |
| Trie | Child ordering | Sort children at each node | Prod. of Sₙᵢ | Reorder children | Product of factorials |
| Polynomial (vars x₁...xₖ) | Variable swaps | Sort monomials by chosen order | Sₖ or subgroup | Permute variable indices | ≤ n! × m |
| Polynomial mod ideal | Leading term division | Gröbner basis (Buchberger) | Structure via ideal | Polynomial reductions | Variable |
| Undirected Graph | Node relabelings | Canonical labeling (nauty) | Sₙ (node perms) | All node permutations | ≤ n! |
| Directed Graph | Node relabelings | Canonical labeling with direction | Sₙ (node perms) | All node permutations | ≤ n! |
| String (cyclic symmetry) | Smallest rotation | Booth's algorithm | Cₙ | Rotate string | n |
| Matrix (basis change) | GL(n) | Min (conjugation, Smith form) | GL(n) | Conjugation, similarity | Potentially infinite |
| Tensor (index symmetry) | Perm/antisymmetric | Min via index permutation | Sₙ, Aₙ, Dₙ, Cₙ | Permute/rotate indices | Various |
| Coloring of objects | Permute colors/labels | Min coloring under perms | Sₖ (color #(k)) | Permute color labels | k! |
| Bit patterns (cyclic/dih) | Rotation/reflection | Rotate/reflect, min | Cₙ, Dₙ | Rotate/reflection | n, 2n |
| Differential expressions | Structural | Apply calculus rules | Various | Term rewrites | Varies by expression |
| Linear algebra | Matrix groups | Echelon forms, decompositions | GL, O, etc. | Basis changes | Potentially infinite |
| Finite automata | State relabelings | DFA minimization | Sₙ | State permutations | ≤ n! |
| Program loops | Loop transformations | Polyhedral methods | Matrix groups | Loop reordering | Varies by nest |
| Intervals | Order constraints | Canonical bounds | Point-wise | min/max operations | 1 |
| Effect systems | Effect dependencies | Order commutative effects | DAG | Reordering | Depends on effects |

## Conclusion

Canonicalization through group actions provides a powerful unifying framework for working with equivalence classes of diverse data structures. By identifying the appropriate symmetry group and defining its action on a data structure, we can derive canonical representatives that enable efficient equality testing, pattern matching, and normalization.

The approaches outlined in this document demonstrate how abstract group theory translates into practical algorithms for finding canonical forms across a wide range of data structures, from simple arrays to complex mathematical objects like polynomials, tensors, matrices, and automata.

In the Orbit system, these canonicalization strategies play a crucial role in the rewriting and optimization process, allowing the system to recognize equivalent expressions and apply transformations effectively across diverse mathematical and computational domains.