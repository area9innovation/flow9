# Mathematical Algorithm Speedups Through Identity Exploitation and Domain Specialization

## Introduction

Mathematical algorithms often experience dramatic performance improvements when we leverage specific algebraic identities, domain-specific properties, or apply constraints to restrict the problem space. This document explores how Orbit's e-graph architecture with canonical forms provides a powerful framework for automatically discovering and applying these optimizations through saturation of rewrite rules.

Just as Orbit can automatically derive FFT from DFT by exploiting cyclic group symmetries, similar transformations can be applied to many other algorithms. The key insight is that by saturating the e-graph with all known identities and algebraic properties, optimal algorithms can emerge naturally from the rewriting process without requiring explicit decision procedures.

## The E-Graph Advantage for Algorithm Discovery

Orbit's e-graph architecture with canonical forms provides two fundamental advantages that make automatic algorithm discovery possible:

### 1. Exponential Reduction Through Structure Sharing

E-graphs avoid combinatorial explosion by representing multiple equivalent expressions in a shared structure:

```orbit
// Consider n expressions with multiple equivalent forms
// Traditional approach: Store all versions separately (exponential space)
// E-graph approach: Represent equivalence classes with shared structure

// Example: Equivalent ways to compute a sum
a + b + c + d : Associative;  // Could be parsed many ways
a + (b + (c + d));
((a + b) + c) + d;
(a + b) + (c + d);
// All represented as a single e-class in the e-graph
```

### 2. Exponential Reduction Through Canonical Forms

Canonical forms select a single representative from each equivalence class, enabling efficient pattern matching:

```orbit
// Without canonicalization: Need to match all n! permutations
a + b + c + d : Commutative;
a + b + c + d;
b + a + c + d;
a + c + b + d;
// ... (24 total permutations)

// With canonicalization: Match only the canonical form
a + b + c + d : Commutative → sort_operands(a + b + c + d) : Canonical;
// Only need to match against the canonical form
```

### 3. Emergent Algorithms Through Rule Saturation

Instead of encoding decision procedures for algorithm selection, Orbit applies all possible rules and lets optimal algorithms emerge naturally:

```orbit
// Traditional approach: Explicitly select an algorithm based on input properties
matrix_multiply(A, B) {
	if (is_large_enough(A) && is_large_enough(B))
		return strassen_multiply(A, B);
	else
		return standard_multiply(A, B);
}

// Orbit approach: Apply all relevant rules and let e-graph find optimal implementation
multiply(A, B) : Matrix;
A * B : Matrix → standard_multiply(A, B) : Impl;  // Basic implementation
A * B : Matrix : LargeMatrix → strassen_multiply(A, B) : Impl;  // Optimization rule
A * B : Matrix : DiagonalMatrix → diagonal_multiply(A, B) : Impl;  // Structure-specific rule
// The e-graph contains all equivalent implementations
// Extract function can select the best one based on cost model
```

## Automatic Propagation of Domain Properties

A key strength of Orbit is the ability to automatically detect and propagate domain-specific properties, which then trigger specialized optimizations:

```orbit
// Domain detection and propagation
A : Matrix, is_triangular(A) ⊢ A : TriangularMatrix;  // Property detection
A : TriangularMatrix, B : TriangularMatrix ⊢ A * B : TriangularMatrix;  // Property propagation

// Property-triggered optimizations
A * B : TriangularMatrix → triangular_multiply(A, B) : Optimized;  // Specialized algorithm
inverse(A) : TriangularMatrix → triangular_inverse(A) : Optimized;  // O(n²) algorithm
```

This allows Orbit to discover domain-specific optimizations without explicitly encoding algorithm selection logic. The domain properties flow through the computation graph, triggering optimizations wherever applicable.

## Cross-Domain Synergies Through Group-Theoretic Bridging

### Mathematical Structures as Bridges Between Domains

One of the most powerful aspects of Orbit's approach is the ability to establish bridges between different mathematical domains using group theory and algebraic structures. This enables applying optimizations from one domain to problems in another domain:

```orbit
// Bridge between graph theory and linear algebra
G : Graph ↔ adjacency_matrix(G) : Matrix;  // Bidirectional transformation

// Bridge between polynomials and vectors
p : Polynomial ↔ coefficient_vector(p) : Vector;  // Bidirectional transformation

// Bridge between groups and permutations
g : Group ↔ permutation_representation(g) : Permutation;  // Bidirectional transformation
```

These bridges allow optimizations to flow across domain boundaries, potentially unlocking algorithms that wouldn't be obvious in the original domain.

### Group-Theoretic Identities Unlocking New Optimizations

The recognition of group structures in problems can lead to entirely new optimization strategies that weren't apparent in the original formulation:

```orbit
// Recognizing cyclic group structure in rotations
rotation(x, n) : Operation ⊢ rotation(x, n) : C_n;  // Detect cyclic group

// This domain annotation enables these optimizations
rotation(rotation(x, a), b) : C_n → rotation(x, (a + b) % n) : Optimized;  // Combining rotations
rotation(x, 0) : C_n → x : Identity;  // Identity element optimization
rotation(x, n) : C_n → rotation(x, n % cyclicGroupOrder(x)) : Canonical;  // Canonical form
```

The key insight is that once group-theoretic properties are discovered, they unlock an entire family of optimizations that apply to any operation with the same group structure, regardless of the underlying domain.

### Transformations Between Representation Domains

Problems can often be transformed between different representation domains to leverage specialized algorithms:

```orbit
// Graph coloring via transformation to SAT
graph_coloring(G, k) : GraphColoring ↔ sat_encoding(G, k) : SatisfiabilityProblem;  // Transform to SAT

// Polynomial system solving via transformation to matrix
solve_poly_system(eqs) : PolynomialSystem ↔ macaulay_matrix(eqs) : LinearAlgebra;  // Transform to linear algebra

// Convex optimization via transformation to geometric programming
optimize(f, constraints) : ConvexProblem ↔ geometric_program(f, constraints) : GeometricProgramming;  // Transform to geometric programming
```

These transformations act as "wormholes" between domains, allowing problems to be solved using the most effective techniques from each domain.

## Tabulation-Based Optimizations in Fixed-Size Domains

### Complete Tabulation in Z₈/C₈

For small finite groups like Z₈ (integers modulo 8) or C₈ (cyclic group of order 8), complete tabulation of all operations becomes a practical optimization technique:

```orbit
// Recognize 8-bit integer operations as operations in Z₈
a + b : Int8 ⊢ a + b : Z_8;  // Modular addition
a * b : Int8 ⊢ a * b : Z_8;  // Modular multiplication

// Tabulation-based optimizations for Z₈ operations
a + b : Z_8 → addition_table_lookup(a, b) : Tabulated if use_lookup_tables;  // O(1) lookup
a * b : Z_8 → multiplication_table_lookup(a, b) : Tabulated if use_lookup_tables;  // O(1) lookup

// Precomputed tables (feasible because only 256×256 entries for 8-bit integers)
initialize_tables() → {
	addition_table = [[i + j) % 256 for j in 0..255] for i in 0..255];
	multiplication_table = [[(i * j) % 256 for j in 0..255] for i in 0..255];
};
```

These tabulation optimizations can then be applied automatically whenever operations are recognized as occurring in Z₈/C₈, without the need for explicit algorithm selection.

### Synergy Between Group Theory and Tabulation

The real power emerges when group-theoretic properties are combined with tabulation:

```orbit
// Detect cyclic subgroup structure in tabulated operations
multiply(a, b) : Z_8, is_power_of_2(a) ⊢ multiply(a, b) : CyclicSubgroup;  // Detect power-of-2 subgroups

// This enables additional optimizations
multiply(a, b) : CyclicSubgroup → shift_left(b, log2(a)) : BitShift;  // Replace multiply with shift
divide(b, a) : CyclicSubgroup → shift_right(b, log2(a)) : BitShift;  // Replace divide with shift

// Precomputed log tables for powers of 2
log2_table = [log2(i) for i in powers_of_2(0..255)];
```

This example demonstrates how recognizing group structure in tabulated operations can unlock additional optimizations like replacing multiplications with bit shifts.

