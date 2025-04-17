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

```orbit
fn canonicalize_symmetric(elements, comparator) (
	sort(elements, comparator)
)
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

```orbit
// Booth's lexicographically minimal string rotation algorithm
fn least_rotation(s) (
	let n = length(s);
	let initial_f = map(range(0, 2 * n), \__.(-1));

	// Process all positions through recursion
	fn process_j(j, k, f) (
		if j >= 2 * n then k
		else (
			let initial_i = f[j - k - 1];

			// Process inner while loop recursively
			fn process_i(i, curr_k) (
				if i == -1 || s[j % n] == s[(curr_k + i + 1) % n] then
					Pair(i, curr_k)
				else (
					let new_k = if s[j % n] < s[(curr_k + i + 1) % n] then
						j - i - 1
					else
						curr_k;
					process_i(f[i], new_k)
				)
			);

			let result = process_i(initial_i, k);
			let i = result.first;
			let new_k = result.second;

			// Update f and continue loop
			let new_f = if i == -1 && s[j % n] != s[(new_k + i + 1) % n] then (
				let final_k = if s[j % n] < s[(new_k + i + 1) % n] then j else new_k;
				// Create new array with updated value at j-final_k
				update_array(f, j - final_k, -1)
			) else (
				// Create new array with updated value at j-new_k
				update_array(f, j - new_k, i + 1)
			);

			process_j(j + 1, new_k, new_f)
		)
	);

	// Start the recursive process
	process_j(1, 0, initial_f)
)
```

A simpler but less efficient O(n²) algorithm for finding the minimum rotation:

```orbit
fn min_rotation(array) (
	let n = length(array);

	// Find minimum rotation recursively
	fn find_min(i, min_so_far) (
		if i >= n then min_so_far
		else (
			let rotation = concat(subarray(array, i, n - i), subarray(array, 0, i));
			let new_min = if is_less(rotation, min_so_far) then rotation else min_so_far;
			find_min(i + 1, new_min)
		)
	);

	// Start with the original array as minimum
	find_min(1, array)
)
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
```orbit
fn canonicalize_dihedral(array) (
	let n = length(array);

	// Helper function to find minimum rotation
	fn check_rotations(i, curr_array, curr_min) (
		if i >= n then curr_min
		else (
			let rotation = concat(subarray(curr_array, i, n - i), subarray(curr_array, 0, i));
			let new_min = if is_less(rotation, curr_min) then rotation else curr_min;
			check_rotations(i + 1, curr_array, new_min)
		)
	);

	// First check all rotations of original array
	let min_after_rotations = check_rotations(1, array, array);

	// Then check all rotations of the reflected array
	let reflected = reverse(array);
	check_rotations(0, reflected, min_after_rotations)
)
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
```orbit
fn canonicalize_bag(bag) (
	sort(bag)
)
```

**Example**:
```
// Original bag: [3, 1, 3, 2, 1]
// Canonical form: [1, 1, 2, 3, 3]
```

### Sets

A set has no duplicates and no defined order. The canonical form of a set is a sorted array with duplicates removed.

**Algorithm**:
```orbit
fn canonicalize_set(set) (
	sort(remove_duplicates(set))
)
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
```orbit
fn canonicalize_binary_tree(node) (
	node is (
		Nil() => Nil();
		Node(value, left, right) => (
			// Recursively canonicalize left and right subtrees
			let canon_left = canonicalize_binary_tree(left);
			let canon_right = canonicalize_binary_tree(right);

			// Make smaller subtree the left child
			if compare(canon_right, canon_left) < 0 then
				Node(value, canon_right, canon_left)
			else
				Node(value, canon_left, canon_right)
		)
	)
)
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
```orbit
fn canonicalize_trie(node) (
	node is (
		Leaf() => node;
		TrieNode(children) => (
			// Canonicalize all children recursively
			let canonicalized_children = map(children, \child.canonicalize_trie(child));

			// Sort children by their edge labels
			let sorted_children = sort(canonicalized_children, \a, b.compare_edge_labels(a, b));

			// Return new node with sorted children
			TrieNode(sorted_children)
		)
	)
)
```

### Undirected Graphs

Canonicalizing undirected graphs is a complex problem equivalent to the graph isomorphism problem. The nauty algorithm is commonly used:

**High-level Algorithm**:
1. Compute vertex invariants (degree, neighbor properties)
2. Partition vertices based on invariants
3. Refine partitions iteratively
4. Generate canonical labeling through backtracking search

```orbit
fn canonicalize_undirected_graph(graph) (
	// Using nauty or similar algorithm
	compute_canonical_form(graph)
)
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

