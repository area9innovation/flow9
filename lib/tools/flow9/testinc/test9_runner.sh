#!/bin/bash

# Initial compilation with update-incremental=1
echo "=== Initial compilation test9b.flow with update-incremental=1 ==="
flowcpp --batch flow9.flow -- testinc/test9b.flow update-incremental=1 verbose=1

# Change the recursive type by adding an attribute to Node
echo ""
echo "=== Changing Node struct to add a label field in test9a.flow ==="
sed -i 's/Node(value: ?, left: TreeNode<?>, right: TreeNode<?>);/Node(value: ?, label: string, left: TreeNode<?>, right: TreeNode<?>);/' testinc/test9a.flow
sed -i 's/Node(__, left, right): 1 + max(treeDepth(left), treeDepth(right));/Node(__, __, left, right): 1 + max(treeDepth(left), treeDepth(right));/' testinc/test9a.flow

# Recompile without update-incremental to see if changes are detected
echo ""
echo "=== Recompiling test9b.flow without update-incremental ==="
flowcpp --batch flow9.flow -- testinc/test9b.flow verbose=1

# Restore the original file
echo ""
echo "=== Restoring original file ==="
sed -i 's/Node(value: ?, label: string, left: TreeNode<?>, right: TreeNode<?>);/Node(value: ?, left: TreeNode<?>, right: TreeNode<?>);/' testinc/test9a.flow
sed -i 's/Node(__, __, left, right): 1 + max(treeDepth(left), treeDepth(right));/Node(__, left, right): 1 + max(treeDepth(left), treeDepth(right));/' testinc/test9a.flow