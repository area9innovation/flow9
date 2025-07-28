# Understanding Tensors in Orbit

## Introduction
Tensors are fundamental mathematical objects that generalize scalars, vectors, and matrices to an arbitrary number of dimensions. Their application is pervasive across physics (e.g., general relativity, fluid dynamics, electromagnetism using stress, strain, and electromagnetic field tensors), engineering (e.g., continuum mechanics, diffusion MRI), data science (representing multi-modal datasets), and prominently in machine learning (as weights, activations, and gradients in neural networks). This chapter details how Orbit represents tensors, the operations it supports, and how its algebraic rewriting capabilities can be applied to tensor expressions for simplification, canonicalization, and optimization.

## 1. Definition and Representation in Orbit

### 1.1. What is a Tensor?
A tensor can be visualized as a multi-dimensional array of numerical values. The **rank** (also known as order or degree) of a tensor signifies the number of indices required to uniquely identify each of its components. 

*   A **scalar** is a rank-0 tensor (no indices).
*   A **vector** is a rank-1 tensor (one index, e.g., `vᵢ`).
*   A **matrix** is a rank-2 tensor (two indices, e.g., `Mᵢⱼ`).
*   A **rank-3 tensor** requires three indices (e.g., `Tᵢⱼₖ`), and so on for higher ranks.

### 1.2. Orbit Domain: `Tensor<T, Shape>`
Orbit employs a parameterized domain to represent tensors:

*   `Tensor<T, Shape>`
	*   `T`: The data type of the tensor's components (e.g., `Real`, `Integer`, `Complex`, or even another `Distribution` for probabilistic tensors).
	*   `Shape`: A list of positive integers defining the size (extent) of each dimension. For example:
		*   Scalar `s`: `Shape = []` (e.g., `Tensor<Real, []>`).
		*   Vector `v` of length `N`: `Shape = [N]` (e.g., `Tensor<Real, [N]>`).
		*   Matrix `M` of `R` rows and `C` columns: `Shape = [R, C]` (e.g., `Tensor<Real, [R, C]>`).
		*   Rank-3 tensor `A` of dimensions `P, M, N`: `Shape = [P, M, N]` (e.g., `Tensor<Real, [P, M, N]>`).

**Representation in Orbit:**
Internally, tensors are represented as nested lists or arrays corresponding to their rank and shape:
*   Scalar `s: T`: `s`
*   Vector `v: Tensor<T, [N]>`: `[v₀, v₁, ..., v₍N-₁₎]`
*   Matrix `M: Tensor<T, [R,C]>`: `[[m₀₀, ..., m₀₍C-₁₎], ..., [m₍R-₁₎₀, ..., m₍R-₁₎₍C-₁₎]]`
*   Rank-3 Tensor `A: Tensor<T, [P,M,N]>`: A list of `P` matrices, where each matrix is `M x N`.

### 1.3. Element Access
Components of a tensor are accessed using a number of indices equal to its rank:

*   **Orbit Syntax:** `A[idx₀, idx₁, ..., idx₍rank-₁₎]`
*   **Example:** For `A : Tensor<Real, [2,3,4]>`, `A[0][1][2]` accesses a specific scalar component.

### 1.4. Relationship to Other Orbit Domains
Orbit's tensor domain integrates with its existing hierarchy:

```orbit
// Subdomain relationships
Vector<T, N> ⊂ Tensor<T, [N]>;
Matrix<T, R, C> ⊂ Tensor<T, [R, C]>;
Scalar<T> ⊂ Tensor<T, []>; // If Scalar<T> is a defined domain for simple types

// Algebraic properties
Tensor<T, Shape> ⊂ VectorSpaceOver<T> if T : Field;
Tensor<T, Shape> ⊂ ModuleOver<T> if T : Ring; // More general case
// This implies Tensor<T,Shape> is an AbelianGroup under addition.
```

This hierarchical placement allows tensors to inherit rewrite rules and properties defined for these more general algebraic structures (e.g., commutativity and associativity of addition from `AbelianGroup`).

### 1.5. Index Notation and Einstein Summation (Conceptual Link)
Traditional physics and mathematics often use index notation (e.g., `Tᵢⱼₖ`, `T_μ^ν`). The Einstein summation convention, where repeated indices across upper and lower positions imply summation over that index (e.g., `Aᵢₖ Bₖⱼ = Σₖ Aᵢₖ Bₖⱼ`), is a powerful shorthand for tensor contractions.

