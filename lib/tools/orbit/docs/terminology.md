# Orbit System Terminology

This document consolidates terminology, structures, domains, and notation used across the Orbit documentation.

## Core Concepts

*   **Orbit:** A domain-unified rewriting engine designed for mathematical formalism and practical programming using a functional paradigm.
*   **Rewriting System:** A system that applies rules to transform expressions or terms into equivalent or simpler forms.
*   **Domain:** A classification or property associated with an expression (e.g., `Integer`, `Real`, `S₂`, `Polynomial`, `Canonical`, `Pure`, `IO`). Domains can represent types, mathematical structures, effects, semantic states, or symmetry groups.
*   **Domain Annotation (`: Domain`):** Syntax used to associate an expression with a domain. On the LHS of a rule, it acts as a constraint; on the RHS, it's an assertion.
*   **Negative Domain Guard (`!: Domain`):** Syntax used in patterns to match expressions that *do not* belong to the specified domain. Useful for preventing infinite loops or applying rules only once.
*   **Domain Hierarchy (`⊂` or `c=`):** Defines subset relationships between domains (e.g., `Integer ⊂ Real`). Rules defined for parent domains apply to child domains.
*   **Canonical Form:** A unique, standard representation chosen from a set of equivalent expressions. Essential for equality testing, optimization, and reducing redundancy. Marked with `: Canonical`.
*   **AST (Abstract Syntax Tree):** The tree structure representing code or expressions. Orbit has first-class support for AST manipulation.
	*   `: ast`: Annotation indicating a function parameter receives an unevaluated AST.
	*   `quote(e)`: Prevents evaluation, treating `e` as an AST.
	*   `eval(e)`: Evaluates an AST expression `e`. Can be used within `quote` or `: ast` contexts for selective evaluation.
	*   `substituteWithBindings(expr, bindings)`: Substitutes variables in `expr` based on `bindings` without evaluating.
	*   `evalWithBindings(expr, bindings)`: Substitutes variables and evaluates the result.
	*   `unquote(expr, bindings)`: Traverses `expr`, evaluating only sub-expressions wrapped in `eval()`.
	*   `prettyOrbit(expr)`: Formats an AST into readable code.
	*   `astname(expr)`: Returns the type/operator name of the root AST node.
*   **OGraph / EGraph:** Data structure for efficiently representing sets of equivalent expressions (e-classes) and their relationships. OGraph extends EGraph with domain/group annotations and a designated canonical root per e-class.
	*   `e-node`: Represents an operation and its children (which are e-classes).
	*   `e-class`: Represents a set of equivalent e-nodes.
	*   `makeOGraph`, `addOGraph`, `mergeOGraphNodes`, `addDomainToNode`, `matchOGraphPattern`, etc.: Runtime functions for manipulating OGraphs.

## Rewriting Syntax

*   `lhs => rhs` or `lhs → rhs`: Unidirectional rewrite rule.
*   `lhs <=> rhs` or `lhs ↔ rhs`: Bidirectional equivalence rule.
*   `if cond`: Conditional application of a rule.
*   `⊢` or `\|-`: Entailment. Asserts a domain property based on a matched pattern (e.g., `a:Int + b:Int ⊢ + : S₂`).
*   `discard`: Indicates a branch/rule result should be pruned/ignored.
*   Pattern Variables: Lowercase identifiers (`a`, `x`) match arbitrary subexpressions. Repeated variables must match equivalent expressions.

## Group Theory

