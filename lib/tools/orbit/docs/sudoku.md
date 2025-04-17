# Sudoku Solver Using Orbit's OGraph System

This document outlines an approach to implementing a Sudoku solver using Orbit's powerful OGraph system, integrating graph theory, algebraic techniques, and Binary Decision Diagrams (BDDs).

## Introduction

Sudoku is a 9×9 grid puzzle where the goal is to fill each cell with digits 1-9 such that each row, column, and 3×3 sub-grid contains every digit exactly once. We can approach this problem through multiple mathematical lenses:

1. **Graph Theory**: Viewing Sudoku as a vertex coloring problem
2. **Abstract Algebra**: Using Gröbner bases to solve polynomial systems
3. **Boolean Logic**: Representing constraints as Boolean formulas using BDDs

Orbit's OGraph system allows us to seamlessly integrate these approaches into a unified solver.

## Graph Theory Approach Using OGraph

### Representing Sudoku as a Graph

In the graph representation, each cell is a vertex, and constraints between cells are edges:

```flow
// Create OGraph for Sudoku
let sudokuGraph = makeOGraph("sudoku");

// Create vertices for all 81 cells
for (row in 0..8) {
	for (col in 0..8) {
		let cellId = addOGraph(sudokuGraph, Cell(row, col));

		// Add domain for possible values (initially 1-9 for empty cells)
		let valuesDomain = addOGraph(sudokuGraph, Domain(1..9));
		addDomainToNode(sudokuGraph, cellId, valuesDomain);
	}
}

// Add constraint edges between cells in same row, column, or box
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

### Domain Propagation Using Rewrite Rules

Constraint propagation is implemented through rewrite rules:

```flow
// Define rewrite rules for constraint propagation
let constraintRules = quote(
	// If a cell has value N, remove N from domains of adjacent cells
	Cell(r, c) : Value(n) && Cell(r2, c2) : Domain(vals) && Adjacent(Cell(r, c), Cell(r2, c2))
		=> Cell(r2, c2) : Domain(remove(vals, n));

	// If a cell's domain has only one value, assign that value
	Cell(r, c) : Domain([n]) => Cell(r, c) : Value(n) : Solved;

	// If a value appears only once in possible domains within a unit,
	// assign that value to the corresponding cell
	Cell(r, c) : Domain(vals) && UniqueValueInUnit(r, c, n)
		=> Cell(r, c) : Value(n) : Solved;
);
```

### Implementing Backtracking Search

```flow
// Function to select the next cell to assign a value to (MRV heuristic)
fn selectNextCell(graph) {
	// Find cell with smallest domain that isn't solved yet
	let minDomainSize = 10;
	let bestCell = None();

	matchOGraphPattern(graph, Cell(r, c) : Domain(vals) !: Solved, \(bindings : ast, eclassId) . {
		let domainSize = length(evalWithBindings("vals", bindings));
		if (domainSize < minDomainSize) {
			minDomainSize = domainSize;
			bestCell = Some(Pair(evalWithBindings("r", bindings), evalWithBindings("c", bindings)));
		}
	});

	bestCell;
}

