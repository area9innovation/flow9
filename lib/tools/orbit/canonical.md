# Canonical Forms and Rewriting Rules for Symmetry Groups

## Introduction

This document provides a comprehensive set of rewriting rules for common symmetry groups, enabling canonical representations of expressions involving these groups. These rules are particularly useful for optimization and simplification in computational domains that exhibit symmetries.

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

### Known Isomorphisms

```
// Basic isomorphisms
C₂ ≅ Z/2Z;        // Cyclic group of order 2 is isomorphic to integers modulo 2
D₁ ≅ C₂;          // Dihedral group of order 2 is isomorphic to cyclic group of order 2
D₂ ≅ C₂ × C₂;      // Dihedral group of order 4 is isomorphic to direct product of C₂ with itself

// Less obvious isomorphisms
S₃ ≅ D₃;           // Symmetric group on 3 elements is isomorphic to dihedral group of order 6
```

### Discrete Type Mappings

```
// Mapping discrete types to groups
int8 ≅ Z/256Z ≅ C₂₅₆;     // 8-bit integer arithmetic is isomorphic to modular arithmetic
int16 ≅ Z/65536Z ≅ C₆₅₅₃₆;  // 16-bit integer arithmetic

// Modular arithmetic groups
Z/nZ ≅ Cₙ;                 // Integers modulo n form a cyclic group of order n

// Bitwise operations
xor on (Z/2Z)ⁿ ≅ (C₂)ⁿ;     // Bitwise XOR on n-bit types forms an abelian group
```

## Practical Applications

### Integer Operations

```
// Addition forms a cyclic group in modular arithmetic
(a + b) mod n : Cₙ;  // Addition modulo n has cyclic group structure

// Multiplication forms a more complex group
(a * b) mod n : (Z/nZ)*;  // Multiplicative group of integers modulo n

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