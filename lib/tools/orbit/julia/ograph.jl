module OGraph

using DataStructures

export ONode, OClass, OGraph, 
       make_ograph, find_root, insert_node, lookup_class,
       change_node_in_class, merge_classes, find_node,
       find_node_ignore_belongs_to, nodes_structurally_equal,
       traverse_ograph, insert_or_find_node, 
       set_class_int, get_class_int, set_class_double, get_class_double,
       set_class_string, get_class_string, 
       add_belongs_to_node, remove_belongs_to_from_node,
       node_belongs_to, get_node_belongs_to

# Core data structures
"""
    ONode

A node in the graph with an operator, children, and domain memberships.
"""
struct ONode
    op::String
    children::Vector{Int}
    belongs_to::Vector{Int}

    # Constructor with default empty belongsTo
    ONode(op::String, children::Vector{Int}) = new(op, children, Int[])
    ONode(op::String, children::Vector{Int}, belongs_to::Vector{Int}) = new(op, children, belongs_to)
end

"""
    OClass

An equivalence class with a canonical root ID and a node.
"""
struct OClass
    root::Int
    node::ONode
end

"""
    OGraph

Main data structure for graph operations with equivalence classes, 
a union-find structure, and storage for primitive values.
"""
mutable struct OGraph
    oclasses::Dict{Int, OClass}    # Map from class id to equivalence class
    classes::Dict{Int, Int}        # Union-find data structure: maps from an id to its parent id
    next_id::Int                   # Next available id
    int_values::Dict{Int, Int}            # Integer values associated with eclasses
    double_values::Dict{Int, Float64}     # Double values associated with eclasses
    string_values::Dict{Int, String}      # String values associated with eclasses
end

# Core functions

"""
    make_ograph() -> OGraph

Create a new, empty OGraph.
"""
function make_ograph()
    OGraph(
        Dict{Int, OClass}(),       # oclasses
        Dict{Int, Int}(),          # classes
        1,                         # next_id - start IDs from 1
        Dict{Int, Int}(),          # int_values
        Dict{Int, Float64}(),      # double_values
        Dict{Int, String}()        # string_values
    )
end

"""
    find_root(graph::OGraph, id::Int) -> Int

Find the canonical id (root) of the equivalence class for a node.
"""
function find_root(graph::OGraph, id::Int)
    if !haskey(graph.classes, id)
        return id  # This is the root
    end
    
    parent_id = graph.classes[id]
    if parent_id != id
        # Find the root recursively with path compression
        root = find_root(graph, parent_id)
        graph.classes[id] = root  # Path compression
        return root
    else
        return id
    end
end

"""
    lookup_class(graph::OGraph, id::Int) -> Union{OClass, Nothing}

Look up a node in the graph.
"""
function lookup_class(graph::OGraph, id::Int)
    root = find_root(graph, id)
    get(graph.oclasses, root, nothing)
end

"""
    change_node_in_class(graph::OGraph, class_id::Int, node::ONode)

Add a node to an equivalence class.
"""
function change_node_in_class(graph::OGraph, class_id::Int, node::ONode)
    root = find_root(graph, class_id)
    if haskey(graph.oclasses, root)
        # Create a new OClass with the same root but the new node
        updated_class = OClass(root, node)
        graph.oclasses[root] = updated_class
    end
end

"""
    insert_node(graph::OGraph, node::ONode) -> Int

Insert a new node into the graph and return its id.
"""
function insert_node(graph::OGraph, node::ONode)
    # Get the next available ID
    new_id = graph.next_id
    
    # Ensure belongs_to includes at least the primary domain ID if it's a new node with empty belongs_to
    updated_node = if isempty(node.belongs_to)
        ONode(node.op, node.children, [new_id])
    else
        node
    end
    
    # Create new class
    new_class = OClass(new_id, updated_node)
    
    # Add the node to the graph
    graph.oclasses[new_id] = new_class
    graph.classes[new_id] = new_id  # Points to itself initially
    
    # Increment the ID counter for next use
    graph.next_id = new_id + 1
    
    return new_id
end

