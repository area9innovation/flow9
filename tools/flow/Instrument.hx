import FlowUtil;
import Flow;
import FlowArray;

class Instrument {
	// A facility to add debug tracing for the listed names
	public static function instrument(p : Program, variables : String) : Void {
		// A fast way to see if a name is hit
		var vars = new Map();
		for (v in variables.split(",")) {
			vars.set(v, true);
		}
		
		var traceFound = false;
		var toStringFound = false;
	
		// First, register all strings and find the duplicated ones
		for (d in p.declsOrder) {
			traceFound = traceFound || d == "trace";
			toStringFound = toStringFound || d == "toString";
			if (vars.exists(d)) {
				var e = p.topdecs.get(d);
				switch (e) {
					case Lambda(arguments, type, body, _, pos): {
						var instrumented = instrumentFunction(d, body, pos);
						p.topdecs.set(d, FlowUtil.lambda(arguments, type, instrumented, pos));
					}
					default: {
						trace("Does not support instrumenting " + e + " yet");
					}
				}
			}
		}
		
		if (!traceFound) {
			Errors.print("--instrument requires \"trace = ref false;\" to be defined. Try \"import runtime;\"");
		}
		if (!toStringFound) {
			Errors.print("--instrument requires \"native toString : (flow) -> string = Native.toString;\" to be defined.  Try \"import runtime;\"");
		}
	}
	
	/*
		fn(args) -> ret {
			body
		}
	
	should be changed to
	
		fn(args) -> ret {
			if (trace) {
				println("fn called");
			}
			r = body;
			if (trace) {
				println("fn gave" + toString(r));
			}
			r;
		}
	*/
	static function instrumentFunction(name : String, body : Flow, pos : Position) : Flow {
		var p : Position = { f: pos.f, l: pos.l, s: pos.s, e: pos.e, type: null, type2: null };
		var sp : Position = { f: pos.f, l: pos.l, s: pos.s, e: pos.e, type: TString, type2: null };

		var instrumented = Sequence(FlowArrayUtil.fromArray([
			If(	Deref(VarRef("trace", p), p), 
				Call(VarRef("println", p), FlowArrayUtil.one(ConstantString(name, p)), p),
				ConstantVoid(p),
				p),
			Let( "$r", null, body, 
				Sequence(FlowArrayUtil.two(
					If(	Deref(VarRef("trace", p), p), 
						Call(VarRef("println", p), 
							FlowArrayUtil.one(
								Plus(
									ConstantString(name + "=", sp),
									Call(VarRef("toString", p), FlowArrayUtil.one(VarRef("$r", p)), p),
									sp
								)
							), p),
						ConstantVoid(p),
					p),
					VarRef("$r", p)
				), p)
			, p)
		]), p);
	
		return instrumented;
	}
}

