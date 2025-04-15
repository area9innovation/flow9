# Native Orbit API for OGraph Optimization

This document outlines a design for a native API to the Orbit OGraph, leveraging its AST capabilities and direct interface with the ograph instead of using Mango for connecting different syntaxes.

## Core API Design

Here's how the API could be structured, centered around the `orbit` function that optimizes expressions using rewrite rules:

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

## Supporting Types and Functions

```orbit
// Extract the optimal expression from a graph based on a cost function
fn extractOptimal(graph : OGraph, cost : (ast) -> double) -> ast (
	let rootClasses = getRootClasses(graph);

	// For each equivalence class, find the node with minimum cost
	fold(rootClasses, (expr: nullAst(), cost: inf()), \best, classId -> (
		let nodes = getNodesInClass(graph, classId);
		let classBest = fold(nodes, (expr: nullAst(), cost: inf()), \b, node -> (
			let expr = nodeToExpr(graph, node);
			let nodeCost = cost(expr);
			if (nodeCost < b.cost) (expr: expr, cost: nodeCost)
			else b
		));

		if (classBest.cost < best.cost) classBest
		else best
	)).expr
)
```

## Example Usage

Here's how you might use this API to optimize mathematical expressions:

```orbit
fn quote(e : ast) = e;

// Define some rewrite rules for algebraic simplification
let algebraRules = quote(
	// Commutativity: 
	a + b => b + a;
	a * b => b * a;

	// Identity: 
	a + 0 => a;
	1 * a <=> a;

	// Zero: 
	a * 0 => 0;

	// Distribution: 
	a * (b + c) <=> (a * b) + (a * c);
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
	// Expression:
	let expr = quote((2 * x + 3 * x) * (y + z) - (0 * w));

	println("Original: " + prettyOrbit(expr));

	// Apply optimization
	let optimized = orbit(algebraRules, expressionCost, expr);

	println("Optimized: " + prettyOrbit(optimized));

	// Expected output: 5 * x * (y + z)
)
```
