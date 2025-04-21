# Demo showing the natural syntax for Orbit in Julia

# Include the core modules
include("ograph.jl")
using .OGraph

include("ograph_pattern.jl")
using .OGraphPattern

# Include our syntax extensions
include("orbit_syntax.jl")
using .OrbitSyntax

# Include utilities for graph building
include("orbit_utils.jl")
using .OrbitUtils

# Display function to help us see the graph structure
function display_ograph(graph)
    println("\nGraph Structure:")
    println("===============")
    
    OGraph.traverse_ograph(graph, (id, node) -> begin
        if id == OGraph.find_root(graph, id)  # Only show canonical nodes
            println("Node ID: $id, Op: $(node.op)")
            
            # Show children
            if !isempty(node.children)
                print("  Children: ")
                for (i, child) in enumerate(node.children)
                    child_root = OGraph.find_root(graph, child)
                    child_node = OGraph.lookup_class(graph, child_root).node
                    print("$child ($(child_node.op))")
                    if i < length(node.children)
                        print(", ")
                    end
                end
                println()
            end
            
            # Show value if it's a leaf
            if node.op == "Int"
                val = OGraph.get_class_int(graph, id)
                println("  Value: $val")
            elseif node.op == "Double"
                val = OGraph.get_class_double(graph, id)
                println("  Value: $val")
            elseif node.op == "String" || node.op == "Domain"
                val = OGraph.get_class_string(graph, id)
                println("  Value: $val")
            end
            
            # Show domain membership
            if !isempty(node.belongs_to)
                print("  Belongs to: ")
                for (i, domain_id) in enumerate(node.belongs_to)
                    domain_root = OGraph.find_root(graph, domain_id)
                    if OGraph.lookup_class(graph, domain_root) !== nothing && 
                       OGraph.lookup_class(graph, domain_root).node.op == "Domain"
                        domain_name = OGraph.get_class_string(graph, domain_root)
                        print("$domain_name")
                        if i < length(node.belongs_to)
                            print(", ")
                        end
                    end
                end
                println()
            end
            
            println()  # Empty line for better readability
        end
    end)
    println("===============\n")
end

function test_natural_syntax()
    println("Testing natural syntax for Orbit in Julia...")
    
    # Create a new graph
    graph = OGraph.make_ograph()
    
    # ------------------------------------------------------------
    # Example 1: Using the direct expression insertion to build graph
    # ------------------------------------------------------------
    println("\nExample 1: Basic pattern matching")
    
    # Create expression directly using the macro
    add_id = @insert_expr graph 5 + 10
    println("Created expression with id: $add_id")
    
    # Create domains using utility functions
    integer_id = OrbitUtils.create_domain(graph, "Integer")
    s2_id = OrbitUtils.create_domain(graph, "Su2082")
    
    # Add domains to the addition node
    OrbitUtils.add_domain(graph, add_id, integer_id)
    OrbitUtils.add_domain(graph, add_id, s2_id)
    
    # Display initial graph
    display_ograph(graph)
    
    # Define a pattern using natural syntax
    println("Creating pattern: x + y")
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
    
    # ------------------------------------------------------------
    # Example 2: Domain annotations and more complex patterns
    # ------------------------------------------------------------
    println("\nExample 2: Domain annotations and more complex patterns")
    
    # Define a pattern with domain annotation using natural syntax
    println("Creating pattern: (x + y) : Integer")
    integer_pattern = @pattern (x + y) : Integer
    
    # Match the domain-specific pattern
    println("\nMatching domain-specific pattern...")
    match_count = OGraphPattern.match_pattern(graph, integer_pattern, (bindings, eclass_id) -> begin
        println("Found match at eclass ID: $(eclass_id)")
        println("Bindings:")
        for (var, node_id) in bindings
            val = OGraph.get_class_int(graph, node_id)
            println("  $(var) = $(val)")
        end
    end)
    
    println("Total domain-specific matches: $(match_count)")
    
    # ------------------------------------------------------------
    # Example 3: Applying rules
    # ------------------------------------------------------------
    println("\nExample 3: Applying rules")
    
    # Create another addition with reversed operands: 10 + 5
    add_id2 = @insert_expr graph 10 + 5
    
    # Add domains to this node too
    OrbitUtils.add_domain(graph, add_id2, integer_id)  # Integer domain
    OrbitUtils.add_domain(graph, add_id2, s2_id)      # Su2082 domain
    
    display_ograph(graph)
    
    # Define a canonicalization rule for commutative addition
    println("Creating commutative canonicalization rule using natural syntax")
    # In a real implementation, we would handle the condition properly
    # Here we're just demonstrating the syntax
    rule = @rule (x + y) : Su2082 u2192 y + x
    
    # Apply the rule
    println("\nApplying commutative rule...")
    matches = OrbitSyntax.apply_rule(graph, rule, true)
    println("Rule applied $(matches) times")
    
    # Show the graph after rule application
    display_ograph(graph)
    
    println("Natural syntax demo completed.")
end

# Run the test
test_natural_syntax()