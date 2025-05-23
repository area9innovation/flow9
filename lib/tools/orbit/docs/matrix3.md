# Matrix Decompositions and Factorizations via Orbit's Rewriting

## Introduction

Matrix decompositions (also known as factorizations) are fundamental tools in linear algebra, allowing us to express a matrix as a product of other matrices with simpler, more desirable properties (e.g., triangular, diagonal, orthogonal). These decompositions are key to solving linear systems, computing inverses and determinants, understanding matrix properties (like rank), and forming the basis for many advanced algorithms.

This document, following from [`matrix1.md`](./matrix1.md) and [`matrix2.md`](./matrix2.md), explores how Orbit's symbolic rewriting capabilities can be used to derive, represent, and utilize common matrix decompositions. Orbit aims not just to call pre-defined decomposition routines but to understand their construction and properties through algebraic manipulation.


## Block Matrix Operations and Schur Complements in Orbit

Orbit can reason about matrices partitioned into blocks. Operations on these block matrices can be defined using rewrite rules. We primarily use `assemble_blocks([[A,B],[C,D]])` to denote a 2x2 block matrix constructed from matrix blocks A, B, C, and D, and `block(M, row_splits, col_splits)` to decompose a matrix (as seen in `matrix1.md`).

### Block Matrix Representation
A 2x2 block matrix `M` composed of blocks `A` (top-left), `B` (top-right), `C` (bottom-left), and `D` (bottom-right) is represented as:
`M = assemble_blocks([[A, B], [C, D]])`

### Block Matrix Addition
Addition of two conformingly partitioned block matrices is performed block-wise:
```orbit
// Rule for adding two 2x2 block matrices
assemble_blocks([[A1, B1], [C1, D1]]) + assemble_blocks([[A2, B2], [C2, D2]]) →
	assemble_blocks([[A1 + A2, B1 + B2], [C1 + C2, D1 + D2]]);
```

### Block Matrix Multiplication
Block matrix multiplication is detailed in `matrix1.md`. The rule effectively computes:
`M1 * M2 → assemble_blocks([[A1*A2_11 + B1*A2_21, ...], ..., ...])`
(Refer to `matrix1.md` for the explicit `A * B : MatrixMultiply !: Blocked` rule).

### Schur Complement Definition
The Schur complement is defined as a conditional expression.
```orbit
// Schur complement of block A in M = [[A,B],[C,D]]
define_schur_A(A, B, C, D) : Matrix
	if is_invertible(A) → D - C * inverse(A) * B;

// Schur complement of block D in M = [[A,B],[C,D]]
define_schur_D(A, B, C, D) : Matrix
	if is_invertible(D) → A - B * inverse(D) * C;
```

### Block Matrix Inversion using Schur Complements
The inverse of a 2x2 block matrix can be expressed using the Schur complement.
```orbit
inverse(assemble_blocks([[A, B], [C, D]])) : Matrix
	if is_invertible(A) →
		let S_A = define_schur_A(A, B, C, D);
		if is_invertible(S_A) →
			let invA = inverse(A);
			let invS_A = inverse(S_A);
			assemble_blocks([
				[invA + invA * B * invS_A * C * invA,  -(invA * B * invS_A)],
				[-(invS_A * C * invA),                invS_A]
			]);
	// A similar rule can be defined if D is invertible using S_D.
```
(Note: `-X` denotes `negate(X)` or direct unary minus if supported for matrices).

### Block LDU Decomposition and Schur Complements
The Schur complement appears in the block LDU decomposition of a matrix.
```orbit
// M = L * D_block * U
// L and U are unitriangular block matrices, D_block is block diagonal.
assemble_blocks([[A,B],[C,D]]) : BlockLDUProduct
  if is_invertible(A) →
	let invA = inverse(A);
	let S_A = define_schur_A(A, B, C, D); // Schur Complement of A
	// L factor: [[I, 0], [C*invA, I]]
	let L_factor = assemble_blocks([
		[IdentityMatrix_like(A), ZeroMatrix_like(B)],
		[C * invA,               IdentityMatrix_like(D)]
	  ]);
	// D_block factor (block diagonal): [[A, 0], [0, S_A]]
	let D_block_factor = assemble_blocks([
		[A,                  ZeroMatrix_like(B)],
		[ZeroMatrix_like(C), S_A]
	  ]);
	// U factor: [[I, invA*B], [0, I]]
	let U_factor = assemble_blocks([
		[IdentityMatrix_like(A), invA * B],
		[ZeroMatrix_like(C),     IdentityMatrix_like(D)]
	  ]);
	L_factor * D_block_factor * U_factor;
// Assumes IdentityMatrix_like(X) and ZeroMatrix_like(X) generate
// identity/zero matrices with dimensions compatible with X.
```