```orbit
fn canonicalize_directed_graph(graph) (
	// Similar to undirected graphs but with direction considered
	compute_canonical_directed_form(graph)
)
```

### Polynomials

For polynomials, we need to establish a consistent term ordering:

#### Monomial Orders

1. **Lexicographic (lex)**: Compare by first differing exponent
2. **Graded Lexicographic (grlex)**: First compare total degree, then lex
3. **Graded Reverse Lexicographic (grevlex)**: First total degree, then reverse lex on last differing exponent

**Algorithm**:
```orbit
fn canonicalize_polynomial(poly, order_type) (
	// Combine like terms
	let terms = combine_like_terms(poly);

	// Sort terms according to selected monomial order
	let sorted_terms = sort(terms, \t1, t2.compare_monomials(t1, t2, order_type));

	sorted_terms
)
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

```orbit
fn compute_groebner_basis(polynomials, order) (
	// Process pairs recursively until fixed point
	fn process_pairs(G, pairs) (
		if is_empty(pairs) then G
		else (
			let pair = head(pairs);
			let remaining_pairs = tail(pairs);

			let f = pair.first;
			let g = pair.second;

			let s = s_polynomial(f, g);
			let r = reduce(s, G);

			if r != 0 then (
				// Create new pairs with r and each element in G
				let new_pairs = append_all(remaining_pairs, map(G, \h.Pair(r, h)));

				// Add r to G
				let new_G = append(G, r);

				process_pairs(new_G, new_pairs)
			) else
				process_pairs(G, remaining_pairs)
		)
	);

	// Start with all pairs from initial polynomials
	let initial_pairs = all_pairs(polynomials);
	process_pairs(polynomials, initial_pairs)
)
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

```orbit
fn forward_ad(f, x, x_dot) (
	// Create dual number (value, derivative)
	let dual_x = Dual(x, x_dot);

	// Evaluate function with dual arithmetic rules
	let dual_result = f(dual_x);  // Using overloaded operators for duals

	// Return pair of value and derivative
	Pair(dual_result.value, dual_result.derivative)
)
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

```orbit
fn reverse_ad(f, x) (
	// Forward pass: compute function and build computational graph
	let result = forward_with_recording(f, x);
	let y = result.first;
	let tape = result.second;

	// Initialize adjoints (partial derivatives) with output having adjoint 1.0
	let initial_adjoints = singleton_tree(y, 1.0);

	// Helper function to process each node in the backward pass
	fn process_nodes(nodes, curr_idx, adjoints) (
		if curr_idx < 0 then adjoints
		else (
			let node = nodes[curr_idx];

			// Get current node's adjoint
			let node_adjoint = lookupDefault(adjoints, node, 0.0);

			// Process all inputs of this node
			let inputs_with_grads = node.inputs_with_gradients();

			// Helper to update adjoints for each input
			fn process_inputs(inputs, idx, curr_adjoints) (
				if idx >= length(inputs) then curr_adjoints
				else (
					let input_pair = inputs[idx];
					let input_node = input_pair.first;
					let local_gradient = input_pair.second;

					// Update adjoint for this input
					let new_adjoints = if hasKey(curr_adjoints, input_node) then
						setTree(curr_adjoints, input_node,
							lookupTree(curr_adjoints, input_node).value + node_adjoint * local_gradient)
					else
						setTree(curr_adjoints, input_node, node_adjoint * local_gradient);

					process_inputs(inputs, idx + 1, new_adjoints)
				)
			);

			let updated_adjoints = process_inputs(inputs_with_grads, 0, adjoints);
			process_nodes(nodes, curr_idx - 1, updated_adjoints)
		)
	);

	// Reverse the tape and process all nodes
	let reversed_tape = reverse(tape);
	let final_adjoints = process_nodes(reversed_tape, length(reversed_tape) - 1, initial_adjoints);

	// Extract gradients for input variables
	map(x, \var.lookupDefault(final_adjoints, var, 0.0))
)
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

