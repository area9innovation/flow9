import Flow;
import FlowArray;
import sys.FileSystem;

enum Kind { Expr; Type; Name; }

typedef Env = Map<String,String>; 
typedef Change = {st: Int, en : Int, newText : String};

class Refactor extends Rules {

	var module : Module;
	var changes : Array<Change>;

	public static function doRefactorings (options : FlowNeko) : Void {
	  //Options.DEBUG = true; 
	  Assert.trace("Refactor: parse " + options.refactor);
	  if (options.rules == null) {
		Errors.report("Refactor: no rules file specified: use --refactor-rules option");
	  } else if (options.indirect)
		refactorIndrectFiles(options, options.refactor);
	  else if (options.allFiles)
		refactorAllFiles(options, options.refactor);
	  else
		refactorFile(options, options.refactor, options.recursive);
	}

	public static function refactorIndrectFiles (options : FlowNeko, fname : String) : Void {
	  var content = FilesCache.content(fname);
	  var files = content.split("\n");
	  for (file in files) {
		var tfile = StringTools.trim(file);
		if (tfile != "" && tfile.charAt(0) != "#")
		  refactorFile(options, file, false);
	  }
	}

	public static function refactorAllFiles (options : FlowNeko, root : String) : Void {
	  if (!sys.FileSystem.isDirectory(root))
		Errors.report("Refactor: file `" + root + "' is not a directory");
	  else {
		var files = FileSystem.readDirectory(root);
		for (f in files) {
		  var fname = root + "/" + f;
		  if (f == "." || f == "..") 
			{}
		  else 
			  if (StringTools.endsWith(fname, ".flow")) {
				refactorFile(options, fname, false);
			  } else 
				try {
				  if (sys.FileSystem.isDirectory(fname)) {
					refactorAllFiles(options, fname);
				  }
				} catch (e : Dynamic) {
				  Errors.report("Refactor: File `" + fname + "': exception: " + e);
				  Errors.report("Call Stack: " + haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
				}
		}
	  }
		
	}

	public static function refactorFile (options : FlowNeko, fname : String, imports : Bool) : Void {
	  if (!FileSystem.exists (fname))
		Errors.report("Refactor: file `" + fname + "' not found");
	  else {
		Errors.print("Refactor: processing file `" + fname + "'...");
		options.modules.parseFileAndImports(fname, function(m) {
			var ref = new Refactor();
			Assert.check (options.rules != null);
			ref.parseFromFile(options.rules);
			var changes = ref.refactorModule(m);
			var updated = ref.updateText(m.content, changes);
			if (updated == m.content)
			  Errors.print("Refactor: file `" + fname + "': no changes");
			else
			  refactorWriteFile(options, fname, updated);
			return true;
		  });
	  }
	}

	public static function refactorWriteFile(option : FlowNeko, fname : String, newContent : String) {
	  var fn = if (option.refactorSfx == null) fname else fname + option.refactorSfx;
	  try {
		Errors.report("Refactor: writing `" + fn + "'...");
		Util.writeFile(fn, newContent);
	  } catch (e : Dynamic) {
		Errors.report("Refactor: error on writing file `" + fn + "': " + e.toString());
		Errors.report("Call Stack: " + haxe.CallStack.toString (haxe.CallStack.exceptionStack()));
	  }
	}

	public function refactorFlow(node : Flow) {
	  FlowUtil.mapFlow(node, function(flow){ refactorNode(flow); return flow; });
	}

	public function refactorModule(m : Module) {
	  module = m;
	  changes = new Array();
	  for (d in m.toplevel)
		refactorFlow(d);
	  for (t in m.unittests)
		refactorFlow(t);
	  for (td in m.userTypeDeclarations) {
		// todo: process td.name
		refactorType(td.type.type);	  
	  }
	  module = null;
	  changes.sort(function(a,b){ return a.st-b.st;});
	  return changes;
	}

	function refactorType(node : FlowType) {
	  for (rule in typeRules) {
		var env = new Env();
		if (matchType(rule.pattern, node, env)) {
		  //var pos = FlowUtil.getPosition(node);
		  //Assert.check(pos != null);
		  //var range = module.positionToBytes(pos);
		  //Assert.trace("Type: " + pos.f + ":" + range.start + "-" + (range.start + range.bytes));
		  //Assert.trace("Type: Ref: " + Prettyprint.prettyprint(node) + " => " + Prettyprint.prettyprint(rule.subst) + " (pattern=" + Prettyprint.prettyprint(rule.pattern) + ")");
		  //changes.push({st: range.start, en: range.start + range.bytes, newText: Prettyprint.prettyprint(rule.subst)});
		  node = generateType(rule.subst, env);
		}	
	  }
	}

	function refactorNode(node : Flow) {
	  for (rule in flowRules) {
		var env = new Env();
		if (match(rule.pattern, node, env)) {
		  var pos = FlowUtil.getPosition(node);
		  Assert.check(pos != null);
		  var range = module.positionToBytes(pos);
		  /*var flow = generateFlow(rule.subst, env);
		  //Assert.trace(Prettyprint.prettyprint(node));
		  //Assert.trace(Prettyprint.prettyprint(flow));
		  //Assert.trace("" + range);*/
	    
		  var newText = new StringBuf();
		  var pos = 0;
		  //Assert.trace(Prettyprint.prettyprint(node));
		  //Assert.trace(rule.text);
		  for (v in rule.vars) {
			newText.addSub(rule.text, pos, v.pos.st-pos);
			var val = env.get(v.name);
			//Assert.trace("name:" + v.name + " at " + v.pos + " = " + val);
			Assert.check(val != null);
			newText.add(val);
			pos = v.pos.en;
		  }
		  newText.addSub(rule.text, pos);
		  changes.push({st: range.start, en: range.start + range.bytes, newText:newText.toString()});
		}	
	  }
	}

	static function matches<T>(matcher: T -> T -> Env -> Bool, patterns: Array<T>, nodes: Array<T>, env: Env) : Bool {
	  if (patterns.length != nodes.length) 
		return false;
	  for (i in 0...patterns.length) 
		if (!matcher(patterns[i], nodes[i], env))
		  return false;
	  return true;
	}

	static function matchString (a : String, b : String, e : Env) { return a == b; }

	static function matchMonoTypeDeclaration(decl : MonoTypeDeclaration, decl2 : MonoTypeDeclaration, env : Env) {
	  return decl.name == decl2.name && matchType(decl.type, decl2.type, env) && decl.is_mutable == decl2.is_mutable;
	}

	static function matchType(pattern: FlowType, type: FlowType, env: Env) : Bool {
	  return switch (pattern) {
	  case TVoid  : type == TVoid;
	  case TBool  : type == TBool;
	  case TInt   : type == TInt;
	  case TDouble: type == TDouble;
	  case TString: type == TString;
	  case TFlow  : type == TFlow;
	  case TNative: type == TNative;
	  case TReference(etype): 
		switch (type) { case TReference(etype2): matchType(etype, etype2, env); default: false; };

	  case TPointer(etype): 
		switch (type) { case TPointer(etype2): matchType(etype, etype2, env); default: false; };

	  case TArray(etype): 
		switch (type) { case TArray(etype2): matchType(etype, etype2, env); default: false; };

	  case TFunction(args, returns): 
		switch (type) { case TFunction(args2, returns2): matchType(returns, returns2, env) && matches(matchType, args, args2, env); default: false; };

	  case TStruct(name, args, max): 
		switch (type) { case TStruct(name2, args2, max2): name == name2 && matches(matchMonoTypeDeclaration, args, args2, env); default: false; };

	  case TUnion(min, max):
		Assert.check(min == max, "Refactor: TUnion: min == max");
		switch (type) { 
		case TUnion(min2, max2): 
		  Assert.check(min2 == max2, "Refactor: TUnion: min2 == max2");
		  var keys  = new Array(); 
		  for (key in min.keys ()) keys.push(key);
		  keys.sort(Util.compareStrings);
		  var keys2 = new Array(); 
		  for (key in min2.keys ()) keys2.push(key);
		  keys.sort(Util.compareStrings);
		  if (!matches(matchString, keys, keys2, env))
			return false;
		  for (key in keys) 
			if (!matchType(min.get(key), min2.get(key), env))
			  return false;
		  true;
			
		default: false; 
		};


	  case TTyvar(vtype): // todo: vtype's == null's after parsing, may be this can cuse problems
		switch (type) { case TTyvar(vtype2): true; default: false; };

	  case TName(name, args):
		switch (type) { case TName(name2, args2): name == name2 && matches(matchType, args, args2, env); default: false; };

	  case TBoundTyvar(id):
		switch (type) { case TBoundTyvar(id2): id == id2; default: false; };
	  }
	}

	function match(pattern: Flow, node: Flow, env: Env) : Bool {
	  return switch(pattern) {
	  case SyntaxError(error, pos): false;
	  case ConstantVoid(pos): 
		switch (node) { case ConstantVoid(_): true; default: false; };

	  case ConstantBool(value, pos): 
		switch (node) { case ConstantBool(value2, pos2): value == value2; default: false; };

	  case ConstantI32(value, pos): 
		switch (node) { case ConstantI32(value2, pos2): value == value2; default: false; };

	  case ConstantDouble(value, pos): 
		switch (node) { case ConstantDouble(value2, pos2): value == value2; default: false; };

	  case ConstantString(value, pos): 
		switch (node) { case ConstantString(value2, pos2): value == value2; default: false; };

	  case ConstantArray(values, pos): 
		switch (node) { case ConstantArray(values2, pos2): matches(match, values, values2, env); default: false; };

	  case ConstantNative(value, pos): 
		switch (node) { case ConstantNative(value2, pos2): value == value2; default: false; };

	  case ConstantStruct(name, fields, pos): 
		switch (node) { case ConstantStruct(name2, fields2, pos2): name == name2 && matches(match, fields, fields2, env); default: false; };

	  case VarRef(name, pos): 
		if (RulesProto.isExprVar(name)) { 
		  env.set(name, getNodeText(node)); 
		  true;
		} else {
		  switch (node) { 
		  case VarRef(name2, pos2): name == name2; 
		  default: false; 
		  };
		}

	  case Field(call, name, pos): 
		switch (node) { case Field(call2, name2, pos2): name == name2 && match(call, call2, env); default: false; };

	  case RefTo(value, pos): 
		switch (node) { case RefTo(value2, pos2): match(value, value2, env); default: false; };

	  case Pointer(loc, pos): 
		switch (node) { case Pointer(loc2, pos2): loc == loc2; default: false; };

	  case Deref(value, pos): 
		switch (node) { case Deref(value2, pos2): match(value, value2, env); default: false; };

	  case SetRef(pointer, value, pos): 
		switch (node) { case SetRef(pointer2, value2, pos2): match(pointer, pointer2, env) && match(value, value2, env); default: false; };

	  case SetMutable(pointer, field, value, pos):
		switch (node) { case SetMutable(pointer2, field2, value2, pos2): match(pointer, pointer2, env) && match(value, value2, env) && field == field2; default: false; };

	  case Cast(value, type, toType, pos): 
		switch (node) { case Cast(value2, type2, toType2, pos2): match(value, value2, env) && matchType(type, type2, env) && matchType(toType, toType2, env); default: false; };

	  case Let(name, sigma, value, scope, pos): 
		switch (node) { 
		case Let(name2, sigma2, value2, scope2, pos2): 
		  name == name2 &&
			matchType(sigma.type, sigma2.type, env) && 
			match(value, value2, env); 
		default: false; 
		};

	  case Closure(value, env, pos): Assert.fail("Refactor: Closure - invalid node type"); false;

	  case Lambda(arguments, type, body, uniqNo, pos): 
		switch (node) { 
		case Lambda(arguments2, type2, body2, uniqNo2, pos2): 
		  matches(matchString, FlowArrayUtil.toArray (arguments), FlowArrayUtil.toArray (arguments2), env) &&
			matchType (type, type2, env) && 
			match(body, body2, env) &&
			uniqNo == uniqNo2; 

		default: false; };

	  case Call(closure, arguments, pos): 
		switch (node) { case Call(closure2, arguments2, pos2): match (closure, closure2, env) && matches(match, arguments, arguments2, env); default: false; };

	  case Sequence(statements, pos): 
		switch (node) { case Sequence(statements2, pos2): matches(match, statements, statements2, env); default: false; };

	  case If(cond, th, el, pos): 
		switch (node) { case If(cond2, th2, el2, pos2): match(cond, cond2, env) && match(th, th2, env) && match(el, el2, env); default: false; };

	  case Not(value, pos): 
		switch (node) { case Not(value2, pos2): match(value, value2, env); default: false; };

	  case Negate(value, pos): 
		switch (node) { case Negate(value2, pos2): match(value, value2, env); default: false; };

	  case Multiply(a, b, pos): 
		switch (node) { case Multiply(a2, b2, pos2): match(a, a2, env) && match(b, b2, env); default: false; };

	  case Divide(a, b, pos): 
		switch (node) { case Divide(a2, b2, pos2): match(a, a2, env) && match(b, b2, env); default: false; };

	  case Modulo(a, b, pos): 
		switch (node) { case Modulo(a2, b2, pos2): match(a, a2, env) && match(b, b2, env); default: false; };

	  case Plus(a, b, pos): 
		switch (node) { case Plus(a2, b2, pos2): match(a, a2, env) && match(b, b2, env); default: false; };

	  case Minus(a, b, pos): 
		switch (node) { case Minus(a2, b2, pos2): match(a, a2, env) && match(b, b2, env); default: false; };

	  case Equal(a, b, pos): 
		switch (node) { case Equal(a2, b2, pos2): match(a, a2, env) && match(b, b2, env); default: false; };

	  case NotEqual(a, b, pos): 
		switch (node) { case NotEqual(a2, b2, pos2): match(a, a2, env) && match(b, b2, env); default: false; };

	  case LessThan(a, b, pos): 
		switch (node) { case LessThan(a2, b2, pos2): match(a, a2, env) && match(b, b2, env); default: false; };

	  case LessEqual(a, b, pos): 
		switch (node) { case LessEqual(a2, b2, pos2): match(a, a2, env) && match(b, b2, env); default: false; };

	  case GreaterThan(a, b, pos): 
		switch (node) { case GreaterThan(a2, b2, pos2): match(a, a2, env) && match(b, b2, env); default: false; };

	  case GreaterEqual(a, b, pos): 
		switch (node) { case GreaterEqual(a2, b2, pos2): match(a, a2, env) && match(b, b2, env); default: false; };

	  case And(a, b, pos): 
		switch (node) { case And(a2, b2, pos2): match(a, a2, env) && match(b, b2, env); default: false; };

	  case Or(a, b, pos): 
		switch (node) { case Or(a2, b2, pos2): match(a, a2, env) && match(b, b2, env); default: false; };
	 
	  case Switch(value, type, cases, pos): 
		switch (node) { 
		case Switch(value2, type2, cases2, pos2): 
		  match(value, value2, env) &&
			matches(function(c : SwitchCase, c2 : SwitchCase, env : Env) { 
				return 
				  c.structname == c2.structname && 
				  matches(function(arg, arg2, env) { return arg == arg2; }, c.args, c2.args, env) &&
				  match(c.body, c2.body, env);
			  }, cases, cases2, env) &&
			matchType(type, type2, env); 
		default: false; 
		};

	  case SimpleSwitch(value, cases, pos): 
		switch (node) { 
		case SimpleSwitch(value2, cases2, pos2): 
		  match(value, value2, env) &&
			matches(function(c : SimpleCase, c2 : SimpleCase, env : Env) { 
				return c.structname == c2.structname && match(c.body, c2.body, env);
			  }, cases, cases2, env);
		default: false; 
		};

	  case ArrayGet(a, i, pos): 
		switch (node) { case ArrayGet(a2, i2, pos2): match(a, a2, env) && match(i, i2, env); default: false; };
	 
	  case Native(name, io, args, result, defbody, pos): 
		switch (node) { 
		case Native(name2, io2, args2, result2, defbody2, pos2): 
		  name == name2 && io == io2 && matches(matchType, args, args2, env) && matchType(result, result2, env) && defbody == null && defbody2 == null; 
		default: false; 
		};

	  case NativeClosure(_, _, _): Assert.fail("Refactor:NativeClosure invalid node"); false;
	  case StackSlot(_, _, _): Assert.fail("Refactor:Stackslot invalid node"); false;
	  }
	  return false;
	}

	function generateFlow(subst: Flow, env: Env): Void {
	  FlowUtil.traverseExp(subst, function(subst) {
		  switch(subst) {
		  case VarRef(name, pos): 
			if (RulesProto.isVar(name)) { 
			  var flow = env.get(name);
			  if (flow != null) {
				//Assert.trace("Subst: " + Prettyprint.prettyprint(subst) + " => " + flow);
				return;
			  }
			  else
				Errors.report("Subst: " + Prettyprint.prettyprint(subst) + " - unknown var `" + name + "'");
			}
		  default: {}
		  }
		  return;
		});
	}

	function generateType(subst: FlowType, env: Env): FlowType {
	  return subst;
	}

	public function updateText(content: String, changes: Array<Change>): String {
	  var p = 0;
	  var res = new StringBuf();
	  for (c in changes) {
		res.addSub(content, p, c.st - p);
		res.add(c.newText);
		p = c.en;
	  }
	  res.addSub(content, p);
	  return res.toString();
	}

	public function getNodeText(node: Flow) {
	  var coor = module.positionToBytes(FlowUtil.getPosition(node));
	  return module.content.substr(coor.start, coor.bytes);
	}
  }
