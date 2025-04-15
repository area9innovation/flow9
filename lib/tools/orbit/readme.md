# Orbit: Domain-Unified Rewriting Engine: Bridging Mathematical Formalism and Practical Programming

## Introduction

We present a novel approach to program transformation and optimization that unifies three powerful technologies: equivalence graphs (e-graphs), a domain-unified rewriting system based on group theory, and Orbit's native AST capabilities. This synthesis creates a powerful cross-language rewriting engine capable of applying formal mathematical theorems directly to program code.

## Orbit: A Functional Programming Language

Orbit is a functional programming language that integrates e-graphs (called ographs) to enable advanced rewriting and optimization capabilities. The language provides a native interface to ographs, allowing direct manipulation of abstract syntax trees (ASTs) and application of rewrite rules.

### Running Orbit

You run Orbit like this:

```

flow9/lib/tools/orbit> flowcpp --batch orbit.flow -- tests/pattern.orb

```

### Enabling Tracing

Orbit provides a detailed tracing feature that shows all steps of interpretation, which is useful for debugging and understanding program execution. To enable tracing, use the `trace=1` URL parameter:

```

flow9/lib/tools/orbit> flowcpp --batch orbit.flow -- trace=1 tests/pattern.orb

```

With tracing enabled, you'll see detailed output for each interpretation step, including:
- Expression types being processed
- Variable lookups and bindings
- Function calls and their arguments
- Evaluation of sub-expressions

Without tracing (the default), only the final result will be displayed, making the output cleaner and more concise for normal usage.

### Using the Test Suite

Orbit includes a comprehensive test suite to verify correct behavior and prevent regressions. The test suite automatically runs all .orb files in a specified directory and captures their outputs.

#### Running the Test Suite

To run the test suite on all tests in the default 'tests' directory:

```

flow9/lib/tools/orbit> ./run_orbit_tests.sh

```

This script executes all .orb files in the 'tests' directory and saves the outputs to the 'test_output' directory.

#### Test Suite Options

The test script supports several command-line parameters:

```

flow9/lib/tools/orbit> ./run_orbit_tests.sh --test-dir=custom_tests --output-dir=results --trace --verbose

```

- `--test-dir=DIR`: Specifies the directory containing test files (default: 'tests')
- `--output-dir=DIR`: Specifies the directory to save test outputs (default: 'test_output')
- `--timeout=SECONDS`: Maximum time to allow a test to run before timing out (default: 10 seconds)
- `--trace`: Enables detailed tracing during test execution
- `--verbose`: Shows detailed output for each test while running
- `--help`: Displays usage information

#### Test Suite Output

The test suite generates:

1. Individual output files for each test in the output directory
2. A summary file (_summary.txt) with test results and statistics
3. Console output showing which tests passed or failed

#### Using for Regression Testing

The test suite is designed to work with version control systems like git for regression testing:

1. Run the test suite to generate baseline outputs
2. Commit these outputs to your repository
3. After making changes, run the test suite again
4. Use `git diff` to see if any test outputs have changed

This workflow makes it easy to identify unintended changes in behavior during development.

#### Examples

Run all tests in the default directory:
```

./run_orbit_tests.sh

```

Run a specific set of tests with detailed output:
```

./run_orbit_tests.sh --test-dir=tests/math --verbose

```

Turn on tracing for step-by-step execution details:
```

./run_orbit_tests.sh --trace

```

## Theoretical Foundation: Domains and Symmetry Groups

At the heart of our system lies the insight that computational domains themselves—whether programming languages, algebraic structures, or formal systems—should be first-class citizens in the rewriting process. **In Orbit, domains are represented simply as terms within the language.** However, the intention is for users to **structure these domain terms into a hierarchy, ideally forming a partial order or lattice (e.g., `Integer ⊂ Real ⊂ Complex`).** This hierarchical structure allows the system to apply rewrite rules and reasoning defined at more abstract domain levels (like `Ring`) to expressions belonging to more specific sub-domains (like `Integer`), thereby maintaining the system's expressive power while enabling high-level optimization and transformation strategies.

By representing domains explicitly within our e-graph structure, we enable:

1. **Cross-Domain Reasoning**: Values can exist simultaneously in multiple domains through domain annotations.
2. **Hierarchical Rule Application**: Rules defined for parent domains apply to child domains.
3. **Canonical Representations**: Each domain can leverage its natural symmetry group for canonicalization.
4. **Deep Algebraic Structures**: The system automatically discovers and exploits algebraic properties.

For example, addition exhibits symmetry group S₂ (the symmetric group of order 2), which captures commutativity. When we encounter expressions like `a + b` in any language associated with a domain where addition is commutative (like `Real` or `Integer`), the system can automatically canonicalize to a standard form based on this algebraic property, thus avoiding redundant representations.