"""
    insert_or_find_node(graph::OGraph, node::ONode) -> Int

Insert a node if it doesn't exist, or find its id if it does.
"""
function insert_or_find_node(graph::OGraph, node::ONode)
    # First check if the node already exists
    existing_node = find_node(graph, node.op, node.children)
    if existing_node !== nothing
        return find_root(graph, existing_node)  # Return canonical id
    else
        return insert_node(graph, node)  # Insert the new node
    end
end

"""
    find_node(graph::OGraph, op::String, children::Vector{Int}) -> Union{Int, Nothing}

Find a node in the graph that matches the op and children.
"""
function find_node(graph::OGraph, op::String, children::Vector{Int})
    # Find canonical representatives for all children
    canonical_children = [find_root(graph, child) for child in children]
    
    # Look through all nodes in the graph to find a match
    for (class_id, oclass) in graph.oclasses
        if oclass.node.op == op && length(oclass.node.children) == length(canonical_children)
            # Check if all children match
            all_match = true
            for (i, child) in enumerate(oclass.node.children)
                if i > length(canonical_children) || find_root(graph, child) != canonical_children[i]
                    all_match = false
                    break
                end
            end
            
            if all_match
                return class_id
            end
        end
    end
    
    return nothing
end

"""
    find_node_ignore_belongs_to(graph::OGraph, op::String, children::Vector{Int}) -> Union{Int, Nothing}

Find a node in the graph that matches op and children structurally, ignoring belongsTo.
"""
function find_node_ignore_belongs_to(graph::OGraph, op::String, children::Vector{Int})
    # Look through all nodes in the graph to find a match
    for (class_id, oclass) in graph.oclasses
        if oclass.node.op == op && length(oclass.node.children) == length(children)
            # Check if all children match structurally
            all_children_match = true
            for (i, node_child) in enumerate(oclass.node.children)
                if i > length(children) || !nodes_structurally_equal(graph, node_child, children[i])
                    all_children_match = false
                    break
                end
            end
            
            if all_children_match
                return class_id
            end
        end
    end
    
    return nothing
end

"""
    nodes_structurally_equal(graph::OGraph, node_id1::Int, node_id2::Int) -> Bool

Helper function to check if two nodes are structurally equal.
"""
function nodes_structurally_equal(graph::OGraph, node_id1::Int, node_id2::Int)
    # Get the canonical IDs for both nodes
    root1 = find_root(graph, node_id1)
    root2 = find_root(graph, node_id2)
    
    # If they're the same canonical node, they're definitely equal
    if root1 == root2
        return true
    end
    
    # Otherwise, check structural equality
    node1 = lookup_class(graph, root1)
    node2 = lookup_class(graph, root2)
    
    if node1 === nothing || node2 === nothing
        return false
    end
    
    # Check if the operators match
    if node1.node.op != node2.node.op || 
       length(node1.node.children) != length(node2.node.children)
        return false
    end
    
    # For leaf nodes, check primitive values if relevant
    if isempty(node1.node.children)
        if node1.node.op == "Int"
            int1 = get_class_int(graph, root1)
            int2 = get_class_int(graph, root2)
            return int1 == int2
        elseif node1.node.op == "Double"
            double1 = get_class_double(graph, root1)
            double2 = get_class_double(graph, root2)
            return double1 == double2
        elseif node1.node.op == "String" || node1.node.op == "Identifier" || node1.node.op == "Variable"
            str1 = get_class_string(graph, root1)
            str2 = get_class_string(graph, root2)
            return str1 == str2
        else
            # Other leaf nodes just need to have the same op
            return true
        end
    else
        # For non-leaf nodes, recursively check all children
        for j in 1:length(node1.node.children)
            if j > length(node2.node.children) || 
               !nodes_structurally_equal(graph, node1.node.children[j], node2.node.children[j])
                return false
            end
        end
        return true
    end
end

"""
    merge_classes(graph::OGraph, id1::Int, id2::Int)

Merge two equivalence classes.
"""
function merge_classes(graph::OGraph, id1::Int, id2::Int)
    root1 = find_root(graph, id1)
    root2 = find_root(graph, id2)
    
    if root1 != root2
        # We always use the first as the new root to ensure specificity is preserved
        new_root = root1
        old_root = root2
        
        # Update the union-find data structure
        graph.classes[old_root] = new_root
        
        # Also need to update the OClass mapping
        if haskey(graph.oclasses, old_root)
            old_class = graph.oclasses[old_root]
            # The old class points to the new root
            updated_old_class = OClass(new_root, old_class.node)
            graph.oclasses[old_root] = updated_old_class
        end
    end
