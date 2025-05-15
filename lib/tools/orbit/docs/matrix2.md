# Leveraging Specialized Matrix Structures in Orbit

## Introduction

Building upon the foundational concepts outlined in [`matrix1.md`](./matrix1.md), this document delves into how Orbit identifies and optimizes operations for matrices possessing specific, exploitable structures. By annotating matrices with their corresponding domains, Orbit can apply highly specialized rewrite rules. These rules often lead to significant computational savings compared to general-purpose algorithms, moving from O(N³) or O(N²) complexities to O(N log N), O(N), or even O(1) in some cases.

## Comprehensive Matrix Hierarchy

Orbit aims to recognize and leverage a rich hierarchy of matrix types. The following hierarchy, based on common mathematical classifications, guides Orbit's domain-specific rule development. Many of these types imply specific storage schemes, computational shortcuts, or algebraic properties that Orbit can exploit.

```text
Tensor<T, ...>
└── Matrix<T, N, M>
    └── SquareMatrix<T, N> (N = M)
        ├── DiagonalMatrix<T, N>
        │   ├── ScalarMatrix<T, N> (all diagonal entries equal)
        │   ├── IdentityMatrix<T, N> (all diagonal entries = 1)
        │   ├── IdempotentMatrix<T, N> (diag entries 0 or 1, D^2 = D)
        │   └── InvolutoryMatrix<T, N> (diag entries ±1, D^2 = I)
        ├── TriangularMatrix<T, N> (Upper or Lower)
        │   ├── UpperTriangularMatrix<T, N>
        │   │   └── DiagonalMatrix<T, N>
        │   └── LowerTriangularMatrix<T, N>
        │       └── DiagonalMatrix<T, N>
        ├── SymmetricMatrix<T, N> (T = Tᵀ)
        │   └── DiagonalMatrix<T, N> (all diagonal matrices are symmetric)
        ├── SkewSymmetricMatrix<T, N> (T = -Tᵀ, diag 0)
        ├── HermitianMatrix<T, N> (complex, T = Tᴴ)
        ├── SkewHermitianMatrix<T, N> (complex, T = -Tᴴ)
        ├── OrthogonalMatrix<T, N> (real, QᵀQ = I)
        │   ├── SpecialOrthogonalMatrix<T, N> (det = 1)
        │   └── ReflectionMatrix<T, N> (det = –1)
        ├── UnitaryMatrix<T, N> (complex, UᴴU = I)
        │   └── SpecialUnitaryMatrix<T, N> (det = 1)
        ├── NormalMatrix<T, N> (AᴴA = AAᴴ, contains Hermitian, Unitary, etc.)
        ├── NilpotentMatrix<T, N, k> (A^k = 0)
        ├── IdempotentMatrix<T, N> (A^2 = A)
        │   └── OrthogonalProjectorMatrix<T, N> (idempotent & symmetric)
        ├── InvolutoryMatrix<T, N> (A^2 = I)
        ├── PermutationMatrix<T, N>
        │   ├── OrthogonalMatrix<T, N>
        │   ├── MonomialMatrix<T, N> (all nonzero entries ±1)
        │   ├── BinaryMatrix<T, N> (entries 0/1)
        │   ├── DoublyStochasticMatrix<T, N> (rows, cols sum to 1)
        │   └── SparseMatrix<T, N, N>
        ├── MonomialMatrix<T, N> (one nonzero per row/col, invertible)
        ├── SparseMatrix<T, N, M>
        ├── BandedMatrix<T, N, L, U>
        │   └── TridiagonalMatrix<T, N>
        │       └── DiagonalMatrix<T, N>
        ├── ToeplitzMatrix<T, N>
        ├── HankelMatrix<T, N>
        ├── CirculantMatrix<T, N>
        ├── HadamardMatrix<T, N> (±1, H Hᵀ = nI)
        ├── VandermondeMatrix<T, N, M>
        ├── LowRankMatrix<T, N, M, k>
        │   └── RankOneMatrix<T, N, M>
        ├── StochasticMatrix<T, N, M> (rows or cols sum to 1)
        │   └── DoublyStochasticMatrix<T, N>
        ├── PartialPermutationMatrix<T, N, M> (rectangular, one 1 per row/col)
        ├── EmbeddingMatrix<T, V, D>
        └── CompanionMatrix<T, N> (used for polynomials)
```

The Orbit rules and domain definitions (`DomainA ⊂ DomainB`) throughout this document and related matrix documents should reflect these relationships. For example, `DiagonalMatrix<T, N> ⊂ SquareMatrix<T, N> ⊂ Matrix<T, N, N>`. Orbit uses these subtype relations to infer properties and apply specialized algorithms.

## Orbit Domain Subtype Rules for Matrix Specializations

