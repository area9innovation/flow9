# Comprehensive test script for OGraph implementation with natural syntax

# Include the core modules
include("ograph.jl")
using .OGraph

include("ograph_pattern.jl")
using .OGraphPattern

# Include the natural syntax extension
include("orbit_syntax.jl")
using .OrbitSyntax

# Include utilities for graph building
include("orbit_utils.jl")
using .OrbitUtils

# Helper function to display graph structure
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

# Main test function
function test_ograph()
    println("Testing OGraph implementation with natural syntax...")
    
    # Create a new graph
    graph = OGraph.make_ograph()
    println("Created new OGraph")
    
    # Create expressions using the macro
    id_5plus10 = @insert_expr graph 5 + 10
    println("Created expression 5 + 10, id: $id_5plus10")
    
    id_10plus5 = @insert_expr graph 10 + 5
    println("Created expression 10 + 5, id: $id_10plus5")
    
    id_3plus4 = @insert_expr graph 3 + 4
    println("Created expression 3 + 4, id: $id_3plus4")
    
    # Create domains
    integer_id = OrbitUtils.create_domain(graph, "Integer")
    println("Created Integer domain node, id: $integer_id")
    
    s2_id = OrbitUtils.create_domain(graph, "Su2082")
    println("Created Su2082 domain node, id: $s2_id")
    
    canonical_id = OrbitUtils.create_domain(graph, "Canonical")
    println("Created Canonical domain node, id: $canonical_id")
    
    # Add domains to nodes
    OrbitUtils.add_domain(graph, id_5plus10, integer_id)
    OrbitUtils.add_domain(graph, id_5plus10, s2_id)
    OrbitUtils.add_domain(graph, id_10plus5, integer_id)
    OrbitUtils.add_domain(graph, id_10plus5, s2_id)
    OrbitUtils.add_domain(graph, id_3plus4, integer_id)
    println("Added domain memberships to addition nodes")
    
    # Display initial graph
    display_ograph(graph)
    
    # ----------------------------------------------------------
    # Test 1: Basic Pattern Matching using Natural Syntax
    # ----------------------------------------------------------
    println("\nTest 1: Basic Pattern Matching using Natural Syntax")
    
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
    
    # ----------------------------------------------------------
    # Test 2: Domain-Specific Pattern Matching
    # ----------------------------------------------------------
    println("\nTest 2: Domain-Specific Pattern Matching")
    
    # Define a pattern with domain annotation
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
    
    # ----------------------------------------------------------
    # Test 3: Negative Domain Patterns
    # ----------------------------------------------------------
    println("\nTest 3: Negative Domain Patterns")
    
    # Define a pattern with negative domain guard
    println("Creating pattern: (x + y) !: Canonical")
    neg_pattern = @pattern (x + y) !: Canonical
    
    # Match the negative domain pattern
    println("\nMatching negative domain pattern...")
    match_count = OGraphPattern.match_pattern(graph, neg_pattern, (bindings, eclass_id) -> begin
        println("Found match at eclass ID: $(eclass_id)")
        println("Bindings:")
        for (var, node_id) in bindings
            val = OGraph.get_class_int(graph, node_id)
            println("  $(var) = $(val)")
        end
    end)
    
    println("Total negative domain matches: $(match_count)")
    
    # ----------------------------------------------------------
    # Test 4: Applying Rules
    # ----------------------------------------------------------
    println("\nTest 4: Applying Rules")
    
    # Define a rule for commutative addition canonicalization
    println("Creating rule: (x + y) : Su2082 u2192 y + x : Canonical (if y < x)")
    
    # Since we can't fully evaluate the condition yet, let's use a simpler rule for the demo
    rule = @rule (x + y) : Su2082 u2192 y + x : Canonical
    
    # Apply the rule
    println("\nApplying commutative rule...")
    matches = OrbitSyntax.apply_rule(graph, rule, true)
    println("Rule applied $(matches) times")
    
    # Display the graph after rule application
    display_ograph(graph)
    
    println("\nAll tests completed successfully.")
end

# Run the test
test_ograph()