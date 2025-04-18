# Canonical Forms and Rewriting Rules for Symmetry Groups

## Introduction

This document provides a comprehensive set of rewriting rules for common symmetry groups, enabling canonical representations of expressions involving these groups. These rules are essential for practical computational optimization across multiple domains.

### Why Canonical Forms Matter

Canonical forms provide tremendous practical benefits in computational systems:

- **Storage Efficiency**: By representing equivalent expressions with a single canonical form, memory usage can be dramatically reduced. For example, the expression `a + b + c` has 6 equivalent forms due to commutativity, but only needs to be stored once in canonical form.

- **Computational Efficiency**: Pattern matching on canonical forms is exponentially faster. Without canonicalization, systems would need to check all equivalent variations of a pattern - with n terms under symmetric group Sₙ, that's n! possibilities!

- **Optimization Opportunities**: Identifying algebraic patterns becomes much easier with canonical forms, enabling advanced optimizations like algebraic simplification and automatic parallelization.

- **Consistent Representation**: Canonical forms ensure that the same mathematical expression always has the same representation, which is critical for caching, memoization, and equality testing.

## Notation

This document uses the following notation for groups, operators, and relations:

### Group Symbols
- **Sₙ**: Symmetric group of order n! (all permutations of n elements). *Example: S₃ contains all 6 permutations of 3 elements (e.g., [1,2,3], [1,3,2], [2,1,3], etc.)*
- **Aₙ**: Alternating group of order n!/2 (even permutations of n elements). *Example: A₄ contains the 12 even permutations of 4 elements.*
- **Cₙ**: Cyclic group of order n (rotational symmetry). *Example: C₄ represents 90° rotations, like rotating a square by 0°, 90°, 180°, or 270°.*
- **Dₙ**: Dihedral group of order 2n (reflections and rotations of a regular n-gon). *Example: D₄ includes all 8 symmetries of a square (4 rotations and 2 reflections).*
- **GL(n,F)**: General linear group (invertible n×n matrices over field F). *Example: GL(2,ℝ) includes all 2×2 invertible matrices with real entries.*
- **SL(n,F)**: Special linear group (n×n matrices with determinant 1 over field F). *Example: SL(2,ℝ) includes matrices like [[a,b],[c,d]] where ad-bc=1.*
- **O(n)**: Orthogonal group (n×n matrices M where M^T·M = I). *Example: O(2) represents all rotations and reflections in 2D space.*
- **Q₈**: Quaternion group (non-abelian group of order 8). *Example: Q₈ = {±1, ±i, ±j, ±k} where i²=j²=k²=ijk=-1.*
- **ℤ/nℤ**: Integers modulo n (also denoted as ℤₙ). *Example: ℤ/4ℤ = {0,1,2,3} with modular addition.*

### Operators and Relations
- **×**: Direct product of groups. *Example: C₂ × C₃ forms a group of order 6 with elements like (a,b) where a ∈ C₂, b ∈ C₃.*
- **⋊**: Semi-direct product of groups. *Example: Dₙ ≅ Cₙ ⋊ C₂ where reflections act on rotations.*
- **⊂**: Subset relation (A ⊂ B means A is a subgroup of B). *Example: C₃ ⊂ S₃ since rotations are a subset of all permutations.*
- **⊲**: Normal subgroup (A ⊲ B means A is a normal subgroup of B). *Example: Aₙ ⊲ Sₙ for all n ≥ 2.*
- **≅**: Isomorphism (A ≅ B means groups A and B are isomorphic). *Example: C₆ ≅ C₂ × C₃ since gcd(2,3)=1.*
- **≇**: Not isomorphic (A ≇ B means groups A and B are not isomorphic). *Example: Q₈ ≇ D₄ despite both having order 8.*
- **|G|**: Order (size) of group G. *Example: |S₄| = 24, the number of permutations of 4 elements.*
- **∈**: Element membership (a ∈ G means a is an element of G). *Example: (1 2 3) ∈ S₃ means this cycle is in the symmetric group.*
- **⟺**: Logical equivalence (p ⟺ q means p if and only if q). *Example: x ∈ Aₙ ⟺ x is an even permutation.*

### Rewrite Rule Notation
- **a : G**: Expression a belongs to domain G
- **=>**: Rewrite rule (left hand side rewrites to right hand side)
- **<=>**: Bidirectional equivalence between patterns
- **if**: Conditional application of a rule
- **a : G => b : H**: Expression a in domain G rewrites to expression b in domain H
- **a !: G**: Expression a does NOT belong to domain G
- **⊢** or **\|-**: Entailment operator (when left pattern matches, right side domain annotation is applied)
- **⊂** or **c=**: Subset relation (indicates domain hierarchy)
- **eval()**: Used to evaluate expressions on the right-hand side during rewriting
- **: Canonical**: Annotation indicating the result is in canonical form
- **discard**: Indicates a branch that should be pruned during canonicalization

Throughout this document, rewrite rules are presented in a pattern-matching style where the left side of => describes a pattern to match, and the right side describes the transformation to apply. Conditions after "if" specify when the rule applies.

### Domain Annotation Syntax

Domain annotations serve multiple purposes in the rewriting system depending on context:

#### Pattern Matching of Domain (Left-Hand Side)

```
expr : Domain
```

On the left-hand side of a rule, this is a **constraint** requiring that:
- The matched node must already have the specified domain in its "belongs to" field
- This acts as a filter in pattern matching, restricting the match to nodes that belong to specific domains

Examples:
```
a + b : Int          // Matches addition expressions in the Int domain
a + b : S₂           // Matches addition with S₂ symmetry property
```

#### Negative Domain Match (!:)

The `!:` operator allows matching expressions that do NOT belong to a domain:

```
expr !: Domain => ...
```

This pattern matches only when the expression does not have the specified domain annotation, which is useful for:
- Applying transformations only to expressions that haven't been processed yet
- Preventing infinite loops in rewriting
- Implementing multi-phase transformations

Examples:
```
// Apply simplification only to expressions that haven't been simplified yet
expr !: Simplified => simplify(expr) : Simplified

// Prevent infinite recursion by marking processed expressions
x * (y + z) !: Expanded => (x * y + x * z) : Expanded

// Multi-phase transformation pipeline
expr !: Phase1 => phase1(expr) : Phase1
expr : Phase1 !: Phase2 => phase2(expr) : Phase2
expr : Phase2 !: Phase3 => phase3(expr) : Phase3
```

**Comparing Negative Guards vs. Positive Annotations**:

Positive annotations (`:`) and negative guards (`!:`) serve complementary purposes:

```
// Positive annotation - only applies to expressions already in the Int domain
a + b : Int => canonical_sum(a, b)

// Negative guard - explicitly avoids expressions in the Processed domain
a + b !: Processed => canonical_sum(a, b) : Processed
```

Positive annotations restrict rules to expressions with specific properties, while negative guards prevent re-processing expressions that have already been handled. Together, they enable fine-grained control over the rewriting process.

#### Entailment (Right-Hand Side)

```
a + b => a + b : S₂
```

On the right-hand side, this is an **assertion** that:
- The resulting node should have the domain added to its "belongs to" field
- This is how domain membership information is assigned to expressions

#### Explicit Entailment Rules

The entailment operator (⊢) creates conditional domain annotations:

```
pattern ⊢ op : Domain
```

This means when `pattern` matches, the operator `op` has `Domain` added to its "belongs to" field.

Examples:
```
a : Real + b : Real ⊢ + : S₂  // When adding reals, the + operator has S₂ symmetry
n ⊢ n : Prime if isPrime(n)   // If n is prime, it gets the Prime domain
```