The following rules define the subtype relationships between different matrix domains within Orbit. These relationships allow Orbit to infer properties and apply more specific rules or algorithms. The type parameter `T` can be further constrained (e.g., `T : Real`, `T : Complex`, `T : Field`) as needed for specific properties.

```orbit
// General Matrix Structure
Matrix<T, N, M> ⊂ Tensor<T, [N, M]> // Tensor of rank 2
SquareMatrix<T, N> ⊂ Matrix<T, N, N> // Matrix with N=M

// Diagonal and Related Matrices
DiagonalMatrix<T, N> ⊂ SquareMatrix<T, N>
DiagonalMatrix<T, N> ⊂ UpperTriangularMatrix<T, N>
DiagonalMatrix<T, N> ⊂ LowerTriangularMatrix<T, N>
DiagonalMatrix<T, N> ⊂ SymmetricMatrix<T, N>
DiagonalMatrix<T, N> ⊂ HermitianMatrix<T, N> where T : Complex // Or T : Real, becomes Symmetric
ScalarMatrix<T, N> ⊂ DiagonalMatrix<T, N>
IdentityMatrix<T, N> ⊂ ScalarMatrix<T, N>

// Triangular Matrices
UpperTriangularMatrix<T, N> ⊂ SquareMatrix<T, N>
LowerTriangularMatrix<T, N> ⊂ SquareMatrix<T, N>

// Symmetric, Hermitian, and Skew Variations
SymmetricMatrix<T, N> ⊂ SquareMatrix<T, N> // T : Real or general field
SkewSymmetricMatrix<T, N> ⊂ SquareMatrix<T, N> // T : Real or general field
HermitianMatrix<T, N> ⊂ SquareMatrix<T, N> where T : Complex
SkewHermitianMatrix<T, N> ⊂ SquareMatrix<T, N> where T : Complex

// Normal Matrices (Commute with their conjugate transpose)
NormalMatrix<T, N> ⊂ SquareMatrix<T, N>
SymmetricMatrix<T, N> ⊂ NormalMatrix<T, N> where T : Real
HermitianMatrix<T, N> ⊂ NormalMatrix<T, N> where T : Complex
SkewSymmetricMatrix<T, N> ⊂ NormalMatrix<T, N> where T : Real // (A^T A = -A A = A(-A) = A A^T)
SkewHermitianMatrix<T, N> ⊂ NormalMatrix<T, N> where T : Complex
OrthogonalMatrix<T, N> ⊂ NormalMatrix<T, N> where T : Real
UnitaryMatrix<T, N> ⊂ NormalMatrix<T, N> where T : Complex
DiagonalMatrix<T, N> ⊂ NormalMatrix<T, N> // Diagonal matrices are inherently normal

// Orthogonal and Unitary Matrices
OrthogonalMatrix<T, N> ⊂ SquareMatrix<T, N> where T : Real // QᵀQ = I
UnitaryMatrix<T, N> ⊂ SquareMatrix<T, N> where T : Complex   // UᴴU = I
SpecialOrthogonalMatrix<T, N> ⊂ OrthogonalMatrix<T, N> where T : Real // det = 1
SpecialUnitaryMatrix<T, N> ⊂ UnitaryMatrix<T, N> where T : Complex   // det = 1
ReflectionMatrix<T, N> ⊂ OrthogonalMatrix<T, N> where T : Real     // det = -1
// Scaled Hadamard implies Orthogonal:
// HadamardMatrix<T,N> where T: Field implies (1/sqrt(N)) * H : OrthogonalMatrix<FieldWithSqrt, N>

// Permutation Matrices (Elements 0 or 1, one '1' per row/col)
PermutationMatrix<N> ⊂ SquareMatrix<Int, N> // Typically Int elements 0,1
PermutationMatrix<N> ⊂ OrthogonalMatrix<Real, N>      // Interpreted as Real for orthogonality
PermutationMatrix<N> ⊂ MonomialMatrix<Real, N>
PermutationMatrix<N> ⊂ DoublyStochasticMatrix<Real, N>
PermutationMatrix<N> ⊂ BinaryMatrix<Int, N>
PermutationMatrix<N> ⊂ SparseMatrix<Int, N, N>
PermutationMatrix<N> ⊂ InvertibleMatrix<Field, N> // Interpreted over a Field

// Specialized Algebraic Properties
NilpotentMatrix<T, N, K_Nilpotency> ⊂ SquareMatrix<T, N> // A^k = 0
IdempotentMatrix<T, N> ⊂ SquareMatrix<T, N>             // A^2 = A
InvolutoryMatrix<T, N> ⊂ SquareMatrix<T, N>             // A^2 = I
OrthogonalProjectorMatrix<T, N> ⊂ IdempotentMatrix<T, N>
OrthogonalProjectorMatrix<T, N> ⊂ SymmetricMatrix<T, N> where T : Real
OrthogonalProjectorMatrix<T, N> ⊂ HermitianMatrix<T, N> where T : Complex

// Banded and Sparse Structures
SparseMatrix<T, N, M, Format> ⊂ Matrix<T, N, M>
BandedMatrix<T, N, L_BW, U_BW> ⊂ SquareMatrix<T, N>
TridiagonalMatrix<T, N> ⊂ BandedMatrix<T, N, 1, 1>

// Rank-Based Structures
LowRankMatrix<T, N, M, K_Rank> ⊂ Matrix<T, N, M>
RankOneMatrix<T, N, M> ⊂ LowRankMatrix<T, N, M, 1>

// Specific Patterns and Applications
StochasticMatrix<T, N, M> ⊂ Matrix<T, N, M> // General non-negative with sum constraints
RowStochasticMatrix<T, N, M> ⊂ StochasticMatrix<T, N, M>
ColStochasticMatrix<T, N, M> ⊂ StochasticMatrix<T, N, M>
DoublyStochasticMatrix<T, N> ⊂ RowStochasticMatrix<T, N, N> // Also ColStochastic
DoublyStochasticMatrix<T, N> ⊂ ColStochasticMatrix<T, N, N>

ToeplitzMatrix<T, N> ⊂ SquareMatrix<T, N>
HankelMatrix<T, N> ⊂ SquareMatrix<T, N>
CirculantMatrix<T, N> ⊂ ToeplitzMatrix<T, N> // Also subset of Hankel if symmetric

MonomialMatrix<T, N> ⊂ SquareMatrix<T, N> // One non-zero per row/col

EmbeddingMatrix<T, VocabSize, EmbedDim> ⊂ Matrix<T, VocabSize, EmbedDim>
CompanionMatrix<T, N> ⊂ SquareMatrix<T, N>
VandermondeMatrix<T, N, M> ⊂ Matrix<T, N, M>
HadamardMatrix<N> ⊂ SquareMatrix<Int, N> // Entries +1, -1. H H^T = n I
// Note: (1/sqrt(N)) * H : OrthogonalMatrix<Real, N> if H : HadamardMatrix<N>
```

