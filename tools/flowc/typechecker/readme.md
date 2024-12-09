# Type Resolution System Specification

## Overview
The system resolves type constraints in Flow9's type inference system by iteratively applying unification rules and heuristics to resolve type variables (tyvars) to concrete types.

## Core Concepts

### Types
- Basic types (int, string, etc.)
- Type variables (α1, α2, etc.)
- Type parameters (T, U, etc.)
- Functions (arg -> ret)
- Arrays ([type])
- References (ref<read,write>)
- Named unions and structs
- Field sets (unnamed structs)
- Unnamed unions
- Bounded types (lower ≤ type ≤ upper)

### Unification Modes
1. `FUnifyLeft`: Left type must be contained in right, can grow left
2. `FGrowRight`: Grow right type to accommodate left
3. `FReduceLeft`: Reduce left type to fit right
4. `FUnifyRight`: Left contained in right, can reduce right

## Resolution Process

### Main Resolution Phases
1. Initial type resolution
2. Bound resolution
3. Dependency rerunning
4. Heuristic resolution
5. Final cleanup

### Detailed Steps

1. **Basic Type Resolution** (`resolveAllTypes`)
   - Resolve row types (field sets)
   - Resolve unnamed unions
   - Apply basic type unification rules

2. **Bound Resolution** (`resolveBounds`)
   - Three modes:
	 - Exact (heuristic=0): Unify all bounds
	 - Upper bounds (heuristic=1): Resolve upper bounds only
	 - Lower bounds (heuristic=2): Resolve lower bounds only

3. **Dependency Rerunning** (`rerunDeps`)
   - Reapply unification on dependent types
   - Handle transitive dependencies

4. **Heuristic Resolution**
   a. **Cassiopeia Heuristic** (`resolveCassiopeia`)
	  - Pattern: ..u ≤ α → α = u..
	  - Resolves union of upper bounds
   
   b. **Reverse Cassiopeia** (`resolveCassiopeia2`)
	  - Pattern: α ≤ l.. → α = l..
	  - Resolves union of lower bounds
   
   c. **Kissing Heuristic** (`resolveKisses`)
	  - Pattern: α = {...U} ≤ β = {L...}
	  - Tries to resolve U ≤ L

5. **Tyvar Resolution** (`resolveTyvarVsTyvar`)
   - Resolves unbound tyvar vs tyvar cases
   - Picks lowest number for bigger side

6. **Typar Resolution** (`resolveTyvarsToTypars`)
   - Resolves remaining free tyvars to type parameters

### Error Handling
- Tracks tyvar to source position mapping
- Reports errors with source locations
- Deduplicates error messages
- Special handling for implicit type parameters

### Iteration Control
- Maximum of 5 main iterations
- Stops when no more changes occur
- Additional iterations for specific cases

# Type Resolution Heuristics Details

## 1. Cassiopeia Heuristic

### Pattern
```
..u ≤ α
```
where:
- `..u` represents a bounded type with upper bound `u`
- `α` is an unbound type variable

### Resolution
```
α = u..
```

### Example
```flow
// Given constraints:
{name: string, age: int, ..u} ≤ α   // α must contain at least name and age
{id: int, ..u} ≤ α				  // α must contain at least id

// Cassiopeia resolves α to:
α = {name: string, age: int, id: int, ..u}
```

### Purpose
- Collects all cases where there are upper bounds on an unbound type variable
- Combines them into a union of all upper bounds
- Particularly useful for resolving record subtyping constraints

## 2. Reverse Cassiopeia Heuristic

### Pattern
```
α ≤ l..
```
where:
- `l..` represents a bounded type with lower bound `l`
- `α` is an unbound type variable

### Resolution
```
α = l..
```

### Example
```flow
// Given constraints:
α ≤ {x: int, y: int, ..l}	 // α can have at most x and y fields
α ≤ {z: bool, ..l}			// α can have at most z field

// Reverse Cassiopeia resolves α to:
α = {x: int, y: int, z: bool, ..l}
```

### Purpose
- Mirror of Cassiopeia for lower bounds
- Combines lower bound constraints on unbound type variables
- Useful for completing type information from multiple constraints

## 3. Kissing Heuristic

### Pattern
```
α = {...U} ≤ β = {L...}
```
where:
- `α` and `β` are type variables
- `U` is an upper bound
- `L` is a lower bound
- The types "kiss" but don't transfer information

### Resolution
Attempts to resolve `U ≤ L`

### Example
```flow
// Given:
α = {name: string, ..u1} ≤ β = {l1.., id: int}

// The Kissing heuristic tries:
u1 ≤ l1

// If successful:
α = {name: string, id: int}
β = {name: string, id: int}
```

### Purpose
- Handles cases where two record types meet but don't directly overlap
- Tries to unify their bounds without commitment
- If unification fails, the original constraints are preserved
- Useful for resolving record type hierarchies

## Implementation Details

### Precedence
1. Standard unification is attempted first
2. Cassiopeia heuristics are applied next
3. Kissing heuristic is applied last

### Safeguards
```flow
errors = ref false;
et = funify(acc2, uppera, lowerb, to.kind, \e -> errors := true);
if (!^errors) {
	// Apply the resolution
} else {
	// Keep original constraints
}
```

## Common Use Cases

### Record Type Resolution
```flow
// Initial constraints:
type Person = { name: string, ..r };
type Employee = { id: int, ..s };
α ≤ Person
α ≤ Employee

// After Cassiopeia:
α = { name: string, id: int }
```

### Function Type Resolution
```flow
// Initial constraints:
α = (β) -> γ
β ≤ {x: int, ..u}
γ ≤ {y: string, ..v}

// After heuristics:
α = ({x: int, ..u}) -> {y: string, ..v}
```

### Union Type Resolution
```flow
// Initial:
α ≤ string | int
β ≤ number | int
α = β

// After resolution:
α = β = int
```

These heuristics work together to resolve complex type constraints that can't be solved by simple unification alone. They're particularly powerful for handling record types, row polymorphism, and gradual typing scenarios.