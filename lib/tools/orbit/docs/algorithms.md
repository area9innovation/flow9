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
fn booth_canonical(arr) = (
	if length(arr) <= 1 then arr
	else (
		let n = length(arr);

		// Create an auxiliary array which is the original array concatenated with itself
		let double_arr = arr + arr;

		// Initialize failure function array with -1
		// (We use -1 instead of conventional 0 to simplify logic)
		let f = \i. if i < 0 || i >= n then -1 else f(i);

		// Compute the min rotation index in linear time
		fn compute_min_index() = (
			// Initialize starting values
			fn find_min(i, j, k) = (
				// We're done when we've checked all rotations
				if i + k >= 2 * n then j
				else if k >= n then find_min(i + 1, j, 0)
				else (
					// Compute the current indices we're comparing
					let i_idx = (i + k) % (2 * n);
					let j_idx = (j + k) % (2 * n);

					if double_arr[i_idx] < double_arr[j_idx] then
						// i rotation is smaller, j becomes i
						find_min(i, i, k + 1)
					else if double_arr[i_idx] > double_arr[j_idx] then
						// j rotation is smaller, i moves forward
						find_min(i + k + 1, j, 0)
					else
						// Equal so far, continue comparison
						find_min(i, j, k + 1)
				)
			);

			// Start with first two positions
			find_min(0, 0, 0)
		);

		let min_start = compute_min_index();

		// Build the canonical form starting from min_start
		fn build_result(idx, result) = (
			if idx >= n then result
			else build_result(idx + 1, result + [arr[(min_start + idx) % n]])
		);

		build_result(0, [])
	)
);
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

TODO: We should also look at the height of the tree and balance it.

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

```orbit
fn canonicalize_derivative(expr) = (
	expr is (
		// Apply chain rule for composite functions
		d/dx(f(g(x))) => canonicalize((d/df(f))(g(x)) * (d/dx(g(x))));

		// Apply product rule
		d/dx(f * g) => canonicalize(f * (d/dx(g)) + (d/dx(f)) * g);

		// Apply quotient rule
		d/dx(f / g) => canonicalize(((d/dx(f)) * g - f * (d/dx(g))) / (g^2));

		// Apply sum/difference rule
		d/dx(f + g) => canonicalize((d/dx(f)) + (d/dx(g)));
		d/dx(f - g) => canonicalize((d/dx(f)) - (d/dx(g)));

		// Apply power rule
		d/dx(x^n) => canonicalize(n * x^(n-1)) if is_constant(n);

		// Apply standard function derivatives
		d/dx(sin(x)) => canonicalize(cos(x));
		d/dx(cos(x)) => canonicalize(-sin(x));
		d/dx(e^x) => canonicalize(e^x);
		d/dx(ln(x)) => canonicalize(1/x);

		// Handle higher-order derivatives recursively
		d²/dx²(f) => canonicalize(d/dx(d/dx(f)));

		// Default case
		_ => expr
	)
)
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

```orbit
fn canonicalize_partial_derivative(expr) = (
	expr is (
		// For constants with respect to the variable
		∂/∂xᵢ(c) => 0 if is_constant_wrt(c, xᵢ);

		// For variables
		∂/∂xᵢ(xⱼ) => if i == j then 1 else 0;

		// Sum rule
		∂/∂xᵢ(f + g) => canonicalize(∂/∂xᵢ(f) + ∂/∂xᵢ(g));

		// Product rule
		∂/∂xᵢ(f * g) => canonicalize(f * ∂/∂xᵢ(g) + ∂/∂xᵢ(f) * g);

		// Mixed partial derivatives (equal for smooth functions)
		∂²f/∂xᵢ∂xⱼ => canonicalize(∂²f/∂xⱼ∂xᵢ) if is_smooth(f);

		// Default case
		_ => expr
	)
)
```

## Matrix and Linear Algebra Canonicalization

Matrices and linear algebraic structures require specialized canonicalization approaches that respect their mathematical properties.

### Basic Matrix Canonicalization

```orbit
fn canonicalize_matrix(matrix) = (
	// Handle special cases based on matrix properties
	if is_diagonal(matrix) then
		canonicaliz_ediagonal_matrix(matrix)
	else if is_symmetric(matrix) then
		canonicaliz_esymmetric_matrix(matrix)
	else if is_triangular(matrix) then
		canonicaliz_etriangular_matrix(matrix)
	// For general matrices, use row echelon form
	else if need_canonical_representation then
		row_echelon_form(matrix)
	else
		matrix
)
```

### Matrix Decomposition-Based Canonicalization

Matrix decompositions provide powerful tools for canonicalization:

```orbit
fn canonicalize_via_decomposition(matrix) = (
	// Singular Value Decomposition (SVD)
	if svd_is_appropriate(matrix) then (
		let svd_result = svd(matrix);
		let U = svd_result.first;
		let Σ = svd_result.second;
		let V_T = svd_result.third;
		// Ensure uniqueness of decomposition
		let unique_svd = make_unique_svd(U, Σ, V_T);
		Triple(unique_svd.first, unique_svd.second, unique_svd.third)  // Canonical triplet representation
	)

	// Eigendecomposition for diagonalizable matrices
	else if is_diagonalizable(matrix) then (
		let eigen_result = eigendecomposition(matrix);
		let P = eigen_result.first;
		let D = eigen_result.second;
		// Sort eigenvalues and corresponding eigenvectors
		let sorted_eigen = sort_eigen(P, D);
		Pair(sorted_eigen.first, sorted_eigen.second)  // Canonical pair representation
	)

	// QR decomposition
	else if qr_is_appropriate(matrix) then (
		let qr_result = qr_decomposition(matrix);
		let Q = qr_result.first;
		let R = qr_result.second;
		// Ensure uniqueness (e.g., positive diagonal in R)
		let unique_qr = make_unique_qr(Q, R);
		Pair(unique_qr.first, unique_qr.second)  // Canonical pair representation
	)

	// LU decomposition
	else if lu_is_appropriate(matrix) then (
		let lu_result = lu_decomposition(matrix);
		Pair(lu_result.first, lu_result.second)  // Canonical pair representation
	)

	// Cholesky for positive definite matrices
	else if is_positive_definite(matrix) then (
		let L = cholesky_decomposition(matrix);  // Lower triangular
		L  // Canonical representation
	)

	else
		matrix
)
```

### Structured Matrix Canonicalization

```orbit
fn canonicalize_symmetric_matrix(matrix) = (
	// Ensure the matrix is exactly symmetric
	let n = matrix.rows;

	// Helper function to symmetrize all elements
	fn symmetrize_elements(i, result_matrix) = (
		if i >= n then result_matrix
		else (
			fn process_j(j, curr_matrix) = (
				if j >= n then curr_matrix
				else (
					let avg_value = (curr_matrix[i,j] + curr_matrix[j,i])/2;
					let matrix1 = set_matrix_element(curr_matrix, i, j, avg_value);
					let matrix2 = set_matrix_element(matrix1, j, i, avg_value);
					process_j(j + 1, matrix2)
				)
			);

			let updated_matrix = process_j(i + 1, result_matrix);
			symmetrize_elements(i + 1, updated_matrix)
		)
	);

	symmetrize_elements(0, matrix)
)

