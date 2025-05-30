# Orbit's Approach to Core Matrix Algebra and Multiplication

## Introduction

Matrix algebra forms a computational backbone across a vast spectrum of scientific, engineering, and data-driven domains. Operations ranging from fundamental matrix multiplication to complex tasks like eigendecomposition and inversion present significant opportunities for optimization. This document introduces how **Orbit**, an advanced rewriting system grounded in group theory and domain-specific algebraic reasoning, facilitates the **automatic derivation and optimization of computational strategies for core matrix operations, primarily focusing on matrix multiplication.**

Orbit employs a dynamic, rule-driven methodology:

1.  **Symbolic Representation in E-graphs**: Matrix expressions and operations are represented symbolically within Orbit's e-graph structure.
2.  **Domain-Driven Algebraic Rewriting**: Expressions are annotated with their algebraic domains (e.g., `Matrix<RingElement, N, M>`) and relevant group symmetries. Orbit applies rewrite rules based on fundamental algebraic laws.
3.  **Group-Theoretic Canonicalization**: For structures or operations exhibiting group symmetries, Orbit leverages canonicalization algorithms to transform expressions into unique, often more efficient, forms.
4.  **Emergent Optimized Pathways**: Optimized computational strategies emerge from rule application and canonicalization.

This document lays the groundwork for understanding Orbit's framework for matrix algebra.

## Expressing Matrix Multiplication in Orbit

We start by defining matrix multiplication within Orbit's framework:

```orbit
// Define domains for matrix operations
Matrix<T, N, M> ⊂ Tensor<T, [N, M]> // NxM Matrix over elements of type T
Vector<T, N> ⊂ Matrix<T, N, 1> // Vectors are single-column matrices

// Define standard matrix multiplication C = A * B
(A : Matrix<T, N, M>) * (B : Matrix<T, M, P>) → C : Matrix<T, N, P>
	where C[i, j] = sum(k, 0, M-1, A[i, k] * B[k, j]);

// Assume elements T belong to at least a Semiring (need + and *)
T ⊂ Semiring // Basic requirement
T ⊂ Ring    // Often needed for advanced methods
```
This representation defines the standard algorithm via summations and element access, grounding it in the algebraic properties of the underlying element type `T`.

## The Key Insight 1: Divide-and-Conquer via Block Decomposition

The first major optimization strategy relies on recursively dividing matrices into blocks. This isn't explicitly coded but derived from the algebraic properties of matrix operations (assuming matrix elements form a Ring).

TODO: This is not correct code, but conceptual.

```orbit
// Define matrix blocking operation
block(M : Matrix<T, N, M>, row_splits, col_splits) → BlockedMatrix;

// Define matrix assembly from blocks
assemble_blocks([[M11, M12], [M21, M22]]) → M : Matrix;

// Foundational rewrite: Express multiplication using 2x2 blocks
// This rewrite holds because matrix blocks themselves satisfy Ring axioms.
A : Matrix * B : Matrix !: Blocked
	if can_split_into_blocks(A, B, 2, 2) →
		let [[A11, A12], [A21, A22]] = block(A, [N/2], [M/2]);
		let [[B11, B12], [B21, B22]] = block(B, [M/2], [P/2]);
		assemble_blocks([
			[(A11 * B11) + (A12 * B21), (A11 * B12) + (A12 * B22)],
			[(A21 * B11) + (A22 * B21), (A21 * B12) + (A22 * B22)]
		]) : Blocked;

// Condition for splitting (e.g., even dimensions)
can_split_into_blocks(A : Matrix<T, N, M>, B : Matrix<T, M, P>, r_blocks, c_blocks) →
	eval(N % r_blocks == 0 && M % c_blocks == 0 && P % r_blocks == 0); // Simplified condition
```
This rewrite rule decomposes the N x P multiplication into 8 multiplications of smaller matrices and 4 additions. Applying this rule recursively yields a standard O(N³) divide-and-conquer algorithm.

## The Key Insight 2: Algebraic Rearrangement (Strassen's Algorithm)

Strassen's algorithm improves upon the block decomposition by using a clever set of algebraic identities to compute the result with only 7 recursive multiplications instead of 8. Orbit can discover or apply these identities as specific rewrite rules that exploit the Ring structure.

TODO: This is not correct code, but conceptual.