## Exploiting Special Matrix Structures

Orbit's domain system allows it to recognize and apply tailored algorithms for various matrix types.

### Identity Matrix

The identity matrix acts as the multiplicative identity in the matrix ring.

TODO: Add rule that recognizes the identity matrix.

```orbit
// Domain definition
IdentityMatrix<N> ⊂ DiagonalMatrix<Int, N> // Typically {0, 1} elements
// Property: I[i,i] == 1, I[i,j] == 0 if i != j

// Rule: Multiplication by Identity is a no-op O(1) conceptually, or O(N*M) if copy needed
(I : IdentityMatrix<N>) * (A : Matrix<T, N, M>) → A;
(A : Matrix<T, N, M>) * (I : IdentityMatrix<M>) → A;
```

### Diagonal Matrices

TODO: Add rule that recognizes the identity matrix.

```orbit
// Domain definition
DiagonalMatrix<T, N> ⊂ Matrix<T, N, N>

// Property: M[i,j] == 0 if i != j

// Rule: Multiplication of diagonal matrices is element-wise O(N)
(A : DiagonalMatrix) * (B : DiagonalMatrix) : MatrixMultiply →
	diag_matrix([A[i,i] * B[i,i] for i = 0 to N-1]) : DiagonalMatrix;

// Rule: Multiplication by a diagonal matrix scales rows or columns O(N*P or N*M)
(A : DiagonalMatrix) * (B : Matrix<T, N, P>) →
	matrix([[A[i,i] * B[i,j] for j=0..P-1] for i=0..N-1]); // Row scaling
(A : Matrix<T, N, M>) * (B : DiagonalMatrix) →
	matrix([[A[i,j] * B[j,j] for j=0..M-1] for i=0..N-1]); // Column scaling
```

### Permutation Matrices

Permutation matrices represent permutations and form a structure isomorphic to the Symmetric Group S_N. They consist of only 0s and 1s, with exactly one '1' per row and column.

TODO: Add rule that recognizes a permutation matrix.

```orbit
// Domain definition
PermutationMatrix<N> ⊂ Matrix<Int, N, N>

// Property: Corresponds to a permutation σ ∈ S_N

// Rule: Multiplication of permutation matrices corresponds to permutation composition O(N)
(P1 : PermutationMatrix) * (P2 : PermutationMatrix) : S_N →
	permutation_matrix(compose_permutations(permutation(P1), permutation(P2))) : PermutationMatrix;

// Rule: Multiplication by a permutation matrix permutes rows or columns of another matrix O(N*M or N*P)
(P : PermutationMatrix) * (A : Matrix<T, N, M>) → permute_rows(A, permutation(P));
(A : Matrix<T, N, M>) * (P : PermutationMatrix<M>) → permute_columns(A, permutation(P));
```

