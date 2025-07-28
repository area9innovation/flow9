# Inferring Semantic Properties as Domains in Orbit

## Introduction

Beyond type inference, Orbit's domain-based rewriting system can be used to infer deeper *semantic properties* of functions and operations. By analyzing the structure and components of expressions, we can associate them with domains representing properties like `Associative`, `Commutative`, `Invertible`, or `Idempotent`.

This document describes how we infer and propagate semantic properties through expressions, enabling optimizations, verification, and transformations.

## Defining Semantic Property Domains

We define domains to represent semantic properties that can be inferred and propagated.

```orbit
// Symmetry groups and algebraic properties
S₂ ⊂ SymmetryGroup;     // Symmetric group of order 2 (commutativity)
Associative ⊂ Property;
Distributive ⊂ Property;
Idempotent ⊂ Property;

// Invertibility properties
Invertible ⊂ Property;      // Operation has an inverse
InvertibleIf(cond) ⊂ Property;  // Conditional invertibility

// Numeric domains
Int32 ⊂ Integer ⊂ Rational ⊂ Real ⊂ Complex;
```

## Inferring Properties via Pattern Matching

We use direct pattern matching and the entailment operator (⊢) to identify operations and infer their properties.

### 1. Properties of Basic Arithmetic Operations

```orbit
// Addition has symmetry group S₂ (commutativity) for all numeric domains
a : Numeric + b : Numeric ⊢ + : S₂;

// Addition is associative for all numeric domains
a : Numeric + b : Numeric ⊢ + : Associative;

// Multiplication has symmetry group S₂ (commutativity) for all numeric domains
a : Numeric * b : Numeric ⊢ * : S₂;

// Multiplication is associative for all numeric domains
a : Numeric * b : Numeric ⊢ * : Associative;

// Multiplication distributes over addition
a : Numeric * (b : Numeric + c : Numeric) ⊢ * : Distributive;
```

### 2. Int32-Specific Rules

```orbit
// Int32 addition has well-defined overflow behavior
a : Int32 + b : Int32 => (a + b) : Int32 : WrappingOverflow;

// Int32 multiplication has well-defined overflow behavior
a : Int32 * b : Int32 => (a * b) : Int32 : WrappingOverflow;

// Int32 division is only defined when the divisor is not zero
a : Int32 / b : Int32 => (a / b) : Int32 : PartialFunction if b != 0;

// Int32 modulo is only defined when the divisor is not zero
a : Int32 % b : Int32 => (a % b) : Int32 : PartialFunction if b != 0;
```

### 3. Propagating Properties (Bubbling Up)

A key insight is that properties can bubble up from subexpressions to their parents:

```orbit
// Operations composed of associative operations maintain associativity. todo: use unicode compose syntax
compose(f : Associative, g : Associative) ⊢ compose(f, g) : Associative;
```

### 4. Inverse Operations With Constraints

```orbit
// Addition is always invertible - inverse is subtraction
a : Numeric + b : Numeric ⊢ (a + b) : Invertible;

// Multiplication is invertible only when both operands are non-zero
a : Numeric * b : Numeric ⊢ (a * b) : Invertible if a != 0 && b != 0;

// Division is invertible only when the dividend is non-zero
a : Numeric / b : Numeric ⊢ (a / b) : Invertible if a != 0;

// Exponentiation is invertible under specific conditions
a : Numeric ^ b : Numeric ⊢ (a ^ b) : Invertible if a > 0;
```

## Benefits of Property Inference and Bubbling

This approach to property inference enables:

* **Compositional Reasoning:** Properties of complex expressions are derived from properties of their components
* **Targeted Optimizations:** Apply transformations only when required properties are present
* **Provable Correctness:** Verify that transformations preserve semantics
* **Domain-Specific Rules:** Different behaviors for different numeric domains (Int32 vs. Real)
* **Conditional Transformations:** Apply optimizations only when conditions are met (e.g., non-zero divisors)

## Examples with Int32 Domain

```orbit
// Int32-specific distributivity with overflow awareness
(a : Int32 * (b : Int32 + c : Int32)) : WrappingOverflow <=>
	((a : Int32 * b : Int32) + (a : Int32 * c : Int32)) : WrappingOverflow;

// Int32 addition commutativity
a : Int32 + b : Int32 ⊢ + : S₂;

// Int32 multiplication by 0 simplification
a : Int32 * 0 : Int32 => 0 : Int32;

// Int32 multiplication by powers of 2 can be replaced by shifts
a : Int32 * 2 : Int32 => a << 1 : Int32;
a : Int32 * 4 : Int32 => a << 2 : Int32;
a : Int32 * 8 : Int32 => a << 3 : Int32;
```
## Computational Complexity Analysis

Orbit's domain-based system provides a comprehensive framework for automated computational complexity analysis. By combining recurrence-based analysis with amortized potential methods, it can derive precise time complexity bounds for a wide range of functional programs.

### 1. Size Metrics

Each value is associated with a concrete size metric in the natural numbers:

```orbit
// Lists/Linked Sequences
s([]) => 0;
s(x::xs) => 1 + s(xs);

// Arrays/Strings
s(array) => |array|;
s(string) => length(string);

// Trees and Graphs
s(tree) => node_count(tree);
s(graph) => |V| + |E|;  // Vertices + Edges
```

These size metrics yield input variables (n, m, ...) for cost expressions.

### 2. Cost and Potential Domains

#### 2.1 Cost Domain

Each AST e-class carries a cost annotation representing its time complexity:

```orbit
// Cost domain
e : Cost(O(P(n₁, ..., nₖ)));
```

where P is a polynomial in terms of input sizes n₁ through nₖ.

#### 2.2 Potential Domain

For amortized analysis, we introduce a potential domain that assigns credits to data structures:

```orbit
// Potential domain for amortized analysis
e : Pot(Φ(n));
```

where Φ(n) is a function mapping size to potential credits that can be used to pay for future operations.

### 3. Primitive and Library Cost Annotations

#### 3.1 Primitives

```orbit
// Basic operations have constant time complexity
C(x + y) => O(1);
C(x * y) => O(1);
C(a[i]) => O(1);
C(cons(x, xs)) => O(1);
```

#### 3.2 Higher-Order Functions

For collection size n = s(xs), and cost constants for functions:

```orbit
C(map(f, xs)) => O(n · c_f + n);
C(filter(p, xs)) => O(n · c_p + n);
C(fold(op, z, xs)) => O(n · c_op + n);
```

### 4. Composite Expression Rules

#### 4.1 Sequential Composition
```orbit
C(e₁; e₂) => C(e₁) + C(e₂);
```

#### 4.2 Let-Binding
```orbit
C(let x = e₁; e₂) => C(e₁) + C(e₂);
```

#### 4.3 Conditionals
```orbit
C(if(c, t, e)) => O(1) + max(C(t), C(e));
```

#### 4.4 Multi-Parameter Functions

For functions with multiple collection arguments, complexity depends on all their sizes:

```orbit
// For f: (A₁, ..., Aₖ) -> Result with sizes nᵢ = s(Aᵢ)
C(f(A₁, ..., Aₖ)) => O(P(n₁, ..., nₖ)) + sum(C(A₁), ..., C(Aₖ));
```

Example: 
```orbit
// Linear merge on two arrays with sizes n = s(A), m = s(B)
C(merge(A, B)) => O(n + m);
```

### 5. Recurrence Extraction and Control-Flow Refinement

#### 5.1 Extraction

For recursive definitions, we extract recurrence relations:

```orbit
// For recursive definition: f(p) = ... f(α(p)) ...
// Generate recurrence: T_f(n) = C_body(n) + ∑ᵢ T_f(nᵢ)
// where nᵢ = s(α(p))
```

#### 5.2 Refinement

Controlling recurrences with pattern-match guards:

```orbit
// Example: Divide-and-conquer with base case
T(n) => {
	O(1),           if n < 2;  // Base case
	2*T(n/2) + O(n), otherwise;  // Recursive case
};
```

#### 5.3 Solving

Applying master theorem or other solvers to obtain closed-form:

```orbit
// Divide-and-conquer recurrence
T(n) = 2T(n/2) + O(n) => O(n log n);

// Example: Merge-sort
C(mergeSort(xs)) => O(n log n);  // where n = s(xs)
```

### 6. Amortized-Potential Analysis

#### 6.1 Potential Seeding

Assigning potential to data structures:

```orbit
// Empty list has zero potential
Φ([]) => 0;

// Cons node carries 'a' credits
Φ(x::xs) => Φ(xs) + a;
```

#### 6.2 Potential Consumption

Enforcing invariants between potential and actual cost:

```orbit
// For operations consuming an element:
operation(xs) : {
	Cost(C_actual),
	Constraint(Φ(n) ≥ C_actual + Φ(n-1))
};
```

#### 6.3 Examples

```orbit
// Dynamic array with amortized O(1) push
dynamicArrayPush(arr, x) : {
	AmortizedCost(O(1)),
	ActualCost(O(n)),      // Occasional resize cost
	Pot(Φ(n) = n)          // Linear potential function
};

// Union-find with path compression
unionFind.union(x, y) : {
	AmortizedCost(O(α(n))), // α is inverse Ackermann
	Pot(Φ(n) = n·log(n))   // Potential for path compression
};
```

### 7. Cost and Potential Simplification

Rewrite rules applied until fixed point:

```orbit
// Idempotence
O(f) + O(f) => O(f);

// Dominance of max
O(f) + O(g) => O(max(f, g));

// Absorb constants
O(1) + O(f) => O(f);

// Multiplicative collapse
O(f) · O(g) => O(f·g);
c · O(f) => O(f);  // for constant c

// Potential-Cost relationship
Φ(n) ≥ C(n) => Amortized(C(n));
```

### 8. Analysis Examples

Orbit's complexity analysis framework applies to a wide range of algorithms:

#### 8.1 Basic Collection Processing

```orbit
// Single-pass scans - O(n)
C(sum(xs)) => O(n);         // where n = s(xs)
C(length(xs)) => O(n);      // where n = s(xs)
C(findMax(xs)) => O(n);     // where n = s(xs)

// Fixed-arity recursion
// Tail-recursive list reversal
C(rev(xs, acc)) => O(n);    // where n = s(xs)

// Naive Fibonacci: F(n) = F(n-1) + F(n-2)
C(fib(n)) => O(φⁿ);         // Exponential complexity with golden ratio φ
```

#### 8.2 Divide-and-Conquer Algorithms

```orbit
C(binarySearch(xs, key)) => O(log n);  // where n = s(xs)
C(mergeSort(xs)) => O(n log n);        // where n = s(xs)
C(quickSelect(xs, k)) => O(n);         // Average case, O(n²) worst case
```

#### 8.3 Matrix and Graph Algorithms

```orbit
C(matrixAdd(A, B)) => O(n²);           // for n×n matrices
C(matrixMultiply(A, B)) => O(n³);      // Naive implementation

C(bfs(graph)) => O(|V| + |E|);         // Breadth-first search
C(dijkstra(graph, source)) => O((|V| + |E|) log |V|);  // With binary heap
C(bellmanFord(graph, source)) => O(|V|·|E|);
```

#### 8.4 Advanced and Non-Polynomial Algorithms

```orbit
// Dynamic programming
C(knapsack(items, capacity)) => O(n·W);  // n items, capacity W
C(lcs(s1, s2)) => O(n·m);              // Longest common subsequence

// Advanced transforms
C(fft(xs)) => O(n log n);              // Fast Fourier Transform
C(strassenMultiply(A, B)) => O(n^2.81);  // Strassen's matrix multiply

// Non-polynomial algorithms
C(tspBruteForce(graph)) => O(n!);         // Traveling Salesman Problem
C(subsetSumNaive(nums, target)) => O(2ⁿ);  // Subset Sum Problem
```

### 9. Advanced Features for Future Integration

The Orbit system is designed to accommodate more sophisticated complexity analysis features:

```orbit
// Distinguishing average vs. worst-case
C(quicksort(xs)) => {
	Average(O(n log n)),
	Worst(O(n²))
};

// Randomized algorithms with probabilistic bounds
C(randomizedMINSAT(formula)) => {
	Expected(O(n * log n)),
	HighProbability(0.99, O(n * log n))
};

// Space complexity annotations
C(mergeSort(xs)) => {
	Time(O(n log n)),
	Space(O(n))
};

// Memory hierarchy and parallel processing
C(matrixMultiply(A, B)) => {
	CPU(O(n³)),
	CacheMisses(O(n³/B)),  // B = cache line size
	WorkComplexity(O(n³)),
	SpanComplexity(O(n)) with WorkerCount(p)
};
```