```orbit
// Strassen's identities as rewrite rules
// Define intermediate matrices M1 to M7 based on sums/differences of blocks
define_strassen_intermediates(A11, A12, A21, A22, B11, B12, B21, B22) : RingOps → {
	M1 = (A11 + A22) * (B11 + B22);
	M2 = (A21 + A22) * B11;
	M3 = A11 * (B12 - B22);
	M4 = A22 * (B21 - B11);
	M5 = (A11 + A12) * B22;
	M6 = (A21 - A11) * (B11 + B12);
	M7 = (A12 - A22) * (B21 + B22);
	{M1, M2, M3, M4, M5, M6, M7}
};

// Rewrite the standard block multiplication result in terms of M1-M7
assemble_blocks_strassen(M1, M2, M3, M4, M5, M6, M7) : RingOps →
	assemble_blocks([
		[M1 + M4 - M5 + M7, M3 + M5],
		[M2 + M4,           M1 - M2 + M3 + M6]
	]);

// Rule that applies Strassen's decomposition if beneficial
A * B : Blocked !: StrassenOptimized
	if is_large_enough_for_strassen(A, B) && element_type_is_ring(T) →
		let [[A11, A12], [A21, A22]] = block(A);
		let [[B11, B12], [B21, B22]] = block(B);
		let {M1..M7} = apply_recursive_multiply(define_strassen_intermediates(A11..A22, B11..B22)); // apply_recursive_multiply conceptually calls the * operator on sub-problems
		assemble_blocks_strassen(M1..M7) : StrassenOptimized;

// Predicate to check if Strassen is worthwhile
is_large_enough_for_strassen(A, B) → eval(size(A) > STRASSEN_THRESHOLD);
element_type_is_ring(T) → inherits(T, Ring);
```
These rewrites replace the standard 8-multiplication block formula with Strassen's 7-multiplication version, improving complexity to O(N^log₂(7)).

## Exploiting Basic Matrix Structures

Orbit can automatically apply further optimizations if matrices possess specific structures.

### Identity Matrix
The identity matrix acts as the multiplicative identity in the matrix ring.
```orbit
// Domain definition
IdentityMatrix<N> ⊂ DiagonalMatrix<Int, N>

// Rule: Multiplication by Identity
(I : IdentityMatrix<N>) * (A : Matrix<T, N, M>) → A;
(A : Matrix<T, N, M>) * (I : IdentityMatrix<M>) → A;
```

### Diagonal Matrices
```orbit
// Domain definition
DiagonalMatrix<T, N> ⊂ Matrix<T, N, N>

// Property: M[i,j] == 0 if i != j

// Rule: Multiplication of diagonal matrices is element-wise O(N)
(A : DiagonalMatrix) * (B : DiagonalMatrix) →
	diag_matrix([A[i,i] * B[i,i] for i = 0 to N-1]) : DiagonalMatrix;

// Rule: Multiplication by a diagonal matrix scales rows or columns
(A : DiagonalMatrix) * (B : Matrix<T, N, P>) →
	matrix([[A[i,i] * B[i,j] for j=0..P-1] for i=0..N-1]); // Row scaling
(A : Matrix<T, N, M>) * (B : DiagonalMatrix) →
	matrix([[A[i,j] * B[j,j] for j=0..M-1] for i=0..N-1]); // Column scaling
```

## Role of Algebraic Structures in Core Operations

The derivation of these algorithms hinges on recognizing and exploiting algebraic structures:
1.  **Semiring/Ring:** The structure of matrix elements `T` allows the definition of matrix addition and multiplication. Ring properties (associativity, distributivity, additive inverse) are key for block decomposition and Strassen's algorithm.
2.  **Ring of Matrices:** N x N matrices (over a Ring T) themselves form a Ring, justifying the block decomposition approach.

Orbit leverages these structures via domain annotations and targeted rewrite rules.

## Overview of Orbit's Unified Selection Strategy

