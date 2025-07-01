# Orbit and Specialized Matrices in 2D/3D Computer Graphics

## Introduction

Computer graphics, computer vision, robotics, and computational geometry rely heavily on a specialized set of matrices for geometric transformations. These transformations include translation, scaling, rotation, shear, and projection. Understanding the algebraic structure and group-theoretic properties of these matrices is crucial for optimizing rendering pipelines, animation systems, and geometric algorithms.

This document explores how Orbit can represent, reason about, and optimize operations involving these specialized matrices, particularly in the context of 2D and 3D graphics. A key strategy is to define a high-level **Graphics DSL (Domain Specific Language)** for transformations and establish **bidirectional rewrite rules** between DSL operations and their matrix representations. This allows Orbit to:
1.  **Lift** graphics operations into the matrix domain.
2.  Apply its full suite of matrix algebra tools for **composition, simplification, and analysis** (e.g., recognizing identities, group properties, or special structures like triangular forms).
3.  Potentially **Lower** an optimized matrix back into a canonical or simplified DSL sequence.

## Homogeneous Coordinates

In 2D or 3D Euclidean space, a point is typically represented as `(x, y)` or `(x, y, z)`. Homogeneous coordinates augment these with an additional coordinate, `w`.
*   A 2D point `(x, y)` becomes `(x*w, y*w, w)`. Typically, `w=1` for points, so `(x, y, 1)`.
*   A 3D point `(x, y, z)` becomes `(x*w, y*w, z*w, w)`. Typically, `w=1` for points, so `(x, y, z, 1)`.
*   Vectors (representing directions, with no fixed position) often have `w=0`, e.g., `(vx, vy, vz, 0)`.

This representation allows a `(n+1)x(n+1)` matrix to perform affine transformations (like translation) and projective transformations on `n`-dimensional points.

```orbit
// Conceptual domain for homogeneous coordinates
HomogeneousPoint2D<T> ⊂ Vector<T, 3>
HomogeneousPoint3D<T> ⊂ Vector<T, 4>

// Conversion rules (conceptual)
to_homogeneous(p : Point2D) → point(p.x, p.y, 1) : HomogeneousPoint2D;
to_euclidean(hp : HomogeneousPoint2D) → point(hp.x/hp.w, hp.y/hp.w) : Point2D if hp.w != 0;
```

## A Simple Graphics DSL and Bidirectional Matrix Conversion

We can define a simple DSL for common graphics operations. Orbit can then convert these to and from their matrix forms.

**DSL Operations (Examples):**

