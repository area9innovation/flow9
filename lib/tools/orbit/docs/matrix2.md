# Leveraging Specialized Matrix Structures in Orbit

## Introduction

Building upon the foundational concepts outlined in [`matrix1.md`](./matrix1.md), this document delves into how Orbit identifies and optimizes operations for matrices possessing specific, exploitable structures. By annotating matrices with their corresponding domains (e.g., `:SparseMatrix`, `:CirculantMatrix`, `:SymmetricMatrix`), Orbit can apply highly specialized rewrite rules. These rules often lead to significant computational savings compared to general-purpose algorithms, moving from O(N³) or O(N²) complexities to O(N log N), O(N), or even O(1) in some cases.

## Exploiting Special Matrix Structures

Orbit's domain system allows it to recognize and apply tailored algorithms for various matrix types.



### Identity Matrix
The identity matrix acts as the multiplicative identity in the matrix ring.
```orbit
// Domain definition
IdentityMatrix<N> ⊂ DiagonalMatrix<Int, N> // Typically {0, 1} elements
// Property: I[i,i] == 1, I[i,j] == 0 if i != j

// Rule: Multiplication by Identity is a no-op O(1) conceptually, or O(N*M) if copy needed
matrix_multiply(I : IdentityMatrix<N>, A : Matrix<T, N, M>) → A;


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
matrix_multiply(A : Matrix<T, N, M>, I : IdentityMatrix<M>) → A;
```
### Permutation Matrices
Permutation matrices represent permutations and form a structure isomorphic to the Symmetric Group S_N. They consist of only 0s and 1s, with exactly one '1' per row and column.

```orbit
// Domain definition
PermutationMatrix<N> ⊂ Matrix<Int, N, N>

// Property: Corresponds to a permutation σ ∈ S_N

// Rule: Multiplication of permutation matrices corresponds to permutation composition O(N)
matrix_multiply(P1 : PermutationMatrix, P2 : PermutationMatrix) : S_N →
	permutation_matrix(compose_permutations(permutation(P1), permutation(P2))) : PermutationMatrix;

// Rule: Multiplication by a permutation matrix permutes rows or columns of another matrix O(N*M or N*P)
matrix_multiply(P : PermutationMatrix, A : Matrix<T, N, M>) → permute_rows(A, permutation(P));
matrix_multiply(A : Matrix<T, N, M>, P : PermutationMatrix<M>) → permute_columns(A, permutation(P));
```

### Symmetric / Hermitian Matrices
Symmetric matrices (`A = Aᵀ`) and Hermitian matrices (`A = Aᴴ`, for complex entries where Aᴴ is the conjugate transpose) exhibit reflective symmetry across the main diagonal.

```orbit
// Domain definitions
SymmetricMatrix<T, N> ⊂ Matrix<T, N, N> // For real or general fields (A[i,j] == A[j,i])
HermitianMatrix<T, N> ⊂ Matrix<T, N, N>   // For T ⊂ Complex (A[i,j] == conjugate(A[j,i]))

// Rule: Preserve symmetry/Hermitian property under certain operations
add(A : SymmetricMatrix, B : SymmetricMatrix) → add(A, B) : SymmetricMatrix;
matrix_multiply(transpose(P), matrix_multiply(A : SymmetricMatrix, P)) : SymmetricMatrix;
// A Hermitian => A is normal (A*Aᴴ = Aᴴ*A)

// Note: Multiplication A*B doesn't preserve symmetry unless A,B commute.
multiply(A: HermitianMatrix, conjugate_transpose(A)) ↔ multiply(conjugate_transpose(A), A: HermitianMatrix);

// Note: Specialized algorithms for eigendecomposition or solving systems (e.g., LDLᵀ) leverage this structure.
// Orbit might rewrite a general solver call to a specialized one if A : SymmetricMatrix.
```

### Skew-Symmetric / Skew-Hermitian Matrices
These matrices have anti-symmetry across the diagonal (`A = -Aᵀ` or `A = -Aᴴ`).

