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
Matrix<T, N, M> ⊂ Tensor // NxM Matrix over elements of type T
MatrixMultiply ⊂ LinearOperation
ElementwiseOp ⊂ Operation
Vector<T, N> ⊂ Matrix<T, N, 1> // Vectors are single-column matrices

// Define standard matrix multiplication C = A * B
matrix_multiply(A : Matrix<T, N, M>, B : Matrix<T, M, P>) : MatrixMultiply → C : Matrix<T, N, P>
	where C[i, j] = sum(k, 0, M-1, A[i, k] * B[k, j]);

// Element access
get_element(M : Matrix<T, N, M>, i, j) → M[i, j] : T;


// Row/Column sums (useful for some matrix properties)
row_sum(M : Matrix<T, N, M>, i) → sum(j, 0, M-1, M[i, j]);
col_sum(M : Matrix<T, N, M>, j) → sum(i, 0, N-1, M[i, j]);

// Summation definition (inherits properties like associativity/commutativity if T allows)
sum(k, start, end, expr(k)) : Summation; // Properties depend on '+' for type T

// Assume elements T belong to at least a Semiring (need + and *)
T ⊂ Semiring // Basic requirement
T ⊂ Ring    // Often needed for advanced methods
```
This representation defines the standard algorithm via summations and element access, grounding it in the algebraic properties of the underlying element type `T`.

## The Key Insight 1: Divide-and-Conquer via Block Decomposition

The first major optimization strategy relies on recursively dividing matrices into blocks. This isn't explicitly coded but derived from the algebraic properties of matrix operations (assuming matrix elements form a Ring).

```orbit
// Define matrix blocking operation
block(M : Matrix<T, N, M>, row_splits, col_splits) → BlockedMatrix;

// Define matrix assembly from blocks
assemble_blocks([[M11, M12], [M21, M22]]) → M : Matrix;

// Foundational rewrite: Express multiplication using 2x2 blocks
// This rewrite holds because matrix blocks themselves satisfy Ring axioms.
matrix_multiply(A, B) : MatrixMultiply !: Blocked
	if can_split_into_blocks(A, B, 2, 2) →
		let [[A11, A12], [A21, A22]] = block(A, [N/2], [M/2]);
		let [[B11, B12], [B21, B22]] = block(B, [M/2], [P/2]);
		assemble_blocks([
			[matrix_multiply(A11, B11) + matrix_multiply(A12, B21), matrix_multiply(A11, B12) + matrix_multiply(A12, B22)],
			[matrix_multiply(A21, B11) + matrix_multiply(A22, B21), matrix_multiply(A21, B12) + matrix_multiply(A22, B22)]
		]) : Blocked;

// Condition for splitting (e.g., even dimensions)
can_split_into_blocks(A : Matrix<T, N, M>, B : Matrix<T, M, P>, r_blocks, c_blocks) →
	eval(N % r_blocks == 0 && M % c_blocks == 0 && P % r_blocks == 0); // Simplified condition
```
This rewrite rule decomposes the N x P multiplication into 8 multiplications of smaller matrices and 4 additions. Applying this rule recursively yields a standard O(N³) divide-and-conquer algorithm.

## The Key Insight 2: Algebraic Rearrangement (Strassen's Algorithm)

Strassen's algorithm improves upon the block decomposition by using a clever set of algebraic identities to compute the result with only 7 recursive multiplications instead of 8. Orbit can discover or apply these identities as specific rewrite rules that exploit the Ring structure.

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
matrix_multiply(A, B) : Blocked !: StrassenOptimized
	if is_large_enough_for_strassen(A, B) && element_type_is_ring(T) →
		let [[A11, A12], [A21, A22]] = block(A);
		let [[B11, B12], [B21, B22]] = block(B);
		let {M1..M7} = apply_recursive_multiply(define_strassen_intermediates(A11..A22, B11..B22)); // apply_recursive_multiply conceptually calls matrix_multiply on sub-problems
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
matrix_multiply(I : IdentityMatrix<N>, A : Matrix<T, N, M>) → A;
matrix_multiply(A : Matrix<T, N, M>, I : IdentityMatrix<M>) → A;
```