While Orbit's primary representation is the multi-dimensional array, its symbolic engine can:
1.  Parse expressions written in a simplified Einstein-like notation.
2.  Recognize patterns in explicit summations that correspond to tensor contractions and convert them to canonical contraction operations (see Section 2.2.2).
3.  Potentially output code (e.g., for code generation targets) using optimized loops derived from Einstein summation forms.

## 2. Fundamental Tensor Operations in Orbit

Orbit defines a suite of operations on tensors. Compatibility of shapes and component types (`T`) is essential for most operations.

### 2.1. Element-wise Operations
These operations apply independently to each component of the tensor(s).

*   **Tensor Addition/Subtraction:**
	*   Notation: `A + B`, `A - B`
	*   Operands: `A: Tensor<T, Shape>`, `B: Tensor<T, Shape>` (must have identical shapes and component type `T`).
	*   Result: `Tensor<T, Shape>`, where `(A+B)[indices...] = A[indices...] + B[indices...]`.
*   **Scalar Multiplication:**
	*   Notation: `s * A` (or `A * s`)
	*   Operands: `s: T` (scalar), `A: Tensor<T, Shape>`.
	*   Result: `Tensor<T, Shape>`, where `(s*A)[indices...] = s * A[indices...]`.
*   **Element-wise Product (Hadamard Product):**
	*   Notation: `hadamard_product(A, B)` (Orbit avoids `∘` to prevent conflict with function composition).
	*   Operands: `A: Tensor<T, Shape>`, `B: Tensor<T, Shape>` (identical shapes and type `T`).
	*   Result: `Tensor<T, Shape>`, where `result[indices...] = A[indices...] * B[indices...]`.

### 2.2. Operations Changing Rank or Shape

*   **Outer Product (Tensor Product):**
	*   Notation: `A ⊗ B` (Orbit uses `⊗` for the general tensor product, distinct from `kronecker_product(Matrix, Matrix)` which is a specific type of tensor product often resulting in block matrices, see [`notation.md`](./notation.md) and [`matrix2.md`](./matrix2.md)).
	*   Operands: `A: Tensor<T, ShapeA>`, `B: Tensor<T, ShapeB>`.
	*   Result: `Tensor<T, ShapeA + ShapeB>`, where `ShapeA + ShapeB` is the concatenation of `ShapeA` and `ShapeB`. The rank of the result is `rank(A) + rank(B)`.
	*   Definition: `(A ⊗ B)[a_indices..., b_indices...] = A[a_indices...] * B[b_indices...]`.
	*   Example: `u: Tensor<T,[M]>`, `v: Tensor<T,[N]>`. `u ⊗ v` is `W: Tensor<T,[M,N]>` where `W[i,j] = u[i] * v[j]`. This is the standard vector outer product yielding a matrix.

*   **Tensor Contraction:** This is a fundamental operation that reduces the rank of a tensor (or a product of tensors) by summing over one or more pairs of specified indices.
	*   **Generalized Orbit Function:** 

		```orbit	
		// Contracts tensor A over its specified indices_A and tensor B over its indices_B.
		// If B is omitted, contracts A with itself.
		contract(A: Tensor<T,SA>, indices_A: Vector<Integer>, 
				 [B: Tensor<T,SB>, indices_B: Vector<Integer>]) 
			-> Tensor<T,S_Result>;
		// indices_A and indices_B must have the same length and corresponding dimensions must match.
		```

	*   **Examples as Contractions:**
		*   **Vector Dot Product (`u ⋅ v`):** `contract(u, [0], v, [0])` where `u,v: Tensor<T,[N]>`. Result is `Tensor<T,[]>`, a scalar.
		*   **Matrix Trace (`tr(M)`):** `contract(M, [0], M, [1])` (conceptually, though often `contract(M,[0,1])` if contracting internal indices). For `M:Tensor<T,[N,N]>`, `contract(M, [0,1])` would mean `Σᵢ M[i,i]`. Result `Tensor<T,[]>`.
		*   **Matrix-Vector Product (`y = Mv`):** `yᵢ = Σⱼ Mᵢⱼvⱼ`. This is `contract(M, [1], v, [0])` if `M:Tensor<T,[R,C]>, v:Tensor<T,[C]>`. Result `Tensor<T,[R]>`.
		*   **Matrix-Matrix Product (`C = AB`):** `Cᵢₖ = Σⱼ AᵢⱼBⱼₖ`. This is `contract(A, [1], B, [0])` if `A:Tensor<T,[P,M]>, B:Tensor<T,[M,N]>`. Result `Tensor<T,[P,N]>`.
	*   **Einstein Summation Interface (Conceptual):** Orbit might provide a function that parses an Einstein summation string to perform complex contractions:
		```orbit
		// einsum("ijk,jkl->il", A, B)
		//   where A:Tensor<T,[I,J,K]>, B:Tensor<T,[J,K,L]> 
		//   results in C:Tensor<T,[I,L]>
		//   C[i,l] = Σ_j Σ_k A[i,j,k] * B[j,k,l]
		```

