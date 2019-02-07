import js.Browser;

import pixi.core.display.Container;
import pixi.core.display.DisplayObject;

using DisplayObjectHelper;

class AccessTreeNode {
	public var id : Int;
	@:isVar public var node(get, set) : AccessNode;
	@:isVar public var parent(get, set) : AccessTreeNode;
	public var children : Map<Int, AccessTreeNode> = new Map<Int, AccessTreeNode>();
	public var childrenChanged : Bool = false;
	public var changed : Bool = false;
	public var zOrder : Int = -9999;

	public function new(id : Int, ?node : AccessNode, ?parent : AccessTreeNode) {
		this.id = id;
		this.node = node;
		this.parent = parent;
	}

	public function get_node() : AccessNode {
		return node;
	}

	public function set_node(node : AccessNode) : AccessNode {
		if (this.node != node) {
			this.node = node;

			if (this.node != null) {
				this.node.parent = this;
			}
		}

		return this.node;
	}

	public function get_parent() : AccessTreeNode {
		return parent;
	}

	public function set_parent(parent : AccessTreeNode) : AccessTreeNode {
		if (this.parent != parent) {
			this.parent = parent;

			if (this.parent != null) {
				this.parent.updateZOrder();
			}
		}

		return this.parent;
	}

	public function updateZOrder() : Bool {
		var previousZOrder = zOrder;
		zOrder = node != null ? node.zOrder : -9999;

		for (child in children) {
			if (child.zOrder > zOrder) {
				zOrder = child.zOrder;
			}
		}

		if (zOrder == -9999) {
			return false;
		}

		if (parent == null || previousZOrder == zOrder || !parent.updateZOrder()) {
			updateDisplay();
			return true;
		} else {
			return false;
		}
	}

	public function updateDisplay() : Void {
		if (node != null && node.node != null) {
			if (RenderSupportJSPixi.DebugAccessOrder) {
				untyped node.node.setAttribute("zorder", zOrder);
				untyped node.node.setAttribute("nodeindex", node.nodeIndex);
			}

			untyped node.node.style.display = zOrder >= AccessNode.tree.zOrder && node.clip.getClipVisible() ? "block" : "none";
		}

		for (child in children) {
			child.updateDisplay();
		}
	}
}

class AccessNode {
	public static var tree : AccessTreeNode = new AccessTreeNode(0);

	public var clip : DisplayObject;
	public var node : js.html.Node;
	@:isVar public var nodeIndex(get, set) : Array<Int>;
	@:isVar public var zOrder(get, set) : Int;
	@:isVar public var parent(get, set) : AccessTreeNode;

	public function new(clip : DisplayObject, node : js.html.Node, ?nodeIndex : Array<Int>, ?zOrder : Int = -9999) {
		this.clip = clip;
		this.node = node;
		this.nodeIndex = nodeIndex;
		this.zOrder = zOrder;
	}

	public function get_nodeIndex() : Array<Int> {
		return nodeIndex;
	}

	public function set_nodeIndex(nodeIndex : Array<Int>) : Array<Int> {
		if (nodeIndex != null && this.nodeIndex != nodeIndex) {
			this.nodeIndex = nodeIndex;
			addNode(this);
		}

		return this.nodeIndex;
	}

	public function get_zOrder() : Int {
		return zOrder;
	}

	public function set_zOrder(zOrder : Int) : Int {
		if (this.zOrder != zOrder) {
			this.zOrder = zOrder;

			updateZOrder();
		}

		return this.zOrder;
	}

	public function get_parent() : AccessTreeNode {
		return parent;
	}

	public function set_parent(parent : AccessTreeNode) : AccessTreeNode {
		if (this.parent != parent) {
			this.parent = parent;

			updateZOrder();
		}

		return this.parent;
	}

	public function updateZOrder() : Void {
		if (parent != null) {
			parent.updateZOrder();
		}
	}

	public function updateDisplay() : Void {
		if (parent != null) {
			parent.updateDisplay();
		}
	}

	private static function addNode(node : AccessNode, ?nodeIndexPosition : Int = 0, ?tree : AccessTreeNode) : Void {
		if (node.nodeIndex == null || node.nodeIndex.length == 0) {
			return;
		}

		if (tree == null) {
			tree = AccessNode.tree;
		}

		var id = node.nodeIndex[nodeIndexPosition];

		if (nodeIndexPosition == node.nodeIndex.length - 1) {
			if (tree.children.get(id) != null) {
				tree.children.get(id).node = node;
			} else {
				tree.children.set(id, new AccessTreeNode(id, node, tree));
			}

			tree.children.get(id).changed = true;
		} else {
			if (tree.children.get(id) == null) {
				tree.children.set(id, new AccessTreeNode(id, null, tree));
			}

			addNode(node, nodeIndexPosition + 1, tree.children.get(id));
		}

		tree.childrenChanged = true;
	}

	public static function removeNode(node : AccessTreeNode) : Void {
		if (node.parent != null) {
			node.parent.children.remove(node.id);

			if (node.node != null && node.node.node != null && node.node.node.parentNode != null) {
				node.node.node.parentNode.removeChild(node.node.node);
			}

			if (!node.parent.children.keys().hasNext() && node.parent.node == null) {
				removeNode(node.parent);
			} else {
				node.parent.updateZOrder();
			}
		}
	}

	private static function printTree(?tree : AccessTreeNode, ?id : String = "") {
		if (tree == null) {
			tree = AccessNode.tree;
		}

		for (key in tree.children.keys()) {
			var node = tree.children.get(key).node;
			trace(id + key + " " + (node != null ? untyped node.node.getAttribute("role") : "null"));
			printTree(tree.children.get(key), id + key + " ");
		}
	}

	public static function updateAccessTree(?tree : AccessTreeNode, ?parent : js.html.Node) {
		if (tree == null) {
			tree = AccessNode.tree;
		}

		if (parent == null) {
			parent = Browser.document.body;
		}

		for (key in tree.children.keys()) {
			var child = tree.children.get(key);

			if (!child.childrenChanged && !child.changed) {
				continue;
			}

			var node = child.node;

			if (node != null && node.node != null) {
				if (child.changed) {
					parent.appendChild(node.node);
					child.changed = false;
				}

				updateAccessTree(child, node.node);
			} else {
				updateAccessTree(child, parent);
			}

			child.childrenChanged = false;
		}
	}
}