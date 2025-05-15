# Automatic Derivation and Optimization of Matrix Computations via Orbit's Algebraic Rewriting and Group-Theoretic Canonicalization

## Introduction

Matrix algebra forms a computational backbone across a vast spectrum of scientific, engineering, and data-driven domains. Operations ranging from fundamental matrix multiplication to complex tasks like eigendecomposition, inversion, and the evaluation of matrix functions (e.g., trace, determinant) present significant opportunities for optimization. This document introduces how **Orbit**, an advanced rewriting system grounded in group theory and domain-specific algebraic reasoning, facilitates the **automatic derivation and optimization of computational strategies for a wide array of matrix operations.**

We primarily illustrate this capability through the lens of matrix multiplication—a classic area for algorithmic enhancement. Similar to how the Fast Fourier Transform (FFT) emerges from exploiting the Cₙ cyclic group structure inherent in the Discrete Fourier Transform (DFT), Orbit aims to uncover optimized computational pathways for matrix problems. Instead of relying on a static library of pre-defined algorithms for each matrix task, Orbit employs a dynamic, rule-driven methodology:

1.  **Symbolic Representation in E-graphs**: Matrix expressions and operations are represented symbolically within Orbit's e-graph structure, allowing for flexible manipulation and equivalence exploration.
2.  **Domain-Driven Algebraic Rewriting**: Expressions are annotated with their algebraic domains (e.g., `Matrix<RingElement, N, M>`, `:CirculantMatrix`, `:SymmetricMatrix`, `:PositiveDefinite`) and relevant group symmetries (`:S₂`, `:Cₙ`, `:GL_n_Invariant`). Orbit then applies a rich set of rewrite rules based on fundamental algebraic laws (associativity, distributivity, properties of inverses, etc.) and the specific characteristics of these domains.
3.  **Group-Theoretic Canonicalization**: For matrix structures or operations exhibiting inherent group symmetries (such as circulant matrices embodying Cₙ symmetry, or products within a `tr(...)` operation having Cₖ symmetry), Orbit leverages its group canonicalization algorithms. This transforms expressions into unique, often more computationally efficient, canonical forms.
4.  **Emergent Optimized Pathways**: Through this systematic process, optimized computational strategies—be it Strassen's method for dense matrix multiplication, FFT-based approaches for structured matrices, or simplified expressions for trace and determinant calculations—emerge as the result of rule application and canonicalization, rather than being explicitly pre-programmed for every scenario.

While matrix multiplication serves as a compelling example of deriving complexity improvements, this document lays the groundwork for understanding how Orbit's framework can be extended to other critical matrix computations. The principles of recognizing algebraic structure, applying domain-specific rewrite rules, and exploiting group symmetries for canonicalization provide a unified approach to optimizing a broad class of matrix problems. This moves beyond traditional, hardcoded algorithmic choices towards a more adaptive and mathematically principled system for symbolic computation and optimization in matrix algebra.

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

// Summation definition (inherits properties like associativity/commutativity if T allows)
sum(k, start, end, expr(k)) : Summation; // Properties depend on '+' for type T

// Row/Column sums
row_sum(M : Matrix<T, N, M>, i) → sum(j, 0, M-1, M[i, j]);
col_sum(M : Matrix<T, N, M>, j) → sum(i, 0, N-1, M[i, j]);

// Assume elements T belong to at least a Semiring (need + and *)
// For Strassen etc., we often need a Ring (needs additive inverse '-')
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

This rewrite rule decomposes the N x P multiplication into 8 multiplications of smaller matrices and 4 additions. Applying this rule recursively yields a standard O(N³) divide-and-conquer algorithm (assuming N=M=P). The crucial point is that this structure emerges from the Ring properties of matrix operations, not specific coding.

## The Key Insight 2: Algebraic Rearrangement (Strassen's Algorithm)

Strassen's algorithm improves upon the block decomposition by using a clever set of algebraic identities to compute the result with only 7 recursive multiplications instead of 8. Orbit can discover or apply these identities as specific rewrite rules that exploit the Ring structure (associativity, distributivity, additive inverse).

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

// Rule that applies Strassen's decomposition if beneficial (e.g., large matrices)
matrix_multiply(A, B) : Blocked !: StrassenOptimized
	if is_large_enough_for_strassen(A, B) && element_type_is_ring(T) →
		let [[A11, A12], [A21, A22]] = block(A);
		let [[B11, B12], [B21, B22]] = block(B);
		// Apply multiply recursively to compute M1..M7
		let {M1..M7} = apply_recursive_multiply(define_strassen_intermediates(A11..A22, B11..B22));
		assemble_blocks_strassen(M1..M7) : StrassenOptimized;

// Predicate to check if Strassen is worthwhile (depends on N and hardware)
is_large_enough_for_strassen(A, B) → eval(size(A) > STRASSEN_THRESHOLD);
element_type_is_ring(T) → inherits(T, Ring); // Check if T supports subtraction
```

These rewrites replace the standard 8-multiplication block formula with Strassen's 7-multiplication version. Orbit selects this path based on conditions like matrix size and the element type supporting Ring operations (specifically, subtraction). The complexity improves to O(N^log₂(7)) ≈ O(N^2.81).

## Exploiting Special Matrix Structures

Orbit can automatically apply further optimizations if matrices possess specific structures by recognizing these structures via domain annotations and applying specialized rewrite rules.

### Identity Matrix

The identity matrix acts as the multiplicative identity in the matrix ring.

```orbit
// Domain definition
IdentityMatrix<N> ⊂ DiagonalMatrix<Int, N> // Typically {0, 1} elements
// Property: I[i,i] == 1, I[i,j] == 0 if i != j

// Rule: Multiplication by Identity is a no-op O(1) conceptually, or O(N*M) if copy needed
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

// Rule: Multiplication by a diagonal matrix scales rows or columns O(N*P or N*M)
matrix_multiply(A : DiagonalMatrix, B : Matrix<T, N, P>) →
	matrix([[A[i,i] * B[i,j] for j=0..P-1] for i=0..N-1]); // Row scaling
matrix_multiply(A : Matrix<T, N, M>, B : DiagonalMatrix) →
	matrix([[A[i,j] * B[j,j] for j=0..M-1] for i=0..N-1]); // Column scaling
```

### Permutation Matrices

Permutation matrices represent permutations, forming a structure isomorphic to the Symmetric Group S_N.

```orbit
// Domain definition
PermutationMatrix<N> ⊂ Matrix<Int, N, N> // Typically {0, 1} elements
// Property: Exactly one '1' per row and column, rest '0'.

// Rule: Multiplication corresponds to permutation composition (S_N action) O(N)
matrix_multiply(P1 : PermutationMatrix, P2 : PermutationMatrix) : S_N →
	permutation_matrix(compose_permutations(permutation(P1), permutation(P2))) : PermutationMatrix;

// Rule: Multiplication applies permutation to rows/columns O(N*M or N*P)
matrix_multiply(P : PermutationMatrix, A : Matrix<T, N, M>) → permute_rows(A, permutation(P));
matrix_multiply(A : Matrix<T, N, M>, P : PermutationMatrix<M>) → permute_columns(A, permutation(P));
```

### Symmetric / Hermitian Matrices

Symmetric (A = Aᵀ) and Hermitian (A = Aᴴ) matrices have reflective symmetry across the diagonal.

```orbit
// Domain definitions
SymmetricMatrix<T, N> ⊂ Matrix<T, N, N> // For real or general fields
HermitianMatrix<T, N> ⊂ Matrix<T, N, N> // For complex fields (T ⊂ Complex)

// Properties
// Symmetric: A[i,j] == A[j,i]
// Hermitian: A[i,j] == conjugate(A[j,i])