### 10. Analysis Workflow

The complete workflow for automated complexity analysis in Orbit follows these steps:

1. Parse program AST into O-Graph
2. Tag all e-classes with Cost and Pot domains
3. Annotate primitives and library functions with base costs
4. Infer composite costs using the rules in Sections 3-4
5. Seed and consume potentials for amortized analysis
6. Extract and refine recurrences for recursive functions
7. Solve recurrences and simplify annotations
8. Query final annotation C(e) to obtain precise complexity bounds

This unified approach combines recurrence-based and amortized analysis in one framework, allowing for precise complexity characterization of functional programs.

## Static Single Assignment Form and Rewriting

Static Single Assignment (SSA) form is a fundamental intermediate representation in compilers, where each variable is assigned exactly once and every use refers to a single definition. This section explores how dominator analysis, SSA conversion, and SSA-based optimizations can be expressed through Orbit's rewriting system.

### 1. Dominator Analysis as a Rewrite System

The dominator relationship is a key property for control flow analysis: a node d dominates node n if every path from the program entry to n must pass through d. Computing this relationship is essential for SSA construction.

#### 1.1 Control Flow Graph Domain

```orbit
// Define domains for CFG elements
CFGNode ⊂ Term;
EntryNode ⊂ CFGNode;
RegularNode ⊂ CFGNode;
ExitNode ⊂ CFGNode;

// Edge representation
Edge(from : CFGNode, to : CFGNode) ⊂ Term;

// Dominance relation (node d dominates node n)
Dominates(d : CFGNode, n : CFGNode) ⊂ Property;
```

#### 1.2 Dominance Computation Rules

The standard iterative dominance algorithm can be elegantly expressed as a set of rewrite rules:

```orbit
// Initialization: Every node dominates itself
n : CFGNode ⊢ Dominates(n, n);

// Entry node dominates all nodes
entry : EntryNode, n : CFGNode ⊢ Dominates(entry, n);

// Core dominance computation rule:
// Node d dominates n if it dominates all predecessors of n
d : CFGNode, n : CFGNode !: EntryNode,
∀p.(Edge(p, n) ⊢ Dominates(d, p)) ⊢ Dominates(d, n);
```

These three rules capture the essence of the iterative dominance algorithm, computing the complete dominance relation through repeated application until reaching a fixed point.

#### 1.3 Immediate Dominators

For SSA construction, we need immediate dominators - the closest dominator of each node:

```orbit
// Immediate dominator relation
ImmediateDominator(d : CFGNode, n : CFGNode) ⊂ Property;

// A node d is the immediate dominator of n if:
// 1. d dominates n
// 2. d ≠ n
// 3. Any other dominator of n also dominates d
d : CFGNode, n : CFGNode !: EntryNode,
Dominates(d, n), d ≠ n,
∀x.(Dominates(x, n) ∧ x ≠ n ⊢ Dominates(x, d)) ⊢
ImmediateDominator(d, n);
```

#### 1.4 Dominance Frontier

The dominance frontier is crucial for inserting φ-functions during SSA construction:

```orbit
// Dominance frontier relation
DominanceFrontier(n : CFGNode, f : CFGNode) ⊂ Property;

// Node f is in the dominance frontier of n if:
// 1. n dominates a predecessor of f
// 2. n does not strictly dominate f
n : CFGNode, f : CFGNode, p : CFGNode,
Edge(p, f), Dominates(n, p), !Dominates(n, f) ⊢
DominanceFrontier(n, f);
```

By applying these rewrite rules repeatedly, we build a complete dominance analysis framework within the Orbit system, using its native rewriting capabilities.

### 2. Converting To/From SSA Form

SSA form requires that each variable has exactly one definition, with φ-functions at control flow join points to merge values from different paths.

#### 2.1 SSA Domains

```orbit
// Define domains for SSA
SSAVar ⊂ Term;           // SSA variable (with unique version)
SSADef ⊂ Term;           // Definition of an SSA variable
SSAPhi ⊂ SSADef;         // Phi function definition
NonSSA ⊂ Term;           // Non-SSA form expression
InSSA ⊂ Term;            // Expression converted to SSA form
```

#### 2.2 Converting to SSA Form

SSA conversion happens in three main phases, each expressible as rewrite rules:

##### Phase 1: Variable Versioning

```orbit
// Create a unique version for each definition
assign(x, expr) : NonSSA !: Processed ⊢
	assign(x_i, expr) : InSSA : Processed;

// Track variable versions
x_i : SSAVar, DefSite(x_i, loc) ⊢
	VersionOf(x, i) : Property;
```

##### Phase 2: Phi Function Insertion

```orbit
// Insert phi functions at dominance frontier nodes for each variable
v : Variable, n : CFGNode, f : CFGNode,
Writes(v, n), DominanceFrontier(n, f),
ReachingDefs(v, f, defs) where |defs| > 1 ⊢
	InsertPhi(v, f, defs);

// Create phi node with appropriate arguments
InsertPhi(v, node, [d1, d2, ...]) ⊢
	assign(v_new, phi([v_d1, v_d2, ...])) : SSAPhi;
```

##### Phase 3: Variable Usage Renaming

```orbit
// Rename variable uses to their reaching definitions
use(x) : NonSSA, ReachingDef(x, loc, x_i) ⊢
	use(x_i) : InSSA;

// Update phi function arguments based on control flow
phi([...]) : SSAPhi, BlockPred(block, pred),
ReachingDef(v, pred, v_i) ⊢
	UpdatePhiArg(phi, pred, v_i);
```

#### 2.3 Converting from SSA Form

Converting out of SSA requires eliminating φ-functions:

```orbit
// Convert phi function to explicit moves in predecessor blocks
assign(x_i, phi([v_1, v_2, ...])) : SSAPhi !: Processed ⊢
	[InsertMove(pred_1, x_i, v_1),
	 InsertMove(pred_2, x_i, v_2), ...] : Processed;

// Insert actual move operation at end of predecessor block
InsertMove(block, target, source) ⊢
	BlockEnd(block, assign(target, source));

// After phi elimination, clean up SSA versions
x_i : SSAVar !: Cleaned ⊢ x : NonSSA : Cleaned;
```

This approach handles the elimination of φ-functions by inserting copy operations at the end of predecessor blocks, effectively moving the variable merging from the join point to the incoming paths.

