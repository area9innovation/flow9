import Flow;

class Environment {
	public function new() {
		variables = new Map();
	}
	public function add(e : Environment) : Environment {
		var overridden = new Environment();
		for (variableName in e.variables.keys()) {
			var value = e.variables.get(variableName);
			// Save the original value to be able to restore this later
			if (variables.exists(variableName)) {
				overridden.variables.set(variableName, variables.get(variableName));
			}
			variables.set(variableName, value);
		}
		return overridden;
	}
	public function retract(e : Environment) : Void {
		for (variableName in e.variables.keys()) {
			var value = e.variables.get(variableName);
			variables.set(variableName, value);
		}
	}
	
	public function serialize(indent : String) : String {
		if (false) {
			var r = '';
			var sep = '\n' + indent;
			for (v in variables.keys()) {
				r += sep + v + '=';
				r += Prettyprint.prettyprint(variables.get(v), indent + '  ');
				sep = ',\n' + indent;
			}
			if (r == '') return r;
			return "Environment([" + r + '\n' + indent + '])';
		} else {
			var r = '';
			var sep = '';
			for (v in variables.keys()) {
				r += sep + v;
				sep = ',';
			}
			if (r == '') return r;
			return "Environment([" + r + '])';
		}
	}
	
	public function lookup(name : String) : Flow {
		return variables.get(name);
	}
	
	public function define(name : String, value : Flow) : Void {
		variables.set(name, value);
	}
	
	public function revoke(name : String) : Void {
		variables.remove(name);
	}
	
	public function getFreeVariables() : FlowArray<Flow> {
		var vars = new FlowArray();
		for (a in variables) {
			vars.push(a);
		}
		return vars;
	}
	public var variables : Map<String,Flow>;
}
