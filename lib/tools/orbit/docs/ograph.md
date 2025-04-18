# O-Graphs in Orbit

This document describes the O-Graph functionality available in the Orbit language.

## Overview

O-Graphs (Orbit Graphs) are a data structure that efficiently represents equivalence classes of expressions similar to E-graphs (Equivalence Graphs). They are used in term rewriting systems, theorem provers, and optimizing compilers to efficiently reason about equality between expressions.

O-Graphs are an extension of E-Graphs. The main innovations are that each e-class can belong to other e-classes. The other main difference is that we let the root of an e-class be the representative of that e-class. Also, we allow multiple instances of the same e-node with different e-classes. These innovations combine to allow new capabilities as discussed further below.

In Orbit, O-Graphs are accessible through a set of runtime functions that allow you to:

1. Create and manage O-Graphs
2. Add expressions and establish equivalences
3. Associate expressions with domains
4. Extract and visualize the graph structure

## Available Runtime Functions

### Graph Creation and Management

#### `makeOGraph(name: string) -> string`

Creates a new, empty O-Graph with the given name and returns the name.

```orbit
let g = makeOGraph("myGraph");
```

### Adding Expressions

#### `addOGraph(graphName: string, expr: expression) -> int`

Recursively adds an entire expression tree to the graph and returns the ID of the root node.

```orbit
let exprId = addOGraph(g, (a + b) * (c - d));
```

This adds all nodes in the expression tree: *, +, -, a, b, c, d with proper relationships.

The `extractOGraph` allows us to get it back out:

```orbit
// Now we can extract the expression from the graph
let expr = extractOGraph(g, exprId);
```

To document the new `findOGraphId` runtime function in `ograph.md`, you should add a subsection in the "Available Runtime Functions" section (below or near `addOGraph` and `extractOGraph`). Here’s a precise documentation excerpt to include:

#### `findOGraphId(graphName: string, expr: expression) -> int`

**Finds the node ID for a structurally-equal term in the O-Graph, or returns -1 if it does not exist.**

- **Parameters:**
  - `graphName`: The name of the O-Graph (as a string).
  - `expr`: The (possibly quoted) term or expression to look for.

- **Returns:**  
  The node ID (as integer) of a node in the graph that is *structurally equal* to `expr`, or -1 if no such node exists. If the term was just added, this will match the inserted node’s ID.

- **Usage Example:**
  ```orbit
	let g = makeOGraph("myGraph");
	let x_id = addOGraph(g, quote(foo(bar, 7)));
	let found = findOGraphId(g, quote(foo(bar, 7)));   // returns x_id
	let not_found = findOGraphId(g, quote(nonexistent())); // returns -1
```

- **Notes:**
  - "Structurally equal" means the term’s tree shape and content matches, regardless of canonicalization or node IDs.

### Establishing Equivalences

#### O-Graph Canonicalization and Equivalence Classes

When working with O-Graphs, understanding how canonicalization works is critical. When expressions are merged to represent equivalence, one expression is designated as the "canonical representative" or "root" of the equivalence class.

When you later extract an expression from an eclass, you'll always get the canonical form, not necessarily the exact expression you originally added. This behavior is by design and enables the system to maintain a consistent representation of equivalent expressions.

#### `mergeOGraphNodes(graphName: string, nodeId1: int, nodeId2: int) -> bool`

Merges two nodes to represent that they are equivalent expressions. Returns true if successful.

```orbit
// Establish that a + b is equivalent to c - d
let n1 = addOGraph(g, a + b);
let n2 = addOGraph(g, c - d);
mergeOGraphNodes(g, n1, n2);
```

**IMPORTANT**: The order of nodeIds matters! The first node (`nodeId1`) will become the canonical representative (root) of the merged equivalence class. When extracting expressions later, the canonical form will be used. This is especially important in rewriting systems where you typically want the transformed expression to be canonical.

```orbit
// Pattern matching and rewriting example
matchOGraphPattern(graph, pattern, \(bindings : ast, eclassId) . (
	// Process the replacement
	let result = substituteWithBindings(replacement, bindings);

	// Add the result to the graph
	let resultId = addOGraph(graph, result);

	// Make the result the canonical form by putting its ID first
	mergeOGraphNodes(graph, resultId, eclassId);
));
```

### Domain Associations

#### `addDomainToNode(graphName: string, nodeId: int, domainId: int) -> bool`

Associates a node with a domain node, which can be any expression in the O-Graph. Returns true if successful.