### Symmetric / Hermitian Matrices

Symmetric matrices (`A = Aᵀ`) and Hermitian matrices (`A = Aᴴ`, for complex entries where Aᴴ is the conjugate transpose) exhibit reflective symmetry across the main diagonal.

```orbit
// Domain definitions
SymmetricMatrix<T, N> ⊂ Matrix<T, N, N> // For real or general fields (A[i,j] == A[j,i])
HermitianMatrix<T, N> ⊂ Matrix<T, N, N>   // For T ⊂ Complex (A[i,j] == conjugate(A[j,i]))

// Rule: Preserve symmetry/Hermitian property under certain operations
(A : SymmetricMatrix) + (B : SymmetricMatrix) → A + B : SymmetricMatrix;
Pᵀ * ((A : SymmetricMatrix) * P) : SymmetricMatrix;
// A Hermitian => A is normal (A*Aᴴ = Aᴴ*A)

// Note: Multiplication A*B doesn't preserve symmetry unless A,B commute.
(A: HermitianMatrix) * Aᴴ ↔ Aᴴ * (A: HermitianMatrix);

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
(A : SkewSymmetricMatrix) + (B : SkewSymmetricMatrix) → A + B : SkewSymmetricMatrix;

// Note: Eigenvalues are purely imaginary or zero. Used in Lie algebras (see matrix4.md).
```

### Orthogonal / Unitary Matrices

These matrices represent rotations/reflections and preserve vector norms. Their inverse is their transpose (orthogonal) or conjugate transpose (unitary).

```orbit
// Domain definitions
OrthogonalMatrix<T, N> ⊂ Matrix<T, N, N> // T ⊂ Real, Aᵀ*A = A*Aᵀ = I
UnitaryMatrix<T, N> ⊂ Matrix<T, N, N>   // T ⊂ Complex, Aᴴ*A = A*Aᴴ = I

// Rule: Product of orthogonal/unitary matrices is orthogonal/unitary (closure under multiplication - forms a group)
(A : OrthogonalMatrix) * (B : OrthogonalMatrix) → A * B : OrthogonalMatrix;
(A : UnitaryMatrix) * (B : UnitaryMatrix) → A * B : UnitaryMatrix;

// Rule: Multiplication involving inverse simplifies to Identity (O(N²) for explicit I, or no-op)
(A : OrthogonalMatrix)ᵀ * A → IdentityMatrix<N>;
A * (A : OrthogonalMatrix)ᵀ → IdentityMatrix<N>;
(A : UnitaryMatrix)ᴴ * A → IdentityMatrix<N>;
A * (A : UnitaryMatrix)ᴴ → IdentityMatrix<N>;

// Rule: Multiplication preserves norm (conceptual rule, useful for symbolic reasoning)
norm((A : OrthogonalMatrix) * (x : Vector)) → norm(x);
```

### Special Orthogonal Group SO(n)

The Special Orthogonal Group SO(n) consists of all n×n orthogonal matrices with a determinant of +1. These matrices represent orientation-preserving isometries, typically rotations in n-dimensional Euclidean space. SO(n) is a subgroup of O(n).

```orbit
// Domain definition
SpecialOrthogonalMatrix<T, N> ⊂ OrthogonalMatrix<T, N> // T is typically Real
// Or: SO<N> ⊂ O<N> (if using shorter group symbols as domains)

// Properties:
// M ∈ SO(n) ⇔ Mᵀ * M = I ∧ det(M) = 1

// Rule: Product of SO(n) matrices is SO(n)
(A : SpecialOrthogonalMatrix) * (B : SpecialOrthogonalMatrix) →
	A * B : SpecialOrthogonalMatrix;

// Rule: Inverse of SO(n) matrix is its transpose and is SO(n)
(A : SpecialOrthogonalMatrix)⁻¹ → Aᵀ : SpecialOrthogonalMatrix;

```
**Use Cases:** SO(2) for 2D rotations, SO(3) for 3D rotations (robotics, aerospace, computer graphics).
norm((A : OrthogonalMatrix) * (x : Vector)) → norm(x);
```

### Special Unitary Group SU(n)

The Special Unitary Group SU(n) consists of all n×n unitary matrices with a determinant of +1. These matrices preserve the complex inner product and are crucial in quantum mechanics. SU(n) is a subgroup of U(n).

```orbit
// Domain definition
SpecialUnitaryMatrix<T, N> ⊂ UnitaryMatrix<T, N> // T is typically Complex
// Or: SU<N> ⊂ U<N>

