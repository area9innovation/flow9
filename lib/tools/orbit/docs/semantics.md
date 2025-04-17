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
## Conclusion

By using pattern matching with domain annotations and the entailment operator, Orbit can infer semantic properties of expressions and propagate them appropriately. The ability to bubble up properties from subexpressions is particularly powerful, allowing for compositional reasoning about complex expressions while maintaining precision. This approach enables sophisticated program transformation while preserving semantic guarantees.