### Example: Fast Modular Exponentiation via Table and Group Structure

```orbit
// Traditional approach to modular exponentiation
pow_mod(base, exp, 8) : Z_8 → {
	let result = 1;
	for (i = 0; i < exp; i++)
		result = (result * base) % 8;
	result
};

// With group theory and tabulation
pow_mod(base, exp, 8) : Z_8 → {
	// Detect that Z_8 has order 4 for multiplicative group (elements that have inverses)
	// This means x^4 = x^0 = 1 for any x relatively prime to 8
	let reduced_exp = exp % multiplicative_order(base, 8);

	// Lookup in precomputed power table
	power_table[base][reduced_exp]
} : Optimized;

// Precomputed power tables
power_table = [[pow_mod_naive(base, exp, 8) for exp in 0..3] for base in 0..7];
```

By combining the group-theoretic insight about the order of the multiplicative group with tabulation, we achieve O(1) modular exponentiation for Z₈.

## Core Principles of Algorithm Acceleration

### 1. Algebraic Identity Exploitation

Orbit can saturate the e-graph with algebraic identities, allowing them to be applied wherever relevant:

```orbit
// Adding algebraic identities to the e-graph
a * (b + c) ↔ a * b + a * c : Distributive;  // Bidirectional rule
(x + y)² ↔ x² + 2*x*y + y² : Expansion;  // Expansion identity
(x - y)² ↔ x² - 2*x*y + y² : Expansion;  // Another identity
x² - y² ↔ (x + y) * (x - y) : Factorization;  // Factorization identity
```

These identities can then trigger optimizations in various contexts without requiring explicit pattern matching in each algorithm.

### 2. Domain-Specific Properties

Domain annotations in Orbit automatically enable specialized implementations:

```orbit
// Domain-specific optimizations emerge through annotation
A : UpperTriangularMatrix ⊢ matrix_multiply(A, B) → upper_triangular_multiply(A, B) : Optimized;
A : DiagonalMatrix ⊢ matrix_multiply(A, B) → diagonal_multiply(A, B) : Optimized;
A : SparseMatrix ⊢ matrix_multiply(A, B) → sparse_multiply(A, B) : Optimized;
```

These properties can be either detected automatically or annotated by the user. Once present, they propagate through the computation automatically.

### 3. Divide and Conquer Through Rewrite Saturation

Divide-and-conquer optimizations can emerge naturally from the saturation of basic rewrite rules:

```orbit
// Basic recurrence relation definition
operation(data, n) : Recurrence → base_case(data) if n ≤ threshold;
operation(data, n) : Recurrence → recursive_case(data, n) if n > threshold;

// Divide-and-conquer transformations
operation(data, n) : Recurrence : Splittable →
	combine([operation(subset(data, i), n/k) for i = 0 to k-1]) : Optimized
	if can_divide(operation, data, n, k);
```

The saturation of these rules in the e-graph allows divide-and-conquer patterns to emerge for computations that satisfy the necessary properties.

## Graph-Matrix Transformation Example: PageRank

A powerful example of cross-domain synergy is the computation of PageRank, which can be expressed both as a graph algorithm and as a matrix computation:

```orbit
// PageRank as an iterative graph algorithm
pagerank_graph(G, alpha, iterations) : GraphAlgorithm → {
	// Initialize scores
	let scores = [1/|V| for v in G.vertices];

	// Iterative propagation on graph
	for (i = 0; i < iterations; i++) {
		let new_scores = [0 for v in G.vertices];
		for (v in G.vertices) {
			for (u in G.in_neighbors(v)) {
				new_scores[v] += alpha * scores[u] / G.out_degree(u);
			}
			new_scores[v] += (1 - alpha) / |V|;
		}
		scores = new_scores;
	}

	scores
};

// PageRank as a matrix eigenvector problem
pagerank_matrix(G, alpha) : LinearAlgebra → {
	// Create transition matrix
	let M = transition_matrix(G, alpha);

	// Compute principal eigenvector
	power_iteration(M)
};
```

The key insight is that Orbit can automatically bridge between these representations:

```orbit
// Bridge between graph and matrix representations
pagerank_graph(G, alpha, iterations) : GraphAlgorithm ↔ pagerank_matrix(G, alpha) : LinearAlgebra;

// This enables optimizations from both domains
// From graph domain: exploiting sparsity, parallelizing over vertices
// From matrix domain: using specialized eigenvalue algorithms, exploiting matrix structure

// Specialized case: when graph has specific structure
G : StronglyConnectedComponents ⊢ pagerank_matrix(G, alpha) → block_decomposed_pagerank(G, alpha) : Optimized;
```

By bridging between graph and matrix representations, Orbit can automatically apply optimizations from both domains, potentially discovering algorithms that combine the best aspects of both approaches.

## Linear Algebra Algorithms

### Matrix Multiplication

Strassen's algorithm for matrix multiplication emerges from the saturation of rules for matrix partitioning and algebraic manipulation:

```orbit
// Basic matrix multiplication definition
A * B : Matrix → standard_multiply(A, B) : MatrixProduct;

// Block matrix multiplication rules
partition(A, 2, 2) * partition(B, 2, 2) ↔ block_multiply(A, B) : MatrixProduct;

// Strassen's optimization emerges from algebraic rewriting
block_multiply(A, B) : MatrixProduct : LargeMatrix → {
	// The Strassen identity automatically emerges from algebraic simplifications
	// in the e-graph through rewrite rule saturation
	let [A₁₁, A₁₂, A₂₁, A₂₂] = partition(A, 2, 2);
	let [B₁₁, B₁₂, B₂₁, B₂₂] = partition(B, 2, 2);

	let M₁ = (A₁₁ + A₂₂) * (B₁₁ + B₂₂);
	let M₂ = (A₂₁ + A₂₂) * B₁₁;
	let M₃ = A₁₁ * (B₁₂ - B₂₂);
	let M₄ = A₂₂ * (B₂₁ - B₁₁);
	let M₅ = (A₁₁ + A₁₂) * B₂₂;
	let M₆ = (A₂₁ - A₁₁) * (B₁₁ + B₁₂);
	let M₇ = (A₁₂ - A₂₂) * (B₂₁ + B₂₂);

	let C₁₁ = M₁ + M₄ - M₅ + M₇;
	let C₁₂ = M₃ + M₅;
	let C₂₁ = M₂ + M₄;
	let C₂₂ = M₁ - M₂ + M₃ + M₆;

	combine([C₁₁, C₁₂, C₂₁, C₂₂])
} : Optimized;
```

The key difference in Orbit's approach is that Strassen's algorithm can emerge from rewrite rule saturation rather than being explicitly encoded as a separate algorithm.

### Fast Matrix Inversion

Matrix inversion optimizations emerge from domain-specific properties:

```orbit
// General matrix inversion
inverse(M) : Matrix → general_inverse(M) : Inverse;

// Domain-specific optimizations emerge automatically
M : DiagonalMatrix ⊢ inverse(M) → diagonal_inverse(M) : Optimized;  // O(n) algorithm
M : TriangularMatrix ⊢ inverse(M) → triangular_inverse(M) : Optimized;  // O(n²) algorithm
M : OrthogonalMatrix ⊢ inverse(M) → transpose(M) : Optimized;  // M⁻¹ = Mᵀ
M : ToeplitzMatrix ⊢ inverse(M) → toeplitz_inverse(M) : Optimized;  // Specialized algorithm
```

No explicit decision procedure is needed - the appropriate optimization is triggered automatically when a matrix's domain properties are known.

## Number Theory & Arithmetic Algorithms

### Fast Integer Multiplication

Karatsuba's algorithm emerges from algebraic identities and recursive patterns:

```orbit
// Basic integer multiplication
multiply(a, b) : Integer → standard_multiply(a, b) : Product;

// Algebraic splitting for large integers
multiply(a, b) : Integer : LargeInteger → {
	// Split numbers: a = a₁·10^m + a₀, b = b₁·10^m + b₀
	let m = max(digits(a), digits(b)) / 2;
	let [a₁, a₀] = split_at_digit(a, m);
	let [b₁, b₀] = split_at_digit(b, m);

	// Key Karatsuba identity emerges from algebraic expansion in the e-graph
	let z₀ = multiply(a₀, b₀);  // Low parts
	let z₂ = multiply(a₁, b₁);  // High parts
	let z₁ = multiply(a₁ + a₀, b₁ + b₀) - z₂ - z₀;  // Middle part

	z₂ * 10^(2*m) + z₁ * 10^m + z₀
} : Optimized;
```

The e-graph saturation naturally discovers that computing (a₁+a₀)(b₁+b₀) - a₁b₁ - a₀b₀ requires only 3 multiplications instead of 4, leading to Karatsuba's algorithm.

### Fast Exponentiation

Binary exponentiation emerges from algebraic identities:

```orbit
// Basic exponentiation definition
power(x, n) : AlgebraicOperation → x * power(x, n-1) if n > 0;  // Recursive definition
power(x, 0) : AlgebraicOperation → 1;  // Base case

// These identities lead to binary exponentiation through e-graph saturation
power(x, 2*k) ↔ power(x^2, k) : PowerIdentity;  // Square-and-multiply identity
power(x, 2*k+1) ↔ x * power(x^2, k) : PowerIdentity;  // Odd exponent identity
```

When these rules saturate the e-graph, the binary exponentiation algorithm naturally emerges as the optimal implementation without needing an explicit decision procedure.

## Polynomial Algorithms

### Polynomial Evaluation

Horner's method emerges from algebraic rearrangement:

```orbit
// Basic polynomial evaluation
eval_poly(coeffs, x) : Polynomial → sum([coeffs[i] * x^i for i in 0..n]) : PolynomialValue;

// Algebraic rearrangement leads to Horner's method
coeffs[0] + x * coeffs[1] + x^2 * coeffs[2] + ... + x^n * coeffs[n] ↔
coeffs[0] + x * (coeffs[1] + x * (coeffs[2] + ... + x * coeffs[n]...)) : Horner;
```

The nested form of Horner's method emerges naturally from algebraic rearrangement in the e-graph, reducing from O(n²) to O(n) operations.

### Fast Polynomial Multiplication via FFT

The FFT-based fast polynomial multiplication emerges as a special case of the convolution transformation:

```orbit
// Basic polynomial multiplication (convolution of coefficients)
multiply_poly(p, q) : Polynomial → convolution(p, q) : Product;

// Domain transformation rules
convolution(p, q) : Transform ↔ ifft(fft(p) * fft(q)) : FrequencyDomain;  // Transform to frequency domain
fft(p) : C_n → butterfly_fft(p) : Optimized if is_power_of_2(length(p));  // Apply FFT optimization
```

Through rule saturation, the e-graph discovers that polynomial multiplication can be implemented efficiently through FFT, reducing complexity from O(n²) to O(n log n).

## Specialized Representations for Computation Domains

Another powerful aspect of Orbit's approach is the ability to leverage specialized representations for different computation domains. This enables performance gains by matching the representation to the computation's needs:

```orbit
// Dense vector operations
v + w : DenseVector → dense_vector_add(v, w) : Optimized;
v * w : DenseVector → dense_vector_multiply(v, w) : Optimized;

// Sparse vector operations
v + w : SparseVector → sparse_vector_add(v, w) : Optimized;
v * w : SparseVector → sparse_vector_multiply(v, w) : Optimized;

// Compressed sparse row matrix operations
A * v : CSRMatrix → csr_matrix_vector_multiply(A, v) : Optimized;
```

The insights from one representation can influence optimizations in another:

```orbit
// Bridge between computation domains allows cross-domain learning
A : DenseMatrix, is_mostly_zeros(A) ⊢ convert(A, SparseMatrix) : Optimization;
v : SparseVector, is_mostly_nonzeros(v) ⊢ convert(v, DenseVector) : Optimization;
```

This ability to fluidly move between different representations based on computational properties leads to algorithms that can adapt to the specific characteristics of the input data.

## Fast Transforms and Spectral Methods

### Walsh-Hadamard Transform (WHT)