// Properties:
// M ∈ SU(n) ⇔ Mᴴ * M = I ∧ det(M) = 1 (where Mᴴ is conjugate transpose)

// Rule: Product of SU(n) matrices is SU(n)
(A : SpecialUnitaryMatrix) * (B : SpecialUnitaryMatrix) →
	A * B : SpecialUnitaryMatrix;

// Rule: Inverse of SU(n) matrix is its conjugate transpose and is SU(n)
(A : SpecialUnitaryMatrix)⁻¹ → Aᴴ : SpecialUnitaryMatrix;

```
**Use Cases:** SU(2) is related to spin in quantum mechanics (Pauli matrices generate its Lie algebra). SU(3) is used in the Standard Model of particle physics.

### Symplectic Matrix

Symplectic matrices preserve the standard symplectic form. They are essential in Hamiltonian mechanics and symplectic geometry. $Sp(2n, F)$ denotes the symplectic group of $2n \times 2n$ matrices over field $F$.

```orbit
// Domain definition
SymplecticMatrix<T, N> ⊂ Matrix<T, N, N> // N must be even, N = 2k

// Property: Aᵀ * J * A = J
// where J is the standard symplectic matrix: J = [[0, I_k], [-I_k, 0]]
// I_k is k x k identity matrix, 0 is k x k zero matrix.

// Rule: Product of symplectic matrices is symplectic (forms a group Sp(2n))
(A : SymplecticMatrix) * (B : SymplecticMatrix) → A * B : SymplecticMatrix;

// Rule: Inverse of a symplectic matrix
// A⁻¹ = J⁻¹ * Aᵀ * J  (and J⁻¹ = -J = Jᵀ)
(A : SymplecticMatrix)⁻¹ → (-J) * Aᵀ * J;

// Note: Determinant of a symplectic matrix is +1.
determinant(A : SymplecticMatrix) → 1;
```
**Use Cases:** Classical mechanics, quantum information theory.


### Triangular Matrices (Upper and Lower)

Triangular matrices have all zeros above (lower triangular) or below (upper triangular) the main diagonal. They are crucial in linear algebra solvers (e.g., Gaussian elimination results in LU decomposition).

```orbit
// Domain definitions
UpperTriangularMatrix<T, N> ⊂ Matrix<T, N, N> // M[i,j] == 0 if i > j
LowerTriangularMatrix<T, N> ⊂ Matrix<T, N, N> // M[i,j] == 0 if i < j

// Rule: Product of same-type triangular matrices is triangular. Standard O(N³) but with reduced loop bounds.
// Example for Upper * Upper: C[i, j] = sum(k=i to j, A[i, k] * B[k, j])
(A : UpperTriangularMatrix) * (B : UpperTriangularMatrix) : MatrixMultiply →
	compute_triangular_product(A, B, "upper") : UpperTriangularMatrix;

// Rule: Multiplication by a general matrix also has reduced loops.
// Example for Upper * General: C[i, j] = sum(k=i to N-1, A[i, k] * B[k, j])
(A : UpperTriangularMatrix) * (B : Matrix<T, N, P>) →
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
(A : BandedMatrix<_, N, L1, U1>) * (B : BandedMatrix<_, N, L2, U2>) →
	compute_banded_product(A, B) : BandedMatrix<_, N, L1+L2, U1+U2>;

// Rule: Specialized O(N) algorithms for solving tridiagonal systems (Thomas algorithm).
// Orbit can rewrite `solve(A:TridiagonalMatrix, b)` to `thomas_algorithm(A,b)`.
```

### Nilpotent Matrix

A matrix A is nilpotent if Aᵏ = 0 for some positive integer k (the index of nilpotency).

```orbit
// Domain definition
NilpotentMatrix<T, N, K_Nilpotency> ⊂ Matrix<T, N, N> // K_Nilpotency is the smallest k such that A^k = 0

// Property: All eigenvalues are 0.
trace(A : NilpotentMatrix) → 0;
det(A : NilpotentMatrix) → 0;

// Rule: Powers beyond k are zero
(A : NilpotentMatrix<_,_,K>)^m → ZeroMatrix<N,N> if m >= K;

// Rule: (I - A) is invertible if A is nilpotent, with (I - A)⁻¹ = I + A + A² + ... + A^(K-1)
inverse(IdentityMatrix<N> - (A : NilpotentMatrix<_,N,K>)) → sum(i, 0, K-1, A^i);
```
**Use Cases:** Lie algebra theory, study of linear operators.

### Idempotent Matrix (Projection Matrix)

A matrix P is idempotent if P² = P. Such matrices are projections onto some subspace.

```orbit
// Domain definition
IdempotentMatrix<T, N> ⊂ Matrix<T, N, N>
// Alias: ProjectionMatrix<T,N> ⊂ IdempotentMatrix<T,N>

