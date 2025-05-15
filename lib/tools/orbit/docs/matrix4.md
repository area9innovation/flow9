# Advanced Matrix Analysis in Orbit: Functions, Eigen-problems, and Lie Theory

## Introduction

This document expands on the foundational matrix concepts discussed in [`matrix1.md`](./matrix1.md), [`matrix2.md`](./matrix2.md), and [`matrix3.md`](./matrix3.md). It delves into more advanced analytical aspects of matrix algebra, focusing on how Orbit can represent, reason about, and optimize:

1.  **Matrix Trace:** Its properties, symmetries, use cases, and canonicalization in Orbit.
2.  **Matrix Determinant:** Its properties, geometric interpretation, use cases, and canonicalization in Orbit.
3.  **Detailed Eigenvalue and Eigenvector Problems:** Building on the initial introduction, exploring deeper properties and computational implications.
4.  **Matrix Functions:** Applying scalar functions (like exponential, logarithm, powers) to matrix arguments.
5.  **Introduction to Matrix Lie Groups and Lie Algebras:** Formalizing the connection between certain matrix groups and their associated algebraic structures.

Orbit's strength lies in using its symbolic rewriting engine, domain annotations, and group-theoretic canonicalization to manage the complexities inherent in these advanced topics.

## Matrix Trace

The **trace** of a square matrix `M`, denoted `tr(M)`, is the sum of the elements on its main diagonal. It's a fundamental concept in linear algebra with various applications.

```orbit
// Definition of Trace for an N x N matrix
trace(M : Matrix<T, N, N>) : Scalar<T> → sum(i, 0, N-1, M[i, i]);
```

### Key Properties of the Trace

The trace exhibits several important algebraic properties, which can be expressed as rewrite rules in Orbit:

1.  **Linearity:** The trace is a linear map.
    *   `tr(A + B) → tr(A) + tr(B)`
    *   `tr(c * A) → c * tr(A)` (where `c` is a scalar)

2.  **Cyclic Property (Invariance under cyclic permutations):**
    *   `tr(A * B) → tr(B * A)`
    *   This extends to products of multiple matrices: `tr(A * B * C) → tr(B * C * A) → tr(C * A * B)`.
    *   This property highlights that the trace is invariant under the action of the Cyclic Group Cₖ (acting on the order of k matrices in a product by cyclic permutation).

3.  **Transpose Invariance:** The trace of a matrix is equal to the trace of its transpose.
    *   `tr(M) → tr(Mᵀ)`

4.  **Similarity Invariance:** The trace is invariant under similarity transformations.
    *   If `P` is an invertible matrix, then `tr(P⁻¹ * A * P) → tr(A)`.
    *   This crucial property implies that the trace is an invariant of a linear transformation, regardless of the basis chosen.

### Symmetries and Use Cases of the Trace

The invariances of the trace connect it to deeper mathematical symmetries and make it a valuable tool:

1.  **Eigenvalue Analysis:**
    *   `tr(A) = sum(eigenvalues(A))`. This is consistent with similarity invariance, as similar matrices share eigenvalues.

2.  **Character Theory in Group Representations:**
    *   The trace of a matrix representing a group element is its "character". Characters are constant on conjugacy classes due to trace's similarity invariance.

3.  **Machine Learning and Statistics:**
    *   **Dimensionality Reduction (PCA):** Trace optimization often appears, e.g., maximizing `tr(XᵀCX)`.
    *   **Regularization:** The nuclear norm (trace norm), `||A||_* = tr(sqrt(Aᵀ*A))`, is used for low-rank matrix completion.
    *   **Model Complexity:** `tr(HatMatrix)` gives effective parameters in linear models.
    *   **Covariance Matrices:** `tr(Σ)` is total variance.