```orbit
// Add the expression a + b
let exprId = addOGraph(g, a + b);

// Add the domain expression S_2
let domainId = addOGraph(g, S_2);

// Associate the expression with the domain
addDomainToNode(g, exprId, domainId);
```

This allows associating expressions with arbitrary domain expressions.

### Pattern Matching

#### `matchOGraphPattern(graphName: string, pattern: expression, callback: (bindings: ast, eclassId: int) -> void) -> int`

Searches for all occurrences of a pattern in the graph and calls the provided callback for each match, passing a map of variable bindings and the e-class ID of the matched node. Returns the number of matches found.

**IMPORTANT**: The `bindings` parameter in the callback function must be marked as `ast` to ensure the bindings are not prematurely evaluated. This typing is crucial for proper functionality when using these bindings with functions like `substituteWithBindings`.

```orbit
// Create a graph with some expressions
let g = makeOGraph("myGraph");
addOGraph(g, a + b);
addOGraph(g, 5 * 6);
addOGraph(g, (a + b) * c);

// Find all expressions matching the pattern x + y
// Note: bindings parameter is explicitly typed as ast to prevent premature evaluation
let matchCount = matchOGraphPattern(g, x + y, \(bindings : ast, eclassId) -> {
	// For each match, print the bindings and the e-class ID
	let xExpr = bindings["x"];
	let yExpr = bindings["y"];
	println("Found: " + xExpr + " + " + yExpr + " at e-class " + eclassId);

	// You can use the e-class ID to modify the graph or for further processing
	// For example, to merge with another node or add domain annotations
});

println("Found " + matchCount + " matches");
```

#### `substituteWithBindings(expr: expression, bindings: ast) -> expression`

Applies variable substitutions to an expression using the provided bindings, but does not evaluate the result. This is useful for template-based code generation or symbolic manipulation where you want to substitute variables without triggering evaluation.

```orbit
// Pattern match to extract components
let pattern = quote(a + b);
let expr = quote(5 + 10);

// Manual binding creation
let bindings = [
	Pair("a", quote(5)),
	Pair("b", quote(10))
];

// Use the bindings to create a new expression
let template = quote(2 * a - b);
let result = substituteWithBindings(template, bindings);
println("Result: " + prettyOrbit(result)); // Result: 2 * 5 - 10
```

This function performs a direct syntactic substitution without evaluating the resulting expression, unlike `evalWithBindings` which also evaluates the expression after substitution. It's particularly useful for rule-based term rewriting systems where you want to control when and how substituted expressions are evaluated.

**IMPORTANT**: The `bindings` parameter must be marked as `ast` to ensure they are not prematurely evaluated.

Pattern matching is a powerful feature that enables finding and transforming expressions in the graph based on their structure. The pattern can contain concrete values (e.g., `5`, `"hello"`) and pattern variables (e.g., `x`, `y`) that match any expression.

#### Working with Pattern Matching Results

**CRITICAL**: When defining a callback for `matchOGraphPattern`, always explicitly mark the `bindings` parameter as `ast` type. This prevents premature evaluation of the bindings and ensures proper functioning when used with functions like `substituteWithBindings`.

```orbit
// CORRECT: Explicit ast typing for bindings
matchOGraphPattern(graph, pattern, \(bindings : ast, eclassId) . (
	// Now you can safely use substituteWithBindings
	let result = substituteWithBindings(replacement, bindings);
	// ...
));

// INCORRECT: Without ast typing, bindings may be prematurely evaluated
matchOGraphPattern(graph, pattern, \(bindings, eclassId) . (
	// May cause unexpected behavior
	let result = substituteWithBindings(replacement, bindings);
	// ...
));
```

#### Pattern Variables

Pattern variables in patterns are represented as identifiers (e.g., `x`, `y`, `z`) and can match any expression. When a pattern variable appears multiple times in a pattern, all occurrences must match semantically equivalent expressions.

For example, the pattern `x + x` would match expressions like `a + a` or `5 + 5`, but not `a + b` or `5 + 6`.

#### Consistency and Semantic Equivalence

When the same pattern variable appears multiple times in a pattern, the system ensures that all occurrences match semantically equivalent expressions, not just syntactically identical ones. Two nodes are considered semantically equivalent if:

1. They refer to the same node ID in the graph
2. They are variables/identifiers with the same name
3. They are literals with the same value
4. They are operations with the same operator and semantically equivalent children

