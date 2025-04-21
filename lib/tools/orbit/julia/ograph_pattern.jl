module OGraphPattern

using ..OGraph

export PatternResult, PatternSuccess, PatternFailure,
       match_pattern, match_pattern_at_node

# Pattern matching result types
abstract type PatternResult end

struct PatternSuccess <: PatternResult
    bindings::Dict{String, Int}  # Variable name to node ID
    
    # Constructor with default empty bindings
    PatternSuccess() = new(Dict{String, Int}())
    PatternSuccess(bindings::Dict{String, Int}) = new(bindings)
end

struct PatternFailure <: PatternResult
end

"""
    match_pattern(graph::OGraph.OGraph, pattern::Any, callback::Function, tracing::Bool=false) -> Int

Match a pattern in the graph and call the callback for each match.
Callback signature: (bindings::Dict{String,Int}, eclassId::Int) -> Any
Returns the number of matches found.
"""
function match_pattern(graph::OGraph.OGraph, pattern::Any, callback::Function, tracing::Bool=false)
    match_count = 0
    
    if tracing
        println("Pattern matching in graph")
    end
    
    # Strategy: Try to match the pattern starting at each node in the graph
    OGraph.traverse_ograph(graph, (node_index, node) -> begin
        if tracing
            println("DEBUG: Checking node ID: $(node_index), op: $(node.op)")
        end
        
        # Try to match the pattern at this node
        result = match_pattern_at_node(graph, node_index, pattern, tracing)
        
        if result isa PatternSuccess
            if tracing
                println("DEBUG: Found match at node ID: $(node_index)")
                println("DEBUG: Found match with $(length(result.bindings)) bindings at eclass ID: $(OGraph.find_root(graph, node_index))")
                
                # Debug output - log all bindings
                for (key, value) in result.bindings
                    println("  $key = $(value)")
                end
            end
            
            # Call the callback directly with the bindings (eclass IDs) and the e-class ID
            match_count += 1
            root_id = OGraph.find_root(graph, node_index)
            callback(result.bindings, root_id)
        elseif tracing
            println("DEBUG: No match at node ID: $(node_index)")
        end
    end)
    
    if tracing
        println("DEBUG: match_pattern returned $(match_count) matches")
    end
    
    return match_count
end

