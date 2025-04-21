module OrbitUtils

using ..OGraph
using ..OrbitSyntax

export @insert_expr

"""Create a node in a graph with a given value and return its ID"""
function create_node(graph::OGraph.OGraph, value::Int)
    node = OGraph.ONode("Int", Int[])
    id = OGraph.insert_node(graph, node)
    OGraph.set_class_int(graph, id, value)
    return id
end

function create_node(graph::OGraph.OGraph, value::Float64)
    node = OGraph.ONode("Double", Int[])
    id = OGraph.insert_node(graph, node)
    OGraph.set_class_double(graph, id, value)
    return id
end

function create_node(graph::OGraph.OGraph, value::String)
    node = OGraph.ONode("String", Int[])
    id = OGraph.insert_node(graph, node)
    OGraph.set_class_string(graph, id, value)
    return id
end

"""Create a binary operation node (e.g., a + b)"""
function create_op_node(graph::OGraph.OGraph, op::String, left_id::Int, right_id::Int)
    node = OGraph.ONode(op, [left_id, right_id])
    return OGraph.insert_node(graph, node)
end

"""Create a domain node with the given name"""
function create_domain(graph::OGraph.OGraph, name::String)
    domain_node = OGraph.ONode("Domain", Int[])
    domain_id = OGraph.insert_node(graph, domain_node)
    OGraph.set_class_string(graph, domain_id, name)
    return domain_id
end

"""Add domain membership to a node"""
function add_domain(graph::OGraph.OGraph, node_id::Int, domain_id::Int)
    OGraph.add_belongs_to_node(graph, node_id, domain_id)
end

"""Helper function to build an expression recursively"""
function build_expression(graph::OGraph.OGraph, expr)
    if isa(expr, Expr) && expr.head == :call
        # Operation expression (e.g., a + b)
        op = string(expr.args[1])
        children = [build_expression(graph, arg) for arg in expr.args[2:end]]
        node = OGraph.ONode(op, children)
        return OGraph.insert_node(graph, node)
    elseif isa(expr, Int)
        # Integer literal
        return create_node(graph, expr)
    elseif isa(expr, Float64)
        # Float literal
        return create_node(graph, expr)
    elseif isa(expr, String)
        # String literal
        return create_node(graph, expr)
    elseif isa(expr, Symbol)
        # Variable/identifier - treat as a string value for simplicity
        return create_node(graph, string(expr))
    else
        error("Unsupported expression type: $(typeof(expr))")
    end
end

"""Macro to insert an expression into the graph directly

Usage: @insert_expr graph x + y
Returns the ID of the root node of the expression.
"""
macro insert_expr(graph, expr)
    return quote
        build_expression($(esc(graph)), $(QuoteNode(expr)))
    end
end

end # module