#### Domain Hierarchy

The subset relation (⊂) indicates domain inheritance:

```
SubDomain ⊂ SuperDomain
```

This establishes that any expression in the subdomain is also in the superdomain, allowing rules defined for parent domains to apply to child domains.

Example:
```
Integer ⊂ Real ⊂ Complex  // Integer values are also Real values
Group ⊂ Ring ⊂ Field      // Rings have group structure
```

## Common Group Properties

Many symmetry groups share fundamental properties. This section consolidates these common properties to avoid repetition throughout the document.

### Core Group Properties

| Property | Description | Example Groups | Concrete Example |
|----------|-------------|----------------|------------------|
| **Associativity** | (a·b)·c = a·(b·c) for all elements | All groups | `(2+3)+4 = 2+(3+4) = 9` in integer addition |
| **Identity** | There exists an element e such that e·a = a·e = a | All groups | `0+a = a+0 = a` in addition; `1×a = a×1 = a` in multiplication |
| **Inverses** | For each element a, there exists a⁻¹ such that a·a⁻¹ = a⁻¹·a = e | All groups | `-5+5 = 0` in addition; `2×(1/2) = 1` in multiplication |
| **Commutativity** | a·b = b·a for all elements (not required for all groups) | Cₙ, Aₙ, ℤₙ | `3+4 = 4+3 = 7` in addition; `3×5 = 5×3 = 15` in multiplication |
| **Non-commutativity** | a·b ≠ b·a for some elements | Sₙ (n≥3), Dₙ (n≥3), Q₈ | Matrix multiplication: `[[0,1],[1,0]]×[[1,0],[0,0]] = [[0,0],[1,0]]` but `[[1,0],[0,0]]×[[0,1],[1,0]] = [[0,1],[0,0]]` |

### Common Subgroup Relationships

| Group | Normal Subgroups | Index | Notes |
|-------|-----------------|-------|-------|
| Sₙ | Aₙ | 2 | Aₙ is always normal in Sₙ with index 2 |
| Dₙ | Cₙ | 2 | The rotation subgroup is normal with index 2 |
| GL(n,F) | SL(n,F) | - | SL(n,F) is the kernel of the determinant homomorphism |
| Q₈ | {±1} | 4 | Center is a normal subgroup |

### Group Order Overview

| Group | Order | Structure |
|-------|-------|----------|
| Sₙ | n! | All permutations of n elements |
| Aₙ | n!/2 | Even permutations of n elements |
| Cₙ | n | Cyclic with n elements |
| Dₙ | 2n | Rotations and reflections of regular n-gon |
| Q₈ | 8 | Non-abelian group with all non-identity elements of order 4 |

## Basic Symmetry Groups

### Symmetric Group (Sₙ)

The symmetric group Sₙ represents all possible permutations of n elements.

- **S₁**: Trivial group (identity only)
- **S₂**: Group of order 2, represents commutativity (a + b = b + a)
- **S₃**: Group of order 6, all permutations of 3 elements
- **Sₙ**: Group of order n!, all permutations of n elements

### Cyclic Group (Cₙ)

Cₙ represents rotational symmetry of order n.

- **C₁**: Trivial group (identity only)
- **C₂**: Group of order 2, represents 180° rotation
- **C₃**: Group of order 3, represents 120° rotations
- **C₄**: Group of order 4, represents 90° rotations
- **Cₙ**: Group of order n, represents 360°/n rotations

### Dihedral Group (Dₙ)

Dₙ represents rotational and reflectional symmetries of a regular n-gon.

- **D₁**: Group of order 2, represents reflection only
- **D₂**: Group of order 4, represents 180° rotation and 2 reflections
- **D₃**: Group of order 6, represents 120° rotations and 3 reflections
- **D₄**: Group of order 8, represents 90° rotations and 4 reflections
- **Dₙ**: Group of order 2n, represents 360°/n rotations and n reflections

### Alternating Group (Aₙ)

Aₙ consists of all even permutations of n elements and is a normal subgroup of Sₙ.

- **A₁**: Trivial group (identity only)
- **A₂**: Trivial group (identity only, as all permutations of 2 elements are odd)
- **A₃**: Group of order 3, represents the cyclic permutations of 3 elements
- **A₄**: Group of order 12, consists of all even permutations of 4 elements
- **Aₙ**: Group of order n!/2, all even permutations of n elements

## Algebraic Structures Hierarchy

The following hierarchy shows the progression of algebraic structures from simple to complex, providing context for the groups, rings, fields, and other structures discussed in this document.

```
Set
└── Magma (Set with binary operation)
	└── Semigroup (Associative magma)
		└── Monoid (Semigroup with identity)
			├── Group (Monoid with inverses)
			│   ├── Abelian Group (Commutative group)
			│   │   ├── Cyclic Group (Cₙ) (Generated by a single element)
			│   │   └── Vector Space (Abelian group with scalar multiplication)
			│   └── Non-Abelian Groups
			│       ├── Symmetric Group (Sₙ)
			│       ├── Alternating Group (Aₙ)
			│       ├── Dihedral Group (Dₙ)
			│       └── Matrix Groups
			│           ├── General Linear Group (GL(n,F))
			│           ├── Special Linear Group (SL(n,F))
			│           └── Orthogonal Group (O(n))
			└── Semiring (Monoid with second operation distributing over first)
				└── Ring (Semiring with additive inverses)
					├── Commutative Ring
					│   └── Field (Commutative ring with multiplicative inverses)
					└── Non-Commutative Rings
```

## Matrix Groups

Matrix groups capture important symmetries in linear algebra and geometry.

### General Linear Group (GL(n, F))

GL(n, F) consists of all invertible n×n matrices over a field F.

- **GL(1, ℝ)**: Group of non-zero real numbers under multiplication
- **GL(2, ℝ)**: Group of 2×2 real invertible matrices
- **GL(n, ℝ)**: Group of all real n×n matrices with non-zero determinant

### Special Linear Group (SL(n, F))

SL(n, F) consists of all n×n matrices with determinant 1 over a field F.

- **SL(2, ℝ)**: Group of 2×2 real matrices with determinant 1
- **SL(n, ℝ)**: Group of all real n×n matrices with determinant 1

### Orthogonal Group (O(n))

O(n) consists of all n×n orthogonal matrices (matrices M where M^T M = I).

- **O(1)**: Group of 1×1 matrices {1, -1}, isomorphic to C₂
- **O(2)**: Group of 2×2 orthogonal matrices (rotations and reflections in the plane)
- **O(3)**: Group of 3×3 orthogonal matrices (rotations and reflections in 3D space)

### Quaternion Group (Q₈)

Q₈ is a non-abelian group of order 8, with all non-identity elements having order 4. The quaternion group is important in 3D computer graphics, robotics, and physics for representing rotations in 3D space without gimbal lock problems.

- **Elements**: Q₈ = {±1, ±i, ±j, ±k} where 1 is the identity element
- **Multiplication Rules**: i² = j² = k² = ijk = -1
- **Multiplication Table** (excerpt):
  ```
	| * | i  | j  | k  |
	|---|----|----|----|
	| i | -1 | k  | -j |
	| j | -k | -1 | i  |
	| k | j  | -i | -1 |
```

- Not isomorphic to D₄ (dihedral group of order 8) despite both having order 8
- Not isomorphic to C₂ × C₄ (direct product of cyclic groups)
- Used in computer graphics for representing 3D rotations smoothly
- **Practical Application**: Unit quaternions provide a more efficient and numerically stable way to compose 3D rotations than 3×3 rotation matrices