### 3. SSA-Based Optimizations

One of the key advantages of SSA form is how it simplifies many compiler optimizations.

#### 3.1 Constant Propagation

```orbit
// Simple constant propagation
assign(x_i, const(c)) : SSADef, use(x_i) : InSSA ⊢
	use(const(c)) : Optimized;

// Conditional constant folding
if(const(true), thenBlock, elseBlock) : InSSA ⊢
	thenBlock : Optimized;

if(const(false), thenBlock, elseBlock) : InSSA ⊢
	elseBlock : Optimized;
```

#### 3.2 Value Numbering and Common Subexpression Elimination

```orbit
// Local value numbering - identify redundant computations
assign(x_i, expr) : SSADef, assign(y_j, expr) : SSADef,
!Dominates(y_j, x_i) ⊢
	assign(x_i, y_j) : Optimized;

// Global value numbering
assign(x_i, op(args...)) : SSADef, HasValue(args) : ValueNumber(vn) ⊢
	assign(x_i, VN(vn)) : ValueNumbered;

// Replace expressions with same value number
use(x_i) : ValueNumbered(vn), use(y_j) : ValueNumbered(vn) ⊢
	Equivalent(x_i, y_j);
```

#### 3.3 Dead Code Elimination

```orbit
// Remove unused definitions without side effects
assign(x_i, expr) : SSADef !: Used, !HasSideEffects(expr) ⊢
	noop() : Eliminated;

// Mark live variables recursively
use(x_i) : InSSA ⊢ Used(x_i);
assign(x_i, expr), Uses(expr, y_j), Used(x_i) ⊢ Used(y_j);
```

#### 3.4 Loop Invariant Code Motion

```orbit
// Move loop-invariant computations outside loops
assign(x_i, expr) : SSADef, InLoop(x_i, loop),
∀v.(Uses(expr, v) ⊢ LoopInvariant(v, loop)) ⊢
	MoveToLoopPreheader(assign(x_i, expr), loop);

// Mark loop invariants (variables defined outside loop)
assign(x_i, _) : SSADef, !InLoop(assign(x_i, _), loop) ⊢
	LoopInvariant(x_i, loop);

// Constants are loop invariant
const(_) : InSSA ⊢ LoopInvariant(const(_), loop);
```

#### 3.5 Array Bounds Check Elimination

```orbit
// Static array bounds check elimination
assign(i, const(c)) : SSADef, arrAccess(arr, i) : InSSA,
ArrayLength(arr, len), 0 ≤ c < len ⊢
	arrAccess(arr, i) : BoundsCheckEliminated;

// Inductive bounds check elimination for loops
i_0 = const(0),
i_n = phi([i_0, i_m]),
i_m = i_n + const(1),
cond(i_n < len),
arrAccess(arr, i_n) : InSSA,
ArrayLength(arr, len) ⊢
	arrAccess(arr, i_n) : BoundsCheckEliminated;
```

### 4. Example: Optimization Pipeline in SSA Form

To illustrate how these optimizations work together, consider a simple optimization pipeline:

```orbit
// Original code (conceptual):
//   x = 10;
//   y = 20;
//   z = x + y;
//   if (cond) {
//     a = z * 2;
//   } else {
//     a = z;
//   }
//   b = a + z;

// After SSA conversion:
assign(x_1, const(10)) : SSADef;
assign(y_1, const(20)) : SSADef;
assign(z_1, add(x_1, y_1)) : SSADef;
if(cond,
	[assign(a_1, mul(z_1, const(2)))],
	[assign(a_2, z_1)]
);
assign(a_3, phi([a_1, a_2])) : SSAPhi;
assign(b_1, add(a_3, z_1)) : SSADef;

// After constant propagation:
assign(x_1, const(10)) : SSADef;
assign(y_1, const(20)) : SSADef;
assign(z_1, const(30)) : SSADef; // x_1 + y_1 = 30
if(cond,
	[assign(a_1, const(60))],     // z_1 * 2 = 60
	[assign(a_2, const(30))]      // z_1 = 30
);
assign(a_3, phi([const(60), const(30)])) : SSAPhi;
assign(b_1, add(a_3, const(30))) : SSADef;
```

Depending on the value of `cond`, further optimizations are possible. If `cond` is a constant (e.g., from previous optimizations), the conditional can be eliminated, completing the constant folding process:

```orbit
// If cond = true (after conditional elimination):
assign(a_3, const(60));
assign(b_1, const(90));  // a_3 + z_1 = 60 + 30 = 90

// If cond = false:
assign(a_3, const(30));
assign(b_1, const(60));  // a_3 + z_1 = 30 + 30 = 60
```

This example demonstrates how SSA form makes optimizations like constant propagation and dead code elimination more effective and straightforward to implement as rewrite rules.

## Scope Analysis and Closure Conversion

While SSA form is powerful for representing and optimizing variables with unique definitions, functional languages introduce additional complexities with nested scopes, lexical closures, and variable shadowing. This section explores how to extend Orbit's domain system to handle these concepts, using SSA as a foundation.

### 1. Modeling Lexical Scopes and Environments

To properly handle functional programming constructs, we need domain annotations that capture scope relationships and variable environments.

#### 1.1 Scope and Environment Domains

```orbit
// Define domains for scopes and environments
Scope ⊂ Term;              // Lexical scope
ScopeChain ⊂ Term;        // Chain of nested scopes
Env ⊂ Term;               // Variable environment
Closure ⊂ Term;           // Function closure

// Variable classifications
LocalVar ⊂ SSAVar;         // Variable local to current scope
CapturedVar ⊂ SSAVar;      // Variable captured from outer scope
EscapingVar ⊂ SSAVar;      // Variable that escapes its scope (used in inner functions)
```

#### 1.2 Scope Relationships and Nesting

```orbit
// Establish parent-child relationships between scopes
ParentScope(parent : Scope, child : Scope) ⊂ Property;

// Scope contains variable declaration
Declares(scope : Scope, var : SSAVar) ⊂ Property;

// Track variable access in a specific scope
Accesses(scope : Scope, var : SSAVar) ⊂ Property;

// Variable is declared in an ancestor scope
AncestorDeclares(scope : Scope, var : SSAVar) ⊂ Property;
```

### 2. Analyzing Variable Capture and Shadowing