### Diagonal Matrices
```orbit
// Domain definition
DiagonalMatrix<T, N> ⊂ Matrix<T, N, N>

// Property: M[i,j] == 0 if i != j

// Rule: Multiplication of diagonal matrices is element-wise O(N)
matrix_multiply(A : DiagonalMatrix, B : DiagonalMatrix) : MatrixMultiply →
	diag_matrix([A[i,i] * B[i,i] for i = 0 to N-1]) : DiagonalMatrix;

// Rule: Multiplication by a diagonal matrix scales rows or columns
matrix_multiply(A : DiagonalMatrix, B : Matrix<T, N, P>) →
	matrix([[A[i,i] * B[i,j] for j=0..P-1] for i=0..N-1]); // Row scaling
matrix_multiply(A : Matrix<T, N, M>, B : DiagonalMatrix) →
	matrix([[A[i,j] * B[j,j] for j=0..M-1] for i=0..N-1]); // Column scaling
```

## Role of Algebraic Structures in Core Operations

The derivation of these algorithms hinges on recognizing and exploiting algebraic structures:
1.  **Semiring/Ring:** The structure of matrix elements `T` allows the definition of matrix addition and multiplication. Ring properties (associativity, distributivity, additive inverse) are key for block decomposition and Strassen's algorithm.
2.  **Ring of Matrices:** N x N matrices (over a Ring T) themselves form a Ring, justifying the block decomposition approach.

Orbit leverages these structures via domain annotations and targeted rewrite rules.

## Overview of Orbit's Unified Selection Strategy

