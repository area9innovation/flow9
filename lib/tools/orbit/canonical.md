# Canonical Forms and Rewriting Rules for Symmetry Groups

## Introduction

This document provides a comprehensive set of rewriting rules for common symmetry groups, enabling canonical representations of expressions involving these groups. These rules are particularly useful for optimization and simplification in computational domains that exhibit symmetries.

## Notation

This document uses the following notation for groups, operators, and relations:

### Group Symbols
- **Sₙ**: Symmetric group of order n! (all permutations of n elements)
- **Aₙ**: Alternating group of order n!/2 (even permutations of n elements)
- **Cₙ**: Cyclic group of order n (rotational symmetry)
- **Dₙ**: Dihedral group of order 2n (reflections and rotations of a regular n-gon)
- **GL(n,F)**: General linear group (invertible n×n matrices over field F)
- **SL(n,F)**: Special linear group (n×n matrices with determinant 1 over field F)
- **O(n)**: Orthogonal group (n×n matrices M where M^T·M = I)
- **Q₈**: Quaternion group (non-abelian group of order 8)
- **ℤ/nℤ**: Integers modulo n (also denoted as ℤₙ)

### Operators and Relations
- **×**: Direct product of groups
- **⋊**: Semi-direct product of groups
- **⊂**: Subset relation (A ⊂ B means A is a subgroup of B)
- **⊲**: Normal subgroup (A ⊲ B means A is a normal subgroup of B)
- **≅**: Isomorphism (A ≅ B means groups A and B are isomorphic)
- **≇**: Not isomorphic (A ≇ B means groups A and B are not isomorphic)
- **|G|**: Order (size) of group G
- **∈**: Element membership (a ∈ G means a is an element of G)
- **⟺**: Logical equivalence (p ⟺ q means p if and only if q)

### Rewrite Rule Notation
- **a : G**: Expression a belongs to domain G
- **=>**: Rewrite rule (left hand side rewrites to right hand side)
- **if**: Conditional application of a rule
- **a : G => b : H**: Expression a in domain G rewrites to expression b in domain H
- **a !: G**: Expression a does NOT belong to domain G
- **eval()**: Used to evaluate expressions on the right-hand side during rewriting
- **: Canonical**: Annotation indicating the result is in canonical form
- **discard**: Indicates a branch that should be pruned during canonicalization

Throughout this document, rewrite rules are presented in a pattern-matching style where the left side of => describes a pattern to match, and the right side describes the transformation to apply. Conditions after "if" specify when the rule applies.

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

### Matrix Groups

Matrix groups capture important symmetries in linear algebra and geometry.

#### General Linear Group (GL(n, F))

GL(n, F) consists of all invertible n×n matrices over a field F.

- **GL(1, ℝ)**: Group of non-zero real numbers under multiplication
- **GL(2, ℝ)**: Group of 2×2 real invertible matrices
- **GL(n, ℝ)**: Group of all real n×n matrices with non-zero determinant

#### Special Linear Group (SL(n, F))

SL(n, F) consists of all n×n matrices with determinant 1 over a field F.

- **SL(2, ℝ)**: Group of 2×2 real matrices with determinant 1
- **SL(n, ℝ)**: Group of all real n×n matrices with determinant 1

#### Orthogonal Group (O(n))

O(n) consists of all n×n orthogonal matrices (matrices M where M^T M = I).

- **O(1)**: Group of 1×1 matrices {1, -1}, isomorphic to C₂
- **O(2)**: Group of 2×2 orthogonal matrices (rotations and reflections in the plane)
- **O(3)**: Group of 3×3 orthogonal matrices (rotations and reflections in 3D space)

### Quaternion Group (Q₈)

Q₈ is a non-abelian group of order 8, with all non-identity elements having order 4.

- Not isomorphic to D₄ (dihedral group of order 8)
- Not isomorphic to C₂ × C₄ (direct product of cyclic groups)
- Elements usually denoted {±1, ±i, ±j, ±k}

## Canonical Forms

### Canonicalization Rules

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

// General rotation rules
rotate_left(rotate_right(x, k), k) => x : Canonical;
rotate_left(rotate_left(x, a), b) => rotate_left(x, eval((a + b) % n)) : Canonical;
rotate_left(x, 0) => x : Canonical;
```

#### Dihedral Group (Dₙ)

```
// D₄ canonicalization (square symmetry group)
(rotate(x, n % 4)) : D₄ => x : Canonical if (n % 4) == 0;
(rotate(x, n % 4)) : D₄ => rotate90(x) : Canonical if (n % 4) == 1;
(rotate(x, n % 4)) : D₄ => rotate180(x) : Canonical if (n % 4) == 2;
(rotate(x, n % 4)) : D₄ => rotate270(x) : Canonical if (n % 4) == 3;