### Properties and Applications as Orbit Rules

1.  **Determinants via Schur Complements:**
    ```orbit
	det(assemble_blocks([[A,B],[C,D]])) : Scalar
	  if is_invertible(A) → det(A) * det(define_schur_A(A,B,C,D));

	det(assemble_blocks([[A,B],[C,D]])) : Scalar
	  if is_invertible(D) → det(D) * det(define_schur_D(A,B,C,D));
```

2.  **Solving Linear Systems (Recursive Strategy):**
    A system `M*x = y` where `M`, `x`, `y` are block-partitioned can be solved by reducing it to a system involving the Schur complement.
    ```orbit
	// System: assemble_blocks([[A,B],[C,D]]) * assemble_block_vector([[x1],[x2]]) = assemble_block_vector([[y1],[y2]])
	// This rule defines a strategy to find x1, x2.
	solve_block_system(
		assemble_blocks([[A,B],[C,D]]),
		assemble_block_vector([[y1],[y2]])
	  ) : BlockVectorSolution
	  if is_invertible(A) →
		let S_A = define_schur_A(A,B,C,D);
		if is_invertible(S_A) → // S_A must be invertible to solve the reduced system
		  let invA = inverse(A);
		  let y2_prime = y2 - C*invA*y1;
		  let x2_solution = solve_system(S_A, y2_prime); // solve_system is a general solver for non-block system S_A
		  let x1_solution = invA*(y1 - B*x2_solution);
		  assemble_block_vector([[x1_solution],[x2_solution]]);
	// assemble_block_vector is a conceptual constructor for block vectors.
	// solve_system(Matrix, Vector) is assumed to be a general system solving mechanism.
```

3.  **Positive Definiteness:**
    The positive definiteness of a block matrix `M` is related to the positive definiteness of `A` and its Schur complement `S_A`.
    ```orbit
	// M = assemble_blocks([[A,B],[C,D]])
	is_positive_definite(assemble_blocks([[A,B],[C,D]])) : TruthValue ↔
		is_positive_definite(A) ∧ is_positive_definite(define_schur_A(A,B,C,D));
	// This relies on the property that if M is PD, then A must be PD (and thus invertible).
```

Schur complements and block matrix operations provide powerful symbolic and computational tools that Orbit can leverage through these rewrite rules.


3.  **Inertia and Positive Definiteness:** The inertia (number of positive, negative, and zero eigenvalues) of `M` is related to the inertia of `A` and `S_A`. Specifically, `M` is positive definite if and only if `A` is positive definite and `S_A` is positive definite.

4.  **Numerical Analysis:** Schur complement methods are widely used in solving large sparse linear systems and in domain decomposition methods for PDEs.

The Schur complement is a fundamental tool in matrix theory and numerical linear algebra, providing a way to break down problems involving large matrices into smaller, more manageable pieces. Orbit can represent the formation of Schur complements and use their properties in simplification and decomposition rules.


## LU Decomposition

LU decomposition factors a square matrix `A` into the product of a lower triangular matrix `L` (often with unit diagonal) and an upper triangular matrix `U`, such that `A = LU`.

```orbit
// Domain definitions
LowerTriangularUnitDiag<T, N> ⊂ LowerTriangularMatrix<T, N> // L[i,i] = 1

// Conceptual decomposition rule
decompose_lu(A : Matrix<T, N, N>) : Decomposition → { L : LowerTriangularUnitDiag, U : UpperTriangularMatrix }
	where L * U = A;
```

