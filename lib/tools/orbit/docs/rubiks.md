# Rubik's Cubes: Group Structures, Rewriting, and Canonical Forms

## 1. Introduction

Rubik's Cubes and their `N×N×N` variants (for `N≥2`) possess rich mathematical structures, specifically permutation groups. This document details how these group-theoretic properties can be leveraged within a rewriting system (like Orbit's OGraph). By defining abstract group structures and their simplification rules separately, we can apply them to the specific domain of Rubik's Cubes simply by annotating states and moves appropriately.

Beyond academic interest, understanding the group structure of Rubik's Cubes has practical applications in speedcubing, algorithm development, and computer-based solvers. The framework developed here bridges pure mathematics and practical solving strategies.

*This document is structured as follows:* Sections 2-3 define the state/move representation and the precise group structures involved. Sections 4-5 detail the abstract group rewrite rules and canonicalization strategies. Section 6 explains how these abstract rules apply to the cube domain. Section 7 discusses synergy across cube sizes, and Section 8 concludes with potential evaluation metrics. A running example is used to illustrate key concepts.

## Notation Table

| Symbol           | Meaning                                        | Example Usage                 |
| :--------------- | :--------------------------------------------- | :---------------------------- |
| `N`              | Size of the cube (N×N×N)                       | `N=3` for standard cube       |
| `State`          | Represents the configuration of the cube       | `State(...)`                  |
| `Turn(Ax,L,Dir)` | A move: Axis `Ax`, Layer `L`, Direction `Dir`  | `Turn(X, 0, +1)`              |
| `Compose(g, h)`  | Abstract group operation (g then h)            | `Compose(Move1, Move2)`       |
| `Inverse(g)`     | Abstract inverse of group element g            | `Inverse(Turn(X,0,1))`        |
| `Identity(G)`    | Abstract identity element of group G           | `Identity(RubikGroup_3x3)`    |
| `Element(d, G)`  | Abstract element `d` in group `G`              | `Element(p, S₈)`              |
| `g : G`          | Element `g` belongs to domain/group `G`        | `State :  G₁`       |
| `G₁ ⊂ G₂`        | Group `G₁` is a subgroup of `G₂`               | `A₈ ⊂ S₈`                     |
| `H ⋊ G`          | Semi-direct product of H by G                  | `C₃⁷ ⋊ A₈`                    |
| `G × H`          | Direct product of G and H                      | `S₈ × S₁₂`                    |
| `Sₙ`             | Symmetric group on n elements                  | `S₈` (corner permutations)    |
| `Aₙ`             | Alternating group on n elements (even perms)   | `A₈` (reachable corner perms) |
| `Cₙ`             | Cyclic group of order n                        | `C₃` (corner orientation)     |
| `ℤₙᵏ`            | Direct product of k copies of `Cₙ`             | `C₃⁷`, `C₂¹¹`                 |
| `→`              | Unidirectional rewrite rule                    | `g · Identity(G) → g`         |
| `↔`              | Bidirectional equivalence rule                 | `Compose(a,b) ↔ Compose(b,a)` |
| `φ`              | Homomorphism defining group action             | Action in `H ⋊ G`             |
| `Canonical(G)`   | Annotation for canonical form within group `G` | `State :  G₀`       |

## 2. Cube Components and Coordinate-Based Representation

### 2.1 Types of Cubies

A Rubik's Cube consists of four distinct types of cubies, each with specific properties:

1. **Core**: The fixed central infrastructure with 0 stickers, not visible from the outside.
2. **Centers**: 6 fixed pieces with 1 sticker each. These establish the color scheme and don't move relative to each other.
3. **Edges**: 12 pieces with 2 stickers each. Each edge has 2 possible orientations when placed in any position.
4. **Corners**: 8 pieces with 3 stickers each. Each corner has 3 possible orientations when placed in any position.

The *state* of a Rubik's Cube is fully determined by the permutation and orientation of its edges and corners. Centers are fixed on standard cubes (though they can rotate on larger cubes).

### 2.2 Coordinate System

To generalize across cube sizes (`N×N×N`, `N≥2`), we use a coordinate system:

1.  **Coordinate System**: Assume a standard 3D Cartesian system with the cube centered at (0,0,0). Axes X, Y, Z point conventionally (e.g., Right, Up, Front). 

    For even N cubes: We index layers by offset from cube center, e.g., ∈ {-½(N-1), ..., +½(N-1)}. This prevents ambiguity when LayerIndex=0.

    For odd N cubes: Layer indices still run `0..N-1` with the central layer at `(N-1)/2`.

    Visual representation for N=3:
    ```
			 2 +---+---+---+
			     |   |   |   |
			 1 +---+---+---+
			     |   |   |   |
			 0 +---+---+---+
			         0   1   2
```

2.  **State Representation**: A mapping from *cubie positions* (defined by coordinates) to *cubie identities* (type: corner, edge, center; original colors/stickers) and *orientations*.

3.  **Move Representation**: A move `Turn(Axis, LayerIndex, Direction)`:
    *   `Axis`: The axis of rotation (`X`, `Y`, or `Z`).
    *   `LayerIndex`: Integer from `0` to `N-1`, specifying the slice perpendicular to `Axis` to turn. `0` might be the "Left" face layer along X, `N-1` the "Right".
    *   `Direction`: `+1` for clockwise (e.g., 90°), `-1` for counter-clockwise (e.g., -90° or 270°), when looking along the positive axis direction. `+2` could represent 180°.

    *Formal Grammar (BNF-like):*
    ```
	Move ::= Turn(Axis, LayerIndex, Direction)
	Axis ::= 'X' | 'Y' | 'Z'
	LayerIndex ::= <integer 0..N-1>
	Direction ::= <integer typically +1, -1, +2>
```

    *Example*: Standard 'R' on a 3x3: `Turn(X, 2, +1)`. Slice 'M' on 3x3: `Turn(X, 1, -1)` (typically defined CCW).

## 3. The Abstract Group Layer

We use abstract constructors to represent group concepts:

*   `Compose(g, h)`: Group operation.
*   `Inverse(g)`: Inverse element.
*   `Identity(G)`: Identity element of group `G`.
*   `Element(data, G)`: Group element `data` in group `G`.

Concrete cube turns are mapped to `Element` nodes within the rewriting system, annotated with the appropriate `RubikGroup_NxN`.

## 4. Rubik's Cube Groups

The set of reachable states forms the `RubikGroup_NxN`.

### 4.1 Specific Group Structures & Decomposition

Here we quote the exact cardinality of the `RubikGroup_3x3`: \(|G| = 43,252,003,274,489,856,000 = 2^{27} \cdot 3^{14} \cdot 5^{3} \cdot 7^{2} \cdot 11\).

1.  **2×2×2 Cube (`RubikGroup_2x2`)**: 8 corners.
    *   **Structure**: A semi-direct product `C₃⁷ ⋊ A₈`. Only *even* permutations of corners are reachable (`A₈`), and orientations of 7 corners determine the 8th (`C₃⁷`). Element orders can reach a maximum of 1260, which is valuable for algorithmic heuristic considerations.
    *   **Decomposition**: Combines **Corner Orientation Group** (`C₃⁷`) and the **Corner Permutation Group** (`A₈`).

2.  **3×3×3 Cube (`RubikGroup_3x3`)**: 8 corners, 12 edges.
    *   **Structure**: Isomorphic to `((C₃⁷ × C₂¹¹) ⋊ (A₈ × A₁₂))`. Combines corner orientation (`C₃⁷`), edge orientation (`C₂¹¹`), *even* corner permutations (`A₈`), and *even* edge permutations (`A₁₂`).
    *   **Parity Constraint**: The permutation of corners and the permutation of edges must have the *same parity*. This constraint is implicitly handled by generating moves ensuring `sgn(perm_corner) = sgn(perm_edge)`.
    
        **Example of Parity Constraint**: The move sequence `R L U2 R L U2` produces a single "double-swap" of edges (UF↔UB, DF↔DB) with no effect on corners. Since this creates an odd permutation of edges, it's impossible to create just a single edge swap without affecting corners or other edges.
        
    *   **Decomposition**: Involves the **Corner Group** (`C₃⁷ ⋊ A₈`) and the **Edge Group** (`C₂¹¹ ⋊ A₁₂`), linked by the parity constraint.

    *   **Center of the Group**: The center of G (elements that commute with all cube permutations) consists of exactly two elements: { Identity, Superflip }. The "Superflip" is the unique non-trivial central configuration where all edges are flipped in place, while corners remain solved.

