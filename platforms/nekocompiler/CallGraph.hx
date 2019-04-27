import FlowArray;
import Flow;

#if sys
import sys.io.File;
#end

enum StaticInfo {
	VarUse(n : String);
	Call(n : String);
	LetDef(n : String);
}

typedef Info = FlowArray<StaticInfo>;


class CallGraph {
	public function new() {
	}

	public function make(i : FlowInterpreter, output : String) {
		calls = new Map<String,Map<String,Bool>>();
		lets = new Map<String,Map<String,Bool>>();
		uses = new Map<String,Map<String,Bool>>();
		
		for (d in i.order) {
			var c = i.topdecs.get(d);
			var info = populateCalls(d, c);
			
			for (inf in info) {
				switch (inf) {
				case VarUse(n) : 
					if (i.topdecs.get(n) != null) {
						set(d, n, uses);
					}
				case Call(n): {
					if (i.topdecs.get(n) != null) {
						set(d, n, calls);
					}
				}
				case LetDef(n): set(d, n, lets);
				}
			}
		}
		
		#if sys
		var file = File.write(output, true);
		file.writeString(asDot(i));
		file.close();
		#end
	}

	public function makeForDark(i : FlowInterpreter, modules : Modules, output : String) {
		var ret = "";
		
		var dump = function(m : Map<String,Map<String,Bool>>) : String {
			var tmp = "";
			for (from in m.keys()) {
				tmp += from + ":";
				var tos = m.get(from);
				if (tos != null) {
					for (to in tos.keys()) {
						tmp += ' ' + to;
					}
				}
				tmp += '\n';
			}
			return tmp;
		};

		for (f in modules.modules.keys()) {
			var module = modules.getModule(f);
			var moduleName = module.name;
			ret += "*** file: " + moduleName + '.flow\n';

			// per module data
			calls = new Map<String,Map<String,Bool>>();
			lets = new Map<String,Map<String,Bool>>();
			uses = new Map<String,Map<String,Bool>>();

			for (d in module.declarations) {
				var c = i.topdecs.get(d);
				if (c == null) c = module.toplevel.get(d);
				var info = populateCalls(d, c);
				
				set(d, null, calls);
				
				if (info == null || info.length <= 0) {

				} else {
					for (inf in info) {
						switch (inf) {
							case VarUse(n) : 
								if (i.topdecs.get(n) != null) {
									set(d, n, uses);
								}
							case Call(n): {
								if (i.topdecs.get(n) != null) {
									set(d, n, calls);
								}
							}
							case LetDef(n): { 
								set(d, n, lets);
							}
						}
					}
				}
			}

			ret += dump(calls);
		}

		#if sys
		var file = File.write(output, true);
		file.writeString(ret);
		file.close();
		#end
	}

	public function collectUses(m : Module) : FlowArray<String> {
		var uses = new FlowArray();
		
		var recordUse = function(info : FlowArray<StaticInfo>) {
			for (inf in info) {
				if (inf != null) {
					switch (inf) {
					case VarUse(n) : 
						uses.push(n);
					case Call(n): {
						uses.push(n);
					}
					case LetDef(n): 
					}
				}
			}
		}
		
		for (d in m.toplevel.keys()) {
			var c : Flow = m.toplevel.get(d);
			var info = new FlowArray();
			traverse(c, info);
			recordUse(info);
		}
		for (d in m.userTypeDeclarations.keys()) {
			var t = m.userTypeDeclarations.get(d);
			var info = new FlowArray();
			traverseType(t.type.type, info);
			recordUse(info);
		}
		for (u in m.unittests) {
			var info = new FlowArray();
			traverse(u, info);
			recordUse(info);
		}
		return uses;
	}
	
	function asDot(i : FlowInterpreter) : String {
		var dot = 'digraph "Call" {\n';
		
		dot += 'node [shape=box, margin="0.3, 0.1"]\n';

		// Declare nodes
/*		for (d in i.order) {
			dot += asDotNode(d);
		}
*/
		dot += edges(uses, "black");
		dot += edges(calls, "blue");
//		dot += edges(lets, "red");

		dot += "}\n";
		return dot;
	}	
	
	function asDotNode(n : String) {
		var dot = '"' + nodeId(n) + '" [label="';
		var label = nodeId(n);
		dot += label;

		dot += '"'
			+ '];\n';
		return dot;
	}

	function edges(h : Map<String,Map<String,Bool>>, color : String) : String {
		var dot = "";
		// Declare edges
		for (from in h.keys()) {
			var tos = h.get(from);
			if (tos != null) {
				var fromNode = nodeId(from);
				for (to in tos.keys()) {
					// node1 -> node2 [label="Label" color="lightgrey"];
					dot += '"' + fromNode + '" -> "' + nodeId(to) + '" [color="' + color + '"];\n';
				}
			}
		}
		return dot;
	}

	function nodeId(n : String) {
		return n;
	}
	
	function set(from : String, to : String, hash : Map<String,Map<String,Bool>>) {
		var e = hash.get(from);
		if (to != null) {
			if (e == null) {
				e = new Map();
			}
			e.set(to, true);
		}

		hash.set(from, e);
	}
	
	// A call from function Key to [ Value ]
	var calls : Map<String,Map<String,Bool>>;
	var uses : Map<String,Map<String,Bool>>;
	var lets : Map<String,Map<String,Bool>>;

	private function populateCalls(from : String, f : Flow) : FlowArray<StaticInfo> {
		var info = new FlowArray();
		traverse(f, info);
		return info;
	}
	
