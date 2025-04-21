module OrbitSyntax

using ..OGraph
using ..OGraphPattern

export var, const_int, const_double, const_string, op, domain_annotation
export @pattern, @rule  # Only export the main pattern and rule macros

# Pattern construction helpers
function var(name::String)
    Dict("type" => "variable", "name" => name)
end

function const_int(value::Int)
    Dict("type" => "literal", "value" => value)
end

function const_double(value::Float64)
    Dict("type" => "literal", "value" => value)
end

function const_string(value::String)
    Dict("type" => "literal", "value" => value)
end

function op(operator::String, args...)
    if length(args) == 2
        Dict(
            "type" => "binary_operation",
            "operator" => operator,
            "left" => args[1],
            "right" => args[2]
        )
    else
        # For n-ary operations or other cases
        Dict(
            "type" => "operation",
            "operator" => operator,
            "args" => collect(args)
        )
    end
end

function domain_annotation(expr, domain)
    Dict(
        "type" => "type_annotation",
        "expression" => expr,
        "domain" => Dict("type" => "domain", "name" => domain)
    )
end

function negative_domain_annotation(expr, domain)
    Dict(
        "type" => "negative_type_annotation",
        "expression" => expr,
        "domain" => Dict("type" => "domain", "name" => domain)
    )
end

# Expression parsing helpers
function parse_expression(expr)
    if isa(expr, Symbol)
        # Variable
        return var(string(expr))
    elseif isa(expr, Number)
        # Literal
        if isa(expr, Int)
            return const_int(expr)
        elseif isa(expr, Float64)
            return const_double(expr)
        end
    elseif isa(expr, String)
        # String literal
        return const_string(expr)
    elseif isa(expr, Expr)
        if expr.head == :call
            # Function call or operator
            op_sym = expr.args[1]
            op_str = string(op_sym)
            args = [parse_expression(arg) for arg in expr.args[2:end]]
            return op(op_str, args...)
        elseif expr.head == :(::) && length(expr.args) == 2
            # Domain annotation (e.g., expr : Domain)
            inner_expr = parse_expression(expr.args[1])
            domain = string(expr.args[2])
            return domain_annotation(inner_expr, domain)
        elseif expr.head == :call && expr.args[1] == :(:)
            # Alternative syntax for domain annotation
            inner_expr = parse_expression(expr.args[2])
            domain = string(expr.args[3])
            return domain_annotation(inner_expr, domain)
        elseif expr.head == :call && expr.args[1] == :!:
            # Negative domain annotation (e.g., expr !: Domain)
            inner_expr = parse_expression(expr.args[2])
            domain = string(expr.args[3])
            return negative_domain_annotation(inner_expr, domain)
        else
            error("Unsupported expression type: $(expr.head)")
        end
    else
        error("Unsupported expression: $expr")
    end
end

# Macros for natural syntax
macro pattern(expr)
    pattern = parse_expression(expr)
    return :($(esc(pattern)))
end

macro rule(expr)
    if expr.head == :call && length(expr.args) >= 3
        if expr.args[1] == :(u2192) || expr.args[1] == :(->) # Unidirectional rule
            lhs = parse_expression(expr.args[2])
            rhs = parse_expression(expr.args[3])
            
            # Check for condition
            condition = nothing
            if length(expr.args) > 3 && expr.args[4] isa Expr && expr.args[4].head == :if
                condition = expr.args[4].args[1]
            end
            
            rule = Dict("type" => "rule", "lhs" => lhs, "rhs" => rhs)
            if condition !== nothing
                rule["condition"] = Meta.quot(condition)
            end
            
            return :($(esc(rule)))
        elseif expr.args[1] == :(u2194) || expr.args[1] == :(==) # Bidirectional rule
            lhs = parse_expression(expr.args[2])
            rhs = parse_expression(expr.args[3])
            
            rule = Dict("type" => "bidirectional_rule", "lhs" => lhs, "rhs" => rhs)
            return :($(esc(rule)))
        end
    end
    
    error("Invalid rule syntax: $expr")
end

