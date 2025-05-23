# O-Graphs in Orbit

This document describes the O-Graph library available in the Orbit language.

## Overview

O-Graphs (Orbit Graphs) are a data structure that efficiently represents equivalence classes of expressions similar to E-graphs (Equivalence Graphs). They are used in term rewriting systems, theorem provers, and optimizing compilers to efficiently reason about equality between expressions.

O-Graphs are a relative of E-Graphs. The main innovations are that each e-class can belong to other e-classes. The other main difference is that we let the root of an e-class be the representative of that e-class. These innovations combine to allow new capabilities as discussed further below.

In Orbit, O-Graphs are accessible through a set of runtime functions that allow you to:

1. Create and manage O-Graphs
2. Add expressions and establish equivalences
3. Associate expressions with domains
4. Extract and visualize the graph structure

These are packaged in a nice rewriting package in the `lib/rewrite.orb` file. TODO: Rewrite only implements =>. Not the other operators yet.

## Available Runtime Functions

### Graph Creation and Management

#### `makeOGraph(name: string) -> string`

Creates a new, empty O-Graph with the given name and returns the name.

```orbit
let g = makeOGraph("myGraph");
```

### Adding Expressions

#### `addOGraph(graphName: string, expr: expression) -> int`

Recursively adds an entire expression tree to the graph and returns the ID of the root node. **Note:** When lowering to SExpr, associative and commutative operations (like `+`, `*`, `&&`, `||`) are automatically flattened to n-ary S-expression representation for efficient canonicalization and pattern matching.

```orbit
// Adding nested binary associative ops - automatically flattened during lowering
let exprId = addOGraph(g, (a + b) + c);
// Automatically converted to `+`(a, b, c) in the S-expression backend

// Adding complex nested expressions - fully flattened automatically
let complexId = addOGraph(g, a + b + c + (d + e) + f);
// Automatically converted to `+`(a, b, c, d, e, f) in the S-expression backend

// Direct n-ary S-expression (equivalent)
let exprIdNary = addOGraph(g, `+`(a, b, c));
```

This adds all nodes in the expression tree, automatically flattening all nested A/C operations into their n-ary S-expression form during the Orbit-to-SExpr conversion.

The `extractOGraph` function retrieves the expression, potentially reconstructing a binary tree structure from the canonical n-ary form for user-facing representation.

```orbit
// Now we can extract the expression from the graph
let expr = extractOGraph(g, exprId); // Might return (a + b) + c or a + (b + c)
```

#### `addOGraphWithSub(graphName: string, expr: expression, bindings: [Pair<string, int>]) -> int`

**Adds an expression to the graph with variable substitution using eclass IDs.**

- **Parameters:**
  - `graphName`: The name of the O-Graph (as a string).
  - `expr`: The expression to add, which may contain variables to be substituted.
  - `bindings`: An array of Pair<string, int> where the string is a variable name and the int is an eclass ID to substitute.

- **Returns:**  
  The eclass ID of the resulting expression.

- **Behavior:**
  - Any variable in the expression that has a matching name in the bindings will be replaced with the corresponding eclass ID.
  - Automatically flattens all nested associative operations during Orbit-to-SExpr lowering (e.g., `a+b+c+(d+e)+f` becomes `+`(a,b,c,d,e,f)).
  - Domain annotations in the expression (using `:` syntax) are processed automatically during addition.
  - Greatly improves efficiency by avoiding conversion between OGraph and OrMath_expr representations.

- **Usage Example:**
```orbit
	let g = makeOGraph("myGraph");

	// Add base expressions
	let x_id = addOGraph(g, 5);
	let y_id = addOGraph(g, 10);

	// Create a template with variables
	let template = quote(a * b); // Or potentially `*`(a, b)

	// Add the template with substitutions
	let bindings = [Pair("a", x_id), Pair("b", y_id)];
	let result_id = addOGraphWithSub(g, template, bindings);

	// This effectively adds the S-expression (* 5 10) to the graph
	// The result_id points to the node representing this expression
```

- **Notes:**
  - Particularly useful after pattern matching, as it works directly with the eclass IDs returned by `matchOGraphPattern`.
  - Performs more efficiently than adding a substituted expression with `addOGraph` because it avoids creating intermediate OrMath_expr objects.
  - Automatically handles domain annotations, making it ideal for rewriting systems.

#### `findOGraphId(graphName: string, expr: expression) -> int`

**Finds the node ID for a structurally-equal term in the O-Graph, or returns -1 if it does not exist.**

- **Parameters:**
  - `graphName`: The name of the O-Graph (as a string).
  - `expr`: The (possibly quoted) term or expression to look for.

