import JSBinflowBuffer;
import Native;
import HaxeRuntime;

// Compiled by test.js: exposes the deserialiser and the runtime it needs
class BinflowBufferExports {
	static function main() {
		HaxeRuntime._structnames_ = new haxe.ds.IntMap<String>();
		HaxeRuntime._structids_ = new haxe.ds.StringMap<Int>();
		HaxeRuntime._structargs_ = new haxe.ds.IntMap<Array<String>>();
		HaxeRuntime._structargtypes_ = new haxe.ds.IntMap<Array<RuntimeType>>();
		untyped __js__("module.exports = { JSBinflowBuffer: JSBinflowBuffer, Native: Native, HaxeRuntime: HaxeRuntime, RuntimeType: RuntimeType, FlowRefObject: FlowRefObject }");
	}
}
