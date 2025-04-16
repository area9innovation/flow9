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

## Conclusion

Canonicalization through group actions provides a powerful unifying framework for working with equivalence classes of diverse data structures. By identifying the appropriate symmetry group and defining its action on a data structure, we can derive canonical representatives that enable efficient equality testing, pattern matching, and normalization.

The approaches outlined in this document demonstrate how abstract group theory translates into practical algorithms for finding canonical forms across a wide range of data structures, from simple arrays to complex mathematical objects like polynomials and graphs.

In the Orbit system, these canonicalization strategies play a crucial role in the rewriting and optimization process, allowing the system to recognize equivalent expressions and apply transformations effectively.
