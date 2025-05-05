# Orbit System Terminology

This document consolidates terminology, structures, domains, and notation used across the Orbit documentation.

## Core Concepts

*   **Orbit:** A domain-unified rewriting engine designed for mathematical formalism and practical programming using a functional paradigm.
*   **Rewriting System:** A system that applies rules to transform expressions or terms into equivalent or simpler forms.
*   **Domain:** A classification or property associated with an expression (e.g., `Integer`, `Real`, `S₂`, `Polynomial`, `Pure`, `IO`). Domains can represent types, mathematical structures, effects, semantic states, or symmetry groups.
*   **Domain Annotation (`: Domain`):** Syntax used to associate an expression with a domain. On the LHS of a rule, it acts as a constraint; on the RHS, it's an assertion.
*   **Negative Domain Guard (`!: Domain`):** Syntax used in patterns to match expressions that *do not* belong to the specified domain. Useful for preventing infinite loops or applying rules only once.
*   **Domain Hierarchy (`⊂`):** Defines subset relationships between domains (e.g., `Integer ⊂ Real`). Rules defined for parent domains apply to child domains.
*   **Canonical Form:** A unique, standard representation chosen from a set of equivalent expressions based on defined rules (e.g., lexicographical order for Sₙ, minimal rotation for Cₙ). Essential for equality testing, optimization, and reducing redundancy. Within the O-Graph, the designated **representative (root)** node of an e-class converges to this canonical form through rule saturation.
*   **AST (Abstract Syntax Tree):** The tree structure representing code or expressions. Orbit has first-class support for AST manipulation.
	*   `: ast`: Annotation indicating a function parameter receives an unevaluated AST.
	*   `quote(e)`: Prevents evaluation, treating `e` as an AST.
	*   `eval(e)`: Evaluates an AST expression `e`. Can be used within `quote` or `: ast` contexts for selective evaluation.
	*   `substituteWithBindings(expr, bindings)`: Substitutes variables in `expr` based on `bindings` without evaluating.
	*   `evalWithBindings(expr, bindings)`: Substitutes variables and evaluates the result.
	*   `unquote(expr, bindings)`: Traverses `expr`, evaluating only sub-expressions wrapped in `eval()`.
	*   `prettyOrbit(expr)`: Formats an AST into readable code.
	*   `astname(expr)`: Returns the type/operator name of the root AST node.
*   **O-Graph / E-Graph:** Data structure for efficiently representing sets of equivalent expressions (e-classes) and their relationships. O-Graph extends E-Graph with domain/group annotations and a designated **representative (root)** per e-class, which converges to the canonical form during saturation.
	*   `e-node`: Represents an operation and its children (which are e-classes).
	*   `e-class`: Represents a set of equivalent e-nodes, identified by its representative (root) node's ID.
	*   `makeOGraph`, `addOGraph`, `mergeOGraphNodes`, `addDomainToNode`, `matchOGraphPattern`, etc.: Runtime functions for manipulating O-Graphs.

## Rewriting Syntax

*   `lhs -> rhs` or `lhs → rhs`: Unidirectional rewrite rule.
*   `lhs <-> rhs` or `lhs ↔ rhs`: Bidirectional equivalence rule.
*   `if cond`: Conditional application of a rule.
*   `⊢` or `|-`: Entailment. Asserts a domain property based on a matched pattern (e.g., `a:Int + b:Int ⊢ + : S₂`).
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
	*   `*` : Abstract group operation (e.g., `g * h`).
	*   `×`: Direct Product (independent groups, e.g., `G × H`).
	*   `⋊`: Semi-Direct Product (one group acts on another, e.g., `H ⋊[φ] G`).
	*   `≀`: Wreath Product (hierarchical action).