// Rule: Exploit symmetry in storage (store only half) - affects access cost
// Rule: Preserve symmetry/Hermitian property under certain operations
// Example: A, B symmetric => A+B symmetric
add(A : SymmetricMatrix, B : SymmetricMatrix) → add(A, B) : SymmetricMatrix;
// Example: A symmetric => Pᵀ*A*P symmetric for any P
matrix_multiply(transpose(P), matrix_multiply(A : SymmetricMatrix, P)) : SymmetricMatrix;
// Example: A Hermitian => A is normal (A*Aᴴ = Aᴴ*A)
multiply(A: HermitianMatrix, conjugate_transpose(A)) ↔ multiply(conjugate_transpose(A), A: HermitianMatrix);

// Note: Multiplication A*B doesn't preserve symmetry unless A,B commute.
// Specialized algorithms (e.g., for Eigen decomposition) leverage this structure.
```

### Skew-Symmetric / Skew-Hermitian Matrices

These matrices have anti-symmetry across the diagonal.

```orbit
// Domain definitions
SkewSymmetricMatrix<T, N> ⊂ Matrix<T, N, N>
SkewHermitianMatrix<T, N> ⊂ Matrix<T, N, N>

// Properties
// SkewSymmetric: A[i,j] == -A[j,i], A[i,i] == 0
// SkewHermitian: A[i,j] == -conjugate(A[j,i]), A[i,i] is purely imaginary or zero

// Rule: Preserve skew property under addition/scaling
add(A : SkewSymmetricMatrix, B : SkewSymmetricMatrix) → add(A, B) : SkewSymmetricMatrix;
scale(c : Real, A : SkewSymmetricMatrix) → scale(c, A) : SkewSymmetricMatrix;

// Note: Eigenvalues are purely imaginary or zero. Used in Lie algebras.
```

### Orthogonal / Unitary Matrices

These matrices represent rotations/reflections, preserving vector norms (length). Their inverse is their transpose/conjugate transpose.

```orbit
// Domain definitions
OrthogonalMatrix<T, N> ⊂ Matrix<T, N, N> // T ⊂ Real, Aᵀ*A = A*Aᵀ = I
UnitaryMatrix<T, N> ⊂ Matrix<T, N, N>   // T ⊂ Complex, Aᴴ*A = A*Aᴴ = I

// Properties (equivalent definitions)
// Orthogonal: transpose(A) == inverse(A)
// Unitary: conjugate_transpose(A) == inverse(A)

// Rule: Product of orthogonal/unitary matrices is orthogonal/unitary
matrix_multiply(A : OrthogonalMatrix, B : OrthogonalMatrix) → matrix_multiply(A, B) : OrthogonalMatrix;
matrix_multiply(A : UnitaryMatrix, B : UnitaryMatrix) → matrix_multiply(A, B) : UnitaryMatrix;

// Rule: Multiplication simplifies using inverse property
matrix_multiply(transpose(A : OrthogonalMatrix), A) → IdentityMatrix<N>;
matrix_multiply(A, transpose(A : OrthogonalMatrix)) → IdentityMatrix<N>;
matrix_multiply(conjugate_transpose(A : UnitaryMatrix), A) → IdentityMatrix<N>;
matrix_multiply(A, conjugate_transpose(A : UnitaryMatrix)) → IdentityMatrix<N>;

// Rule: Multiplication preserves norm (||Ax|| = ||x||) - may simplify downstream analysis
norm(matrix_multiply(A : OrthogonalMatrix, x : Vector)) → norm(x);
```

### Triangular Matrices (Upper and Lower)

Triangular matrices are common in linear algebra solvers (e.g., LU decomposition).

```orbit
// Domain definitions
UpperTriangularMatrix<T, N> ⊂ Matrix<T, N, N>
LowerTriangularMatrix<T, N> ⊂ Matrix<T, N, N>

// Properties
// Upper: M[i,j] == 0 if i > j
// Lower: M[i,j] == 0 if i < j

// Rule: Product of same-type triangular matrices is triangular O(N³) standard, but with reduced loop bounds
// Example for Upper * Upper: C[i, j] = sum(k=i to j, A[i, k] * B[k, j])
matrix_multiply(A : UpperTriangularMatrix, B : UpperTriangularMatrix) : MatrixMultiply →
	compute_triangular_product(A, B, "upper") : UpperTriangularMatrix;

matrix_multiply(A : LowerTriangularMatrix, B : LowerTriangularMatrix) : MatrixMultiply →
	compute_triangular_product(A, B, "lower") : LowerTriangularMatrix;

// Rule: Multiplication by a general matrix (example: Upper * General)
// Result is general, but computation has reduced loops
// C[i, j] = sum(k=i to N-1, A[i, k] * B[k, j])
matrix_multiply(A : UpperTriangularMatrix, B : Matrix<T, N, P>) →
	compute_triangular_general_product(A, B, "upper");

matrix_multiply(A : Matrix<T, N, M>, B : LowerTriangularMatrix<M>) →
	compute_general_triangular_product(A, B, "lower");

// Note: Solving Ax=b is O(N²) for triangular A (forward/backward substitution)
// This isn't multiplication, but a related optimization Orbit could represent.
solve_linear_system(A : UpperTriangularMatrix, b : Vector) → backward_substitution(A, b);
solve_linear_system(A : LowerTriangularMatrix, b : Vector) → forward_substitution(A, b);
```

### Banded Matrices

These matrices have non-zero elements confined to a band around the main diagonal.

```orbit
// Domain definition
BandedMatrix<T, N, L, U> ⊂ Matrix<T, N, N> // L=lower bandwidth, U=upper bandwidth

// Property: A[i,j] == 0 if j < i - L or j > i + U

// Subtypes:
TridiagonalMatrix<T, N> ⊂ BandedMatrix<T, N, 1, 1>
PentadiagonalMatrix<T, N> ⊂ BandedMatrix<T, N, 2, 2>

// Rule: Multiplication has reduced loop bounds O(N * (L+U+1) * min(N, L'+U'+1))
// Result bandwidth adds up: L_res = L+L', U_res = U+U'
matrix_multiply(A : BandedMatrix<_, N, L, U>, B : BandedMatrix<_, N, L', U'>) →
	compute_banded_product(A, B) : BandedMatrix<_, N, L+L', U+U'>;

// Rule: Specialized O(N) algorithms for solving tridiagonal systems (Thomas algorithm)
solve_linear_system(A : TridiagonalMatrix, b : Vector) → thomas_algorithm(A, b);
```

### Circulant Matrices

Circulant matrices have a structure related to the Cyclic Group C_N and polynomial multiplication modulo x^N - 1. Their multiplication is equivalent to circular convolution, often accelerated by FFT.

```orbit
// Domain definition
CirculantMatrix<T, N> ⊂ Matrix<T, N, N>
// Property: C[i, j] = c[(j - i) mod N] (depends only on j-i mod N)

// Rule: Multiplication is circular convolution of the generating vectors O(N log N) via FFT
matrix_multiply(C1 : CirculantMatrix, C2 : CirculantMatrix) : C_N !: ViaFFT →
	circulant_matrix(circular_convolution(vector(C1), vector(C2))) : CirculantMatrix;

// Rule: Connect circular convolution to FFT (if T supports it)
circular_convolution(a, b) : Convolution →
	ifft(fft(a) * fft(b)) : ViaFFT // '*' is element-wise product
	if supports_fft(T);

// Rule: Multiplication of Circulant matrix by vector via FFT O(N log N)
matrix_multiply(C : CirculantMatrix, x : Vector) : C_N !: ViaFFT →
	ifft(fft(vector(C)) * fft(x)) : Vector : ViaFFT
	if supports_fft(T);
```

### Toeplitz Matrices

Toeplitz matrices (constant diagonals) can be multiplied efficiently, often by embedding them into larger Circulant matrices.

```orbit
// Domain definition
ToeplitzMatrix<T, N> ⊂ Matrix<T, N, N>
// Property: T[i, j] = t[j - i] (depends only on j-i)

// Rule: Embed Toeplitz into Circulant for multiplication O(N log N)
matrix_multiply(T1 : ToeplitzMatrix, T2 : ToeplitzMatrix) : MatrixMultiply !: ViaCirculant →
	let N_embed = choose_embedding_size(N); // e.g., >= 2*N-1, often power of 2
	let C1 = embed_toeplitz_in_circulant(T1, N_embed);
	let C2 = embed_toeplitz_in_circulant(T2, N_embed);
	let C_result = matrix_multiply(C1, C2); // Uses Circulant multiplication (FFT)
	extract_result_from_circulant(C_result, N) : ToeplitzProduct : ViaCirculant;