- **Returns:**  
  The node ID (as integer) of a node in the graph that is *structurally equal* to `expr` in its canonical internal form (potentially n-ary S-expression), or -1 if no such node exists. If the term was just added, this will match the inserted node's ID.

- **Usage Example:**
```orbit
	let g = makeOGraph("myGraph");
	let x_id = addOGraph(g, quote(foo(bar, 7)));
	let found = findOGraphId(g, quote(foo(bar, 7)));   // returns x_id
	let not_found = findOGraphId(g, quote(nonexistent())); // returns -1

	// Finding an n-ary form
	let sum_id = addOGraph(g, a + b + c); // Internally likely `+`(a, b, c)
	let found_sum = findOGraphId(g, quote(`+`(a, b, c))); // Might find sum_id
	let found_binary = findOGraphId(g, quote(a + (b + c))); // Also might find sum_id
```

- **Notes:**
  - "Structurally equal" refers to the canonical internal representation (potentially n-ary S-expression) used within the O-Graph.

### Establishing Equivalences

#### O-Graph Canonicalization and Equivalence Classes

When working with O-Graphs, understanding how canonicalization works is critical. When expressions are merged to represent equivalence, one expression is designated as the **representative** or "root" of the equivalence class (e-class). This is achieved mechanically using the `mergeOGraphNodes` function.

For associative/commutative operations represented internally as n-ary S-expressions (e.g., `(+ a b c)`), canonicalization involves sorting the argument list based on a defined order (e.g., lexicographical order of sub-expression IDs). This directly handles `Sₙ` symmetry.

When you later extract an expression from an e-class using functions like `extractOGraph`, you'll always get the *current representative* of that class. Crucially, through the process of **equality saturation** (repeatedly applying rewrite rules until no more changes occur), this representative node is driven towards the *true canonical form* as defined by the system's rules (e.g., sorted argument list for A/C ops, specific normal forms for other structures).

#### `mergeOGraphNodes(graphName: string, nodeId1: int, nodeId2: int) -> bool`

Merges two nodes (and their respective e-classes) to represent that they are equivalent expressions. Returns true if successful, false if they were already in the same class.

```orbit
// Establish that a + b is equivalent to c - d
let n1 = addOGraph(g, a + b);
let n2 = addOGraph(g, c - d);
mergeOGraphNodes(g, n1, n2);
```

### Domain Associations

#### `addDomainToNode(graphName: string, nodeId: int, domainId: int) -> bool`

Associates a node (specifically, its e-class) with a domain node, which can be any expression in the O-Graph. Returns true if successful. This adds the `domainId` to the `belongsTo` set of the node's e-class.

```orbit
// Add the expression a + b
let exprId = addOGraph(g, a + b); // Internally becomes `+`(a, b) if '+' is A/C

// Add the domain expression S_n (representing permutation symmetry for n-ary ops)
let domainId = addOGraph(g, S_n);

// Associate the expression's e-class with the domain S_n
addDomainToNode(g, exprId, domainId);
```

This allows associating expressions with arbitrary domain expressions, representing types, properties, or group memberships.

### Pattern Matching

#### `matchOGraphPattern(graphName: string, pattern: expression, callback: (bindings: ast, eclassId: int) -> void) -> int`

Searches for all occurrences of a pattern in the graph and calls the provided callback for each match, passing a map of variable bindings (variable name -> eclass ID) and the e-class ID of the matched node's root. Returns the number of matches found. Patterns involving associative/commutative operations should match against the internal n-ary S-expression representation.

**IMPORTANT**: The `bindings` parameter in the callback function must be marked as `ast` to ensure the bindings are not prematurely evaluated. This typing is crucial for proper functionality when using these bindings with functions like `substituteWithBindings`.

