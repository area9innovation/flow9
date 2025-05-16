# Understanding Tensors in Orbit

Tensors are mathematical objects that generalize scalars, vectors, and matrices to higher dimensions. They are essential in numerous fields, including physics (e.g., stress, strain, electromagnetism), engineering, data science (e.g., multi-dimensional data arrays), and machine learning (e.g., weights in neural networks). This chapter explores how tensors are represented, manipulated, and reasoned about within the Orbit system.

## 1. Introduction to Tensors

A tensor can be understood as a multi-dimensional array of numerical values. The **rank** (or order) of a tensor indicates the number of dimensions or indices required to specify an individual component.

*   A **scalar** is a rank-0 tensor (0 indices).
*   A **vector** is a rank-1 tensor (1 index).
*   A **matrix** is a rank-2 tensor (2 indices).

Orbit uses a parameterized domain `Tensor<T, Shape>` to represent tensors, where:
*   `T` is the type of the tensor's components (e.g., `Real`, `Integer`, `Complex`).
*   `Shape` is a list of positive integers defining the size of each dimension (e.g., `[N]`, `[M, N]`, `[P, M, N]`)

**Notation in Orbit:**

*   **Representation:** Tensors are represented as nested lists (arrays) corresponding to their rank and shape.
    *   Rank-0 Tensor (Scalar `s:T`): `s` (Domain: `Tensor<T, []>`).
    *   Rank-1 Tensor (Vector `v:Vector<T,N>`): `[v₀, v₁, ..., v₍N-₁₎]` (Domain: `Tensor<T, [N]>`).
    *   Rank-2 Tensor (Matrix `M:Matrix<T,R,C>`): `[[m₀₀, ..., m₀₍C-₁₎], ..., [m₍R-₁₎₀, ..., m₍R-₁₎₍C-₁₎]]` (Domain: `Tensor<T, [R, C]>`).
    *   Rank-3 Tensor (e.g., `A:Tensor<T, [P,M,N]>`): A list of `P` matrices, where each matrix is `M x N`.
*   **Element Access:** Components are accessed using multiple indices.
    *   Syntax: `A[i, j, k, ...]`
    *   Example: For `A:Tensor<Real, [2,2,2]>`, `A[0,1,0]` accesses a specific scalar component.
*   **Index Notation (Conceptual, from `terminology.md`):** Physics and mathematics often use index notation like `Tᵢⱼᵏ` or `Tᵃᵦ`, where superscripts and subscripts denote contravariant and covariant indices, respectively. Orbit's focus is typically on the array representation but can symbolically manipulate expressions involving such indices.

## 2. Basic Tensor Operations

Several fundamental operations are defined for tensors. `T` is the component type, and shapes must be compatible for operations.

*   **Tensor Addition/Subtraction:**
    *   Notation: `A + B`, `A - B`
    *   Description: Performed element-wise. Tensors `A` and `B` must have the same type `T` and the same shape. The result is a tensor of the same type and shape.
    *   Example: If `A, B : Tensor<Real, [2,2]>`, then `(A+B)[i,j] = A[i,j] + B[i,j]`.
*   **Scalar Multiplication:**
    *   Notation: `s * A`
    *   Description: Each component of tensor `A:Tensor<T,Shape>` is multiplied by scalar `s:T`. The result is `Tensor<T,Shape>`.
*   **Tensor Contraction (Generalized Inner Product):**
    *   Description: Reduces the rank of a tensor (or product of tensors) by summing over one or more pairs of indices. A common example is matrix multiplication, which is a contraction of the outer product of two matrices.
        *   Vector dot product (`u ⋅ v`): Contraction of `uᵢvᵢ` over `i`.
        *   Matrix trace (`tr(M)`): Contraction `Mᵢᵢ` over `i`.
        *   Matrix-vector product `(Mv)ᵢ = Mᵢⱼvⱼ` (sum over `j`).
        *   Matrix-matrix product `(AB)ᵢₖ = AᵢⱼBⱼₖ` (sum over `j`).
    *   Orbit can represent these operations using explicit functions or by recognizing patterns amenable to Einstein summation notation (see `terminology.md`).