```orbit
// Domain definitions
SkewSymmetricMatrix<T, N> ⊂ Matrix<T, N, N> // A[i,j] == -A[j,i], A[i,i] == 0
SkewHermitianMatrix<T, N> ⊂ Matrix<T, N, N> // A[i,j] == -conjugate(A[j,i]), A[i,i] is purely imaginary or 0

// Rule: Preserve skew property under addition/scaling.
add(A : SkewSymmetricMatrix, B : SkewSymmetricMatrix) → add(A, B) : SkewSymmetricMatrix;

// Note: Eigenvalues are purely imaginary or zero. Used in Lie algebras (see matrix4.md).
```

### Orthogonal / Unitary Matrices
These matrices represent rotations/reflections and preserve vector norms. Their inverse is their transpose (orthogonal) or conjugate transpose (unitary).

```orbit
// Domain definitions
OrthogonalMatrix<T, N> ⊂ Matrix<T, N, N> // T ⊂ Real, Aᵀ*A = A*Aᵀ = I
UnitaryMatrix<T, N> ⊂ Matrix<T, N, N>   // T ⊂ Complex, Aᴴ*A = A*Aᴴ = I

// Rule: Product of orthogonal/unitary matrices is orthogonal/unitary (closure under multiplication - forms a group)
matrix_multiply(A : OrthogonalMatrix, B : OrthogonalMatrix) → matrix_multiply(A, B) : OrthogonalMatrix;
matrix_multiply(A : UnitaryMatrix, B : UnitaryMatrix) → matrix_multiply(A, B) : UnitaryMatrix;

// Rule: Multiplication involving inverse simplifies to Identity (O(N²) for explicit I, or no-op)
matrix_multiply(transpose(A : OrthogonalMatrix), A) → IdentityMatrix<N>;
matrix_multiply(A, transpose(A : OrthogonalMatrix)) → IdentityMatrix<N>;
matrix_multiply(conjugate_transpose(A : UnitaryMatrix), A) → IdentityMatrix<N>;
matrix_multiply(A, conjugate_transpose(A : UnitaryMatrix)) → IdentityMatrix<N>;

// Rule: Multiplication preserves norm (conceptual rule, useful for symbolic reasoning)
// norm(matrix_multiply(A : OrthogonalMatrix, x : Vector)) → norm(x);
```

### Triangular Matrices (Upper and Lower)
Triangular matrices have all zeros above (lower triangular) or below (upper triangular) the main diagonal. They are crucial in linear algebra solvers (e.g., Gaussian elimination results in LU decomposition).

```orbit
// Domain definitions
UpperTriangularMatrix<T, N> ⊂ Matrix<T, N, N> // M[i,j] == 0 if i > j
LowerTriangularMatrix<T, N> ⊂ Matrix<T, N, N> // M[i,j] == 0 if i < j

// Rule: Product of same-type triangular matrices is triangular. Standard O(N³) but with reduced loop bounds.
// Example for Upper * Upper: C[i, j] = sum(k=i to j, A[i, k] * B[k, j])
matrix_multiply(A : UpperTriangularMatrix, B : UpperTriangularMatrix) : MatrixMultiply →
	compute_triangular_product(A, B, "upper") : UpperTriangularMatrix;

// Rule: Multiplication by a general matrix also has reduced loops.
// Example for Upper * General: C[i, j] = sum(k=i to N-1, A[i, k] * B[k, j])
matrix_multiply(A : UpperTriangularMatrix, B : Matrix<T, N, P>) →
	compute_triangular_general_product(A, B, "upper");

// Note: Solving Ax=b is O(N²) for triangular A (forward/backward substitution).
// Orbit can rewrite `solve(A:UpperTriangular, b)` to `backward_substitution(A,b)`.
// (See matrix3.md for decompositions leading to triangular systems)
```

### Banded Matrices
Non-zero elements are confined to a band around the main diagonal. Tridiagonal and pentadiagonal matrices are common special cases.

```orbit
// Domain definition
BandedMatrix<T, N, L_BW, U_BW> ⊂ Matrix<T, N, N> // L_BW=lower bandwidth, U_BW=upper bandwidth
// Property: A[i,j] == 0 if j < i - L_BW or j > i + U_BW

// Subtypes:
TridiagonalMatrix<T, N> ⊂ BandedMatrix<T, N, 1, 1>

// Rule: Multiplication has reduced loop bounds. Result bandwidth sums up.
// Complexity can be O(N * L_BW * U_BW') or similar, much better than O(N³).
matrix_multiply(A : BandedMatrix<_, N, L1, U1>, B : BandedMatrix<_, N, L2, U2>) →
	compute_banded_product(A, B) : BandedMatrix<_, N, L1+L2, U1+U2>;

// Rule: Specialized O(N) algorithms for solving tridiagonal systems (Thomas algorithm).
// Orbit can rewrite `solve(A:TridiagonalMatrix, b)` to `thomas_algorithm(A,b)`.
```

