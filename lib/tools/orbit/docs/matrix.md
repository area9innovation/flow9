# Overview of Orbit's Matrix Algebra Documentation

This document serves as a central guide to the comprehensive documentation on how Orbit, an advanced rewriting system, handles various aspects of matrix algebra. The following documents provide detailed insights into specific areas:

1.  **Core Matrix Algebra and Multiplication ([`matrix1.md`](./matrix1.md))**
    *   Introduces Orbit's fundamental approach to matrix operations, primarily focusing on matrix multiplication.
    *   Covers symbolic representation in e-graphs, domain-driven algebraic rewriting based on algebraic laws (Semiring, Ring), divide-and-conquer strategies like block decomposition, and the algebraic rearrangement leading to algorithms like Strassen's.
    *   Discusses how Orbit exploits basic matrix structures (e.g., Identity, Diagonal) and how it can infer commutativity (S₂ symmetry) for specific matrix multiplication instances.

2.  **Specialized Matrix Structures ([`matrix2.md`](./matrix2.md))**
    *   Explores how Orbit identifies and optimizes operations for a wide variety of specialized matrix structures by applying highly specific rewrite rules.
    *   Details include a comprehensive matrix hierarchy and domain subtype rules for types such as Identity, Diagonal, Permutation, Symmetric/Hermitian, Skew-Symmetric/Skew-Hermitian, Orthogonal/Unitary (including SO(n) and SU(n)), Triangular, Banded (e.g., Tridiagonal), Nilpotent, Idempotent, Involutory, Sparse, Low-Rank (including Rank-1), Circulant, Toeplitz, Hankel, Hadamard, Monomial, Stochastic, and matrices relevant to machine learning like Embedding matrices when multiplied by One-Hot vectors.
    *   Also touches upon operations like Hadamard Product and Kronecker Product in relation to these structures.

3.  **Matrix Decompositions and Factorizations ([`matrix3.md`](./matrix3.md))**
    *   Focuses on how Orbit can symbolically derive, represent, and utilize common matrix decompositions and factorizations.
    *   Covers LU decomposition (including LUP/PLU for pivoting), Cholesky decomposition (for symmetric/Hermitian positive definite matrices), QR decomposition (via Gram-Schmidt, Householder reflections, or Givens rotations), and Singular Value Decomposition (SVD).
    *   Explains Orbit's role in symbolic algorithms, property enforcement (e.g., for triangular, orthogonal factors), canonicalization, and application of these decompositions to solve linear systems, compute determinants, inverses, rank, and pseudo-inverses.
    *   Includes details on block matrix operations and Schur complements, their properties, and applications (e.g., block LDU, determinants, solving systems, positive definiteness).

4.  **Advanced Matrix Analysis ([`matrix4.md`](./matrix4.md))**
    *   Delves into advanced analytical topics within matrix algebra from Orbit's perspective.
    *   Covers matrix trace (properties like linearity, cyclic property, transpose/similarity invariance, relation to eigenvalues) and matrix determinant (properties like multiplicativity, transpose/similarity invariance, relation to invertibility and eigenvalues, geometric interpretation).
    *   Provides a detailed discussion of eigenvalue and eigenvector problems, including the characteristic polynomial, diagonalization, Spectral Theorem for symmetric/Hermitian matrices, Jordan Normal Form, and the Cayley-Hamilton Theorem.
    *   Explains how matrix functions (e.g., exponential, logarithm, powers) can be handled via Taylor series or, more practically, through diagonalization or Jordan form.
    *   Introduces matrix Lie groups (GL(n), SL(n), O(n), SO(n), U(n), SU(n)) and their associated Lie algebras (gl(n), sl(n), so(n), u(n), su(n)), the matrix exponential map, and rewrite rules based on their properties.
    *   Also covers Normal, Unipotent, Companion, and Vandermonde matrices.

5.  **Matrices in 2D/3D Computer Graphics ([`matrix5.md`](./matrix5.md))**
    *   Discusses the application of Orbit to specialized matrices used extensively in 2D/3D computer graphics, computer vision, robotics, and computational geometry.
    *   Explains the use of homogeneous coordinates to represent transformations like translation, scaling, rotation, shear, and projection (perspective and orthographic).
    *   Focuses on a graphics DSL (Domain Specific Language) for these transformations and establishing bidirectional rewrite rules between DSL operations and their matrix representations.
    *   Covers how Orbit can leverage matrix algebra for composition and simplification, and utilize the group-theoretic structures of these transformations (e.g., SO(2), SO(3), Affine group, Euclidean group, Similarity group, Projective Linear Group PGL(n+1,R)).
    *   Includes a discussion on quaternions for representing 3D rotations and their conversion to/from matrices.

Please refer to the individual documents for in-depth information on each topic.