## Native OGraph Integration

Orbit provides a native interface to the OGraph system, enabling direct manipulation of abstract syntax trees and powerful rewriting capabilities. The core API is centered around the `orbit` function:

```orbit
// Main function: Takes rewrite rules, cost function, and expression to optimize
fn orbit(rules : ast, cost : (expr : ast) -> double, expr : ast) : ast (
	// Create a new ograph
	let graph = makeOGraph();

	// Add the expression to optimize to the graph
	let nodeId = addExprToGraph(graph, expr);

	// Apply all rewrite rules to saturation
	let saturated = applyRulesToSaturation(graph, rules);

	// Extract the optimal expression according to the cost function
	let optimized = extractOptimal(saturated, cost);

	optimized
)
```

The `orbit` function takes three parameters:
1. A set of rewrite rules as an AST
2. A cost function that determines the optimality of expressions
3. The expression to be optimized

It returns the optimized version of the input expression.

## Domain-Unified Rewriting System: Grammar and Semantics

### Core Notation and Semantics

The Domain-Unified Rewriting System uses domain annotations to express relationships between expressions across different domains:

```orbit
// a belongs to domain A
a : A

// If a belongs to domain A, then a and b are equivalent, and b belongs to domain B
a : A => b : B

// Entailment: Addition between two reals is commutative
a : Real + b : Real  ⊢  + : S₂

// The addition of two reals is a real
a : Real + b : Real => (a + b) : Real

// The domain of Int is a subset of Real
Int ⊂ Real

// Apply an annotation during rewrite only if it's not already present
(x + c) !: ExplicitCoef => (1 * x + c) : ExplicitCoef
```

### Operator Semantics in E-Graph Context

| Operator | ASCII Alternative | E-Graph Interpretation | Semantic Meaning | Example | Node Relationship Behavior |
|----------|------------------|------------------------|------------------|---------|---------------------------|
| `:` | `:` | Domain annotation | In patterns: Constrains matches to the specified domain. In results: Asserts the expression belongs to the domain. | `x : Algebra` | Adds the domain `Algebra` to the "belongs to" field of node `x`. |
| `⇒` | `=>` | Rewrite rule | Converts an expression from one form to another, potentially across domains. | `a + b : JavaScript => a + b : Python` | Creates a node for `a + b` that belongs to the `JavaScript` domain, and another node for `a + b` that belongs to the `Python` domain. |
| `⇔` | `<=>` | Equivalence | Declares bidirectional equivalence between patterns, preserving domain membership. | `x * (y + z) : Algebra <=> (x * y) + (x * z) : Algebra` | Creates nodes for both expressions and marks them as equivalent. |
| `⊢` | `\|-` | Entailment | When the left pattern matches, the right side domain annotation is applied. | `a : Field + b : Field \|- + : S₂` | When a matching expression is found, the `+` operator node has domain `S₂` added to it. |
| `⊂` | `c=` | Subset relation | Indicates domain hierarchy, automatically applying parent domain memberships to children. | `Integer c= Real` | Establishes that any node belonging to the `Integer` domain also implicitly belongs to the `Real` domain. |
| `!:` | `!:` | Negative Domain Constraint | In patterns: Constrains matches to nodes that *do not* belong to the specified domain/annotation. | `x !: Processed => ...` | Checks if the node `x`'s "belongs to" field *does not* contain `Processed`. Match succeeds only if the domain/annotation is absent. |

In the e-graph implementation, each node maintains a "belongs to" field that tracks which domains or annotations it belongs to. The operators above define how domains are added to nodes and how nodes relate to each other.

## Pattern Matching vs. Entailment

Here's a more precise description of how domain annotations work in different contexts:

### 1. Pattern Matching of Domain (Left-Hand Side)

```
expr : Domain
```

On the left-hand side of a rule, this is a **constraint** requiring that:
- The matched node must already have the specified domain in its "belongs to" field
- This acts as a filter in pattern matching, restricting the match to nodes that belong to specific domains

```
a + b : Int
a + b : S₂
```

This matches:
- An addition expression that belongs to the Int domain
- An addition with S₂ symmetry property (matches any permutation in the S₂ orbit)

In particular, this means that the node for `a + b` must have both its original domain and the specified domain (`Int`/`S₂`) in its "belongs to" field for this pattern to match.

### 2. Entailment (Right-Hand Side)

```
a + b => a + b : S₂
```

On the right-hand side, this is an **assertion** that:
- The resulting node should have `S₂` added to its "belongs to" field
- This adds domain membership information to the node for `a+b`, allowing it to match patterns requiring S₂ membership

