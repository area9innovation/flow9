
enum BinaryTree<Y> {
	TreeNode(key : String, value : Y, left : BinaryTree<Y>, right : BinaryTree<Y>, depth : Int);
	TreeEmpty;
}

// Struct PopResult is used (by in popmin() & popmax()) to return a triple of key, value &
// the new tree with max (or min) popped
typedef PopResult<Y> = {
	k : String,
	v : Y,
	rest : BinaryTree<Y>
}

class BinTree {
/*
	//makeTree : () -> BinaryTree;
makeTree() {
	TreeEmpty();
}
*/

static public function addOrUpdateTree<Y>(set : BinaryTree<Y>, key : String, value : Y) : BinaryTree<Y> {
	return switch (set) {
		case TreeNode(k, v, left, right, depth):
			if (key < k) {
				rebalancedTree(k, v, addOrUpdateTree(left, key, value), right);
			} else if (key == k) {
				// Update the value of this node
				mkTreeNode(k, value, left, right);
			} else {
				rebalancedTree(k, v, left, addOrUpdateTree(right, key, value));
			}
		case TreeEmpty:
			TreeNode(key, value, TreeEmpty, TreeEmpty, 1);
	}
}

static private function mkTreeNode<Y>(k : String, v : Y, left : BinaryTree<Y>, right : BinaryTree<Y>) : BinaryTree<Y> {
	return TreeNode(k, v, left, right, max(treeDepth(left), treeDepth(right)) + 1);
}

static private function max(i1 : Int, i2 : Int) : Int {
	return if (i1 < i2) i2 else i1;
}


static private function rebalancedTree(k, v, left, right) {
	var leftDepth = treeDepth(left);
	var rightDepth = treeDepth(right);
	
	var balance = leftDepth - rightDepth;
	
	var composed = mkTreeNode(k, v, left, right);
	
	return if (balance == -1 || balance == 0 || balance == 1) {
		composed;
	} else if (balance < 0) {
		// Right-right or right-left?
		switch (right) {
			case TreeEmpty: composed;
			case TreeNode(rk, rv, rl, rr, rdepth): {
				var rld = treeDepth(rl);
				var rrd = treeDepth(rr);
				if (rld < rrd) {
					// Right right
					treeLeftRotation(composed);
				} else {
					// Right left
					treeLeftRotation(mkTreeNode(k, v, left, treeRightRotation(right)));
				}
			}
		}
	} else {
		// Left-left or left-right?
		switch (left) {
			case TreeEmpty: composed;
			case TreeNode(lk, lv, ll, lr, ldepth): {
				var lld = treeDepth(ll);
				var lrd = treeDepth(lr);
				if (lld < lrd) {
					// Left right
					treeRightRotation(mkTreeNode(k, v, treeLeftRotation(left), right));
				} else {
					// Left left
					treeRightRotation(composed);
				}
			}
		}
	}
}