end

"""
    traverse_ograph(graph::OGraph, fn::Function)

Traverse the graph and apply a function to each node.
The function takes (id::Int, node::ONode) as arguments.
"""
function traverse_ograph(graph::OGraph, fn::Function)
    for (_, oclass) in graph.oclasses
        root = find_root(graph, oclass.root)
        if root == oclass.root
            fn(oclass.root, oclass.node)
        end
    end
end

# Primitive value functions

"""
    set_class_int(graph::OGraph, eclass::Int, value::Int)

Associate an int value with an eclass.
"""
function set_class_int(graph::OGraph, eclass::Int, value::Int)
    graph.int_values[eclass] = value
end

"""
    get_class_int(graph::OGraph, eclass::Int) -> Union{Int, Nothing}

Retrieve the int value associated with an eclass, if it exists.
"""
function get_class_int(graph::OGraph, eclass::Int)
    get(graph.int_values, eclass, nothing)
end

"""
    set_class_double(graph::OGraph, eclass::Int, value::Float64)

Associate a double value with an eclass.
"""
function set_class_double(graph::OGraph, eclass::Int, value::Float64)
    graph.double_values[eclass] = value
end

"""
    get_class_double(graph::OGraph, eclass::Int) -> Union{Float64, Nothing}

Retrieve the double value associated with an eclass, if it exists.
"""
function get_class_double(graph::OGraph, eclass::Int)
    get(graph.double_values, eclass, nothing)
end

"""
    set_class_string(graph::OGraph, eclass::Int, value::String)

Associate a string value with an eclass.
"""
function set_class_string(graph::OGraph, eclass::Int, value::String)
    graph.string_values[eclass] = value
end

"""
    get_class_string(graph::OGraph, eclass::Int) -> Union{String, Nothing}

Retrieve the string value associated with an eclass, if it exists.
"""
function get_class_string(graph::OGraph, eclass::Int)
    get(graph.string_values, eclass, nothing)
end

# Domain membership functions

"""
    add_belongs_to_node(graph::OGraph, node_id::Int, domain_id::Int)

Add a domain to a node's belongsTo list.
"""
function add_belongs_to_node(graph::OGraph, node_id::Int, domain_id::Int)
    root = find_root(graph, node_id)
    oclass = lookup_class(graph, root)
    
    if oclass !== nothing
        # Only add if not already present
        if !(domain_id in oclass.node.belongs_to)
            updated_belongs_to = vcat(oclass.node.belongs_to, [domain_id])
            updated_node = ONode(
                oclass.node.op,
                oclass.node.children,
                updated_belongs_to
            )
            change_node_in_class(graph, root, updated_node)
        end
    end
end

"""
    remove_belongs_to_from_node(graph::OGraph, node_id::Int, domain_id::Int)

Remove a domain from a node's belongsTo list.
"""
function remove_belongs_to_from_node(graph::OGraph, node_id::Int, domain_id::Int)
    root = find_root(graph, node_id)
    oclass = lookup_class(graph, root)
    
    if oclass !== nothing
        # Filter out the domain to remove
        updated_belongs_to = filter(id -> id != domain_id, oclass.node.belongs_to)
        updated_node = ONode(
            oclass.node.op,
            oclass.node.children,
            updated_belongs_to
        )
        change_node_in_class(graph, root, updated_node)
    end
end

"""
    node_belongs_to(graph::OGraph, node_id::Int, domain_id::Int) -> Bool

Check if a node belongs to a specific domain.
"""
function node_belongs_to(graph::OGraph, node_id::Int, domain_id::Int)
    root = find_root(graph, node_id)
    oclass = lookup_class(graph, root)
    
    if oclass !== nothing
        return domain_id in oclass.node.belongs_to
    end
    return false
end

"""
    get_node_belongs_to(graph::OGraph, node_id::Int) -> Vector{Int}

Get all domains a node belongs to.
"""
function get_node_belongs_to(graph::OGraph, node_id::Int)
    root = find_root(graph, node_id)
    oclass = lookup_class(graph, root)
    
    if oclass !== nothing
        return oclass.node.belongs_to
    end
    return Int[]
end

end # module