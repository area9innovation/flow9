# Sudoku Solver Using Orbit and OGraph

This document outlines an approach to implementing a Sudoku solver using Orbit's powerful OGraph system, leveraging both graph theory and algebraic techniques described in the "Unlocking Sudoku's Secrets" article.

https://chalkdustmagazine.com/features/unlocking-sudokus-secrets/

## Introduction

Sudoku is a 9×9 grid puzzle where the goal is to fill each cell with digits 1-9 such that each row, column, and 3×3 sub-grid contains every digit exactly once. The mathematical foundations of Sudoku can be explored through graph theory (vertex coloring) and abstract algebra (polynomial systems). Orbit's domain-unified rewriting engine provides an elegant framework for implementing these approaches.

## Graph Theory Approach Using OGraph

### 1. Representing Sudoku as a Graph

First, we'll represent a Sudoku puzzle as a constraint graph using OGraph:

```orbit
let sudokuGraph = makeOGraph("sudoku");
```

#### Vertices (Cells)

Each of the 81 cells in the Sudoku grid corresponds to a vertex in our graph:

```orbit
// Create vertices for all 81 cells
for (row in 0..8) {
	for (col in 0..8) {
		let cellId = addOGraph(sudokuGraph, Cell(row, col));

		// Add domain for possible values (initially 1-9 for empty cells)
		let valuesDomain = addOGraph(sudokuGraph, Domain(1..9));
		addDomainToNode(sudokuGraph, cellId, valuesDomain);
	}
}
```

#### Edges (Constraints)

We add edges between cells that cannot have the same value (cells in the same row, column, or 3×3 box):

```orbit
// Add constraint edges
for (row1 in 0..8) {
	for (col1 in 0..8) {
		let cell1 = Cell(row1, col1);
		let cell1Id = findNodeId(sudokuGraph, cell1);

		for (row2 in 0..8) {
			for (col2 in 0..8) {
				if (row1 != row2 || col1 != col2) {
					let cell2 = Cell(row2, col2);
					let cell2Id = findNodeId(sudokuGraph, cell2);

					// Add edge if cells are in same row, column, or 3×3 box
					if (row1 == row2 || col1 == col2 ||
							(Math.floor(row1/3) == Math.floor(row2/3) &&
							 Math.floor(col1/3) == Math.floor(col2/3))) {
						addConstraintEdge(sudokuGraph, cell1Id, cell2Id);
					}
				}
			}
		}
	}
}
```

### 2. Domain Propagation Using Rewrite Rules

We can use Orbit's pattern matching and domain annotation to implement constraint propagation:

```orbit
// Define rewrite rules for constraint propagation
let constraintRules = quote(
	// If a cell has value N, remove N from domains of adjacent cells
	Cell(r, c) : Value(n) && Cell(r2, c2) : Domain(vals) && Adjacent(Cell(r, c), Cell(r2, c2))
		=> Cell(r2, c2) : Domain(remove(vals, n));

	// If a cell's domain has only one value, assign that value
	Cell(r, c) : Domain([n]) => Cell(r, c) : Value(n) : Solved;

	// If a value appears only once in possible domains within a unit (row, column, or box),
	// assign that value to the corresponding cell
	Cell(r, c) : Domain(vals) && UniqueValueInUnit(r, c, n)
		=> Cell(r, c) : Value(n) : Solved;
);
```

### 3. Implementing the Greedy Algorithm with Backtracking

The article describes using a greedy algorithm with backtracking for solving Sudoku. We can implement this in Orbit as follows:

```orbit
// Function to select the next cell to assign a value to (MRV heuristic)
fn selectNextCell(graph) {
	// Find cell with smallest domain that isn't solved yet
	let minDomainSize = 10;
	let bestCell = None();

	matchOGraphPattern(graph, Cell(r, c) : Domain(vals) !: Solved, \(bindings : ast, eclassId) . (
		let domainSize = length(evalWithBindings("vals", bindings));
		if (domainSize < minDomainSize) {
			minDomainSize = domainSize;
			bestCell = Some(Pair(evalWithBindings("r", bindings), evalWithBindings("c", bindings)));
		}
	));

	bestCell;
}

// Main backtracking solver
fn solveSudoku(graph) {
	// First, apply constraint propagation until fixed point
	let saturated = applyRulesToSaturation(graph, constraintRules);

	// Check if puzzle is solved
	let solved = true;
	matchOGraphPattern(saturated, Cell(r, c) !: Solved, \(bindings : ast, eclassId) . (
		solved = false;
	));

	if (solved) {
		return true;
	}

	// Select cell with fewest possibilities
	let nextCell = selectNextCell(saturated);
	if (nextCell == None()) {
		return false; // No valid assignments possible
	}

	let row = nextCell.value.first;
	let col = nextCell.value.second;

	// Get possible values for this cell
	let possibleValues = [];
	matchOGraphPattern(saturated, Cell(r, c) : Domain(vals), \(bindings : ast, eclassId) . (
		if (evalWithBindings("r", bindings) == row && evalWithBindings("c", bindings) == col) {
			possibleValues = evalWithBindings("vals", bindings);
		}
	));

	// Try each possible value
	for (val in possibleValues) {
		// Create a copy of the graph for this branch
		let branchGraph = copyOGraph(saturated);

		// Assign the value
		let cellId = findNodeId(branchGraph, Cell(row, col));
		let valueNode = addOGraph(branchGraph, Value(val));
		addDomainToNode(branchGraph, cellId, valueNode);
		let solvedNode = addOGraph(branchGraph, Solved);
		addDomainToNode(branchGraph, cellId, solvedNode);

		// Recursively solve
		if (solveSudoku(branchGraph)) {
			// Copy solution back to original graph
			mergeOGraphs(graph, branchGraph);
			return true;
		}
	}

	return false; // No solution found
}
```