*   **Group Properties/Concepts:**
	*   `|G|`: Order (size) of group G.
	*   `1` or `e`: Identity element (context dependent).
	*   `g⁻¹` or `inverse(g)`: Inverse of element g.
	*   `⊂`: Subgroup relation.
	*   `⊲`: Normal subgroup relation.
	*   `≅`: Isomorphism (structurally identical groups).
	*   `Action (•)`: How a group transforms elements of a set (e.g., `g • x`).
	*   `Orbit`: Set of elements reachable from one element via group action.
	*   `Homomorphism (φ)`: Structure-preserving map between groups.
	*   `Automorphism (Aut(G))`: Isomorphism from a group to itself.
	*   `Kernel`: Elements mapping to identity under homomorphism.
	*   `Image`: Set of elements reached by homomorphism.
	*   `Center`: Elements commuting with all group elements.
	*   `Conjugacy Class`: Orbit under conjugation action (`g * h * g⁻¹`).
	*   `Invariant`: Property unchanged by group action.

## Mathematical Domains & Structures

*   **Algebraic Structures:** `Set`, `Magma`, `Semigroup`, `Monoid`, `Group`, `AbelianGroup`, `Ring`, `Field`, `Vector Space`, `BooleanAlgebra`, `Lattice`.
*   **Numbers:** `Integer`, `Int32`, `Rational`, `Real`, `Double`, `Complex`, `Numeric`.
*   **Linear Algebra:** `Matrix`, `Vector`, Transpose (`Aᵀ`), Inverse (`A⁻¹`), Determinant (`det(A)`), Trace (`tr(A)`), Dot Product (`⋅` or `dot_product`), Cross Product (`×` or `cross_product`), Row Echelon Form (`rref`), Matrix Decompositions (`svd`, `eigen`, `qr`, `lu`, `cholesky`), `DiagonalMatrix`, `SymmetricMatrix`, `OrthogonalMatrix`, etc.
*   **Calculus:** `Differential Calculus`, Derivative (`diff(f, x)`), Partial Derivative (`∂f/∂xᵢ`), Gradient (`∇f` or `grad(f)`), Jacobian (`J(f)` or `jacobian(f)`), Hessian (`H(f)` or `hessian(f)`), Integral (`integrate(f, x)` or `integrate(f, x, a, b)`), Summation (`summation(f, i, a, b)`), Limit (`limit(f, x, a)`).
*   **Polynomials:** `Polynomial`, `Monomial`, `Polynomial Ring`, Ideal (`⟨...⟩`), Gröbner Basis (`groebner_basis(...)`), Leading Term (`leading_term(f)`), Normal Form (`normal_form(f, G)`), S-polynomial (`S(f,g)`), Monomial Orders (`lex`, `grlex`, `grevlex`).
*   **Logic:** `Boolean`, Propositional Logic (`∧`, `∨`, `¬`), Quantifiers (`∀ x: P(x)`, `∃ x: P(x)`), BDD (`ITE(v,t₀,t₁)`), CNF/DNF.
*   **Tensors:** Higher-dimensional arrays, Index Notation (`T^{i}_{j}`), Contraction (`C(T)`), Tensor Product (`⊗` or `kronecker`), Einstein Summation.
*   **Interval Arithmetic:** Intervals (`[a,b]`), Interval operations, `inf`, `sup`, `width`, `mid`, Intersection (`∩`), Hull (`∪`).
*   **Transforms:** `DFT`, `FFT`, `WHT`, `Convolution`.
*   **Recurrence Relations:** `T(n)`, Master Theorem, Akra-Bazzi, Characteristic Polynomial, Generating Functions.

## Chemistry Domains

*   **Molecular Structure:**
	*   `MolecularCompound`: Base domain for molecular compounds.
	*   `MolecularGraph`: Representation of a molecule as a graph (atoms as vertices, bonds as edges).
	*   `SMILES`: Simplified Molecular Input Line Entry System representation.
	*   `InChI`: International Chemical Identifier representation.
*   **Point Groups:** Molecular symmetry classifications.
	*   `PointGroup`: Base domain for all molecular symmetry groups.
	*   `C₁`: No symmetry (identity only).
	*   `Cₙ`: n-fold rotation symmetry (e.g., `C₂`, `C₃`, `C₄`).
	*   `Cₙᵥ`: n-fold rotation with n vertical mirror planes (e.g., `C₂ᵥ`, `C₃ᵥ`).
	*   `Dₙ`: n-fold rotation with perpendicular C₂ axes.
	*   `Dₙₕ`: Dₙ with horizontal mirror plane.
	*   `Tᵈ`: Tetrahedral symmetry.
	*   `Oₕ`: Octahedral symmetry.