### 3. Explicit Entailment Rules

```
pattern ⊢ op : Domain
```

This creates a conditional domain annotation:
- When `pattern` matches something, including an op
- The op node has `Domain` added to its "belongs to" field

For example:
```
n ⊢ n : Prime if isPrime(n);
```

## Domain Hierarchies and Rule Inheritance

Orbit organizes domains into hierarchies with rule inheritance. For example:

```
AbelianGroup ⊂ Ring ⊂ Field
Integer ⊂ Real ⊂ Complex
Python.List ⊂ Python.Iterable
```

Rules defined at more abstract levels automatically apply to concrete instances. For example, commutativity defined for `AbelianGroup` applies to integers in Python, allowing the system to apply `a + b ⇔ b + a` without explicitly defining this rule for Python integers.

## Example Usage: Algebraic Simplification

Here's how you might use this API to optimize mathematical expressions:

```orbit
fn quote(e : ast) = e;

// Define some rewrite rules for algebraic simplification
let algebraRules = quote(
	// Commutativity with domain constraints
	a : Real + b : Real <=> b : Real + a : Real;

	// Identity: a + 0 => a
	a + 0 => a;

	// Identity: a * 1 => a
	a * 1 => a;

	// Zero: a * 0 => 0
	a * 0 => 0;

	// Distribution: a * (b + c) => (a * b) + (a * c)
	a * (b + c) <=> (a * b) + (a * c);

	// Combine like terms: a * c + b * c => (a + b) * c
	a * c + b * c => (a + b) * c;
);

// Define a cost function that prefers smaller expressions
fn expressionCost(expr : ast) -> double (
	expr is (
		a + b => 1.0 + expressionCost(a) + expressionCost(b);
		a * b => 1.0 + expressionCost(a) + expressionCost(b);
		a - b => 1.0 + expressionCost(a) + expressionCost(b);
		a / b => 1.0 + expressionCost(a) + expressionCost(b);
		a ^ b => 1.0 + expressionCost(a) + expressionCost(b);
		-a => 1.0 + expressionCost(a);
		_ => 1.0;  // Base case: literals, variables
	)
)

// Optimize an expression
fn main() (
	// Expression: (2 * x + 3 * x) * (y + z) - (0 * w)
	let expr = quote((2 * x + 3 * x) * (y + z) - (0 * w));

	println("Original: " + prettyOrbit(expr));

	// Apply optimization
	let optimized = orbit(algebraRules, expressionCost, expr);

	println("Optimized: " + prettyOrbit(optimized));

	// Expected output: 5 * x * (y + z)
)
```

## Example: Polynomial Equation Solving with Group Theory

Here's a more complex example showing how Orbit can use group-theoretic structures and domain annotations to solve quadratic equations:

```orbit
fn quote(e : ast) = e;

// Define rules for solving quadratic equations
let quadraticRules = quote(
	// Domain hierarchy for number types
	Integer ⊂ Rational ⊂ Real ⊂ Complex;

	// Moving terms from right to left side
	A = B + C <=> A - C = B;
	A = B - C <=> A + C = B;

	// Moving terms with coefficient
	A = B + n*C <=> A - n*C = B;
	A = B - n*C <=> A + n*C = B;

	// Moving all terms to the left side (canonical form preparation)
	A = B <=> A - B = 0 : Canonical;

	// Combining like terms for x^2
	a*x^2 + b*x^2 <=> (a+b)*x^2;
	a*x^2 - b*x^2 <=> (a-b)*x^2;

	// Combining like terms for x
	a*x + b*x <=> (a+b)*x;
	a*x - b*x <=> (a-b)*x;

	// Combining constants
	a : Constant + b : Constant <=> $(a+b) : Constant : Canonical;
	a : Constant - b : Constant <=> $(a-b) : Constant : Canonical;

	// Add explicit coefficient to x when needed
	// Rule: If (x + c) does NOT have the ExplicitCoef annotation,
	// rewrite it to (1 * x + c) and add the ExplicitCoef annotation to the result.
	(x + c) !: ExplicitCoef => (1 * x + c) : ExplicitCoef;

	// Quadratic formula cases based on discriminant
	// Two real solutions when discriminant > 0
	a*x^2 + b*x + c = 0 : Quadratic => {
		(-b + sqrt(b^2 - 4*a*c))/(2*a),
		(-b - sqrt(b^2 - 4*a*c))/(2*a)
	} : Solutions if b^2 - 4*a*c > 0;

	// One real solution when discriminant = 0
	a*x^2 + b*x + c = 0 : Quadratic => {
		-b/(2*a)
	} : Solutions if b^2 - 4*a*c = 0;

	// No real solutions when discriminant < 0
	a*x^2 + b*x + c = 0 : Quadratic => {} : Solutions if b^2 - 4*a*c < 0;

	// Complex solutions for negative discriminant
	a*x^2 + b*x + c = 0 : Quadratic : Complex => {
		-b/(2*a) + sqrt(-(b^2 - 4*a*c))/(2*a) * i,
		-b/(2*a) - sqrt(-(b^2 - 4*a*c))/(2*a) * i
	} : ComplexSolutions if b^2 - 4*a*c < 0;

	// Solve interface
	solve x in (y : Set) => x = y : Canonical;
);

// Function to solve a quadratic equation
fn solveQuadratic(expr : ast) -> ast (
	// Use the quadratic rules to solve the equation
	let costFunction = \expr -> (
		expr is (
			_ : Solutions => 0.0;  // Favor solution sets
			_ : Canonical => 1.0;  // Prefer canonical forms over others
			_ => 10.0;           // Penalize other expressions
		)
	);

	// Apply optimization
	let result = orbit(quadraticRules, costFunction, expr);
	result
)

// Example usage
fn main() (
	// Example 1: x^2 - 1 = 2*x
	let eq1 = quote(solve x in (x^2 - 1 = 2*x));
	let sol1 = solveQuadratic(eq1);
	println("Equation 1: " + prettyOrbit(eq1));
	println("Solution 1: " + prettyOrbit(sol1));
	// Expected: {1 + sqrt(2), 1 - sqrt(2)} -- Actual simplified result might vary based on sqrt precision

	// Example 2: x^2 + 4 = 0
	let eq2 = quote(solve x in (x^2 + 4 = 0));
	let sol2 = solveQuadratic(eq2);
	println("Equation 2: " + prettyOrbit(eq2));
	println("Solution 2: " + prettyOrbit(sol2));
	// Expected: {} (no real solutions)

	// Example 3: x^2 - 6*x + 9 = 0 (perfect square)
	let eq3 = quote(solve x in (x^2 - 6*x + 9 = 0));
	let sol3 = solveQuadratic(eq3);
	println("Equation 3: " + prettyOrbit(eq3));
	println("Solution 3: " + prettyOrbit(sol3));
	// Expected: {3} (exactly one solution)

	// Example 4: Find complex solutions
	let eq4 = quote(solve x in (x^2 + 1 = 0) : Complex);
	let sol4 = solveQuadratic(eq4);
	println("Equation 4: " + prettyOrbit(eq4));
	println("Solution 4: " + prettyOrbit(sol4));
	// Expected: {i, -i}
)
```

When this code is executed, it would demonstrate how the Orbit system can solve quadratic equations by incrementally applying rewrite rules that transform the input equation. Behind the scenes, the following transformations would occur:

1. For `x^2 - 1 = 2*x`:
   - Move all terms to left side: `x^2 - 1 - 2*x = 0`
   - Arrange in standard form: `x^2 - 2*x - 1 = 0`
   - Extract coefficients: `a=1, b=-2, c=-1`
   - Calculate discriminant: `b^2-4ac = 4+4 = 8 > 0`
   - Apply quadratic formula: `{(-(-2) + sqrt(8))/2, (-(-2) - sqrt(8))/2}`
   - Simplify: `{(2 + 2*sqrt(2))/2, (2 - 2*sqrt(2))/2}`
   - Final result: `{1 + sqrt(2), 1 - sqrt(2)}`

The system would use domain annotations throughout this process to track what kinds of mathematical operations are valid and to direct the simplification strategy.

## Example: Cross-Domain Transformations

Domain annotations enable transformations between different languages or domains:

```orbit
let crossDomainRules = quote(
	// JavaScript to Python transformation
	array.map(f).filter(p) : JavaScript => [f(x) for x in array if p(x)] : Python;

	// Math to code transformation
	sum(i, 0, n, f(i)) : Math => fold(\acc x -> acc + f(x), 0, range(0, n)) : Code;

	// Set theory to list operations
	union(A, B) : SetTheory => distinct(A + B) : Lists;

	// Domain-specific optimizations
	a : Real * (b : Real + c : Real) : Distributive => (a : Real * b : Real) + (a : Real * c : Real);
);
```

## Conclusion

Orbit provides a powerful platform for working with symbolic expressions, mathematical rewriting, and cross-domain transformations. Its native OGraph integration and domain annotation system enable sophisticated program optimization and transformation capabilities while maintaining a clean, functional programming model.

The ability to express and solve problems in domains like polynomial equations demonstrates the power of combining group theory with computational rewriting. By bridging the gap between mathematical formalism and practical programming, Orbit enables new approaches to challenging computational problems through group-theoretic reasoning, domain-crossing transformations, and cost-driven optimization.