**Orbit's Role in LU Decomposition:**

1.  **Symbolic Gaussian Elimination:** The process of Gaussian elimination to obtain `U` can be represented as a sequence of rewrite rules applying elementary row operations to `A`. These operations simultaneously build up `L` (as the inverse of the product of elementary matrices corresponding to these row operations).
    ```orbit
	// Elementary Row Operations as rewrite rules (conceptual)
	// E_add_row(i, j, c) * M  → M' (adds c * row_j to row_i of M)
	// L_factor would accumulate inverses: L = ... * inv(E_add_row(k,l,m))

	// Rule: If A is reducible to U via E_ops, and L is inv(E_ops_product)
	A → L_from_elimination(A) * U_from_elimination(A);
```

2.  **Pivoting (LUP/PLU Decomposition):** For numerical stability and to handle cases where a zero pivot is encountered, row interchanges (permutations) are used. This leads to `PA = LU` or `A = PLU`, where `P` is a PermutationMatrix.
    ```orbit
	// Domain for permutation matrix from S_N (see matrix2.md)
	decompose_lup(A : Matrix<T, N, N>) : Decomposition → { P : PermutationMatrix, L : LowerTriangularUnitDiag, U : UpperTriangularMatrix }
		where P * A = L * U;
```
    Orbit can manage the permutation matrix `P` by applying permutation rules and tracking row swaps during symbolic elimination.

**Applications Derivable in Orbit:**

*   **Solving Linear Systems (`Ax = b`):**
    ```orbit
	solve_system(A, b) where A = L*U → solve_system_lu(L, U, b);
	solve_system_lu(L, U, b) → backward_substitution(U, forward_substitution(L, b));
	// forward_substitution and backward_substitution are O(N²) for triangular systems.
```

*   **Computing Determinants:**
    ```orbit
	det(A) where A = L*U → det(L) * det(U);
	det(L : LowerTriangularUnitDiag) → 1;
	det(U : UpperTriangularMatrix) → product_of_diagonal_elements(U);
	// If PA=LU, then det(P)det(A) = det(L)det(U) => sgn(P)det(A) = det(U)
	det(A) where P*A = L*U → sign(P) * product_of_diagonal_elements(U);
```

*   **Matrix Inversion:**
    `A⁻¹ = (LU)⁻¹ = U⁻¹L⁻¹`. Inverting triangular matrices is easier (though explicit inversion is often avoided).

## Cholesky Decomposition

For a symmetric (or Hermitian) positive definite matrix `A`, Cholesky decomposition finds a unique lower triangular matrix `L` with positive diagonal entries such that `A = LLᵀ` (or `A = RRᵀ` where `R` is upper triangular, `R=Lᵀ`).

```orbit
// Domain for positive definite matrices (see matrix2.md for SymmetricMatrix)
PositiveDefiniteMatrix<T,N> ⊂ SymmetricMatrix<T,N>

// Conceptual decomposition rule
decompose_cholesky(A : PositiveDefiniteMatrix<T, N>) : Decomposition → { L : LowerTriangularMatrix }
	where L * Lᵀ = A && all(L[i,i] > 0);
```

**Orbit's Role in Cholesky Decomposition:**

1.  **Domain Verification:** Orbit first needs rules to verify or infer that `A` is indeed symmetric and positive definite. Properties like `eigenvalues(A) > 0` or positive leading principal minors can be used.
2.  **Symbolic Algorithm:** The formulas for computing entries of `L` can be expressed as rewrite rules:
    `L[j,j] = sqrt(A[j,j] - sum(k=0 to j-1, L[j,k]²))`
    `L[i,j] = (1/L[j,j]) * (A[i,j] - sum(k=0 to j-1, L[i,k]*L[j,k]))` for `i > j`.
    Orbit could symbolically expand these summations for small N or use them to guide transformations.
3.  **Uniqueness as Canonical Form:** The resulting `L` (with positive diagonals) is unique, making it a canonical factor for positive definite matrices.

**Applications Derivable in Orbit:**