Orbit can implement a sophisticated strategy to select the best algorithm based on detected domains and heuristics. This involves a priority list where specific, cheaper operations (like identity or sparse multiplication) are checked before more general, expensive ones (like Strassen's or standard multiplication).

TODO: This is not correct code, but conceptual.

```orbit
// Conceptual unified matrix multiplication function
multiply(A, B) : MatrixMultiply →
	identity_mult(A, B) : IdentityResult if is_identity(A) || is_identity(B);
	sparse_multiply(A, B) : SparseResult if is_sparse(A) || is_sparse(B); // Assuming is_sparse checks overall sparsity
	diag_mult(A, B) : DiagResult if is_diag(A) || is_diag(B); // Assuming is_diag checks
	perm_mult(A, B) : PermResult if is_perm(A) || is_perm(B); // Assuming is_perm checks
	embed_lookup(A, B) : EmbedResult if is_embed(A) && is_onehot(B); // For ML tasks
	orthogonal_simplify(A, B) : OrthogonalResult if is_orthogonal(A) || is_orthogonal(B); // e.g. A*A^T = I
	circulant_fft_multiply(A, B) : CirculantResult if is_circulant(A) && is_circulant(B) && supports_fft(T);
	toeplitz_fft_multiply(A, B) : ToeplitzResult if is_toeplitz(A) && is_toeplitz(B) && supports_fft(T);
	hankel_fft_multiply(A, B) : HankelResult if is_hankel(A) && is_hankel(B) && supports_fft(T);
	banded_multiply(A, B) : BandedResult if is_banded(A) && is_banded(B);
	triangular_multiply(A, B) : TriangularResult if is_tri(A) && is_tri(B); // is_tri checks if Upper or Lower
	low_rank_multiply(A, B) : LowRankResult if is_low_rank(A) || is_low_rank(B);
	strassen_multiply(A, B) : StrassenResult if use_strassen(A, B) && element_type_is_ring(T);
	recursive_block_multiply(A, B) : RecursiveResult if use_recursive(A, B);
	standard_multiply(A, B) : StandardResult; // Fallback
```
The system applies the most specific, efficient rule based on detected matrix properties and configuration.

## Inferring Commutativity (S₂ Symmetry) for Matrix Multiplication

While matrix multiplication `A * B` is generally non-commutative (i.e., `A * B ≠ B * A`), there are specific, identifiable conditions under which it *does* commute. When Orbit detects these conditions through the domains of the operand matrices, it can infer `S₂` symmetry for that particular `A * B` instance. This allows the system to canonicalize the expression, ensuring that `A * B` and `B * A` are recognized as equivalent and can be represented by a single, ordered form in the O-Graph.

### General Approach

The core idea is to use rules that, upon matching specific patterns of operand domains, assert `S₂` symmetry onto the multiplication operator instance.

```orbit
// General canonicalization rule for any operation instance marked with S₂
op(X, Y) : S₂ → op(sort_args(X, Y))
	if !is_sorted_args(X,Y); // sort_args uses a canonical ordering for X and Y
```
This rule applies generally. The key is to correctly tag the `A * B` instances with `: S₂` using specific entailment rules based on operand domains:

### Specific Conditions and Entailment Rules for S₂ Symmetry

1.  **Identity Matrix:** Multiplication by an identity matrix `I` always commutes.
    
```orbit
	A : Matrix * I : IdentityMatrix |- * : S₂;
	I : IdentityMatrix * A : Matrix |- * : S₂;
	// This implies: A * I ↔ I * A
```

2.  **Zero Matrix:** Multiplication by a zero matrix `Z` (a matrix of all zeros) always commutes.
    
```orbit
	// Assuming ZeroMatrix<T, N, M> ⊂ Matrix<T, N, M> is defined.
	A : Matrix * Z : ZeroMatrix |- * : S₂;
	Z : ZeroMatrix * A : Matrix |- * : S₂;
	// This implies: A * Z ↔ Z * A
```

3.  **Matrix with Itself:** A matrix always commutes with itself.
    
```orbit
	A : Matrix * A : Matrix |- * : S₂;
	// This is notationally consistent, A*A = A*A.
```

4.  **Scalar Matrices:** Any two scalar matrices (of the form `s*I`) commute.
    
```orbit
	// Assuming ScalarMatrix<T, N> ⊂ DiagonalMatrix<T, N> is defined.
	S1 : ScalarMatrix * S2 : ScalarMatrix |- * : S₂;
```

5.  **Diagonal Matrices:** Any two diagonal matrices of the same dimensions commute.
    
```orbit
	D1 : DiagonalMatrix * D2 : DiagonalMatrix |- * : S₂;
```

6.  **Circulant Matrices:** Any two N×N circulant matrices commute.
    
```orbit
	// Assuming CirculantMatrix<T, N> is defined.
	C1 : CirculantMatrix * C2 : CirculantMatrix |- * : S₂;
```

7.  **Polynomials in the Same Matrix:** If matrix `B` is a polynomial expression in matrix `A` (e.g., `B = c₂A² + c₁A + c₀I`), then `A` and `B` commute.
    
```orbit
	// Assuming a domain PolynomialInMatrix(A) signifies B is such a polynomial in A.
	A : Matrix * B : PolynomialInMatrix(A) |- * : S₂;
	B : PolynomialInMatrix(A) * A : Matrix |- * : S₂;
```

### Benefits in Orbit

Inferring `S₂` symmetry for specific matrix multiplication instances provides significant advantages:

*   **Canonicalization:** `A * B` and `B * A` (where commutative) map to a single O-Graph node.
*   **Simplified Equivalence:** Makes equivalence checks straightforward.
*   **Reduced Rule Complexity:** Rewrite rules involving commutative matrix products only need to match one operand order.
*   **Enhanced Pattern Matching:** Allows patterns to match regardless of operand order in commutative cases.

## Further Exploration

This document provides a foundational view of Orbit's capabilities in matrix algebra. For more detailed information on specific areas, please refer to the following:

*   For a deep dive into how Orbit leverages a wide variety of **specialized matrix structures** (e.g., Sparse, Circulant, Orthogonal, Low-Rank) for optimization, see [`matrix2.md`](./matrix2.md).
*   To understand how Orbit can symbolically derive and utilize common **matrix decompositions and factorizations** (e.g., LU, Cholesky, QR, SVD), refer to [`matrix3.md`](./matrix3.md).
*   For **advanced analytical topics** including a more thorough treatment of matrix trace, determinant, eigen-problems, matrix functions, and an introduction to Lie theory in the context of matrices, consult [`matrix4.md`](./matrix4.md).
*   Focus on 2d and 3d **geometric transformations** (e.g., rotation, scaling, shearing) and their matrix representations in the context of Orbit's algebraic framework can be found in [`matrix5.md`](./matrix5.md).