#### 2.1 Detection Rules for Variable Classification

```orbit
// Local variables are declared and used in the same scope
x_i : SSAVar, s : Scope, Declares(s, x_i),
!(∃ childScope. ParentScope(s, childScope) ∧ Accesses(childScope, x_i)) ⊢
	x_i : LocalVar;

// Escaping variables are used in child scopes
x_i : SSAVar, s : Scope, Declares(s, x_i),
(∃ childScope. ParentScope(s, childScope) ∧ Accesses(childScope, x_i)) ⊢
	x_i : EscapingVar;

// Captured variables are accessed from a scope where they aren't declared
x_i : SSAVar, s : Scope, Accesses(s, x_i), !Declares(s, x_i),
(∃ ancestorScope. AncestorDeclares(ancestorScope, x_i)) ⊢
	x_i : CapturedVar;
```

#### 2.2 Shadowing Analysis

```orbit
// Variables shadow others with the same name in ancestor scopes
x_i : SSAVar, y_j : SSAVar, BaseName(x_i) = BaseName(y_j),
s1 : Scope, s2 : Scope, Declares(s1, x_i), Declares(s2, y_j),
AncestorScope(s2, s1) ⊢ Shadows(x_i, y_j);

// Track which version of a shadowed variable to use at each reference point
use(x) : NonSSA, ScopeAt(use(x), s),
VisibleInScope(x_i, s) ⊢ use(x_i) : InSSA;
```

### 3. Closure Conversion and Environment Building

Once we've identified captured variables, we can perform closure conversion to make the environment explicit:

```orbit
// For each function that captures variables, create an explicit environment
f : Function, CapturesVars(f, [v1, v2, ...]) ⊢
	CreateEnv(f, [v1, v2, ...]);

// Convert function to closure with explicit environment
fn(params, body) : Function, env : Env ⊢
	closure(fn(env, params, body'), env) : Closure;

// Transform body to use environment explicitly
use(x_i) : CapturedVar, MemberOf(x_i, env, idx) ⊢
	env_access(env, idx) : InSSA;
```

### 4. Example: Functional Program with Closures and Shadowing

Let's examine a complete example showing how Orbit analyzes and transforms a functional program with nested scopes, shadowing, and closures:

```javascript
// Original functional program
function makeCounter(init) {
	let count = init;          // count_1 in scope_1

	function increment(step) { // scope_2 (parent=scope_1)
		let newCount = count + step;  // newCount_1 in scope_2, captures count_1
		count = newCount;             // updates captured count_1
		return count;
	}

	function reset() {         // scope_3 (parent=scope_1)
		let count = 0;           // count_2 in scope_3, shadows count_1
		return count;            // uses local count_2, not the captured one
	}

	return { increment, reset };
}
```

#### 4.1 Initial Scope and Declaration Analysis

```orbit
// Establish scope structure
s1 : Scope; // makeCounter scope
s2 : Scope; // increment scope
s3 : Scope; // reset scope
ParentScope(s1, s2);
ParentScope(s1, s3);

// Variable declarations in each scope
Declares(s1, init_1);
Declares(s1, count_1);
Declares(s2, step_1);
Declares(s2, newCount_1);
Declares(s3, count_2); // Note: different version for shadowed variable

// Analyze variable accesses
Accesses(s2, count_1);   // increment accesses count from outer scope
Accesses(s2, step_1);    // increment accesses its parameter
Accesses(s2, newCount_1); // increment accesses its local variable
Accesses(s3, count_2);   // reset accesses its local count, not the outer one
```

#### 4.2 Variable Classification

```orbit
// Apply classification rules
init_1 : LocalVar;       // Only used in makeCounter
step_1 : LocalVar;       // Only used in increment
newCount_1 : LocalVar;   // Only used in increment
count_2 : LocalVar;      // Only used in reset, shadows count_1

count_1 : EscapingVar;   // Escapes from makeCounter to increment
```

#### 4.3 Identify Shadowing

```orbit
// Shadowing relationship
count_2 : SSAVar, count_1 : SSAVar,
BaseName(count_2) = BaseName(count_1),
Declares(s3, count_2), Declares(s1, count_1),
AncestorScope(s1, s3) ⊢ Shadows(count_2, count_1);
```

#### 4.4 Closure Conversion

```orbit
// First convert increment function
function increment(step_1) { body } : Function,
CapturesVars(increment, [count_1]) ⊢
	CreateEnv(increment, [count_1]);

// Create closure with environment
fn(step_1, increment_body) : Function, env_1 = { count_1 } ⊢
	closure(fn(env_1, step_1, increment_body'), env_1) : Closure;

// Transform increment body to use environment
increment_body is {
	// Original: let newCount = count + step;
	// Transformed: let newCount = env.count + step;
	let newCount_1 = env_access(env_1, 0) + step_1;

	// Original: count = newCount;
	// Transformed: env.count = newCount;
	env_update(env_1, 0, newCount_1);

	// Original: return count;
	// Transformed: return env.count;
	return env_access(env_1, 0);
}

// No conversion needed for reset - it doesn't capture variables
function reset() { body } : Function,
!CapturesVars(reset) ⊢ reset : Closure; // Simple conversion, no environment needed
```

#### 4.5 Final SSA-based Representation

After scope analysis and closure conversion, we have a clean representation that clearly identifies:

1. Local variables that can be register-allocated
2. Captured variables that must be stored in environments
3. Proper resolution of shadowed variables

```orbit
// SSA representation after scope analysis and closure conversion
function makeCounter(init_1) {
	let count_1 = init_1; // EscapingVar (will be part of a closure environment)

	// Closure for increment with explicit environment reference
	let env_1 = { count_1 }; // Environment holding captured count_1
	let increment = closure(
		function(env, step_1) {
			let newCount_1 = env_access(env, 0) + step_1; // LocalVar
			env_update(env, 0, newCount_1);
			return env_access(env, 0);
		},
		env_1
	);

	// Reset doesn't capture variables, so no environment needed
	let reset = function() {
		let count_2 = 0; // LocalVar, shadows count_1
		return count_2;
	};

	return { increment, reset };
}
```

### 5. Preparing for Register Allocation

With the SSA-based representation and closure conversion complete, we can prepare for register allocation by annotating variables with their storage classes:

```orbit
// Register allocation domain properties
AllocateInRegister(var : SSAVar) ⊂ Property;
AllocateInEnvironment(var : SSAVar, env, idx) ⊂ Property;
AllocateOnStack(var : SSAVar) ⊂ Property;

// Allocation rules
v : LocalVar, !LongLived(v) ⊢ AllocateInRegister(v);
v : CapturedVar, MemberOf(v, env, idx) ⊢ AllocateInEnvironment(v, env, idx);
v : LocalVar, LongLived(v) ⊢ AllocateOnStack(v);
```

These allocation annotations guide the backend code generator, providing essential information for efficient register allocation and memory access. Local variables that don't escape their scope can be register allocated, while captured variables must be accessed through environment objects.

### 6. Benefits of Combined SSA and Scope Analysis

The combination of SSA form and lexical scope analysis enables several advanced optimizations for functional languages:

1. **Escape Analysis**: Identifying non-escaping allocations that can be stack-allocated
2. **Closure Optimization**: Minimizing the size of closure environments by only including captured variables
3. **Inlining Decisions**: Better information for deciding when to inline functions based on closure size
4. **Selective Closure Conversion**: Some closures can be transformed into simple function pointers if they don't capture variables
5. **Environment Sharing**: Multiple closures from the same scope can share environment structures

```orbit
// Optimizations for closure environments

// Environment sharing between closures from the same scope
f1 : Function, f2 : Function, SameScope(f1, f2),
CapturesVars(f1, vars1), CapturesVars(f2, vars2) ⊢
	ShareEnvironment(f1, f2, Union(vars1, vars2));

// Eliminate environment for non-capturing functions
f : Function, !CapturesVars(f) ⊢
	SimplifyToClosure(f, null);

// Flatten nested closures when possible
closure(fn1, env1), fn1 = closure(fn2, env2) ⊢
	closure(fn2', MergeEnvs(env1, env2));
```

By representing these transformations as rewrite rules in Orbit, we obtain a powerful and flexible system for optimizing functional programs while preserving their semantics.

## Register Allocation via Graph Coloring

With SSA-based analysis and scope information in place, we can implement register allocation using graph coloring, expressing the entire process through Orbit's rewrite system. This approach produces efficient code while maintaining the semantics of the original program.

### 1. Interference Graph Construction

The first step is to build an interference graph where each node represents a variable and edges represent interferences (variables that need to be live at the same time).

#### 1.1 Interference Graph Domains

```orbit
// Domains for interference graph
InterferenceGraph ⊂ Term;
Interferes(v1 : SSAVar, v2 : SSAVar) ⊂ Property;
LiveAt(v : SSAVar, point : Location) ⊂ Property;
Degree(v : SSAVar, count : Integer) ⊂ Property;

// Register allocation domains
Register ⊂ Term;
NumRegisters(n : Integer) ⊂ Property;
Color(v : SSAVar, color : Integer) ⊂ Property;
Spilled(v : SSAVar) ⊂ Property;
```

#### 1.2 Computing Live Ranges

Live ranges determine when variables interfere. We compute them with rewrite rules:

```orbit
// Variable is live at its definition point
define(x_i, expr) : SSADef, PointOf(define(x_i, expr), point) ⊢
	LiveAt(x_i, point);

// Variable is live at each use
use(x_i) : InSSA, PointOf(use(x_i), point) ⊢
	LiveAt(x_i, point);

// Live range propagation through control flow
LiveAt(v, point), SuccessorPoint(point, next),
!Killed(v, point, next) ⊢ LiveAt(v, next);

// Phi nodes create special backward-propagating live ranges
phiParam(phi_node, pred_block, v_i), ExitPoint(pred_block, exit_point) ⊢
	LiveAt(v_i, exit_point);
```

#### 1.3 Building Interference Edges

```orbit
// Two different variables that are live at the same point interfere
LiveAt(v1, point), LiveAt(v2, point), v1 ≠ v2,
!Duplicate(v1, v2) ⊢ Interferes(v1, v2);

// Explicit interference with phi results for the variables coming from the same path
assign(x_i, phi([...])) : SSAPhi, PhiParam(phi_node, block, v_j),
!Duplicate(x_i, v_j) ⊢ Interferes(x_i, v_j);

// Compute degree of each node (number of interferences)
v : SSAVar, count = CountInterfering(v) ⊢ Degree(v, count);
```

### 2. Graph Coloring Algorithm

We model graph coloring using rewrite rules. This is a simplified version of the Chaitin-Briggs algorithm:

#### 2.1 Building the Coloring Stack

```orbit
// Start with an empty stack
InitializeStack() ⊢ Stack([]) : ColoringStack;

// Push low-degree nodes onto the stack (degree < available registers)
Stack(nodes) : ColoringStack, v : SSAVar !: OnStack, !Spilled(v),
NumRegisters(k), Degree(v, d), d < k ⊢
	Stack([v | nodes]) : ColoringStack, v : OnStack;

// If no low-degree nodes exist, choose the highest-degree node to spill
Stack(nodes) : ColoringStack,
!(∃v. !OnStack(v) ∧ !Spilled(v) ∧ Degree(v, d) ∧ NumRegisters(k) ∧ d < k),
v : SSAVar !: OnStack, !Spilled(v), HighestDegree(v) ⊢
	v : Spilled, v : OnStack, Stack([v | nodes]) : ColoringStack;

// When all nodes are on stack, start coloring
Stack(nodes) : ColoringStack,
(∀v. v : SSAVar ⊢ (OnStack(v) ∨ Spilled(v))) ⊢
	BeginColoring(nodes) : ColoringPhase;
```

#### 2.2 Assigning Colors (Registers)

```orbit
// Pop nodes from stack and assign colors (registers)
BeginColoring([v | rest]) : ColoringPhase, NumRegisters(k),
AvailableColors(v, used, k) ⊢
	Coloring(rest) : ColoringPhase, Color(v, FirstAvailable(used, k));

// Helper to find available colors based on already-colored neighbors
v : SSAVar, neighbors = [n | Interferes(v, n) ∧ Color(n, _)],
colors = [c | n ∈ neighbors ∧ Color(n, c)],
avail = {0,1,...,k-1} - colors ⊢
	AvailableColors(v, avail, k);

// When a spilled node is encountered during coloring, skip it
BeginColoring([v | rest]) : ColoringPhase, v : Spilled ⊢
	BeginColoring(rest) : ColoringPhase;

// When we finish coloring, verify results
BeginColoring([]) : ColoringPhase ⊢
	VerifyColoring() : ValidationPhase;
```