Fast WHT emerges from the same divide-and-conquer pattern as FFT:

```orbit
// Basic Walsh-Hadamard Transform definition
wht(x) : Transform → [sum([x[j] * (-1)^(bit_count(j&i)) for j in 0..n-1]) for i in 0..n-1] : WHT;

// Pattern for recursive decomposition
wht(x) : Transform : RecursiveSplittable → {
	let n = length(x);
	if n == 1 then
		x
	else {
		let even = x[0:n:2];  // Even indices
		let odd = x[1:n:2];    // Odd indices

		let wht_even = wht(even);
		let wht_odd = wht(odd);

		concat(wht_even + wht_odd, wht_even - wht_odd)
	}
} : Optimized;
```

The saturation of the recursive pattern naturally leads to the emergence of fast WHT algorithm with O(n log n) complexity.

## Matrix Factorization Algorithms

### QR Factorization Specializations

Specialized QR algorithms emerge from matrix structure detection:

```orbit
// Basic QR factorization
qr_factorize(A) : Matrix → householder_qr(A) : QRFactorization;

// Domain-specific optimizations emerge automatically
A : TridiagonalMatrix ⊢ qr_factorize(A) → tridiagonal_qr(A) : Optimized;  // O(n) algorithm
A : BandMatrix ⊢ qr_factorize(A) → band_qr(A) : Optimized;  // Structure-specific algorithm
A : OrthogonalMatrix ⊢ qr_factorize(A) → (A, I) : Optimized;  // Trivial factorization
```

## Numerical Methods

### Differential Equation Solvers

Optimized ODE solvers emerge from system property detection:

```orbit
// Basic ODE solver
solve_ode(system, initial, t_span) : ODE → rk4_method(system, initial, t_span) : Solution;

// Domain-specific optimizations emerge automatically
system : StiffSystem ⊢ solve_ode(system, initial, t_span) → implicit_method(system, initial, t_span) : Optimized;
system : HamiltonianSystem ⊢ solve_ode(system, initial, t_span) → symplectic_integrator(system, initial, t_span) : Optimized;
system : OscillatorySystem ⊢ solve_ode(system, initial, t_span) → oscillatory_solver(system, initial, t_span) : Optimized;
```

### Fast Multipole Method

The Fast Multipole Method emerges from the application of approximation rules to n-body interactions:

```orbit
// Basic n-body interaction computation
compute_interactions(particles) : NBodyProblem → {
	// Direct computation: O(n²)
	[sum([force(particle, other) for other in particles if other != particle]) for particle in particles]
} : DirectComputation;

// Hierarchical approximation rules
compute_interactions(particles) : NBodyProblem : Hierarchical → {
	// Build hierarchical tree
	let tree = build_octree(particles);

	// Apply hierarchical approximation
	[compute_particle_force(particle, tree) for particle in particles]
} : Optimized;

// Rules for approximating distant interactions
force(p, q) : Interaction : DistantInteraction → multipole_approximation(p, q) : Approximated;
```

These rules enable the automatic emergence of O(n) algorithms for n-body simulations instead of the naive O(n²) approach.

## FFT Implementation Variants

Just as in our original FFT case study, different FFT implementations emerge automatically from input properties:

```orbit
// Basic Fourier transform definition
fft(x) : Transform → dft(x) : FourierTransform;  // Start with DFT definition

// The key insight is that all these rules can be applied simultaneously in the e-graph
// Each one fires based on its domain preconditions

// Power of 2 size case: Cooley-Tukey algorithm emerges
x : Transform : PowerOf2 ⊢ fft(x) → cooley_tukey_fft(x) : Optimized;

// Prime size case: Rader's algorithm emerges
x : Transform : PrimeSize ⊢ fft(x) → rader_fft(x) : Optimized;

// Composite number case: Mixed-radix algorithm emerges
x : Transform : CompositeSize ⊢ fft(x) → mixed_radix_fft(x) : Optimized;

// General case: Bluestein's algorithm as fallback
x : Transform ⊢ fft(x) → bluestein_fft(x) : Optimized;
```

The appropriate algorithm emerges automatically based on the properties of the input, without requiring an explicit decision procedure.