### Circulant Matrices
Each row is a cyclic shift of the row above it. They are related to the Cyclic Group C_N and polynomial multiplication modulo x^N - 1. Multiplication is equivalent to circular convolution.

```orbit
// Domain definition
CirculantMatrix<T, N> ⊂ Matrix<T, N, N>
// Property: C[i, j] = c[(j - i) mod N] (defined by its first row/column)

// Rule: Multiplication is circular convolution of the generating vectors, O(N log N) via FFT if T supports it.
matrix_multiply(C1 : CirculantMatrix, C2 : CirculantMatrix) : C_N !: ViaFFT →
	circulant_matrix(circular_convolution(first_row_vector(C1), first_row_vector(C2))) : CirculantMatrix;

// Rule: Connect circular convolution to FFT (Fast Fourier Transform)
circular_convolution(a, b) : Convolution →
	ifft(elementwise_multiply(fft(a), fft(b))) : ViaFFT // elementwise_multiply is Hadamard product
	if supports_fft(T);

// Rule: Multiplication of Circulant matrix by vector also via FFT, O(N log N).
matrix_multiply(C : CirculantMatrix, x : Vector) : C_N !: ViaFFT →
	ifft(elementwise_multiply(fft(first_row_vector(C)), fft(x))) : Vector : ViaFFT
	if supports_fft(T);
```

### Toeplitz Matrices
Matrices with constant diagonals (T[i, j] = t[j - i]). They can be multiplied efficiently, often by embedding them into larger Circulant matrices.

```orbit
// Domain definition
ToeplitzMatrix<T, N> ⊂ Matrix<T, N, N>
// Property: T[i, j] = t[j - i]

// Rule: Embed Toeplitz into Circulant for multiplication, O(N log N).
matrix_multiply(T1 : ToeplitzMatrix, T2 : ToeplitzMatrix) : MatrixMultiply !: ViaCirculant →
	let N_embed = choose_embedding_size_for_toeplitz(N); // e.g., >= 2*N-1, power of 2
	let C1 = embed_toeplitz_in_circulant(T1, N_embed);
	let C2 = embed_toeplitz_in_circulant(T2, N_embed);
	let C_result = matrix_multiply(C1, C2); // Uses Circulant multiplication (FFT)
	extract_toeplitz_from_circulant(C_result, N) : ToeplitzProduct : ViaCirculant;
```

### Hankel Matrices
Matrices with constant skew-diagonals (H[i, j] = h[i + j]). They are related to Toeplitz matrices via permutation.

```orbit
// Domain definition
HankelMatrix<T, N> ⊂ Matrix<T, N, N>
// Property: H[i, j] = h[i + j]

// Rule: Convert to Toeplitz via permutation matrix J (anti-diagonal 1s).
// H = J * T_H or H = T'_H * J, where T_H, T'_H are Toeplitz.
hankel_to_toeplitz(H : HankelMatrix, J : AntiDiagonalIdentity) → matrix_multiply(J, H); // Results in a Toeplitz matrix

// Rule: Multiplication via conversion to Toeplitz/Circulant/FFT, O(N log N).
matrix_multiply(H1 : HankelMatrix, H2 : HankelMatrix) : MatrixMultiply !: ViaToeplitz →
	let J = anti_diagonal_identity_matrix(N);
	let T1_equiv = matrix_multiply(J, H1); // T1_equiv is Toeplitz
	// H1*H2 = J*T1_equiv*H2. For H1*H2, typically H1*J*T2_equiv = T_prod_equiv
	// This requires careful handling of the permutation J.
	// A common strategy is: H*x = J*T*x (if H=JT)
	// Or transform H to T, multiply T*T, then transform result back if product is Hankel.
	// More directly: Fast Hankel-vector products exist.
	fast_hankel_vector_product(H1, H2) : HankelProduct : ViaSpecializedAlgo;
```