## Group Actions

Group actions define how the abstract symmetry groups concretely transform expressions or data structures. These actions form the bridge between abstract group theory and practical transformations in computational domains.

### Direct Group Action Representation

```
// S₂ acts by swapping elements
action(S₂, [a, b]) => [b, a];

// Cyclic group acts by rotation
action(C₄, arr) => arr[n:] + arr[:n];

// Dihedral group combines rotations and reflections
action(D₄, arr) => rotate_or_reflect(arr);

// Group composition follows group laws
action(S₂, action(S₂, arr)) => arr : Identity;  // Double swap is identity
action(C₄, action(C₄, action(C₄, action(C₄, arr)))) => arr : Identity;  // Four rotations is identity
```

### Group Actions on Common Data Structures

#### Arrays and Lists

```
// S₂ swaps elements
apply(S₂, [a, b]) => [b, a];

// S₃ permutes three elements (6 possible arrangements)
apply(S₃, [a, b, c]) => one_of([a,b,c], [a,c,b], [b,a,c], [b,c,a], [c,a,b], [c,b,a]);

// C₄ rotates elements
apply(C₄, [a, b, c, d]) => one_of([a,b,c,d], [d,a,b,c], [c,d,a,b], [b,c,d,a]);

// D₄ includes rotations and reflections of a square
apply(D₄, matrix) => one_of(rotations_and_reflections(matrix));
```

#### Algebraic Expressions

```
// S₂ acts on binary operations by swapping operands
apply(S₂, op(a, b)) => op(b, a) if op : S₂;

// C₄ acts on rotational transformations
apply(C₄, rotate(x, k)) => rotate(x, (k + 1) % 4);

// Group action on nested expressions
apply(G, op(a, b)) => op(apply(G, a), apply(G, b)) if preserves_structure(G, op);
```

#### Matrices

```
// GL(n,F) acts on vectors by matrix multiplication
apply(GL(n,F), v) => A * v where A : GL(n,F);

// O(3) represents 3D rotations and reflections
apply(O(3), point) => R * point where R : O(3);

// Group action composition
apply(compose(G₁, G₂), x) => apply(G₁, apply(G₂, x));
```

## Canonical Forms

### Canonicalization Rules

#### Rotation Canonicalization (Common Patterns)

Many groups involve rotation operations that share common canonicalization patterns:

```
// General rotation canonicalization pattern
(rotate(x, n % k)) : G => x : Canonical if (n % k) == 0;
(rotate(x, n % k)) : G => rotate_by_angle(x, (n % k) * (360/k)) : Canonical if (n % k) != 0;

// Composition of rotations
rotate_left(rotate_left(x, a), b) => rotate_left(x, eval((a + b) % n)) : Canonical;

// Identity rotation
rotate_left(x, 0) => x : Canonical;

// Inverse rotations
rotate_left(rotate_right(x, k), k) => x : Canonical;
```

This general pattern applies to cyclic groups (Cₙ) and the rotation subgroup of dihedral groups (Dₙ).

#### Symmetric Group (Sₙ)

```
// S₂ canonicalization (commutative operation)
(a + b) : S₂ => a + b : Canonical if a <= b;
(a + b) : S₂ => b + a : Canonical if b < a;

// S₃ canonicalization (3 elements)
(a * b * c) : S₃ => ordered3(a, b, c);

// Helper function for S₃ ordering
ordered3(a, b, c) => a * b * c : Canonical if a <= b && b <= c;
ordered3(a, b, c) => a * c * b : Canonical if a <= c && c < b;
ordered3(a, b, c) => b * a * c : Canonical if b < a && a <= c;
ordered3(a, b, c) => b * c * a : Canonical if b <= c && c < a;
ordered3(a, b, c) => c * a * b : Canonical if c < a && a <= b;
ordered3(a, b, c) => c * b * a : Canonical if c < b && b < a;
```

#### Cyclic Group (Cₙ)

```
// C₂ canonicalization (180° rotation)
(rotate180(x)) : C₂ => x : Canonical;
(rotate180(rotate180(x))) : C₂ => x : Canonical;

// C₄ canonicalization (90° rotation)
(rotate(x, n % 4)) : C₄ => x : Canonical if (n % 4) == 0;
(rotate(x, n % 4)) : C₄ => rotate90(x) : Canonical if (n % 4) == 1;
(rotate(x, n % 4)) : C₄ => rotate180(x) : Canonical if (n % 4) == 2;
(rotate(x, n % 4)) : C₄ => rotate270(x) : Canonical if (n % 4) == 3;
```

#### Dihedral Group (Dₙ)

```
// D₄ canonicalization (square symmetry group)
// First canonicalize rotations
(rotate(x, n % 4)) : D₄ => x : Canonical if (n % 4) == 0;
(rotate(x, n % 4)) : D₄ => rotate90(x) : Canonical if (n % 4) == 1;
(rotate(x, n % 4)) : D₄ => rotate180(x) : Canonical if (n % 4) == 2;
(rotate(x, n % 4)) : D₄ => rotate270(x) : Canonical if (n % 4) == 3;

// Then handle reflections
(reflect(x, axis)) : D₄ => reflectH(x) : Canonical if axis == "horizontal";
(reflect(x, axis)) : D₄ => reflectV(x) : Canonical if axis == "vertical";
(reflect(x, axis)) : D₄ => reflectD1(x) : Canonical if axis == "diagonal1";
(reflect(x, axis)) : D₄ => reflectD2(x) : Canonical if axis == "diagonal2";
```

#### Alternating Groups (Aₙ)

```
// A₃ canonicalization (even permutations of 3 elements)
(a * b * c) : A₃ => ordered3(a, b, c) if permutation_sign(a, b, c) == +1;

// General rule for Aₙ:
(p) : Aₙ => canonical_even_permutation(p);

// Helper: checks whether permutation is even
permutation_sign(a, b, c) => eval(+1) if number_of_transpositions(a, b, c) is even;
permutation_sign(a, b, c) => eval(-1) otherwise;

// Only allow canonical permutations with positive sign
(p) : Aₙ => discard if permutation_sign(p) == -1;
```

### Advanced Canonicalization Methods

#### Matrix Groups

Matrix groups have important applications in mathematics, physics, and computer graphics.

```
// GL canonicalization using row echelon form
(M) : GL(n, F) => eval(rref(M)) : Canonical;
(M) : GL(n, F) => discard if eval(det(M)) == 0;  // Not invertible ⇒ not in GL

// SL canonicalization using normalized RREF with det = 1
(M) : SL(n, F) => eval(normalize(rref(M))) if eval(det(M)) == 1;
```

#### Orthogonal Group (O(n))

```
// O(n): MᵀM = I
(M) : O(n) => eval(canonical_orthogonal_form(M)) if eval(Mᵀ·M) == I;
```

#### Commutative Ring Terms and Gröbner Basis Canonicalization

```
// Commutative polynomials in ring: normalize via lex order
(f + g) : PolynomialRing => eval(ordered_sum(f, g));

// Multivariate monomial canonical form
(x^a * y^b * z^c) => eval(Monomial(x, y, z, [a, b, c]));

// Reduction via known ideal (Gröbner-like)
(p) : Ideal(I) => eval(normal_form(p, I)) : Canonical;
```

### Gröbner Basis for Commutative Rings

Gröbner bases provide a systematic approach to canonicalizing expressions in commutative rings, especially polynomial rings. This powerful mathematical tool generalizes both Gaussian elimination for linear systems and polynomial division for univariate polynomials.