*   **Outer Product (Tensor Product):**
    *   Notation: `A ⊗ B` or `outer_product(A, B)` (Orbit prefers `⊗` or `kronecker` as per `notation.md` for Kronecker product, a specific type of outer product).
    *   Description: Creates a higher-rank tensor from two lower-rank tensors. If `A:Tensor<T,ShapeA>` and `B:Tensor<T,ShapeB>`, then `A ⊗ B` has shape `ShapeA + ShapeB` (concatenation of shape lists).
    *   ` (A ⊗ B)[i₁...,j₁...] = A[i₁...] * B[j₁...] `
    *   Example: Outer product of two vectors `u:Tensor<T,[M]>` and `v:Tensor<T,[N]>` results in a matrix (rank-2 tensor) `W:Tensor<T,[M,N]>` where `W[i,j] = u[i] * v[j]`.
*   **Element-wise Product (Hadamard Product for Matrices/Vectors):**
    *   Notation: `hadamard_product(A, B)` or `AodotB` (conceptual, `∘` is often used but can conflict with composition).
    *   Description: Tensors `A` and `B` must have the same type `T` and shape. The result is a tensor of the same type and shape, where components are `(A ∘ B)[i,j,...] = A[i,j,...] * B[i,j,...]`.
*   **Permutation of Indices:**
    *   Description: Rearranges the order of indices of a tensor, effectively reordering its data. For a matrix `M:Tensor<T,[R,C]>`, transposing `Mᵀ` is a permutation of indices `(i,j) → (j,i)`. This changes its shape to `[C,R]`.
    *   More generally, for `A:Tensor<T, [d₁, d₂, d₃]>`, permuting indices `(0,1,2) → (2,0,1)` results in `A':Tensor<T, [d₃, d₁, d₂]>` where `A'[k,i,j] = A[i,j,k]`.

## 3. Tensors in Orbit's Domain System

*   **Core Domain:**
    *   `Tensor<T, Shape>`: The primary parameterized domain for tensors, where `T` is the component type and `Shape` is a list of integers representing dimensions.
*   **Relationship to Other Structures:**
    *   `Vector<T, N>` is equivalent to `Tensor<T, [N]>`.
    *   `Matrix<T, R, C>` is equivalent to `Tensor<T, [R, C]>`.
    *   `Tensor<T, Shape>` instances, under element-wise addition and scalar multiplication, form a **`VectorSpace`** (and thus an `AbelianGroup` under addition). This allows Orbit to apply general algebraic rules.
*   **TensorSpace (Conceptual):** While not explicitly a primitive domain in `terminology.md`'s hierarchy, the collection of all tensors of a given type `T` and shape forms a vector space. Operations like contraction and outer product define additional algebraic structure on these spaces (e.g., forming a Tensor Algebra).
*   **Symmetries:** Specific tensors can possess symmetries (e.g., symmetric tensor where `Tᵢⱼ = Tⱼᵢ`, anti-symmetric `Tᵢⱼ = -Tⱼᵢ`). These can be represented by additional domain annotations or entailments in Orbit, leading to specialized rewrite rules.

## 4. Orbit Rewriting Rules for Tensors

Rules apply to tensors `A, B, C : Tensor<T, Shape>` (assuming compatible shapes for operations). `s, t : T` are scalars. `0̿:Tensor<T,Shape>` is the zero tensor of the given shape.

**Tensor Addition (from `AbelianGroup` on `Tensor<T,Shape>`):**
```orbit
// Commutativity
A:Tensor<T,Shape> + B:Tensor<T,Shape> ↔ B + A : Tensor<T,Shape> : S₂

// Associativity (n-ary `+`)
// (A:Tensor<T,Shape> + B:Tensor<T,Shape>) + C:Tensor<T,Shape> ↔ A + (B + C) : Tensor<T,Shape>

// Additive Identity
A:Tensor<T,Shape> + 0̿:Tensor<T,Shape> → A : Tensor<T,Shape>
0̿:Tensor<T,Shape> + A:Tensor<T,Shape> → A : Tensor<T,Shape>

// Additive Inverse
A:Tensor<T,Shape> + (-A:Tensor<T,Shape>) → 0̿ : Tensor<T,Shape>
```