	private function traverse(e : Flow, out : Info) {
		try {
			traverse0(e, out);
		} catch (E : Dynamic) {
			// the exception we get is a crazy haxe bug: "VerifyError #1068:
			// __AS3__.vec.Vector & * cannot be reconciled"
		}
	}
	private function traverse0(e : Flow, out : Info) {
		if (e == null) {
			return;
		}
		switch (e) {
			case SyntaxError(s, pos):
			case ConstantVoid(pos):
			case ConstantBool(value, pos):
			case ConstantI32(value, pos): 
			case ConstantDouble(value, pos):
			case ConstantString(value, pos):
			case ConstantArray(value, pos):
				traverseList(value, e, out);
			case ConstantStruct(newname, values, pos):
				traverseList(values, e, out);
			case ConstantNative(value, pos):
			case ArrayGet(array, index, pos):
				traverse(array, out);
				traverse(index, out);
			case VarRef(name, pos):
				out.push(VarUse(name));
			case Field(call, name, pos):
				traverse(call, out);
			case RefTo(value, pos):
				traverse(value, out);
			case Pointer(index, pos):
			case Deref(pointer, pos):
				traverse(pointer, out);
			case SetRef(pointer, value, pos):
				traverse2(pointer, value, e, out);
			case SetMutable(pointer, field, value, pos):
				traverse2(pointer, value, e, out);
			case Cast(value, fromtype, totype, pos):
				traverse(value, out);
				traverseType(fromtype, out);
				traverseType(totype, out);
			case Let(name, sigma, value, scope, pos): {
				out.push(LetDef(name));
				traverse2(value, scope, e, out);
				if (sigma != null) {
					traverseType(sigma.type, out);
				}
			}
            case Lambda(arguments, type, body, _, pos):
				for (n in arguments) {
					out.push(LetDef(n));
				}
				traverse(body, out);
				traverseType(type, out);
			case Closure(body, environment, pos):
				traverse(body, out);
			case Flow.Call(closure, arguments, pos):
				switch (closure) {
					case VarRef(n, pos) :
						out.push(Call(n));
					default: traverse(closure, out);
					};
				traverseList(arguments, e, out);
			case Sequence(statements, pos):
				traverseList(statements, e, out);
			case If(condition, then, elseExp, pos):
				traverse(condition, out);
				traverse(then, out);
				traverse(elseExp, out);
			case Not(e, pos): traverse(e, out);
			case Negate(e, pos): traverse(e, out);
			case Multiply(e1, e2, pos):
				traverse2(e1, e2, e, out);
			case Divide(e1, e2, pos):
				traverse2(e1, e2, e, out);
			case Modulo(e1, e2, pos):
				traverse2(e1, e2, e, out);
			case Plus(e1, e2, pos):
				traverse2(e1, e2, e, out);
			case Minus(e1, e2, pos):
				traverse2(e1, e2, e, out);
			case Equal(e1, e2, pos):
				traverse2(e1, e2, e, out);
			case NotEqual(e1, e2, pos):
				traverse2(e1, e2, e, out);
			case LessThan(e1, e2, pos):
				traverse2(e1, e2, e, out);
			case LessEqual(e1, e2, pos):
				traverse2(e1, e2, e, out);
			case GreaterThan(e1, e2, pos):
				traverse2(e1, e2, e, out);
			case GreaterEqual(e1, e2, pos):
				traverse2(e1, e2, e, out);
			case And(e1, e2, pos):
				traverse2(e1, e2, e, out);
			case Or(e1, e2, pos):
				traverse2(e1, e2, e, out);
			case Switch(value, type, cases, pos) :
				for (c in cases) {
					if (c.structname != "default") {
						out.push(LetDef(c.structname));
					}
					traverse(c.body, out);
				}
				traverseType(type, out);
			case SimpleSwitch(value, cases, pos) :
				for (c in cases) {
					if (c.structname != "default") {
						out.push(LetDef(c.structname));
					}
					traverse(c.body, out);
				}
			case Native(name, io, args, result, defbody, pos):
				if (defbody != null) traverse(defbody, out);
			case NativeClosure(nargs, fn, pos):
			case StackSlot(q0, q1, q2):
		}
	}
	
	function traverseType(t : FlowType, out : Info) {
		try {
			traverseType0(t, out);
		} catch (E : Dynamic) {
			// the exception we get is a crazy haxe bug: "VerifyError #1068:
			// __AS3__.vec.Vector & * cannot be reconciled"
		}
	}
	
	function traverseType0(t : FlowType, out : Info) {
		if (t == null) return;
		switch (t) {
			case TVoid:
			case TBool:
			case TInt:
			case TDouble:
			case TString:
			case TReference(type): traverseType(type, out);
			case TPointer(type): traverseType(type, out);
			case TArray(type): traverseType(type, out);
			case TFunction(args, returns): 
				traverseType(returns, out);
				for (a in args) {
					traverseType(a, out);
				}
			case TStruct(structname, args, max): 
				out.push(VarUse(structname));
				for (a in args) {
					traverseType(a.type, out);
				}
			case TUnion(min, max): {
				for (st in min) {
					traverseType(st, out);
				}
				for (st in max) {
					traverseType(st, out);
				}
			}
			case TTyvar(ref): traverseType(ref.type, out);
			case TBoundTyvar(i):
			case TFlow:
			case TNative:
			case TName(name, args): out.push(VarUse(name));
		}
	}
	
	private function traverseList(es : FlowArray<Flow>, place : Flow, out : Info) {
		for (e in es) {
			traverse(e, out);
		}
	}

	function traverse2(e1 : Flow, e2 : Flow, place : Flow, out : Info) {
		traverse(e1, out);
		traverse(e2, out);
	}

	/*function singleton(i : StaticInfo) : FlowArray<StaticInfo> {
		var is = new FlowArray();
		is.push(i);
		return is;
	}*/
}