fn canonicalize_triangular_matrix(matrix) = (
	let n = matrix.rows;

	// For upper triangular, zero out below diagonal
	let matrix1 = if is_upper_triangular(matrix) then (
		// Helper to zero out elements below diagonal
		fn zero_below(i, curr_matrix) = (
			if i >= n then curr_matrix
			else (
				fn process_j(j, mat) = (
					if j >= i then mat
					else (
						let new_mat = set_matrix_element(mat, i, j, 0);
						process_j(j + 1, new_mat)
					)
				);
				let updated_matrix = process_j(0, curr_matrix);
				zero_below(i + 1, updated_matrix)
			)
		);
		zero_below(1, matrix)
	) else matrix;

	// For lower triangular, zero out above diagonal
	let matrix2 = if is_lower_triangular(matrix1) then (
		// Helper to zero out elements above diagonal
		fn zero_above(i, curr_matrix) = (
			if i >= n then curr_matrix
			else (
				fn process_j(j, mat) = (
					if j >= n then mat
					else if j <= i then process_j(j + 1, mat)
					else (
						let new_mat = set_matrix_element(mat, i, j, 0);
						process_j(j + 1, new_mat)
					)
				);
				let updated_matrix = process_j(0, curr_matrix);
				zero_above(i + 1, updated_matrix)
			)
		);
		zero_above(0, matrix1)
	) else matrix1;

	matrix2
)
```

### Matrix Multiplication Canonicalization

```orbit
fn canonicalize_matrix_multiplication(expr) = (
	expr is (
		// Associative property: (AB)C = A(BC)
		(A*B)*C => (
			// Choose canonical grouping based on dimensions
			if A.cols*B.cols + A.cols*C.cols < A.cols*B.cols + B.cols*C.cols then
				canonicaliz(A*(B*C))
			else
				canonicaliz((A*B)*C)
		);

		// Identity elimination
		A*I => canonicalize(A);
		I*A => canonicalize(A);

		// Special case: diagonal matrix multiplication
		A*B => canonicalize_diagonal_product(A, B) if is_diagonal(A) && is_diagonal(B);

		// Default
		_ => expr
	)
)
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