"""
    match_pattern_at_node(graph::OGraph.OGraph, node_id::Int, pattern::Any, tracing::Bool) -> PatternResult

Match a pattern at a specific node.
"""
function match_pattern_at_node(graph::OGraph.OGraph, node_id::Int, pattern::Any, tracing::Bool)
    root = OGraph.find_root(graph, node_id)
    oclass = OGraph.lookup_class(graph, root)
    
    if oclass === nothing
        return PatternFailure()
    end
    
    # Pattern decomposition would go here - implement based on your pattern representation
    # For a simplified implementation, we'll handle a few basic cases
    
    # Example for variable patterns (implement according to your actual pattern representation)
    if pattern_is_variable(pattern)
        var_name = get_pattern_variable_name(pattern)
        if !isempty(var_name)
            if tracing
                println("DEBUG: Pattern variable $(var_name) binds to node $(root)")
            end
            return PatternSuccess(Dict(var_name => root))
        else
            return PatternFailure()
        end
    elseif pattern_is_type_annotation(pattern)
        if tracing
            println("DEBUG: Processing TypeAnnotation pattern (: operator)")
        end
        
        # Extract the expression and domain from the pattern
        expression_pattern = get_expression_from_type_annotation(pattern)
        domain_pattern = get_domain_from_type_annotation(pattern)
        
        # First match the expression part against this node
        expression_result = match_pattern_at_node(graph, node_id, expression_pattern, tracing)
        
        if expression_result isa PatternSuccess
            # Found a match for the expression part
            # Now verify domain membership
            domain_node_id = find_domain_id(graph, domain_pattern, tracing)
            
            if tracing
                println("DEBUG: getDomainId returned: $(domain_node_id)")
            end
            
            if domain_node_id == -1
                if tracing
                    println("DEBUG: Could not find domain node")
                end
                return PatternFailure()
            else
                # Check domain membership
                belongs_to_domain = OGraph.node_belongs_to(graph, node_id, domain_node_id)
                
                if tracing
                    println("DEBUG: Checking if node $(node_id) belongs to domain $(domain_node_id)")
                    println("DEBUG: Domain membership result: $(belongs_to_domain)")
                end
                
                if belongs_to_domain
                    if tracing
                        println("DEBUG: Node belongs to required domain, match successful")
                    end
                    return expression_result  # Return the expression match bindings
                else
                    if tracing
                        println("DEBUG: Node does not belong to required domain, match failed")
                    end
                    return PatternFailure()
                end
            end
        else
            if tracing
                println("DEBUG: Expression part of TypeAnnotation pattern didn't match")
            end
            return PatternFailure()
        end
    elseif pattern_is_negative_type_annotation(pattern)
        # Similar to type annotation but checks for non-membership
        if tracing
            println("DEBUG: Processing NotTypeAnnotation pattern (!: operator)")
        end
        
        expression_pattern = get_expression_from_negative_type_annotation(pattern)
        domain_pattern = get_domain_from_negative_type_annotation(pattern)
        
        expression_result = match_pattern_at_node(graph, node_id, expression_pattern, tracing)
        
        if expression_result isa PatternSuccess
            domain_node_id = find_domain_id(graph, domain_pattern, tracing)
            
            if domain_node_id == -1
                # If domain doesn't exist, negative check succeeds
                return expression_result
            else
                # Check that node does NOT belong to domain
                belongs_to_domain = OGraph.node_belongs_to(graph, node_id, domain_node_id)
                
                if !belongs_to_domain
                    return expression_result
                else
                    return PatternFailure()
                end
            end
        else
            return PatternFailure()
        end
    else
        # For other patterns, check structural equality
        if pattern_matches_node(graph, node_id, pattern)
            # For leaf nodes, return empty bindings
            if isempty(oclass.node.children)
                return PatternSuccess()
            else
                # For non-leaf nodes, extract bindings from children
                node_children = oclass.node.children
                pattern_children = get_pattern_children(pattern)
                
                if tracing
                    println("DEBUG: Operator and child count match, extracting bindings from children")
                end
                
                if length(node_children) != length(pattern_children)
                    return PatternFailure()
                end
                
                return match_all_children(graph, node_children, pattern_children, Dict{String, Int}(), tracing)
            end
        else
            # No match
            return PatternFailure()
        end
    end
end

"""
    match_all_children(graph::OGraph.OGraph, child_ids::Vector{Int}, patterns::Vector{Any}, 
                     bindings::Dict{String, Int}, tracing::Bool) -> PatternResult

Match all children of an operation.
"""
function match_all_children(graph::OGraph.OGraph, child_ids::Vector{Int}, patterns::Vector{Any}, 
                          bindings::Dict{String, Int}, tracing::Bool)
    if isempty(child_ids) && isempty(patterns)
        # All children matched successfully
        return PatternSuccess(bindings)
    elseif isempty(child_ids) || isempty(patterns)
        # Mismatched number of children
        return PatternFailure()
    else
        # Try to match the first child
        first_result = match_pattern_at_node(graph, child_ids[1], patterns[1], tracing)
        
        if first_result isa PatternSuccess
            # Merge bindings, ensuring consistency
            merge_result = merge_bindings(graph, bindings, first_result.bindings)
            
            if merge_result isa PatternSuccess
                # Continue with remaining children
                return match_all_children(graph, child_ids[2:end], patterns[2:end], 
                                       merge_result.bindings, tracing)
            else
                return PatternFailure()
            end
        else
            return PatternFailure()
        end
    end
end