*   **Efficiently Solving Linear Systems:** `Ax = b` becomes `LLᵀx = b`. Solve `Ly = b` then `Lᵀx = y`.
*   **Statistical Computations:** E.g., generating multivariate normal random variables, evaluating Gaussian likelihoods where the covariance matrix is positive definite.
*   **Numerical Optimization:** Used in methods like Newton's method when dealing with Hessian matrices.

## QR Decomposition

QR decomposition factors a matrix `A` into `A = QR`, where `Q` is an orthogonal (or unitary) matrix and `R` is an upper triangular matrix.

```orbit
// OrthogonalMatrix and UpperTriangularMatrix domains from matrix2.md

// Conceptual decomposition rule
decompose_qr(A : Matrix<T, M, N>) : Decomposition → { Q : OrthogonalMatrix<M>, R : UpperTriangularMatrix<M,N> } // if M >= N
	where Q * R = A;
```

**Orbit's Role in QR Decomposition:**

1.  **Symbolic Gram-Schmidt Process:** The classical Gram-Schmidt process (or modified versions for stability) can be represented symbolically in Orbit to orthogonalize the columns of `A` to form `Q`, with `R` capturing the coefficients.
    ```orbit
	// q_i = (a_i - sum_j<i proj(q_j, a_i)) / ||...||
	// R[j,i] = q_j ⋅ a_i
	// Orbit would apply rules for vector projection, normalization, dot products.
```
2.  **Symbolic Householder Reflections or Givens Rotations:** More stable methods involve applying a sequence of Householder reflections or Givens rotations to `A` to transform it into `R`, while `Q` is the product of these orthogonal transformations.
    ```orbit
	// Householder transformation H = I - 2vvᵀ/(vᵀv)
	// A -> H_1*A -> H_2*H_1*A -> ... -> H_k*...*H_1*A = R
	// Q = H_1ᵀ*H_2ᵀ*...*H_kᵀ = H_1*H_2*...*H_k (since H is symmetric orthogonal)
	// Orbit could represent H_i as specific OrthogonalMatrix instances and manage their product.
```
3.  **Canonicalization of Q and R:** `R` can be made unique by requiring its diagonal elements to be non-negative. `Q` is then uniquely determined. Orbit can enforce this (e.g., by multiplying rows of `Q` and corresponding columns of `R` by -1 if `R[i,i] < 0`).

**Applications Derivable in Orbit:**

*   **Solving Linear Least-Squares Problems:** For `Ax = b` where `A` is `M x N` with `M > N` (overdetermined), `QRx = b` => `R x = Qᵀb`. This is an upper triangular system solvable by back substitution.
*   **Eigenvalue Computations (QR Algorithm):** Iteratively computes QR decompositions (`A_k = Q_k R_k`) and then forms `A_{k+1} = R_k Q_k`. Under certain conditions, `A_k` converges to a triangular or quasi-triangular form revealing eigenvalues.

## Singular Value Decomposition (SVD)

SVD factors any `M x N` matrix `A` into `A = UΣVᵀ`, where:
*   `U` is an `M x M` orthogonal matrix (columns are left singular vectors).
*   `Σ` is an `M x N` diagonal matrix with non-negative real numbers (singular values) in decreasing order on its diagonal.
*   `V` is an `N x N` orthogonal matrix (columns are right singular vectors, `Vᵀ` has rows as right singular vectors).

```orbit
// Diagonal matrix with specific ordering properties
SingularValueDiagonalMatrix<T,M,N> ⊂ DiagonalMatrix<T,M,N>
// Property: Σ[i,i] >= Σ[i+1,i+1] >= 0

// Conceptual decomposition rule
decompose_svd(A : Matrix<T, M, N>) : Decomposition →
	{ U : OrthogonalMatrix<M>, Sigma : SingularValueDiagonalMatrix<T,M,N>, V : OrthogonalMatrix<N> }
	where U * Sigma * Vᵀ = A;
```

**Orbit's Role in SVD:**