## The Power of Saturation-Based Algorithm Discovery

Unlike traditional approaches that explicitly encode algorithm selection logic, Orbit's saturation-based approach offers several advantages:

### 1. Combinatorial Optimization Through Rule Interaction

By saturating the e-graph with all known rewrite rules, unexpected optimization opportunities can emerge from the interaction of multiple rules:

```orbit
// Individual rules that interact in unexpected ways
A * (B + C) ↔ A * B + A * C : Distributive;
A * (B * C) ↔ (A * B) * C : Associative;
A + A ↔ 2 * A : Arithmetic;

// These can combine to discover non-obvious optimizations
// For example, detecting common subexpressions:
// A*B + A*C could transform to A*(B+C), revealing shared computation
```

### 2. Property Propagation Without Explicit Logic

Domain properties automatically propagate through expressions, triggering optimizations without explicit if-then logic:

```orbit
// Define how properties propagate
A : LargeMatrix, B : LargeMatrix ⊢ A * B : LargeMatrix;  // Property propagation
A : SparseMatrix, B : SparseMatrix ⊢ A * B : SparseMatrix;  // Sparsity propagation

// Optimizations then trigger automatically when properties are present
A * B : LargeMatrix → strassen_multiply(A, B) : Optimized;
A * B : SparseMatrix → sparse_multiply(A, B) : Optimized;
```

### 3. Cross-Domain Optimization Opportunities

Saturation allows optimizations to apply across domain boundaries, finding unexpected connections:

```orbit
// Polynomial convolution can use FFT
convolve(p, q) : Polynomial ↔ ifft(fft(p) * fft(q)) : FFTBased;

// String matching can use FFT for certain patterns
pattern_match(text, pattern) : RepeatingPattern → fft_based_match(text, pattern) : Optimized;

// Image processing can use FFT for large convolutions
image_convolve(image, kernel) : LargeKernel → fft_convolution(image, kernel) : Optimized;

// Graph spectral algorithms can use matrix decompositions
graph_spectral_clustering(G) : Graph → svd_clustering(adjacency_matrix(G)) : LinearAlgebra;
```

### 4. Automatic Algorithm Derivation

By saturating the e-graph with mathematical identities and rewrite rules, entirely new algorithms can be derived automatically:

```orbit
// Starting with naive matrix multiplication: O(n³)
matrix_multiply(A, B) → [sum([A[i][k] * B[k][j] for k in 0..n-1]) for i in 0..n-1, j in 0..n-1];

// Through saturation with algebraic identities and recursion patterns
// Strassen's algorithm can emerge: O(n^2.807)
```

This is precisely how Orbit could automatically derive FFT from DFT, Karatsuba from standard multiplication, and potentially discover other algorithmic improvements.

## Conclusion

Orbit's e-graph architecture with canonical forms enables a fundamentally different approach to algorithm optimization. Rather than explicitly encoding decision procedures for algorithm selection, it applies a saturation-based approach where:

1. **All optimization rules are applied simultaneously** in the e-graph
2. **Domain properties are automatically detected and propagated** throughout the computation
3. **Optimal algorithms emerge naturally** from the interaction of rewrite rules
4. **Exponential reductions from e-graphs and canonical forms** make this approach computationally feasible
5. **Cross-domain transformations** enable applying techniques from different mathematical areas
6. **Group-theoretic structures** unlock entire families of optimizations across domains
7. **Representation changes** allow problems to be solved in their most natural domain

This approach has several advantages:

- **Extensibility**: Adding new optimizations is as simple as adding new rewrite rules
- **Composability**: Optimizations naturally compose through e-graph saturation
- **Discoverability**: New algorithms can emerge from the interaction of existing rules
- **Adaptability**: The system automatically adapts to the specific properties of the input data
- **Cross-domain synergy**: Optimizations from different domains can combine in unexpected ways

The ultimate vision is a system where users express their intent in a high-level mathematical language, and Orbit automatically discovers the most efficient implementation based on the specific properties of the problem, potentially discovering novel algorithmic optimizations by bridging between different mathematical domains.