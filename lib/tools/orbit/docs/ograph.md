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
  - Domain annotations in the expression (using `:` syntax) are processed automatically during addition.
  - Greatly improves efficiency by avoiding conversion between OGraph and OrMath_expr representations.

- **Usage Example:**
  ```orbit
	let g = makeOGraph("myGraph");

	// Add base expressions
	let x_id = addOGraph(g, 5);
	let y_id = addOGraph(g, 10);

	// Create a template with variables
	let template = quote(a * b);

	// Add the template with substitutions
	let bindings = [Pair("a", x_id), Pair("b", y_id)];
	let result_id = addOGraphWithSub(g, template, bindings);

	// This effectively adds (5 * 10) to the graph
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
  The node ID (as integer) of a node in the graph that is *structurally equal* to `expr`, or -1 if no such node exists. If the term was just added, this will match the inserted node's ID.

- **Usage Example:**
  ```orbit
	let g = makeOGraph("myGraph");
	let x_id = addOGraph(g, quote(foo(bar, 7)));
	let found = findOGraphId(g, quote(foo(bar, 7)));   // returns x_id
	let not_found = findOGraphId(g, quote(nonexistent())); // returns -1
```

- **Notes:**
  - "Structurally equal" means the term's tree shape and content matches, regardless of canonicalization or node IDs.

### Establishing Equivalences

#### O-Graph Canonicalization and Equivalence Classes

When working with O-Graphs, understanding how canonicalization works is critical. When expressions are merged to represent equivalence, one expression is designated as the **representative** or "root" of the equivalence class (e-class). This is achieved mechanically using the `mergeOGraphNodes` function.

When you later extract an expression from an e-class using functions like `extractOGraph`, you'll always get the *current representative* of that class. Crucially, through the process of **equality saturation** (repeatedly applying rewrite rules until no more changes occur), this representative node is driven towards the *true canonical form* as defined by the system's rules (e.g., sorting operands for commutativity, applying specific normal forms). Rules intended to produce such canonical forms might be marked with the `: Canonical` annotation to indicate their purpose.

#### `mergeOGraphNodes(graphName: string, nodeId1: int, nodeId2: int) -> bool`

Merges two nodes (and their respective e-classes) to represent that they are equivalent expressions. Returns true if successful, false if they were already in the same class.

```orbit
// Establish that a + b is equivalent to c - d
let n1 = addOGraph(g, a + b);
let n2 = addOGraph(g, c - d);
mergeOGraphNodes(g, n1, n2);
```

**IMPORTANT**: The order of nodeIds matters! The first node (`nodeId1`) becomes the **designated representative (root)** of the merged equivalence class. During equality saturation, rewrite rules (potentially marked with `: Canonical` to indicate their purpose, like `expr => canonical_expr : Canonical`) transform expressions within an e-class. When merging the result of such a canonicalizing rule (`resultId`) with the original node (`eclassId`), using `mergeOGraphNodes(resultId, eclassId)` ensures the *intended* canonical form becomes the designated representative. The saturation process then guarantees that this representative eventually converges to the unique canonical form defined by the system's rules and ordering criteria.

```orbit
// Pattern matching and rewriting example demonstrating root selection
matchOGraphPattern(graph, pattern, \(bindings : ast, eclassId) . (
	// Process the replacement to get the intended canonical result
	let canonical_result = substituteWithBindings(replacement_template, bindings); // replacement might be marked : Canonical

	// Add the canonical result to the graph
	let canonicalId = processDomainAnnotations(graph, canonical_result); // Ensures domains are added

	// Make the canonical result the representative of the merged class
	// By putting its ID first, we designate it as the root.
	mergeOGraphNodes(graph, canonicalId, eclassId);
));
```

### Domain Associations

#### `addDomainToNode(graphName: string, nodeId: int, domainId: int) -> bool`

Associates a node (specifically, its e-class) with a domain node, which can be any expression in the O-Graph. Returns true if successful. This adds the `domainId` to the `belongsTo` set of the node's e-class.

```orbit
// Add the expression a + b
let exprId = addOGraph(g, a + b);

// Add the domain expression S_2
let domainId = addOGraph(g, S_2);

// Associate the expression's e-class with the domain S_2
addDomainToNode(g, exprId, domainId);
```

This allows associating expressions with arbitrary domain expressions, representing types, properties, or group memberships.

### Pattern Matching

#### `matchOGraphPattern(graphName: string, pattern: expression, callback: (bindings: ast, eclassId: int) -> void) -> int`

Searches for all occurrences of a pattern in the graph and calls the provided callback for each match, passing a map of variable bindings (variable name -> eclass ID) and the e-class ID of the matched node's root. Returns the number of matches found.

**IMPORTANT**: The `bindings` parameter in the callback function must be marked as `ast` to ensure the bindings are not prematurely evaluated. This typing is crucial for proper functionality when using these bindings with functions like `substituteWithBindings`.

```orbit
// Create a graph with some expressions
let g = makeOGraph("myGraph");
addOGraph(g, a + b);
addOGraph(g, 5 * 6);
addOGraph(g, (a + b) * c);

