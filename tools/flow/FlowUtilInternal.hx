// These are helpers which should NOT be used from native helpers, because we can not rely on deconstructing these structures
class FlowUtilInternal {
	static public function getConstructor(code : Flow) : { name: String, args : FlowArray<Flow>} {
		switch (code) {
		case ConstantStruct(name, args, pos):
			return { name: name, args: args };
		case VarRef(a, pos):
			return { name : a, args: new FlowArray()};
		default: throw "Expected a struct, not: " + Prettyprint.print(code);
		}
	}
	
	static public function getAddress(pointer : Flow) : Int {
		switch (pointer) {
		case Pointer(index, pos):
			return index;
		default: throw "Expected a pointer. Got " + Prettyprint.print(pointer);
		}
	}
}