#### 2.3 Handling Register Pressure and Spilling

```orbit
// Verification may detect coloring failures - nodes that couldn't get a color
VerifyColoring() : ValidationPhase,
∃v. !Spilled(v) ∧ !Color(v, _) ⊢
	SpillMore() : SpillPhase;

// When verification succeeds, prepare for code generation
VerifyColoring() : ValidationPhase,
∀v. v : SSAVar ⊢ (Spilled(v) ∨ Color(v, _)) ⊢
	PrepareCodeGen() : CodeGenPhase;
```

### 3. Code Generation with Register Assignments

#### 3.1 Mapping Colors to Physical Registers

```orbit
// Associate colors with physical register names
Color(v, 0) ⊢ RegisterName(v, "rax");
Color(v, 1) ⊢ RegisterName(v, "rbx");
Color(v, 2) ⊢ RegisterName(v, "rcx");
// ... and so on for all available registers
```

#### 3.2 Transforming Code to Use Registers

```orbit
// Transform variable references to register references in assignments
assign(x_i, expr) : SSADef, RegisterName(x_i, reg) ⊢
	assign(reg, expr) : MachineCode;

// Transform variable references to register references in expressions
use(x_i) : InSSA, RegisterName(x_i, reg) ⊢
	use(reg) : MachineCode;

// Generate memory operations for spilled variables
assign(x_i, expr) : SSADef, Spilled(x_i), StackSlot(x_i, offset) ⊢
	[compute(expr, "rax"), store("rax", "rbp", offset)] : MachineCode;

use(x_i) : InSSA, Spilled(x_i), StackSlot(x_i, offset) ⊢
	load("rbp", offset, "rax") : MachineCode;
```

### 4. Interfacing with SSA and Scope Information

We leverage the scope analysis and SSA information to make better register allocation decisions:

```orbit
// Variables from the same scope but different basic blocks may not interfere
// even if their live ranges overlap (if control flow prevents them from being used together)
LiveAt(v1, point1), LiveAt(v2, point2), ScopeOf(v1, s), ScopeOf(v2, s),
BlockOf(point1, b1), BlockOf(point2, b2), b1 ≠ b2,
!CanReach(b1, b2) ∧ !CanReach(b2, b1) ⊢
	NonInterfering(v1, v2);

// Environment-allocated variables don't need registers
AllocateInEnvironment(v, env, idx) ⊢ EnvironmentAllocated(v);

// Don't consider environment-allocated variables for register allocation
v : SSAVar, EnvironmentAllocated(v) ⊢ SkipRegisterAllocation(v);
```

### 5. Example: Allocating Registers in a Function

Let's look at a practical example of the register allocation process for a simple function:

```js
function sumSquares(n) {
	let sum = 0;
	for (let i = 1; i <= n; i++) {
		let square = i * i;
		sum = sum + square;
	}
	return sum;
}
```

#### 5.1 After SSA Conversion

```orbit
// SSA Form
function sumSquares(n_1) {
	let sum_1 = 0;
	let i_1 = 1;
	goto loop_condition;

loop_condition:
	let continue_1 = i_1 <= n_1;
	if (continue_1) goto loop_body else goto exit;

loop_body:
	let square_1 = i_1 * i_1;
	let sum_2 = sum_1 + square_1;
	let i_2 = i_1 + 1;
	sum_1 = phi([sum_1, sum_2]);
	i_1 = phi([i_1, i_2]);
	goto loop_condition;

exit:
	return sum_1;
}
```

#### 5.2 Interference Graph

```orbit
// Interferences
Interferes(n_1, sum_1);
Interferes(n_1, i_1);
Interferes(n_1, continue_1);
Interferes(n_1, square_1);
Interferes(sum_1, i_1);
Interferes(sum_1, continue_1);
Interferes(sum_1, square_1);
Interferes(i_1, continue_1);
Interferes(i_1, square_1);
Interferes(continue_1, i_2);
Interferes(square_1, sum_2);
Interferes(square_1, i_2);
Interferes(sum_2, i_2);

// Degrees
Degree(n_1, 4);
Degree(sum_1, 4);
Degree(i_1, 4);
Degree(continue_1, 3);
Degree(square_1, 4);
Degree(sum_2, 2);
Degree(i_2, 3);
```

#### 5.3 Graph Coloring Process

Assuming we have 4 registers available:

```orbit
// Initial stack build (low-degree first)
Stack([sum_2, continue_1, i_2]);

// No more low-degree nodes, spill highest-degree
Spilled(n_1); // Chosen for spill
Stack([n_1, sum_2, continue_1, i_2]);

// Continue with remaining nodes
Stack([square_1, i_1, sum_1, n_1, sum_2, continue_1, i_2]);

// Start coloring (popping in reverse order)
Color(i_2, 0);       // Register 0
Color(continue_1, 1); // Register 1
Color(sum_2, 2);     // Register 2
// Skip n_1 (spilled)
Color(sum_1, 2);     // Register 2 (reusing sum_2's register)
Color(i_1, 0);       // Register 0 (reusing i_2's register)
Color(square_1, 3);  // Register 3
```

#### 5.4 Register Allocation Result

```orbit
// Physical register mapping
RegisterName(i_1, "rax");    // reg0
RegisterName(i_2, "rax");    // reg0
RegisterName(continue_1, "rbx"); // reg1
RegisterName(sum_1, "rcx");   // reg2
RegisterName(sum_2, "rcx");   // reg2
RegisterName(square_1, "rdx"); // reg3
StackSlot(n_1, -8);      // spilled to stack
```

#### 5.5 Final Code With Registers

```orbit
// Machine code with registers
function sumSquares() {
	// Parameter n_1 already spilled to [rbp-8] by convention
	mov rcx, 0          // sum_1 = 0
	mov rax, 1          // i_1 = 1
	jmp loop_condition

loop_condition:
	cmp rax, [rbp-8]    // compare i_1 and n_1 (from stack)
	setle bl            // continue_1 = i_1 <= n_1
	test bl, bl
	jnz loop_body
	jmp exit

loop_body:
	mov rdx, rax        // square_1 = i_1
	imul rdx, rax       // square_1 = square_1 * i_1
	add rcx, rdx        // sum_2 = sum_1 + square_1
	inc rax             // i_2 = i_1 + 1
	jmp loop_condition  // phi nodes handled naturally by register reuse

exit:
	mov rax, rcx        // return sum_1 (result in rax)
	ret
}
```