*   **Group:** A set with an associative binary operation, identity element, and inverses.
*   **Symmetry Group:** A group capturing the symmetries of an object or expression.
	*   `Sₙ`: Symmetric group (all permutations of n elements). Used for commutativity (S₂) and set/multiset equivalence. Canonical form: sorted sequence.
	*   `Aₙ`: Alternating group (even permutations of n elements).
	*   `Cₙ`: Cyclic group (rotations). Used for modular arithmetic, bit rotations. Canonical form: minimal rotation (Booth's algorithm).
	*   `Dₙ`: Dihedral group (rotations and reflections). Used for geometric symmetries. Canonical form: minimal representation under rotations and reflections.
	*   `GL(n,F)`: General Linear group (invertible n×n matrices over field F).
	*   `SL(n,F)`: Special Linear group (n×n matrices with determinant 1).
	*   `O(n)`: Orthogonal group (n×n matrices M where MᵀM = I).
	*   `Q₈`: Quaternion group.
	*   `ℤ/nℤ` or `ℤₙ`: Integers modulo n (isomorphic to Cₙ under addition).
	*   `(ℤ/nℤ)^*`: Multiplicative group of units modulo n.
*   **Group Operation Symbols:**
	*   `·` or `Compose(g,h)`: Abstract group operation.
	*   `×`: Direct Product (independent groups).
	*   `⋊`: Semi-Direct Product (one group acts on another).
	*   `≀`: Wreath Product (hierarchical action).
*   **Group Properties/Concepts:**
	*   `|G|`: Order (size) of group G.
	*   `Identity(G)`: Identity element.
	*   `Inverse(g)`: Inverse of element g.
	*   `⊂`: Subgroup relation.
	*   `⊲`: Normal subgroup relation.
	*   `≅`: Isomorphism (structurally identical groups).
	*   `Action`: How a group transforms elements of a set.
	*   `Orbit`: Set of elements reachable from one element via group action.
	*   `Homomorphism (φ)`: Structure-preserving map between groups.
	*   `Automorphism (Aut(G))`: Isomorphism from a group to itself.
	*   `Kernel`: Elements mapping to identity under homomorphism.
	*   `Image`: Set of elements reached by homomorphism.
	*   `Center`: Elements commuting with all group elements.
	*   `Conjugacy Class`: Orbit under conjugation action (`g h g⁻¹`).
	*   `Invariant`: Property unchanged by group action.

## Mathematical Domains & Structures

*   **Algebraic Structures:** `Set`, `Magma`, `Semigroup`, `Monoid`, `Group`, `AbelianGroup`, `Ring`, `Field`, `Vector Space`, `BooleanAlgebra`, `Lattice`.
*   **Numbers:** `Integer`, `Int32`, `Rational`, `Real`, `Double`, `Complex`, `Numeric`.
*   **Linear Algebra:** `Matrix`, `Vector`, `Transpose (Aᵀ)`, `Inverse (A⁻¹)`, `Determinant (det(A))`, `Trace (tr(A))`, `Dot Product (·)`, `Cross Product (×)`, `Row Echelon Form (rref)`, Matrix Decompositions (`svd`, `eigen`, `qr`, `lu`, `cholesky`), `DiagonalMatrix`, `SymmetricMatrix`, `OrthogonalMatrix`, etc.
*   **Calculus:** `Differential Calculus`, `Derivative (d/dx)`, `Partial Derivative (∂/∂xᵢ)`, `Gradient (∇)`, `Jacobian (J(f))`, `Hessian (H(f))`, `Integral (∫)`, `Summation (∑)`, `Limit`.
*   **Polynomials:** `Polynomial`, `Monomial`, `Polynomial Ring`, `Ideal (⟨...⟩)`, `Gröbner Basis`, `Leading Term (LT)`, `Normal Form (NF)`, `S-polynomial (S(f,g))`, Monomial Orders (`lex`, `grlex`, `grevlex`).
*   **Logic:** `Boolean`, Propositional Logic (`&&`/`∧`, `||`/`∨`, `!` /`¬`), Quantifiers (`∀`, `∃`), BDD (`ITE(v,t₀,t₁)`), CNF/DNF.
*   **Tensors:** Higher-dimensional arrays, Index Notation (`T^{i}_{j}`), Contraction (`C(T)`), Tensor Product (`⊗`), Einstein Summation.
*   **Interval Arithmetic:** Intervals (`[a,b]`), Interval operations, `inf`, `sup`, `width`, `mid`, Intersection (`∩`), Hull (`∪`).
*   **Transforms:** `DFT`, `FFT`, `WHT`, `Convolution`.
*   **Recurrence Relations:** `T(n)`, Master Theorem, Akra-Bazzi, Characteristic Polynomial, Generating Functions.

## Computer Science Domains

*   **Data Structures:** `Array`, `List`, `Set`, `Bag/Multiset`, `Binary Tree`, `Trie`, `Graph`.
*   **Automata & Formal Languages:** `Finite Automata (DFA, NFA)`, `Regular Expression (Regex)`, `Alphabet (Σ)`, `Language (L(r))`, `ε` (empty string), `∅` (empty set), `State (q)`, `Transition (δ)`.
*   **Compilers & Languages:** `Parser Combinators` (`⟨*⟩`, `⟨|⟩`), `Grammar`, `Left-recursion`, `Left-factoring`, `First/Follow sets`.
*   **Concurrency:** `Process Calculus`, Parallel (`∥`), Choice (`+`/`⊕`), Sequence (`;`), Replication (`!`), Restriction (`ν`), Channels (`a↑`/`a↓`), Locks, Barriers, Threads.
*   **Functional Programming:** `Lambda (λ)`, `map`, `filter`, `fold`, `Functor`, `Monad`, `Applicative`.
*   **Complexity Analysis:** `O(...)`, `Θ(...)`, `Ω(...)`, `Cost`, `Potential (Φ)`, Amortized Analysis, Average/Worst Case.
*   **Cryptography:** `Homomorphic Encryption` (`E(m)`, `D(c)`, `⊕`, `⊗`), Modular Arithmetic (`mod n`), `φ(n)`, RSA, Diffie-Hellman.
*   **Effects:** `Effect System`, `Pure`, `State`, `IO`, `Exception`, `EffectDomain(E)`.
*   **GPU Computing:** `WebGPU`, `WGSL`, `Kernel`, `Workgroup`, `Storage Class`, `Region-Based Memory`.

## Specific Algorithms / Methods

*   **FFT Algorithms:** Cooley-Tukey, Rader's, Bluestein's.
*   **Canonicalization Algorithms:** Booth's (Cyclic), Nauty (Graphs), Buchberger's (Gröbner Basis).
*   **Approximation Methods:** Newton-Raphson, Taylor Series, Padé Approximants, Runge-Kutta, Monte Carlo, Finite Differences.
*   **Sudoku/Rubik's Cube Solvers:** Constraint Propagation, Backtracking, Subgroup Methods (G₀-G₄).

This consolidated list provides a reference for the key terms and notations used within the Orbit system documentation.

## Unified Domain Lattice Structure

To enable a unified system where rules and properties can be inherited and shared, we can structure the identified domains into a conceptual lattice or hierarchy. This hierarchy uses the subset relation (`⊂`) to denote that elements of a subdomain also belong to the superdomain, allowing rules defined for broader categories (like `Ring`) to apply to more specific instances (like `Integer` or `Int32`).

This is one possible structure; the exact relationships can be refined based on the specific semantics desired within the Orbit system.


```
Top (Most General Domain)
 ├── ComputationalObject
 │   ├── DataStructure
 │   │   ├── Sequence
 │   │   │   ├── Array
 │   │   │   ├── List
 │   │   │   └── String
 │   │   ├── Map / Dictionary
 │   │   ├── Set / Multiset (Bag)
 │   │   ├── Tree
 │   │   │   ├── BinaryTree
 │   │   │   └── Trie
 │   │   └── Graph (Directed/Undirected)
 │   ├── Expression / AST (Abstract Syntax Tree)
 │   │   ├── OrbitExpr (Orbit's own AST)
 │   │   └── MathExpr (Mathematical Notation)
 │   └── Representation
 │       ├── BDD (Binary Decision Diagram)
 │       ├── PolynomialSystem
 │       └── State (e.g., CubeState, SudokuGrid)
 │
 ├── MathematicalStructure
 │   ├── AlgebraicStructure
 │   │   ├── SetTheory (Operations: ∪, ∩)
 │   │   ├── Magma
 │   │   │   └── Semigroup
 │   │   │       └── Monoid
 │   │   │           ├── Group
 │   │   │           │   ├── AbelianGroup
 │   │   │           │   │   └── CyclicGroup (Cₙ)
 │   │   │           │   │       └── IntegersModN (ℤ/nℤ)
 │   │   │           │   ├── SymmetricGroup (Sₙ)
 │   │   │           │   │   └── AlternatingGroup (Aₙ)
 │   │   │           │   ├── DihedralGroup (Dₙ)
 │   │   │           │   ├── MatrixGroup
 │   │   │           │   │   ├── GeneralLinearGroup (GL(n,F))
 │   │   │           │   │   │   └── SpecialLinearGroup (SL(n,F))
 │   │   │           │   │   └── OrthogonalGroup (O(n))
 │   │   │           │   └── QuaternionGroup (Q₈)
 │   │   │           └── Semiring
 │   │   │               └── Ring
 │   │   │                   ├── CommutativeRing
 │   │   │                   │   ├── PolynomialRing
 │   │   │                   │   │   └── Ideal / GröbnerBasis
 │   │   │                   │   └── Field
 │   │   │                   │       ├── Rational
 │   │   │                   │       ├── Real
 │   │   │                   │       │   └── Interval // Interval Arithmetic relates here
 │   │   │                   │       └── Complex
 │   │   │                   └── Integer ⊂ CommutativeRing // Integer is a Ring, subset of Rational
 │   │   │                       └── IntN (e.g., Int32) ⊂ Integer // Finite Integer Ring/Group
 │   │   ├── VectorSpace (over a Field)
 │   │   │   ├── Vector
 │   │   │   └── Matrix
 │   │   ├── Tensor
 │   │   └── Lattice
 │   │       └── DistributiveLattice
 │   │           └── BooleanAlgebra
 │   │               └── BooleanFunction (represented by LogicExpr, BDD, CNF, etc.)
 │   └── Calculus
 │       ├── DifferentialCalculus (Operators: d/dx, ∂/∂xᵢ, ∇, J, H)
 │       ├── IntegralCalculus (Operators: ∫)
 │       └── TensorCalculus (Operators: ∇ᵢ, div, curl)
 │
 ├── ProgrammingConstruct
 │   ├── Type
 │   │   ├── PrimitiveType (int, float, bool, string)
 │   │   ├── ConstructedType (list<T>, map<K,V>, FunctionType)
 │   │   └── OrbitType (Int, Double, String, Bool, Ast, Function)
 │   ├── Effect
 │   │   ├── Pure
 │   │   ├── State (ReadOnlyState)
 │   │   ├── IO (Console)
 │   │   └── Exception
 │   ├── ConcurrencyConstruct
 │   │   ├── Process (PiCalculus, CSP)
 │   │   ├── Channel
 │   │   └── SynchronizationPrimitive (Lock, Barrier)
 │   ├── LoopConstruct / IterationDomain
 │   ├── Parser / GrammarConstruct
 │   └── MemoryLayout (AoS, SoA, RowMajor, ColMajor)
 │
 ├── AnalysisProperty
 │   ├── SemanticProperty
 │   │   ├── Associative
 │   │   ├── Commutative (often linked to S₂)
 │   │   ├── Distributive
 │   │   ├── Idempotent
 │   │   └── Invertible (InvertibleIf)
 │   ├── ComplexityMeasure
 │   │   ├── Cost (O, Θ, Ω)
 │   │   ├── Potential (Φ)
 │   │   ├── AmortizedCost, AverageCost, WorstCost, BitCost
 │   │   └── SpaceComplexity
 │   ├── NumericalProperty
 │   │   ├── Precision / ErrorBound
 │   │   ├── Stability
 │   │   └── ConditionNumber
 │   └── VerificationProperty
 │       ├── Correctness
 │       └── Termination
 │
 ├── FormalSystem
 │   ├── LogicSystem (Propositional, Predicate)
 │   ├── FormalLanguage
 │   │   └── RegularLanguage (Regex, DFA, NFA)
 │   └── CategoryTheoryConstruct (Functor, Monad, Applicative)
 │
 └── ApplicationDomain
		 ├── SignalProcessing (DFT, FFT, WHT)
		 ├── Cryptography (HomomorphicEncryption, RSA, ModularArithmetic)
		 ├── Physics / Simulation (NBodyProblem, PDE, Electrodynamics)
		 ├── Graphics (Transformations, Rendering)
		 ├── ConstraintSatisfaction (Sudoku, Rubik's Cube)
		 └── MachineLearning (NeuralNetworkOps)

```


**Explanation and Usage:**

1.  **Hierarchy:** Indentation represents the `⊂` relationship. For example, `CyclicGroup ⊂ AbelianGroup ⊂ Group`.
2.  **Inheritance:** A rule defined for `Group` (like associativity) automatically applies to `AbelianGroup`, `CyclicGroup`, `Sₙ`, etc. A rule for `Ring` applies to `Integer`, `Real`, `PolynomialRing`.
3.  **Multiple Inheritance:** Some domains fit in multiple places (e.g., `BooleanAlgebra` is both a `Ring` and a `DistributiveLattice`). The O-Graph supports multiple domain annotations per e-class to handle this.
4.  **Instances vs. Subtypes:** Some entries are instances (e.g., `Sₙ` is *an instance* of `Group`) while others are true subtypes (e.g., `Integer` *is a kind of* `Ring`). The `⊂` notation is used broadly here to indicate that properties/rules should be inherited.
5.  **Orthogonal Concepts:** Some domains like `Type`, `Effect`, `Complexity`, or `MemoryLayout` are somewhat orthogonal to the mathematical structures but interact with them. They are grouped logically.
6.  **Purpose:** This lattice allows Orbit to automatically apply general mathematical laws (like commutativity via `S₂` defined for `AbelianGroup`) to specific computational types (like Orbit's `Int` or `Double`) once the connection (`Int ⊂ Ring ⊂ AbelianGroup`) is established. It also enables cross-domain rule application where structures are isomorphic (e.g., `ℤ/nℤ` addition and `Cₙ`).

This unified structure allows the Orbit system to reason about expressions from diverse sources within a single, coherent framework, maximizing code reuse for rewrite rules and enabling powerful cross-domain optimizations based on shared underlying mathematical principles.