```orbit
fn normal_form(f, G) = (
	// Compute the normal form of f with respect to Gröbner basis G
	// This is a unique representative of f in the ideal generated by G

	reduce(f, G)
)

fn ideal_membership_test(f, G) = (
	// Test if polynomial f belongs to the ideal generated by G
	let nf = normal_form(f, G);

	nf == 0  // f is in the ideal if and only if its normal form is zero
)

fn polynomial_canonicalization(f, I) = (
	// Canonicalize a polynomial f with respect to an ideal I
	// by reducing it modulo a Gröbner basis for I

	let G = compute_grobner_basis(I);
	normal_form(f, G)
)
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

```orbit
fn canonicalize_tensor(tensor) = (
	// Handle tensor symmetry properties
	let tensor1 = if has_index_symmetry(tensor) then
		apply_symmetry_constraints(tensor)
	else
		tensor;

	// Rename free indices to canonical names
	let tensor2 = rename_free_indices(tensor1);

	// Rename dummy (repeated) indices canonically
	let tensor3 = rename_dummy_indices(tensor2);

	// Apply tensor contractions where possible
	let tensor4 = apply_contractions(tensor3);

	tensor4
)
```

### Index Canonicalization

```orbit
fn rename_free_indices(tensor) = (
	// Identify free indices (those appearing exactly once)
	let free_indices = find_free_indices(tensor);

	// Sort free indices based on position and rename to canonical names
	let sorted_indices = sort_by_position(free_indices);

	// Create mapping from original indices to canonical names
	fn build_mapping(i, mapping) = (
		if i >= length(sorted_indices) then mapping
		else (
			let new_mapping = setTree(mapping, sorted_indices[i], canonical_name(i));
			build_mapping(i + 1, new_mapping)
		)
	);
	let mapping = build_mapping(0, makeTree());

	// Apply renaming
	rename_indices(tensor, mapping)
)

fn rename_dummy_indices(tensor) = (
	// Identify pairs of dummy indices (those appearing exactly twice)
	let dummy_pairs = find_dummy_pairs(tensor);

	// Sort pairs based on position and rename to canonical names
	let sorted_pairs = sort_by_position(dummy_pairs);

	// Create mapping from original indices to canonical names
	fn build_mapping(i, mapping) = (
		if i >= length(sorted_pairs) then mapping
		else (
			let pair = sorted_pairs[i];
			let idx1 = pair.first;
			let idx2 = pair.second;
			let dummy_name = canonical_dummy_name(i);
			let mapping1 = setTree(mapping, idx1, dummy_name);
			let mapping2 = setTree(mapping1, idx2, dummy_name);
			build_mapping(i + 1, mapping2)
		)
	);
	let mapping = build_mapping(0, makeTree());

	// Apply renaming
	rename_indices(tensor, mapping)
)
```

### Symmetry Application

```orbit
fn apply_symmetry_constraints(tensor) = (
	// Get tensor symmetry properties
	let symmetries = get_tensor_symmetries(tensor);

	// Apply each symmetry type recursively
	fn apply_symmetries(remaining_symmetries, current_tensor) = (
		if is_empty(remaining_symmetries) then current_tensor
		else (
			let symmetry = head(remaining_symmetries);
			let next_symmetries = tail(remaining_symmetries);

			let updated_tensor = symmetry.type is (
				"symmetric" => symmetrize(current_tensor, symmetry.indices);
				"antisymmetric" => antisymmetrize(current_tensor, symmetry.indices);
				"cyclic" => cyclically_symmetrize(current_tensor, symmetry.indices);
				_ => current_tensor
			);

			apply_symmetries(next_symmetries, updated_tensor)
		)
	);

	apply_symmetries(symmetries, tensor)
)

fn symmetrize(tensor, indices) = (
	// Average over all permutations of the specified indices
	let result = zero_tensor_like(tensor);
	let perms = all_permutations(indices);

	// Sum over permutations recursively
	fn sum_permutations(remaining_perms, sum_tensor) = (
		if is_empty(remaining_perms) then sum_tensor
		else (
			let perm = head(remaining_perms);
			let next_perms = tail(remaining_perms);
			let permuted_tensor = permute_indices(tensor, indices, perm);
			let updated_sum = tensor_add(sum_tensor, permuted_tensor);
			sum_permutations(next_perms, updated_sum)
		)
	);

	let total = sum_permutations(perms, result);
	tensor_divide(total, length(perms))
)