// Property: P² = P
(P : IdempotentMatrix)^2 → P;
(P : IdempotentMatrix)^k → P if k >= 1;

// Rule: If P is idempotent, then I - P is also idempotent.
// (I - P) projects onto the null space of P.
(IdentityMatrix<N> - (P : IdempotentMatrix)) : IdempotentMatrix;

// Rule: Eigenvalues are 0 or 1.
// eigenvalues(P : IdempotentMatrix) ⊂ {0, 1};
```
**Use Cases:** Statistics (e.g., hat matrix in regression), linear algebra (projections).

### Involutory Matrix

A matrix A is involutory if A² = I (identity matrix).

```orbit
// Domain definition
InvolutoryMatrix<T, N> ⊂ Matrix<T, N, N>

// Property: A² = I
(A : InvolutoryMatrix)^2 → IdentityMatrix<N>;

// Rule: Inverse is the matrix itself
(A : InvolutoryMatrix)⁻¹ → A;

// Rule: Powers simplify
(A : InvolutoryMatrix)^k → IdentityMatrix<N> if is_even(k);
(A : InvolutoryMatrix)^k → A if is_odd(k);

// Note: Eigenvalues are ±1.
```
**Use Cases:** Reflection matrices, certain cryptographic algorithms.

### Orthogonal Projector (Orthogonal Idempotent Matrix)

An orthogonal projector is a projection matrix that is also symmetric (A² = A and A = Aᵀ) or Hermitian (A² = A and A = Aᴴ for complex matrices).

```orbit
// Domain definition
OrthogonalProjectorMatrix<T, N> ⊂ IdempotentMatrix<T, N>, SymmetricMatrix<T, N> // For Real T
OrthogonalProjectorMatrix<T, N> ⊂ IdempotentMatrix<T, N>, HermitianMatrix<T, N> // For Complex T

// Properties: A²=A, A=Aᵀ (or A=Aᴴ)
// All eigenvalues are 0 or 1.
// Projects onto the column space of A, and I-A projects onto its null space.

// Rule: For an orthogonal projector P, norm(P*x) ≤ norm(x)
// norm((P : OrthogonalProjectorMatrix) * (x : Vector)) ≤ norm(x);
```
**Use Cases:** Least squares solutions, signal processing, quantum mechanics.

### Hadamard Matrix

A Hadamard matrix H of order n is an n×n matrix with entries +1 or -1, such that H Hᵀ = n I_n.

```orbit
// Domain definition
HadamardMatrix<N> ⊂ Matrix<Int, N, N> // Entries are +1 or -1

// Property: H * Hᵀ = N * IdentityMatrix<N>
(H : HadamardMatrix<N>) * Hᵀ → N * IdentityMatrix<N>;

// Rule: Inverse (up to scalar)
(H : HadamardMatrix<N>)⁻¹ → (1/N) * Hᵀ;

// Note: If a Hadamard matrix of order N exists, N must be 1, 2, or a multiple of 4.
// Fast multiplication (Fast Walsh-Hadamard Transform, FWHT) O(N log N) if N is power of 2.
(H : HadamardMatrix<N>) * (x : Vector<_,N>) : ViaFWHT → 
    fast_walsh_hadamard_transform(H, x) if is_power_of_2(N);
```
**Use Cases:** Error-correcting codes, signal processing, experimental design.

### Monomial Matrix

A monomial matrix is a square matrix that has exactly one non-zero entry in each row and column. It is a product of a permutation matrix and a non-singular diagonal matrix.

```orbit
// Domain definition
MonomialMatrix<T, N> ⊂ Matrix<T, N, N>
// Representation: M = P * D or M = D' * P, where P is PermutationMatrix, D, D' are DiagonalMatrix (invertible)

// Rule: Product of monomial matrices is monomial.
(M1 : MonomialMatrix) * (M2 : MonomialMatrix) → product_monomial(M1,M2) : MonomialMatrix;

// Rule: Inverse is also monomial.
(M : MonomialMatrix)⁻¹ : MonomialMatrix;
// If M = P*D, then M⁻¹ = D⁻¹*P⁻¹ = D⁻¹*Pᵀ.

// Note: Forms a group, the group of monomial matrices.
```
**Use Cases:** Group theory, representation theory.

### Reflection Matrix

A reflection matrix is an orthogonal matrix with a determinant of -1. It represents a reflection across a hyperplane.

```orbit
// Domain definition
ReflectionMatrix<T,N> ⊂ OrthogonalMatrix<T,N> // T is typically Real

// Property: determinant(R) = -1
determinant(R : ReflectionMatrix) → -1;