3.  **N×N×N Cube (N > 3)**: Adds multiple edge types and center pieces.
    *   **Structure**: Complex direct and semi-direct products of symmetric and cyclic groups.

### 4.2 Practical Invariants

Certain properties remain invariant under all valid move sequences:

1. **Total Corner Twist**: The sum of corner orientations must equal 0 (mod 3). This means the total twist of all corners must be divisible by 3.
   ```
	 Σ(corner_orientations) ≡ 0 (mod 3)
```

2. **Total Edge Flip**: The sum of edge orientations must equal 0 (mod 2). This means the total number of flipped edges must be even.
   ```
	 Σ(edge_orientations) ≡ 0 (mod 2)
```

3. **Permutation Parity**: The parity of the corner permutation must match the parity of the edge permutation.
   ```
	 sgn(corner_permutation) = sgn(edge_permutation)
```

These invariants provide immediate rejection rules for unsolvable states in algorithm implementations.

### 4.3 Relevant Subgroups

Solving often uses the Thistlethwaite/Kociemba sequence (G₀ ⊃ G₁ ⊃ G₂ ⊃ G₃ ⊃ G₄ = {Identity}):
*   **G₀**: `RubikGroup_NxN`.
*   **G₁**: Edge orientations correct. Generators include {U, D, R², L², F², B², M, E, S} (slice moves added for clarification).
*   **G₂**: Corner orientations correct, edges in the correct slice (for 3x3). Generators include those of G₁ plus slice moves like {M², E², S²} (or their equivalents expressed via outer layer turns).
*   **G₃**: "Square Group" - pieces in correct orbits. Generators {U², D², R², L², F², B², M², E², S²}.
*   **G₄**: `{Identity(RubikGroup_NxN)}`.

## 4.4 Rubik’s Cubes as Polynomial Ideals and Gröbner Bases

A powerful alternative to group-theoretic reasoning is **encoding the Rubik’s Cube as a system of polynomial equations** over a finite field, such that the solution set of the ideal corresponds to valid cube states and move sequences. This is especially feasible and pedagogically relevant for the 2×2×2 “Pocket Cube”, whose state space is large (3,674,160 states) yet tractable for radical algebraic techniques with modern tools.

### State & Move Encoding in Polynomials

- **Permutation Variables:**  
  Let \( p_{i,j} \) be a Boolean variable (over \(\mathbb{F}_2\)) equal to 1 if cubie originally at position \(i\) is now at \(j\).  
- **Orientation Variables:**  
  Let \( o_j \) encode the orientation (0,1,2 ≡ mod 3) of the corner currently at position \(j\), over, say, \(\mathbb{F}_7\) (since there exists a primitive cube root of unity).

- **Constraints:**  
  - Each position \(j\) contains exactly one cubie:  \(\sum_{i=0}^{7} p_{i,j} = 1\)
  - Each cubie occurs exactly once:\(\sum_{j=0}^{7} p_{i,j} = 1\)
  - Booleanity: \(p_{i,j}^2 - p_{i,j} = 0\)
  - **Permutation parity (alternating group \(A_8\))**: Ensures only reachable permuted states.
  - **Orientation constraints:** \(o_j^3 - 1 = 0\), and total orientation multiplies to 1 (modulo 3 roots).
- **Moves as Polynomial Mappings:**  
  Each generator move (say \(R\), \(U\), \(F\)) permutes \(p_{i,j}\) and adjusts \(o_j\) (modulo 3). Move composition corresponds to polynomial substitution, and bounds on sequence length can be encoded via repeated variable blocks (“time slices”).
- **Instance/Solution:**
  - Scrambled-state variables imposed in first block.
  - Solved-state variables imposed in final block.
  - Constraint polynomials enforce each time slice is a legitimate move or no-op.

