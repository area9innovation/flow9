# Matrix Decompositions and Factorizations via Orbit's Rewriting

## Introduction

Matrix decompositions (also known as factorizations) are fundamental tools in linear algebra, allowing us to express a matrix as a product of other matrices with simpler, more desirable properties (e.g., triangular, diagonal, orthogonal). These decompositions are key to solving linear systems, computing inverses and determinants, understanding matrix properties (like rank), and forming the basis for many advanced algorithms.

This document, following from [`matrix1.md`](./matrix1.md) and [`matrix2.md`](./matrix2.md), explores how Orbit's symbolic rewriting capabilities can be used to derive, represent, and utilize common matrix decompositions. Orbit aims not just to call pre-defined decomposition routines but to understand their construction and properties through algebraic manipulation.

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