*   **Index Permutation / Transposition:**
	*   Notation: `permute_indices(A: Tensor<T, OldShape>, permutation_map: Vector<Integer>) -> Tensor<T, NewShape>`
		*   `permutation_map` defines how original axis indices are reordered. E.g., for `A` with shape `[d₀,d₁,d₂]`, `permutation_map = [2,0,1]` means new tensor `A'` has shape `[d₂,d₀,d₁]` and `A'[k,i,j] = A[i,j,k]` (original index 0 maps to new 1, 1 to 2, 2 to 0).
	*   **Specific Transpose `transpose(A: Tensor<T,Shape>, dim0: Int, dim1: Int) -> Tensor<T,ShapePermuted>`:** Swaps dimensions `dim0` and `dim1`.
		*   For a matrix `M:Tensor<T,[R,C]>`, `transpose(M, 0, 1)` yields `Mᵀ:Tensor<T,[C,R]>`.

*   **Reshaping:**
	*   Notation: `reshape(A: Tensor<T, OldShape>, new_shape_list: Vector<Integer>) -> Tensor<T, NewShape>`
	*   Changes the shape of the tensor while preserving the total number of elements and their data order (usually C-style row-major or Fortran-style column-major flattening/unflattening).
	*   Constraint: `product(OldShape) == product(NewShape)`.
	*   Example: `reshape(A:Tensor<T,[2,6]>, [4,3])` or `reshape(A:Tensor<T,[12]>, [2,2,3])`.

## 3. Algebraic Properties and Rewrite Rules in Orbit

Leveraging Orbit's domain system, tensors inherit rules from their algebraic supertypes (`VectorSpaceOver<T>`, `AbelianGroup`).

### 3.1. Vector Space Properties (for `Tensor<T,Shape>` over field `T`)

*   **Tensor Addition (from `AbelianGroup`):**
	```orbit
	// Commutativity (if + is defined as n-ary and associated with S_n symmetry)
	// A : Tensor<T,Shape> + B : Tensor<T,Shape> ↔ B + A : Tensor<T,Shape> : S₂;
	// Or handled by n-ary `+` canonicalization (sorting arguments).

	// Associativity (handled by n-ary `+` representation in Orbit S-expressions)
	// (A + B) + C ↔ A + (B + C);

	// Additive Identity (0̿ is the ZeroTensor of appropriate shape)
	A : Tensor<T,Shape> + ZeroTensor<T,Shape> → A;

	// Additive Inverse
	A : Tensor<T,Shape> + (-A) → ZeroTensor<T,Shape>; // -A is element-wise negation
	```
*   **Scalar Multiplication:**
	```orbit
	s:T * (A:Tensor<T,Shape> + B:Tensor<T,Shape>) → (s * A) + (s * B);
	(s:T + t:T) * A:Tensor<T,Shape> → (s * A) + (t * A);
	(s:T * t:T) * A:Tensor<T,Shape> → s * (t * A);
	1:T * A:Tensor<T,Shape> → A; // If T has multiplicative identity 1
	0:T * A:Tensor<T,Shape> → ZeroTensor<T,Shape>; // If T has additive identity 0
	```

### 3.2. Outer Product (`⊗`) Rules

```orbit
// Distributivity over tensor addition (bilinearity)
A ⊗ (B + C) → (A ⊗ B) + (A ⊗ C) where shape_B = shape_C;
(A + B) ⊗ C → (A ⊗ C) + (B ⊗ C) where shape_A = shape_B;

// Interaction with scalar multiplication
(s * A) ⊗ B ↔ s * (A ⊗ B);
A ⊗ (s * B) ↔ s * (A ⊗ B);

// Interaction with zero tensor
A ⊗ ZeroTensor<T,ShapeB> → ZeroTensor<T,concat(ShapeA,ShapeB)>;
ZeroTensor<T,ShapeA> ⊗ B → ZeroTensor<T,concat(ShapeA,ShapeB)>;

// Associativity (up to index flattening and reordering)
// (A ⊗ B) ⊗ C is structurally different from A ⊗ (B ⊗ C) in terms of index grouping,
// but their flattened element lists are related by a permutation.
// (A ⊗ B) ⊗ C ↔ permute_indices(A ⊗ (B ⊗ C), specific_permutation_map)
// This implies a canonical ordering for repeated tensor products might be chosen.
```