// Find all expressions matching the pattern x + y
// Note: bindings parameter is explicitly typed as ast
let matchCount = matchOGraphPattern(g, quote(x + y), \(bindings : ast, eclassId) -> {
	// For each match, print the bindings and the e-class ID
	let xId = bindings["x"]; // eclass ID for the expression matched by x
	let yId = bindings["y"]; // eclass ID for the expression matched by y
	println("Found match for x + y in e-class " + i2s(eclassId));
	println("  x matched e-class: " + i2s(xId));
	println("  y matched e-class: " + i2s(yId));

	// Example: Rewrite x + y to y + x (assuming + is commutative)
	let replacement = quote(y + x);
	let resultId = addOGraphWithSub(g, replacement, bindings); // Use bindings directly

	// Merge, making the new form the representative
	mergeOGraphNodes(g, resultId, eclassId);
});

println("Found " + i2s(matchCount) + " matches");
```

**Direct Access to Eclass IDs**: The `bindings` map passed to the callback contains variable name → eclass ID mappings, allowing you to work directly with the graph structure efficiently.

#### `substituteWithBindings(expr: expression, bindings: ast) -> expression`

Applies variable substitutions to an expression using the provided bindings map (variable name -> AST/eclass ID), but does **not** evaluate the result. This is useful for template-based code generation or symbolic manipulation where you want to substitute variables without triggering evaluation. It performs a direct syntactic substitution.

```orbit
// Pattern match to extract components
let pattern = quote(a + b);
let expr_to_match = quote(5 + 10);
// Assuming pattern matching produces:
let bindings = [ Pair("a", 5), Pair("b", 10) ]; // Simplified binding representation for example

// Use the bindings to create a new expression from a template
let template = quote(2 * a - b);
let result_ast = substituteWithBindings(template, bindings);
println("Result AST: " + prettyOrbit(result_ast)); // Result AST: 2 * 5 - 10
```

**IMPORTANT**: The `bindings` parameter must be marked as `ast`.

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
let bindings = [ Pair("multiplier", 2) ];

// Process the template
let result = unquote(template, bindings);
println("Result: " + prettyOrbit(result));
// Result: { let x = 3 + 4; let y = 14; [x, y, 21, 2] }
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

**Reads the entire content of a file as a string.**

- **Parameters:**
  - `path`: The path to the file to read.

- **Returns:**  
  The entire content of the file as a string.

- **Notes:**
  - Returns an empty string if the file does not exist or cannot be read.

#### `setFileContent(path: string, content: string) -> bool`

**Writes content to a file, creating the file if it doesn't exist.**

- **Parameters:**
  - `path`: The path to the file to write.
  - `content`: The string content to write to the file.

- **Returns:**  
  Boolean indicating success (true) or failure (false).

- **Notes:**
  - Overwrites the file if it already exists.
  - Creates parent directories if they don't exist.

### Program Environment & Code Manipulation

#### `getCommandLineArgs() -> [string]`

**Retrieves command line arguments passed to the Orbit program.**

- **Parameters:** None

- **Returns:**  
  An array of strings containing the command line arguments.

- **Usage Example:**
  ```orbit
	// Process command line arguments
	let args = getCommandLineArgs();
	println("Command line arguments: " + args);

	// Check for specific flags
	let verbose = contains(args, "--verbose");
	let help = contains(args, "--help");

	if (help) {
		printHelp();
	} else {
		// Process remaining arguments
		for (arg in args) {
			if (arg != "--verbose" && !startsWith(arg, "--")) {
				processFile(arg);
			}
		}
	}
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
	if (parseResult.second != "") {
		println("Parse error: " + parseResult.second);
	} else {
		// Successfully parsed - now can evaluate, transform, or analyze
		let ast = parseResult.first;
		println("AST: " + prettyOrbit(ast));

		// Evaluate the parsed expression
		let result = eval(ast);
		println("Result: " + result);  // Prints 7
	}
```

- **Advanced Example - Dynamic Code Generation:**
  ```orbit
	// Generate code dynamically
	fn generateFunction(name, argNames, body) {
		let functionCode = "fn " + name + "(" + strJoin(argNames, ", ") + ") = (\n";
		functionCode = functionCode + "  " + body + "\n)";

		// Parse the generated code
		let parsed = parseOrbit(functionCode);
		if (parsed.second != "") {
			println("Error generating function: " + parsed.second);
			None();
		} else {
			Some(parsed.first);
		}
	}

	// Use the generator
	let squareFn = generateFunction("square", ["x"], "x * x");