**Scalar Multiplication (from `VectorSpace` properties for `Tensor<T,Shape>`):**
```orbit
// Distributivity over tensor addition
s:T * (A:Tensor<T,Shape> + B:Tensor<T,Shape>) → (s * A) + (s * B) : Tensor<T,Shape>

// Distributivity over scalar addition
(s:T + t:T) * A:Tensor<T,Shape> → (s * A) + (t * A) : Tensor<T,Shape>

// Compatibility of scalar multiplication
(s:T * t:T) * A:Tensor<T,Shape> → s * (t * A) : Tensor<T,Shape>

// Identity for scalar multiplication
1:T * A:Tensor<T,Shape> → A : Tensor<T,Shape> // If T has identity 1

// Multiplication by zero scalar
0:T * A:Tensor<T,Shape> → 0̿:Tensor<T,Shape> // If T has zero 0
```

**Outer Product (Tensor Product `⊗`):**
```orbit
// Distributivity over addition (bilinearity)
A ⊗ (B + C) → (A ⊗ B) + (A ⊗ C) // Assuming compatible shapes and types
(A + B) ⊗ C → (A ⊗ C) + (B ⊗ C)

// Scalar multiplication
(s * A) ⊗ B → s * (A ⊗ B)
A ⊗ (s * B) → s * (A ⊗ B)

// Associativity (conceptual, shapes change)
// (A ⊗ B) ⊗ C ↔ A ⊗ (B ⊗ C) // Resulting tensor has same elements in different order based on index grouping
```

**Tensor Contraction (Conceptual rules, specific rules depend on indices):**
Let `contract(Tensor, index_pairs)` be a contraction operation.
```orbit
// Linearity
contract(A + B, pairs) → contract(A, pairs) + contract(B, pairs)
contract(s * A, pairs) → s * contract(A, pairs)

// Contraction of an outer product can simplify
// e.g., contract(u ⊗ v, [(0,1)]) where u,v are vectors → u ⋅ v (dot product)
```

**Index Permutation:**
Let `permute_indices(Tensor, permutation_map)` be the operation.
```orbit
// Permuting then permuting by inverse yields original
permute_indices(permute_indices(A, p₁), p₂) → A if p₂ = inverse_permutation(p₁)

// Permuting indices of a sum
permute_indices(A + B, p) → permute_indices(A, p) + permute_indices(B, p)

// Permuting indices of a scalar multiple
permute_indices(s * A, p) → s * permute_indices(A, p)
```

**Symmetric/Anti-symmetric Tensors (Rank-2 example `A:Tensor<T,[N,N]>`):**
```orbit
// If A is symmetric (A : SymmetricTensor)
A[i,j] : SymmetricTensor → A[j,i]

// If A is anti-symmetric (A : AntiSymmetricTensor)
A[i,j] : AntiSymmetricTensor → -A[j,i]
A[i,i] : AntiSymmetricTensor → 0 // Diagonal elements are zero
```
These high-level rules can be instantiated for specific tensor ranks and operations.

## 5. Applications and Einstein Summation

Tensors are fundamental to representing physical laws and multi-linear relationships. Orbit's `terminology.md` mentions **Einstein Summation Convention**, where repeated indices imply summation. For example, `Cᵢⱼ = AᵢₖBₖⱼ` implies `Cᵢⱼ = Σₖ AᵢₖBₖⱼ`. Recognizing such patterns can lead to powerful symbolic manipulation and code generation for tensor computations.

Tensor calculus, also mentioned, involves operations like covariant derivatives and manipulation of tensor fields, which are beyond basic tensor algebra but rely on its foundations.

## 6. Conclusion

Tensors, as `Tensor<T, Shape>` in Orbit, provide a powerful generalization of scalars, vectors, and matrices. By embedding them within a formal domain system that recognizes their algebraic properties (notably as elements of a VectorSpace), Orbit can apply a rich set of rewrite rules for simplification, canonicalization, and optimization. This is particularly relevant for applications in physics, engineering, and machine learning where complex tensor manipulations are common. The ability to handle operations like contraction, outer product, and index permutations symbolically opens avenues for advanced computational algebra within the Orbit framework.