### Sparse Matrices
Matrices with a large proportion of zero elements. Operations can skip multiplications/additions involving zero. The best algorithm depends on the sparse format (CSR, CSC, COO, etc.) and the sparsity patterns.

```orbit
// Domain definition (conceptual, Format is part of the type)
SparseMatrix<T, N, M, Format> ⊂ Matrix<T, N, M>
// Example Formats: CSR (Compressed Sparse Row), CSC (Compressed Sparse Column), COO (Coordinate list)

// Rule: Generic understanding that zero elements are skipped.
// C[i, j] = sum(k where A[i,k]!=0 && B[k,j]!=0, A[i, k] * B[k, j])
// This is more effectively handled by format-specific algorithms.

// Rule: Use format-specific algorithms. Complexity varies, e.g., O(N + M + nnz_result) for A*B.
matrix_multiply(A : SparseMatrix<CSR>, B : SparseMatrix<CSC>) →
	sparse_multiply_csr_csc(A, B) : SparseMatrix<ResultFormat>;

matrix_multiply(A : SparseMatrix<COO>, x : Vector) →
	sparse_multiply_coo_vector(A, x) : Vector;
```

### Low-Rank Matrices
Matrices that can be represented or approximated as the product of two smaller matrices (`M = U * Vᵀ`), common in machine learning (e.g., embeddings, matrix factorization).

```orbit
// Domain definition
LowRankMatrix<T, N, M, K> ⊂ Matrix<T, N, M>
// Property: M = U * Vᵀ where U is N x K, V is M x K, and K << N, M (rank K)

// Represent explicitly as factors
low_rank_factors(U : Matrix<T, N, K>, V : Matrix<T, M, K>) → M : LowRankMatrix<T, N, M, K>;

// Rule: Optimize multiplication using associativity. Avoid forming the full M.
// (U*Vᵀ)*B = U*(Vᵀ*B). Complexity: M*K*P (for Vᵀ*B) + N*K*P (for U*result). If Vᵀ is K*M.
matrix_multiply(A : LowRankMatrix<_, N, M, K_A>, B : Matrix<T, M, P>) →
	let {U_A, V_A} = get_factors(A);
	matrix_multiply(U_A, matrix_multiply(transpose(V_A), B))
	if (K_A*P < N*M); // Heuristic: intermediate V_Aᵀ*B is smaller than forming A

// A*(U*Vᵀ) = (A*U)*Vᵀ. Complexity: N*M*K_B (for A*U_B) + N*K_B*P (for result*V_Bᵀ).
matrix_multiply(A : Matrix<T, N, M>, B : LowRankMatrix<_, M, P, K_B>) →
	let {U_B, V_B} = get_factors(B);
	matrix_multiply(matrix_multiply(A, U_B), transpose(V_B))
	if (N*K_B < M*P); // Heuristic: intermediate A*U_B is smaller than forming B

// (U_A*V_Aᵀ)*(U_B*V_Bᵀ) = U_A * (V_Aᵀ*U_B) * V_Bᵀ
matrix_multiply(A : LowRankMatrix<_, N, M, K_A>, B : LowRankMatrix<_, M, P, K_B>) →
	let {U_A, V_A} = get_factors(A);
	let {U_B, V_B} = get_factors(B);
	let Intermediate = matrix_multiply(transpose(V_A), U_B); // K_A x K_B matrix
	matrix_multiply(U_A, matrix_multiply(Intermediate, transpose(V_B)));
```

### Embedding Matrices & One-Hot Vectors
A common machine learning operation involves multiplying an embedding matrix (tall, `VocabSize x EmbedDim`) by a one-hot vector (representing a word index), which simplifies to a lookup.

```orbit
// Domain definitions
EmbeddingMatrix<T, VocabSize, EmbedDim> ⊂ Matrix<T, VocabSize, EmbedDim>
OneHotVector<N, HotIndex> ⊂ Vector<Int, N> // Vector with one '1' at HotIndex, rest '0'

// Rule: Multiplication is a lookup (effectively O(EmbedDim) to copy the row).
matrix_multiply(E : EmbeddingMatrix<_, V, D>, x : OneHotVector<V, Idx>) →
	get_row(E, Idx) : Vector<T, D>;
```