```

### Hankel Matrices

Hankel matrices have constant skew-diagonals (constant `i+j`). They are related to Toeplitz matrices via permutation.

```orbit
// Domain definition
HankelMatrix<T, N> ⊂ Matrix<T, N, N>
// Property: H[i, j] = h[i + j] (depends only on i+j)

// Rule: Convert to Toeplitz via permutation matrix J (anti-diagonal 1s)
// H = J * T or H = T * J where T is Toeplitz
hankel_matrix(h) : HankelMatrix → matrix_multiply(J, toeplitz_matrix(t_from_h(h)));
hankel_matrix(h) : HankelMatrix → matrix_multiply(toeplitz_matrix(t'_from_h(h)), J);

// Rule: Multiplication via conversion to Toeplitz/Circulant/FFT O(N log N)
matrix_multiply(H1 : HankelMatrix, H2 : HankelMatrix) : MatrixMultiply !: ViaToeplitz →
	let T1 = to_toeplitz(H1); // Convert H1 to corresponding Toeplitz T1
	let T2 = to_toeplitz(H2); // Convert H2 to corresponding Toeplitz T2
	let T_result = matrix_multiply(T1, T2); // Use Toeplitz multiply (FFT)
	from_toeplitz(T_result) : HankelProduct : ViaToeplitz; // Convert result back

// Fast Hankel-vector product algorithms exist O(N log N)
matrix_multiply(H : HankelMatrix, x : Vector) → fast_hankel_vector_product(H, x);
```

### Sparse Matrices

Sparsity patterns (many zero elements) allow skipping multiplications involving zero. The best algorithm depends on the sparse format (CSR, CSC, COO, etc.) and the sparsity patterns of both matrices.

```orbit
// Domain definition (conceptual)
SparseMatrix<T, N, M, Format> ⊂ Matrix<T, N, M>
// Example Formats: CSR, CSC, COO

// Rule: Generic skip of zero multiplications in the definition
// C[i, j] = sum(k where A[i,k]!=0 && B[k,j]!=0, A[i, k] * B[k, j])
// This is more effectively handled by format-specific algorithms.

// Rule: Use format-specific algorithms (complexity varies, often O(N + M + nnz_result))
matrix_multiply(A : SparseMatrix<CSR>, B : SparseMatrix<CSC>) →
	sparse_multiply_csr_csc(A, B) : SparseMatrix<ResultFormat>; // Specialized

matrix_multiply(A : SparseMatrix<COO>, x : Vector) →
	sparse_multiply_coo_vector(A, x) : Vector;
```

### Low-Rank Matrices (Rank-Deficient)

Matrices common in ML (e.g., embeddings, matrix factorization) can often be represented or approximated as the product of two tall/thin matrices (`M = U * Vᵀ`).

```orbit
// Domain definition
LowRankMatrix<T, N, M, K> ⊂ Matrix<T, N, M>
// Property: M = U * Vᵀ where U is N x K, V is M x K, and K << N, M (rank K)

// Represent explicitly as factors
low_rank(U : Matrix<T, N, K>, V : Matrix<T, M, K>) → M : LowRankMatrix<T, N, M, K>;

// Rule: Optimize multiplication using associativity O(NKP + MKP) or O(NKM + NkM)
// Choose based on dimensions N, M, P, K. Complexity is O(max(NKP, MKP)) or O(max(NKM, NKM)).
matrix_multiply(A : LowRankMatrix<_, N, M, K>, B : Matrix<T, M, P>) →
	let {U, V} = get_factors(A);
	matrix_multiply(U, matrix_multiply(transpose(V), B)) // U * (Vᵀ * B)
	if K*P < N*M; // Heuristic: when intermediate Vᵀ*B is smaller

matrix_multiply(A : Matrix<T, N, M>, B : LowRankMatrix<_, M, P, K>) →
	let {U, V} = get_factors(B);
	matrix_multiply(matrix_multiply(A, U), transpose(V)) // (A * U) * Vᵀ
	if N*K < M*P; // Heuristic: when intermediate A*U is smaller
```

### Embedding Matrices & One-Hot Vectors

A common ML operation is multiplying an embedding matrix (tall, `VocabSize x EmbedDim`) by a one-hot vector, which simplifies to a lookup.

```orbit
// Domain definitions
EmbeddingMatrix<T, VocabSize, EmbedDim> ⊂ Matrix<T, VocabSize, EmbedDim>
OneHotVector<N> ⊂ Vector<Int, N> // Vector with one '1', rest '0'

// Rule: Multiplication is a lookup O(EmbedDim)
matrix_multiply(E : EmbeddingMatrix<_, V, D>, x : OneHotVector<V>) →
	get_row(E, get_hot_index(x)) : Vector<T, D>;

// Rule: Multiplication by transposed embedding matrix (e.g., output layer)
// Often involves multiplying a dense vector by a large, transposed embedding matrix.
matrix_multiply(x: Vector<T, D>, transpose(E : EmbeddingMatrix<_, V, D>)) →
	vector_matrix_multiply(x, transpose(E)); // Standard multiply, but potential for optimization
```

### Stochastic Matrices (e.g., from Softmax)

Matrices resulting from row-wise or column-wise Softmax have rows or columns that sum to 1 (probability distributions).

```orbit
// Domain definitions
RowStochasticMatrix<T, N, M> ⊂ Matrix<T, N, M>
ColStochasticMatrix<T, N, M> ⊂ Matrix<T, N, M>
DoublyStochasticMatrix<T, N> ⊂ RowStochasticMatrix<T, N, N>, ColStochasticMatrix<T, N, N>

// Properties:
// RowStochastic: sum(M[i, j] for j = 0..M-1) = 1 for all i
// ColStochastic: sum(M[i, j] for i = 0..N-1) = 1 for all j

// Rule: Simplify sums involving stochastic dimensions
// Example: Sum of elements in a row of (A * P) where P is RowStochastic
// sum(matrix_multiply(A:Matrix<_,N,M>, P:RowStochasticMatrix<_,M,P>)[i, j] for j = 0..P-1)
//   = sum_j sum_k A[i, k] * P[k, j]
//   = sum_k A[i, k] * (sum_j P[k, j])  // Swap summation order
//   = sum_k A[i, k] * 1                // Since P is RowStochastic
//   = row_sum(A, i)
sum_over_cols(matrix_multiply(A : Matrix<T, N, M>, P : RowStochasticMatrix<T, M, P>), i) →
	row_sum(A, i);

sum_over_rows(matrix_multiply(P : ColStochasticMatrix<T, N, M>, B : Matrix<T, M, P>), j) →
	col_sum(B, j);

// Note: Doubly stochastic matrices have connections to permutations (Birkhoff polytope)
// and spectral properties (largest eigenvalue is 1). These could lead to further
// specialized rules if relevant for specific computations.
```

## Other Relevant Operations

While not matrix types, these operations are fundamental and interact with matrix structures.

### Hadamard Product (Element-wise Product)

This is an operation, not a matrix structure, but extremely common, especially in ML.

```orbit
// Operation definition
hadamard_product(A : Matrix<T, N, M>, B : Matrix<T, N, M>) : ElementwiseOp → C : Matrix<T, N, M>
	where C[i, j] = A[i, j] * B[i, j]; // Also denoted A ∘ B or A .* B

// Properties:
// Commutative: hadamard_product(A, B) ↔ hadamard_product(B, A) : S₂
// Associative: hadamard_product(A, hadamard_product(B, C)) ↔ hadamard_product(hadamard_product(A, B), C) : A
// Distributes over addition: hadamard_product(A, B + C) ↔ hadamard_product(A, B) + hadamard_product(A, C)

// Rule: Simplification with diagonal matrices
// hadamard_product(D : DiagonalMatrix, M : Matrix) -> Creates a diagonal matrix with D[i,i]*M[i,i]
// trace(Aᵀ * (B ∘ C)) = sum_{i,j} A[i,j] * B[i,j] * C[i,j] -- Useful identity
```

### Kronecker Product

Another important operation, creating larger matrices from smaller ones.

```orbit
// Operation definition
kronecker_product(A : Matrix<T, N, M>, B : Matrix<T, P, Q>) : TensorOp → C : Matrix<T, N*P, M*Q>;
// C is block matrix where (i,j)-th block is A[i,j] * B

// Properties (Mixed Product Property is key):
// (A ⊗ B) * (C ⊗ D) = (A * C) ⊗ (B * D)  (if dimensions match)
matrix_multiply(kronecker_product(A, B), kronecker_product(C, D)) →
	kronecker_product(matrix_multiply(A, C), matrix_multiply(B, D))
	if can_multiply(A, C) && can_multiply(B, D);

// Other properties:
// transpose(A ⊗ B) = transpose(A) ⊗ transpose(B)
// inverse(A ⊗ B) = inverse(A) ⊗ inverse(B) (if invertible)
// trace(A ⊗ B) = trace(A) * trace(B)
// A ⊗ (B + C) = A ⊗ B + A ⊗ C
// (A + B) ⊗ C = A ⊗ C + B ⊗ C

// Rule: Apply mixed product property to simplify complex multiplications
// Example: Multiply result of Kronecker product by vector vec(X) = (X column stacked)
// (A ⊗ B) * vec(X) = vec(B * X * Aᵀ)
matrix_multiply(kronecker_product(A, B), vec(X)) → vec(matrix_multiply(B, matrix_multiply(X, transpose(A))));
```

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

## Example Derivation Trace (Conceptual)

Consider multiplying two 4x4 matrices A and B:

1.  `matrix_multiply(A:4x4, B:4x4)`
2.  **Detect Structure:** Check if A or B match special domains (Sparse, Diagonal, Triangular, LowRank, etc.). If yes, apply the corresponding rule (e.g., `sparse_multiply`, `diagonal_multiply`).
3.  **Apply Block Decomposition (if no special structure matched):** Rule `matrix_multiply(...) !: Blocked → ...` matches.
    *   Decomposes into 8 multiplications of 2x2 blocks (A11*B11, A12*B21, etc.) and 4 additions.
4.  **Recursive Application:** Consider one sub-problem, e.g., `matrix_multiply(A11:2x2, B11:2x2)`.
5.  **Apply Strassen (if enabled and beneficial):** Rule `matrix_multiply(...) : Blocked !: StrassenOptimized → ...` matches (assuming 2x2 is large enough or base case).
    *   Calculates M1..M7 using 7 multiplications of scalars (base case) and additions/subtractions.
    *   Assembles the 2x2 result using Strassen's formula.
6.  Repeat for all sub-problems (applying structure detection/Strassen recursively).
7.  **Combine Results:** The top-level additions combine the results of the sub-problems.

If Strassen's rule wasn't enabled or applicable, the recursion would bottom out at scalar multiplication, yielding the O(N³) block algorithm. If the matrices were detected as Circulant, the `matrix_multiply(...) : C_N` rule would take precedence, leading to FFT-based computation.

## Role of Algebraic Structures

The derivation of these algorithms hinges on recognizing and exploiting various algebraic structures:

1.  **Semiring/Ring:** The fundamental structure of matrix elements `T` allows definition of matrix addition and multiplication. Ring properties (especially additive inverse) are needed for Strassen. Distributivity and associativity are key.
2.  **Ring of Matrices:** The fact that N x N matrices (over a Ring T) themselves form a Ring justifies the block decomposition approach.
3.  **Groups (S_N, C_N, O(N), U(N)):** Permutation matrices inherit S_N structure. Circulant matrices relate to C_N and convolutions. Orthogonal/Unitary matrices form groups O(N)/U(N) whose properties (AᵀA=I) simplify multiplication.
4.  **Vector Spaces & Modules:** Matrices represent linear maps between vector spaces. Properties like rank (for LowRankMatrix) are vector space concepts.
5.  **Specific Algebraic Constraints:** Properties like symmetry (A=Aᵀ), skew-symmetry, triangularity (zero patterns), sparsity, or stochasticity (sum constraints) define sub-domains with specialized algorithms.
6.  **Tensor Algebra:** Strassen-like algorithms and the Kronecker product are deeply connected to the concept of tensor rank and multi-linear algebra.

Orbit leverages these structures via domain annotations and targeted rewrite rules.

## Unified Selection Strategy

Orbit can implement a sophisticated strategy to select the best algorithm based on detected domains and heuristics:

```orbit
// Unified matrix multiplication function (conceptual priority list)
multiply(A, B) : MatrixMultiply →
	// Highest priority for Identity, sparsity, diagonal, permutation, one-hot (often cheapest)
	identity_mult(A, B) : IdentityResult if is_identity(A) || is_identity(B);
	sparse_multiply(A, B) : SparseResult if is_sparse(A) || is_sparse(B);
	diag_mult(A, B) : DiagResult if is_diag(A) || is_diag(B);
	perm_mult(A, B) : PermResult if is_perm(A) || is_perm(B);
	embed_lookup(A, B) : EmbedResult if is_embed(A) && is_onehot(B);
	// Simplifications involving Orthogonal/Unitary
	orthogonal_simplify(A, B) : OrthogonalResult if is_orthogonal(A) || is_orthogonal(B);
	// Then FFT-based methods
	circulant_fft_multiply(A, B) : CirculantResult if is_circulant(A) && is_circulant(B);
	toeplitz_fft_multiply(A, B) : ToeplitzResult if is_toeplitz(A) && is_toeplitz(B);
	hankel_fft_multiply(A, B) : HankelResult if is_hankel(A) && is_hankel(B);
	// Banded/Triangular optimizations
	banded_multiply(A, B) : BandedResult if is_banded(A) && is_banded(B);
	triangular_multiply(A, B) : TriangularResult if is_tri(A) && is_tri(B);
	// Low-rank optimization
	low_rank_multiply(A, B) : LowRankResult if is_low_rank(A) || is_low_rank(B);
	// Properties like Symmetry might influence choices below but don't typically change the algorithm directly
	// Strassen/Recursive block methods
	strassen_multiply(A, B) : StrassenResult if use_strassen(A, B) && element_type_is_ring(T);
	recursive_block_multiply(A, B) : RecursiveResult if use_recursive(A, B);
	// Fallback standard method
	standard_multiply(A, B) : StandardResult; // Base case or small matrices

// Additional rules for simplifying expressions involving results, e.g., using stochastic properties
simplify_expr_with_stochastic(expr) : StochasticProperty → simplified_expr;
// Rules for simplifying products involving Kronecker/Hadamard products
simplify_kronecker(expr) : HasKronecker → simplified_expr;
simplify_hadamard(expr) : HasHadamard → simplified_expr;
```
The system applies the most specific, efficient rule based on detected matrix properties (domains) and configuration (e.g., Strassen threshold, FFT availability).



### Matrix Trace

The **trace** of a square matrix `M`, denoted `tr(M)`, is the sum of the elements on its main diagonal. It's a fundamental concept in linear algebra with various applications.

```orbit
// Definition of Trace for an N x N matrix
trace(M : Matrix<T, N, N>) : Scalar<T> → sum(i, 0, N-1, M[i, i]);

```

#### Key Properties of the Trace

The trace exhibits several important algebraic properties, which can be expressed as rewrite rules in Orbit:

1.  **Linearity:** The trace is a linear map.
    *   `tr(A + B) → tr(A) + tr(B)`
    *   `tr(c * A) → c * tr(A)` (where `c` is a scalar)

2.  **Cyclic Property (Invariance under cyclic permutations):** This is one of an_EQ_important_EQ_properties.
    *   `tr(A * B) → tr(B * A)`
    *   This extends to products of multiple matrices: `tr(A * B * C) → tr(B * C * A) → tr(C * A * B)`.
    *   This property highlights that the trace is invariant under the action of the Cyclic Group Cₙ (acting on the order of n matrices in a product by cyclic permutation).

3.  **Transpose Invariance:** The trace of a matrix is equal to the trace of its transpose.
    *   `tr(M) → tr(Mᵀ)`

4.  **Similarity Invariance:** The trace is invariant under similarity transformations.
    *   If `P` is an invertible matrix, then `tr(P⁻¹ * A * P) → tr(A)`.
    *   This crucial property implies that the trace is an invariant of a linear transformation, regardless of the basis chosen to represent that transformation. The trace is a *class function* on the General Linear Group GL(n, F) acting by conjugation (`A ↦ P⁻¹AP`).

#### Symmetries and Use Cases of the Trace

The invariances of the trace connect it to deeper mathematical symmetries and make it a valuable tool in various applications:

1.  **Eigenvalue Analysis:**
    *   The trace of a matrix is equal to the sum of its eigenvalues (counting multiplicity): `tr(A) = sum(eigenvalues(A))`.
    *   Since similar matrices share the same characteristic polynomial (and thus the same eigenvalues), their traces are equal, which is consistent with the similarity invariance. This is fundamental in fields like physics and engineering for analyzing linear systems.

2.  **Character Theory in Group Representations:**
    *   In group representation theory, the trace of a matrix representing a group element is the "character" of that element in that specific representation.
    *   Characters are constant on the conjugacy classes of the group, a direct consequence of the trace's similarity invariance. Characters are instrumental in classifying and decomposing group representations.

3.  **Machine Learning and Statistics:**
    *   **Dimensionality Reduction (e.g., PCA):** Trace optimization is often a component of techniques like Principal Component Analysis, for example, in maximizing `tr(XᵀCX)` under certain constraints, where `C` is a covariance matrix.
    *   **Regularization:** The nuclear norm (also known as the trace norm), `||A||_* = tr(sqrt(Aᵀ*A))`, is the sum of the singular values of `A`. It's widely used as a convex surrogate for the rank of a matrix in optimization problems such as low-rank matrix completion and robust PCA.
    *   **Model Complexity:** In statistical linear models, the trace of the projection matrix (hat matrix) `H = X(XᵀX)⁻¹Xᵀ` gives the effective number of parameters or degrees of freedom of the model.
    *   **Covariance Matrices:** For a multivariate random variable, the trace of its covariance matrix `Σ` represents the total variance of its components.

4.  **Numerical Linear Algebra:**
    *   **Trace Estimation:** For very large matrices where computing the matrix `f(A)` (e.g., `A⁻¹` or `exp(A)`) is computationally prohibitive, its trace `tr(f(A))` can often be estimated efficiently using stochastic methods like Hutchinson's estimator. This estimator relies on averaging `zᵀ * f(A) * z` over random vectors `z`, and its analysis often uses the cyclic property of the trace.

5.  **Graph Theory:**
    *   If `Adj` is the adjacency matrix of a graph, `tr(Adj^k)` counts the total number of closed walks of length `k` in the graph. For instance, `tr(Adj^2)` is twice the number of edges, and `tr(Adj^3)` is six times the number of triangles.

6.  **Physics:**
    *   **Quantum Mechanics:** The expectation value of an observable `O` in a quantum state described by a density matrix `ρ` is given by `tr(ρO)`. The normalization condition for a density matrix is `tr(ρ) = 1`.
    *   **Statistical Mechanics:** Partition functions, which are central to statistical mechanics, often involve traces, such as `Z = tr(exp(-βH))`, where `H` is the Hamiltonian of the system.

The cyclic property `tr(A*B) = tr(B*A)` is especially powerful. It permits the reordering of matrix products under the trace operation, which can lead to significant computational simplifications or enable alternative analytical strategies.

For the Orbit system, these properties can be encoded as rewrite rules. Such rules can simplify expressions involving traces or identify opportunities for optimization when trace operations are part of larger computational graphs. For example, recognizing `tr(P⁻¹ * A * P)` and rewriting it to `tr(A)` simplifies the expression and can avoid potentially costly matrix multiplications and inversions if only the trace value is required. The inherent connection of trace properties to group actions (like Cₙ for cyclic permutations in products, and GL(n,F) for similarity transformations) aligns well with Orbit's group-theoretic rewriting capabilities.

### Inferring Group Symmetries for Canonicalization in Orbit

The algebraic properties of the trace are not just useful for direct simplification but also serve as powerful indicators of underlying symmetries. Orbit can leverage these indicators through rewrite rules to infer group actions and apply its canonicalization strategies, further enhancing optimization and equivalence detection.

#### 1. Cyclic Symmetry in Products: `tr(M₁ * M₂ * ... * Mₖ)`

The property `tr(AB) = tr(BA)` extends to `tr(M₁M₂...Mₖ) = tr(M_{\sigma(1)}M_{\sigma(2)}...M_{\sigma(k)})` where `σ` is a cyclic permutation. This means the expression under the trace exhibits `Cₖ` (Cyclic Group of order k) symmetry.

**Orbit Inference and Canonicalization:**

*   **Rewrite Rule for Cₖ Inference:**
```orbit
	// Pattern: trace of a product of k matrices
	tr(matrix_multiply_chain(M₁, M₂, ..., Mₖ)) ⊢ tr_arg_list : Cₖ;
	// `matrix_multiply_chain` would be an internal representation of sequential multiplications
	// `tr_arg_list` refers to the sequence (M₁, ..., Mₖ)
```
    This rule annotates the list of matrices *within the trace operation* with `Cₖ` symmetry.

*   **Canonical Form via Cyclic Group Algorithm:**
    Once `Cₖ` symmetry is inferred for the argument list `(M₁, ..., Mₖ)`, Orbit can apply its `canonicalise_cyclic_efficient` algorithm (e.g., Booth's algorithm as described in `paper.md`, Algorithm 2) to find the lexicographically smallest cyclic permutation of this list.
```orbit
	// Canonicalization rule for trace arguments
	tr(arg_list : Cₖ) → tr(canonicalise_cyclic_efficient(arg_list));
```
    **Example:**
    `tr(A*B*C)` and `tr(B*C*A)` would both be canonicalized. If `canonicalise_cyclic_efficient([A,B,C])` yields `[A,B,C]`, then:
    `tr(A*B*C) → tr([A,B,C])` (conceptually)
    `tr(B*C*A) → tr([A,B,C])`
    These would then map to the same e-class in the O-Graph, signifying their equivalence.

#### 2. Similarity Transformation Invariance: `tr(P⁻¹ * A * P)`

The property `tr(P⁻¹ * A * P) = tr(A)` means the trace is invariant under conjugation by an invertible matrix `P`. This is a fundamental property related to the General Linear Group GL(n,F).

**Orbit Inference and Canonicalization:**

*   **Rewrite Rule for GL(n,F) Invariance and Simplification:**
```orbit
	// Pattern: trace of a similarity transform
	tr(matrix_multiply(matrix_multiply(P_inv, A), P))
		if is_inverse(P_inv, P) && is_invertible(P)
		→ tr(A) : GL_Conj_Invariant;
```
    This rule directly simplifies the expression to its canonical form `tr(A)`. The annotation `: GL_Conj_Invariant` could be added to `tr(A)` to signify that this particular trace value is known to be invariant under similarity transformations of `A`.

*   **Benefits for Canonicalization:**
    This directly reduces complex expressions to simpler canonical forms. For example, `tr(Q⁻¹ * (R⁻¹ * X * R) * Q)` would simplify in steps:
    1.  Let `Y = R⁻¹ * X * R`. Then the expression is `tr(Q⁻¹ * Y * Q)`.
    2.  This simplifies to `tr(Y)`.
    3.  Substituting `Y` back: `tr(R⁻¹ * X * R)`.
    4.  This simplifies to `tr(X)`.

    The canonical form is simply `tr(X)`, significantly reducing computation and representation size.

#### 3. Linearity and Commutativity with Scalar Multiplication: `tr(c*A) = c*tr(A)`

While `tr(c*A) = c*tr(A)` is a linearity property, if `c` itself is a matrix (e.g., a scalar matrix `s*I`), then `tr((s*I)*A) = tr(A*(s*I))`. This also falls under the `C₂` symmetry for the product `(s*I)*A`.

**Orbit Inference and Canonicalization:**

*   **Rewrite Rule for Scalar Factor Commutation:**
```orbit
	// c is a scalar, A is a matrix
	tr(matrix_multiply(c, A)) : ScalarMultiplication → c * tr(A);

	// S is a scalar matrix (S = s*I), A is a matrix
	// This would be canonicalized by the C₂ rule for tr(S*A)
	tr(matrix_multiply(S : ScalarMatrix, A))
		⊢ tr_arg_list : C₂;
	// Then canonicalized to e.g., tr(matrix_multiply(A, S)) if A < S by canonical order,
	// or further simplified if S = s*I:
	tr(matrix_multiply(s_identity_matrix(s_val), A)) → s_val * tr(A);
```

#### Exploiting Inferred Symmetries in Orbit

By inferring these group symmetries (`Cₖ` for products, `GL(n,F)` invariance for similarity transforms), Orbit can:

1.  **Reduce Expression Complexity:** Directly simplify expressions like `tr(P⁻¹AP)` to `tr(A)`.
2.  **Standardize Representations:** Ensure that equivalent trace expressions like `tr(ABC)`, `tr(BCA)`, and `tr(CAB)` map to the same canonical representation in the O-Graph by applying cyclic canonicalization to the argument list `(A,B,C)`.
3.  **Improve Equality Checking:** Two structurally different trace expressions can be quickly identified as equivalent if they reduce to the same canonical form.
4.  **Enhance Pattern Matching:** Rewrite rules that operate on trace expressions can be written against the canonical form, reducing the number of patterns that need to be considered.
5.  **Aid Further Algebraic Reasoning:** The inferred group annotations (`:Cₖ`, `:GL_Conj_Invariant`) can provide hints for downstream processing or for inferring even richer algebraic structures within the Orbit system, as discussed in `canonical.md` under "Inferring Algebraic Structures via Symmetry Groups." For instance, the similarity invariance is key to character theory in group representations.

By actively looking for these trace patterns and annotating them with their corresponding group symmetries, Orbit can more effectively apply its canonicalization machinery, leading to a more robust and efficient system for symbolic computation involving matrices.

### Matrix Determinant

The **determinant** of a square matrix `M`, denoted `det(M)` or sometimes `|M|`, is a scalar value that encodes certain properties of the matrix and the linear transformation it represents. It is a fundamental concept in linear algebra with wide-ranging applications.

```orbit
// Conceptual definition for an N x N matrix
// The actual computation method (e.g., cofactor expansion, row reduction) would be encapsulated.
determinant(M : Matrix<T, N, N>) : Scalar<T> → compute_determinant_value(M);

```

#### Key Properties of the Determinant

The determinant has a rich set of algebraic properties, many of which can be expressed as rewrite rules in Orbit:

1.  **Identity Matrix**: The determinant of the identity matrix is 1.
    *   `determinant(I : IdentityMatrix<N>) → 1`

2.  **Multiplicative Property**: The determinant of a product of matrices is the product of their determinants.
    *   `determinant(A * B) → determinant(A) * determinant(B)`
    *   This implies `det` is a homomorphism from the group of invertible matrices GL(n,F) to the multiplicative group of the field F*.

3.  **Transpose Invariance**: The determinant of a matrix is equal to the determinant of its transpose.
    *   `determinant(Mᵀ) → determinant(M)`

4.  **Scalar Multiplication**: If a matrix `A` (N×N) is multiplied by a scalar `c`:
    *   `determinant(c * A) → c^N * determinant(A)`

5.  **Inverse Matrix**: If `A` is invertible:
    *   `determinant(A⁻¹) → 1 / determinant(A)` (if `determinant(A) ≠ 0`)

6.  **Singular Matrices**:
    *   If a matrix `A` has a row or column consisting entirely of zeros, `determinant(A) → 0`.
    *   If a matrix `A` has two identical rows or columns, `determinant(A) → 0`.
    *   More generally, `A` is invertible if and only if `determinant(A) ≠ 0`.
```orbit
		is_invertible(A) ↔ determinant(A) ≠ 0;
		determinant(M : SingularMatrix) → 0; // If M is known to be singular
```

7.  **Triangular Matrices**: For an upper or lower triangular matrix, the determinant is the product of its diagonal elements.
    *   `determinant(M : UpperTriangular) → product_of_diagonal_elements(M)`
    *   `determinant(M : LowerTriangular) → product_of_diagonal_elements(M)`
    *   (This implies `determinant(M : DiagonalMatrix) → product_of_diagonal_elements(M)`)

8.  **Effect of Row/Column Operations**:
    *   Swapping two rows (or columns) multiplies the determinant by -1. This is the **alternating property**.
        *   `determinant(swap_rows(A, r1, r2)) → -determinant(A)`
    *   Multiplying a single row (or column) by a scalar `c` multiplies the determinant by `c`.
        *   `determinant(scale_row(A, r, c)) → c * determinant(A)`
    *   Adding a multiple of one row (or column) to another row (or column) does not change the determinant.
        *   `determinant(add_multiple_to_row(A, target_r, source_r, c)) → determinant(A)`

#### Symmetries, Invariances, and Geometric Interpretation

The determinant's properties reveal important symmetries and provide geometric insights:

1.  **Similarity Invariance**: The determinant is invariant under similarity transformations.
    *   `determinant(P⁻¹ * A * P) → determinant(A)` (if `P` is invertible)
    *   This means the determinant is a property of the linear transformation represented by `A`, independent of the chosen basis. It is a class function on GL(n,F) under conjugation.

2.  **Volume Scaling Factor**: For a real matrix `A`, `abs(determinant(A))` represents the factor by which the linear transformation `A` scales volumes.
    *   If `determinant(A) = 0`, the transformation collapses space into a lower dimension.
    *   The sign of `determinant(A)` indicates whether the transformation preserves or reverses orientation (e.g., in 2D, a reflection has a negative determinant).

3.  **Alternating Multilinear Form**: The determinant can be viewed as an alternating multilinear function of the columns (or rows) of the matrix.
    *   **Multilinear**: `det(... c*v_j ..., w) = c * det(... v_j ..., w)` and `det(... v_j + v'_j ..., w) = det(... v_j ..., w) + det(... v'_j ..., w)`.
    *   **Alternating**: If any two columns (or rows) are identical, the determinant is zero. Swapping two columns (or rows) negates the determinant. This property connects the determinant to permutations (Sₙ) and their signs, particularly in the Leibniz formula for the determinant:
        `det(A) = sum(σ in S_n, sgn(σ) * product(i=1 to N, A[i, σ(i)]))`
        where `sgn(σ)` is the sign of the permutation `σ`.

#### Use Cases of the Determinant

*   **Checking Invertibility**: `det(A) ≠ 0` is a necessary and sufficient condition for `A` to be invertible.
*   **Solving Linear Systems (Cramer's Rule)**: Provides an explicit formula for solutions, though often computationally impractical for large systems compared to methods like Gaussian elimination.
*   **Eigenvalue Problems**: The eigenvalues `λ` of `A` are the roots of the characteristic polynomial `p(λ) = det(A - λI) = 0`.
*   **Change of Variables in Multidimensional Integration**: The Jacobian determinant is used to account for volume changes when transforming coordinate systems.
*   **Geometric Algorithms**: Used in computational geometry for orientation tests, volume calculations, etc.
*   **Matrix Decompositions**: Determinants appear in relation to LU decomposition, QR decomposition, etc. For example, if `A = LU`, then `det(A) = det(L)det(U) = product(diag(L)) * product(diag(U))`.

#### Inferring Group Symmetries and Properties for Canonicalization in Orbit

Orbit can exploit the determinant's properties for simplification, inference, and applying canonical forms:

1.  **Direct Simplification from Group/Structural Domains**:
    Orbit can have rules that directly evaluate or simplify determinants based on matrix domain annotations.
```orbit
	determinant(M : SLnF_Matrix) → 1; // By definition of Special Linear Group
	determinant(M : OrthogonalMatrix) → result where result * result = 1; // result is +1 or -1
										// Further rules might determine which one based on context
										// (e.g. rotations vs. roto-reflections)
	determinant(M : SingularMatrix) → 0; // If rank < N is known
	determinant(M : ZeroMatrix) → 0;
	determinant(M : UpperTriangular) → product_of_diagonal_elements(M);
	determinant(M : LowerTriangular) → product_of_diagonal_elements(M);
```

2.  **Exploiting the Alternating Property (Sₙ Connection)**:
    The alternating nature of the determinant is fundamental. If Orbit encounters an expression `determinant(permute_rows(A, σ))` where `σ` is a permutation, it can rewrite it:
```orbit
	// σ is a permutation object/representation
	determinant(permute_rows(A, σ)) → sign(σ) * determinant(A);
	determinant(permute_cols(A, σ)) → sign(σ) * determinant(A);

	// Specific case: swapping two rows
	determinant(A_prime) where A_prime = row_swap(A, r1, r2) → -determinant(A);
```
    This allows canonicalizing the input matrix to `determinant` by, for example, sorting rows/columns while accumulating sign changes, although direct computation via row reduction is usually more efficient.

3.  **Leveraging the Multiplicative Property for Decomposition and Simplification**:
    The rule `determinant(A * B) → determinant(A) * determinant(B)` is powerful.
```orbit
	// Example: Product with an easily computed determinant
	determinant(matrix_multiply(A, D : DiagonalMatrix)) → determinant(A) * product_of_diagonal_elements(D);
	determinant(matrix_multiply(A, P : PermutationMatrix)) → determinant(A) * sign_of_permutation(P);
```
    This can break down a complex determinant into simpler parts or reveal if a determinant is zero if one factor is singular.

4.  **Canonicalization via Similarity Invariance**:
    The rule `determinant(P⁻¹ * A * P) → determinant(A)` is a key simplification and canonicalization.
```orbit
	determinant(matrix_multiply(matrix_multiply(P_inv, A), P))
		if is_inverse(P_inv, P) && is_invertible(P)
		→ determinant(A) : GL_Conj_Invariant;
```
    This ensures that expressions representing determinants of similar matrices can be unified to the same canonical form `determinant(A)` in the O-Graph.

5.  **Symbolic Row/Column Reduction for Computation**:
    Orbit can symbolically apply rewrite rules based on the effects of row operations to transform a matrix into an upper triangular form (or REF/RREF). The determinant is then the product of the diagonal elements, adjusted by any scaling factors or sign changes accumulated during the process. This mirrors how Gaussian elimination is used for determinant computation.
```orbit
	// Conceptual rewrite sequence:
	// determinant(M) → det_via_row_reduction(M, 1); // state: (matrix, current_multiplier)

	// det_via_row_reduction(matrix_op_add_row(M_curr), mult) → det_via_row_reduction(M_curr, mult);
	// det_via_row_reduction(matrix_op_swap_row(M_curr), mult) → det_via_row_reduction(M_curr, -mult);
	// det_via_row_reduction(matrix_op_scale_row(M_curr, c), mult) → det_via_row_reduction(M_curr, mult * c);

	// Base case when matrix is UpperTriangular
	// det_via_row_reduction(M_tri : UpperTriangular, mult) → mult * product_of_diagonal_elements(M_tri);
```
    This turns the computation of a determinant into a sequence of canonicalizing matrix transformations.

6.  **Impact on O-Graph and Expression Equivalence**:
    *   Equivalent expressions like `determinant(AB)` and `determinant(A)determinant(B)` would merge in the O-Graph once the rewrite rule is applied.
    *   `determinant(Aᵀ)` would simplify to `determinant(A)`.
    *   Complex forms like `determinant(P⁻¹AP)` simplify, reducing representational overhead and aiding equality checks.

By systematically applying these properties, Orbit can simplify determinant expressions, choose efficient computation strategies (e.g., row reduction for general matrices, product of diagonals for triangular ones), and recognize equivalences that might otherwise be obscured by complex formulations. The connection to group theory (GL(n,F) for multiplicative and similarity properties, Sₙ for the alternating property) provides a deep structural understanding that Orbit can exploit.

### Eigenvalues and Eigenvectors

Eigenvalues and eigenvectors are fundamental concepts in linear algebra that reveal intrinsic properties of linear transformations represented by square matrices. They are crucial for understanding matrix behavior, simplifying complex systems, and are widely applied across various scientific and engineering disciplines.

#### Definition and Core Concepts

For a given square `N × N` matrix `A`, a non-zero vector `v` is an **eigenvector** of `A` if the application of `A` to `v` scales `v` by a scalar factor `λ`, known as the **eigenvalue** corresponding to `v`.

Mathematically:
`A v = λ v`

Where:
*   `A` is an `N × N` matrix.
*   `v` is a non-zero `N × 1` column vector (the eigenvector).
*   `λ` is a scalar (the eigenvalue), which can be real or complex.

This equation can be rewritten as:
`(A - λI) v = 0`

Where `I` is the `N × N` identity matrix. For this equation to have a non-zero solution for `v`, the matrix `(A - λI)` must be singular. This leads to the **characteristic equation**:

`det(A - λI) = 0`

The solutions `λ` to this polynomial equation are the eigenvalues of `A`. For each eigenvalue `λᵢ`, the corresponding eigenvectors `vᵢ` can be found by solving the system `(A - λᵢI) vᵢ = 0`. The set of all eigenvalues of `A` is called its **spectrum**.

```orbit
// Conceptual representation in Orbit
// Define an eigenvalue problem
eigen_problem(A : Matrix<T,N,N>) → solution_set : EigenSolutionSet
  where solution_set contains pairs (λᵢ : Scalar<T>, vᵢ : Vector<T,N>)
  such that matrix_multiply(A, vᵢ) = scalar_multiply(λᵢ, vᵢ)
  and characteristic_poly(A, λ) = determinant(matrix_subtract(A, scalar_multiply(λ, I<N>)));

// Characteristic polynomial definition
solve_for_roots(characteristic_poly(A, λ)) → eigenvalues_of(A);
```

#### Key Properties of Eigenvalues and Eigenvectors

1.  **Sum and Product:**
	*   The sum of the eigenvalues of `A` is equal to its trace: `tr(A) = Σ λᵢ`.
	*   The product of the eigenvalues of `A` is equal to its determinant: `det(A) = Π λᵢ`.

2.  **Transpose:** A matrix `A` and its transpose `Aᵀ` have the same eigenvalues, but not necessarily the same eigenvectors.

3.  **Matrix Powers:** If `λ` is an eigenvalue of `A` with eigenvector `v`, then:
	*   `λᵏ` is an eigenvalue of `Aᵏ` for any positive integer `k`, with the same eigenvector `v`.
	*   If `A` is invertible, `1/λ` is an eigenvalue of `A⁻¹` with the same eigenvector `v`.

4.  **Scalar Multiplication:** If `λ` is an eigenvalue of `A`, then `cλ` is an eigenvalue of `cA` for any scalar `c`.

5.  **Shift Property:** If `λ` is an eigenvalue of `A`, then `λ - s` is an eigenvalue of `A - sI` for any scalar `s`.

6.  **Triangular and Diagonal Matrices:** The eigenvalues of a triangular matrix (upper or lower) or a diagonal matrix are its diagonal entries.

7.  **Linear Independence:** Eigenvectors corresponding to distinct eigenvalues are linearly independent.

8.  **Symmetric Matrices (Real):** If `A` is a real symmetric matrix (`A = Aᵀ`), then:
	*   All its eigenvalues `λᵢ` are real.
	*   Its eigenvectors `vᵢ` corresponding to distinct eigenvalues are orthogonal.
	*   `A` is always diagonalizable by an orthogonal matrix.

9.  **Positive Definite Matrices:** A symmetric matrix is positive definite if and only if all its eigenvalues are positive (`λᵢ > 0`).

#### Symmetries and Invariances Related to Eigen-Problems

The most crucial invariance property for eigenvalues is:

*   **Similarity Invariance:** Similar matrices have the same characteristic polynomial and thus the same eigenvalues. If `B = P⁻¹AP` for some invertible matrix `P`, then `A` and `B` share the same set of eigenvalues `λᵢ`.
	*   If `v` is an eigenvector of `A` for eigenvalue `λ`, then `P⁻¹v` is an eigenvector of `B` for the same eigenvalue `λ`.
	`B(P⁻¹v) = (P⁻¹AP)(P⁻¹v) = P⁻¹A(PP⁻¹)v = P⁻¹Av = P⁻¹(λv) = λ(P⁻¹v)`

This invariance is fundamental because it means eigenvalues are intrinsic properties of the linear transformation represented by the matrix, independent of the basis chosen.

#### Use Cases of Eigenvalues and Eigenvectors

Eigenvalue analysis is a cornerstone of many advanced computational techniques:

1.  **Principal Component Analysis (PCA):** Eigenvalues of the covariance matrix indicate the variance along principal components (eigenvectors), used for dimensionality reduction.
2.  **Quantum Mechanics:** Eigenvalues of Hamiltonian operators represent energy levels (quantized energies) of a quantum system, and eigenvectors represent the corresponding stationary states.
3.  **Vibrational Analysis:** Eigenvalues of a system's dynamic matrix correspond to the squares of its natural frequencies of vibration, and eigenvectors describe the mode shapes.
4.  **Stability Analysis of Dynamical Systems:** Eigenvalues of the system matrix determine the stability of equilibrium points (e.g., in control theory or differential equations).
5.  **Graph Theory (Spectral Graph Theory):** Eigenvalues of the adjacency matrix or Laplacian matrix of a graph reveal properties like connectivity, bipartiteness, and are used in spectral clustering.
6.  **Google's PageRank Algorithm:** The PageRank vector is the principal eigenvector of a modified adjacency matrix of the web graph.
7.  **Differential Equations:** Eigenvalue methods are used to find solutions to systems of linear differential equations.
8.  **Facial Recognition (Eigenfaces):** Uses PCA and eigenvectors to represent faces in a lower-dimensional space.

#### Exploiting Eigen-Properties for Canonicalization and Simplification in Orbit

Orbit can leverage the properties of eigenvalues and eigenvectors for sophisticated analysis, simplification, and canonicalization:

1.  **Recognizing the Characteristic Equation:**
	Orbit can identify the pattern `determinant(A - λI)` as the characteristic polynomial of `A`.
```orbit
    determinant(matrix_subtract(A, scalar_multiply(λ_var, I))) ⊢ is_characteristic_poly_of(A, λ_var);
```

2.  **Relating to Trace and Determinant for Verification/Inference:**
	Rewrite rules can enforce consistency or simplify expressions involving trace, determinant, and eigenvalues.
```orbit
    // If eigenvalues are known/symbolic
    tr(A) where eigenvalues_of(A) = {λ₁, ..., λₙ} → sum(λ₁, ..., λₙ);
    determinant(A) where eigenvalues_of(A) = {λ₁, ..., λₙ} → product(λ₁, ..., λₙ);

    // Inference rule
    A : HasEigenvalues {λᵢ...} ⊢ tr(A) = sum(λᵢ...);
    A : HasEigenvalues {λᵢ...} ⊢ determinant(A) = product(λᵢ...);
    
```

3.  **Canonicalization through Diagonalization (Similarity Invariance):**
	If a matrix `A` is diagonalizable, i.e., `A = PDP⁻¹` where `D` is a diagonal matrix of eigenvalues, Orbit can aim to rewrite `A` or expressions involving `A` using its diagonal form.
```orbit
    // If A is known to be diagonalizable with P_inv*A*P = D_eigenvalues
    A : DiagonalizableBy P → P * D_eigenvalues(A) * P_inv;
    // Operations on A can then be simplified by operating on D
    matrix_power(A : DiagonalizableBy P, k) → P * matrix_power(D_eigenvalues(A), k) * P_inv;
      // where matrix_power(D_diag, k) simply raises diagonal elements to k.

    // Directly state that eigenvalues are those of the diagonal form
    eigenvalues_of(A) where A = P * D_diag * P_inv → diagonal_elements_of(D_diag);
    
```
	This leverages the similarity invariance: `eigenvalues(A)` are identical to `eigenvalues(D)`, which are simply the diagonal entries of `D`.

4.  **Simplifying Powers and Inverses:**
	Rules can directly compute eigenvalues of matrix powers or inverses.
```orbit
    eigenvalues_of(matrix_power(A, k)) → map(λ x. x^k, eigenvalues_of(A));
    eigenvalues_of(matrix_inverse(A)) → map(λ x. 1/x, eigenvalues_of(A)) if A : Invertible;
    
```

5.  **Domain-Specific Eigenvalue Properties:**
	For matrices with specific domain annotations, Orbit can infer properties of their eigenvalues.
```orbit
    A : SymmetricMatrix ⊢ eigenvalues_of(A) : RealNumbersSet;
    A : PositiveDefiniteMatrix ⊢ eigenvalues_of(A) : PositiveRealNumbersSet;
    A : OrthogonalMatrix ⊢ map(λ x. abs(x), eigenvalues_of(A)) = {1, ..., 1}; // Eigenvalues have modulus 1
    A : UpperTriangular ⊢ eigenvalues_of(A) = diagonal_elements_of(A);
    A : LowerTriangular ⊢ eigenvalues_of(A) = diagonal_elements_of(A);
    
```

6.  **Unifying Eigenvalue Sets:**
	If `B = P⁻¹AP`, then `eigenvalues_of(A)` and `eigenvalues_of(B)` should unify to the same set in the O-Graph. Orbit can use the similarity invariance to ensure this:
```orbit
    eigenvalues_of(matrix_multiply(matrix_multiply(P_inv, A), P))
        if is_inverse(P_inv, P) && is_invertible(P)
        → eigenvalues_of(A) : GL_Conj_Invariant_Spectrum;
    
```
	This means even if computed through different symbolic paths, expressions for the eigenvalues of similar matrices would be canonicalized to the same representation.

By encoding these properties as rewrite rules and leveraging domain annotations, Orbit can transform complex eigen-problems into simpler forms, verify consistency across related matrix properties (trace, determinant, eigenvalues), and canonicalize representations based on fundamental invariances. This provides a powerful framework for reasoning about and simplifying linear algebra expressions involving eigenvalues and eigenvectors.
```

## Conclusion

This document illustrates how Orbit's approach, centered on algebraic rewriting and domain knowledge, can automatically derive various matrix multiplication algorithms from the standard definition. By exploiting structures like Rings, Groups, and specific matrix patterns (diagonal, circulant, sparse, triangular, low-rank, stochastic, symmetric, orthogonal, etc.), Orbit can transform the basic O(N³) algorithm into more efficient forms like Strassen's O(N^2.81) or specialized O(N log N), O(N²), or even O(N) or O(K) methods for certain structures.

Key takeaways:

1.  **Algebraic Foundation:** Matrix multiplication algorithms are grounded in the algebraic properties of matrices and their elements.
2.  **Rewrite Rules:** These properties are expressed as conditional rewrite rules within Orbit.
3.  **Automatic Derivation:** Complex algorithms like Strassen's or FFT-based methods emerge from applying these rules, rather than being explicitly coded.
4.  **Structure Recognition:** Detecting special matrix structures (via domains like Triangular, LowRank, Stochastic, Symmetric, Orthogonal, Banded) enables highly specialized and efficient algorithms relevant in diverse fields like linear algebra and machine learning.
5.  **Unified Framework:** Orbit provides a single framework to represent, optimize, and select among diverse matrix multiplication strategies based on mathematical principles.

This mirrors the FFT derivation, showcasing a powerful methodology for automated algorithm discovery and optimization driven by understanding the underlying mathematical structure of computational problems.