### 3.3. Contraction Rules
Let `contract(T, idx_pairs)` or `contract(A, idxA, B, idxB)` be the syntax.

```orbit
// Linearity
contract(A + B, idxA, C, idxC) → contract(A, idxA, C, idxC) + contract(B, idxA, C, idxC)
	where shape_A = shape_B;
contract(A, idxA, C + D, idxC) → contract(A, idxA, C, idxC) + contract(A, idxA, D, idxC)
	where shape_C = shape_D;
contract(s*A, idxA, B, idxB) → s * contract(A, idxA, B, idxB);
contract(A, idxA, s*B, idxB) → s * contract(A, idxA, B, idxB);

// Contraction of an outer product often simplifies:
// Example: Trace of an outer product of two vectors u, v (rank-1 tensors)
// u:Tensor<T,[N]>, v:Tensor<T,[N]>
// M = u ⊗ v  // M is Tensor<T,[N,N]> where M[i,j] = u[i]v[j]
// tr(M) = Σᵢ M[i,i] = Σᵢ u[i]v[i] = u ⋅ v
// contract(u ⊗ v, [(0,1)]) → dot_product(u,v); // If [(0,1)] means contract 0th index of result with 1st index of result
// Using the more explicit form:
// contract(outer_product(u,v), [0], [1]) → dot_product(u,v) // Assuming outer_product results in a matrix and indices are for that matrix

// Contraction with an identity tensor (Kronecker delta like behavior)
// contract(A : Tensor<T,[N,M]>, [1], IdentityMatrix<T,M>, [0]) → A // Sum_k A_ik * δ_kj = A_ij
```

### 3.4. Index Permutation and Reshape Rules

```orbit
permute_indices(permute_indices(A, p1_map), p2_map) → permute_indices(A, compose_permutations(p1_map, p2_map));
permute_indices(A, identity_permutation_map) → A;

transpose(transpose(A, dim0, dim1), dim0, dim1) → A;
transpose(A, dim0, dim1) ↔ permute_indices(A, map_for_swap(dim0,dim1,rank(A)));

permute_indices(A+B, p_map) → permute_indices(A, p_map) + permute_indices(B, p_map);
permute_indices(s*A, p_map) → s * permute_indices(A, p_map);

reshape(reshape(A, S1), S2) → reshape(A, S2) if product(S1)=product(S2);
reshape(A, shape(A)) → A;

// Reshaping a sum (if semantically valid for the operation, usually only if A,B have same shape initially)
// reshape(A+B, NewShape) → reshape(A, NewShape) + reshape(B, NewShape)
//   if shape(A) == shape(B) and product(shape(A)) == product(NewShape);
```

## 4. Specialized Tensors and Symmetries

Orbit can define domains for tensors with special structures or symmetries, enabling more specific rewrite rules.

### 4.1. Zero Tensor
*   **Orbit Domain:** `ZeroTensor<T, Shape>`
*   Properties: Additive identity. `ZeroTensor[indices...] = 0` for all indices.

### 4.2. Identity Tensors (Generalized Kronecker Delta)
*   The concept of an identity tensor is context-dependent on the operation (usually contraction).
*   **Identity Matrix:** `IdentityMatrix<T,N> ⊂ Tensor<T,[N,N]>`, where components are `δᵢⱼ` (1 if `i=j`, 0 otherwise).
	It acts as an identity for matrix multiplication (a specific type of contraction).
*   **Higher-Rank Identity Elements:** For specific contractions, a higher-rank tensor might act as an identity. For instance, a rank-4 tensor `Iᵢⱼᵏˡ = δᵢᵏδⱼˡ` could be an identity for contracting two rank-2 tensors in a certain way: `Σₖₗ Aᵢⱼ Iʲᵏˡᵐ Bₗₘ → Aᵢₖ Bₖₘ` (this needs careful formulation).

### 4.3. Symmetric Tensors
*   **Description:** A tensor is symmetric with respect to a pair of indices if its components remain unchanged when those indices are swapped.
A tensor is fully symmetric if it's symmetric with respect to all pairs of its indices.
*   **Orbit Domain (Example for rank-2):** `SymmetricTensor<T, [N,N]>`
*   **Orbit Rules (Example for rank-2):**
	```orbit
	A : SymmetricTensor<T,[N,N]> ⊢ A[i,j] = A[j,i];
	// For fully symmetric higher-rank tensors, any permutation of indices leaves component unchanged.
```