4.  **Numerical Linear Algebra:**
    *   **Trace Estimation:** For large `f(A)`, `tr(f(A))` can be estimated efficiently using stochastic methods (e.g., Hutchinson's estimator), often relying on the cyclic property.

5.  **Graph Theory:**
    *   `tr(Adj^k)` counts closed walks of length `k` in a graph.

6.  **Physics:**
    *   **Quantum Mechanics:** Expectation value `tr(ρO)`; density matrix normalization `tr(ρ) = 1`.
    *   **Statistical Mechanics:** Partition functions `Z = tr(exp(-βH))`.

### Inferring Group Symmetries for Canonicalization in Orbit (Trace)

Orbit leverages trace properties to infer symmetries and apply canonicalization:

1.  **Cyclic Symmetry in Products: `tr(M₁ * M₂ * ... * Mₖ)`**
    The property `tr(AB) = tr(BA)` implies `Cₖ` symmetry for the argument list under the trace.
    *   **Orbit Inference:**
        ```orbit
		tr(M₁ * M₂ * ... * Mₖ) ⊢ tr_arg_list : Cₖ;
		// tr_arg_list refers to (M₁, ..., Mₖ)
```
    *   **Canonical Form:** Apply `canonicalise_cyclic_efficient` (e.g., Booth's algorithm) to the argument list.
        ```orbit
		tr(arg_list : Cₖ) → tr(canonicalise_cyclic_efficient(arg_list));
		// Example: tr(A*B*C) and tr(B*C*A) map to the same canonical form.
```

2.  **Similarity Transformation Invariance: `tr(P⁻¹ * A * P)`**
    *   **Orbit Simplification:**
        ```orbit
		tr(P_inv * A * P)
			if is_inverse(P_inv, P) && is_invertible(P)
			→ tr(A) : GL_Conj_Invariant;
```
        This directly reduces complex expressions to the canonical form `tr(A)`.


3.  **Scalar Factor Commutation with Scalar Matrices:**
    If `c` is a scalar, `tr(c*A) = c*tr(A)` is covered by linearity. For a scalar matrix `S = s*I`:
    ```orbit
	// S is a scalar matrix (S = s*I), A is a matrix
	// The product tr(S*A) exhibits C₂ symmetry for its arguments (S, A).
	tr(S * A)
		⊢ tr_arg_list : C₂;
	// This can be canonicalized, e.g., to tr(A*S) if A < S by canonical order.
	// If S is s*IdentityMatrix, it simplifies further:
	tr(s_identity_matrix(s_val) * A) → s_val * tr(A);
```

## Matrix Determinant

The **determinant** of a square matrix `M`, denoted `det(M)` or `|M|`, is a scalar value encoding properties of the matrix and its linear transformation.

```orbit
// Conceptual definition
determinant(M : Matrix<T, N, N>) : Scalar<T> → compute_determinant_value(M);
```

### Key Properties of the Determinant

Orbit uses these properties as rewrite rules:

1.  **Identity Matrix**: `determinant(I : IdentityMatrix<N>) → 1`
2.  **Multiplicative Property**: `determinant(A * B) → determinant(A) * determinant(B)`
    *   This implies `det` is a homomorphism from GL(n,F) to F*.
3.  **Transpose Invariance**: `determinant(Mᵀ) → determinant(M)`
4.  **Scalar Multiplication**: `determinant(c * A : Matrix<_,N,N>) → c^N * determinant(A)`
5.  **Inverse Matrix**: `determinant(A⁻¹) → 1 / determinant(A)` (if `det(A) ≠ 0`)
6.  **Singular Matrices**:
    *   If `A` has a zero row/column or identical rows/columns, `determinant(A) → 0`.
    *   `is_invertible(A) ↔ determinant(A) ≠ 0`.
    *   `determinant(M : SingularMatrix) → 0;`
7.  **Triangular Matrices**: `determinant(M : TriangularMatrix) → product_of_diagonal_elements(M)`
8.  **Effect of Row/Column Operations**:
    *   Swapping two rows/columns: `determinant(swap_rows(A, r1, r2)) → -determinant(A)` (Alternating property).
    *   Scaling a row/column by `c`: `determinant(scale_row(A, r, c)) → c * determinant(A)`
    *   Adding a multiple of one row/column to another: `determinant(add_multiple_to_row(A,...)) → determinant(A)`

### Symmetries, Invariances, and Geometric Interpretation (Determinant)

1.  **Similarity Invariance**: `determinant(P⁻¹ * A * P) → determinant(A)` (if `P` invertible).
    *   The determinant is a class function on GL(n,F).
2.  **Volume Scaling Factor**: `abs(determinant(A))` is how `A` scales volumes. Sign indicates orientation preservation/reversal.
3.  **Alternating Multilinear Form**: The determinant is an alternating multilinear function of matrix columns/rows, connecting it to permutations (Sₙ) and their signs via the Leibniz formula: `det(A) = sum(σ in S_n, sgn(σ) * product(A[i, σ(i)]))`.

### Use Cases of the Determinant

*   Checking invertibility.
*   Solving linear systems (Cramer's Rule).
*   Eigenvalue problems (characteristic polynomial `det(A - λI) = 0`).
*   Change of variables in integration (Jacobian determinant).
*   Geometric algorithms.

### Inferring Group Symmetries and Properties for Canonicalization in Orbit (Determinant)

1.  **Direct Simplification from Domains**:
    ```orbit
	determinant(M : SLnF_Matrix) → 1;
	determinant(M : OrthogonalMatrix) → result where result * result = 1; // ±1
	determinant(M : SingularMatrix) → 0;
	determinant(M : TriangularMatrix) → product_of_diagonal_elements(M);
```
2.  **Exploiting Alternating Property (Sₙ Connection)**:
    ```orbit
	determinant(permute_rows(A, σ)) → sign(σ) * determinant(A);
```
3.  **Leveraging Multiplicative Property**:
    ```orbit
	determinant(A * D) → determinant(A) * product_of_diagonal_elements(D);
```
4.  **Canonicalization via Similarity Invariance**:
    ```orbit
	determinant(P_inv * A * P)
		if is_inverse(P_inv, P) && is_invertible(P)
		→ determinant(A) : GL_Conj_Invariant;
```
5.  **Symbolic Row/Column Reduction**: Orbit can symbolically apply row operations to transform a matrix to triangular form, with the determinant being the product of diagonal elements adjusted by accumulated multipliers/signs. This mirrors Gaussian elimination for determinant computation.

## Detailed Eigenvalue and Eigenvector Analysis

For a square `N × N` matrix `A`, a non-zero vector `v` is an **eigenvector** of `A` if `A v = λ v`, where `λ` is the corresponding **eigenvalue**. This can be rewritten as `(A - λI) v = 0`, which has a non-zero solution for `v` if and only if `det(A - λI) = 0` (the **characteristic equation**).

```orbit
// Conceptual representation in Orbit
eigen_problem(A : Matrix<T,N,N>) → solution_set : EigenSolutionSet
	where solution_set contains pairs (λᵢ : Scalar<T>, vᵢ : Vector<T,N>)
	such that A * vᵢ = λᵢ * vᵢ;

characteristic_poly(A : Matrix<T,N,N>, λ_var : Symbol) → determinant(A - λ_var * IdentityMatrix<N>);

eigenvalues(A : Matrix<T,N,N>) → roots_of(characteristic_poly(A, default_lambda_var));
eigenvectors(A : Matrix<T,N,N>, λ : Scalar<T>) → null_space_vectors(A - λ * IdentityMatrix<N>);
```

### Deeper Properties and Orbit's Handling

1.  **Similarity Invariance (Recap & Canonicalization):**
    If `B = P⁻¹AP`, then `A` and `B` have the same eigenvalues. The eigenvectors are related by `v_B = P⁻¹v_A`.
    ```orbit
	eigenvalues(P_inv * A * P)
		if is_inverse(P_inv, P) && is_invertible(P)
		→ eigenvalues(A) : GL_Conj_Invariant_Spectrum;

	// This rule ensures that the set of eigenvalues for similar matrices
	// can be canonicalized to a single representation in the O-Graph.
```

2.  **Diagonalization:**
    If an `N x N` matrix `A` has `N` linearly independent eigenvectors, it is diagonalizable. This means there exists an invertible matrix `P` (whose columns are the eigenvectors) and a diagonal matrix `D` (whose diagonal entries are the eigenvalues) such that `A = PDP⁻¹`.
    ```orbit
	// Domain for diagonalizable matrices
	DiagonalizableMatrix<T,N> ⊂ Matrix<T,N,N>;

	// Rule: If A is diagonalizable, relate it to its diagonal form.
	A : DiagonalizableMatrix → P_eigenvecs(A) * D_eigenvals(A) * P_inv_eigenvecs(A);

	// Inference: A matrix with N distinct eigenvalues is diagonalizable.
	A where count(distinct(eigenvalues(A))) = N ⊢ A : DiagonalizableMatrix;
	// Real symmetric matrices are always diagonalizable by an orthogonal matrix.
	A : SymmetricMatrix<Real,N> ⊢ A : DiagonalizableMatrix where P_eigenvecs(A) : OrthogonalMatrix;
```
    Diagonalization is a powerful canonical form for certain operations, especially matrix functions.

3.  **Spectral Theorem:**
    For real symmetric matrices (`A = Aᵀ`), eigenvalues are real, and eigenvectors corresponding to distinct eigenvalues are orthogonal. Such matrices are always orthogonally diagonalizable: `A = QDQᵀ` where `Q` is an orthogonal matrix.
    For Hermitian matrices (`A = Aᴴ`), eigenvalues are real, and they are unitarily diagonalizable: `A = UDUᴴ` where `U` is a unitary matrix.
    ```orbit
	A : SymmetricMatrix<Real,N> → Q_ortho_eigenvecs(A) * D_real_eigenvals(A) * Q_ortho_eigenvecs(A)ᵀ;
	A : HermitianMatrix<Complex,N> → U_unitary_eigenvecs(A) * D_real_eigenvals(A) * U_unitary_eigenvecs(A)ᴴ;
```
    Orbit can use these specific forms when the matrix domain is known.

4.  **Jordan Normal/Canonical Form:**
    Not all matrices are diagonalizable. Any square matrix `A` over an algebraically closed field (like Complex numbers) is similar to a Jordan matrix `J`, `A = PJP⁻¹`. `J` is block diagonal with Jordan blocks on its diagonal. Eigenvalues are on the diagonal of `J`.
    While symbolically computing `J` and `P` is complex, Orbit can use the *existence* of such a form or properties of Jordan blocks if provided or inferred.

5.  **Cayley-Hamilton Theorem:**
    Every square matrix `A` satisfies its own characteristic equation: `p(A) = 0`, where `p(λ) = det(A - λI)`. For example, if `p(λ) = λ² + c₁λ + c₀`, then `A² + c₁A + c₀I = 0`.
    ```orbit
	// Rule: A matrix satisfies its characteristic polynomial.
	// If char_poly_coeffs(A) = [c_n, c_{n-1}, ..., c_1, c_0] (for p(λ)=c_nλⁿ+...+c_1λ+c_0)
	// Then: c_n*A^n + ... + c_1*A + c_0*IdentityMatrix = ZeroMatrix
	evaluate_polynomial_on_matrix(char_poly(A), A) → ZeroMatrix<N,N>;
```
    This can be used to simplify higher powers of `A` or express `A⁻¹` as a polynomial in `A`.

### Key Properties of Eigenvalues and Eigenvectors

1.  **Sum and Product:**
    *   `tr(A) = Σ λᵢ` (sum of eigenvalues).
    *   `det(A) = Π λᵢ` (product of eigenvalues).
2.  **Transpose:** `A` and `Aᵀ` have the same eigenvalues.
3.  **Matrix Powers:** If `λ` is an eigenvalue of `A` (eigenvector `v`):
    *   `λᵏ` is an eigenvalue of `Aᵏ` (eigenvector `v`).
    *   `1/λ` is an eigenvalue of `A⁻¹` (if `A` invertible, eigenvector `v`).
4.  **Scalar Multiplication:** `cλ` is an eigenvalue of `cA`.
5.  **Shift Property:** `λ - s` is an eigenvalue of `A - sI`.
6.  **Triangular/Diagonal Matrices:** Eigenvalues are the diagonal entries.
7.  **Linear Independence:** Eigenvectors for distinct eigenvalues are linearly independent.
8.  **Symmetric Matrices (Real):**
    *   Eigenvalues are real.
    *   Eigenvectors for distinct eigenvalues are orthogonal.
    *   Always diagonalizable by an orthogonal matrix (`A = QDQᵀ`).
9.  **Positive Definite Matrices:** Symmetric matrix with all eigenvalues `λᵢ > 0`.

### Symmetries and Invariances Related to Eigen-Problems

*   **Similarity Invariance:** Similar matrices (`B = P⁻¹AP`) have the same characteristic polynomial and thus the same eigenvalues. If `v` is an eigenvector of `A` for `λ`, then `P⁻¹v` is an eigenvector of `B` for `λ`. This is a cornerstone for canonicalization.

### Use Cases of Eigenvalues and Eigenvectors

1.  **Principal Component Analysis (PCA):** Eigenvalues/vectors of covariance matrix guide dimensionality reduction.
2.  **Quantum Mechanics:** Eigenvalues of Hamiltonians are energy levels; eigenvectors are stationary states.
3.  **Vibrational Analysis:** Natural frequencies and mode shapes.
4.  **Stability of Dynamical Systems:** Eigenvalues of system matrix determine stability.
5.  **Spectral Graph Theory:** Eigenvalues of adjacency/Laplacian matrices reveal graph properties (connectivity, clustering).
6.  **Google's PageRank:** Principal eigenvector of a modified web graph matrix.
7.  **Solving Differential Equations.**

### Exploiting Eigen-Properties for Canonicalization and Simplification in Orbit

1.  **Recognizing Characteristic Equation:**
    ```orbit
	determinant(A - λ_var * I) ⊢ is_characteristic_poly_of(A, λ_var);
```
2.  **Relating to Trace/Determinant:**
    ```orbit
	tr(A) where eigenvalues_of(A) = {λ₁, ..., λₙ} → sum(λ₁, ..., λₙ);
	determinant(A) where eigenvalues_of(A) = {λ₁, ..., λₙ} → product(λ₁, ..., λₙ);
```
3.  **Canonicalization via Diagonalization (Similarity Invariance):**
    If `A` is diagonalizable (`A = PDP⁻¹`), `D` (diagonal matrix of eigenvalues) is a canonical form for spectral properties.
    ```orbit
	A : DiagonalizableBy P → P * D_eigenvalues(A) * P_inv;
	eigenvalues(A) where A = P * D_diag * P_inv → diagonal_elements_of(D_diag);
```
4.  **Simplifying Powers/Inverses based on Eigenvalues:**
    ```orbit
	eigenvalues_of(A^k) → map(λ x. x^k, eigenvalues_of(A));
	eigenvalues_of(A⁻¹) → map(λ x. 1/x, eigenvalues_of(A)) if A : Invertible;
```
5.  **Domain-Specific Eigenvalue Properties:**
    ```orbit
	A : SymmetricMatrix ⊢ eigenvalues_of(A) : RealNumbersSet;
	A : PositiveDefiniteMatrix ⊢ eigenvalues_of(A) : PositiveRealNumbersSet;
	A : OrthogonalMatrix ⊢ map(λ x. abs(x), eigenvalues_of(A)) = {1, ..., 1};
	A : TriangularMatrix ⊢ eigenvalues_of(A) = diagonal_elements_of(A);
```
6.  **Unifying Eigenvalue Sets via Similarity Invariance:**
    ```orbit
	eigenvalues(P_inv * A * P)
		if is_inverse(P_inv, P) && is_invertible(P)
		→ eigenvalues(A) : GL_Conj_Invariant_Spectrum;
```
    This ensures expressions for eigenvalues of similar matrices canonicalize to the same representation.

7.  **Spectral Theorem for Symmetric/Hermitian Matrices:**
    Enables rewriting to orthogonally/unitarily diagonalized forms.
    ```orbit
	A : SymmetricMatrix<Real,N> → Q_ortho_eigenvecs(A) * D_real_eigenvals(A) * Q_ortho_eigenvecs(A)ᵀ;
```
8.  **Cayley-Hamilton Theorem Application:**
    `p(A) = 0` where `p` is the characteristic polynomial of `A`.
    ```orbit
	evaluate_polynomial_on_matrix(char_poly(A), A) → ZeroMatrix<N,N>;
	// This can simplify A^k for k >= N, or A⁻¹
```

## Matrix Functions

Applying a scalar function `f(x)` to a square matrix `A` results in a matrix `f(A)`. This is well-defined for analytic functions (those with a convergent Taylor series).

1.  **Via Taylor Series Expansion:**
    If `f(x) = Σ aᵢxⁱ`, then `f(A) = Σ aᵢAⁱ` (where `A⁰ = I`).
    ```orbit
	// Example: Matrix Exponential
	matrix_exponential(A : Matrix<T,N,N>) → IdentityMatrix<N> + A + A²/2! + A³/3! + ... : TaylorSeriesExpansion;
	// Orbit would need rules for symbolic series manipulation and convergence criteria.
```

2.  **Via Diagonalization (Most Practical Symbolic Approach):**
    If `A` is diagonalizable, `A = PDP⁻¹`, then `f(A) = P f(D) P⁻¹`. `f(D)` is computed by applying `f` to each diagonal element of `D`.
    ```orbit
	// Rule: Apply function via diagonalization
	f(A : DiagonalizableMatrix) →
		P_eigenvecs(A) * f_on_diagonal(D_eigenvals(A), f) * P_inv_eigenvecs(A);

	f_on_diagonal(D_diag : DiagonalMatrix, f_scalar_func) →
		diagonal_matrix(map(f_scalar_func, diagonal_elements_of(D_diag)));

	// Specific example for matrix_power
	A^k where A : DiagonalizableMatrix →
		P_eigenvecs(A) * matrix_power_diag(D_eigenvals(A), k) * P_inv_eigenvecs(A);
	matrix_power_diag(D_diag, k) → diagonal_matrix(map(λx. x^k, diagonal_elements_of(D_diag)));
```
    This is often the most effective way for Orbit to handle matrix functions symbolically.

3.  **Via Jordan Normal Form:**
    If `A = PJP⁻¹`, then `f(A) = P f(J) P⁻¹`. Computing `f(J)` involves applying `f` to Jordan blocks, which can be done using Taylor series for each block.

4.  **Exponentiation by Squaring for Matrix Powers (`Aᵏ`):**
    This is an algorithmic optimization rather than a matrix function definition, but crucial for computing powers efficiently. Orbit can represent this as a recursive rewrite strategy:
    ```orbit
	A^k : RequiresMultiplication →
		if k = 0 then IdentityMatrix<N>
		else if k = 1 then A
		else if is_even(k) then (A²)^(k/2) // A^k = (A^2)^(k/2)
		else A * A^(k-1); // A^k = A * A^(k-1)
```

### Normal Matrix
A complex square matrix A is normal if it commutes with its conjugate transpose: A Aᴴ = Aᴴ A. If A is a real matrix, it is normal if A Aᵀ = Aᵀ A. Normal matrices are precisely those that are unitarily diagonalizable (or orthogonally diagonalizable if real).

```orbit
// Domain definition
NormalMatrix<T, N> ⊂ Matrix<T, N, N>

// Property: A * Aᴴ = Aᴴ * A (for T ⊂ Complex)
// Property: A * Aᵀ = Aᵀ * A (for T ⊂ Real)

// Rule: All Hermitian, Skew-Hermitian, Unitary (and their real counterparts: Symmetric, Skew-Symmetric, Orthogonal) matrices are Normal.
A : HermitianMatrix ⊢ A : NormalMatrix;
A : SkewHermitianMatrix ⊢ A : NormalMatrix;
A : UnitaryMatrix ⊢ A : NormalMatrix;
A : SymmetricMatrix ⊢ A : NormalMatrix;
A : SkewSymmetricMatrix ⊢ A : NormalMatrix;
A : OrthogonalMatrix ⊢ A : NormalMatrix;

// Rule: Normal matrices are unitarily (or orthogonally if real) diagonalizable.
A : NormalMatrix<Complex,N> → U_unitary_eigenvecs(A) * D_complex_eigenvals(A) * U_unitary_eigenvecs(A)ᴴ;
A : NormalMatrix<Real,N> → Q_ortho_eigenvecs(A) * D_real_eigenvals(A) * Q_ortho_eigenvecs(A)ᵀ;

// Property: Eigenvectors corresponding to distinct eigenvalues are orthogonal.
```
**Use Cases:** This is a broad theoretical class. Its main importance is guaranteeing unitary/orthogonal diagonalizability, simplifying many analyses and computations, especially for matrix functions and spectral theory.

### Unipotent Matrix
A matrix A is unipotent if all its eigenvalues are 1. Equivalently, the matrix A - I is nilpotent.

```orbit
// Domain definition
UnipotentMatrix<T, N> ⊂ Matrix<T, N, N>

// Property: All eigenvalues are 1.
eigenvalues(A : UnipotentMatrix) → set_of_ones(N);

// Property: A - I is nilpotent.
(A : UnipotentMatrix) - IdentityMatrix<N> : NilpotentMatrix;

// Rule: Determinant is 1.
determinant(A : UnipotentMatrix) → 1;

// Rule: Trace is N.
trace(A : UnipotentMatrix) → N;

// Note: If A is unipotent, then (A-I)^k = 0 for some k <= N.
// The group of unipotent upper triangular matrices is important in Lie theory (e.g., a Sylow p-subgroup of GL(n, F_p)).
```
**Use Cases:** Theory of algebraic groups, Lie groups (e.g., unipotent subgroups), representation theory.

### Companion Matrix
A companion matrix is a specific sparse matrix whose characteristic polynomial is directly related to its entries. For a monic polynomial p(x) = c₀ + c₁x + ... + c_{n-1}x^{n-1} + xⁿ, the companion matrix is:
```
[[0, 0, ..., 0, -c₀],
 [1, 0, ..., 0, -c₁],
 [0, 1, ..., 0, -c₂],
 [..., ..., ..., ..., ...],
 [0, 0, ..., 1, -c_{n-1}]]
```

```orbit
// Domain definition
CompanionMatrix<T, N> ⊂ Matrix<T, N, N> // For a polynomial of degree N

// Property: The characteristic polynomial of CompanionMatrix(coeffs) is p(x) = sum(coeffs[i]*x^i) + x^N.
characteristic_poly(C : CompanionMatrix, x) → define_poly_from_coeffs(get_coeffs(C), x);

// Rule: Eigenvalues are the roots of the associated polynomial.
eigenvalues(C : CompanionMatrix) → roots_of_polynomial(get_coeffs(C));

// Note: Companion matrices are generally not symmetric, but can be useful for finding roots of polynomials via eigenvalue algorithms.
```
**Use Cases:** Finding roots of polynomials, control theory (state-space representation).

### Vandermonde Matrix
A Vandermonde matrix V is defined by a sequence of scalars x₁, ..., x_m. For an n-row Vandermonde matrix (often m=n):
$V_{ij} = x_i^{j-1}$ (for 0-indexed columns j=0..n-1) or $V_{ij} = x_i^{j}$ (for 1-indexed columns j=1..n).
Example for n columns, 0-indexed:
```
[[1, x₁, x₁², ..., x₁ⁿ⁻¹],
 [1, x₂, x₂², ..., x₂ⁿ⁻¹],
 ...
 [1, x_m, x_m², ..., x_mⁿ⁻¹]]
```

```orbit
// Domain definition
VandermondeMatrix<T, M, N> ⊂ Matrix<T, M, N> // M rows, N columns, based on M points x_i

// Property: If M=N, det(V) = product_{1 ≤ i < k ≤ N} (x_k - x_i).
// Invertible if and only if all x_i are distinct (when M=N).
determinant(V : VandermondeMatrix<_,N,N>) → compute_vandermonde_determinant(get_points(V))
	if N = num_points(V);

// Note: Multiplication by a Vandermonde matrix (or its transpose) evaluates a polynomial at points x_i (or finds coefficients of interpolating polynomial).
// Fast matrix-vector products (O(M log M) or O(N log N)) are possible using techniques related to FFT for specific choices of x_i (e.g., roots of unity for DFT matrix).
(V : VandermondeMatrix) * (c : Vector) : ViaFastAlgo →
	fast_vandermonde_multiply(V, c) if points_allow_fft_like_algo(get_points(V));
```
**Use Cases:** Polynomial interpolation, least squares fitting, discrete Fourier transform (DFT matrix is a specific Vandermonde matrix), error-correcting codes.

## Introduction to Matrix Lie Groups and Lie Algebras

Certain sets of matrices form continuous groups (Lie groups) under matrix multiplication. These are fundamental in physics, geometry, and differential equations. Each Lie group has an associated Lie algebra, which is a vector space capturing the group's infinitesimal structure.

Orbit can define domains for these groups and algebras and use their properties for rewrites.

### Common Matrix Lie Groups and Their Algebras

| Group        | Description                             | Lie Algebra `g` | Description of `g`                     |
|--------------|-----------------------------------------|-----------------|----------------------------------------|
| `GL(n,F)`    | Invertible `n x n` matrices             | `gl(n,F)`       | All `n x n` matrices                   |
| `SL(n,F)`    | `det(A)=1`                              | `sl(n,F)`       | `tr(X)=0`                              |
| `O(n)`       | Real, `AᵀA=I`                           | `so(n)` (`o(n)`) | Real, skew-symmetric (`Xᵀ = -X`)       |
| `SO(n)`      | `O(n)` and `det(A)=1` (rotations)       | `so(n)`         | Real, skew-symmetric                   |
| `U(n)`       | Complex, `AᴴA=I`                        | `u(n)`          | Complex, skew-Hermitian (`Xᴴ = -X`)    |
| `SU(n)`      | `U(n)` and `det(A)=1`                   | `su(n)`         | Complex, skew-Hermitian, `tr(X)=0`     |


1.  **General Linear Group `GL(n, F)`:** Group of `n x n` invertible matrices over field `F`.
    *   **Lie Algebra `gl(n, F)`:** Space of all `n x n` matrices over `F`. The Lie bracket is the matrix commutator: `[X, Y] = XY - YX`.
    ```orbit
	Matrix<T,N,N> ⊂ gl_algebra<T,N>; // All matrices form the algebra
	matrix_commutator(X,Y) → (X*Y) - (Y*X);
```

2.  **Special Linear Group `SL(n, F)`:** Subgroup of `GL(n, F)` with `det(A) = 1`.
    *   **Lie Algebra `sl(n, F)`:** Space of `n x n` matrices with `tr(X) = 0`.
    ```orbit
	A : Matrix<T,N,N> where determinant(A) = 1 ⊢ A : SLnF_Group;
	X : Matrix<T,N,N> where trace(X) = 0 ⊢ X : slnF_Algebra;
```

3.  **Orthogonal Group `O(n)`:** Group of `n x n` real matrices `A` with `AᵀA = I` (or `A⁻¹ = Aᵀ`).
    *   **Lie Algebra `o(n)` or `so(n)`:** Space of `n x n` real skew-symmetric matrices (`Xᵀ = -X`). (Technically `so(n)` is the algebra for `SO(n)` but often used for `O(n)` as well).
    ```orbit
	A : Matrix<Real,N,N> where Aᵀ * A = IdentityMatrix<N> ⊢ A : On_Group;
	X : Matrix<Real,N,N> where Xᵀ = negate(X) ⊢ X : on_Algebra; // X is skew-symmetric
```

4.  **Special Orthogonal Group `SO(n)`:** Subgroup of `O(n)` with `det(A) = 1` (rotations).
    *   **Lie Algebra `so(n)`:** Same as for `O(n)` (skew-symmetric matrices).

5.  **Unitary Group `U(n)`:** Group of `n x n` complex matrices `A` with `AᴴA = I` (or `A⁻¹ = Aᴴ`).
    *   **Lie Algebra `u(n)`:** Space of `n x n` complex skew-Hermitian matrices (`Xᴴ = -X`).
    ```orbit
	A : Matrix<Complex,N,N> where Aᴴ * A = IdentityMatrix<N> ⊢ A : Un_Group;
	X : Matrix<Complex,N,N> where Xᴴ = negate(X) ⊢ X : un_Algebra; // X is skew-Hermitian
```

6.  **Special Unitary Group `SU(n)`:** Subgroup of `U(n)` with `det(A) = 1`.
    *   **Lie Algebra `su(n)`:** Space of `n x n` complex skew-Hermitian matrices with `tr(X) = 0`.

### The Matrix Exponential Map

The matrix exponential `exp(tX)` maps elements `X` from a Lie algebra to the corresponding Lie group (for scalar `t`).

```orbit
// Rule: Exponential map connects algebra to group
matrix_exponential(X : on_Algebra) : On_Group; // More specifically SO(n) if connected component
matrix_exponential(X : un_Algebra) : Un_Group;
matrix_exponential(X : slnF_Algebra) : SLnF_Group;
// exp(tX) for scalar t
matrix_exponential(t * X) : SO_n_Group; // if X != 0 and X : on_Algebra (type of X is implicit from context)
```
This allows Orbit to reason about transformations between these algebraic structures.

### Rewrite Rules Based on Lie Group/Algebra Properties

*   **Simplifying Inverses:**
    ```orbit
	A⁻¹ where A : On_Group → Aᵀ;
	A⁻¹ where A : Un_Group → Aᴴ;
```
*   **Determinant Properties:**
    ```orbit
	determinant(A : SLnF_Group) → 1;
	determinant(A : SOn_Group) → 1;
	determinant(A : SUn_Group) → 1;
	determinant(A : On_Group) → result where result*result=1; // ±1
```
*   **Commutator Identities (for Lie Algebras):**
    Jacobi Identity: `[X, [Y, Z]] + [Y, [Z, X]] + [Z, [X, Y]] = 0`.
    These can be used for simplifying nested commutator expressions.

*   **Baker-Campbell-Hausdorff (BCH) Formula (Advanced):**
    For `X, Y` in a Lie algebra, `log(exp(X)exp(Y)) = X + Y + 1/2[X,Y] + 1/12[X,[X,Y]] - 1/12[Y,[X,Y]] + ...`
    Orbit could store truncated versions of this formula to approximate or simplify products of matrix exponentials, especially when `X` and `Y` nearly commute.

### The Matrix Exponential Map
`exp(tX)` maps `X` from a Lie algebra to the Lie group.
```orbit
matrix_exponential(t * X) : SO_n_Group;
```

### Rewrite Rules Based on Lie Group/Algebra Properties
*   **Inverses:** `A⁻¹ where A : On_Group → Aᵀ;`
*   **Determinants:** `determinant(A : SLnF_Group) → 1;`
*   **Commutator Identities:** Jacobi identity `[X,[Y,Z]] + [Y,[Z,X]] + [Z,[X,Y]] = 0`.
*   **Baker-Campbell-Hausdorff (BCH) Formula:** For `log(exp(X)exp(Y))`, can simplify products of exponentials.

## Conclusion

Advanced matrix analysis topics like detailed eigen-problems, matrix functions, and Lie theory introduce sophisticated algebraic structures and properties. Orbit, with its strong foundation in symbolic rewriting, domain annotation, and canonicalization, is well-equipped to manage these concepts.

By:
*   Representing eigenvalues and eigenvectors and their invariances (especially similarity).
*   Leveraging diagonalization for computing matrix functions and establishing canonical forms.
*   Defining domains for matrix Lie groups and their associated Lie algebras.
*   Using the matrix exponential to map between these structures.
*   Encoding the algebraic properties of these groups and algebras as rewrite rules.

Orbit can provide powerful tools for simplification, canonicalization, and automated reasoning in these advanced areas of matrix mathematics. This opens up possibilities for optimizing complex scientific and engineering computations that rely heavily on these concepts.