// Property: Often involutory (R² = I), especially for reflections across hyperplanes through origin.
// (R : ReflectionMatrix)^2 → IdentityMatrix<N> if is_hyperplane_reflection(R);
```
**Use Cases:** Geometric transformations, computer graphics.

### Rank-1 Matrix (Dyad)

A rank-1 matrix can be expressed as the outer product of two non-zero vectors: A = u vᵀ.

```orbit
// Domain definition
RankOneMatrix<T, N, M> ⊂ LowRankMatrix<T, N, M, 1> // Sub-domain of LowRankMatrix with K=1
// Property: A = u * vᵀ for vectors u (N x 1) and v (M x 1)

// Rule: Explicit representation
outer_product(u : Vector<T,N>, v_transposed : Vector<T,M>) → A : RankOneMatrix<T,N,M>;

// Rule: Multiplication by vector
// A * x = (u * vᵀ) * x = u * (vᵀ * x) (scalar vᵀ*x times vector u)
(A : RankOneMatrix) * (x : Vector) → 
    let {u, v_transposed} = get_rank_one_factors(A);
    u * (v_transposed * x); // (v_transposed * x) is a scalar product

// Rule: Product of two rank-1 matrices (results in scaled rank-1 or zero)
// (u1*v1ᵀ) * (u2*v2ᵀ) = u1 * (v1ᵀ*u2) * v2ᵀ
(A1 : RankOneMatrix) * (A2 : RankOneMatrix) → 
    let {u1, v1t} = get_rank_one_factors(A1);
    let {u2, v2t} = get_rank_one_factors(A2);
    outer_product(u1, v2t) * (v1t * u2); // (v1t * u2) is a scalar
```
**Use Cases:** Simplest form of low-rank approximation, update formulas (e.g., Sherman-Morrison).

### Circulant Matrices

Each row is a cyclic shift of the row above it. They are related to the Cyclic Group C_N and polynomial multiplication modulo x^N - 1. Multiplication is equivalent to circular convolution.

TODO: How does this relate to permutation matrices?

```orbit
// Domain definition
CirculantMatrix<T, N> ⊂ Matrix<T, N, N>
// Property: C[i, j] = c[(j - i) mod N] (defined by its first row/column)

// Rule: Multiplication is circular convolution of the generating vectors, O(N log N) via FFT if T supports it.
(C1 : CirculantMatrix) * (C2 : CirculantMatrix) : C_N !: ViaFFT →
	circulant_matrix(circular_convolution(first_row_vector(C1), first_row_vector(C2))) : CirculantMatrix;

// Rule: Connect circular convolution to FFT (Fast Fourier Transform)
circular_convolution(a, b) : Convolution →
	ifft(hadamard_product(fft(a), fft(b))) : ViaFFT // elementwise_multiply is Hadamard product
	if supports_fft(T);

// Rule: Multiplication of Circulant matrix by vector also via FFT, O(N log N).
(C : CirculantMatrix) * (x : Vector) : C_N !: ViaFFT →
	ifft(hadamard_product(fft(first_row_vector(C)), fft(x))) : Vector : ViaFFT
	if supports_fft(T);
```

### Toeplitz Matrices

Matrices with constant diagonals (T[i, j] = t[j - i]). They can be multiplied efficiently, often by embedding them into larger Circulant matrices.

```orbit
// Domain definition
ToeplitzMatrix<T, N> ⊂ Matrix<T, N, N>
// Property: T[i, j] = t[j - i]

// Rule: Embed Toeplitz into Circulant for multiplication, O(N log N).
(T1 : ToeplitzMatrix) * (T2 : ToeplitzMatrix) : MatrixMultiply !: ViaCirculant →
	let N_embed = choose_embedding_size_for_toeplitz(N); // e.g., >= 2*N-1, power of 2
	let C1 = embed_toeplitz_in_circulant(T1, N_embed);
	let C2 = embed_toeplitz_in_circulant(T2, N_embed);
	let C_result = C1 * C2; // Uses Circulant multiplication (FFT)
	extract_toeplitz_from_circulant(C_result, N) : ToeplitzProduct : ViaCirculant;
```

Their inversion can also be performed efficiently using specialized algorithms like the Trench algorithm or Gohberg-Semencul formulas.

### Hankel Matrices
Matrices with constant skew-diagonals (H[i, j] = h[i + j]). They are related to Toeplitz matrices via permutation.

```orbit
// Domain definition
HankelMatrix<T, N> ⊂ Matrix<T, N, N>
// Property: H[i, j] = h[i + j]