## Algebraic Approach Using Orbit

We can also implement the Gröbner basis approach described in the article using Orbit's symbolic manipulation capabilities:

### 1. Representing Sudoku as a System of Polynomials

```orbit
fn createSudokuPolynomials() {
	let polys = [];

	// Create 81 variables for each cell
	let vars = map(range(0, 81), \i.("x" + i));

	// Each cell can only take values 1-9
	for (i in 0..80) {
		let var = vars[i];
		let cellConstraint = "(" + var + "-1)*(" + var + "-2)*...*(" + var + "-9)";
		polys.push(cellConstraint);
	}

	// Each row, column, and 3×3 box must sum to 45 and have product 362880
	// Rows
	for (row in 0..8) {
		let rowVars = map(range(0, 9), \col.(vars[row*9 + col]));
		polys.push(sumPolynomial(rowVars, 45));
		polys.push(productPolynomial(rowVars, 362880));
	}

	// Columns
	for (col in 0..8) {
		let colVars = map(range(0, 9), \row.(vars[row*9 + col]));
		polys.push(sumPolynomial(colVars, 45));
		polys.push(productPolynomial(colVars, 362880));
	}

	// 3×3 boxes
	for (boxRow in 0..2) {
		for (boxCol in 0..2) {
			let boxVars = [];
			for (r in 0..2) {
				for (c in 0..2) {
					let row = boxRow*3 + r;
					let col = boxCol*3 + c;
					boxVars.push(vars[row*9 + col]);
				}
			}
			polys.push(sumPolynomial(boxVars, 45));
			polys.push(productPolynomial(boxVars, 362880));
		}
	}

	polys;
}

// Helper functions for creating sum and product polynomials
fn sumPolynomial(vars, target) {
	let sum = vars.join(" + ");
	return sum + " - " + target;
}

fn productPolynomial(vars, target) {
	let product = vars.join(" * ");
	return product + " - " + target;
}
```

### 2. Computing Gröbner Basis Using Orbit

We can implement Buchberger's algorithm for computing a Gröbner basis. This is a sophisticated algorithm, so we'll outline the key components:

```orbit
fn buchbergerAlgorithm(polys) {
	// Initialize Gröbner basis with the input polynomials
	let G = polys;
	let pairs = [];

	// Generate all pairs of polynomials
	for (i in 0..length(G)-1) {
		for (j in i+1..length(G)-1) {
			pairs.push(Pair(i, j));
		}
	}

	// Process pairs until none remain
	while (!isEmpty(pairs)) {
		let pair = pairs[0];
		pairs = tail(pairs);

		let i = pair.first;
		let j = pair.second;

		// Compute S-polynomial
		let S = sPolynomial(G[i], G[j]);

		// Reduce S with respect to G
		let r = reduce(S, G);

		if (r != 0) {
			// Add new pairs involving r
			for (k in 0..length(G)-1) {
				pairs.push(Pair(length(G), k));
			}

			// Add r to G
			G.push(r);
		}
	}

	return G;
}

// Compute S-polynomial of f and g
fn sPolynomial(f, g) {
	let ltf = leadingTerm(f);
	let ltg = leadingTerm(g);
	let lcm = leastCommonMultiple(ltf, ltg);

	return (lcm / ltf) * f - (lcm / ltg) * g;
}

// Reduce polynomial p with respect to set G
fn reduce(p, G) {
	let r = 0;
	let q = p;

	while (q != 0) {
		let reducible = false;

		for (i in 0..length(G)-1) {
			let ltg = leadingTerm(G[i]);
			let ltq = leadingTerm(q);

			if (divides(ltg, ltq)) {
				q = q - (ltq / ltg) * G[i];
				reducible = true;
				break;
			}
		}

		if (!reducible) {
			r = r + leadingTerm(q);
			q = q - leadingTerm(q);
		}
	}

	return r;
}
```

### 3. Reading Solutions from the Gröbner Basis