// Main backtracking solver
fn solveSudoku(graph) {
	// First, apply constraint propagation until fixed point
	let saturated = applyRulesToSaturation(graph, constraintRules);

	// Check if puzzle is solved
	let solved = true;
	matchOGraphPattern(saturated, Cell(r, c) !: Solved, \(bindings : ast, eclassId) . {
		solved = false;
	});

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
	matchOGraphPattern(saturated, Cell(r, c) : Domain(vals), \(bindings : ast, eclassId) . {
		if (evalWithBindings("r", bindings) == row && evalWithBindings("c", bindings) == col) {
			possibleValues = evalWithBindings("vals", bindings);
		}
	});

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

The algebraic approach represents Sudoku as a system of polynomial equations:

```flow
fn createSudokuPolynomials() {
	let polys = [];

	// Create 81 variables for each cell
	let vars = map(range(0, 81), \i.("x" + i));

	// Each cell can only take values 1-9
	for (i in 0..80) {
		let var = vars[i];
		let cellConstraint = "(" + var + "-1)*(" + var + "-2)*...(" + var + "-9)";
		polys.push(cellConstraint);
	}

	// Each row, column, and 3×3 box must sum to 45 and have product 362880
	// Rows
	for (row in 0..8) {
		let rowVars = map(range(0, 9), \col.(vars[row*9 + col]));
		polys.push(sumPolynomial(rowVars, 45));
		polys.push(productPolynomial(rowVars, 362880));
	}

	// Columns and boxes (similar implementation)

	polys;
}
```

We can compute a Gröbner basis for this system using Buchberger's algorithm:

```flow
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
```

## BDD Representation for Sudoku

Binary Decision Diagrams (BDDs) offer a canonical, compact representation of Boolean functions. For Sudoku, we encode constraints as Boolean variables:

```flow
fn create_sudoku_bdds() {
	let constraints = [];

	// 1. Each cell contains exactly one digit
	for (r in 0..8) {
		for (c in 0..8) {
			// Exactly one of x_{r,c,1}, x_{r,c,2}, ..., x_{r,c,9} is true
			let cell_constraint = create_exactly_one_bdd([x(r,c,1), x(r,c,2), ..., x(r,c,9)]);
			constraints.push(cell_constraint);
		}
	}

	// 2. Each row contains each digit exactly once
	for (r in 0..8) {
		for (d in 1..9) {
			let row_constraint = create_exactly_one_bdd([x(r,0,d), x(r,1,d), ..., x(r,8,d)]);
			constraints.push(row_constraint);
		}
	}

	// Similar constraints for columns and boxes

	// Combine all constraints with AND
	let sudoku_constraints = constraints[0];
	for (i in 1..length(constraints)-1) {
		sudoku_constraints = bdd_and(sudoku_constraints, constraints[i]);
	}

	return sudoku_constraints;
}

// Helper function to create a BDD representing "exactly one variable is true"
fn create_exactly_one_bdd(vars) {
	// First, ensure at least one is true
	let at_least_one = vars[0];
	for (i in 1..length(vars)-1) {
		at_least_one = bdd_or(at_least_one, vars[i]);
	}

	// Then, ensure no two are true simultaneously
	let at_most_one = bdd_constant(1);  // Start with true
	for (i in 0..length(vars)-2) {
		for (j in i+1..length(vars)-1) {
			// Not both vars[i] and vars[j]
			let not_both = bdd_not(bdd_and(vars[i], vars[j]));
			at_most_one = bdd_and(at_most_one, not_both);
		}
	}

	// Return the conjunction of both conditions
	return bdd_and(at_least_one, at_most_one);
}
```

### Integrating BDDs with OGraph

```flow
fn integrate_bdds_with_ograph(graph, bdd_constraints) {
	// Add the BDD constraints to the OGraph
	let bddNodeId = addOGraph(graph, BDD(bdd_constraints));

	// Define relationships between BDD variables and cell domains
	matchOGraphPattern(graph, Cell(r, c) : Domain(vals), \(bindings : ast, eclassId) . {
		let row = evalWithBindings("r", bindings);
		let col = evalWithBindings("c", bindings);
		let domain = evalWithBindings("vals", bindings);

		// For each value in the domain, create a relationship with the corresponding BDD variable
		for (val in domain) {
			let bddVarId = addOGraph(graph, BDDVar(row, col, val));
			addDomainToNode(graph, eclassId, bddVarId);
		}
	});

	// Define rewrite rules that synchronize BDD and domain constraints
	let bdd_rewrite_rules = quote(
		// When a BDD variable becomes false, remove the value from the cell's domain
		BDDVar(r, c, v) : False && Cell(r, c) : Domain(vals) =>
			Cell(r, c) : Domain(remove(vals, v));

		// When a cell's domain has only one value, set the corresponding BDD variable to true
		Cell(r, c) : Domain([v]) => BDDVar(r, c, v) : True;

		// When all BDD variables except one are false for a cell, set the remaining one to true
		Cell(r, c) : AllFalseExcept(v) => BDDVar(r, c, v) : True;
	);

	return bdd_rewrite_rules;
}
```

## Integrated Hybrid Approach

The power of Orbit's OGraph system allows us to integrate all three approaches:

```flow
fn solve_sudoku_hybrid(initialGrid) {
	// 1. Create the OGraph
	let graph = makeOGraph("sudoku");

	// 2. Initialize graph with cells, domains, and constraints
	initializeGraph(graph, initialGrid);

	// 3. Create BDD representation of the Sudoku constraints
	let bdd_constraints = create_sudoku_bdds();

	// 4. Integrate BDDs with the OGraph
	let bdd_rules = integrate_bdds_with_ograph(graph, bdd_constraints);

	// 5. Define combined rewrite rules
	let combined_rules = quote(
		// Graph-based constraint propagation rules
		Cell(r, c) : Value(n) && Cell(r2, c2) : Domain(vals) && Adjacent(Cell(r, c), Cell(r2, c2))
			=> Cell(r2, c2) : Domain(remove(vals, n));

		// Algebraic rules for polynomial constraints
		Row(r) : Values(vals) => Sum(vals) : Equals(45);
		Row(r) : Values(vals) => Product(vals) : Equals(362880);

		// BDD-based inference rules
		BDDSolution(r, c, v) => Cell(r, c) : Value(v) : Solved;

		// Rules that combine approaches
		Cell(r, c) : Polynomial(p) && Cell(r, c) : Domain(vals)
			=> Cell(r, c) : Domain(intersect(vals, roots(p)));

		Cell(r, c) : BDDConstraints(constraints) && Cell(r, c) : Domain(vals)
			=> Cell(r, c) : Domain(filter(vals, satisfies_constraints(constraints)));
	);

	// 6. Define a cost function for the orbit optimizer
	let costFunction = \expr.(expr is (
		_ : Solved => 0.0;  // Prefer solved states
		Cell(_, _) : Domain(vals) => length(vals) * 1.0;  // Prefer smaller domains
		_ => 10.0;  // Penalize other expressions
	));

	// 7. Apply constraint propagation
	let propagated = applyRulesToSaturation(graph, combined_rules);

	// 8. If not solved, perform hybrid backtracking search
	let is_solved = check_if_solved(propagated);

	if (is_solved) {
		return extract_solution(propagated);
	} else {
		return hybrid_backtracking_search(propagated, combined_rules, costFunction);
	}
}
```

### BDD-based Constraint Propagation

BDDs excel at logical inference and constraint propagation:

```flow
fn bdd_constraint_propagation(bdd, assignment) {
	// Restrict the BDD based on current assignment
	let restricted_bdd = apply_assignment(bdd, assignment);

	// Perform unit propagation
	let inferences = [];

	for (var in get_variables(bdd)) {
		// Try forcing var to true
		let bdd_true = bdd_restrict(restricted_bdd, var, true);
		// Try forcing var to false
		let bdd_false = bdd_restrict(restricted_bdd, var, false);

		// If either restriction leads to unsatisfiability, infer the opposite
		if (bdd_true == bdd_constant(0)) {
			inferences.push(Pair(var, false));
		} else if (bdd_false == bdd_constant(0)) {
			inferences.push(Pair(var, true));
		}
	}

	return inferences;
}
```

### Hybrid Backtracking Search

When pure constraint propagation isn't enough, we use a hybrid backtracking search:

```flow
fn hybrid_backtracking_search(graph, rules, costFunction) {
	// Select cell with smallest domain (MRV heuristic)
	let nextCell = select_cell_with_smallest_domain(graph);
	if (nextCell == None()) {
		return extract_solution(graph);  // All cells assigned
	}

	let row = nextCell.value.first;
	let col = nextCell.value.second;
	let domain = get_domain(graph, row, col);

	// Try values in domain order
	for (val in domain) {
		// Create a copy of the graph for this branch
		let branch = copyOGraph(graph);

		// Assign the value
		assign_value(branch, row, col, val);

		// Apply constraint propagation using all three methods
		let propagated = applyRulesToSaturation(branch, rules);

		// Check for consistency with BDDs
		let bdd_consistent = check_bdd_consistency(propagated);

		if (bdd_consistent) {
			// Recursively continue search
			let result = hybrid_backtracking_search(propagated, rules, costFunction);

			if (result != None()) {
				return result;  // Found a solution
			}
		}
		// If we reach here, this branch failed
	}

	return None();  // No solution found in any branch
}
```

## Advantages of the Hybrid Approach

The hybrid approach offers several key advantages:

1. **Complementary Strengths**: Each approach excels at different aspects of the Sudoku problem:
   - Graph theory provides a natural representation and efficient constraint propagation
   - Boolean logic via BDDs offers powerful logical inference
   - Algebraic techniques provide a rigorous mathematical foundation

2. **Early Pruning**: BDDs can quickly detect unsatisfiable configurations, allowing early pruning of search branches

3. **Improved Inference**: Combined approaches can deduce more constraints than any individual approach

4. **Unified Framework**: OGraph seamlessly integrates all three approaches through domain annotations and rewrite rules

5. **Symmetry Exploitation**: Orbit can leverage Sudoku's inherent symmetries for further optimization

## Leveraging Orbit's Domain Annotations

Orbit's domain-based rewriting system is particularly useful for Sudoku due to its ability to represent and exploit symmetries:

```flow
// Define Sudoku symmetry properties
Sudoku : SymmetryGroup;

// Row permutation symmetry
Permute(sudoku, rows) : RowPermutation ⊢ Sudoku : SymmetryGroup;

// Column permutation symmetry
Permute(sudoku, cols) : ColumnPermutation ⊢ Sudoku : SymmetryGroup;

// Digit permutation symmetry
Permute(sudoku, digits) : DigitPermutation ⊢ Sudoku : SymmetryGroup;

// Box symmetry (transpose, rotate)
Transpose(sudoku) : BoxSymmetry ⊢ Sudoku : SymmetryGroup;
```

## Rewrite Rules for Solving Strategies

Orbit can express common Sudoku solving techniques as rewrite rules:

```flow
// Naked Singles
Cell(r, c) : Domain([v]) => Cell(r, c) : Value(v) : NakedSingle;

// Hidden Singles
Cell(r, c) : Domain(vals) && UniqueInUnit(r, c, v) => Cell(r, c) : Value(v) : HiddenSingle;

// Locked Candidates
Cells(cells) : SameBox & SameValue(v) & SameRow =>
	RemoveValueFromOtherCellsInRow(cells, v);
```

## Conclusion

By combining OGraph's powerful rewriting system with Binary Decision Diagrams and algebraic methods, we create a Sudoku solver that leverages the strengths of multiple mathematical approaches. This hybrid approach demonstrates the versatility of Orbit's domain-unified rewriting engine, which allows us to seamlessly integrate different mathematical formalisms into a cohesive problem-solving framework.

The resulting solver is not only efficient but also provides insight into the mathematical structure of Sudoku puzzles from multiple perspectives. More broadly, this integration serves as a model for how Orbit can unify diverse mathematical approaches to solve complex constraint satisfaction problems.