*   `translate2D(tx, ty)`
*   `scale2D(sx, sy)`
*   `rotate2D(angle_rad)`
*   `translate3D(tx, ty, tz)`
*   `scale3D(sx, sy, sz)`
*   `rotate3D_axis(axis_x, axis_y, axis_z, angle_rad)` (Rodrigues' rotation or quaternion-based)
*   `perspective3D(fov_y, aspect, near, far)`

**Orbit Domains for DSL Operations and Matrices:**

```orbit
// DSL Operation Domains
OpTranslate2D<tx, ty> : GraphicsOperation2D
OpScale2D<sx, sy> : GraphicsOperation2D
OpRotate2D<angle> : GraphicsOperation2D
OpTranslate3D<tx, ty, tz> : GraphicsOperation3D
// ... and so on for other DSL operations

// Transformation Matrix Domains
TransformationMatrix2D ⊂ Matrix<Real, 3, 3> // Using Real for typical graphics floats
TransformationMatrix3D ⊂ Matrix<Real, 4, 4>

// Domains for specific matrix types recognized by their structure
CanonicalTranslationMatrix2D<tx, ty> ⊂ TransformationMatrix2D
CanonicalScaleMatrix3D<sx, sy, sz> ⊂ TransformationMatrix3D
CanonicalRotationMatrix2D<angle> ⊂ TransformationMatrix2D
```

**Bidirectional Rewrite Rules (Lifting DSL to Matrix & Lowering Matrix to DSL):**

The `↔` symbol indicates a bidirectional rewrite rule, allowing Orbit to convert in either direction.

1.  **2D Translation:**
```orbit
	// DSL to Matrix (Lifting)
	translate2D(tx, ty) : OpTranslate2D<tx,ty> ↔
		matrix([
			[1, 0, tx],
			[0, 1, ty],
			[0, 0, 1]
		]) : CanonicalTranslationMatrix2D<tx, ty>;

	// Matrix to DSL (Lowering - if matrix matches the specific pattern)
	M : Matrix<Real,3,3> where M = [[1,0,tx_val],[0,1,ty_val],[0,0,1]] ↔
		translate2D(tx_val, ty_val) : OpTranslate2D<tx_val, ty_val>;
```

2.  **2D Scaling:**
```orbit
	scale2D(sx, sy) : OpScale2D<sx,sy> ↔
		matrix([
			[sx, 0,  0],
			[0,  sy, 0],
			[0,  0,  1]
		]) : CanonicalScaleMatrix2D<sx, sy>;

	M : Matrix<Real,3,3> where M = [[sx_val,0,0],[0,sy_val,0],[0,0,1]] ↔
		scale2D(sx_val, sy_val) : OpScale2D<sx_val, sy_val>;
```

3.  **2D Rotation (around origin):**
    Let `c = cos(angle_rad)`, `s = sin(angle_rad)`.
```orbit
	rotate2D(angle) : OpRotate2D<angle> ↔
		matrix([
			[cos(angle), -sin(angle), 0],
			[sin(angle),  cos(angle), 0],
			[0,           0,          1]
		]) : CanonicalRotationMatrix2D<angle>;

	// Recognizing a rotation matrix is more complex due to floating point values
	// and trigonometric identities. Rules might involve checking R*Rᵀ=I, det(R)=1,
	// and extracting the angle.
	M : Matrix<Real,3,3> where is_so2_matrix_form(M) ↔
		rotate2D(extract_so2_angle(M)) : OpRotate2D<extract_so2_angle(M)>;
```

4.  **3D Translation:**
```orbit
	translate3D(tx, ty, tz) : OpTranslate3D<tx,ty,tz> ↔
		matrix([
			[1, 0, 0, tx],
			[0, 1, 0, ty],
			[0, 0, 1, tz],
			[0, 0, 0, 1]
		]) : CanonicalTranslationMatrix3D<tx, ty, tz>;

	M : Matrix<Real,4,4> where M = [[1,0,0,tx_val],[0,1,0,ty_val],[0,0,1,tz_val],[0,0,0,1]] ↔
		translate3D(tx_val, ty_val, tz_val) : OpTranslate3D<tx_val, ty_val, tz_val>;
```

**Leveraging Matrix Algebra:**

Once DSL operations are lifted to matrices, Orbit's full power comes into play:
*   **Composition:** A sequence of DSL commands `op1; op2; op3;` becomes `Matrix(op3) * Matrix(op2) * Matrix(op1)`.
```orbit
	// Example: translate2D(10,0) then rotate2D(pi/2)
	// Lifts to: M_rot * M_trans
	// Orbit computes the product:
	// [[0,-1,0],[1,0,0],[0,0,1]] * [[1,0,10],[0,1,0],[0,0,1]] = [[0,-1,0],[1,0,10],[0,0,1]]
```
*   **Simplification & Canonicalization:**
    *   `translate2D(tx1, ty1) * translate2D(tx2, ty2) → translate2D(tx1+tx2, ty1+ty2)` (via matrix product and then lowering, or a direct DSL rule).
    *   `rotate2D(a1) * rotate2D(a2) → rotate2D(a1+a2)`.
    *   A matrix might be identified as a special form discussed in other `matrix*.md` files (e.g., `UpperTriangularMatrix`, `OrthogonalMatrix`) enabling further simplifications or choice of specialized algorithms. For example, if a sequence of 2D transformations results in `[[s, 0, tx], [0, s, ty], [0,0,1]]`, it can be lowered to `scale2D_uniform_then_translate2D(s, tx, ty)`.
*   **Inverse Operations:** `inverse(translate2D(tx,ty))` can be found by inverting the matrix and then lowering the result back to `translate2D(-tx,-ty)`.
*   **Group Properties:** The system can use the group properties (e.g., SO(2) for 2D rotations, Affine group for compositions) discussed later.

## Special Matrix Forms and Their Geometric Actions

The following table details common transformation matrices. Orbit aims to recognize these forms, either from DSL lifting or from general matrix operations.

| **Name**                    | **Form (Homogeneous Coordinates)**                                                                                                                                                                | **Geometric Action**       | **Group-Theoretic Properties**                                                                                                           | **Notes**                                         |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| **Translation**             | 2D: $\begin{bmatrix} 1 & 0 & t_x \\ 0 & 1 & t_y \\ 0 & 0 & 1 \end{bmatrix}$<br>3D: $\begin{bmatrix} 1 & 0 & 0 & t_x \\ 0 & 1 & 0 & t_y \\ 0 & 0 & 1 & t_z \\ 0 & 0 & 0 & 1 \end{bmatrix}$ | Shifts points              | Forms an abelian group isomorphic to $\mathbb{R}^n$ under addition; translation subgroup of affine/Euclidean groups.                     | Represented in homogeneous coordinates.           |
| **Scaling**                 | 2D: $\begin{bmatrix} s_x & 0 & 0 \\ 0 & s_y & 0 \\ 0 & 0 & 1 \end{bmatrix}$<br>3D: $\begin{bmatrix} s_x & 0 & 0 & 0 \\ 0 & s_y & 0 & 0 \\ 0 & 0 & s_z & 0 \\ 0 & 0 & 0 & 1 \end{bmatrix}$ | Expands/contracts axes     | Abelian group (if $s_i \neq 0$); forms diagonal subgroup of GL(n) (considering the linear part).                                         | Uniform if $s_x = s_y (= s_z)$.                   |
| **Rotation**                | 2D: $\begin{bmatrix} \cos\theta & -\sin\theta & 0 \\ \sin\theta & \cos\theta & 0 \\ 0 & 0 & 1 \end{bmatrix}$<br>3D (about axis): Forms are more complex, often built from basis rotations. | Rotates points             | Special Orthogonal group SO(2) or SO(3). SO(2) is abelian, SO(3) is non-abelian.                                                          | 3D: Rodrigues’ formula for arbitrary axis. Quaternions are often used. |
| **Reflection**              | e.g., 2D (over Y-axis): $\begin{bmatrix} -1 & 0 & 0 \\ 0 & 1 & 0 \\ 0 & 0 & 1 \end{bmatrix}$                                                                                               | Flips over axis/plane      | Subgroup of Orthogonal group O(2) or O(3); determinant is -1.                                                                            | Involutory ($A^2 = I$).                           |
| **Shear**                   | e.g., 2D (X-shear): $\begin{bmatrix} 1 & k & 0 \\ 0 & 1 & 0 \\ 0 & 0 & 1 \end{bmatrix}$                                                                                                     | Skews along an axis        | Forms a subgroup (specific to shear type, e.g., upper triangular with 1s on diagonal). Generally non-abelian if combined.               | Preserves area/volume.                             |
| **Perspective Projection**  | 3D to 2D (simple, project to z=d plane): $\begin{bmatrix} d & 0 & 0 & 0 \\ 0 & d & 0 & 0 \\ 0 & 0 & d & 0 \\ 0 & 0 & 1 & 0 \end{bmatrix}$ (then divide by w). More complex forms for view frustum. | Projects to plane          | Not a group under multiplication; part of projective transformations PGL(n+1, ℝ).                                                         | Homogeneous coordinates essential. Division by `w` after multiplication. |
| **Orthographic Projection** | e.g., 3D to XY plane: $\begin{bmatrix} 1 & 0 & 0 & 0 \\ 0 & 1 & 0 & 0 \\ 0 & 0 & 0 & 0 \\ 0 & 0 & 0 & 1 \end{bmatrix}$ | Flattens to plane (drops a coordinate) | Not invertible from 3D to 2D space, not a group.                                                                                          | Simpler than perspective, preserves parallel lines. |
| **Affine Transformation**   | General form (homogeneous): $\begin{bmatrix} A & \mathbf{t} \\ \mathbf{0}^T & 1 \end{bmatrix}$, where $A$ is an $n \times n$ invertible linear transformation, $\mathbf{t}$ is $n \times 1$ translation. | Any combination of linear transformations and translation. | Affine group Aff(n), semi-direct product GL(n) $\ltimes \mathbb{R}^n$.                                                                     | Includes translation, rotation, scaling, shear, reflection. Preserves parallelism. |
| **Similarity**              | Uniform scaling $\times$ Rotation $\times$ Translation.                                                                                                                                          | Preserves shapes, not necessarily size. | Similarity group. Subgroup of Aff(n).                                                                                                    | $A = sR$ where $s$ is scalar, $R \in O(n)$.        |
| **Isometry (Euclidean)**    | Rotation $\times$ Reflection $\times$ Translation.                                                                                                                                               | Distance-preserving        | Euclidean group E(n) = O(n) $\ltimes \mathbb{R}^n$.                                                                                        | Preserves distances and angles.                   |
| **Homography (Projective)** | General $(n+1)\times(n+1)$ invertible matrix, unique up to scale.                                                                                                                               | General projective map     | Projective Linear Group PGL(n+1, ℝ).                                                                                                      | Maps lines to lines. Used for camera transformations, image stitching. |


## Group-Theoretic Structure in Graphics

The algebraic structures of these transformations are key:

*   **SO(2), SO(3):** Groups of pure rotations. SO(2) (2D rotations) is abelian. SO(3) (3D rotations) is non-abelian. Orbit can use these properties for canonicalization or simplification of rotation sequences.
```orbit
	// R_z(a1) * R_z(a2) -> R_z(a1+a2) (rotations about the same axis commute)
	// R_x(a) * R_y(b) != R_y(b) * R_x(a) (rotations about different axes generally don't)
```
*   **O(2), O(3):** Orthogonal groups, including rotations and reflections.
*   **Affine Group (Aff(n)):** Comprises all invertible affine transformations. It's a semidirect product GL(n) $\ltimes \mathbb{R}^n$. This means an affine map can be decomposed into a linear transformation (GL(n)) followed by a translation ($\mathbb{R}^n$). Orbit can represent this decomposition:
```orbit
	// M_affine = M_translate * M_linear
	// M_affine : AffineMatrix3D has form [[L, t],[0, 1]] where L is 3x3 linear, t is 3x1 translation
	decompose_affine(M : AffineMatrix3D) → { linear_part : Matrix<Real,3,3>, translation_part : Vector<Real,3> }
		where M[0..2,0..2] = linear_part && M[0..2,3] = translation_part;

	// Composition: (L1, t1) then (L2, t2) applied to a point p: L2(L1 p + t1) + t2 = L2 L1 p + L2 t1 + t2
	// Matrix form: [[L2,t2],[0,1]] * [[L1,t1],[0,1]] = [[L2*L1, L2*t1+t2],[0,1]]
	compose_affine_parts(L1, t1, L2, t2) →
		{ linear = L2*L1, translation = L2*t1 + t2 };
```
*   **Similarity Group:** A subgroup of Aff(n) where the linear part is a uniform scaling combined with a rotation/reflection ($A = sR$, $R \in O(n)$). Preserves shape.
*   **Euclidean Group E(n) (Isometry Group):** A subgroup of Aff(n) where the linear part is orthogonal ($A \in O(n)$). Preserves distances. E(n) = O(n) $\ltimes \mathbb{R}^n$.
*   **Projective Linear Group (PGL(n+1, ℝ)):** Group of homographies.

Orbit can leverage these group structures to simplify sequences of transformations or to convert transformations into canonical forms.

## Quaternions for 3D Rotations

While not matrices, unit quaternions (elements of $S^3$) are widely used to represent 3D rotations. They offer advantages over rotation matrices, such as avoiding gimbal lock and enabling easier interpolation (e.g., SLERP).

*   **Group Structure:** Unit quaternions form a group under quaternion multiplication, which is a double cover of SO(3).
*   **Orbit Handling:** Orbit could define a `Quaternion` domain and provide rules for:
    *   Conversion to/from rotation matrices.
    *   Quaternion multiplication.
    *   Quaternion normalization.
    *   Spherical Linear Interpolation (SLERP).

```orbit
// Conceptual domains and operations
UnitQuaternion ⊂ Vector<Real, 4> // where norm(q) = 1

// DSL operations for quaternions
quat_multiply(q1 : UnitQuaternion, q2 : UnitQuaternion) → q_product : UnitQuaternion;
quat_to_matrix3D(q : UnitQuaternion) → R : CanonicalRotationMatrix3D; // a 4x4 homogeneous matrix
matrix3D_to_quat(R : CanonicalRotationMatrix3D) → q : UnitQuaternion; // R must be pure rotation
quat_slerp(q1: UnitQuaternion, q2: UnitQuaternion, t: Scalar) → q_interpolated : UnitQuaternion;

// Bidirectional rule (conceptual for rotation matrix and quaternion)
rotate_by_quat(q : UnitQuaternion) : OpRotate3DByQuaternion ↔ quat_to_matrix3D(q);
```
Combining rotations using quaternions and then converting to a matrix can be more robust or efficient than multiplying rotation matrices directly.

## Key Considerations for Orbit

*   **Non-Commutativity:** Matrix multiplication (and thus transformation composition) is generally non-commutative. Orbit must preserve transformation order unless specific commutativity rules apply.
*   **Composition to Single Matrix:** A sequence of DSL commands `op_k; ...; op_1;` applied to a point `p` is equivalent to `M_k * ... * M_1 * p_homogeneous`. Orbit can compute the single composite matrix `M_total = M_k * ... * M_1`.
*   **Canonical Forms:** For some sequences, a canonical form might exist. E.g., any affine transformation can be decomposed into Shear -> Scale -> Rotate -> Translate (or other orders). Recognizing such canonical forms can simplify comparisons and analysis. An isometry is often canonicalized to a rotation then a translation.
*   **Computational Cost and Precision:** Different ways of expressing or computing the same transformation (e.g., many small matrix multiplies vs. one pre-computed matrix, quaternion math vs. matrix math) can have different performance and numerical stability implications. Orbit could potentially use heuristics to choose better pathways.

## Conclusion

The specialized matrices used in 2D and 3D graphics possess rich algebraic and group-theoretic structures. By defining a graphics DSL and establishing bidirectional rewrite rules to matrix representations, Orbit can:

1.  **Lift** high-level geometric operations into a common algebraic (matrix) domain.
2.  **Apply** powerful matrix algebra techniques for composition, simplification, and recognition of underlying mathematical structures (groups, special matrix forms like `Triangular`, `Orthogonal`).
3.  **Lower** results back to a DSL, potentially in a more optimal or canonical form.
4.  **Verify** transformations and ensure adherence to geometric properties.

This capability allows Orbit to be a valuable tool in optimizing graphics pipelines, robotics algorithms, game engines, and other applications relying on geometric transformations.