### Solving the Cube Algebraically
The problem is then to compute a **Gröbner basis** for this ideal (preferably in an elimination order that removes intermediate variables). If the basis reduces to a zero-dimensional ideal, the cube is solvable by a (sequence of) specified moves; and all shortest solutions, or proofs of impossibility under constraints, can be extracted from the solutions.

### Comparison & Connection to Group Theory

- The above polynomial system *encodes* precisely the same group structure discussed throughout this document—e.g., parity constraints, semidirect product structure, orientation invariants—but in a form directly amenable to algorithmic algebra (e.g., via computer algebra systems).
- The polynomial ideal approach is conceptually analogous to the canonical forms and group actions: allowable cube states (or move sequences) are intersection points of algebraic varieties; the algebraic invariants enforce precisely the corners of \(C_3^7 \rtimes A_8\).
- For “sticker-color” or “facelet” encodings, one can mimic the Sudoku approach directly, though it is less efficient than the group/cubie encoding.

### Utility and Limitations
- This algebraic method is tractable for the 2×2×2, allowing exploration of *all* minimal solutions, or for exploring exotic constraint scenarios (e.g., forbidden moves, enforced symmetries).
- For larger cubes (like 3×3×3), the combinatorics still tend to overwhelm generic Gröbner-basis solvers, confirming the practical value of direct group-theoretic algorithms for speed in such cases.

### Summary Table: Cubes and Polynomial Ideals

| Cube Type    | Group Structure                | Polynomial Encoding Feasible? |
|--------------|-------------------------------|-------------------------------|
| 2×2×2        | \(C_3^7 \rtimes A_8\)         | **Yes, tractable**            |
| 3×3×3        | \((C_3^7 \times C_2^{11}) \rtimes (A_8 \times A_{12})\) & Only theoret. (huge) |
| NxN (N>3)    | Complex products/semi-direct   | No (except for special subgroups) |

---

#### Implementation Note (Orbit)

Just as equations get canonicalized (e.g., to reduced Gröbner basis) in the polynomial setting, so too does the Orbit/Cube system use canonical forms under group action (e.g., \(A_8\), \(C_3^7\)), leveraging symmetry to minimize search and redundancy.

Researchers and advanced users may wish to:
- Formulate cube constraints directly in polynomial algebra (for e.g., constraint satisfaction or cryptanalysis).
- Use group-theoretic canonicalization for efficient enumeration, then algebraic methods for completeness and proof generation.

---