This example demonstrates how Orbit's rewrite system can model the complete register allocation process using graph coloring. By expressing allocation as rewrite rules, we obtain a clear and formal description of the algorithm while leveraging scope and SSA information to optimize register usage.

### 6. Extensions and Advanced Techniques

The register allocation framework can be extended to handle more advanced techniques:

```orbit
// Register coalescing - avoid unnecessary moves between variables
Interferes(x_i, y_j) !: true,
Move(y_j, x_i), Color(x_i, c) ⊢
	Color(y_j, c), Coalesced(y_j, x_i);

// Register hints for ABI conventions
ReturnValue(v) ⊢ PreferRegister(v, "rax");
Parameter(v, 1) ⊢ PreferRegister(v, "rdi");
Parameter(v, 2) ⊢ PreferRegister(v, "rsi");

// Live range splitting for better allocation
SpillCandidate(v), LongLiveRange(v) ⊢
	SplitLiveRange(v, split_points) : SplitPhase;

// Register allocation for SIMD registers
SIMDVariable(v) ⊢ AllocateSIMDRegister(v);
```

These extensions allow the register allocator to handle complex codebases, optimizing for both general-purpose and special-purpose registers while respecting ABI conventions and minimizing the performance impact of spills.


## Region-Based Memory Inference

Extends the analysis to infer memory region lifetimes for potential stack or arena allocation, reducing reliance on GC.

### 1. Region and Effect Domains

```orbit
// Represent Regions
RegionVar(id) ⊂ DomainTerm; // Abstract region variable, e.g., RegionVar(1)
Region_Global ⊂ DomainTerm; // Predefined global region
Region_Stack(ScopeId) ⊂ DomainTerm; // Stack region tied to a scope

// Represent Effects
Effect ⊂ Property; // Base for effects
AllocatesIn(Region) ⊂ Effect;
ReadsFrom(Region) ⊂ Effect;
WritesTo(Region) ⊂ Effect;
Frees(Region) ⊂ Effect;
FunctionEffects(Reads : set<Region>, Writes : set<Region>, ...) ⊂ Effect;

// Represent Allocation Decisions
AllocationStrategy ⊂ Property;
AllocateOnStack ⊂ AllocationStrategy;
AllocateInRegion(Region) ⊂ AllocationStrategy;
AllocateOnHeapGC ⊂ AllocationStrategy; // Fallback
```

### 2. Constraint Generation via Rewrite Rules (`⊢`)

```orbit
// Initialization: Literals are in the global region
e : Literal ⊢ e : Region(Region_Global);

// Allocation: 'cons' allocates in a fresh region bound by its inputs
(cons x y)
	where x : Region(Rx), y : Region(Ry)
	let ρ_new = freshRegionVar()
	// Assert effects and constraints
	⊢ (cons x y) : Region(ρ_new) : AllocatesIn(ρ_new),
	  AddConstraint(Rx ≤ ρ_new), AddConstraint(Ry ≤ ρ_new); // Add constraints to solver

// Variable Reference
use(x) where x : Region(Rx)
	⊢ AddConstraint(IsLive(Rx, CurrentPoint)); // Region Rx must be live

// Assignment/Update
(set-car! p x) where p : Region(Rp), x : Region(Rx)
	⊢ AddConstraint(Rx ≤ Rp); // Value must live as long as container

// Function Call Effects
f(arg)
	where f : FunctionType(..., Effects(Reads=RS, Writes=WS, Allocates=AS, Frees=FS)),
		  arg : Region(Rarg)
	let Rresult = freshRegionVar() // Region for the result
	⊢ f(arg) : Region(Rresult),
	  AddConstraint(Rarg ≤ RegionOf(f)), // Argument lifetime
	  // Add constraints based on effects RS, WS, AS, FS relating Rarg, Rresult, and function's regions
	  // e.g., for R in RS: AddConstraint(R must be live during call)
	  // e.g., for A in AS: AddConstraint(A ≤ Rresult if result contains allocation)
	  ... ;
```
**Note:** `AddConstraint` is a conceptual action indicating the constraint needs to be added to a global solver system.

### 3. Constraint Solving

*   Requires a separate pass or integrated solver to process the collected `ρ₁ ≤ ρ₂` inequalities.
*   The solver determines the lifetime relationship between abstract regions (e.g., region `ρ₁` is contained within the lifetime of function scope `S`).

### 4. Allocation Decision Rules (`→`)

Apply after constraint solving.

```orbit
// Map solved regions to allocation strategies
v : Region(ρ), SolvedLifetime(ρ, StackScope(S)) ⊢ v : AllocateOnStack;
v : Region(ρ), SolvedLifetime(ρ, ArenaScope(A)) ⊢ v : AllocateInRegion(Region_Arena(A));
v : Region(ρ), SolvedLifetime(ρ, Escaping) ⊢ v : AllocateOnHeapGC; // Fallback
```

### 5. Code Generation Transformation (`→`)

Translate based on allocation annotations.

```orbit
// Transform 'cons' based on allocation strategy
(cons x y) : AllocateOnStack
	→ (scheme_stack_cons x y) // Target Scheme/C call for stack cons
	⊢ :SchemeCode;

(cons x y) : AllocateInRegion(Region_Arena(A))
	→ (scheme_arena_cons A x y) // Target call for arena cons
	⊢ :SchemeCode;

(cons x y) : AllocateOnHeapGC
	→ (scheme_gc_cons x y) // Target call for GC cons
	⊢ :SchemeCode;

// Insert region management code
EnterScope(S) : NeedsStackRegion
	→ (scheme_enter_stack_region()) // Insert stack allocation setup
	⊢ :SchemeCode;

ExitScope(S) : HasStackRegion(ρ_stack)
	→ (scheme_leave_stack_region ρ_stack) // Insert stack deallocation
	⊢ :SchemeCode;
```

## Conclusion

By using pattern matching with domain annotations and the entailment operator, Orbit can infer semantic properties of expressions and propagate them appropriately. The ability to bubble up properties from subexpressions is particularly powerful, allowing for compositional reasoning about complex expressions while maintaining precision. This approach enables sophisticated program transformation while preserving semantic guarantees.