```orbit
fn buchberger_algorithm(F) (
	// Input: Set of polynomials F = {f₁, ..., fₘ}
	// Output: Gröbner basis G for the ideal generated by F

	// Process all pairs recursively
	fn process_pairs(G, B) (
		if is_empty(B) then (
			// Minimize and reduce the basis (optional optimization)
			let minimized_G = minimize_grobner_basis(G);
			reduce_grobner_basis(minimized_G)
		) else (
			// Select and remove a pair from B
			let pair = select_pair(B);
			let remaining_B = remove_pair(B, pair);
			let f = pair.first;
			let g = pair.second;

			// Compute S-polynomial
			let s = s_polynomial(f, g);

			// Reduce S-polynomial with respect to G
			let r = reduce(s, G);

			if r != 0 then (
				// Add new pairs to B (B = B ∪ {{r, h} for each h in G})
				let new_pairs = map(G, \h.Pair(r, h));
				let new_B = union(remaining_B, new_pairs);

				// Add r to the basis (G = G ∪ {r})
				let new_G = append(G, r);

				process_pairs(new_G, new_B)
			) else
				process_pairs(G, remaining_B)
		)
	);

	// Initial pairs: {{f, g} for each pair f,g in F}
	let initial_pairs = all_pairs(F);
	process_pairs(F, initial_pairs)
)

fn s_polynomial(f, g) (
	// Compute the S-polynomial of f and g
	let lt_f = leading_term(f);
	let lt_g = leading_term(g);
	let lcm_term = least_common_multiple(lt_f, lt_g);

	(lcm_term/lt_f) * f - (lcm_term/lt_g) * g
)

fn reduce(p, G) (
	// Reduce polynomial p with respect to set G using recursive approach
	fn reduction_step(q, r, divisible_found) (
		if q == 0 then r
		else if !divisible_found then (
			// Try to find a divisor among G elements
			fn find_divisor(g_idx) (
				if g_idx >= length(G) then
					// No divisor found, move leading term to result
					reduction_step(q - leading_term(q), r + leading_term(q), false)
				else (
					let g = G[g_idx];
					let lt_g = leading_term(g);
					let lt_q = leading_term(q);

					if divides(lt_g, lt_q) then
						// Found divisor, reduce q and continue
						reduction_step(q - (lt_q/lt_g) * g, r, false)
					else
						// Try next divisor
						find_divisor(g_idx + 1)
				)
			);

			find_divisor(0)
		) else (
			// Continue with current q and r
			reduction_step(q, r, false)
		)
	);

	// Start reduction with p, empty result, and no divisor found yet
	reduction_step(p, 0, false)
)
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

```orbit
fn compare_monomials(m1, m2, order_type) (
	order_type is (
		"lex" => lexicographic_comparison(m1, m2);
		"grlex" => (
			let deg1 = total_degree(m1);
			let deg2 = total_degree(m2);

			if deg1 != deg2 then
				deg1 - deg2
			else
				lexicographic_comparison(m1, m2)
		);
		"grevlex" => (
			let deg1 = total_degree(m1);
			let deg2 = total_degree(m2);

			if deg1 != deg2 then
				deg1 - deg2
			else
				reverse_lexicographic_comparison(m1, m2)
		);
		__ => error("Unknown monomial order: " + order_type)
	)
)
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

