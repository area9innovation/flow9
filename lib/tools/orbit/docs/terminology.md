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
*   **Numbers:** `Integer`, `Int(32)`, `Rational`, `Real`, `Double`, `Complex`, `Numeric`.
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

To enable a unified system where rules and properties can be inherited and shared, we can structure the identified domains into a conceptual lattice or hierarchy. This hierarchy uses the subset relation (`⊂`) to denote that elements of a subdomain also belong to the superdomain, allowing rules defined for broader categories (like `Ring`) to apply to more specific instances (like `Integer` or `Int(32)`).

```orbit
```orbit
Top (Most General Domain)
 ├── ComputationalObject
 │   ├── DataStructure
 │   │   ├── Sequence(T)
 │   │   │   ├── Array(T, Size)
 │   │   │   ├── List(T)
 │   │   │   └── String // Sequence(Character)
 │   │   ├── Map(K, V) // Dictionary
 │   │   ├── Set(T)
 │   │   ├── Bag(T) // Multiset
 │   │   ├── Tree(K, V)
 │   │   │   ├── BinaryTree(K, V)
 │   │   │   └── Trie(K, V)
 │   │   └── Graph(Node, Edge)
 │   │       ├── DirectedGraph(Node, Edge)
 │   │       └── UndirectedGraph(Node, Edge)
 │   └── ExpressionAST // Abstract Syntax Tree
 │       ├── OrbitExpr // Orbit's own AST
 │       └── MathExpr // Mathematical Notation AST
 │           ├── ArithmeticExpr(Op, Left, Right)
 │           ├── ComparisonExpr(Op, Left, Right)
 │           ├── BoundExpr(Op, Var, Lower, Upper, Body) // For Sum, Integral, Limit
 │           ├── FunctionCallExpr(Name, Args)
 │           └── ValueExpr(Value, Type)
 │
 ├── MathematicalStructure
 │   ├── Algebraic
 │   │   ├── Magma(T) // T, (T, T) -> T
 │   │   │   └── Semigroup(T) // Associative Magma
 │   │   │       └── Monoid(T) // Semigroup with IdentityElement(T)
 │   │   │           └── Group(T) // Monoid with Inverse(T)
 │   │   │               ├── AbelianGroup(T) // Commutative Group (implies S₂ for operation)
 │   │   │               │   └── CyclicGroup(N) // Generated by one element, N is order
 │   │   │               │       └── IntegersModN(N) // ≅ CyclicGroup(N)
 │   │   │               └── NonAbelianGroup(T) // Specific instances
 │   │   │                   ├── SymmetricGroup(N) // Permutations of N elements, Sₙ
 │   │   │                   ├── AlternatingGroup(N) ⊂ SymmetricGroup(N) // Aₙ
 │   │   │                   ├── DihedralGroup(N) // Symmetries of N-gon
 │   │   │                   ├── MatrixGroup(T, N, Field) // Family of Groups
 │   │   │                   │   ├── GeneralLinearGroup(N, Field) // GL(N, F)
 │   │   │                   │   │   └── SpecialLinearGroup(N, Field) ⊂ GeneralLinearGroup(N, Field) // SL(N, F), det=1
 │   │   │                   │   └── OrthogonalGroup(N, Field) ⊂ GeneralLinearGroup(N, Field) // O(N, F), MᵀM = I
 │   │   │                   └── QuaternionGroup // Q₈
 │   ├── RingLikeStructure(T) // Two Operations: AdditiveOp, MultiplicativeOp
 │   │   ├── Semiring(T) // Additive:Monoid(T), Multiplicative:Monoid(T), Distributivity
 │   │   │   └── Ring(T) // Additive:AbelianGroup(T)
 │   │   │       ├── CommutativeRing(T) // MultiplicativeOp is Commutative
 │   │   │       │   ├── Field(T) // MultiplicativeInverse for non-zero elements
 │   │   │       │   │   ├── Rational // ℚ Instance of Field(RationalNumber)
 │   │   │       │   │   ├── Real // ℝ Instance of Field(RealNumber)
 │   │   │       │   │   │   └── PositiveReal ⊂ Real
 │   │   │       │   │   └── Complex // ℂ Instance of Field(ComplexNumber)
 │   │   │       │   ├── Integer // ℤ Instance of CommutativeRing(MathematicalInteger)
 │   │   │       │   │   ├── Nat // ℕ Natural numbers (0, 1, 2...)
 │   │   │       │   │   └── Int(Wp1) // Signed integer, Wp1 = W_unsigned + 1 bits, Finite Integer Ring Z/2ⁿZ
 │   │   │       │   │       └── UInt(W) // Unsigned W-bit integer
 │   │   │       │   └── PolynomialRing(CoeffRing, VarSymbol)
 │   │   │       │       └── Ideal(PolynomialRing, Generators)
 │   │   │       └── NonCommutativeRing(T) // E.g., MatrixRing(T,N)
 │   │   ├── BooleanAlgebra(T) // Also a DistributiveLattice(T)
 │   ├── ModuleStructure(T, R_Ring) // Module M over Ring R
 │   │   └── VectorSpace(T, F_Field) // Module where Ring is a Field
 │   │       ├── Vector(T, N) // Element of VectorSpace, N dimensions
 │   │       └── Tensor(T, Dims) // Base for multi-dimensional arrays, Dims is list of dimensions
 │   │           └── Matrix(T, N, M) // Tensor(T, [N,M])
 │   │               └── SquareMatrix(T, N) // Matrix(T, N, N)
 │   │                   ├── DiagonalMatrix(T, N)
 │   │                   │   ├── ScalarMatrix(T, N) // Diagonal with all entries equal
 │   │                   │   ├── IdentityMatrix(T, N) // ScalarMatrix with diagonal 1
 │   │                   │   ├── DiagonalIdempotentMatrix(T, N) // D^2 = D, diagonal entries 0 or 1
 │   │                   │   └── DiagonalInvolutoryMatrix(T, N) // D^2 = I, diagonal entries ±1
 │   │                   ├── TriangularMatrix(T, N)
 │   │                   │   ├── UpperTriangularMatrix(T, N)
 │   │                   │   └── LowerTriangularMatrix(T, N)
 │   │                   ├── SymmetricMatrix(T, N) // M = Mᵀ
 │   │                   ├── SkewSymmetricMatrix(T, N) // M = -Mᵀ
 │   │                   ├── HermitianMatrix(T, N) // M = Mᴴ (Complex T)
 │   │                   ├── SkewHermitianMatrix(T, N) // M = -Mᴴ (Complex T)
 │   │                   ├── OrthogonalMatrix(T, N) // QᵀQ = I (Real T)
 │   │                   │   ├── SpecialOrthogonalMatrix(T, N) // det(Q) = 1
 │   │                   │   └── ReflectionMatrix(T, N) // det(Q) = -1
 │   │                   ├── UnitaryMatrix(T, N) // UᴴU = I (Complex T)
 │   │                   │   └── SpecialUnitaryMatrix(T, N) // det(U) = 1
 │   │                   ├── NormalMatrix(T, N) // AᴴA = AAᴴ
 │   │                   ├── NilpotentMatrix(T, N, K_Nilpotency) // A^K = 0
 │   │                   ├── IdempotentMatrix(T, N) // A^2 = A (general projection)
 │   │                   │   └── OrthogonalProjectorMatrix(T, N) // Idempotent & Symmetric/Hermitian
 │   │                   ├── InvolutoryMatrix(T, N) // A^2 = I
 │   │                   ├── PermutationMatrix(N) // SquareMatrix(Integer, N) with 0s/1s, one 1 per row/col
 │   │                   ├── MonomialMatrix(T, N) // One non-zero per row/col
 │   │                   ├── BandedMatrix(T, N, LowerBW, UpperBW)
 │   │                   │   └── TridiagonalMatrix(T, N) // BandedMatrix(T,N,1,1)
 │   │                   ├── ToeplitzMatrix(T, N) // Constant diagonals
 │   │                   ├── HankelMatrix(T, N) // Constant anti-diagonals
 │   │                   ├── CirculantMatrix(T, N) // Each row is cyclic shift of above
 │   │                   ├── HadamardMatrix(N) // SquareMatrix(Integer,N) entries ±1, HHᵀ = NI
 │   │                   └── CompanionMatrix(T, N) // For characteristic polynomial
 │   │                   ├── StochasticMatrix(T, N, M) // Non-negative, rows or cols sum to 1
 │   │                   │   └── DoublyStochasticMatrix(T, N) // Rows & cols sum to 1
 │   │                   ├── SparseMatrix(T, N, M, Format)
 │   │                   ├── LowRankMatrix(T, N, M, K_Rank)
 │   │                   │   └── RankOneMatrix(T, N, M) // LowRankMatrix with K_Rank=1
 │   │                   ├── EmbeddingMatrix(T, VocabSize, EmbedDim)
 │   │                   └── VandermondeMatrix(T, N, M)
 │   ├── OrderStructure(T)
 │   │   ├── PartialOrder(T)
 │   │   │   └── Lattice(T) // Has LUB (join ∨) & GLB (meet ∧)
 │   │   │       └── DistributiveLattice(T)
 │   ├── TopologicalStructure(T)
 │   │   ├── TopologicalSpace(T)
 │   │   │   └── MetricSpace(T, DistanceFunc)
 │   ├── CalculusFramework // Operations act on Fields mostly
 │   │   ├── DifferentialCalculus
 │   │   ├── IntegralCalculus
 │   │   └── TensorCalculus
 │   ├── ProbabilityTheory
 │   │   ├── DomainSpace // Sample Space type (e.g. DiscreteSpace, ContinuousSpace)
 │   │   ├── Distribution(T_Outcome, DS_DomainSpace) // Base for probability distributions
 │   │   │   ├── DiscreteDistribution(T_Outcome) // Distribution(T_Outcome, DiscreteSpace)
 │   │   │   │   ├── Bernoulli(P_Prob) // T_Outcome=Integer (0 or 1)
 │   │   │   │   ├── Binomial(N_Trials, P_Prob) // T_Outcome=Integer
 │   │   │   │   ├── Categorical(Probs_Vector) // T_Outcome=Integer (index)
 │   │   │   │   ├── Geometric(P_Prob) // T_Outcome=Integer
 │   │   │   │   ├── NegativeBinomial(R_Successes, P_Prob) // T_Outcome=Integer
 │   │   │   │   ├── Poisson(Lambda_Rate) // T_Outcome=Integer
 │   │   │   │   └── UniformDiscrete(A_Min, B_Max) // T_Outcome=Integer
 │   │   │   └── ContinuousDistribution(T_Outcome) // Distribution(T_Outcome, ContinuousSpace)
 │   │   │       ├── UniformContinuous(A_Min, B_Max) // T_Outcome=Real
 │   │   │       ├── Normal(Mu_Mean, SigmaSq_Variance) // T_Outcome=Real
 │   │   │       ├── LogNormal(Mu_Log, SigmaSq_Log) // T_Outcome=Real
 │   │   │       ├── Exponential(Lambda_Rate) // T_Outcome=Real
 │   │   │       ├── Gamma(Alpha_Shape, Beta_Rate) // T_Outcome=Real
 │   │   │       ├── ChiSquared(K_DF) // T_Outcome=Real, K_DF is Integer
 │   │   │       ├── Beta(Alpha_Shape, Beta_Shape) // T_Outcome=Real (on [0,1])
 │   │   │       ├── StudentT(Nu_DF) // T_Outcome=Real
 │   │   │       ├── Cauchy(X0_Location, Gamma_Scale) // T_Outcome=Real
 │   │   │       └── Laplace(Mu_Location, B_Scale) // T_Outcome=Real
 │   │   └── MultivariateDistribution(T_OutcomeVector, DS_DomainSpace)
 │   │       ├── Multinomial(N_Trials, Probs_Vector) // T_OutcomeVector=Vector(Integer)
 │   │       ├── Dirichlet(Alphas_Vector) // T_OutcomeVector=Vector(Real)
 │   │       ├── MultivariateNormal(Mean_Vector, Cov_Matrix) // T_OutcomeVector=Vector(Real)
 │   │       ├── Wishart(Scale_Matrix, Nu_DF) // T_OutcomeVector=Matrix(Real)
 │   │       └── InverseWishart(Psi_ScaleMatrix, Nu_DF) // T_OutcomeVector=Matrix(Real)
 │   ├── FunctionSpace(DomainT, CodomainT)
 │   │   ├── LpSpace(P_Exponent, MeasureSpace)
 │   │   └── SobolevSpace(S_Smoothness, P_Exponent, DomainRegion)
 │
 ├── VerificationFramework // For Estimate Verification
 │   ├── VerificationTask(GoalEstimate, AssumptionsList)
 │   ├── Estimate(LHS, RelOp, RHS) // RelOp: ApproxLE, LE, Equal etc.
 │   │   ├── AsymptoticEstimate(LHS, RelOp, RHS, Var, LimitPoint)
 │   │   │   ├── ApproxLE // A ≲ B
 │   │   │   ├── ApproxGE // A ≳ B
 │   │   │   └── ApproxEq // A ∼ B
 │   │   └── ConcreteEstimate(LHS, RelOp, RHS)
 │   │       ├── LE // A ≤ B
 │   │       ├── GE // A ≥ B
 │   │       └── Equal // A = B
 │   ├── Assumption(Estimate)
 │   └── VerificationResult
 │       ├── TrueEstimate(Proof)
 │       └── FalseEstimate(CounterExample)
 │
 ├── ChemistryDomain
 │   ├── MolecularCompound(FormulaString)
 │   │   ├── MolecularGraph(Atoms, Bonds)
 │   │   ├── OrganicCompound
 │   │   │   ├── Hydrocarbon(Formula)
 │   │   │   │   ├── Alkane(NumCarbons)
 │   │   │   │   ├── Alkene(NumCarbons, DoubleBondPositions)
 │   │   │   │   ├── Alkyne(NumCarbons, TripleBondPositions)
 │   │   │   │   └── Arene(RingSystems)
 │   │   │   ├── FunctionalGroupCompound(BaseSkeleton, GroupsList) // General form
 │   │   │   ├── Alcohol(R)
 │   │   │   │   ├── PrimaryAlcohol(R)
 │   │   │   │   ├── SecondaryAlcohol(R1, R2)
 │   │   │   │   ├── TertiaryAlcohol(R1, R2, R3)
 │   │   │   │   └── Diol(R, Pos1, Pos2)
 │   │   │   ├── Ether(R1, R2)
 │   │   │   ├── Aldehyde(R)
 │   │   │   ├── Ketone(R1, R2)
 │   │   │   ├── CarboxylicAcid(R)
 │   │   │   ├── Ester(R_Acid, R_Alcohol)
 │   │   │   ├── Amide(R_Acid, N_Substituents)
 │   │   │   └── Amine(N_Substituents)
 │   ├── ChemicalReaction(Reactants, Products, Conditions)
 │   │   ├── BalancedReaction
 │   │   ├── ReactionType // Oxidation, Reduction, Esterification etc.
 │   ├── PointGroup(Symbol) // E.g. C₁, Cₙ(N), Dₙ(N), Tᵈ, Oₕ
 │   │   ├── C₁(N)
 │   │   ├── Cₙᵥ(N, VPlanes)
 │   │   ├── Dₙₕ(N, HPlane)
 │   │   ├── Tᵈ
 │   │   └── Oₕ
 │   └── StereochemistryDescriptor
 │       ├── StereoCenterConfig(AtomId, Configuration) // Configuration: R_Config, S_Config
 │       └── DoubleBondConfig(BondId, Configuration) // Configuration: E_Config, Z_Config
 │
 ├── ProgrammingConstruct
 │   ├── Type(Name, Parameters)
 │   │   ├── PrimitiveType(Name) // e.g. Integer, Real, Boolean, String
 │   │   ├── CompositeType(Constructor, TypeArgs) // e.g. List(T), Map(K,V)
 │   │   ├── FunctionType(ArgTypes, ReturnType)
 │   │   └── OrbitType // Orbit's internal types (Int, Double etc.)
 │   ├── Effect(Name)
 │   │   ├── Pure
 │   │   ├── State(StateType, AccessMode) // AccessMode: Read, Write
 │   │   ├── IO(Device, Operation)
 │   │   └── Exception(ExceptionType)
 │   ├── ConcurrencyConstruct
 │   │   ├── Process(PID)
 │   │   ├── Channel(T_DataType)
 │   │   └── SynchronizationPrimitive(Type) // Lock, Semaphore, Barrier
 │   ├── ControlFlowConstruct // If, Loop, Match
 │   ├── Module(Name, Exports, Imports)
 │   └── MemoryLayoutHint // AoS, SoA, RowMajor, ColMajor
 │
 ├── AnalysisProperty
 │   ├── SemanticProperty(Operator, PropertyName) // Associative, Commutative, Idempotent
 │   ├── ComplexityMeasure(Algorithm, Resource) // Resource: Time, Space, Energy
 │   │   ├── AsymptoticBound(FunctionClass) // O(N), Theta(NLogN), Omega(1)
 │   │   └── CostModel(MachineModel) // RAMModel, BitCostModel
 │   ├── NumericalProperty
 │   │   ├── Precision(NumBits)
 │   │   ├── ErrorBound(Type) // AbsoluteError, RelativeError
 │   │   ├── StabilityCondition
 │   │   └── ConditionNumber(Matrix)
 │   ├── VerificationProperty // Correctness, Termination, Soundness, Completeness
 │   ├── DependencyTracking
 │   │   ├── DependsOn(Parameter)
 │   │   ├── IndependentOf(Parameter)
 │   │   ├── ParameterSymbol(Name)
 │   │   └── AbsoluteConstant
 │   └── RewritingControlDirective
 │       ├── CaseContext(AssumptionsList)
 │       ├── HeuristicFlag(Name) // e.g. SufficientlyLarge(N)
 │       └── StrategyAnnotation(StrategyName) // e.g. LogTransformStrategy
 │
 ├── FormalSystem
 │   ├── LogicSystem(Name) // PropositionalLogic, PredicateLogic(Order)
 │   ├── FormalLanguage(Alphabet, Grammar)
 │   │   └── RegularLanguage // Generated by Regex or DFA/NFA
 │   └── CategoryTheoryConstruct(Name) // Functor, Monad, NaturalTransformation
 │
 └── ApplicationDomain(Name)
		 ├── SignalProcessing // DFT, FFT, WaveletTransform
		 ├── Cryptography // HE_Scheme(Params), PKC_Scheme(Keys)
		 ├── PhysicsSimulation // NBodySystem(Particles), PDE_System(Equation, BC)
		 ├── ComputerGraphics // SceneGraph, TransformationMatrix(Type)
		 ├── ConstraintSatisfactionProblem(Variables, Constraints)
		 └── MachineLearningModel(Architecture, Weights)
```

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