```orbit
// Create a graph with some expressions
let g = makeOGraph("myGraph");
addOGraph(g, a + b);             // Represents `+`(a, b) internally
addOGraph(g, 5 * 6);             // Represents `*`(5, 6) internally
addOGraph(g, (a + b) + c);       // Represents `+`(a, b, c) internally
addOGraph(g, d + (a + b + c)); // Represents `+`(d, a, b, c) internally

// Find all expressions matching the n-ary pattern `+`(args...)
// Note: bindings parameter is explicitly typed as ast
let matchCount = matchOGraphPattern(g, quote(`+`(args...)), \(bindings : ast, eclassId) -> (
	// For each match, print the bindings and the e-class ID
	let argsIdList = bindings["args"]; // eclass IDs for the arguments matched by args...
	println("Found match for `+`(args...) in e-class " + i2s(eclassId));
	println("  args matched e-class list: " + prettyOrbit(argsIdList)); // Requires list printing

	// Example: Rewrite `+`(a, b, c) to a canonical sorted form `+`(sorted(a, b, c))
	// Assuming a 'sortArgsById' function exists
	let sortedArgs = sortArgsById(graph, argsIdList);
	let replacement = quote(`+`(sortedArgs)); // Use backticks for operator name
	let resultId = addOGraphWithSub(g, replacement, []); // No variable substitution needed here

	// Merge, making the new sorted form the representative
	mergeOGraphNodes(g, resultId, eclassId);
));

// Find matches for a specific binary sub-pattern within an n-ary sum
// Note: The exact syntax for sub-pattern matching needs clarification
// Example: Match x + y where x=a, y=b within `+`(d, a, b, c)
matchOGraphPattern(g, quote(`+`(..., x, y, ...)), \(bindings: ast, eclassId) -> (
	// ... process bindings where x and y matched adjacent elements ...
));


println("Found " + i2s(matchCount) + " matches for `+`(args...)");
```

**Direct Access to Eclass IDs**: The `bindings` map passed to the callback contains variable name → eclass ID (or list of IDs for `...` patterns) mappings, allowing you to work directly with the graph structure efficiently.

#### `substituteWithBindings(expr: expression, bindings: ast) -> expression`

Applies variable substitutions to an expression using the provided bindings map (variable name -> AST/eclass ID), but does **not** evaluate the result. Performs direct syntactic substitution. **Generally superseded by `addOGraphWithSub` for efficiency.**

```orbit
// Pattern match to extract components
let pattern = quote(`+`(a, b)); // Matches n-ary `+` with exactly 2 args
let expr_to_match = quote(5 + 10); // -> `+`(5, 10)
// Assuming pattern matching produces:
let bindings = [ Pair("a", 5), Pair("b", 10) ]; // Simplified binding representation

// Use the bindings to create a new expression from a template
let template = quote(`*`(2, a, b)); // -> `*`(2, 5, 10)
let result_ast = substituteWithBindings(template, bindings);
println("Result AST: " + prettyOrbit(result_ast)); // Result AST: `*`(2, 5, 10)
```

#### `unquote(expr: expression, bindings: ast) -> expression`

Traverses an abstract syntax tree (`expr`) and selectively evaluates only the parts wrapped in `eval(...)` calls, using the provided `bindings` for variable lookups during evaluation. It preserves the structure of the rest of the expression. This provides fine-grained control over evaluation, similar to quasiquotation.

```orbit
// Create a template with selective evaluation
let template = quote(
	let x = 3 + 4;        // This remains syntax
	let y = eval(2 * x); // This part gets evaluated using bindings
	[x, y, eval(x + y), multiplier] // x, y remain syntax, eval(...) gets evaluated
);

// Bindings for any free variables in the template or evaluated parts
let bindings = [ Pair("multiplier", 2), Pair("x", 7) ]; // Binding x for eval

// Process the template
let result = unquote(template, bindings);
println("Result: " + prettyOrbit(result));
// Result: ( let x = 3 + 4; let y = 14; [x, y, 21, 2] )
// Note: x inside eval(x+y) also uses the binding if available, otherwise uses the let-bound x.
// Here, the outer let x = 3+4 doesn't create a binding available to eval(x+y),
// so it likely uses a globally bound x or fails if x isn't bound in 'bindings'.
// A clearer example would involve bindings for x and y.

let template2 = quote([eval(varA), varB, eval(varA + varB)]);
let bindings2 = [ Pair("varA", 10), Pair("varB", 20) ];
let result2 = unquote(template2, bindings2);
println("Result 2: " + prettyOrbit(result2)); // Result 2: [10, varB, 30]
```

#### Pattern Variables

Pattern variables (lowercase identifiers like `x`, `y`) match any expression. If a variable appears multiple times (e.g., `x + x`), all occurrences must match *semantically equivalent* expressions (i.e., expressions belonging to the same e-class after canonicalization).

#### Consistency and Semantic Equivalence

The pattern matcher enforces semantic equivalence for repeated variables. Two nodes are semantically equivalent if they belong to the same e-class (i.e., their canonical roots are the same after running `find`). This ensures robust matching even with shared structures or merged classes.

### File Operations

#### `getFileContent(path: string) -> string`

**Reads the entire content of a file as a string.** Returns an empty string if the file does not exist or cannot be read.

#### `setFileContent(path: string, content: string) -> bool`

**Writes content to a file, creating the file if it doesn't exist.** Boolean indicating success (true) or failure (false). Overwrites the file if it already exists.

### Program Environment & Code Manipulation

