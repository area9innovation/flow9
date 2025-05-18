# Automatic Derivation of Matrix Multiplication Algorithms Through Orbit's Algebraic Rewrites

## Introduction

Matrix multiplication is a fundamental operation in numerous scientific and engineering domains. While the standard algorithm has O(N³) complexity, significant improvements exist for both general and specially structured matrices. Similar to how the Fast Fourier Transform (FFT) emerges from exploiting the group structure of the Discrete Fourier Transform (DFT), this document demonstrates how Orbit's algebraic rewriting capabilities can automatically derive optimized matrix multiplication algorithms from the standard definition by identifying and leveraging underlying mathematical structures.

Instead of treating algorithms like Strassen's method or specialized methods for circulant or sparse matrices as distinct, hardcoded implementations, we show how they can arise naturally from applying algebraic rewrite rules based on properties like associativity, distributivity, and specific structural patterns.

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

## Conclusion

This document illustrates how Orbit's approach, centered on algebraic rewriting and domain knowledge, can automatically derive various matrix multiplication algorithms from the standard definition. By exploiting structures like Rings, Groups, and specific matrix patterns (diagonal, circulant, sparse, triangular, low-rank, stochastic, symmetric, orthogonal, etc.), Orbit can transform the basic O(N³) algorithm into more efficient forms like Strassen's O(N^2.81) or specialized O(N log N), O(N²), or even O(N) or O(K) methods for certain structures.

Key takeaways:

1.  **Algebraic Foundation:** Matrix multiplication algorithms are grounded in the algebraic properties of matrices and their elements.
2.  **Rewrite Rules:** These properties are expressed as conditional rewrite rules within Orbit.
3.  **Automatic Derivation:** Complex algorithms like Strassen's or FFT-based methods emerge from applying these rules, rather than being explicitly coded.
4.  **Structure Recognition:** Detecting special matrix structures (via domains like Triangular, LowRank, Stochastic, Symmetric, Orthogonal, Banded) enables highly specialized and efficient algorithms relevant in diverse fields like linear algebra and machine learning.
5.  **Unified Framework:** Orbit provides a single framework to represent, optimize, and select among diverse matrix multiplication strategies based on mathematical principles.

This mirrors the FFT derivation, showcasing a powerful methodology for automated algorithm discovery and optimization driven by understanding the underlying mathematical structure of computational problems.