"""
    merge_bindings(graph::OGraph.OGraph, a::Dict{String, Int}, b::Dict{String, Int}) -> PatternResult

Merge bindings, ensuring consistency (same variable bound to equivalent nodes).
"""
function merge_bindings(graph::OGraph.OGraph, a::Dict{String, Int}, b::Dict{String, Int})
    # Helper to check if two nodes are semantically equivalent
    function are_equivalent_nodes(id1, id2)
        if OGraph.find_root(graph, id1) == OGraph.find_root(graph, id2)
            return true
        else
            # For simplicity we'll use structural equality
            return OGraph.nodes_structurally_equal(graph, id1, id2)
        end
    end
    
    merged = copy(a)
    
    for (key, b_value) in b
        if haskey(merged, key)
            a_value = merged[key]
            # Variable already bound, must be consistent
            if !are_equivalent_nodes(a_value, b_value)
                return PatternFailure()
            end
        else
            # New binding
            merged[key] = b_value
        end
    end
    
    return PatternSuccess(merged)
end

# These helper functions need to be implemented based on your pattern representation
# Here are placeholder implementations

function pattern_is_variable(pattern)
    # Example implementation assuming pattern is a Dict with "type" field
    return isa(pattern, Dict) && get(pattern, "type", "") == "variable"
end

function get_pattern_variable_name(pattern)
    # Example implementation
    return isa(pattern, Dict) ? get(pattern, "name", "") : ""
end

function pattern_is_type_annotation(pattern)
    return isa(pattern, Dict) && get(pattern, "type", "") == "type_annotation"
end

function get_expression_from_type_annotation(pattern)
    return isa(pattern, Dict) ? get(pattern, "expression", nothing) : nothing
end

function get_domain_from_type_annotation(pattern)
    return isa(pattern, Dict) ? get(pattern, "domain", nothing) : nothing
end

function pattern_is_negative_type_annotation(pattern)
    return isa(pattern, Dict) && get(pattern, "type", "") == "negative_type_annotation"
end

function get_expression_from_negative_type_annotation(pattern)
    return isa(pattern, Dict) ? get(pattern, "expression", nothing) : nothing
end

function get_domain_from_negative_type_annotation(pattern)
    return isa(pattern, Dict) ? get(pattern, "domain", nothing) : nothing
end

function find_domain_id(graph, domain_pattern, tracing)
    # Simplified implementation - find a matching node
    if isa(domain_pattern, Dict) && haskey(domain_pattern, "name")
        domain_name = domain_pattern["name"]
        # Search for a node with matching domain name
        result = -1
        OGraph.traverse_ograph(graph, (id, node) -> begin
            if node.op == "Domain" 
                str_val = OGraph.get_class_string(graph, id)
                if str_val == domain_name
                    result = id
                end
            end
        end)
        return result
    end
    return -1
end

function pattern_matches_node(graph, node_id, pattern)
    # Simplified structural matching
    if !isa(pattern, Dict) || !haskey(pattern, "type")
        return false
    end
    
    oclass = OGraph.lookup_class(graph, node_id)
    if oclass === nothing
        return false
    end
    
    # Match based on pattern type
    if pattern["type"] == "binary_operation" && haskey(pattern, "operator")
        return oclass.node.op == pattern["operator"] && length(oclass.node.children) == 2
    elseif pattern["type"] == "literal" && haskey(pattern, "value")
        if oclass.node.op == "Int"
            val = OGraph.get_class_int(graph, node_id)
            return val == pattern["value"]
        elseif oclass.node.op == "Double"
            val = OGraph.get_class_double(graph, node_id)
            return val == pattern["value"]
        elseif oclass.node.op == "String"
            val = OGraph.get_class_string(graph, node_id)
            return val == pattern["value"]
        end
    end
    
    return false
end

function get_pattern_children(pattern)
    # Extract children from pattern based on pattern type
    if !isa(pattern, Dict) || !haskey(pattern, "type")
        return []
    end
    
    if pattern["type"] == "binary_operation"
        return [get(pattern, "left", nothing), get(pattern, "right", nothing)]
    end
    
    # Add other pattern types as needed
    return []
end

end # module