#### Why Gröbner Bases Matter

Gröbner bases allow us to canonicalize complex polynomial expressions by establishing a unique normal form for each equivalence class of polynomials. This is particularly valuable for:

- Solving systems of polynomial equations
- Simplifying expressions in commutative rings
- Proving polynomial identities
- Computing intersections and projections of algebraic varieties

#### Key Concepts

- **Monomial Order**: Defines a canonical way to arrange monomials in polynomials
  - **lex**: Lexicographic order (like dictionary ordering): x² > xy > y²
  - **grlex**: Graded lexicographic (first by total degree, then lexicographically): x² > xy > y² 
  - **grevlex**: Graded reverse lexicographic (first by total degree, then by reverse lex on variables): x² > xy > y²

- **Normal Form**: Reduced representation of a polynomial modulo an ideal
  - Example: The normal form of x² + xy with respect to G = {x-y} is 2y²
  
- **Ideal Membership**: Determines if a polynomial belongs to an ideal generated by a set of polynomials
  - Example: Testing if x²y - y³ is in the ideal generated by {x-y, y²-1}
  
- **Ideal Operations**: Enables computation with polynomial ideals (intersection, quotient, elimination)
  - Example: Eliminating variables from systems of equations

## Group Combination Rules

### Direct Product

The direct product combines two groups independently.

```
// Direct product of groups
(a : g : Group × b : h : Group ) => (a, b) : Direct_Product(g, h);

// Examples:
(a : C₂ × b : C₃) => (a, b) : Direct_Product(C₂, C₃);  // Group of order 6
(a : S₂ × b : S₂) => (a, b) : Direct_Product(S₂, S₂);  // Group of order 4
```

S₂ ⊂ SymmetricGroup ⊂ Group;
C₄ ⊂ CyclicGroup ⊂ Group;
D₄ ⊂ DihedralGroup ⊂ Group;

### Semi-Direct Product

The semi-direct product combines groups where one acts on the other.

```
// Semi-direct product with action σ
(a : g ⋊_σ b : h) => (a, b) : semi_Direct_Product(g, h, σ);

// Example: Dₙ as semi-direct product
(r : Cₙ ⋊_σ s : C₂) => (r, s) : Dₙ;  // Dihedral group as semi-direct product
```

### Group Combinations Using GCD

When combining cyclic groups, the resulting order often depends on the GCD of the individual orders.

```
// Combining two cyclic groups
Cₘ × Cₙ => Direct_Product(C_eval(lcm(m,n)), C_eval(gcd(m,n)));

// Special case: when m and n are coprime
Cₘ × Cₙ => C_eval(m·n) if gcd(m, n) == 1;

// Examples:
C₄ × C₆ => Direct_Product(C₁₂, C₂);  // lcm(4,6) = 12, gcd(4,6) = 2
C₃ × C₅ => C₁₅;                      // gcd(3,5) = 1, so direct product is cyclic
```

## Group Decompositions

Many groups can be understood through their decomposition into simpler structures. This section centralizes the key decompositions and provides concrete examples.

### Dihedral Group Decompositions

Dihedral groups (Dₙ) can be decomposed as semi-direct products of cyclic groups:

```
// Dₙ decomposition into semi-direct product
Dₙ => Cₙ ⋊ C₂;

// Example: D₄ decomposition (square symmetry)
D₄ => C₄ ⋊ C₂; // Rotations acted upon by reflection

// The reflection action maps each rotation to its inverse
// For example, in D₄:
reflect · rotate(90°) · reflect = rotate(-90°) = rotate(270°)
```

### Symmetric Group Decompositions

Symmetric groups (Sₙ) can be decomposed using alternating groups:

```
// Sₙ decomposition for n > 1
Sₙ => Aₙ ⋊ C₂;  // Semi-direct product with alternating group

// Example: S₃ decomposition
S₃ => A₃ ⋊ C₂;  // A₃ ≅ C₃, so S₃ ≅ C₃ ⋊ C₂ ≅ D₃

// Example: S₄ decomposition
S₄ => A₄ ⋊ C₂;  // A₄ is more complex, not isomorphic to a single cyclic group
```

### Other Important Decompositions

```
// Direct product decompositions
D₂ ≅ C₂ × C₂;  // Dihedral group of order 4 is isomorphic to Klein four-group

// Quaternion group has no elementary decomposition, but subgroup relations:
Q₈ ⊃ {±1} ≅ C₂  // Center of Q₈ is isomorphic to C₂

// Example: Decomposing a group element using the semidirect product
// An element in Dₙ can be uniquely written as r·s where r ∈ Cₙ, s ∈ C₂
r · s · r' · s' = r · (s · r' · s⁻¹) · (s · s')
				= r · r'ⁱⁿᵛ · s''
				// where r'ⁱⁿᵛ is r' or r'⁻¹ depending on s
				// and s'' is either identity or reflection
```

## Group Equivalences

### Group Relationship Hierarchy

The following table summarizes the important relationships between common symmetry groups and classical groups:

```
// Inclusion relationships
Aₙ ⊂ Sₙ;            // Aₙ is a subgroup of Sₙ of index 2
Cₙ ⊂ Dₙ;            // Cₙ is the rotation subgroup of Dₙ
C₁ ⊂ all groups;      // Trivial group is contained in all groups

// Normality relationships
Aₙ ⊲ Sₙ;            // Aₙ is normal in Sₙ (unique subgroup of index 2)
Cₙ ⊲ Dₙ;            // Rotations preserved under conjugation in Dₙ

// Quotient relationship
Sₙ / Aₙ ≅ C₂;        // Quotient group is cyclic of order 2

// Semi-direct product decomposition
Dₙ ≅ Cₙ ⋊ C₂;       // Reflections acting on rotations

// Order relationships
|Cₙ| = n
|Dₙ| = 2n
|Sₙ| = n!
|Aₙ| = n!/2

// Generator relationships
Sₙ is generated by (C₂)^n   // Transpositions generate Sₙ

// Parity criterion
p ∈ Aₙ ⟺ number_of_transpositions(p) is even;  // Used to split Sₙ

// Simplicity
Aₙ is simple for n ≥ 5;   // No normal subgroups

// Commutativity
Cₙ is abelian
Dₙ is non-abelian for n ≥ 3
Sₙ is non-abelian for n ≥ 3
Aₙ is non-abelian for n ≥ 4

// Classical Group Relationships
GL(n,F) ⊃ SL(n,F);      // Special linear is a subgroup of general linear
GL(1,F) ≅ F* ≅ C_{p-1};  // Multiplicative group of non-zero field elements
ℤₙ under addition ≅ Cₙ;    // Modular integers form a cyclic group
(ℤ/nℤ)* is cyclic if φ(n) is cyclic;  // Multiplicative group of units
(C₂)^n is a vector space over GF(2);  // XOR operations form a vector space

// Quaternion Group Relations
Q₈ is non-abelian of order 8;       // Not isomorphic to D₄
Q₈ has all non-identity elements of order 4;  // Different from C₄ and C₂ × C₄

// Group Products and Decompositions
Dₙ ≅ Cₙ ⋊ C₂;              // Semidirect product with reflection acting on rotation
Sₙ ≅ Aₙ ⋊ C₂;              // Decomposition for n ≥ 2
SL₂(F₂) is simple for most fields;  // Special linear group of 2×2 matrices
```

### Known Isomorphisms

