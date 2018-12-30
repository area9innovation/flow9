import FlowArray;

class FlowCgi {
	public function new() {
		
	}
	
	public function handleCgiRequest() {
		name = getParam('name', '');
		var operation = getParam('operation', '');
		if (operation == 'texts') {
			var engine = new ExtractorCgi(name, basepath());
			if (!engine.prepare()) {
				return;
			}
			parse(name, engine, engine.extractTexts);
		} else if (operation == 'settext') {
			var engine = new ExtractorCgi(name, basepath());
			parse(name, engine, engine.settext);
		} else if (operation == 'run') {
			if ("" == name) {
				Sys.println("module name is required");
				return;
			}
			parse(name, this, run);
		} else {
			
		}
	}
	var name : String;

	function parse(name : String, container, fn : Module -> Bool) {
		var nekoPath = basepath();
		container.modules = new Modules([ nekoPath, nekoPath + "/flow/" ], null);
		container.modules.parseFileAndImports(name + ".flow", fn);
	}
	
	// parses a parameter and attempts to guess its type
	// supports nulls, ints, floats, strings
	// non-completely-parsed ints and floats are considered strings
	function parseParameter(arg: String): Flow {
		var pos = null;
		return if (null == arg) {
			Flow.ConstantVoid(pos);
		} else if (arg.indexOf(".") >= 0) {
			var fl = Std.parseFloat(arg);
			null != fl && arg == Std.string(fl) ? Flow.ConstantDouble(fl, pos) : Flow.ConstantString(arg, pos);
		} else {
			var i = Std.parseInt(arg);
			null != i && arg == Std.string(i) ? Flow.ConstantI32((i), pos) : Flow.ConstantString(arg, pos);
		}
	}		

	// extracts value params in v1=1&v2=2 notation
	function getValueParams(): Array<Flow> {
		var params = neko.Web.getParams();
		var regexp = ~/v([0-9]+)/i;
		
		var values: Map<Int,String> = Lambda.fold({ iterator: params.keys }, function (k, h: Map<Int,String>) { 
			if (regexp.match(k)) h.set(Std.parseInt(regexp.matched(1)), params.get(k)); return h;
		}, new Map());

		var max : Int = Lambda.fold({ iterator: function() { return values.keys(); } }, function (k, m) { return k > m ? k : m; }, 0);
		
		var result = [];

		for (i in 0...max) {
			result[i] = parseParameter(values.get(i + 1));
		}

		return result;
	}
	
	function run(module : Module) : Bool {
		// TODO: finish that off
		var result = null;

		// we shall have main - something to run
		var mainCode = module.toplevel.get("main");
		
		var debug = 0;

		var params = FlowArrayUtil.fromArray(getValueParams());

		var interpreter = modules.linkTypecheck(module, debug);

		// interpret flow code - do not attempt to load bytecode from file
		if (null != interpreter) {
			interpreter.evalTopdecs();
			result = interpreter.typeRun(Flow.Call(mainCode, params, null));	
		}

		neko.Lib.print(Prettyprint.prettyprint(result));
		
		return true;
	}
	
	// -------------
	
	public static function getParam(name : String, defaultValue : String) {
		var p = neko.Web.getParams().get(name);
		if (p == null) {
			return defaultValue;
		} else {
			return p;
		}
	}

	function basepath() : String {
		var nekoFile = neko.vm.Module.local().name;
		var path = nekoFile.substr(0, nekoFile.lastIndexOf('/'));
		if (path == "/var/www/html/labsmart-prototype") {
			return "/var/flow/flow";
		}
		return path;
	}
	

	public var modules : Modules;
}