```orbit
fn minimize_dfa(dfa) (
	// Step 1: Remove unreachable states
	let reachable = find_reachable_states(dfa.start_state, dfa.transitions);
	let restricted_dfa = restrict_to_states(dfa, reachable);

	// Step 2: Partition states by equivalence
	// Initial partition: accepting vs non-accepting states
	let initial_partition = [
		restricted_dfa.accepting_states,
		difference(restricted_dfa.states, restricted_dfa.accepting_states)
	];

	// Helper function to refine partition until it stabilizes
	fn refine_partition(partition, changed) (
		if !changed then partition
		else (
			fn process_blocks(blocks, idx, new_partition, any_changed) (
				if idx >= length(blocks) then
					refine_partition(new_partition, any_changed)
				else (
					let block = blocks[idx];

					// Try to split block based on transitions
					let splits = makeTree();

					// Build transition signatures for each state
					fn process_states(states, s_idx, current_splits) (
						if s_idx >= length(states) then current_splits
						else (
							let state = states[s_idx];
							let signature = [];

							// Create signature based on transitions
							fn build_signature(alphabet, a_idx, sig) (
								if a_idx >= length(alphabet) then sig
								else (
									let symbol = alphabet[a_idx];
									let target = restricted_dfa.transitions[state][symbol];
									let target_block = find_block_containing(target, partition);
									build_signature(alphabet, a_idx + 1, append(sig, target_block))
								)
							);

							let state_signature = build_signature(restricted_dfa.alphabet, 0, []);
							let signature_key = tuple(state_signature);

							// Add state to appropriate signature group
							let updated_splits = if hasKey(current_splits, signature_key) then
								setTree(current_splits, signature_key,
									append(lookupTree(current_splits, signature_key).value, state))
							else
								setTree(current_splits, signature_key, [state]);

							process_states(states, s_idx + 1, updated_splits)
						)
					);

					let block_splits = process_states(block, 0, makeTree());
					let split_values = values(block_splits);

					// If block was split, update partition
					if length(split_values) > 1 then (
						let updated_partition = append_all(new_partition, split_values);
						process_blocks(blocks, idx + 1, updated_partition, true)
					) else (
						let updated_partition = append(new_partition, block);
						process_blocks(blocks, idx + 1, updated_partition, any_changed)
					)
				)
			);

			process_blocks(partition, 0, [], false)
		)
	);

	let final_partition = refine_partition(initial_partition, true);

	// Step 3: Construct minimized DFA
	construct_dfa_from_partition(restricted_dfa, final_partition)
)
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
fn canonicalize_interval(interval) (
	// Handle degenerate cases
	if interval.lower > interval.upper then
		empty_interval()  // Empty interval
	else if interval.lower == interval.upper then
		point_interval(interval.lower)  // Point interval
	else
		// Canonical form: [a, b] where a ≤ b
		Interval(interval.lower, interval.upper)
)

fn interval_add(a, b) (
	// [a_lo, a_hi] + [b_lo, b_hi] = [a_lo + b_lo, a_hi + b_hi]
	Interval(a.lower + b.lower, a.upper + b.upper)
)

fn interval_subtract(a, b) (
	// [a_lo, a_hi] - [b_lo, b_hi] = [a_lo - b_hi, a_hi - b_lo]
	Interval(a.lower - b.upper, a.upper - b.lower)
)

fn interval_multiply(a, b) (
	// [a_lo, a_hi] * [b_lo, b_hi] = [min(products), max(products)]
	let products = [
		a.lower * b.lower,
		a.lower * b.upper,
		a.upper * b.lower,
		a.upper * b.upper
	];

	Interval(min(products), max(products))
)

fn interval_divide(a, b) (
	// Division by an interval containing zero
	if b.lower <= 0 && b.upper >= 0 then
		error("Division by interval containing zero")
	else
		// [a_lo, a_hi] / [b_lo, b_hi] = [a_lo, a_hi] * [1/b_hi, 1/b_lo]
		interval_multiply(a, Interval(1.0/b.upper, 1.0/b.lower))
)
```

### Interval Set Operations

```
fn interval_intersection(a, b) (
	// [a_lo, a_hi] ∩ [b_lo, b_hi] = [max(a_lo, b_lo), min(a_hi, b_hi)]
	let lower = max(a.lower, b.lower);
	let upper = min(a.upper, b.upper);

	if lower <= upper then
		Interval(lower, upper)
	else
		empty_interval()  // Empty intersection
)

fn interval_hull(a, b) (
	// Hull (smallest interval containing both a and b)
	// [a_lo, a_hi] ∪ [b_lo, b_hi] = [min(a_lo, b_lo), max(a_hi, b_hi)]
	Interval(min(a.lower, b.lower), max(a.upper, b.upper))
)
```

## Effect System Canonicalization

Effect systems track computational effects like state mutation, I/O, and exceptions. Canonicalization in effect systems organizes code to make effects explicit and well-structured.

### Effect Analysis and Canonicalization

