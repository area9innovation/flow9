// A functional map (i.e., non-side effecting) from string to any type, Y

import FlowUtil;
import BinTree;

class FlowMap<Y> {
/*
	public function new(t0 = null) {
			t = if (t0 == null) new Map<String,Y>() else t0;
	}

	public function get(s : String) : Y {
		return t.get(s);
	}

	public function set(s : String, y : Y) : Map<Y> {
		var t2 = FlowUtil.copyhash(t);
		t2.set(s, y);
		return new Map<Y>(t2);
	}
*/
	public function new(t0 = null) {
			t = if (t0 == null) TreeEmpty else t0;
	}

	public function get(s : String) : Y {
		return BinTree.lookupTree(t, s);
	}

	public function set(s : String, y : Y) : FlowMap<Y> {
		return new FlowMap<Y>(BinTree.addOrUpdateTree(t, s, y));
	}

	var t : BinaryTree<Y>;
}
