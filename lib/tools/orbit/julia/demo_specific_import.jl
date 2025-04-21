# Demo showing specific imports with aliases

# Include the core modules
include("ograph.jl")
using .OGraph

include("ograph_pattern.jl")
using .OGraphPattern

# Include our syntax extensions with specific aliases
include("orbit_syntax.jl")
using .OrbitSyntax: @pattern, @rule

# Include utilities for graph building
include("orbit_utils.jl")
using .OrbitUtils

function test_specific_imports()
    println("Testing with specific imports...")
    
    # Create a new graph
    graph = OGraph.make_ograph()
    
    # Create nodes and expressions using the macro - much cleaner approach
    id_expr = @insert_expr graph 5 + 10
    println("Created expression with id: $id_expr")
    
    # Define a pattern using natural syntax
    println("\nCreating pattern: x + y using @pattern macro")
    pattern = @pattern x + y
    
    # Match the pattern
    println("\nMatching pattern against graph...")
    match_count = OGraphPattern.match_pattern(graph, pattern, (bindings, eclass_id) -> begin
        println("Found match at eclass ID: $(eclass_id)")
        println("Bindings:")
        for (var, node_id) in bindings
            val = OGraph.get_class_int(graph, node_id)
            println("  $(var) = $(val)")
        end
    end)
    
    println("Total matches: $(match_count)")
    
    # Define a rule
    println("\nCreating rule: (x + y) → y + x using @rule macro")
    rule = @rule (x + y) → y + x
    
    println("\nDemo with specific imports completed.")
end

# Run the test
test_specific_imports()