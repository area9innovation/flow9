# Understanding Vectors in Orbit

Vectors are fundamental mathematical entities extensively used across various scientific and engineering disciplines, including computer graphics, physics, and machine learning. Within the Orbit system, vectors are not just abstract concepts but are formally defined and integrated into its domain-driven architecture, enabling powerful algebraic manipulations and optimizations. This chapter delves into the representation, operations, and applications of vectors in Orbit.

## 1. Introduction to Vectors

Conceptually, a vector is often described as an object possessing both **magnitude** (or length) and **direction**. It can represent quantities such as displacement, velocity, force, or even abstract data points in a multi-dimensional space. A vector is characterized by its components, the type of these components (e.g., `Real`, `Integer`), and its dimension (number of components).

In Orbit's formal system, as outlined in `terminology.md`, a generic `Vector` is an element of a **`VectorSpace`** defined over a **`Field F`**. More specifically, Orbit uses a parameterized domain `Vector<T, N>` where `T` is the component type (e.g., `Real`, `Int32`) and `N` is the dimension (a positive integer). This situates vectors within a rigorous algebraic structure, allowing Orbit to leverage the rich properties and theorems associated with vector spaces.

**Notation in Orbit (from `notation.md`):**

*   **Representation:** Vectors are typically represented as ordered lists of their components, using an array literal syntax.
    *   Example: A 2D vector `v` of type `Real` with components `x` and `y` is written as `[x, y]` and has the domain `Vector<Real, 2>`.
    *   Example: A 3D vector `u` of type `Integer` with components `x, y, z` is written as `[x, y, z]` and has the domain `Vector<Integer, 3>`.
*   **Element Access:** Individual components of a vector `V` are accessed using zero-based indexing.
    *   Syntax: `V[i]`
    *   Example: If `V = [5, 10, 15]` (which could be a `Vector<Integer, 3>`), then `V[0]` evaluates to `5`, `V[1]` to `10`, and `V[2]` to `15`.

## 2. Basic Vector Operations

Orbit supports standard vector operations, grounded in the axioms of a vector space. These operations typically require vectors to be of the same type `T` and dimension `N`.

*   **Vector Addition:**
    *   Notation: `u + v`
    *   Description: Vectors are added component-wise. `u` and `v` must be `Vector<T, N>`. The result is also `Vector<T, N>`.
    *   Example: `[1, 2, 3]:Vector<Real,3> + [4, 5, 6]:Vector<Real,3> = [1+4, 2+5, 3+6] = [5, 7, 9]:Vector<Real,3>`
*   **Scalar Multiplication:**
    *   Notation: `s * v` (where `s` is a scalar of type `T` or compatible with `T`)
    *   Description: Each component of the vector `v:Vector<T,N>` is multiplied by the scalar `s`. The result is `Vector<T,N>`.
    *   Example: `3:Real * [1, 2, 4]:Vector<Real,3> = [3*1, 3*2, 3*4] = [3, 6, 12]:Vector<Real,3>`
*   **Dot Product (Inner Product):**
    *   Notation: `u ⋅ v` or `dot_product(u, v)` (`⋅` preferred).
    *   Description: The dot product of two vectors `u:Vector<T,N>` and `v:Vector<T,N>` is a scalar value of type `T`. For `u = [u₁, ..., uₙ]` and `v = [v₁, ..., vₙ]`:
        `u ⋅ v = u₁v₁ + ... + uₙvₙ`
    *   Example: `[1, 2, 3]:Vector<Real,3> ⋅ [4, 0, -2]:Vector<Real,3> = (1*4) + (2*0) + (3*-2) = -2 : Real`
    *   Geometric Significance (typically for `Vector<Real, N>`):
        *   `u ⋅ v = ‖u‖ ‖v‖ cos(θ)`, where `θ` is the angle between `u` and `v`.
        *   If `u ⋅ v = 0` (and `u`, `v` are non-zero), the vectors are orthogonal.
*   **Cross Product (Specifically for 3D Vectors, `Vector<T, 3>`):**
    *   Notation: `u × v` or `cross_product(u, v)` (`×` preferred).
    *   Description: The cross product of two 3D vectors `u:Vector<T,3> = [uₓ, uᵧ, u₂]` and `v:Vector<T,3> = [vₓ, vᵧ, v₂]` is another `Vector<T,3>`:
        `u × v = [uᵧv₂ - u₂vᵧ,  u₂vₓ - uₓv₂,  uₓvᵧ - uᵧvₓ]`
    *   Example: `[1,0,0]:Vector<Real,3> × [0,1,0]:Vector<Real,3> = [0,0,1]:Vector<Real,3>`
    *   Geometric Significance (typically for `Vector<Real, 3>`):
        *   The resulting vector `u × v` is orthogonal to both `u` and `v`.
        *   The magnitude `‖u × v‖ = ‖u‖ ‖v‖ sin(θ)`.