#### `getCommandLineArgs() -> [string]`

**Retrieves command line arguments passed to the Orbit program.**

- **Usage Example:**
```orbit
	// Process command line arguments
	let args = getCommandLineArgs();
	println("Command line arguments: " + args);

	// Check for specific flags
	let verbose = contains(args, "--verbose");
	let help = contains(args, "--help");

	if (help) then
		printHelp();
	else (
		...
	)
```

- **Notes:**
  - Useful for implementing command-line tools and utilities in Orbit.
  - Particularly valuable for scripting and batch processing applications.
  - Can be combined with parsing to create Orbit-based code transformers and analyzers.

#### `parseOrbit(code: string) -> Pair<expr, string>`

**Parses Orbit code from a string into an abstract syntax tree.**

- **Parameters:**
  - `code`: A string containing Orbit code to parse.

- **Returns:**  
  A pair containing:
  - The parsed expression (AST) if successful
  - An error message string (empty if parsing succeeded)

- **Behavior:**
  - Converts Orbit code text into a structured abstract syntax tree.
  - Performs lexical analysis, parsing, and basic semantic analysis.
  - Reports syntax errors in the error message component of the result.

- **Usage Example:**
```orbit
	// Parse code dynamically
	let codeToParse = "1 + 2 * 3";
	let parseResult = parseOrbit(codeToParse);

	// Check for parsing errors
	if (parseResult.second != "") then (
		println("Parse error: " + parseResult.second);
	) else (
		// Successfully parsed - now can evaluate, transform, or analyze
		let ast = parseResult.first;
		println("AST: " + prettyOrbit(ast));

		// Evaluate the parsed expression
		let result = eval(ast);
		println("Result: " + result);  // Prints 7
	)
```

### AST Introspection and Manipulation

#### `astname(expr: expression) -> string`

**Returns the canonical name of an AST node, allowing for type checking and introspection.** For n-ary S-expressions, it returns the operator name (e.g., `"+"`, `"*"`).


#### Variable Substitution vs. Evaluation

When working with pattern matching results, Orbit provides three complementary functions for handling variable bindings:

1. **`substituteWithBindings(expr, bindings)`**: Performs only variable substitution, replacing variables with their bound expressions without evaluating the result.
2. **`evalWithBindings(expr, bindings)`**: Both substitutes variables and evaluates the resulting expression.
3. **`unquote(expr, bindings)`**: Traverses an AST, evaluating only the parts wrapped in `eval` calls, while leaving the rest intact.

#### Domain Annotations in Pattern Matching and Substitution

When working with domain annotations in pattern matching and rewriting, ensure they are correctly processed when adding results back to the graph:


### Visualization

#### Graphviz: `ograph2dot(graphName: string) -> string`

Generates a GraphViz DOT format representation of the O-Graph, which can be visualized using GraphViz tools.

```orbit
let dotCode = ograph2dot(g);
setFileContent("graph.dot", dotCode); // Save to file
// Visualize using: dot -Tpng graph.dot -o graph.png
```

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

## Example: Polynomial Equation Solving with Group Theory

(This section's core logic remains, but polynomial representation `a*x^2 + b*x + c` should internally map to S-expressions like `(+ (* a (^ x 2)) (* b x) c)` and canonicalization rules would sort these terms.)

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
	A = B <=> A - B = 0 if B != 0;

	// Combining like terms for x^2
	a*x^2 + b*x^2 <=> (a+b)*x^2;
	a*x^2 - b*x^2 <=> (a-b)*x^2;

	// Combining like terms for x
	a*x + b*x <=> (a+b)*x;
	a*x - b*x <=> (a-b)*x;

	// Combining constants
	a : Constant + b : Constant <=> $(a+b) : Constant;
	a : Constant - b : Constant <=> $(a-b) : Constant;

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
	solve x in (y : Set) => x = y;
);

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

**For detailed information about more examples of group notation, and canonicalization constructs, please refer to the [canonical.md](canonical.md) document**.

## Conclusion

Orbit provides a powerful platform for working with symbolic expressions, mathematical rewriting, and cross-domain transformations. Its native OGraph integration and domain annotation system enable sophisticated program optimization and transformation capabilities while maintaining a clean, functional programming model.

The ability to express and solve problems in domains like polynomial equations demonstrates the power of combining group theory with computational rewriting. The included `lib/rewrite` library further simplifies the implementation of domain-aware rewriting systems by enforcing the correct sequence of operations (substitution → domain processing → merging).

By bridging the gap between mathematical formalism and practical programming, Orbit enables new approaches to challenging computational problems through group-theoretic reasoning, domain-crossing transformations, and cost-driven optimization.