#### References
- See [chalkdustmagazine.com/features/unlocking-sudokus-secrets/](https://chalkdustmagazine.com/features/unlocking-sudokus-secrets/) for a deep-dive on exact Sudoku-to-polynomial encodings, which directly inspire this approach for Rubik’s Cubes.

## 5. Abstract Rewrite Rules

These apply to any elements annotated with a group domain `G`.

### 5.1 General Group Axiom Rules

```
# Associativity
Compose(a, Compose(b, c)) : G  ↔  Compose(Compose(a, b), c) : G;

# Identity Laws
Compose(g : G, Identity(G))  →  g : G;
Compose(Identity(G), g : G)  →  g : G;

# Inverse Laws
Compose(g : G, Inverse(g))  →  Identity(G);
Compose(Inverse(g), g : G)  →  Identity(G);
Inverse(Inverse(g : G))     →  g : G;
Inverse(Identity(G))        →  Identity(G);
Inverse(Compose(g : G, h : G)) → Compose(Inverse(h), Inverse(g)) : G;
```

### 5.2 Commutation and Conjugation

```
# Commutation (Conditional)
# Define DisjointLayers(M₁, M₂) based on coordinate system:
# Returns true if Turn(Ax₁, L₁, D₁) and Turn(Ax₂, L₂, D₂) affect layers
# that do not share any cubies (e.g., Ax₁=Ax₂, L₁≠L₂; or Ax₁≠Ax₂, ...)
Compose(M₂, M₁) : G  ↔  Compose(M₁, M₂) : G  if DisjointLayers(M₁, M₂);

# Conjugation Definition
Apply(Conjugate(A, B), State)  ↔  Apply(Inverse(A), Apply(B, Apply(A, State)));
```
Specific useful commutator/conjugate sequences can be added as named rules.

Here's the explicit definition of the semidirect-action \(φ\): permutations act on orientations
\[\phi: C_{p} \to Aut(C_{o})\] where an element of \(C_{o}\) is a tuple of orientation indices, and \(C_{p}\) permutes those indices.

### 5.3 Decomposition Rules (Semi-direct Product H ⋊ G)

The permutation part `g` acts on the orientation part `h` via a homomorphism `φ: G → Aut(H)`. Specifically, `φ(g)` permutes the components of the orientation vector `h` according to how `g` permutes the piece positions.

```
# Composition: (h₁, g₁) · (h₂, g₂) = (h₁ · φ(g₁)(h₂), g₁ · g₂)
Compose(Pair(h1, g1) : H ⋊ G, Pair(h2, g2) : H ⋊ G) →
	Pair(Compose(h1, ApplyAction(g1, h2, φ)), Compose(g1, g2)) : H ⋊ G;
# 'ApplyAction(g, h, φ)' represents φ(g)(h).

# Inverse: (h, g)⁻¹ = (φ(g⁻¹)(h⁻¹), g⁻¹)
Inverse(Pair(h, g) : H ⋊ G) →
	Pair(ApplyAction(Inverse(g), Inverse(h), φ), Inverse(g)) : H ⋊ G;
```

### 5.4 Example: Move Sequence Simplification

Consider `R U R'` on a 2x2 corner piece (ignoring others).
*   Let `State₀` be the initial state.
*   `R` might be `Element(r_data, RubikGroup_2x2)`, `U` is `Element(u_data, ...)`, `R'` is `Inverse(R)`.
*   Sequence: `Compose(Inverse(R), Compose(U, R))`.
*   Abstract rules alone don't simplify this beyond associativity.
*   However, if `R = Pair(h_r, g_r)` and `U = Pair(h_u, g_u)` in `C₃⁷ ⋊ A₈`, the semi-direct product rules calculate the combined effect:
    `R U = Pair(h_r · φ(g_r)(h_u), g_r · g_u)`
    `(R U) R' = Compose(Pair(h_ru, g_ru), Pair(h_r_inv, g_r_inv))`
    Applying the rule yields the final `Pair(h_final, g_final)` representing the state change.

## 6. Canonicalization Strategies

### 6.1 Global Canonical Form (Solved State = Identity)

The solved state is `Identity(RubikGroup_NxN)`. The goal of solving is to find a sequence of moves `M` such that `Apply(M, InitialState)` is equivalent to `Identity(RubikGroup_NxN)`.

```
# The identity element is canonical for the whole group
Identity(RubikGroup_NxN) :  G₀;

# We check for equivalence, not rewrite the state away.
# If State's eclass merges with Identity's eclass:
CheckEquivalence(State, Identity(RubikGroup_NxN)) → true : IsSolved;
```

### 6.2 Subgroup Canonical Forms & Rules

Intermediate canonical forms are defined relative to subgroups. Abstract canonicalization rules are triggered by annotations.

```
# Abstract rules (implementations external)
p : Aₙ  →  canonical_even_permutation(p);
r : Cₙ  →  canonical_rotation(r); # e.g., r mod n
d : Dₙ  →  canonical_dihedral(d);

# Link state components to abstract groups
CornerPermutationState(...) : A₈; # Note: A₈ for N≥2
EdgePermutationState(...)   : A₁₂; # Note: A₁₂ for N=3, parity-linked
CornerOrientationState(...) : C₃⁷; # Or component-wise : C₃
EdgeOrientationState(...)   : C₂¹¹; # Or component-wise : C₂

# Define subgroup canonical properties
State : EdgesAreOriented      →  State : G₁;
State : CornersAreOriented    →  State : OrientationGroup;
State : PiecesInCorrectOrbits →  State : G₃;
```
The rewriting system applies these rules to simplify components of the state representation (e.g., canonicalizing the permutation part using the `Aₙ` rule).

### 6.3 Conjugacy Classes

The Rubik's Cube group has 81,120 conjugacy classes. This remarkably high number results from:

1. **Permutation Classes**: 
   - Corner permutation classes: 22 (from symmetric group S₈)
   - Edge permutation classes: 77 (from symmetric group S₁₂)

2. **Orientation Classes**:
   - Corner orientation classes: 140 
   - Edge orientation classes: 308

3. **Parity Restrictions**:
   - Even permutation classes: 12 corner × 40 edge = 480
   - Odd permutation classes: 10 corner × 37 edge = 370

The total conjugacy class count is found by combining permutation and orientation classes while respecting parity constraints: (308 × 140) + (291 × 130) + (17 × 10) = 81,120.

These conjugacy classes provide ample structure for sampler or canonical-class enumeration benchmarks, as well as insights into the cube's algebraic structure.

### 6.4 Solving via Subgroups

Modeled by rules applying move sequences valid within a subgroup `Gᵢ` to reach the canonical form for the next subgroup `Gᵢ₊₁`.

```
# Rule applying G₀ moves to reach G₁ canonical form (Edge Orientation)
State : G₀ → Apply(SolveEdgeOrientationAlg, State) :  G₁;

# Rule applying G₁ moves to reach G₂ canonical form
State :  G₁ → Apply(SolveCornerOrientAndEdgeSliceAlg, State) : G₂;

# ... down to G₄ (Identity)
State : G₃ → Apply(SolveSquareGroupAlg, State) : G₄; # Canonical(G₄) is Identity
```

## 7. Synergy Across Cube Sizes (`N≥2`)

1.  **Abstract Rule Reuse**: Axioms and canonicalization for `Aₙ`, `Cₙ`, `Dₙ`, product groups apply universally via annotations.
2.  **Coordinate Notation**: `Turn(Axis, Layer, Dir)` is uniform.
3.  **Component Annotation**: Corners are always `: A₈`, `: C₃⁷`. Edges complexity varies, but orientation is often `: C₂`. Reusable rules apply to these components.
4.  **Hierarchical Structure**: Subgroup strategy (G₀-G₄) provides a common framework.
    
Canonical forms beyond 'solved' recognize that a cube's position can be a minimal *word metric* length ≤ 20 under the quarter-turn metric, referencing God's number as the upper bound.

## 8. Applications to Speedcubing

### 8.1 Commutators in Blindfolded Solving

Understanding group theory directly informs blindfolded Rubik's Cube solving techniques. Commutators (expressions of form [A, B] = A B A⁻¹ B⁻¹) are particularly valuable:

```
# A basic 3-cycle commutator for corners
[R D R', U'] = R D R' U' R D' R' U
```

This performs a 3-cycle of corners (URF → ULF → ULB) without affecting other pieces, allowing solvers to decompose a scrambled cube into a series of commutators.

### 8.2 Parity Resolution

Parity constraints require specialized algorithms when an odd number of swaps is needed:

```
# Common algorithm to resolve edge parity (double-swap)
R U R' U' R' F R2 U' R' U' R U R' F'
```

This performs a specific permutation that swaps two pairs of edges, illustrating how group theory explains why certain permutations require longer algorithms.

### 8.3 Optimal Solution Finding

The established upper bound of 20 moves (God's number) for any position informs search strategies for optimal solutions. Group-theoretic concepts like:

- Coset space decomposition
- Subgroup-based pruning
- Symmetry reduction

provide the foundation for sophisticated cube-solving programs and techniques.

## 9. Conclusion and Evaluation Hook

Separating abstract group rules from the Rubik's Cube domain allows leveraging general mathematical properties automatically via domain annotations. This modular approach simplifies implementation and enhances synergy across different cube sizes.

*Evaluation Idea*: A potential benchmark could measure the number of rewrite steps (using the abstract rules + cube-specific move effects) required to reduce a scrambled state to its canonical form within successive subgroups (G₁, G₂, etc.) and compare this against the number of states explored in a simple breadth-first search within those subgroups. This would quantify the reduction in search space achieved by the algebraic simplification rules.
