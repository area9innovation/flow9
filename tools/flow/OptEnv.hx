// Environment used during optimisation
import Flow;

class OptEnv {
	function new() {
	}

	static public function make() : OptEnv {
		var o = new OptEnv();
		o.locals = new FlowMap();
		o.unfolding = new Map();
		return o;
	}
	
/*KILL 06/12/2011 14:32. to:
	public function clone() : OptEnv {
		var oo = new OptEnv();
		oo.locals = FlowUtil.copyhash(locals);
		oo.unfolding = unfolding;
		return oo;
	}
*/

	var locals : FlowMap<Flow>;
	public var unfolding : Map<String,Bool>; // unfolding(id)=are we unfolding the lambda with this id

	public function getLocal(x : String) : Flow {
		return locals.get(x);
	}

	public function setLocal(x : String, y : Flow) : OptEnv {
		var o = new OptEnv();
		o.locals = locals.set(x, y);
		o.unfolding = unfolding;
		return o;
	}
}