1.  **Symbolic Derivation (Conceptual):** While a full symbolic derivation of SVD is very complex for general matrices, Orbit can reason about its properties. The singular values `σᵢ` are the square roots of the non-zero eigenvalues of `AᵀA` (and `AAᵀ`). The columns of `V` are eigenvectors of `AᵀA`, and columns of `U` are eigenvectors of `AAᵀ`.
    ```orbit
	// If A = UΣVᵀ then AᵀA = VΣᵀUᵀUΣVᵀ = VΣᵀΣVᵀ
	// And AAᵀ = UΣVᵀVΣᵀUᵀ = UΣΣᵀUᵀ
	// These relate SVD to eigenvalue decomposition of AᵀA and AAᵀ.
	eigen_problem(Aᵀ * A) → {eigenvalues=σᵢ², eigenvectors=cols_of_V };
	eigen_problem(A * Aᵀ) → {eigenvalues=σᵢ², eigenvectors=cols_of_U };
```
2.  **Canonical Form:** The SVD is unique up to choices of signs in columns of `U` and `V` (which must be consistent). The convention of non-negative and sorted singular values in `Σ` makes `Σ` canonical. Orbit can enforce this ordering.
3.  **Utilizing SVD Properties:** Orbit can use SVD properties for simplification and analysis even if it relies on an external routine for the decomposition itself.
    ```orbit
	rank(A) where A = U*Sigma*Vᵀ → number_of_non_zero_singular_values(Sigma);
	condition_number(A) where A = U*Sigma*Vᵀ → max_singular_value(Sigma) / min_non_zero_singular_value(Sigma);
```

**Applications Derivable in Orbit:**

*   **Determining Matrix Rank and Condition Number.**
*   **Low-Rank Matrix Approximation:** The best rank-`k` approximation of `A` is obtained by keeping the largest `k` singular values in `Σ` and setting others to zero. Orbit could perform this truncation symbolically.
*   **Computing Pseudo-Inverse (`A⁺`):** `A⁺ = VΣ⁺Uᵀ`, where `Σ⁺` is formed by taking reciprocals of non-zero singular values and transposing.
    ```orbit
	pseudo_inverse(A) where A=U*Sigma*Vᵀ → V * Σ⁺ * Uᵀ;
```
*   **Principal Component Analysis (PCA):** SVD of the (centered) data matrix is a common way to perform PCA.

## General Strategy for Decompositions in Orbit

For Orbit to effectively work with decompositions:

1.  **Domain Annotation:** Matrices resulting from decompositions (L, U, Q, R, Σ, etc.) should be annotated with their specific domains (e.g., `:UpperTriangularMatrix`, `:OrthogonalMatrix`, `:SingularValueDiagonalMatrix`).
2.  **Property Enforcement:** Rewrite rules should enforce the defining properties of these domains (e.g., `L[i,j] = 0 if i<j` for a lower triangular matrix, `QᵀQ = I` for orthogonal).
3.  **Uniqueness/Canonicalization:** Where unique forms exist (e.g., Cholesky `L` with positive diagonals, `R` in QR with non-negative diagonals, sorted `Σ` in SVD), Orbit should strive to canonicalize to these forms.
4.  **Application Rules:** Rewrite rules should exist to transform operations on the original matrix `A` into simpler operations on its factors. For example, `solve(A,b)` → `solve_lu(L,U,b)`.
5.  **Conditional Derivation:** Rules that derive decompositions (`decompose_lu(A) → ...`) might be expensive. They could be triggered conditionally, by user request, or as part of a higher-level optimization strategy when Orbit determines a decomposition would be beneficial for subsequent operations.

## Conclusion

Matrix decompositions are powerful algebraic tools that simplify matrix structure and enable efficient algorithms. By representing the process of decomposition and the properties of the resulting factors within its symbolic rewriting framework, Orbit can:

*   Symbolically perform or reason about the steps involved in factorizations.
*   Exploit the simplified structure of factored matrices to optimize subsequent computations (e.g., solving linear systems, computing determinants).
*   Use canonical forms of factors (where they exist) to aid in equality checking and expression simplification.

This capability moves Orbit beyond simply applying black-box numerical routines towards a deeper, symbolic understanding and manipulation of matrix factorizations, further enhancing its power in optimizing linear algebra expressions. The next document, [`matrix4.md`](./matrix4.md), will cover advanced analytical topics like matrix functions and a more detailed look at eigen-problems.