*   **Organic Compounds:** Hierarchical classification of organic molecules by functional groups.
	*   `OrganicCompound`: Base domain for all organic compounds.
	*   `Hydrocarbon`: Contains only carbon and hydrogen.
	*   `Alcohol`: Contains -OH functional group.
	*   `Ether`: Contains C-O-C linkage.
	*   `Aldehyde`: Contains -CHO group.
	*   `Ketone`: Contains C=O group.
	*   `CarboxylicAcid`: Contains -COOH group.
	*   `Ester`: Contains -COOR group.
	*   `Amide`: Contains -CONR₂ group.
	*   `Amine`: Contains -NR₂ group.
*   **Hydrocarbon Subtypes:**
	*   `Alkane`: Saturated hydrocarbons.
	*   `Alkene`: Contains C=C double bonds.
	*   `Alkyne`: Contains C≡C triple bonds.
	*   `Arene`: Contains aromatic rings.
*   **Alcohol Subtypes:**
	*   `PrimaryAlcohol`: R-CH₂-OH structure.
	*   `SecondaryAlcohol`: R₂-CH-OH structure.
	*   `TertiaryAlcohol`: R₃-C-OH structure.
	*   `Diol`: Contains two -OH groups.
	*   `Phenol`: Hydroxyl attached to aromatic ring (Alcohol ∩ Arene).
	*   `Enol`: Hydroxyl attached to alkene C (Alcohol ∩ Alkene).
*   **Chemical Reactions:**
	*   `ChemicalReaction`: Base domain for chemical reactions.
	*   `BalancedReaction`: Reaction with balanced atoms.
	*   `Esterification`: Reaction forming esters.
	*   `Oxidation`: Reaction increasing oxygen content.
	*   `Reduction`: Reaction increasing hydrogen content.
	*   `Substitution`: Reaction replacing atoms/groups.
	*   `Addition`: Reaction adding to a molecule without small molecule production.
	*   `Elimination`: Reaction removing atoms with small molecule production.
	*   `Hydrolysis`: Reaction with water breaking bonds.
*   **Reaction Properties:**
	*   `AtomBalanced`: Conservation of atoms in reaction.
	*   `ChargeBalanced`: Conservation of charge in reaction.
	*   `ChiralityPreserving`: Stereochemistry maintained during reaction.
	*   `Stereoselective`: Producing specific stereoisomer preferentially.
	*   `Racemization`: Loss of stereoselectivity.
*   **Stereochemistry:**
	*   `StereoCenter`: Carbon with four different substituents.
	*   `R`: Right-handed configuration at stereocenter.
	*   `S`: Left-handed configuration at stereocenter.
	*   `E`: Entgegen (opposite) configuration at double bond.
	*   `Z`: Zusammen (together) configuration at double bond.
*   **Synthesis and Analysis:**
	*   `SynthesisPath`: Valid route to synthesize a target molecule.
	*   `SynthesisTree`: Complete synthesis plan with branches.
	*   `ReactionPathway`: Series of connected reaction steps.
	*   `CatalyticCycle`: Cyclic process with catalyst regeneration.
	*   `EnergyProfile`: Energy changes through reaction steps.
	*   `RateDetermining`: Step controlling overall reaction rate.

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
*   **Canonicalisation Algorithms:** Booth's (Cyclic), Nauty (Graphs), Buchberger's (Gröbner Basis).
*   **Approximation Methods:** Newton-Raphson, Taylor Series, Padé Approximants, Runge-Kutta, Monte Carlo, Finite Differences.
*   **Sudoku/Rubik's Cube Solvers:** Constraint Propagation, Backtracking, Subgroup Methods (G₀-G₄).
*   **Chemistry Methods:** Molecular Mechanics, Quantum Chemistry (DFT, HF, MP2), QSAR, Molecular Dynamics.