### 4.4. Anti-symmetric (Skew-symmetric) Tensors
*   **Description:** A tensor is anti-symmetric with respect to a pair of indices if its components change sign when those indices are swapped.
A tensor is fully anti-symmetric if it's anti-symmetric with respect to all pairs of its indices.
*   **Orbit Domain (Example for rank-2):** `AntiSymmetricTensor<T, [N,N]>`
*   **Orbit Rules (Example for rank-2):**
	```orbit
	A : AntiSymmetricTensor<T,[N,N]> ⊢ A[i,j] = -(A[j,i]);
	A : AntiSymmetricTensor<T,[N,N]> ⊢ A[i,i] = 0; // Diagonal elements are zero (if 2*component != 0)
```

### 4.5. Diagonal Tensors
*   **Description:** A generalization of diagonal matrices. Components are non-zero only if all indices are equal (for a specific definition of "all indices equal" relevant to the tensor's use, usually for square-like shapes).
*   **Orbit Domain:** `DiagonalTensor<T, Shape>` (e.g., `DiagonalTensor<T, [N,N,N]>` implies `A[i,j,k] = 0` unless `i=j=k`).

## 5. Applications in Orbit

The tensor framework in Orbit has broad applicability.

### 5.1. Physics and Engineering
Many physical laws are expressed using tensor equations (e.g., Maxwell's equations, Einstein field equations, stress-strain relationships). Orbit could symbolically manipulate and simplify these equations.

### 5.2. Machine Learning
Modern machine learning, especially deep learning, heavily relies on tensor operations:
*   **Data Representation:** Inputs (images, videos, text embeddings), weights, biases, activations, and gradients are all represented as tensors.
*   **Core Operations:** `matmul` (matrix multiplication, a form of contraction), `convolution` (another specialized contraction), `reshape`, `permute` (index permutation), `transpose`, element-wise operations are all fundamental.
*   **Optimization Potential:** Orbit could optimize computation graphs of neural networks by simplifying tensor expressions, fusing operations, or choosing more efficient contraction orders (analogous to matrix chain multiplication problem but for general tensors).

### 5.3. Einstein Summation Convention
As mentioned (1.5, 2.2.2), Orbit could parse expressions like `"ij,jk->ik"` (for matrix multiply) or more complex ones, and convert them into a sequence of canonical `outer_product`, `permute_indices`, and `contract` operations. Conversely, sequences of these operations could be recognized and simplified or represented using Einstein notation.

```orbit
// Example conceptual rule
// For A:Tensor<_,[I,J]>, B:Tensor<_,[J,K]>
// contract(A, [1], B, [0]) // Contract 2nd dim of A with 1st dim of B
//    ↔ einsum_eval("ij,jk->ik", A, B); // Assuming einsum_eval is a canonical op
```

## 6. Tensor Algebra and Advanced Concepts (Brief Outlook)

*   **Tensor Algebra `T(V)`:** For a given vector space `V` over a field `F`, the tensor algebra `T(V)` is the direct sum of all tensor powers of `V` (i.e., `F ⊕ V ⊕ (V⊗V) ⊕ (V⊗V⊗V) ⊕ ...`). It forms an associative algebra with the tensor product `⊗` as multiplication. This provides a formal algebraic setting.
*   **Symmetric and Exterior Algebras:** Quotients of the tensor algebra lead to the Symmetric Algebra `Sym(V)` (for symmetric tensors) and the Exterior Algebra `Λ(V)` (for anti-symmetric tensors/differential forms, using the wedge product `∧`). These are crucial in differential geometry and theoretical physics.

While Orbit may not implement these abstract algebras in full generality initially, understanding these structures can guide the design of rules for symmetric and anti-symmetric tensors and their products.

## 7. Conclusion

Tensors, represented in Orbit as `Tensor<T, Shape>`, are a powerful and unifying mathematical concept. By defining a clear domain structure, a comprehensive set of fundamental operations, and leveraging its algebraic rewriting engine, Orbit can effectively simplify, canonicalize, and optimize tensor expressions. This capability is crucial for modern scientific computing, physics, engineering, and especially machine learning, where tensor manipulations are at the heart of many algorithms. The integration with existing algebraic hierarchies (like `VectorSpace`) allows for significant rule reuse and a principled approach to tensor mathematics within the Orbit system.