```
// Basic isomorphisms
C₂ ≅ ℤ/2ℤ;        // Cyclic group of order 2 is isomorphic to integers modulo 2
D₁ ≅ C₂;          // Dihedral group of order 2 is isomorphic to cyclic group of order 2
D₂ ≅ C₂ × C₂;      // Dihedral group of order 4 is isomorphic to direct product of C₂ with itself

// Less obvious isomorphisms
S₃ ≅ D₃;           // Symmetric group on 3 elements is isomorphic to dihedral group of order 6
A₄ ≅ (A₄, *);      // Alternating group on 4 elements has special structure
Q₈ ≇ D₄;          // Quaternion group is not isomorphic to dihedral group of order 8
Q₈ ≇ C₂ × C₄;    // Quaternion group not isomorphic to direct product
```

### Discrete Type Mappings

```
// Mapping discrete types to groups
int8 ≅ ℤ/256ℤ ≅ C₂₅₆;     // 8-bit integer arithmetic is isomorphic to modular arithmetic
int16 ≅ ℤ/65536ℤ ≅ C₆₅₅₃₆;  // 16-bit integer arithmetic

// Modular arithmetic groups
ℤ/nℤ ≅ Cₙ;                 // Integers modulo n form a cyclic group of order n

// Bitwise operations
xor on (ℤ/2ℤ)ⁿ ≅ (C₂)ⁿ;     // Bitwise XOR on n-bit types forms an abelian group
```

## Bidirectional Type Mappings and Rules

This section provides a concise overview of mappings between primitive numeric operations, algebraic structures, and symmetry groups.

### Bidirectional Mapping Table

| Direction | Primitive Operation | Algebraic Structure | Symmetry Group | Example |
|-----------|---------------------|---------------------|----------------|--------|
| Forward | a + b (Int) | Addition | Z (integers) | Integer addition forms infinite cyclic group |
| Backward | group_op(a, b, Z) | a + b | Integer | Group operation maps back to addition |
| Forward | a + b (mod n) | Modular addition | Cₙ | Modular addition forms cyclic group |
| Backward | group_op(a, b, Cₙ) | (a + b) % n | Modular arithmetic | Cyclic group maps to modular arithmetic |
| Forward | a ^ b (bitwise XOR) | Boolean ring | (C₂)ⁿ | XOR forms direct product of C₂ groups |
| Backward | group_op(a, b, (C₂)ⁿ) | a ^ b | Bitwise XOR | XOR implemented as group operation |
| Forward | a op b (commutative) | Commutative operation | S₂ | Commutativity detected as S₂ symmetry |
| Backward | group_op(a, b, S₂) | ordered(a, b) | Canonicalized form | S₂ ensures operand ordering |

### Type-Based Inference Rules

```
// Type inference from operations
Double + operations ⊢ Field          // Double operations form a field
Int + operations    ⊢ Ring           // Integer operations form a ring
Bitwise operations  ⊢ BooleanAlgebra // Bitwise operations form Boolean algebra

// Pattern detection examples
a + b == b + a      ⊢ + : S₂         // Detect commutativity (S₂)
rotate(rotate(x))   ⊢ rotate : Cₙ    // Detect cyclic group (Cₙ)
```

### Canonicalization Through Group Theory

```
// Using S₂ for commutative operations
(a + b) : S₂ => ordered(a, b) : Canonical

// Using Cₙ for rotations
rotate(x, k) : Cₙ => rotate(x, k % n) : Canonical

// Using Dₙ for transformations
transform(x) : Dₙ => canonical_form_in_orbit(x) : Canonical
```

## Practical Applications

### Integer Operations

Modular arithmetic provides a concrete implementation of group theory in computing systems.

```
// Addition forms a cyclic group in modular arithmetic
(a + b) mod n : Cₙ;  // Addition modulo n has cyclic group structure

// Example: Clock arithmetic (mod 12)
ClockAdd(10, 5) => (10 + 5) % 12 => 3  // 10 hours + 5 hours = 3 o'clock

// Multiplication forms a more complex group
(a * b) mod n : (ℤ/nℤ)*;  // Multiplicative group of integers modulo n

// Example: Modular exponentiation used in cryptography (RSA algorithm)
(a^k) mod n => a^(k mod φ(n)) mod n if gcd(a, n) == 1;  // Where φ is Euler's totient function
ModPow(5, 117, 19) => 5^(117 % 18) % 19 => 5^9 % 19 => 1  // Since φ(19) = 18
```

Practical applications include:

- **Cryptography**: RSA encryption relies on modular exponentiation
- **Hash functions**: Use modular arithmetic for distribution
- **Random number generation**: Linear congruential generators use modular arithmetic
- **Error detection/correction**: CRC checksums use polynomial arithmetic over finite fields

### Bit Operations

Bitwise operations provide a rich playground for algebraic structures, with direct applications in computer architecture and cryptography.

```
// Bitwise operations on fixed-width integers
(a ^ b) : (C₂)ⁿ for n-bit integers;  // XOR forms an abelian group

// Example: XOR forming a group (self-inverse property)
int x = 0b1010;
int y = 0b0110;

// Identity element: x ^ 0 = x
x ^ 0 => 0b1010 ^ 0b0000 => 0b1010   // Identity preserved

// Inverse: x ^ x = 0 (each element is its own inverse)
x ^ x => 0b1010 ^ 0b1010 => 0b0000   // Self-inverse

// Associativity: (x ^ y) ^ z = x ^ (y ^ z)
(x ^ y) ^ 0b0011 = x ^ (y ^ 0b0011)   // Associative

// Bit rotations form cyclic groups
rotate_left(x, k) : Cₙ for n-bit integers;  // Left rotation by k positions

// Example: 8-bit rotation
rotate_left(0b10100000, 3) => 0b00000101   // Rotate left by 3 bits
rotate_left(rotate_left(0b10100000, 3), 5) => rotate_left(0b10100000, 8) => 0b10100000

// Bit shifts don't form a group (not invertible)
shift_left(x, k) !: group;  // Shift operations don't form a group

// Example: Shift operations lose information
shift_left(0b10100000, 3) => 0b00000000   // Information lost, can't recover
```

Practical applications of bitwise operations include:

- **Cryptography**: XOR is used in stream ciphers like RC4 and in block cipher modes
- **Hash functions**: SHA and MD5 use bitwise operations extensively
- **Error detection**: Parity bits use XOR for error detection
- **Graphics**: Bit manipulation for masking and compositing
- **Performance optimization**: Replacing multiplication by powers of 2 with bit shifts

### Matrix Group Operations

Matrix groups provide a powerful framework for understanding transformations in linear algebra and geometry, with numerous applications in computer graphics and physics.

```
// Matrix multiplication forms a group for invertible matrices
(A * B) : GL(n, F);  // Matrix multiplication in general linear group

// Example: 2×2 rotation matrices form a group under multiplication
R(30°) * R(45°) = R(75°)  // Composition of rotations is a rotation

// Concrete example with rotation matrices:
R(30°) = [[cos(30°), -sin(30°)], [sin(30°), cos(30°)]]
R(45°) = [[cos(45°), -sin(45°)], [sin(45°), cos(45°)]]
R(30°) * R(45°) = R(75°)  // Matrix multiplication preserves the group structure

// Orthogonal transformations preserve inner products
(M * v) · (M * w) => v · w if M : O(n);  // Inner product preservation

// Example: Rotation matrices preserve distances and angles
// For any vectors v and w and rotation matrix R:
// (Rv) · (Rw) = v · w
// |Rv| = |v|  // Length preservation

// Special linear group preserves volume
det(M) => 1 if M : SL(n, F);  // Determinant is always 1

// Example: Area preservation in 2D transformations
// If A is in SL(2,ℝ), then a parallelogram transformed by A has the same area

// Matrix exponential maps Lie algebra to Lie group
exp(A) : SO(n) if A : so(n);  // Exponential of skew-symmetric matrix gives rotation

// Example: Converting angular velocity to rotation matrix
// For the 2D case, with angular velocity ω:
// A = [[0, -ω], [ω, 0]]  // Skew-symmetric matrix
// exp(A*t) gives the rotation matrix for angle ωt
```