```orbit
fn extractSudokuSolution(groebnerBasis) {
	let solution = {};

	// If the puzzle has a unique solution, the Gröbner basis will
	// contain 81 linear polynomials of the form x_i - a_i = 0
	for (poly in groebnerBasis) {
		if (isLinear(poly)) {
			let varIndex = extractVariableIndex(poly);
			let value = extractValue(poly);
			solution[varIndex] = value;
		}
	}

	// Convert to a 9×9 grid
	let grid = [];
	for (row in 0..8) {
		let rowValues = [];
		for (col in 0..8) {
			let index = row*9 + col;
			rowValues.push(solution[index]);
		}
		grid.push(rowValues);
	}

	return grid;
}
```

## Orbit Implementation: Combining Both Approaches

We can leverage Orbit's OGraph system to implement a hybrid approach that combines both the graph-based and algebraic methods:

```orbit
fn solveSudokuWithOrbit(initialGrid) {
	// Create the OGraph
	let graph = makeOGraph("sudoku");

	// 1. Initialize the graph with cells, domains, and constraints
	initializeGraph(graph, initialGrid);

	// 2. Define rewrite rules that capture both constraint propagation
	// and algebraic reductions
	let rules = quote(
		// Graph-based constraint propagation rules
		Cell(r, c) : Value(n) && Cell(r2, c2) : Domain(vals) && Adjacent(Cell(r, c), Cell(r2, c2))
			=> Cell(r2, c2) : Domain(remove(vals, n));

		Cell(r, c) : Domain([n]) => Cell(r, c) : Value(n) : Solved;

		// Algebraic reduction rules
		Row(r) : Values(vals) => Sum(vals) : Equals(45);
		Row(r) : Values(vals) => Product(vals) : Equals(362880);

		// Combine information between domains
		Cell(r, c) : Polynomial(p) && Cell(r, c) : Domain(vals)
			=> Cell(r, c) : Domain(intersect(vals, roots(p)));
	);

	// 3. Define a cost function for the orbit optimizer
	let costFunction = \expr.(expr is (
		_ : Solved => 0.0;  // Prefer solved states
		Cell(_, _) : Domain(vals) => length(vals) * 1.0;  // Prefer smaller domains
		_ => 10.0;  // Penalize other expressions
	));

	// 4. Optimize the graph using orbit's saturation and extraction
	let solution = orbit(rules, costFunction, graph);

	// 5. Extract the solution
	return extractSolution(solution);
}
```

## Orbit's Unique Advantages for Sudoku

Orbit's rewriting system offers several unique advantages for implementing a Sudoku solver:

1. **Domain Unification**: Orbit can seamlessly integrate both the graph-theoretic and algebraic approaches to Sudoku solving.

2. **Symmetry and Canonicality**: Sudoku puzzles exhibit symmetries that Orbit can exploit through its group-theoretic approach:

```orbit
// Define symmetry properties of Sudoku using domain annotations
Sudoku : S₂;  // Sudoku has S₂ symmetry (permutation symmetry) in some aspects

// Permuting numbers 1-9 doesn't change the puzzle structure
Permute(sudoku, permutation) : SudokuSymmetry =>
	Permute(sudoku, permutation) : ValidSudoku if IsValidPermutation(permutation);
```

3. **Efficient Constraint Propagation**: OGraphs efficiently represent equivalent states, allowing for powerful constraint propagation:

```orbit
// Constraint propagation as domain annotations
Cell(r, c) : Value(v) ⊢ Row(r) : Contains(v);
Cell(r, c) : Value(v) ⊢ Column(c) : Contains(v);
Cell(r, c) : Value(v) ⊢ Box(floor(r/3), floor(c/3)) : Contains(v);

// Group sets of constraints into domains
Row(r) : Complete ⊂ Row(r) : Contains(1) ∩ ... ∩ Row(r) : Contains(9);
```

4. **Rewrite Rules for Solving Strategies**: Orbit can express common Sudoku solving techniques as rewrite rules:

```orbit
// Naked Singles
Cell(r, c) : Domain([v]) => Cell(r, c) : Value(v) : NakedSingle;

// Hidden Singles
Cell(r, c) : Domain(vals) && UniqueInUnit(r, c, v) => Cell(r, c) : Value(v) : HiddenSingle;

// Locked Candidates
Cells(cells) : SameBox & SameValue(v) & SameRow =>
	RemoveValueFromOtherCellsInRow(cells, v);
```

## Conclusion

Implementing a Sudoku solver using Orbit and OGraph provides an elegant framework that unifies graph-theoretic and algebraic approaches to the problem. By representing Sudoku constraints as domain annotations and using Orbit's powerful rewriting system, we can create a solver that efficiently combines constraint propagation with algebraic reduction techniques.

The OGraph system's ability to represent equivalent expressions, track domains, and apply rewrite rules makes it particularly well-suited for solving constraint satisfaction problems like Sudoku. By leveraging Orbit's group-theoretic foundations, we can also exploit the inherent symmetries in Sudoku puzzles to further optimize the solving process.