This consolidated list provides a reference for the key terms and notations used within the Orbit system documentation.

## Unified Domain Lattice Structure

To enable a unified system where rules and properties can be inherited and shared, we can structure the identified domains into a conceptual lattice or hierarchy. This hierarchy uses the subset relation (`⊂`) to denote that elements of a subdomain also belong to the superdomain, allowing rules defined for broader categories (like `Ring`) to apply to more specific instances (like `Integer` or `Int32`).

```orbit
Top (Most General Domain)
 ├── ComputationalObject
 │   ├── DataStructure
 │   │   ├── Sequence
 │   │   │   ├── Array
 │   │   │   ├── List
 │   │   │   └── String
 │   │   ├── Map / Dictionary
 │   │   ├── Set
 │   │   ├── Bag
 │   │   ├── Tree
 │   │   │   ├── BinaryTree
 │   │   │   └── Trie
 │   │   └── Graph
 │   │       ├── Directed Graph
 │   │       └── UnDirected Graph
 │   └── Expression / AST (Abstract Syntax Tree)
 │       ├── OrbitExpr (Orbit's own AST)
 │       └── MathExpr (Mathematical Notation)
 │           ├── ArithmeticExpr // +, *, /, ^ etc.
 │           ├── ComparisonExpr // <, ≤, >, ≥, =
 │           ├── MaxExpr / MinExpr / MedianExpr // Includes Max(), Min(), Median() constructors
 │           ├── NormExpr // Node representing Norm(f, Space)
 │           ├── SummationExpression // Node representing Sum(...)
 │           └── IntegralExpression // Node representing Integral(...)
 │
 ├── MathematicalStructure
 │   ├── Algebraic
 │   │   ├── Magma // Type* → Type* → Type* (binary operation)
 │   │   │   └── Semigroup ⊂ Magma // + mul_assoc axiom
 │   │   │       └── Monoid ⊂ Semigroup // + identity element (1, 0) & axioms
 │   │   │           └── Group ⊂ Monoid // + inverse & axioms
 │   │   │               ├── AbelianGroup ⊂ Group // + mul_comm/add_comm axiom (Orbit: implies S₂ symmetry for op)
 │   │   │               │   └── CyclicGroup (Cₙ) ⊂ AbelianGroup // + generated by one element
 │   │   │               │       └── IntegersModN (ℤ/nℤ) ≅ CyclicGroup // Instance
 │   │   │               └── **Non-Abelian Groups** (Specific instances/domains in Orbit)
 │   │   │                   ├── SymmetricGroup (Sₙ) // Instance of Group
 │   │   │                   ├── AlternatingGroup (Aₙ) ⊂ SymmetricGroup // Subgroup instance
 │   │   │                   ├── DihedralGroup (Dₙ) // Instance of Group
 │   │   │                   ├── MatrixGroup // Family of Groups
 │   │   │                   │   ├── GeneralLinearGroup (GL(n,F))
 │   │   │                   │   │   └── SpecialLinearGroup (SL(n,F)) ⊂ GeneralLinearGroup
 │   │   │                   │   └── OrthogonalGroup (O(n)) ⊂ GeneralLinearGroup
 │   │   │                   └── QuaternionGroup (Q₈) // Instance of Group
 │   ├── **Ring-like Structures (Two Operations: +, *)**
 │   │   ├── Semiring // Extends Additive Monoid, Multiplicative Monoid + distributivity
 │   │   │   └── Ring ⊂ Semiring // Extends Additive AbelianGroup
 │   │   │       ├── CommutativeRing ⊂ Ring // + mul_comm axiom (Orbit: implies * : S₂)
 │   │   │       │   ├── Field ⊂ CommutativeRing // + multiplicative inverse for non-zero
 │   │   │       │   │   ├── Rational (ℚ) ≅ Field // Instance
 │   │   │       │   │   ├── Real (ℝ) ≅ Field // Instance
 │   │   │       │   │   │   └── PositiveReal ⊂ Real // Specific subset for estimates
 │   │   │       │   │   └── Complex (ℂ) ≅ Field // Instance
 │   │   │       │   ├── Integer (ℤ) ⊂ CommutativeRing // Instance
 │   │   │       │   │   └── Nat (ℕ) ⊂ Integer // Natural numbers (often Monoid/Semiring)
 │   │   │       │   │   └── IntN ⊂ Integer // Finite Integer Ring Z/2ⁿZ
 │   │   │       │   └── PolynomialRing ⊂ CommutativeRing
 │   │   │       │       └── Ideal / GröbnerBasis // Concepts within PolynomialRing
 │   │   │       └── NonCommutativeRing // E.g., Matrix Ring
 │   │   ├── BooleanAlgebra ⊂ CommutativeRing // Also a Lattice
 │   ├── **Module & Vector Space Structures**
 │   │   ├── Module (over Ring R) // Extends AbelianGroup + scalar mult
 │   │   │   └── VectorSpace (over Field F) ⊂ Module // Instance where R is a Field
 │   │   │       ├── Vector // Element of VectorSpace
 │   │   │       └── Matrix // Represents Linear Transformation / Element of Matrix Ring/Algebra
 │   │   ├── Tensor // Generalization
 │   ├── **Order Structures**
 │   │   ├── PartialOrder
 │   │   │   └── Lattice ⊂ PartialOrder // + has LUB (join ∨) & GLB (meet ∧)
 │   │   │       └── DistributiveLattice ⊂ Lattice // + distributivity laws
 │   ├── **Topological Structures**
 │   │   ├── TopologicalSpace
 │   │   │   └── MetricSpace ⊂ TopologicalSpace
 │   ├── **Calculus** (Conceptual grouping, operations act on Fields mostly)
 │   │   ├── DifferentialCalculus
 │   │   ├── IntegralCalculus
 │   │   └── TensorCalculus
 │   └── **Function Spaces** (For Advanced Estimates)
 │       ├── FunctionSpace // Base domain
 │       │   ├── LpSpace (Lᵖ) ⊂ FunctionSpace
 │       │   └── SobolevSpace (Hˢ) ⊂ FunctionSpace
 │
 ├── VerificationFramework // NEW: For Estimate Verification
 │   ├── VerificationTask (Verify(...))
 │   ├── Estimate // Represents a relational statement
 │   │   ├── ApproxLE (A ≲ B) ⊂ Estimate // Asymptotic LE
 │   │   ├── ApproxGE (A ≳ B) ⊂ Estimate // Asymptotic GE
 │   │   ├── ApproxEq (A ∼ B) ⊂ Estimate // Asymptotic EQ
 │   │   ├── LE (A ≤ B) ⊂ Estimate // Strict LE
 │   │   ├── GE (A ≥ B) ⊂ Estimate // Strict GE
 │   │   └── Equal (A = B) ⊂ Estimate // Strict EQ
 │   ├── Assumption // Contains an Estimate
 │   └── VerificationResult
 │       ├── TrueEstimate ⊂ VerificationResult
 │       └── FalseEstimate ⊂ VerificationResult
 │
 ├── ChemistryDomain
 │   ├── MolecularCompound
 │   │   ├── MolecularGraph
 │   │   ├── OrganicCompound
 │   │   │   ├── Hydrocarbon
 │   │   │   │   ├── Alkane
 │   │   │   │   ├── Alkene
 │   │   │   │   ├── Alkyne
 │   │   │   │   └── Arene
 │   │   │   ├── Alcohol
 │   │   │   │   ├── PrimaryAlcohol
 │   │   │   │   ├── SecondaryAlcohol
 │   │   │   │   ├── TertiaryAlcohol
 │   │   │   │   └── Diol
 │   │   │   ├── Ether
 │   │   │   ├── Aldehyde
 │   │   │   ├── Ketone
 │   │   │   ├── CarboxylicAcid
 │   │   │   ├── Ester
 │   │   │   ├── Amide
 │   │   │   └── Amine
 │   ├── ChemicalReaction
 │   │   ├── BalancedReaction
 │   │   ├── Oxidation
 │   │   ├── Reduction
 │   │   ├── Esterification
 │   │   ├── Hydrolysis
 │   │   ├── Addition
 │   │   ├── Elimination
 │   │   └── Substitution
 │   ├── PointGroup
 │   │   ├── C₁
 │   │   ├── Cₙ
 │   │   ├── Cₙᵥ
 │   │   ├── Dₙ
 │   │   ├── Dₙₕ
 │   │   ├── Tᵈ
 │   │   └── Oₕ
 │   └── Stereochemistry
 │       ├── StereoCenter
 │       │   ├── R
 │       │   └── S
 │       └── DoubleBond
 │           ├── E
 │           └── Z
 │
 ├── ProgrammingConstruct
 │   ├── Type
 │   │   ├── PrimitiveType (int, float, bool, string)
 │   │   ├── Constructor (Foo, Maybe<?>)
 │   │   ├── ConstructedType (List<T>, Map<K,V>, FunctionType<?, ??>)
 │   │   ├── Polymormism (List<?>, Map<?,??>)
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
 │   │   ├── Cost (O, Θ, Ω) TODO: Split in code speed, code size, memory
 │   │   ├── Potential (Φ)
 │   │   ├── AmortizedCost, AverageCost, WorstCost, BitCost
 │   │   └── SpaceComplexity
 │   ├── NumericalProperty
 │   │   ├── Precision / ErrorBound
 │   │   ├── Stability
 │   │   └── ConditionNumber
 │   ├── VerificationProperty // Properties of verification process itself
 │   │   ├── Correctness
 │   │   └── Termination
 │   ├── **DependencyTracking** // NEW: For Estimates
 │   │   ├── DependsOn(Param) ⊂ DependencyTracking
 │   │   ├── IndependentOf(Param) ⊂ DependencyTracking
 │   │   ├── Parameter(Param) ⊂ DependencyTracking // Identifies a parameter
 │   │   └── AbsoluteConstant ⊂ DependencyTracking // Independent of all parameters
 │   └── **RewritingControl** // NEW: Meta-properties guiding rewriting
 │       ├── CaseContext(Assumptions) ⊂ RewritingControl // Current case assumptions
 │       ├── SufficientlyLarge(Param) ⊂ RewritingControl // Condition for rules
 │       └── Strategy(Name) ⊂ RewritingControl // e.g., Strategy(LogTransform)
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

**Explanation and Usage:**

1.  **Hierarchy:** Indentation represents the `⊂` relationship. For example, `CyclicGroup ⊂ AbelianGroup ⊂ Group`.
2.  **Inheritance:** A rule defined for `Group` (like associativity) automatically applies to `AbelianGroup`, `CyclicGroup`, `Sₙ`, etc. A rule for `Ring` applies to `Integer`, `Real`, `PolynomialRing`.
3.  **Multiple Inheritance:** Some domains fit in multiple places (e.g., `BooleanAlgebra` is both a `Ring` and a `DistributiveLattice`). The O-Graph supports multiple domain annotations per e-class to handle this.
4.  **Instances vs. Subtypes:** Some entries are instances (e.g., `Sₙ` is *an instance* of `Group`) while others are true subtypes (e.g., `Integer` *is a kind of* `Ring`). The `⊂` notation is used broadly here to indicate that properties/rules should be inherited.
5.  **Orthogonal Concepts:** Some domains like `Type`, `Effect`, `Complexity`, or `MemoryLayout` are somewhat orthogonal to the mathematical structures but interact with them. They are grouped logically.
6.  **Purpose:** This lattice allows Orbit to automatically apply general mathematical laws (like commutativity via `S₂` defined for `AbelianGroup`) to specific computational types (like Orbit's `Int` or `Double`) once the connection (`Int ⊂ Ring ⊂ AbelianGroup`) is established. It also enables cross-domain rule application where structures are isomorphic (e.g., `ℤ/nℤ` addition and `Cₙ`).

This unified structure allows the Orbit system to reason about expressions from diverse sources within a single, coherent framework, maximizing code reuse for rewrite rules and enabling powerful cross-domain optimizations based on shared underlying mathematical principles.

## Aligning Orbit's Domain Hierarchy with Lean/Mathlib

To facilitate verification of Orbit transformations by Lean and the potential use of Lean theorems as Orbit rewrite rules, the **mathematical structure** part of Orbit's domain hierarchy closely mirror the type class hierarchy used in Mathlib.

**Alignment Principles:**

1.  **Mirror Algebraic Structures:** Orbit domains representing standard algebraic structures (`Semigroup`, `Monoid`, `Group`, `Ring`, `Field`, `VectorSpace`, `Lattice`, etc.) should directly correspond to Mathlib's type classes (`semigroup`, `monoid`, `group`, `ring`, `field`, `vector_space`, `lattice`). The naming is consistent where possible.
2.  **Use `⊂` for Inheritance:** Orbit's subset relation (`⊂`) between domains should mirror Mathlib's type class inheritance (`extends`). For example, since `ring` extends `add_comm_group` and `monoid` in Lean, Orbit should have `Ring ⊂ AbelianGroup` and `Ring ⊂ Monoid`. TODO: Should we use extends as well?
3.  **Map Concrete Types:** Create Orbit domains for base types corresponding to Lean's types (`Int` for `ℤ`, `Real` for `ℝ`, `Rat` for `ℚ`, `Nat` for `ℕ`, `Bool` for `bool`). The `⊂` relationships should reflect Lean's coercions or instance relationships (e.g., `Int ⊂ Rat ⊂ Real`).
4.  **Axioms vs. Properties:**
	*   **Lean:** Defines structures via axioms (e.g., `add_comm : ∀ a b : G, a + b = b + a` within `add_comm_group`). Theorems are proven from these axioms.
	*   **Orbit:** Can represent these properties using specific domains or annotations on operators. For interoperability:
		*   Lean theorems (`lhs = rhs`) can translate to Orbit rewrite rules (`lhs ↔ rhs`).
		*   Orbit transformations (`e1 → e2`) need to generate Lean proof goals (`e1 = e2`) within the appropriate algebraic context (e.g., `variables [ring R] (a b c : R) ... prove (a * (b + c) = a * b + a * c)`).
5.  **Symmetry Groups:** Orbit's explicit symmetry groups (`S₂`, `Cₙ`, etc.) used for canonicalisation relate to Mathlib's axioms. For instance, if an Orbit domain `MyDomain` inherits from `AbelianGroup`, an Orbit rule like `a:MyDomain + b:MyDomain ⊢ + : S₂` establishes the link. This means Orbit's `S₂` canonicalisation rule for `+` is justified by the `add_comm` axiom proven for `AbelianGroup` in Lean.

**Verification Workflow Example:**

1.  **Orbit Transformation:** Orbit applies a rule `a * (b + c) → (a * b) + (a * c)` because the node for the expression has the `Ring` domain.
2.  **Generate Lean Goal:** Orbit outputs a verification goal for Lean:

```lean
	import Mathlib.Algebra.Ring.Defs

	theorem orbit_step_123 {R : Type*} [ring R] (a b c : R) :
	  a * (b + c) = a * b + a * c := by
	  -- Goal: Prove this equality using ring axioms
	  rw [mul_add] -- Apply the distributivity theorem from Mathlib's ring class
```
3.  **Lean Verification:** Lean attempts to prove the goal using theorems associated with the `ring` type class (like `mul_add`). If successful, the Orbit step is verified.
4.  **Lean Rule to Orbit:** A Lean theorem `theorem add_comm_nat : ∀ n m : ℕ, n + m = m + n := ...` can be translated into an Orbit rule `n:Nat + m:Nat ↔ m:Nat + n:Nat`.

This alignment ensures that the core algebraic reasoning in Orbit is grounded in structures that have rigorous definitions and proven properties in Mathlib, enabling a robust bridge for verification and rule exchange.