Practical applications of matrix groups include:

- **Computer Graphics**: 3D transformations using GL(4,ℝ) and special orthogonal groups
- **Physics**: Describing symmetry operations in crystallography and quantum mechanics
- **Robotics**: Representing rigid body motions using special Euclidean groups
- **Computer Vision**: Camera calibration and structure from motion algorithms
- **Quantum Computing**: Quantum gates as special unitary transformations

### Gröbner Basis Applications

```
// Polynomial reduction using Gröbner basis
(p) : PolynomialRing => eval(normal_form(p, G)) if G is a Gröbner basis;

// Testing polynomial ideal membership
is_in_ideal(p, G) => eval(true) if eval(normal_form(p, G)) == 0;

// Solving polynomial systems
solve_system(F) => eval(solutions_from_gröbner(gröbner_basis(F)));

// Elimination of variables
eliminate(G, vars) => eval(G ∩ k[remaining_vars]);
```

### Integer Type Operations (intₙ)

Fixed-width signed integers exhibit rich algebraic structure with various operations forming different groups.

```
// Addition on n-bit signed integers forms a cyclic group
(a + b) : intₙ => eval((a + b) mod 2^n) : C₂ₙ;

// XOR operation forms a direct product of cyclic groups
(a ^ b) : intₙ => eval(a ^ b) : (C₂)^n;

// Multiplication only forms a group on odd integers
(a * b) : intₙ => eval((a * b) mod 2^n) : (ℤ/2^nℤ)* if gcd(a, 2^n) == 1 && gcd(b, 2^n) == 1;

// Bitwise NOT forms an involution (order 2 group)
~a : intₙ => eval(~a) : C₂;

// Two's complement negation
negate(a) : intₙ => eval(~a + 1) : C₂;

// Bit rotation forms a cyclic group
rotate_left(a, k) : intₙ => eval(rotate_left(a, k mod n)) : Cₙ;

// Composition of rotations and reflections forms a dihedral group
(rotate_left(reflect(a), k)) : intₙ => eval(Dₙ_operation(a, k, true)) : Dₙ;
```

Here's a summary of the most important group structures on n-bit signed integers:

| Operation | Group Structure | Properties | Notes |
|-----------|----------------|------------|-------|
| Addition | C₂ₙ (cyclic) | Abelian | Wraps around due to two's complement |
| XOR | (C₂)^n | Abelian, elementary | Forms a vector space over GF(2) |
| Multiplication | (ℤ/2^nℤ)* | Non-cyclic for n > 2 | Only invertible for odd integers |
| Bitwise NOT | C₂ | Involution | NOT is its own inverse |
| Negation | C₂ | Involution | x = -x only for 0 and overflow values |
| Bit rotation | Cₙ | Cyclic | Acts on the bit positions |
| Rotations + reflections | Dₙ | Non-abelian | Full symmetry group of bit arrangements |

Examples for int₄ (4-bit signed integers, range: -8 to 7):

```
// Addition forms C₁₆
(a + b) : int₄ => (a + b) mod 16 : C₁₆;

// XOR forms (C₂)^4
(a ^ b) : int₄ => a ^ b : (C₂)^4;

// Multiplication group is {1,3,5,7,9,11,13,15}, not cyclic
(a * b) : int₄ => (a * b) mod 16 : (ℤ/16ℤ)* if a % 2 == 1 && b % 2 == 1;
```

#### Multiplication in (ℤ/2^nℤ)* (Only valid when constants are odd)

```
// Inverse for multiplication
(x * k) * k⁻¹ => x : Canonical if gcd(k, 2^n) == 1;

// Associativity and folding
(x * k₁) * k₂ => x * eval(k₁ * k₂) : Canonical if gcd(k₁, 2^n) == 1 && gcd(k₂, 2^n) == 1;
```

#### Division as Shift or Multiplication with Inverse

```
// Division by 2^k
(x / 2^k) => x >> k : Canonical if logical/arithmetic_shift_valid(x, k);

// Division by invertible constant
(x / k) => x * eval(mod_inverse(k, 2^n)) : Canonical if gcd(k, 2^n) == 1;
```

#### XOR in (C₂)^n

```
// Identity
x ^ 0 => x : Canonical;

// Inverse
x ^ x => 0 : Canonical;

// Double applications
(x ^ m) ^ m => x : Canonical;

// Composition
(x ^ a) ^ b => x ^ eval(a ^ b) : Canonical;
```

## Functional Programming Optimizations

Group-theoretic properties enable powerful optimizations in functional programming contexts, where higher-order functions and composition create opportunities for algebraic simplification.

### Function Composition and Application

```
// Detect commutativity in lambda expressions
(λ(a, b).op(a, b)) ⊢ λ : S₂ if op : S₂;  // Lambda inherits commutativity from operation

// Detect associativity in lambda expressions
(λ(a, b).op(a, b)) ⊢ λ : Associative if op : Associative;

// Function composition associativity
(f ∘ (g ∘ h)) : Associative => ((f ∘ g) ∘ h) : Canonical;

// Identity function laws
(id ∘ f) => f : Canonical;  // Left identity
(f ∘ id) => f : Canonical;  // Right identity
```

### Collection Operation Fusion

```
// Map fusion when function composition is detected
map(f, map(g, xs)) => map(λ(x).f(g(x)), xs) : Canonical;

// Filter fusion when predicates have logical properties
filter(p, filter(q, xs)) => filter(λ(x).p(x) && q(x), xs) : Canonical;

// Map-filter interchange when functions preserve predicates
map(f, filter(p, xs)) : Commutable => filter(p, map(f, xs)) : Canonical if independent(f, p);

// Fold-map fusion
fold(op, init, map(f, xs)) => fold(λ(acc, x).op(acc, f(x)), init, xs) : Canonical;
```

### Stream and Collection Optimizations

```
// Stream operation fusion
stream.map(f).map(g) => stream.map(λ(x).g(f(x))) : Canonical;
stream.filter(p).filter(q) => stream.filter(λ(x).p(x) && q(x)) : Canonical;

// Detect parallelizable operations
fold(op, id, xs) ⊢ fold : Parallelizable if op : Associative && op : Commutative;

// Apply optimization based on algebraic properties
fold : Parallelizable => parallel_reduce : Optimized;

// Special case optimizations
fold(+, 0, map(λ(x).c * f(x), xs)) : Distributive => c * fold(+, 0, map(f, xs)) : Canonical if c : Constant;
```

### Algebraic Data Type Transformations

```
// Option/Maybe monad
map(f, None) => None : Canonical;
map(f, Some(x)) => Some(f(x)) : Canonical;

// List monad
flatMap(f, concat(xs, ys)) => concat(flatMap(f, xs), flatMap(f, ys)) : Canonical;
flatMap(f, nil) => nil : Canonical;

// Monad laws
flatMap(return, m) => m : Canonical;  // Left identity
flatMap(f, return(x)) => f(x) : Canonical;  // Right identity
flatMap(g, flatMap(f, m)) => flatMap(λ(x).flatMap(g, f(x)), m) : Canonical;  // Associativity
```