fn antisymmetrize(tensor, indices) = (
	// Average over all permutations of the specified indices with sign
	let result = zero_tensor_like(tensor);
	let perms = all_permutations(indices);

	// Sum over permutations with sign recursively
	fn sum_signed_permutations(remaining_perms, sum_tensor) = (
		if is_empty(remaining_perms) then sum_tensor
		else (
			let perm = head(remaining_perms);
			let next_perms = tail(remaining_perms);
			let sign = permutation_sign(perm);
			let permuted_tensor = permute_indices(tensor, indices, perm);
			let signed_tensor = tensor_multiply(permuted_tensor, sign);
			let updated_sum = tensor_add(sum_tensor, signed_tensor);
			sum_signed_permutations(next_perms, updated_sum)
		)
	);

	let total = sum_signed_permutations(perms, result);
	tensor_divide(total, length(perms))
)
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

```orbit
fn canonicalize_regex(regex) = (
	// Convert to NFA
	let nfa = regex_to_nfa(regex);

	// Convert NFA to DFA
	let dfa = nfa_to_dfa(nfa);

	// Minimize DFA
	let min_dfa = minimize_dfa(dfa);

	// Convert back to regex (if needed)
	let canonical_regex = dfa_to_regex(min_dfa);

	canonical_regex

fn regex_algebraic_simplification(regex) = (
	// Apply algebraic laws to simplify regex using pattern matching
	regex is (
		// Idempotence
		r|r => simplify(r);

		// Empty string laws
		rε => simplify(r);

		// Empty set laws
		r|∅ => simplify(r);

		// Distributivity
		r(s|t) => simplify(rs|rt);

		// Kleene star laws
		(r*)* => simplify(r*);

		// Default case
		_ => regex
	)
)
```

## Loop Transformations and Polyhedral Model

Loop transformations are critical for optimizing computation-intensive programs. The polyhedral model provides a mathematical framework for these transformations.

### Loop Transformations

```orbit
fn canonicalize_loop_nest(loop_nest) = (
	// Normalize loop bounds to start at 0 with step 1
	let normalized = normalize_loops(loop_nest);

	// Apply canonical loop ordering based on data access patterns
	let ordered = reorder_loops(normalized);

	ordered
)

fn normalize_loops(loop_nest) = (
	// Transform each loop recursively
	fn process_loops(loops, idx, current_result) = (
		if idx >= length(loops) then current_result
		else (
			let loop = loops[idx];
			// Transform: for(i=a; i<b; i+=c) → for(i'=0; i'<(b-a)/c; i'+=1)
			let normalized_loop = normalize_loop(loop);
			let updated_result = replace_loop(current_result, loop, normalized_loop);
			process_loops(loops, idx + 1, updated_result)
		)
	);

	process_loops(loop_nest.loops, 0, loop_nest)
)

fn reorder_loops(loop_nest) = (
	// Analyze data dependencies
	let deps = analyze_dependencies(loop_nest);

	// Determine legal loop ordering
	let ordering = compute_legal_ordering(loop_nest.loops, deps);

	// Apply reordering
	reorder_by(loop_nest, ordering)
)
```

### Loop Fusion and Tiling

```orbit
fn fuse_loops(loop1, loop2) = (
	// Check if loops can be legally fused
	if !can_legally_fuse(loop1, loop2) then
		[loop1, loop2]
	else (
		// Create fused loop
		let fused = create_fused_loop(loop1, loop2);
		[fused]
	)
)

fn tile_loop(loop, tile_size) = (
	// Transform single loop into nested tile+intra-tile loops
	// for(i=0; i<N; i++) → for(ii=0; ii<N; ii+=T) for(i=ii; i<min(ii+T,N); i++)

	let outer_loop = create_tile_loop(loop, tile_size);
	let inner_loop = create_intra_tile_loop(loop, tile_size);

	// Replace inner loop body with original loop body
	let inner_with_body = set_loop_body(inner_loop, loop.body);

	// Set inner loop as body of outer loop
	let result = set_loop_body(outer_loop, inner_with_body);

	result
)
```

### Polyhedral Model

