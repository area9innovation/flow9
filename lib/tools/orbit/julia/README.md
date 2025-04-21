# OGraph Implementation in Julia

This folder contains a Julia implementation of the OGraph data structure used in the Orbit system. The implementation follows the same design principles as the Flow9 implementation, providing equivalent functionality with an intuitive natural syntax for patterns and rules.

## Key Features

- Complete implementation of OGraph data structure
- Pattern matching with domain support
- Domain membership tracking and queries
- Natural syntax for patterns and rules using macros

## Files

- `ograph.jl`: Core OGraph data structure implementation
- `ograph_pattern.jl`: Pattern matching functionality
- `orbit_syntax.jl`: Natural syntax implementation (macros for patterns and rules)
- `orbit_utils.jl`: Utility functions for creating nodes and building graphs
- `demo_natural_syntax.jl`: Demo of basic natural syntax
- `demo_specific_import.jl`: Demo of aliased imports

## Example Usage with Natural Syntax

```julia
# Include the modules
include("ograph.jl")
using .OGraph

include("ograph_pattern.jl")
using .OGraphPattern

include("orbit_syntax.jl")
using .OrbitSyntax

include("orbit_utils.jl")
using .OrbitUtils

# Create a new graph
graph = OGraph.make_ograph()

# Create expression directly
expr_id = @insert_expr graph 5 + 10

# Create a domain for "Integer"
integer_id = OrbitUtils.create_domain(graph, "Integer")

# Add the domain to the expression
OrbitUtils.add_domain(graph, expr_id, integer_id)

# Using natural syntax for patterns
pattern = @pattern x + y

# Match the pattern
match_count = OGraphPattern.match_pattern(graph, pattern, (bindings, eclass_id) -> begin
	println("Found match at eclass ID: $(eclass_id)")
	println("Bindings:")
	for (var, node_id) in bindings
		val = OGraph.get_class_int(graph, node_id)
		println("  $(var) = $(val)")
	end
end)

# Define a domain-annotated pattern
domain_pattern = @pattern (x + y) : Integer

# Define a rewrite rule
rule = @rule (x + y) : Su2082 u2192 y + x : Canonical where y < x

# Apply the rule
OrbitSyntax.apply_rule(graph, rule)
```

## Implementation Details

### OGraph Module

The core OGraph data structure provides:

- Node insertion and lookup
- Equivalence class management
- Domain membership tracking
- Primitive value associations

### OGraphPattern Module

The pattern matching functionality includes:

- General pattern matching across the graph
- Support for variable bindings
- Domain-specific pattern constraints with the `:` operator
- Negative domain constraints with the `!:` operator

### OrbitSyntax Module

The natural syntax support provides:

- Macro-based pattern creation (@pattern)
- Macro-based rule definition (@rule)
- Support for domain annotations and conditions
- Automatic AST transformation to pattern structures

### OrbitUtils Module

Utility functions for graph building:

- Creating nodes for different types (Int, Float64, String)
- Creating operation nodes
- Creating and managing domains
- A macro (@insert_expr) for inserting expressions directly into the graph

## TODOs and Future Improvements

1. **Complete Expression Insertion API**: Enhance the @insert_expr macro to handle more complex expressions and edge cases
2. **Condition Evaluation**: Implement proper condition evaluation in rules (e.g., `where y < x`)
3. **Improved Pattern Matching**: Add support for more complex pattern matching capabilities, such as subpatterns and wildcards
4. **Performance Optimization**: Optimize the graph operations, particularly for large graphs
5. **Proper Error Handling**: Add comprehensive error checking and informative error messages
6. **Serialization**: Add support for saving and loading graph state to/from files
7. **Visualization**: Create a visualization component for OGraph instances
8. **Type System**: Strengthen the type system to catch more errors at compile time
9. **Documentation**: Create comprehensive documentation with examples for all features
10. **Testing**: Add unit tests and benchmarks for the implementation

## Requirements

- Julia 1.0 or higher
- DataStructures.jl package