## Cost Functions with Algebraic Structure

Cost functions that respect algebraic structure can dramatically improve optimization by guiding the search toward algebraically meaningful representations.

### Cost Function with Group Properties

```
fn costWithGroups(expr : ast) -> double (
	expr is (
		// Operations with symmetry groups can be reordered for cheaper evaluation
		a + b : Su2082 => 1.0 + min(costWithGroups(a), costWithGroups(b)) +
					 max(costWithGroups(a), costWithGroups(b))/2.0;
		a * b : Su2082 => 1.2 + min(costWithGroups(a), costWithGroups(b)) +
					 max(costWithGroups(a), costWithGroups(b))/2.0;

		// Nested associative operations
		(a + b) + c : Associative => 0.8 + costWithGroups(a) +
									 costWithGroups(b) + costWithGroups(c);
		a + (b + c) : Associative => 0.8 + costWithGroups(a) +
									 costWithGroups(b) + costWithGroups(c);

		// Default costing for other expressions
		_ => 1.0;
	)
)
```

### Cost Functions for Domain-Specific Optimization

```
// Prefer canonical forms when available
fn domainAwareCost(expr : ast) -> double (
	expr is (
		// Prioritize expressions in canonical form
		_ : Canonical => 0.5 * baseCost(expr);

		// Prioritize expressions that have been simplified
		_ : Simplified => 0.7 * baseCost(expr);

		// Penalize expressions that should be expanded
		_ : ShouldExpand => 1.5 * baseCost(expr);

		// Default cost calculation
		_ => baseCost(expr);
	)
)
```

### Structural Costs for Expression Trees

```
// Cost function for expression optimization
fn expressionCost(expr : ast) -> double (
	expr is (
		// Binary operations have fixed costs plus recursive component
		a + b => 1.0 + expressionCost(a) + expressionCost(b);
		a * b => 1.2 + expressionCost(a) + expressionCost(b);
		a - b => 1.0 + expressionCost(a) + expressionCost(b);
		a / b => 1.5 + expressionCost(a) + expressionCost(b);

		// Unary operations
		-a => 0.8 + expressionCost(a);
		f(a) => 1.2 + expressionCost(a);

		// Base cases
		n : Constant => 0.5;  // Constants are cheap
		x : Variable => 0.7;  // Variables are relatively cheap

		// Default for other expressions
		_ => 1.0;
	)
)
```

## Optimization Using Group Properties

### Rewrite Rules Based on Group Structure

```
// Exploiting commutativity (S₂)
a + b => b + a : S₂;  // Can reorder operands freely

// Exploiting associativity
(a + b) + c => a + (b + c) : associative;  // Parentheses can be rearranged

// Exploiting group axioms for inverses
a + (-a) => 0 : group;  // Every element has an inverse

// Exploiting cyclic group properties
rotate(rotate(x, a), b) => rotate(x, (a + b) % n) : Cₙ;  // Combining rotations
```

### Canonical Representatives for Equivalence Classes

```
// Choosing smallest representative under some ordering
(expr) : g => min_representative(expr, g);  // Choose minimal representative

// Example: For commutative operations, order operands lexicographically
a * b : S₂ => ordered(a, b);  // Ordered by some canonical ordering

// Example: For rotation groups, always use the base orientation
rotate(x, k) : Cₙ => x if k == 0;  // Base orientation as canonical form
```

## Inferring Algebraic Structures via Symmetry Groups

Symmetry groups provide a powerful foundation for detecting and inferring higher algebraic structures in computational domains. This section shows how to lift known symmetry groups into richer algebraic structures like monoids, rings, and semirings.

### Structural Lifting Strategy

The key idea is to start from known symmetry groups (Cₙ, Dₙ, Sₙ, etc.) embedded in operations, and use them to induce larger algebraic structures when their operational patterns match algebraic laws.

```
// Detecting a monoid from a group structure
(op, G) : Group, has_identity(op, e) => (op, G, e) : Monoid;

// Detecting commutativity from S₂ symmetry
(op) : S₂ => (op) : Commutative;

// Lifting to ring structure when two operations interact
(+, G) : AbelianGroup, (*, M) : Monoid, distributes(*, +) => (+, *, G, M) : Ring;

// Inferring semiring when no additive inverse exists
(+, G) : CommutativeMonoid, (*, M) : Monoid, distributes(*, +) => (+, *, G, M) : Semiring;
```

### Detecting Fundamental Algebraic Properties

Before building complex structures, we need to detect basic algebraic properties:

```
// Identity element detection
op(e, x) = x ∧ op(x, e) = x for all x ∈ S => has_identity(op, e);

// Associativity detection
op(op(x, y), z) = op(x, op(y, z)) for all x,y,z ∈ S => associative(op);

// Commutativity detection
op(x, y) = op(y, x) for all x,y ∈ S => commutative(op);

// Inverse element detection
for each x ∈ S, ∃y ∈ S: op(x, y) = op(y, x) = e => has_inverse(op);

// Distributivity detection
op₁(x, op₂(y, z)) = op₂(op₁(x, y), op₁(x, z)) for all x,y,z ∈ S => distributes(op₁, op₂);

// Idempotence detection
op(x, x) = x for all x ∈ S => idempotent(op);

// Absorption detection
op₁(x, op₂(x, y)) = op₁(x, y) = op₂(x, op₁(x, y)) for all x,y ∈ S => absorption(op₁, op₂);
```

### From Cyclic Groups to Rings

Cyclic groups under addition naturally extend to rings when multiplication distributes over addition.

```
// C₂ₙ under addition forms an abelian monoid
(intₙ, +, 0) : C₂ₙ => (intₙ, +, 0) : AbelianMonoid;

// When multiplication distributes over addition, detect ring structure
(intₙ, +, *, 0, 1) : AbelianMonoid × Monoid => (intₙ, +, *, 0, 1) : Ring if distributes(*, +);

// Special case: Modular arithmetic forms a ring
(ℤ/nℤ, +, *, 0, 1) => (ℤ/nℤ, +, *, 0, 1) : Ring;

// Field detection: occurs when all non-zero elements have multiplicative inverses
(R, +, *, 0, 1) : Ring => (R, +, *, 0, 1) : Field if ∀x∈R{0}, ∃y∈R: x*y = 1;
```

### From Boolean Groups to Boolean Rings

The group (C₂)^n under XOR naturally extends to a Boolean ring with bitwise operations.

```
// Bitwise XOR forms an abelian group
(intₙ, ^, 0) : (C₂)^n => (intₙ, ^, 0) : AbelianGroup;

// Bitwise AND distributes over XOR
distributes(&, ^) : eval(true) => (intₙ, ^, &, 0, -1) : BooleanRing;

// Boolean ring has idempotent multiplication
(R, +, *, 0, 1) : Ring, ∀x∈R: x*x = x => (R, +, *, 0, 1) : BooleanRing;

// Boolean ring operations map to standard bit operations
(intₙ, ^, &, 0, -1) : BooleanRing => {
	// Ring addition is XOR
	(a + b) => eval(a ^ b);

	// Ring multiplication is AND
	(a * b) => eval(a & b);

	// Additive identity is 0
	// Multiplicative identity is -1 (all bits set)
};
```

### From Dihedral Groups to Transformation Semigroups

Dihedral groups of bit operations induce semigroups and monoids under composition.