```
fn infer_effects(expr) (
	expr is (
		// Literal or constant
		e => Pure if is_literal(e) || is_constant(e);  // No effects

		// Variable reference
		VariableRef(__) => Pure;  // Reading a variable has no effect

		// Assignment
		Assignment(var, value) => (
			let value_effect = infer_effects(value);
			combine_effects(value_effect, State)  // Assignment affects state
		);

		// Function call
		FunctionCall(f, args) => (
			let arg_effects = map(args, infer_effects);
			let function_effect = get_function_effect(f);
			combine_all_effects(cons(function_effect, arg_effects))
		);

		// Conditional
		IfStatement(cond, then_branch, else_branch) => (
			let cond_effect = infer_effects(cond);
			let then_effect = infer_effects(then_branch);
			let else_effect = infer_effects(else_branch);
			combine_all_effects([cond_effect, then_effect, else_effect])
		);

		// Sequence
		Sequence(expr1, expr2) => (
			let effect1 = infer_effects(expr1);
			let effect2 = infer_effects(expr2);
			combine_effects(effect1, effect2)
		);

		// Default case
		__ => Unknown
	)
)
```

### Effect-Based Code Transformation

```
fn canonicalize_with_effects(expr) (
	// Analyze effects
	let effects = infer_effects(expr);

	// Separate pure from effectful code
	let parts = separate_by_effects(expr, effects);
	let pure_parts = parts.first;
	let effectful_parts = parts.second;

	// Hoist pure computations
	let result1 = hoist_pure_computations(pure_parts, effectful_parts);

	// Ensure consistent ordering of effects
	let result2 = order_effects(result1);

	result2
)

fn separate_by_effects(expr, effects) (
	// Separate expression into pure and effectful parts
	if effects == Pure then
		Pair(expr, None())
	else expr is (
		Sequence(expr1, expr2) => (
			let result1 = separate_by_effects(expr1, infer_effects(expr1));
			let pure1 = result1.first;
			let effectful1 = result1.second;

			let result2 = separate_by_effects(expr2, infer_effects(expr2));
			let pure2 = result2.first;
			let effectful2 = result2.second;

			let pure = combine_pure(pure1, pure2);
			let effectful = combine_effectful(effectful1, effectful2);

			Pair(pure, effectful)
		);

		// Default case: consider the whole expression effectful if it has effects
		__ => Pair(None(), expr)
	)
)
```

### Effect Commutativity

```
fn order_effects(expr) (
	expr is (
		Sequence(expr1, expr2) => (
			let effect1 = infer_effects(expr1);
			let effect2 = infer_effects(expr2);

			if are_commutative(effect1, effect2) then
				// Use canonical ordering for commutative effects
				if should_swap(expr1, expr2) then
					Sequence(expr2, expr1)
				else
					Sequence(order_effects(expr1), order_effects(expr2))
			else
				// Recursively order subexpressions
				Sequence(order_effects(expr1), order_effects(expr2))
		);

		// For non-sequence expressions, return as is
		__ => expr
	)
)

fn are_commutative(effect1, effect2) (
	// Check if two effects commute (can be reordered)
	if effect1 == Pure || effect2 == Pure then
		true  // Pure effects commute with anything
	else if effect1 == ReadOnly && effect2 == ReadOnly then
		true  // Multiple reads commute
	else if effect1 == Print && effect2 == Print then
		false  // Print effects don't commute (order matters)
	else
		false  // Default: assume effects don't commute
)
```

## General Approach for Any Data Structure

For any data structure with a defined group action, the general approach is:

1. **Identify the symmetry group** (Sₙ, Cₙ, Dₙ, etc.)
2. **Define the group action** on your data structure
3. **Generate the orbit** or use a specialized algorithm
4. **Select the canonical representative** (usually the lexicographically smallest)

```orbit
fn find_canonical_form(object, group, action) (
	if has_specialized_algorithm(group) then
		apply_specialized_algorithm(object, group)
	else (
		// General case - generate orbit and find minimum
		fn find_min_in_orbit(elements, idx, current_min) (
			if idx >= length(elements) then current_min
			else (
				let g = elements[idx];
				let transformed = action(g, object);

				let new_min = if is_less(transformed, current_min) then
					transformed
				else
					current_min;

				find_min_in_orbit(elements, idx + 1, new_min)
			)
		);

		// Start with the object itself as the minimum
		find_min_in_orbit(group, 0, object)
	)
)
```

## Implementation in Orbit System

In the Orbit system, canonicalization is integrated through:

1. **Data Structure Registration**:
   Each major structure registers its symmetry group(s) and canonicalization action:
```orbit
register_structure(array, symmetric_group, sort_array);
register_structure(cyclic_array, cyclic_group, min_rotation);
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