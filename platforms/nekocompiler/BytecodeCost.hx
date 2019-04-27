import BytecodeWriter;

// A facility to evaluate the space/time cost of a given AST
class BytecodeCost {
	public function new(interpreter : FlowInterpreter) {
		writer = new BytecodeWriter();
		debug = new DebugInfo(null);
		names = new Names();

		// Populate the names
		var n = 0;
		for (d in interpreter.order) {
			names.toplevelAndOuter.set(d, TopLevel(n));
			++n;
		}
		// This numbering is not correct, but it will suffice for cost estimation
		var nstructs = 0;
		for (d in interpreter.userTypeDeclarations) {
			switch (d.type.type) {
			case TStruct(structname, cargs, max): {
				names.structs.set(structname, Struct(nstructs, structname, cargs.length));
				nstructs++;
			}
			default:
			}
		}
	}
	// How much does this AST cost?
	public function cost(e : Flow) : Int {
		try {
			// To find out, we simply compile to bytecode
			var bytecodes = writer.encodeToBuffer(e, debug, names, false);
			// At first, just use the length of the bytecode as the estimate.
			// Later, make a cost model of each opcode separately
			return bytecodes.length;
		} catch (e : Dynamic) {
			trace("Can not estimate the cost of " + Prettyprint.prettyprint(e) + ":\n" + e);
			return 1;
		}
	}
	var writer : BytecodeWriter;
	var names : Names;
	var debug : DebugInfo;
}