Orbit can implement a sophisticated strategy to select the best algorithm based on detected domains and heuristics. This involves a priority list where specific, cheaper operations (like identity or sparse multiplication) are checked before more general, expensive ones (like Strassen's or standard multiplication).

```orbit
// Conceptual unified matrix multiplication function (simplified from matrix.md)
multiply(A, B) : MatrixMultiply →
	identity_mult(A, B) : IdentityResult if is_identity(A) || is_identity(B);
	sparse_multiply(A, B) : SparseResult if is_sparse(A) || is_sparse(B); // Assuming is_sparse checks overall sparsity
	diag_mult(A, B) : DiagResult if is_diag(A) || is_diag(B); // Assuming is_diag checks
	perm_mult(A, B) : PermResult if is_perm(A) || is_perm(B); // Assuming is_perm checks
	embed_lookup(A, B) : EmbedResult if is_embed(A) && is_onehot(B); // For ML tasks
	orthogonal_simplify(A, B) : OrthogonalResult if is_orthogonal(A) || is_orthogonal(B); // e.g. A*A^T = I
	circulant_fft_multiply(A, B) : CirculantResult if is_circulant(A) && is_circulant(B) && supports_fft(T);
	toeplitz_fft_multiply(A, B) : ToeplitzResult if is_toeplitz(A) && is_toeplitz(B) && supports_fft(T);

## Automatic Discovery of Algebraic Identities

Just as Orbit can explore identities in cyclic groups for FFT, it could systematically explore algebraic manipulations within the Matrix Ring structure to discover Strassen-like algorithms.

```orbit
// Conceptual exploration process for block multiplication
DiscoverMatrixIdentities(matrix_multiply(A, B) : Blocked) : Analysis → {
	// Represent the 8 block multiplications symbolically
	let standard_ops = [A11*B11, A12*B21, ..., A22*B22]; // 8 symbolic products
	let target_blocks = [C11, C12, C21, C22]; // Target expressions

	// Try combinations of sums/differences of A blocks and B blocks
	// Search for a set of k < 8 products (P1...Pk) such that
	// each target block Ci,j can be expressed as a linear combination of P1...Pk.
	find_linear_combinations(input_blocks=[Aij, Bij], target_exprs=[Cij], num_products=7)
	// This is related to finding the TENSOR RANK of the matrix multiplication tensor.
};
```
While computationally expensive, this suggests how Orbit could potentially *derive* Strassen's identities from first principles by searching for ways to compute the block results using fewer multiplications, guided by the laws of Ring algebra.

	hankel_fft_multiply(A, B) : HankelResult if is_hankel(A) && is_hankel(B) && supports_fft(T);
	banded_multiply(A, B) : BandedResult if is_banded(A) && is_banded(B);
	triangular_multiply(A, B) : TriangularResult if is_tri(A) && is_tri(B); // is_tri checks if Upper or Lower
	low_rank_multiply(A, B) : LowRankResult if is_low_rank(A) || is_low_rank(B);
	strassen_multiply(A, B) : StrassenResult if use_strassen(A, B) && element_type_is_ring(T);
	recursive_block_multiply(A, B) : RecursiveResult if use_recursive(A, B);
	standard_multiply(A, B) : StandardResult; // Fallback
```
The system applies the most specific, efficient rule based on detected matrix properties and configuration.

## Foundational Matrix Analytics: Trace, Determinant, and Eigenvalues

These fundamental concepts are crucial in linear algebra. Orbit uses their properties for simplification and canonicalization.

### Matrix Trace
The **trace** `tr(M)` of a square matrix `M` is the sum of its diagonal elements.
Key properties Orbit can use:
*   **Linearity:** `tr(A + B) = tr(A) + tr(B)`, `tr(c * A) = c * tr(A)`.
*   **Cyclic Property:** `tr(A * B) = tr(B * A)`. This extends to `tr(A * B * C) = tr(B * C * A) = tr(C * A * B)`, indicating `Cₖ` symmetry for the product arguments within the trace. Orbit can use this to canonicalize the order of matrices under a trace.
*   **Transpose Invariance:** `tr(M) = tr(Mᵀ)`.
*   **Similarity Invariance:** `tr(P⁻¹ * A * P) = tr(A)`. Orbit uses this to simplify such expressions to `tr(A)`, a canonical form.

### Matrix Determinant
The **determinant** `det(M)` of a square matrix `M` is a scalar encoding properties like invertibility and volume scaling.
Key properties Orbit can use:
*   `det(I) = 1`.
*   **Multiplicative Property:** `det(A * B) = det(A) * det(B)`. Orbit uses this to break down complex determinants or simplify products.
*   **Transpose Invariance:** `det(Mᵀ) = det(M)`.
*   **Scalar Multiplication:** `det(c * A) = c^N * det(A)`.
*   **Inverse:** `det(A⁻¹) = 1 / det(A)`.
*   **Singular/Triangular:** `det(Singular) = 0`, `det(Triangular) = product of diagonals`.
*   **Similarity Invariance:** `det(P⁻¹ * A * P) = det(A)`. Orbit uses this for simplification and canonicalization.

### Eigenvalues and Eigenvectors
For a square matrix `A`, `v` is an eigenvector and `λ` its eigenvalue if `A v = λ v`. This leads to the characteristic equation `det(A - λI) = 0`.
Key properties Orbit can use:
*   The sum of eigenvalues is `tr(A)`; their product is `det(A)`.
*   **Similarity Invariance:** Similar matrices (`B = P⁻¹AP`) have the same eigenvalues. Orbit uses this to ensure that `eigenvalues(A)` and `eigenvalues(B)` unify to the same canonical set.
*   Eigenvalues of triangular/diagonal matrices are their diagonal entries.

Detailed exploration of Trace, Determinant, and Eigen-problems, including their applications and advanced canonicalization strategies in Orbit, can be found in [`matrix4.md`](./matrix4.md).

## Further Exploration

This document provides a foundational view of Orbit's capabilities in matrix algebra. For more detailed information on specific areas, please refer to the following:

*   For a deep dive into how Orbit leverages a wide variety of **specialized matrix structures** (e.g., Sparse, Circulant, Orthogonal, Low-Rank) for optimization, see [`matrix2.md`](./matrix2.md).
*   To understand how Orbit can symbolically derive and utilize common **matrix decompositions and factorizations** (e.g., LU, Cholesky, QR, SVD), refer to [`matrix3.md`](./matrix3.md).
*   For **advanced analytical topics** including a more thorough treatment of matrix trace, determinant, eigen-problems, matrix functions, and an introduction to Lie theory in the context of matrices, consult [`matrix4.md`](./matrix4.md).

## Conclusion

Orbit's approach to matrix algebra, centered on algebraic rewriting, domain knowledge, and group-theoretic canonicalization, allows for the automatic derivation and optimization of various matrix computation strategies. By representing operations symbolically and applying rules based on underlying mathematical structures, Orbit can transform standard definitions into more efficient computational pathways, mirroring how advanced algorithms like Strassen's method or FFT-based techniques are discovered and applied. This foundational document sets the stage for exploring more specialized and advanced matrix operations within the Orbit framework.