*   **Norm (Magnitude/Length):**
    *   Notation: `‖v‖` or `norm(v)`.
    *   Description: The norm of a `v:Vector<T,N>` is a non-negative scalar (typically `Real`).
        `‖v‖ = sqrt(v₁² + ... + vₙ²) = sqrt(v ⋅ v)` (Requires `T` to support `²` and `sqrt`, often `T=Real`).
    *   Example: For `v = [3, 4]:Vector<Real,2>`, `‖v‖ = sqrt(3² + 4²) = 5 : Real`.
*   **Unit Vector:**
    *   Description: A vector with a norm of 1.
    *   Calculation: `û = v / ‖v‖` (Requires `v:Vector<Real,N>`). Result is `Vector<Real,N>`.
    *   Example: For `v = [3,4]:Vector<Real,2>`, `û = [3/5, 4/5]:Vector<Real,2>`.

## 3. Vectors in 2D/3D Graphics and Transformations

As detailed in `matrix5.md`, `Vector<T,N>` instances are crucial in computer graphics, especially with homogeneous coordinates. `T` is commonly `Real` (e.g., `Float32` or `Float64`).

*   **Homogeneous Coordinates:**
    *   **Purpose:** Augments coordinates with `w`, allowing affine and projective transformations via matrix multiplication.
    *   **Points:**
        *   A 2D point `(x, y)` (components of type `T`) becomes `[x, y, 1]`.
            *   Orbit Domain: `HomogeneousPoint2D<T> ⊂ Vector<T, 3>` (as defined in `matrix5.md`).
        *   A 3D point `(x, y, z)` becomes `[x, y, z, 1]`.
            *   Orbit Domain: `HomogeneousPoint3D<T> ⊂ Vector<T, 4>` (as defined in `matrix5.md`).
    *   **Direction Vectors:** Have `w=0`.
        *   2D direction `(vx, vy)` (components type `T`): `[vx, vy, 0]`, a `Vector<T, 3>`.
        *   3D direction `(vx, vy, vz)`: `[vx, vy, vz, 0]`, a `Vector<T, 4>`.
        *   **Significance of `w=0`:** Direction vectors are invariant under translation.
            Example: `M_trans * d_homogenousᵀ = d_homogenousᵀ`.

*   **Vectors in Transformation Matrices:**
    *   **Translation Vectors:** A translation by `(tx, ty, tz)` (components type `T`) uses a vector `t = [tx, ty, tz]:Vector<T,3>`.
        `Matrix_translate(tx,ty,tz)` (a 4x4 matrix) incorporates `t`.
        Orbit's `decompose_affine(M:AffineMatrix3D)` extracts `translation_part:Vector<Real,3>`.
    *   **Scaling Vectors:** Scaling factors `(sx, sy, sz)` can be seen as `s = [sx, sy, sz]:Vector<T,3>`.
    *   **Rotation Axes:** `rotate3D_axis(ax, ay, az, angle)` uses `[ax, ay, az]:Vector<T,3>` as the axis.

*   **Other Graphics Applications (typically `Vector<Real,N>`):**
    *   Surface Normals (`Vector<Real,3>`), Velocity/Acceleration, View Vectors, Light Vectors.

## 4. Vectors in Orbit's Domain System

*   **Core Domains:**
    *   `Vector<T, N>`: The primary parameterized domain.
    *   `VectorSpace` (over field `F`): The abstract algebraic structure. `Vector<T,N>` (where `T` is a field element) instantiates `VectorSpace`.
    *   `HomogeneousPoint2D<T> ⊂ Vector<T, 3>`
    *   `HomogeneousPoint3D<T> ⊂ Vector<T, 4>`
*   **Relationship with Matrices:**
    *   Matrix-Vector Multiplication: `M * v` (where `M` is `Matrix<T, R, C>` and `v` is `Vector<T, C>`, result is `Vector<T, R>`).
    *   **Specialized Use Cases (from `matrix.md`):
        *   One-Hot Vectors (e.g., `Vector<Integer, K>`). Multiplication by an embedding matrix selects a row/column.
*   **Algebraic Properties and Rewriting:**
    *   `Vector<T,N>` (under addition) forms an `AbelianGroup`.
    *   `Vector<T,N>` (with scalar multiplication over field `T`) forms a `VectorSpace`.
    *   These allow Orbit to apply general algebraic laws.

## 5. Orbit Rewriting Rules for Vectors

Rules apply to `u:Vector<T,N>`, `v:Vector<T,N>`, `w:Vector<T,N>`. `s:T`, `t:T` are scalars. `0⃗:Vector<T,N>` is the zero vector.

**Vector Addition (from `AbelianGroup` on `Vector<T,N>`):**
```orbit
// Commutativity
u:Vector<T,N> + v:Vector<T,N> ↔ v + u : Vector<T,N> : S₂

// Associativity (n-ary `+`)
// (u:Vector<T,N> + v:Vector<T,N>) + w:Vector<T,N> ↔ u + (v + w) : Vector<T,N>

// Additive Identity
u:Vector<T,N> + 0⃗:Vector<T,N> → u : Vector<T,N>
0⃗:Vector<T,N> + u:Vector<T,N> → u : Vector<T,N>

// Additive Inverse
u:Vector<T,N> + (-u:Vector<T,N>) → 0⃗ : Vector<T,N>
```