(reflect(x, axis)) : D₄ => reflectH(x) : Canonical if axis == "horizontal";
(reflect(x, axis)) : D₄ => reflectV(x) : Canonical if axis == "vertical";
(reflect(x, axis)) : D₄ => reflectD1(x) : Canonical if axis == "diagonal1";
(reflect(x, axis)) : D₄ => reflectD2(x) : Canonical if axis == "diagonal2";
```

#### Alternating Groups (Aₙ)

The alternating group Aₙ consists of all even permutations of n elements and is a subgroup of Sₙ.

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

#### Matrix Groups

Matrix groups have important applications in mathematics, physics, and computer graphics.

##### General Linear Group (GL(n, F))

The general linear group GL(n, F) consists of all invertible n×n matrices over a field F.

```
// GL canonicalization using row echelon form
(M) : GL(n, F) => eval(rref(M)) : Canonical;
(M) : GL(n, F) => discard if eval(det(M)) == 0;  // Not invertible ⇒ not in GL

// SL canonicalization using normalized RREF with det = 1
(M) : SL(n, F) => eval(normalize(rref(M))) if eval(det(M)) == 1;
```

##### Orthogonal Group (O(n))

The orthogonal group O(n) consists of all n×n orthogonal matrices (matrices whose transpose equals their inverse).

```
// O(n): MᵀM = I
(M) : O(n) => eval(canonical_orthogonal_form(M)) if eval(Mᵀ·M) == I;
```

#### Commutative Ring Terms and Gröbner Basis Canonicalization

Commutative rings have a rich algebraic structure that can be exploited for canonicalization.

```
// Commutative polynomials in ring: normalize via lex order
(f + g) : PolynomialRing => eval(ordered_sum(f, g));

// Multivariate monomial canonical form
(x^a * y^b * z^c) => eval(Monomial(x, y, z, [a, b, c]));

// Reduction via known ideal (Gröbner-like)
(p) : Ideal(I) => eval(normal_form(p, I)) : Canonical;
```

### Gröbner Basis for Commutative Rings

Gröbner bases provide a systematic approach to canonicalizing expressions in commutative rings, especially polynomial rings.

- **Monomial Order**: Defines a canonical way to arrange monomials in polynomials (lex, grlex, grevlex)
- **Normal Form**: Reduced representation of a polynomial modulo an ideal
- **Ideal Membership**: Determines if a polynomial belongs to an ideal generated by a set of polynomials
- **Ideal Operations**: Enables computation with polynomial ideals (intersection, quotient, elimination)

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

### Dihedral Group Decompositions

```
// Dₙ decomposition into semi-direct product
Dₙ => Cₙ ⋊ C₂;

// Specific example: D₆ decomposition
D₆ => C₆ ⋊ C₂;

// Alternative decomposition of D₆
D₆ => D₃ × C₂ if gcd(3, 2) == 1;  // Special case when n is odd
```

### Symmetric Group Decompositions

```
// S₄ can be decomposed using normal subgroups
S₄ => A₄ ⋊ C₂;  // Semi-direct product with alternating group A₄

// Sₙ decomposition for n > 4 is more complex
Sₙ => Aₙ ⋊ C₂ for n > 1;  // Semi-direct product with alternating group
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

## Practical Applications

### Integer Operations

```
// Addition forms a cyclic group in modular arithmetic
(a + b) mod n : Cₙ;  // Addition modulo n has cyclic group structure

// Multiplication forms a more complex group
(a * b) mod n : (ℤ/nℤ)*;  // Multiplicative group of integers modulo n

// Powers in modular arithmetic
(a^k) mod n => a^(k mod φ(n)) mod n if gcd(a, n) == 1;  // Where φ is Euler's totient function
```

### Bit Operations

```
// Bitwise operations on fixed-width integers
(a ^ b) : (C₂)ⁿ for n-bit integers;  // XOR forms an abelian group

// Bit rotations form cyclic groups
rotate_left(x, k) : Cₙ for n-bit integers;  // Left rotation by k positions

// Bit shifts don't form a group (not invertible)
shift_left(x, k) !: group;  // Shift operations don't form a group
```

### Matrix Group Operations

```
// Matrix multiplication forms a group for invertible matrices
(A * B) : GL(n, F);  // Matrix multiplication in general linear group

// Orthogonal transformations preserve inner products
(M * v) · (M * w) => v · w if M : O(n);  // Inner product preservation

// Special linear group preserves volume
det(M) => 1 if M : SL(n, F);  // Determinant is always 1

// Matrix exponential maps Lie algebra to Lie group
exp(A) : SO(n) if A : so(n);  // Exponential of skew-symmetric matrix gives rotation
```

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

## Conclusion

The rewriting rules presented in this document provide a foundation for working with symmetry groups in computational contexts. By understanding the structure of these groups and their relationships, we can develop efficient canonicalization strategies, optimize expressions, and reason about program equivalence across a wide range of domains.

These rules are particularly valuable for optimization in areas such as computer graphics (where geometric symmetries are common), cryptography (where group-theoretic properties are fundamental), and algebraic simplification (where commutativity and associativity enable powerful rewrites).

By leveraging these group-theoretic principles, we can develop more powerful and general program optimization techniques that transcend specific domains and apply across the entire computational landscape.