### Stochastic Matrices
Matrices whose rows or columns sum to 1 (representing probability distributions), common in areas like Markov chains or from softmax operations.

```orbit
// Domain definitions
RowStochasticMatrix<T, N, M> ⊂ Matrix<T, N, M>    // sum(M[i, j] for j) = 1 for all i
ColStochasticMatrix<T, N, M> ⊂ Matrix<T, N, M>    // sum(M[i, j] for i) = 1 for all j
DoublyStochasticMatrix<T, N> ⊂ RowStochasticMatrix<T, N, N>, ColStochasticMatrix<T, N, N>

// Rule: Simplify sums involving stochastic dimensions.
// Example: Sum of elements in a row of (A * P) where P is RowStochasticMatrix
// sum_cols( (A * P)[i, :] ) = sum_cols( A[i, :] )
sum_over_cols(matrix_multiply(A : Matrix<T, N, M>, P : RowStochasticMatrix<T, M, P>), i_row) →
	row_sum(A, i_row);

sum_over_rows(matrix_multiply(P : ColStochasticMatrix<T, N, M>, B : Matrix<T, M, P>), j_col) →
	col_sum(B, j_col);
```

## Other Relevant Operations Interacting with Structures

While not matrix types themselves, these operations are fundamental and their interaction with structured matrices can lead to further optimizations.

### Hadamard Product (Element-wise Product)
Denoted `A ∘ B` or `A .* B`, where `C[i, j] = A[i, j] * B[i, j]`.

```orbit
// Operation definition
hadamard_product(A : Matrix<T, N, M>, B : Matrix<T, N, M>) : ElementwiseOp → C : Matrix<T, N, M>;

// Properties: Commutative (S₂), Associative, Distributes over matrix addition.

// Rule: Interaction with Diagonal matrices
// hadamard_product(D : DiagonalMatrix, M : Matrix) results in a matrix where off-diagonal elements of M are zeroed.
// C[i,i] = D[i,i]*M[i,i], C[i,j] = 0 for i!=j if M is not diagonal.
// If M is also Diagonal, then hadamard_product(D1:Diag, D2:Diag) is Diag with D1[i,i]*D2[i,i].

// Rule: Trace identity: trace(Aᵀ * (B ∘ C)) = sum_{i,j} A[i,j] * B[i,j] * C[i,j]
// This might be useful in gradient computations in ML.
```

### Kronecker Product
Creates a larger matrix `A ⊗ B` from smaller matrices `A` and `B`.

```orbit
// Operation definition
kronecker_product(A : Matrix<T, N, M>, B : Matrix<T, P, Q>) : TensorOp → C : Matrix<T, N*P, M*Q>;

// Key Property (Mixed Product Property):
// (A ⊗ B) * (C ⊗ D) = (A * C) ⊗ (B * D)  (if inner dimensions match for A*C and B*D)
matrix_multiply(kronecker_product(A, B), kronecker_product(C, D)) →
	kronecker_product(matrix_multiply(A, C), matrix_multiply(B, D))
	if can_multiply(A, C) && can_multiply(B, D);

// Other properties that can be rewrite rules:
// transpose(A ⊗ B) = transpose(A) ⊗ transpose(B)
// inverse(A ⊗ B) = inverse(A) ⊗ inverse(B) (if A, B invertible)
// trace(A ⊗ B) = trace(A) * trace(B)

// Rule: Vec-trick identity
// (A ⊗ B) * vec(X) = vec(B * X * Aᵀ) where vec(X) stacks columns of X into a vector.
matrix_multiply(kronecker_product(A, B), vec(X : Matrix<_,M,Q>)) → // Assuming B is PxQ, A is NxM
	vec(matrix_multiply(B, matrix_multiply(X, transpose(A))));
```

## Conclusion

By recognizing and annotating these diverse matrix structures, Orbit can move beyond generic matrix algorithms. It applies domain-specific knowledge encoded as rewrite rules to select or derive highly efficient computational strategies. This leads to a system that can automatically optimize matrix operations for specific contexts, significantly improving performance for structured problems common in scientific computing, machine learning, and engineering.

The next documents in this series will explore matrix decompositions ([`matrix3.md`](./matrix3.md)) and advanced analytical topics like matrix functions and eigen-problems ([`matrix4.md`](./matrix4.md)).