// Rule: Convert to Toeplitz via permutation matrix J (anti-diagonal 1s).
// H = J * T_H or H = T'_H * J, where T_H, T'_H are Toeplitz.
hankel_to_toeplitz(H : HankelMatrix, J : AntiDiagonalIdentity) → J * H; // Results in a Toeplitz matrix

// Rule: Multiplication via conversion to Toeplitz/Circulant/FFT, O(N log N).
(H1 : HankelMatrix) * (H2 : HankelMatrix) : MatrixMultiply !: ViaToeplitz →
	let J = anti_diagonal_identity_matrix(N);
	let T1_equiv = J * H1; // T1_equiv is Toeplitz
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
(A : SparseMatrix<CSR>) * (B : SparseMatrix<CSC>) →
	sparse_multiply_csr_csc(A, B) : SparseMatrix<ResultFormat>;

(A : SparseMatrix<COO>) * (x : Vector) →
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
(A : LowRankMatrix<_, N, M, K_A>) * (B : Matrix<T, M, P>) →
	let {U_A, V_A} = get_factors(A);
	U_A * (V_Aᵀ * B)
	if (K_A*P < N*M); // Heuristic: intermediate V_Aᵀ*B is smaller than forming A

// A*(U*Vᵀ) = (A*U)*Vᵀ. Complexity: N*M*K_B (for A*U_B) + N*K_B*P (for result*V_Bᵀ).
(A : Matrix<T, N, M>) * (B : LowRankMatrix<_, M, P, K_B>) →
	let {U_B, V_B} = get_factors(B);
	(A * U_B) * V_Bᵀ
	if (N*K_B < M*P); // Heuristic: intermediate A*U_B is smaller than forming B

// (U_A*V_Aᵀ)*(U_B*V_Bᵀ) = U_A * (V_Aᵀ*U_B) * V_Bᵀ
(A : LowRankMatrix<_, N, M, K_A>) * (B : LowRankMatrix<_, M, P, K_B>) →
	let {U_A, V_A} = get_factors(A);
	let {U_B, V_B} = get_factors(B);
	let Intermediate = V_Aᵀ * U_B; // K_A x K_B matrix
	U_A * (Intermediate * V_Bᵀ);
```

### Embedding Matrices & One-Hot Vectors
A common machine learning operation involves multiplying an embedding matrix (tall, `VocabSize x EmbedDim`) by a one-hot vector (representing a word index), which simplifies to a lookup.

```orbit
// Domain definitions
EmbeddingMatrix<T, VocabSize, EmbedDim> ⊂ Matrix<T, VocabSize, EmbedDim>
OneHotVector<N, HotIndex> ⊂ Vector<Int, N> // Vector with one '1' at HotIndex, rest '0'

// Rule: Multiplication is a lookup (effectively O(EmbedDim) to copy the row).
(E : EmbeddingMatrix<_, V, D>) * (x : OneHotVector<V, Idx>) →
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
sum_over_cols((A : Matrix<T, N, M>) * (P : RowStochasticMatrix<T, M, P>), i_row) →
	row_sum(A, i_row);

sum_over_rows((P : ColStochasticMatrix<T, N, M>) * (B : Matrix<T, M, P>), j_col) →
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
(A : Matrix<T, N, M>) ⊗ (B : Matrix<T, P, Q>) : TensorOp → C : Matrix<T, N*P, M*Q>;

// Key Property (Mixed Product Property):
// (A ⊗ B) * (C ⊗ D) = (A * C) ⊗ (B * D)  (if inner dimensions match for A*C and B*D)
(A ⊗ B) * (C ⊗ D) →
	(A * C) ⊗ (B * D)
	if can_multiply(A, C) && can_multiply(B, D);

// Other properties that can be rewrite rules:
(A ⊗ B)ᵀ = Aᵀ ⊗ Bᵀ
(A ⊗ B)⁻¹ = A⁻¹ ⊗ B⁻¹ (if A, B invertible)
// trace(A ⊗ B) = trace(A) * trace(B)

// Rule: Vec-trick identity
// (A ⊗ B) * vec(X) = vec(B * X * Aᵀ) where vec(X) stacks columns of X into a vector.
(A ⊗ B) * vec(X : Matrix<_,M,Q>) → // Assuming B is PxQ, A is NxM
	vec(B * (X * Aᵀ));
```

## Conclusion

By recognizing and annotating these diverse matrix structures, Orbit can move beyond generic matrix algorithms. It applies domain-specific knowledge encoded as rewrite rules to select or derive highly efficient computational strategies. This leads to a system that can automatically optimize matrix operations for specific contexts, significantly improving performance for structured problems common in scientific computing, machine learning, and engineering.

The next documents in this series will explore matrix decompositions ([`matrix3.md`](./matrix3.md)) and advanced analytical topics like matrix functions and eigen-problems ([`matrix4.md`](./matrix4.md)).