```
// Bit rotation and reflection operations form a dihedral group
(rotate_left, reflect) : Dₙ => (compose(rotate_left, reflect)) : Semigroup;

// Adding identity transforms to semigroup yields monoid
(S, op) : Semigroup, ∃e∈S: ∀x∈S: op(e, x) = op(x, e) = x => (S, op, e) : Monoid;

// Bit transformations act on intₙ as group action
(Dₙ, intₙ, apply) : GroupAction => {
	// Group action laws hold
	apply(identity, x) => eval(x);
	apply(compose(g, h), x) => eval(apply(g, apply(h, x)));
};
```

### From Symmetric Groups to Symmetric Algebras

Operations invariant under permutations can induce symmetric algebraic structures.

```
// Operation invariant under permutation indicates symmetric structure
f(a, b, c) : S₃ => f : SymmetricOperation;

// Symmetric operations often indicate commutative algebraic structures
(op) : SymmetricOperation, (op, S) : Semigroup => (op, S) : CommutativeSemigroup;

// Shuffle algebra example: operations invariant under permutation
(shuffle(a, b)) : S₂ => (shuffle, sequences) : ShuffleAlgebra if associative(shuffle);
```

### Lattice and Order Detection

Some algebraic structures relate to partial orders and lattices:

```
// Detecting partial order from an operation
(≤) : Relation, reflexive(≤), antisymmetric(≤), transitive(≤) => (≤) : PartialOrder;

// Detecting join and meet operations
(∨, S) : CommutativeMonoid, idempotent(∨) => (∨, S) : JoinSemilattice;
(∧, S) : CommutativeMonoid, idempotent(∧) => (∧, S) : MeetSemilattice;

// Lattice structure combines join and meet operations
(S, ∨, ∧) : JoinSemilattice × MeetSemilattice, absorption(∨, ∧) => (S, ∨, ∧) : Lattice;

// Distributive lattice has distributions between join and meet
(S, ∨, ∧) : Lattice, distributes(∨, ∧), distributes(∧, ∨) => (S, ∨, ∧) : DistributiveLattice;

// Bit operations form a distributive lattice
(intₙ, |, &) => (intₙ, |, &) : DistributiveLattice;
```

### Inference for Higher Structures

Generic rules for detecting algebraic structures based on operational properties:

```
// Associative binary operation forms a semigroup
(op, S) : Operation, associative(op) => (op, S) : Semigroup;

// Associative binary operation with identity forms a monoid
(op, S) : Semigroup, has_identity(op, e) => (op, S, e) : Monoid;

// Monoid with inverses forms a group
(op, S, e) : Monoid, has_inverse(op) => (op, S, e) : Group;

// Commutative group is abelian
(op, S, e) : Group, commutative(op) => (op, S, e) : AbelianGroup;

// Commutative monoid with distributive second operation forms semiring
(add, S, zero) : CommutativeMonoid, (mul, S, one) : Monoid, distributes(mul, add)
	=> (add, mul, S, zero, one) : Semiring;

// Semiring with additive inverses forms a ring
(add, mul, S, zero, one) : Semiring, has_inverse(add) => (add, mul, S, zero, one) : Ring;

// Ring with multiplicative inverses for non-zero elements forms a field
(add, mul, S, zero, one) : Ring, has_multiplicative_inverse(mul, S{zero})
	=> (add, mul, S, zero, one) : Field;
```

### Practical Applications

These inference rules enable automated discovery of algebraic structures in code:

```
// Detect loop invariants based on algebraic properties
(loop_body) : Idempotent => loop_optimization(loop_body, "idempotence");

// Optimize computations based on semiring properties
(compute(a + b + c)) : Semiring => parallel_reduction(compute, [a, b, c]);

// Detect opportunities for algebraic transformations
(expr) : DistributiveLattice => rewrite_with_algebraic_laws(expr);

// Integer operations with inferred ring structure
(intₙ_operations) : Ring => apply_ring_optimizations(intₙ_operations);

// Detect and optimize based on neutral elements
(op, e) : NeutralElement => optimize_with_neutral_element(op, e);

// Factorize expressions based on ring properties
(a*x + b*x) : Ring => (a+b)*x : Factorized;
```

## Quick Reference Guide

This section provides a concise summary of key concepts, canonical forms, and rewrite rules.

### Key Group Properties

| Group | Order | Structure | Canonical Form | Key Rules |
|-------|-------|-----------|----------------|-----------|  
| Sₙ | n! | Permutations | Lexicographically ordered elements | a + b => ordered(a, b) |
| Cₙ | n | Rotations | Minimum rotation angle/index | rotate(x, k) => rotate(x, k % n) |
| Dₙ | 2n | Rotations + reflections | Canonical rotation then reflection | transform => rotate(reflect(x)) |
| Aₙ | n!/2 | Even permutations | Even-permutation ordering | canonical_even_permutation(p) |
| GL(n,F) | - | Invertible matrices | Row echelon form | rref(M) |

### Common Decompositions

| Group | Decomposition | Example | Note |
|-------|--------------|---------|------|
| Dₙ | Cₙ ⋊ C₂ | D₄ = C₄ ⋊ C₂ | Rotations acted on by reflections |
| Sₙ | Aₙ ⋊ C₂ | S₃ = A₃ ⋊ C₂ | Alternating group with odd/even parity |
| D₂ | C₂ × C₂ | - | Special case: direct product |

### Optimization Patterns

| Domain | Pattern | Rewrite | Benefit |
|--------|---------|--------|--------|
| Ring | a × (b + c) | (a × b) + (a × c) | Distribute for factorization |
| Cyclic Group | rotate(rotate(x, a), b) | rotate(x, (a+b) % n) | Combine nested rotations |
| Boolean Algebra | x ^ x | 0 | Self-inverse property |
| Commutative | a + b | sorted(a, b) | Canonical ordering |

### Common Implementation Mappings

| Programming Construct | Mathematical Structure | Group/Algebraic Structure |
|----------------------|----------------------|-------------------------|
| Integer addition | Z under addition | Infinite cyclic group |
| Modular arithmetic | ℤ/nℤ | Cyclic group Cₙ |
| Bitwise XOR | Bit vectors | Direct product (C₂)ⁿ |
| Bit rotations | Bit permutations | Cyclic group Cₙ |
| Commutative operators | Unordered pairs | Symmetric group S₂ |

## Conclusion

The rewriting rules presented in this document provide a foundation for working with symmetry groups in computational contexts. By understanding the structure of these groups and their relationships, we can develop efficient canonicalization strategies, optimize expressions, and reason about program equivalence across a wide range of domains.

These rules are particularly valuable for optimization in areas such as:

- **Computer graphics**: Where geometric symmetries (rotations, reflections) are fundamental
- **Cryptography**: Where group-theoretic properties form the mathematical basis
- **Algebraic simplification**: Where commutativity and associativity enable powerful rewrites
- **Functional programming**: Where higher-order function composition follows algebraic laws
- **Machine learning**: Where tensor operations benefit from symmetry optimizations
- **Parallel computing**: Where associative operations enable efficient distribution

By representing symmetry groups explicitly in our e-graph structure via domain annotations, we achieve several powerful capabilities:

1. **Exponential reduction** in the number of equivalent expressions that need representation
2. **Automatic discovery** of optimizations that exploit symmetry properties
3. **Transfer of optimizations** across domains with isomorphic group structures
4. **Inference of algebraic properties** that enable non-trivial optimizations

This group-theoretic foundation significantly enhances our ability to perform deep algebraic reasoning and optimization, allowing us to develop more powerful and general program transformation techniques that transcend specific domains and apply across the entire computational landscape.