# Additional helper for applying rules
function apply_rule(graph::OGraph.OGraph, rule::Dict, tracing::Bool=false)
    if rule["type"] == "rule"
        # Unidirectional rule
        lhs = rule["lhs"]
        rhs = rule["rhs"]
        condition = get(rule, "condition", nothing)
        
        # Match the pattern and apply the transformation
        match_count = OGraphPattern.match_pattern(graph, lhs, (bindings, eclass_id) -> begin
            # Check condition if present
            if condition !== nothing
                # Evaluate condition with bindings
                # This is a simplified version - in practice you'd need to evaluate the condition
                # using the current bindings
                if !eval_condition(condition, bindings, graph)
                    return
                end
            end
            
            # Apply transformation
            # This would involve building the RHS with the current bindings
            # and merging the resulting node with the matched eclass
            result_id = instantiate_pattern(graph, rhs, bindings)
            if result_id !== nothing
                OGraph.merge_classes(graph, eclass_id, result_id)
            end
        end, tracing)
        
        return match_count
    elseif rule["type"] == "bidirectional_rule"
        # Apply in both directions
        lhs_to_rhs = Dict("type" => "rule", "lhs" => rule["lhs"], "rhs" => rule["rhs"])
        rhs_to_lhs = Dict("type" => "rule", "lhs" => rule["rhs"], "rhs" => rule["lhs"])
        
        count1 = apply_rule(graph, lhs_to_rhs, tracing)
        count2 = apply_rule(graph, rhs_to_lhs, tracing)
        
        return count1 + count2
    end
    
    return 0
end

# Helper to evaluate conditions - this would need more work to be complete
function eval_condition(condition, bindings, graph)
    # Placeholder for condition evaluation
    # In a real implementation, you'd evaluate the condition expression
    # with the current bindings
    return true
end

# Helper to instantiate a pattern with bindings
function instantiate_pattern(graph::OGraph.OGraph, pattern::Dict, bindings::Dict{String, Int})
    if pattern["type"] == "variable"
        var_name = pattern["name"]
        if haskey(bindings, var_name)
            return bindings[var_name]
        else
            return nothing
        end
    elseif pattern["type"] == "literal"
        # Create a literal node
        value = pattern["value"]
        if isa(value, Int)
            node = OGraph.ONode("Int", Int[])
            node_id = OGraph.insert_node(graph, node)
            OGraph.set_class_int(graph, node_id, value)
            return node_id
        elseif isa(value, Float64)
            node = OGraph.ONode("Double", Int[])
            node_id = OGraph.insert_node(graph, node)
            OGraph.set_class_double(graph, node_id, value)
            return node_id
        elseif isa(value, String)
            node = OGraph.ONode("String", Int[])
            node_id = OGraph.insert_node(graph, node)
            OGraph.set_class_string(graph, node_id, value)
            return node_id
        end
    elseif pattern["type"] == "binary_operation"
        # Create operation node with instantiated children
        left_id = instantiate_pattern(graph, pattern["left"], bindings)
        right_id = instantiate_pattern(graph, pattern["right"], bindings)
        
        if left_id !== nothing && right_id !== nothing
            node = OGraph.ONode(pattern["operator"], [left_id, right_id])
            return OGraph.insert_node(graph, node)
        end
    elseif pattern["type"] == "operation"
        # Create n-ary operation
        child_ids = []
        for arg in pattern["args"]
            child_id = instantiate_pattern(graph, arg, bindings)
            if child_id === nothing
                return nothing
            end
            push!(child_ids, child_id)
        end
        
        node = OGraph.ONode(pattern["operator"], child_ids)
        return OGraph.insert_node(graph, node)
    elseif pattern["type"] == "type_annotation"
        # Create the expression
        expr_id = instantiate_pattern(graph, pattern["expression"], bindings)
        
        if expr_id !== nothing
            # Find or create the domain
            domain_name = pattern["domain"]["name"]
            domain_id = find_or_create_domain(graph, domain_name)
            
            # Add the domain to the expression
            OGraph.add_belongs_to_node(graph, expr_id, domain_id)
            
            return expr_id
        end
    elseif pattern["type"] == "negative_type_annotation"
        # We don't create nodes with negative domain annotations,
        # but we can instantiate the expression part
        return instantiate_pattern(graph, pattern["expression"], bindings)
    end
    
    return nothing
end

# Helper to find or create a domain node
function find_or_create_domain(graph::OGraph.OGraph, domain_name::String)
    # Search for existing domain
    domain_id = nothing
    OGraph.traverse_ograph(graph, (id, node) -> begin
        if node.op == "Domain" && OGraph.get_class_string(graph, id) == domain_name
            domain_id = id
        end
    end)
    
    if domain_id !== nothing
        return domain_id
    end
    
    # Create new domain
    domain_node = OGraph.ONode("Domain", Int[])
    domain_id = OGraph.insert_node(graph, domain_node)
    OGraph.set_class_string(graph, domain_id, domain_name)
    
    return domain_id
end

end # module