```orbit
fn polyhedral_canonicalization(loop_nest) = (
	// Extract polyhedral representation
	let domain = extract_iteration_domain(loop_nest);
	let schedule = extract_schedule(loop_nest);
	let accesses = extract_access_functions(loop_nest);

	// Optimize schedule while preserving semantics
	let optimized_schedule = optimize_schedule(domain, schedule, accesses);

	// Generate loop nest from optimized schedule
	let optimized_loops = generate_loops(domain, optimized_schedule, accesses);

	optimized_loops
)

fn optimize_schedule(domain, schedule, accesses) = (
	// Find schedule that minimizes cost function (e.g., data locality)
	let dependencies = compute_dependencies(domain, accesses);

	// Create schedule optimization problem
	let problem = create_scheduling_problem(domain, dependencies);

	// Solve for optimal schedule coefficients
	let solution = solve_scheduling_problem(problem);

	// Construct new schedule from solution
	let new_schedule = construct_schedule(solution);

	new_schedule
)
```

## Binary Decision Diagrams (BDDs)

Binary Decision Diagrams (BDDs) provide a canonical representation for Boolean functions, enabling efficient symbolic verification, model checking, and Boolean function manipulation.

### Structure and Representation

A BDD represents a Boolean function φ:{0,1}ⁿ→{0,1} as a rooted directed acyclic graph (DAG) with decision nodes and terminal leaves. Each decision node tests one Boolean variable and has two children:

```
t ::= 0 | 1 | ITE(v, t₀, t₁)
	 where v ∈ {v₁ < ... < vₙ}, t₀, t₁ ∈ t
```

Here `ITE(v, t₀, t₁)` means "if v=0 then follow t₀, else follow t₁." BDDs become powerful when we enforce a canonical form through reduction and variable ordering.

### Conversion to BDD (Shannon Expansion)

To convert arbitrary Boolean formulas into BDD form, we apply Shannon expansion recursively:

```orbit
fn shannon_expand(formula) (
	formula is (
		// Constants
		0 => 0;
		1 => 1;

		// Variables
		v if is_variable(v) => ITE(v, 0, 1);

		// Negation
		!phi => (
			let v = min_variable(phi);
			ITE(v, !restrict(phi, v, 0), !restrict(phi, v, 1))
		);

		// Conjunction
		phi & psi => (
			let v = min_variable(phi, psi);
			ITE(v,
				restrict(phi, v, 0) & restrict(psi, v, 0),
				restrict(phi, v, 1) & restrict(psi, v, 1)
			)
		);

		// Disjunction
		phi | psi => (
			let v = min_variable(phi, psi);
			ITE(v,
				restrict(phi, v, 0) | restrict(psi, v, 0),
				restrict(phi, v, 1) | restrict(psi, v, 1)
			)
		);

		// Exclusive-OR
		phi ^ psi => (
			let v = min_variable(phi, psi);
			ITE(v,
				restrict(phi, v, 0) ^ restrict(psi, v, 0),
				restrict(phi, v, 1) ^ restrict(psi, v, 1)
			)
		);
	)
)

// Restrict a formula by setting variable v to value b
fn restrict(formula, v, b) (
	// Substitute v with constant b in the formula
	substitute(formula, v, b)
)

// Find the smallest (first in order) variable in formula(s)
fn min_variable(formulas...) (
	// Get all variables in the formulas
	let vars = union_all(map(formulas, get_variables));
	// Return the smallest according to the ordering
	min(vars)
)
```

This recursively applies Shannon expansion, always choosing the smallest variable according to the fixed variable ordering.

### BDD Reduction Rules

After converting to BDD form, we apply reduction rules to maintain canonicity:

```orbit
fn reduce_bdd(bdd) (
	bdd is (
		// Terminal nodes remain unchanged
		0 => 0;
		1 => 1;

		ITE(v, t_low, t_high) => (
			// Recursively reduce the children
			let reduced_low = reduce_bdd(t_low);
			let reduced_high = reduce_bdd(t_high);

			// Apply reduction rules

			// Rule 1: Terminal collapse - if both children are same terminal
			if reduced_low == reduced_high then
				reduced_low

			// Rule 2: Check for existing node in unique table
			else if has_node_in_table(v, reduced_low, reduced_high) then
				get_node_from_table(v, reduced_low, reduced_high)

			// Create new reduced node and add to table
			else (
				let new_node = ITE(v, reduced_low, reduced_high);
				add_node_to_table(new_node);
				new_node
			)
		)
	)
)
```

Additionally, we need to implement the variable ordering rule:

```orbit
fn apply_variable_ordering(bdd) (
	bdd is (
		// Terminal nodes are already in order
		0 => 0;
		1 => 1;

		ITE(v, t_low, t_high) => (
			// Check if we need to reorder
			let min_var = min_variable_in_node(t_low, t_high);

			if min_var < v then (
				// Reorder: move min_var to the top
				ITE(min_var,
					apply_variable_ordering(restrict_node(bdd, min_var, 0)),
					apply_variable_ordering(restrict_node(bdd, min_var, 1))
				)
			) else (
				// Already in order, just recurse on children
				ITE(v,
					apply_variable_ordering(t_low),
					apply_variable_ordering(t_high)
				)
			)
		)
	)
)
```

### Complete BDD Canonicalization

The full canonicalization process combines conversion and reduction:

```orbit
fn canonicalize_boolean_function(formula) (
	// Step 1: Convert to BDD form using Shannon expansion
	let bdd_form = shannon_expand(formula);

	// Step 2: Apply variable ordering
	let ordered_bdd = apply_variable_ordering(bdd_form);

	// Step 3: Apply reduction rules
	let canonical_bdd = reduce_bdd(ordered_bdd);

	canonical_bdd
)
```

### Applications and Benefits

Reduced, ordered BDDs provide:

1. **Canonical representation**: Semantically equivalent Boolean functions have identical BDDs
2. **Compactness**: Many Boolean functions have compact BDD representations
3. **Efficient operations**: Boolean operations become graph operations on BDDs
4. **Memory efficiency**: Shared sub-graphs reduce redundancy
5. **Symbolic verification**: Enables verification of systems with large state spaces

**Example**:
```
// Formula: (a & b) | (a & c)
// Shannon expanded:
//   ITE(a,
//     ITE(b, ITE(c, 0, 0), ITE(c, 0, 1)),
//     ITE(b, ITE(c, 0, 1), ITE(c, 1, 1))
//   )

// After reduction:
//   ITE(a,
//     ITE(b, 0, ITE(c, 0, 1)),
//     ITE(c, 1, 1)
//   )

// Further simplified to:
//   ITE(a, ITE(b, 0, c), 1)
// Which is equivalent to a & (b => c)
```

This canonical representation enables efficient equality testing for Boolean functions, regardless of their original syntactic form.

### BDD Operations and Applications

Beyond basic construction and canonicalization, BDDs support efficient implementations of various Boolean operations and analyses.

#### Boolean Operations on BDDs

We can define Boolean operations directly on BDDs by aligning their top-level tests:

```orbit
fn bdd_and(node1, node2) (
	// Handle terminal cases first
	if node1 == 0 || node2 == 0 then 0
	else if node1 == 1 then node2
	else if node2 == 1 then node1
	else (
		// Both are internal nodes
		let v1 = get_var(node1);
		let v2 = get_var(node2);

		if v1 == v2 then (
			// Same variable - align and recurse on both branches
			let low = bdd_and(get_low(node1), get_low(node2));
			let high = bdd_and(get_high(node1), get_high(node2));
			make_node(v1, low, high)
		) else if v1 < v2 then (
			// v1 comes before v2 in order - recurse on v1's branches
			let low = bdd_and(get_low(node1), node2);
			let high = bdd_and(get_high(node1), node2);
			make_node(v1, low, high)
		) else (
			// v2 comes before v1 in order - recurse on v2's branches
			let low = bdd_and(node1, get_low(node2));
			let high = bdd_and(node1, get_high(node2));
			make_node(v2, low, high)
		)
	)
)

// Similar implementations for other operations
fn bdd_or(node1, node2) (
	// Handle terminal cases
	if node1 == 1 || node2 == 1 then 1
	else if node1 == 0 then node2
	else if node2 == 0 then node1
	else /* Similar recursive implementation */
)

fn bdd_not(node) (
	if node == 0 then 1
	else if node == 1 then 0
	else (
		let v = get_var(node);
		let low = bdd_not(get_low(node));
		let high = bdd_not(get_high(node));
		make_node(v, low, high)
	)
)

fn bdd_xor(node1, node2) (
	// Terminal cases
	if node1 == 0 then node2
	else if node2 == 0 then node1
	else if node1 == 1 then bdd_not(node2)
	else if node2 == 1 then bdd_not(node1)
	else /* Similar recursive implementation */
)
```

These operations preserve canonicity and reuse shared structure, making them very efficient.

#### Quantification

Quantifiers are implemented as Boolean operations over variable cofactors:

```orbit
// Existential quantification: ∃v.f
fn bdd_exists(var, node) (
	// Compute f[v→0] ∨ f[v→1]
	bdd_or(
		bdd_restrict(node, var, 0),
		bdd_restrict(node, var, 1)
	)
)

// Universal quantification: ∀v.f
fn bdd_forall(var, node) (
	// Compute f[v→0] ∧ f[v→1]
	bdd_and(
		bdd_restrict(node, var, 0),
		bdd_restrict(node, var, 1)
	)
)

// Variable substitution/restriction
fn bdd_restrict(node, var, value) (
	if is_terminal(node) then node
	else (
		let v = get_var(node);
		if v == var then
			// Direct substitution
			if value == 0 then get_low(node) else get_high(node)
		else if v > var then
			// var doesn't appear in this subtree
			node
		else (
			// Recurse on both branches
			let low = bdd_restrict(get_low(node), var, value);
			let high = bdd_restrict(get_high(node), var, value);
			make_node(v, low, high)
		)
	)
)
```

By rewriting quantifiers into BDD operations, we avoid explicit enumeration of all 2ⁿ variable assignments.

#### Satisfiability and Equivalence

BDDs make some complex problems trivial:

```orbit
fn bdd_is_satisfiable(node) (
	// A BDD is satisfiable if it's not identically 0
	node != 0
)

fn bdd_are_equivalent(node1, node2) (
	// Two functions are equivalent if their canonical BDDs are identical
	node1 == node2
)

// Find one satisfying assignment
fn bdd_find_satisfying_assignment(node) (
	if node == 0 then [] // Unsatisfiable
	else if node == 1 then [] // Any assignment works
	else (
		let v = get_var(node);
		// Try low branch first (v=0)
		if get_low(node) != 0 then
			concat([Pair(v, 0)], bdd_find_satisfying_assignment(get_low(node)))
		else
			// Otherwise try high branch (v=1)
			concat([Pair(v, 1)], bdd_find_satisfying_assignment(get_high(node)))
	)
)
```

#### Model Counting

We can efficiently count satisfying assignments by annotating BDD nodes:

```orbit
fn bdd_count_models(node, var_count) (
	// Cache for dynamic programming
	let counts = makeTree();

	// Recursive counting function
	fn count(n, remaining_vars) (
		// Check cache
		let key = Pair(n, remaining_vars);
		if hasKey(counts, key) then
			lookupTree(counts, key).value
		else (
			let result = if n == 0 then
				0 // No models
			else if n == 1 then
				pow(2, remaining_vars) // All remaining variables can be anything
			else (
				let v = get_var(n);
				// Skip variables not in this path
				let skipped = count_skipped_vars(v, remaining_vars);
				let factor = pow(2, skipped);

				// Recursive counting on both branches
				let low_count = count(get_low(n), remaining_vars - skipped - 1);
				let high_count = count(get_high(n), remaining_vars - skipped - 1);

				factor * (low_count + high_count)
			);

			// Cache result
			setTree(counts, key, result);
			result
		)
	);

	count(node, var_count)
)
```

This approach counts models in time proportional to the BDD size, not the (potentially exponential) number of solutions.

### Practical Applications of BDDs

BDDs excel in several domains:

1. **Hardware Verification**: Representing and checking circuits with millions of gates
2. **Model Checking**: Verifying temporal logic properties of finite-state systems
3. **Logic Synthesis**: Optimizing Boolean functions in circuit design
4. **Symbolic AI**: Compact encoding of domains like planning problems
5. **Set Operations**: Representing large sets and performing operations efficiently

The key property making BDDs practical is that many real-world Boolean functions have compact BDD representations, avoiding exponential blow-up through structural sharing and canonicity.

TODO: Consider if variable reordering in BDDs could be a canonicalization step. This is a common optimization in BDD libraries, but it may not strictly be canonicalization in the same sense as the other examples.

## Interval Arithmetic

Interval arithmetic operates on intervals rather than precise values, providing bounded guarantees for numerical computations.

### Interval Operations

```orbit
fn canonicalize_interval(interval) = (
	// Handle degenerate cases
	if interval.lower > interval.upper then
		empty_interval()  // Empty interval
	else if interval.lower == interval.upper then
		point_interval(interval.lower)  // Point interval
	else
		// Canonical form: [a, b] where a ≤ b
		Interval(interval.lower, interval.upper)
)

fn interval_add(a, b) = (
	// [a_lo, a_hi] + [b_lo, b_hi] = [a_lo + b_lo, a_hi + b_hi]
	Interval(a.lower + b.lower, a.upper + b.upper)
)

fn interval_subtract(a, b) = (
	// [a_lo, a_hi] - [b_lo, b_hi] = [a_lo - b_hi, a_hi - b_lo]
	Interval(a.lower - b.upper, a.upper - b.lower)
)

fn interval_multiply(a, b) = (
	// [a_lo, a_hi] * [b_lo, b_hi] = [min(products), max(products)]
	let products = [
		a.lower * b.lower,
		a.lower * b.upper,
		a.upper * b.lower,
		a.upper * b.upper
	];

	Interval(min(products), max(products))
)

fn interval_divide(a, b) = (
	// Division by an interval containing zero
	if b.lower <= 0 && b.upper >= 0 then
		error("Division by interval containing zero")
	else
		// [a_lo, a_hi] / [b_lo, b_hi] = [a_lo, a_hi] * [1/b_hi, 1/b_lo]
		interval_multiply(a, Interval(1.0/b.upper, 1.0/b.lower))
)
```