This semantic equivalence checking allows for robust pattern matching even in the presence of shared structure or when expressions have been merged through equivalence relationships.

#### Variable Substitution vs. Evaluation

When working with pattern matching results, Orbit provides three complementary functions for handling variable bindings:

1. **`substituteWithBindings(expr, bindings)`**: Performs only variable substitution, replacing variables with their bound expressions without evaluating the result.
2. **`evalWithBindings(expr, bindings)`**: Both substitutes variables and evaluates the resulting expression.
3. **`unquote(expr, bindings)`**: Traverses an AST, evaluating only the parts wrapped in `eval` calls, while leaving the rest intact.

Choosing between these functions depends on your use case:

```orbit
// Example showing the difference between substitute and eval
let expr = quote(2 * x + y);
let bindings = [
	Pair("x", quote(3 + 4)),  // x is bound to the expression (3 + 4)
	Pair("y", quote(10))
];

// Just substitute variables without evaluation
let substituted = substituteWithBindings(expr, bindings);
println(prettyOrbit(substituted));  // Output: 2 * (3 + 4) + 10

// Substitute and evaluate
let evaluated = evalWithBindings(expr, bindings);
println(prettyOrbit(evaluated));    // Output: 24 (because 2 * 7 + 10 = 24)

// Selective evaluation with unquote
let template = quote(2 * eval(x) + y);  // Only evaluate the x part
let selectively = unquote(template, bindings);
println(prettyOrbit(selectively));  // Output: 2 * 7 + 10 (only x was evaluated)
```

#### `unquote(expr: expression, bindings: ast) -> expression`

Traverses an abstract syntax tree and selectively evaluates only the parts wrapped in `eval` calls, while preserving the structure of the rest of the expression. This provides fine-grained control over which parts of an expression are evaluated versus which parts remain as syntax.

```orbit
// Create a template with selective evaluation
let template = quote(
	let x = 3 + 4;
	let y = eval(2 * x);
	[x, y, eval(x + y), multiplier]
);

// Bindings for any variables that might be in the template
let bindings = quote([
	Pair("multiplier", 2)
]);

// Process the template, evaluating only the eval parts
let result = unquote(template, bindings);
println("Result: " + prettyOrbit(result));
// Result: { let x = 3 + 4; let y = 14; [x, y, 21, 2] }
```

The `unquote` function is particularly useful for template metaprogramming where you want most of an expression to remain as syntax (quoted), with only specific parts evaluated. This provides selective evaluation similar to quasiquotation in Lisp/Scheme but with more fine-grained control.

These distinctions are particularly important in rewriting systems where you may want to:

1. **Preserve Structure**: Use `substituteWithBindings` when you want to preserve the structure of expressions for further pattern matching or when building templates.

2. **Compute Results**: Use `evalWithBindings` when you want to compute concrete results or perform simplification.

3. **Selective Evaluation**: Use `unquote` when you need fine-grained control over which parts of an expression to evaluate, especially in template metaprogramming or complex rewriting systems.

Here's a comparison of all three functions with the same input:

```orbit
// Setup
let expr = quote(2 * x + y);
let bindings = [
	Pair("x", quote(3 + 4)),  // x is bound to the expression (3 + 4)
	Pair("y", quote(10))
];

// 1. substituteWithBindings - only replaces variables
let substituted = substituteWithBindings(expr, bindings);
println(prettyOrbit(substituted));  // Output: 2 * (3 + 4) + 10

// 2. evalWithBindings - substitutes and evaluates everything
let evaluated = evalWithBindings(expr, bindings);
println(prettyOrbit(evaluated));    // Output: 24 (because 2 * 7 + 10 = 24)

// 3. unquote - selective evaluation with 'eval' markers
let template = quote(2 * x + eval(y + 5));
let selectively = unquote(template, bindings);
println(prettyOrbit(selectively));  // Output: 2 * (3 + 4) + 15 (only "y + 5" was evaluated)
```

For example, in a rule-based rewriting system, you might use `substituteWithBindings` to generate the right-hand side of a rule with bindings from a matched left-hand side, preserving the structure for further transformations.

#### Pattern Matching Use Cases

Pattern matching is fundamental to many O-Graph operations, particularly:

1. **Rule Application**: Finding subexpressions that match the left-hand side of rewrite rules
2. **Query and Analysis**: Extracting parts of expressions that match certain patterns
3. **Domain Inference**: Identifying expressions that should be associated with domains
4. **Optimization**: Recognizing patterns that can be optimized (e.g., `a * 0 => 0`)

