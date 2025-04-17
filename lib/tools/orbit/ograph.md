# E-Graphs in Orbit

This document describes the E-graph functionality available in the Orbit language.

## Overview

E-graphs (Equality Graphs) are a data structure that efficiently represents equivalence classes of expressions. They are used in term rewriting systems, theorem provers, and optimizing compilers to efficiently reason about equality between expressions.

In Orbit, E-graphs are accessible through a set of runtime functions that allow you to:

1. Create and manage E-graphs
2. Add expressions and establish equivalences
3. Associate expressions with domains
4. Extract and visualize the graph structure

## Available Runtime Functions

### Graph Creation and Management

#### `makeOGraph(name: string) -> string`

Creates a new, empty E-graph with the given name and returns the name.

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

### Establishing Equivalences

#### `mergeOGraphNodes(graphName: string, nodeId1: int, nodeId2: int) -> bool`

Merges two nodes to represent that they are equivalent expressions. Returns true if successful.

```orbit
// Establish that a + b is equivalent to c - d
let n1 = addOGraph(g, a + b);
let n2 = addOGraph(g, c - d);
mergeOGraphNodes(g, n1, n2);
```

The first node will be the new root.

### Domain Associations

#### `addDomainToNode(graphName: string, nodeId: int, domainId: int) -> bool`

Associates a node with a domain node, which can be any expression in the E-graph. Returns true if successful.

```orbit
// Add the expression a + b
let exprId = addOGraph(g, a + b);

// Add the domain expression S_2
let domainId = addOGraph(g, S_2);

// Associate the expression with the domain
addDomainToNode(g, exprId, domainId);
```

This allows associating expressions with arbitrary domain expressions.

### Visualization

#### Graphviz: `ograph2dot(graphName: string) -> string`

Generates a GraphViz DOT format representation of the E-graph, which can be visualized using GraphViz tools.

```orbit
let dotCode = ograph2dot(g);

// You can save this to a file and visualize with GraphViz
// e.g., write to file and then use: dot -Tpng graph.dot -o graph.png
```

## Example: Commutative Property

Here's a complete example showing how to use E-graphs to represent the commutative property of addition (a + b = b + a):

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