	//	lookupTree : (tree : BinaryTree<Y>, key : String) -> Maybe<??>;
	// null if key not found
static public function lookupTree<Y>(set : BinaryTree<Y>, key : String) : Y {
	return switch (set) {
		case TreeNode(k, v, l, r, depth):
			if (key < k) {
				lookupTree(l, key);
			} else if (key == k) {
				v;
			} else {
				lookupTree(r, key);
			}
		case TreeEmpty:
			null;
	}
}

static public function removeFromTree<Y>(set : BinaryTree<Y>, key : String) : BinaryTree<Y> {
	// TODO: We should do rebalancing here as well. http://en.wikipedia.org/wiki/AVL_tree
	return switch (set) {
		case TreeNode(k, v, left, right, depth):
			if (key < k) {
				mkTreeNode(k, v, removeFromTree(left, key), right);
			} else if (key == k) {
				mergeTree(left, right);
			} else {
				mkTreeNode(k, v, left, removeFromTree(right, key));
			}
		case TreeEmpty: set;
	}
}

// mergeTree = a new tree from merging 2 trees; do this by picking the top key/value from
// the leftmost tree & making that the new interior key/value
static private function mergeTree<Y>(t1 : BinaryTree<Y>, t2 : BinaryTree<Y>) : BinaryTree<Y> {
	return switch (t1) {
		case TreeEmpty: t2;
		case TreeNode(k1, v1, l1, r1, d1):
			switch (t2) {
				case TreeEmpty: t1;
				case TreeNode(k2, v2, l2, r2, d2): {
					var p = popmax(t1);
					if (p == null) TreeEmpty else mkTreeNode(p.k, p.v, p.rest, t2);
				}
			}
	}
}

// popmax(t, f) = split t in a new tree & a highest value.  
// Struct PopResult is used (by in popmin() & popmax()) to return a triple of key, value &
// the new tree with max (or min) popped
	
static public function popmax<Y>(t : BinaryTree<Y>) : PopResult<Y> {
	return switch (t) {
		case TreeEmpty: null;
		case TreeNode(k, v, l, r, d):
			switch (r) {
				case TreeEmpty: // so k,v is the bottom right corner value
					{k: k, v: v, rest: l};
				case TreeNode(k1, v1, l1, r1, d1): {
					var p = popmax(r);
					if (p == null) null else {k: p.k, v: p.v, rest: mkTreeNode(k, v, l, p.rest)};
				}
			}
	}
}
	
// This is symmetric to popmax
static public function popmin<Y>(t : BinaryTree<Y>) : PopResult<Y> {
	return switch (t) {
		case TreeEmpty: null;
		case TreeNode(k, v, l, r, d):
			switch (l) {
				case TreeEmpty: // so k,v is the bottom left corner value
					 {k: k, v: v, rest: r};
				case TreeNode(k1, v1, l1, r1, d1): {
					var p = popmin(l);
					if (p == null) null else {k: p.k, v: p.v, rest: mkTreeNode(k, v, r, p.rest)};
				}
			}
	}
}

/*
traversePreOrder : (tree : BinaryTree<Y>, fn : (key : String, value : Y) -> void) -> void;
traversePreOrder(tree, fn) {
	switch (tree : BinaryTree) {
		TreeEmpty: {}
		TreeNode(k, v, left, right, depth): {
			fn(k, v);
			traversePreOrder(left, fn);
			traversePreOrder(right, fn);
		}
	}
}

traverseInOrder : (tree : BinaryTree<Y>, fn : (key : String, value : Y) -> void) -> void;
traverseInOrder(tree, fn) {
	switch (tree : BinaryTree) {
		TreeEmpty:  {}
		TreeNode(k, v, left, right, depth): {
			traverseInOrder(left, fn);
			fn(k, v);
			traverseInOrder(right, fn);
		}
	}
}

traversePostOrder(tree, fn) {
	switch (tree : BinaryTree) {
		TreeEmpty:  {}
		TreeNode(k, v, left, right, depth): {
			traversePostOrder(left, fn);
			traversePostOrder(right, fn);
			fn(k, v);
		}
	}
}

	// using inorder traversal
	foldTree : (tree: BinaryTree<Y>, 
				acc: Z,
				f: (key : String, value: Y, acc: Z) -> ???
				) -> ???;

foldTree(tree, acc, f) {
	switch (tree : BinaryTree) {
		TreeEmpty: acc;
		TreeNode(k, v, left, right, depth): {
			acc1 = foldTree(left, acc, f);
			acc2 = f(k, v, acc1);
			acc3 = foldTree(right, acc2, f);
			acc3;
		}
	}
}

	// copy tree applying function to stored value in preorder
	mapTree : (tree: BinaryTree<Y>, 
				f: (value: Y) -> ???
				) -> BinaryTree<?, ???>;

mapTree(tree, f) {
	switch (tree : BinaryTree) {
		TreeEmpty: TreeEmpty;
		TreeNode(k, v, left, right, depth): {
			TreeNode(k, f(v), mapTree(left, f), mapTree(right, f), depth)
		}
	}
}

	sizeTree : (BinaryTree) -> int;
sizeTree(t) {
	switch (t : BinaryTree) {
		TreeEmpty: 0;
		TreeNode(k, v, l, r, depth): 1 + sizeTree(l) + sizeTree(r);
	}
}

	// A helper that adds an element to an array as the value of a key. This is useful when you have a tree of arrays values
	treePushToArrayValue(tree : BinaryTree<?, [??]>, key : String, value : Y) -> BinaryTree<?, [??]>;
treePushToArrayValue(tree, key, value) {
	c = lookupTree(tree, key);
	addOrUpdateTree(tree, key, arrayPush(either(c, []), value))
}

	// A helper which removes an element from an array as the value of a key. This is useful when you have a tree of arrays values
	treeRemoveFromArrayValue(tree : BinaryTree<?, [??]>, key : String, value : Y) -> BinaryTree<?, [??]>;
treeRemoveFromArrayValue(tree, key, value) {
	c = lookupTree(tree, key);
	switch (c : Maybe) {
		None(): tree;
		Some(v): {
			r = removeFirst(v, value);
			if (length(r) == 0) {
				removeFromTree(tree, key);
			} else {
				addOrUpdateTree(tree, key, r);
			}
		}
	}
}

	// A helper that gets the array associated with a key - returning [] if there is no such key. This is useful when you have a tree of arrays values
	getTreeArrayValue(tree : BinaryTree<?, [??]>, key : String) -> [??];
getTreeArrayValue(tree, key) {
	switch (lookupTree(tree, key) : Maybe) {
		None(): [];
		Some(v): v;
	}
}
*/

static private function treeDepth<Y>(tree : BinaryTree<Y>) : Int {
	return switch (tree) {
		case TreeEmpty: 0;
		case TreeNode(k, v, left, right, depth): depth;
	}
}

static private function treeRightRotation<Y>(tree : BinaryTree<Y>) : BinaryTree<Y> {
	return switch (tree) {
		case TreeEmpty: tree;
		case TreeNode(k, v, left, right, depth):
			switch (left) {
				case TreeEmpty:
					tree;
				case TreeNode(ck, cv, cleft, cright, cdepth):
					mkTreeNode(ck, cv, cleft, mkTreeNode(k, v, cright, right));
			}
	}
}

static private function treeLeftRotation<Y>(tree : BinaryTree<Y>) : BinaryTree<Y> {
	return switch (tree) {
		case TreeEmpty: tree;
		case TreeNode(k, v, left, right, depth):
			switch (right) {
				case TreeEmpty:
					tree;
				case TreeNode(ck, cv, cleft, cright, cdepth):
					mkTreeNode(ck, cv, mkTreeNode(k, v, left, cleft), cright);
			}
	}
}
}