The callback-based API allows for flexible processing of matches without building up large intermediate data structures.

### Visualization

#### Graphviz: `ograph2dot(graphName: string) -> string`

Generates a GraphViz DOT format representation of the O-Graph, which can be visualized using GraphViz tools.

```orbit
let dotCode = ograph2dot(g);

// You can save this to a file and visualize with GraphViz
// e.g., write to file and then use: dot -Tpng graph.dot -o graph.png
```

## Example: Commutative Property

Here's a complete example showing how to use O-Graphs to represent the commutative property of addition (a + b = b + a):

```orbit
// Create a new graph
let g = makeOGraph("commutative");

// Add the expressions a + b and b + a
let expr1 = addOGraph(g, a + b);
let expr2 = addOGraph(g, b + a);

// Establish that they are equivalent
mergeOGraphNodes(g, expr1, expr2);

// Add domain information
let algebraDomain = addOGraph(g, Algebra);
addDomainToNode(g, expr1, algebraDomain);

// Generate DOT output for visualization
let dotCode = ograph2dot(g);
println(dotCode);
```

## Theoretical Foundation: Domains and Symmetry Groups

At the heart of our system lies the insight that computational domains themselves—whether programming languages, algebraic structures, or formal systems—should be first-class citizens in the rewriting process. In the O-Graph, such structures are represented simply as terms within the language. The intention is for users to structure these domain terms into a hierarchy, ideally forming a partial order or lattice (e.g., `Integer ⊂ Real ⊂ Complex`). This hierarchical structure allows the system to apply rewrite rules and reasoning defined at more abstract domain levels (like `Ring`) to expressions belonging to more specific sub-domains (like `Integer`), thereby maintaining the system's expressive power while enabling high-level optimization and transformation strategies.

By representing domains and structures explicitly within our O-Graph structure, we enable:

1. **Cross-Domain Reasoning**: Values can exist simultaneously in multiple domains through domain annotations.
2. **Hierarchical Rule Application**: Rules defined for parent domains apply to child domains.
3. **Canonical Representations**: Each domain can leverage its natural symmetry group for canonicalization.
4. **Deep Algebraic Structures**: The system automatically discovers and exploits algebraic properties.

For example, addition exhibits symmetry group S₂ (the symmetric group of order 2), which captures commutativity. When we encounter expressions like `a + b` in any language associated with a domain where addition is commutative (like `Real` or `Integer`), the system can automatically canonicalize to a standard form based on this algebraic property, thus avoiding redundant representations.

This approach can be clearly seen in rules that explicitly assign symmetry properties:

```orbit
// Define symmetry properties using domain annotations
a : Real + b : Real ⊢ + : S₂;  // The + operation belongs to the S₂ symmetry group
a : Real * b : Real ⊢ * : S₂;  // The * operation belongs to the S₂ symmetry group

// Rotation operations have cyclic group structure
rotate : C₄;  // Rotation operation belongs to cyclic group of order 4
rotate(rotate(rotate(rotate(arr, 1), 1), 1), 1) => arr;  // Four rotations is identity
```

## Native OGraph Integration

Orbit provides a native interface to the OGraph system, enabling direct manipulation of abstract syntax trees and powerful rewriting capabilities. The core API is centered around the `orbit` function:

```orbit
// Main function: Takes rewrite rules, cost function, and expression to optimize
fn orbit(rules : ast, cost : (expr : ast) -> double, expr : ast) : ast = (
	// Create a new ograph
	let graph = makeOGraph();

	// Add the expression to optimize to the graph
	let nodeId = addOGraph(graph, expr);

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

## Orbit Rewriting System: Operator Semantics

The Orbit Rewriting System uses domain annotations to express relationships between expressions across different domains. Below is a detailed explanation of the operators and their semantics in the O-Graph context:

| Operator | ASCII Alternative | O-Graph Interpretation | Semantic Meaning | Example | Node Relationship Behavior |
|----------|------------------|------------------------|------------------|---------|---------------------------|
| `:` | `:` | Domain annotation | In patterns: Constrains matches to the specified domain. In results: Asserts the expression belongs to the domain. | `x : Algebra` | Adds the domain `Algebra` to the "belongs to" field of node `x`. |
| `!:` | `!:` | Negative Domain Constraint | In patterns: Constrains matches to nodes that *do not* belong to the specified domain/annotation. | `x !: Processed => ...` | Checks if the node `x`'s "belongs to" field *does not* contain `Processed`. Match succeeds only if the domain/annotation is absent. |
| `⇒` | `=>` | Rewrite rule | Converts an expression from one form to another, potentially across domains. | `a + b : JavaScript => a + b : Python` | Creates a node for `a + b` that belongs to the `JavaScript` domain, and another node for `a + b` that belongs to the `Python` domain, and then merges these eclasses, with the root being the original. |
| `⇔` | `<=>` | Equivalence | Declares bidirectional equivalence between patterns, preserving domain membership. | `x * (y + z) : Algebra <=> (x * y) + (x * z) : Algebra` | Creates nodes for both expressions and marks them as equivalent, with the root being the original. |
| `⊢` | `\|-` | Entailment | When the left pattern matches, the right side domain annotation is applied. | `a : Field + b : Field \|- + : S₂` | When a matching expression is found, the `+` operator node has domain `S₂` added to it. |
| `⊂` | `c=` | Subset relation | Indicates domain hierarchy, automatically applying parent domain memberships to children. | `Integer c= Real` | Establishes that any node belonging to the `Integer` domain also implicitly belongs to the `Real` domain. |

In the O-Graph implementation, each node maintains a "belongs to" field that tracks which domains or annotations it belongs to. The operators above define how domains are added to nodes and how nodes relate to each other.

The key conventions used throughout O-Graph rules include:

- Lowercase letters (a, b, c, x, y, z) represent pattern variables that match arbitrary expressions
- Uppercase letters (A, B, C) typically represent terms, domain labels, or specific structures

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

## A Note on Terminology: The Concept of "Domain"

A key feature in Orbit is the ability to associate expressions with descriptive terms using the `:` operator (e.g., `x : Real` or `myList : list<int>`). Within the Orbit system, we generally refer to these associated terms (`Real`, `list<int>`, etc.) as **Domains**.

We acknowledge that this term is used broadly here to encompass several related concepts that might traditionally have different names:

*   **Mathematical Domains/Structures:** e.g., `Integer`, `Real`, `Field`, `AbelianGroup`, symmetry groups like `S₂`.
*   **Types:** e.g., `int`, `string`, `list<float>`, `map<string, bool>`, function types like `(int) -> string`.
*   **Effects or Computational Properties:** e.g., `Pure` (no side effects), `IO` (performs input/output), `Total` (guaranteed to terminate).
*   **Semantic States or Tags:** e.g., `Canonical`, `Simplified`, `Processed`, `Solutions`.
*   **Other Annotations:** Any term used to classify or describe an expression for rewriting or analysis purposes.

The choice of "Domain" as the unifying term stems from Orbit's operational perspective. Often, the system *infers* these properties or classifications for expressions during rewriting and analysis. An expression is thus seen as existing *within* one or more of these inferred "Domains". This unified concept simplifies the core rewriting mechanism, allowing rules to operate based on these classifications regardless of whether they represent a traditional mathematical domain, a type, an effect, or a specific state.

Orbit's group-theoretic approach unifies several powerful mathematical frameworks:

1. **Group Theory**: For capturing symmetries and canonical forms
2. **Category Theory**: For formalizing transformations between domains  
3. **Order Theory**: For determining canonical representatives
4. **Universal Algebra**: For detecting properties like associativity and commutativity

By representing symmetry groups explicitly in the ograph structure (via domain annotations), we achieve exponential reduction in equivalent expressions, automatic discovery of optimizations that exploit symmetry, and transfer of optimizations across domains with isomorphic group structures.

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
fn expressionCost(expr : ast) -> double = (
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
fn main() = (
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
fn solveQuadratic(expr : ast) -> ast = (
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
fn main() = (
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

**For detailed information about more examples of group notation, and canonicalization constructs, please refer to the [canonical.md](canonical.md) document**.

## Conclusion

Orbit provides a powerful platform for working with symbolic expressions, mathematical rewriting, and cross-domain transformations. Its native OGraph integration and domain annotation system enable sophisticated program optimization and transformation capabilities while maintaining a clean, functional programming model.

The ability to express and solve problems in domains like polynomial equations demonstrates the power of combining group theory with computational rewriting. By bridging the gap between mathematical formalism and practical programming, Orbit enables new approaches to challenging computational problems through group-theoretic reasoning, domain-crossing transformations, and cost-driven optimization.