### Interval Set Operations

```orbit
fn interval_intersection(a, b) = (
	// [a_lo, a_hi] ∩ [b_lo, b_hi] = [max(a_lo, b_lo), min(a_hi, b_hi)]
	let lower = max(a.lower, b.lower);
	let upper = min(a.upper, b.upper);

	if lower <= upper then
		Interval(lower, upper)
	else
		empty_interval()  // Empty intersection
)

fn interval_hull(a, b) = (
	// Hull (smallest interval containing both a and b)
	// [a_lo, a_hi] ∪ [b_lo, b_hi] = [min(a_lo, b_lo), max(a_hi, b_hi)]
	Interval(min(a.lower, b.lower), max(a.upper, b.upper))
)
```

## Effect System Canonicalization

Effect systems track computational effects like state mutation, I/O, and exceptions. Canonicalization in effect systems organizes code to make effects explicit and well-structured.

### Effect Analysis and Canonicalization

```orbit
fn infer_effects(expr) = (
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

```orbit
fn canonicalize_with_effects(expr) = (
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

fn separate_by_effects(expr, effects) = (
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

```orbit
fn order_effects(expr) = (
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

fn are_commutative(effect1, effect2) = (
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

## Pruning of orbit

```orbit
// Orbit sketch: generic orbit pruning via stabilizer‐chain & prefix pruning
// Hooks: user supplies action, comparison, invariants, and coset reps

/// Find the canonical representative of `obj` under a group action.
/// - `gens`        : array of group generators
/// - `action`      : (g, o) -> o′ applies g to object o
/// - `compare`     : (o1, o2) -> int  lex compare: -1 if o1<o2, 0 if =, 1 if o1>o2
/// - `invariants`  : array of (o -> I) functions; higher I means “worse”
/// - `cosetRepsFn` : fn(gens) -> [[G]]   array of coset‐rep arrays for each base point
fn findCanonical(obj, gens, action, compare, invariants, cosetRepsFn) = (
	// Precompute coset representatives for each level
	let cosetReps = cosetRepsFn(gens);

	// Recursive DFS with pruning
	fn dfs(level, currObj, bestObj) = (
		// 1) Invariant‐based prune: if any inv(currObj) > inv(bestObj), cut
		let bad = invariants is (
			inv => inv(currObj) > inv(bestObj) => true;
			_   => false
		);
		if bad then bestObj
		// 2) Fully assigned: compare to best
		else if level == length(cosetReps) then
			if compare(currObj, bestObj) < 0 then currObj else bestObj
		else (
			// 3) Explore coset reps at this level
			let reps = cosetReps[level];
			// Fold over all g in this coset
			fold(reps, bestObj, \(acc, g).
				let nextObj = action(g, obj);
				// Prefix‐lex prune: if partial action can't beat acc, user hook may reject
				acc2 is (
				  // optional user‐provided prune hooks could go here
				  _ => dfs(level + 1, nextObj, acc)
				);
				acc2
			)
		)
	);

	// Start recursion with level=0, obj as both current and best
	dfs(0, obj, obj)
);

/// Example stub: builds a stabilizer‐chain coset reprs for a permutation group
fn exampleCosets(gens) = (
	// In practice run Schreier–Sims to get a base and coset reps per level
	// Here: single‐level trivial coset of identity
	[ [ identity ] ]
);

// === Usage sketch ===

let myGenerators = [ g1, g2, g3 ];           // user‐provided group generators
let myAction     = \(g, o). apply(g, o);     // how g acts on object o
let myCompare    = \(o1, o2). lexCmp(o1, o2);
let myInvariants = [ sizeInvariant, hashInvariant ];  // cheap bounds
let canon = findCanonical(
	originalObject,
	myGenerators,
	myAction,
	myCompare,
	myInvariants,
	exampleCosets
);

println("Canonical form: " + prettyOrbit(canon));
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