**Scalar Multiplication (from `VectorSpace` properties for `Vector<T,N>`):**
```orbit
// Distributivity over vector addition
s:T * (u:Vector<T,N> + v:Vector<T,N>) → (s * u) + (s * v) : Vector<T,N>

// Distributivity over scalar addition
(s:T + t:T) * u:Vector<T,N> → (s * u) + (t * u) : Vector<T,N>

// Compatibility of scalar multiplication
(s:T * t:T) * u:Vector<T,N> → s * (t * u) : Vector<T,N>

// Identity for scalar multiplication
1:T * u:Vector<T,N> → u : Vector<T,N>  // Assuming T has a multiplicative identity 1

// Multiplication by zero scalar
0:T * u:Vector<T,N> → 0⃗ : Vector<T,N> // Assuming T has an additive identity 0

// Multiplication by -1 scalar
-1:T * u:Vector<T,N> → -u : Vector<T,N> // Assuming T has -1
```

**Dot Product Properties (for `u:Vector<T,N>`, `v:Vector<T,N>`, `w:Vector<T,N>` result in `T`):**
```orbit
// Commutativity
u:Vector<T,N> ⋅ v:Vector<T,N> ↔ v ⋅ u : T : S₂

// Distributivity over vector addition
u:Vector<T,N> ⋅ (v:Vector<T,N> + w:Vector<T,N>) → (u ⋅ v) + (u ⋅ w) : T
(u:Vector<T,N> + v:Vector<T,N>) ⋅ w:Vector<T,N> → (u ⋅ w) + (v ⋅ w) : T

// Bilinearity (scalar multiplication)
(s:T * u:Vector<T,N>) ⋅ v:Vector<T,N> → s * (u ⋅ v) : T
u:Vector<T,N> ⋅ (s:T * v:Vector<T,N>) → s * (u ⋅ v) : T

// Dot product with zero vector
u:Vector<T,N> ⋅ 0⃗:Vector<T,N> → 0 : T
0⃗:Vector<T,N> ⋅ u:Vector<T,N> → 0 : T

// Relation to Norm (if T=Real)
u:Vector<Real,N> ⋅ u:Vector<Real,N> → ‖u‖² : Real
```

**Cross Product Properties (for `Vector<T,3>`):**
```orbit
// Anti-Commutativity
u:Vector<T,3> × v:Vector<T,3> → -(v × u) : Vector<T,3>

// Distributivity over vector addition
u:Vector<T,3> × (v:Vector<T,3> + w:Vector<T,3>) → (u × v) + (u × w) : Vector<T,3>
(u:Vector<T,3> + v:Vector<T,3>) × w:Vector<T,3> → (u × w) + (v × w) : Vector<T,3>

// Scalar multiplication
(s:T * u:Vector<T,3>) × v:Vector<T,3> → s * (u × v) : Vector<T,3>
u:Vector<T,3> × (s:T * v:Vector<T,3>) → s * (u × v) : Vector<T,3>

// Cross product with zero vector
u:Vector<T,3> × 0⃗:Vector<T,3> → 0⃗ : Vector<T,3>
0⃗:Vector<T,3> × u:Vector<T,3> → 0⃗ : Vector<T,3>

// Cross product of a vector with itself
u:Vector<T,3> × u:Vector<T,3> → 0⃗ : Vector<T,3>
```

**Norm Properties (typically for `Vector<Real,N>`):**
```orbit
// Non-negativity
‖u:Vector<Real,N>‖ ≥ 0 : Boolean

// Definiteness
‖u:Vector<Real,N>‖ = 0 ↔ u = 0⃗:Vector<Real,N> : Boolean

// Homogeneity
‖s:Real * u:Vector<Real,N>‖ → abs(s) * ‖u‖ : Real

// Triangle Inequality
‖u:Vector<Real,N> + v:Vector<Real,N>‖ ≤ ‖u‖ + ‖v‖ : Boolean
```
These rules, applied via Orbit's e-graph, simplify vector expressions. The domain hierarchy ensures rules for `VectorSpace` or `AbelianGroup` apply to specific `Vector<T,N>` types like `Vector<Real,3>` or `HomogeneousPoint2D<Real>` (which is `Vector<Real,3>`).

## 6. Conclusion

Vectors, represented as `Vector<T,N>` in Orbit, are indispensable. Their formal definition and associated algebraic rewrite rules allow for robust analysis, transformation, and optimization of vector-based expressions, particularly in graphics and machine learning.

Refer to `matrix5.md` for vector interactions with graphics matrices and other `matrix*.md` files for broader matrix algebra involving vectors.