```

- **Notes:**
  - Enables meta-programming capabilities within Orbit programs.
  - Useful for code generation, domain-specific languages, and dynamic evaluation.
  - Can be combined with `eval` to implement interpreters or compilers in Orbit itself.
  - Makes it possible to load and parse Orbit code at runtime from external sources.

### AST Introspection and Manipulation

#### `astname(expr: expression) -> string`

**Returns the canonical name of an AST node, allowing for type checking and introspection.**

- **Parameters:**
  - `expr`: The expression to inspect.

- **Returns:**  
  A string representing the canonical name of the expression's node type (e.g., "Int", "Variable", "+", "call", etc.).

- **Usage Example:**
  ```orbit
	// Check the type of an expression
	let x = 42;
	let name = astname(x);  // Returns "Int"

	// Implement type predicates
	fn is_number(expr) = (astname(expr) == "Int" || astname(expr) == "Double");
	fn is_var(expr) = (astname(expr) == "Variable" || astname(expr) == "Identifier");

	// Use in pattern matching
	fn process(expr) = (
		expr is (
			x if is_number(x) => x * 2;
			x if is_var(x) => lookup(x);
			_ => expr;
		)
	);
```

- **Notes:**
  - Particularly useful for implementing type predicates and pattern guards
  - Returns operator names for operations (e.g., "+", "*", "=")
  - For function calls, returns "call"

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
// Save dotCode to a file (e.g., graph.dot)
// Visualize using: dot -Tpng graph.dot -o graph.png
```

## Example: Commutative Property

Here's a complete example showing how to use O-Graphs to represent the commutative property of addition (`a + b = b + a`):

```orbit
// Create a new graph
let g = makeOGraph("commutative_example");

// Add the expressions a + b and b + a
let expr1_node = addOGraph(g, a + b);
let expr2_node = addOGraph(g, b + a);

// Add domain information: mark the '+' operation as having S₂ symmetry
// Assuming '+' operator itself can be represented/found
let plus_op_node = findOGraphId(g, quote(+)); // Need a way to represent operators
let s2_domain_node = addOGraph(g, quote(S₂));
if (plus_op_node != -1 && s2_domain_node != -1) {
	addDomainToNode(g, plus_op_node, s2_domain_node);
}

// Find the canonical form according to S₂ (sorting) rule
let canonical_form = if compare(a, b) <= 0 then quote(a + b) else quote(b + a);
let canonical_id = addOGraph(g, canonical_form);

// Establish that both original expressions are equivalent to the canonical form
// Make the canonical form the representative root.
mergeOGraphNodes(g, canonical_id, expr1_node);
mergeOGraphNodes(g, canonical_id, expr2_node);

// Add a property domain to the canonical class
let algebra_domain_node = addOGraph(g, quote(Algebra));
addDomainToNode(g, canonical_id, algebra_domain_node);

// Generate DOT output for visualization
let dotCode = ograph2dot(g);
println(dotCode); // Visualize to see expr1 and expr2 merged under canonical_id
```

## Theoretical Foundation: Domains and Symmetry Groups

At the heart of our system lies the insight that computational domains themselves—whether programming languages, algebraic structures, or formal systems—should be first-class citizens in the rewriting process. In the O-Graph, such structures are represented simply as terms within the language. The intention is for users to structure these domain terms into a hierarchy, ideally forming a partial order or lattice (e.g., `Integer ⊂ Real ⊂ Complex`). This hierarchical structure allows the system to apply rewrite rules and reasoning defined at more abstract domain levels (like `Ring`) to expressions belonging to more specific sub-domains (like `Integer`), thereby maintaining the system's expressive power while enabling high-level optimization and transformation strategies.

By representing domains and structures explicitly within our O-Graph structure, we enable:

1.  **Cross-Domain Reasoning**: Values can exist simultaneously in multiple domains through domain annotations.
2.  **Hierarchical Rule Application**: Rules defined for parent domains apply to child domains.
3.  **Canonical Representations**: Each domain can leverage its natural symmetry group for canonicalization.
4.  **Deep Algebraic Structures**: The system automatically discovers and exploits algebraic properties.

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

The ability to express and solve problems in domains like polynomial equations demonstrates the power of combining group theory with computational rewriting. The included `lib/rewrite` library further simplifies the implementation of domain-aware rewriting systems by enforcing the correct sequence of operations (substitution → domain processing → merging).

By bridging the gap between mathematical formalism and practical programming, Orbit enables new approaches to challenging computational problems through group-theoretic reasoning, domain-crossing transformations, and cost-driven optimization.
