import Flow;
import FlowUtil;
import OrderedHash;
import TypeEnvironment;

#if jsruntime
#error "Attempt to link Flow compiler code into JS runtime"
#end

class FlowInterpreter implements Interpreter {
	public function new(?allTypes : Bool = false) {
		order = new FlowArray();
		topdecs = new Map();
		hidden = new Map();
		environment = new Environment();
		typeEnvironment = new TypeEnvironment();
		userTypeDeclarations = new OrderedHash();
		memory = new Memory();
		debug = 0;
		callstack = new FlowArray();
		nativeRoots = new Map<Int, Flow>();
		nNativeRoots = 0;
		instantiations = new Map();
		arithOps = new FlowArray();
		arithStringOps = new FlowArray();
		allNodeTypes = allTypes;
	}

	public function serialize() : String {
		return
			environment.serialize('') + '\n'
			+ 'Memory:\n' + memory.serialize() + '\n';
	}

	function getCell(pointer : Flow) : Flow {
		return memory.cells[FlowUtilInternal.getAddress(pointer)];
	}
	
	public function gc() : Void {
	}
	public function registerRoot(c : Flow) : Int {
		var n = nNativeRoots;
		nativeRoots.set(n, c);
		nNativeRoots++;
		return n;
	}
	public function lookupRoot(i : Int) : Flow {
		return nativeRoots.get(i);
	}
	
	public function releaseRoot(i : Int) : Void {
		nativeRoots.remove(i);
	}
	var nativeRoots : Map<Int, Flow>;
	var nNativeRoots : Int;
	
	public function toString(value : Flow) : String {
		// This is wrong for values with references
		var replaced = replacePointersWithReferences(value);
		return Prettyprint.prettyprint(replaced, '');
	}
	
	public function typecheckTopdecs<T>(
		debug : Int,
		?cont : Void -> T = null,
		?bind : (Void -> T) -> String -> T = null
	) : T {
		if (cont == null) cont = function(){ return null; };
		if (bind == null) bind = Modules.defaultBind;
		try {
			// Check all type declarations for unknown user types
			for (t in userTypeDeclarations.keys()) {
				var declaration = userTypeDeclarations.get(t);
				var unknown = checkForUnknownUserTypes(declaration.type.type);
				if (unknown != null) {
					reportp("Unknown type " + unknown + " in declaration of " + declaration.name, declaration.position);
					return bind(cont, "ret");
				}
			}
			typeEnvironment.resolveStructs(debug);
			return typecheckTopdecsCont(0, debug, function() {
				reportUntypedArithOps();
				return bind(cont, "ret");
			}, bind);
		/*} catch (e : Dynamic) {
			Errors.report('Exception from typecheckTopdecs: ' + e);
			trace(Assert.callStackToString(haxe.Stack.exceptionStack()));
			printCallstack();*/
		}
	}

	public function typecheckTopdecsCont<T>(
		start : Int,
		debug : Int,
		cont : Void -> T,
		bind : (Void -> T) -> String -> T
	) : T {
		#if flash
		var t = haxe.Timer.stamp();
		#end

		for (di in start ... order.length) {
			var d = order[di];
			#if flash
			if (haxe.Timer.stamp() - t > 10) {
				return bind(function() {
					return typecheckTopdecsCont(di, debug, cont, bind);
				}, "10\" passed, typecheck continuing");
			}
			#end
			var n = Errors.getCount();
			var topdec = topdecs.get(d);
			var envtype = typeEnvironment.lookup(d);
			if (topdec == null) { // symbol loaded from precompiled module
				Assert.check(typeEnvironment.lookup(d) != null, "type lookup");
			} else {
				var declared = userTypeDeclarations.get(d);
				var propagateType = if (declared != null) instantiate1(d, declared.type) 
									   else if (envtype != null) instantiate1(d, envtype) 
									   else null;
				var inferred = 
					if (declared == null) getType(topdec, propagateType) 
					else typeTopDecl(d, topdec, propagateType, declared);
				if (declared == null) {
					typeEnvironment.define(d, mono(inferred)); // todo: allow inferring a polymorphic type for a function 
					// Then type-check again to catch errors in recursive inferred types
					// Test-case:
					//    t(a,b) { t(a); }
					//    main() { t(1, 2); }
					if (Errors.getCount() <= n) {
						// only re-typecheck if there were no errors last, so as to avoid displaying the same errors twice
						getType(topdec);
					}
					if (debug > 1) trace('topdec ' + d + ' : type undeclared ; inferred:  ' + pt(inferred));
				} else {
					/*
					  report('declared type for  ' + d + ' : ' + pts(declared.type), ConstantVoid(declared.position));
					  report('inferred type           ' + pt(inferred), topdec);
					  report(' type environment       ' + pts(typeEnvironment.lookup(d)), topdec);
					*/
					/*Properly check that a function really has the type declared.  This was
					  wrong for "forall" types: it is wrong to check the inferred type is a
					  subtype of an instance of the typescheme.  Example : Consider this
					  declared typescheme

					  decl= (?,??)->void;

					  It says the 2 input types can be different.    Assume the inferred
					  type is :

					  inf= (t,t)->void;        where t is a type variable.

					  An instance of the declared typescheme decl is : 

					  inst= (t1,t2)->void

					  where t1 & t2 are fresh type variables.  Checking whether inf is a
					  subtype of inst, tells us that it is:

					  subtype(inf, inst) ==>  subtype((t,t) , (t1,t2))  <==>  subtype(t, t1) && subtype(t, t2)
					  ==> t:=t1 && t:=t2 ==> t1:=t2.

					  but will unify t1 & t2.  So, not good.  The correct way to check that
					  the inferred type "matches" the declared type is to extend subtype()
					  to work for bound tyvars, i.e., ? & ??, & then only allow ? to have
					  itself as a subtype, i.e., it would then be:

					  subtype(inf, inst) ==>  subtype((t,t) , (?,??))  <==>  subtype(t, ?) && subtype(t, ??)
					  ==> t:=? && t:=?? ==> ?:=?? 

					  which will fail! giving the type error that we want.*/
					if (! typeEnvironment.subtype(inferred, declared.type.type)) {
						// (see comment at the other place where declaredError is called)
						declaredError(d, declared.type, declared.position, inferred, topdec);
					}
					if (debug > 1) trace('topdec ' + d + ' : ' + pts(declared.type) + ' ; inferred:  ' + pt(inferred)) ;
				}
				// Save the inferred type. This overwrites type, so use type2 where appropriate.
				var pos = FlowUtil.getPosition(topdec);
				pos.type = inferred;
			}
		}
		return bind(cont, "typecheck finished");
	}

	private function typeTopDecl(d : String, topdec : Flow, propagateType : FlowType, declared : TypeDeclaration) {
		return switch (topdec) {
			// type toplevel lambdas specially: give them an expected type in
			// order to provoke type errors earlier by propagating the
			// user-declared type more eagerly.  typeLambda() is the code
			// common to typing Lambdas toplevel & non-toplevel.
			case Lambda(arguments, type, body, _, pos):
				if (type != null) {
					if (differentFunctionTypes(type, declared.type.type)) {
						reportp(d + ' has 2 different types declared: ' + pt(declared.type.type),
						declared.position);
						reportp(FlowUtil.repeat(d.length + 26, ' ') + ' and: ' + pt(type), pos);
					}
				}
				typeLambda(d, arguments, body, pos, propagateType);
			case Native(name, io, args, result, defbody, pos):
				if (defbody != null) typeTopDecl(d, defbody, propagateType, declared)
				else getType(topdec, propagateType);
			default: getType(topdec, propagateType);
		}
	}

	// null if there were errors
	public function typecheck(code : Flow) : FlowType {
		try {
			Errors.resetCount();
			var t = typecheck0(code);
			return if (Errors.getCount() == 0) t else null;
		} catch (e : String) {
			Errors.report("Exception during typing: " + e);
			printCallstack();
			return null;
		}
	}
	
	private function typecheck0(code : Flow) : FlowType {
		// Typecheck the bunch
		var t = getType(code);

		return t;
	}

	function getType(value : Flow, context : FlowType = null) : FlowType {
		if (debug > 1) depth++;
		// var n = "getType " + Prettyprint.flowASTKind(value);
		// Profiler.get().profileStart(n);
		var t;
		try {
			t = getType0(value, context);
		} catch (e : Dynamic) {
			report('Exception in type checker: '+e, value);
			t = TFlow;
		}
		if (debug > 1) {
			depth--;
			var s = pp(value);
			if (s != 'debugtyping') {
				trace(indent() + s + ' : ' + pt(t));
			}
		}
		// Profiler.get().profileEnd(n);
		return t;
	}

	public static function indent() : String {
		return FlowUtil.repeat(depth * 2, '  ');
	}
	
	public static var depth = 0;


	function getType0(value : Flow, context : FlowType) : FlowType {

		//trace('typechecking ' + pp(value) + ', expecting: ' + pt(context));
	  var retType = function(type) { 
        /*if (!(FlowUtil.getPosition(value).type == null || FlowUtil.getPosition(value).type == type)) {
		  Assert.DEBUG = true;
		  Assert.trace("value=" + Prettyprint.prettyprint(value));
		  Assert.trace("value.type=" + Prettyprint.prettyprintType(FlowUtil.getPosition(value).type));
		  Assert.trace("      type=" + Prettyprint.prettyprintType(type));
		}
		Assert.check(FlowUtil.getPosition(value).type == null || FlowUtil.getPosition(value).type == type, "type == null"); */
		if (allNodeTypes) {
			var pos = FlowUtil.getPosition(value);
			if (pos.type == null)
				pos.type = type;
		}
		return type;
	  }
		switch (value) {
		case SyntaxError(e, pos) : report(e, value); return newTyvar();
		case ConstantVoid(pos): return TVoid;
		case ConstantString(value, pos): return retType(TString);
		case ConstantDouble(value, pos): return retType(TDouble);
		case ConstantBool(value, pos): return retType(TBool);
		case ConstantI32(value, pos): return retType(TInt);
		case ConstantArray(values, pos): {
			// Make sure all the types are compatible
			var expected : FlowType = if (context == null) null
									  else switch (context) {
												case TArray(t1): t1;
												default:
													//trace('typechecking array with expected: ' + context + '  [' + values + ']');
													null;
									  };
			//trace('typechecking array ' + pp(value) + ' with expected element type: ' + expected);
			var lastType = null;
			for (v in values) {
				var t = getType(v, expected);
				if (lastType == null) {
					lastType = t;
				} else {
					var join = typeEnvironment.lub(t, lastType);
					if (join == null) {
						// though the element types were not direcly compatible they are
						// still ok if they are all subtypes of the expected type: a :
						// [flow] = [1, true]; 1 & true are not compatible, but both are
						// subtypes of flow, so it is ok, and b = [1, true] is NOT ok.
						if (expected == null) {
							report('Types in an array must be the same, or declare them to be flow: '
								   + pt(lastType) + ' is incompatible with ' + pt(t) + why(), v);
						} else if (typeEnvironment.subtype(t, expected)) {
							join = expected;
						} else {
							report('Expected array elements of type: ' + pt(expected) + ', not ' + pt(t) + why(), v);
						}
					}
					lastType = join;
				}
			}
			if (lastType == null) lastType = newTyvar();
			var t = TArray(lastType);
			pos.type = t;
			return t;
		}
		case ConstantStruct(name, values, pos):
			report('impossible: getType(ConstantStruct)', value);
			// Applied structs are dealt with as Call(VarRef(), ...).  ConstantStruct is
			// the runtime representation of that.  So this case can only happen at
			// runtime & getType() is not used at runtime.
			return TFlow;
		case ConstantNative(val, pos):
			return TNative;
		case ArrayGet(a, i, pos):
			var indexType = getType(i, TInt);
			if (! typeEnvironment.subtype(indexType, TInt)) {
				report('Use int as array index, not ' + pt(indexType), i);
			}
			var result = newTyvar();
			var elementtype = if (context != null) context else newTyvar();
			var expected = TArray(elementtype);
			var arrayType = getType(a, expected);
			if (! typeEnvironment.subtype(arrayType, expected) ) {
				report("Expected " + pt(expected) + " but got " + pt(arrayType), a);
			}
			if (! typeEnvironment.subtype(elementtype, result)) {
				report("Context expects " + pt(elementtype) + " but got " + pt(result), a);
			}
			return retType(result);
		case VarRef(name, pos): return retType(getTypeVarRef(name, value, context, false));
		case Field(call, name, pos):
			if (debug > 1) trace(indent() + ' --- ' + pp(value) + ' --- ');

			var t = normalise(getType(call), call);
			var expected = TTyvar(FlowUtil.mkTyvar(TypeEnvironment.newUnion()));
			if (! typeEnvironment.subtype(t, expected)) {
				report('Use . on structs only, not on ' + pt(t), value);
				return newTyvar();
			}

			FlowUtil.getPosition(call).type = t;

			// subtype(t, expected) will give either an error, or, if t is a union,
			// propagate that to expected, or, if t is flow, leave expected untouched, or,
			// if t is uninstantiated (e.g., \ x -> x.field), t := an empty union.
			if (name == 'structname') return TString;
			var field = typeEnvironment.lookupField(name);
			if (field == null) {
				report('No struct has a .' + name + ' field', value);
				return newTyvar();
			}
			
			// check that t is a subtype of field.fromType, i.e., compatible with one or
			// more of the struct types that this field supports
			//report('.' + name + ' works on  : ' + pt(field.fromType), call);
			//report('here it is applied on a : ' + pt(t), call);
			var from = swap(instantiate1('field ' + name + ' input type', field.fromType));
			/*old:
			var u = typeEnvironment.typeMatch(FlowUtil.maxout(t), from);
			if (u == null || FlowUtil.isEmptyUnion(u)) {
				var tu = TypeEnvironment.untyvar(t);
				report(if (tu == null) 'Field .' + name + ' missing'
					   else switch (tu) {
					   case TUnion(n, ns, max):
						'Some or all of ' + (t) + ' have no .' + name + ' field';
						case TStruct(n, args, max): 'Struct ' + pt(t) + ' does not have a .' + name + ' field';
						default: 'Only use .' + name + ' on structs, not on ' + pt(t);
						}, call);
				return newTyvar();
			}
			*/
			if (debug > 1) trace(indent() + '    inferred from type before < : ' + pt(t));
			if (! typeEnvironment.subtype(t, from)) {
				report(ppMaybe(value, ': ') + 'Some or all of ' + pt(t)
					   + ' have no .' + name + ' field.', value); // todo: to add position, see how report() does it.
				return newTyvar();
			}

			if (debug > 1) trace(indent() + '    from type after < applied   : ' + pt(t));
			// todo: if min is not trivial, cut down max to be := min to avoid the
			// spurious introduction of a gazillion unrelated types that are just included
			// because they happen to have a field of this name.  Or maybe reduce max to
			// be structs that are comrades of structs in min.

			if (debug > 1) trace(indent() + '    fieldType:');
			var w = if (! FlowUtil.isFlow(t)) t else if (! FlowUtil.isFlow(from)) from else TFlow;
			if (debug > 1) trace(indent() + '        .' + name + ' domain type=' + pt(w));
			var tfield = fieldType(value, w, context, name);
			if (debug > 1) trace(indent() + '                & output type === ' + pt(tfield));
			pos.type = tfield;
			return tfield;
		case SetMutable(call, name, value, pos):
			if (debug > 1) trace(indent() + ' --- ' + pp(value) + ' --- ');

			var t = normalise(getType(call), call);
			var valType = getType(value);

			var expected = TTyvar(FlowUtil.mkTyvar(TypeEnvironment.newUnion()));
			if (! typeEnvironment.subtype(t, expected)) {
				report('Use ::= on structs only, not on ' + pt(t), value);
				return TVoid;
			}

			FlowUtil.getPosition(call).type = t;

			// subtype(t, expected) will give either an error, or, if t is a union,
			// propagate that to expected, or, if t is flow, leave expected untouched, or,
			// if t is uninstantiated (e.g., \ x -> x.field), t := an empty union.
			var field = typeEnvironment.lookupField(name);
			if (field == null || field.fromTypeMut == null) {
				report('No struct has a mutable .' + name + ' field', value);
				return TVoid;
			}

			// check that t is a subtype of field.fromType, i.e., compatible with one or
			// more of the struct types that this field supports
			//report('.' + name + ' works on  : ' + pt(field.fromType), call);
			//report('here it is applied on a : ' + pt(t), call);
			var from = swap(instantiate1('field ' + name + ' input type', field.fromTypeMut));

			if (debug > 1) trace(indent() + '    inferred from type before < : ' + pt(t));
			if (! typeEnvironment.subtype(t, from)) {
				report(ppMaybe(value, ': ') + 'Some or all of ' + pt(t)
					   + ' have no mutable .' + name + ' field.', value); // todo: to add position, see how report() does it.
				return TVoid;
			}

			if (debug > 1) trace(indent() + '    from type after < applied   : ' + pt(t));
			if (debug > 1) trace(indent() + '    fieldType:');
			var w = if (! FlowUtil.isFlow(t)) t else if (! FlowUtil.isFlow(from)) from else TFlow;
			if (debug > 1) trace(indent() + '        .' + name + ' domain type=' + pt(w));
			var tfield = fieldType(value, w, valType, name);
			if (debug > 1) trace(indent() + '                & output type === ' + pt(tfield));
			pos.type = tfield;

			if (! typeEnvironment.subtype(valType, tfield)) {
				report(ppMaybe(call, ': ') + 'You cannot assign ' + pt(valType) + ' to a mutable field .'+name+' that takes ' + pt(tfield) + why(), call);
			}
			return TVoid;
		case RefTo(value, pos):
			var alpha = newTyvar();
			// allow a subtype step here, so the ref is not constrained to contain only
			// its init value: you want to allow r = ref None; r := Some(1);
			typeEnvironment.subtype(getType(value), alpha);
			return TReference(alpha);
		case Pointer(address, pos):
		 	return TPointer(getType(getCell(value)));
		case Deref(pointer, pos):
			var ptrType = getType(pointer);
			var result = newTyvar();
			if (! typeEnvironment.subtype(ptrType, TReference(result))) {
				report('^ wants a ref, not ' + pt(ptrType), pointer);
			}
			if (FlowUtil.isFlow(ptrType)) {
				report(ppMaybe(pointer, ': ') + 'You cannot deref a flow type. Cast it to a ref first', pointer);
			}
			return retType(result);
		case SetRef(pointer, value, pos):
			var ptrType = getType(pointer);
			var valType = getType(value);
			var alpha = newTyvar();
			if (! typeEnvironment.subtype(ptrType, TReference(alpha))) {
				// Happens in this situation: a = false; a := true;
				report(ppMaybe(pointer, ': ') + pt(ptrType)
					   + ' is not a ref so it cannot be assigned'
					   + why() + '. Declare X = ref Y rather than X = Y', pointer);
			}
			if (! typeEnvironment.subtype(valType, alpha)) {
				report(ppMaybe(pointer, ': ') + 'You cannot assign ' + pt(valType) + ' to a ref that takes ' + pt(alpha) + why(), pointer);
			}
			if (FlowUtil.isFlow(ptrType)) {
				report(ppMaybe(pointer, ': ') + 'You cannot assign ' + pt(valType) + ' to a flow type. Cast it to a ref first', pointer);
			}
			return TVoid;
		case Cast(value, fromtype, totype, pos):
			var t = getType(value);
			if (! typeEnvironment.subtype(t, fromtype)) {
				report(ppMaybe(value, '') + ' is ' + pt(t) + ', not ' + pt(fromtype) + why(), ConstantVoid(pos));
			}
			return totype;
		case Let(name, sigma, value, scope, pos):
			var declared = if (sigma == null) null else FlowUtil.instantiate1(sigma);
			var t1 = getType(value, declared);
			if (t1 == TVoid) {
				report('Can not use {} as value here. (a=b=1 should be a=1; b=1;)', value);
			}
			var previous = shadowCheck('', name, value);
			if (sigma != null) {
				if (! typeEnvironment.subtype(t1, declared)) {
					declaredError(name, sigma, pos, t1, value);
				}
				t1 = declared;
			}
			pos.type2 = t1;
			if (scope == null) {
				return TVoid;
			}

			var prev = typeEnvironment.pushdef(name, mono(t1));
			// Re mono: later we might allow inferring a polymorphic type for a let bound
			// variable (if it sticks to the "value restriction")
			var t2 = getType(scope, context);

			typeEnvironment.popdef(prev);
			return t2;
		case Lambda(arguments, type, body, _, pos):
			var n1 = FlowUtil.typeDepth(type);
			var n2 = FlowUtil.typeDepth(context);
			if (debug > 1) trace('Lambda type before: ' + pt(type) + ' =' + n1 + '  context=' + pt(context) + ' =' + n2);
			//var expected = if (type == null) context else if (context == null) type else typeEnvironment.typeMatch(type, context);
			// let the annotated type dominate rather than the type expected by the
			// context, if the annotated type is there
			var expected = if (n1 > 1 || n1 >= n2) type else context;
			//if (debug > 1) trace('Lambda expected ' + pt(expected) + '  type=' + pt(type));
			return typeLambda('', arguments, body, pos, expected);

		case Closure(body, environment, pos):
			// TODO: getType(body);
			// TODO: enable type checking of toplevel closures (which are not lambdas because of the eval of topdecs in Module.
			return TFlow;		// Not accurate, but if we are to check runtime values, we need to store type info at runtime too
		case Sequence(statements, pos):
			var t = TVoid;
			var l = statements.length;
			var i = 0;
			for (s in statements) {
				++i;
				if (i == cast(l)) {
					t = getType(s, context);
				} else {	
					t = getType(s);
				}
			}
			return t;
		/* alternative that demands statements have void type
			var t = TVoid;
			var disaster = false;
			var disasterType = null;
			var disasterExp = null;
			for (s in statements) {
				if (disaster) {
					report("Only void type allowed in sequence, not " + pt(disasterType), disasterExp);
				}
				t = getType(s);
				if (typeEnvironment.typeMatch(t, TVoid) == null) {
					disaster= true;
					disasterType = t;
					disasterExp = s;
				} else {
					disaster = false;
				}
			}
			return t;
		*/
		case Call(clos, arguments, pos):
			var closType = switch (clos) {
								case VarRef(x, pos): pos.type=getTypeVarRef(x, clos, context, true);
								default: getType(clos);
							};
			var al : Int = arguments.length;
			var checkArgs = function (formals : FlowArray<FlowType>, result : FlowType) : FlowType {
				if (debug > 1) trace(indent() + '[checkArgs ' + ppMaybe(clos) + ' : '
									 + pt(TFunction(formals, result)));
				var fl : Int = formals.length;
				if (al != fl) {
					report('Give ' + fl + ' arguments, not ' + al + ' to ' + pp(clos) + ' : ' + pt(closType), value);
				} else {
					var actuals = [];
					for (i in 0...al) {
						var formal = formals[i];
						var actual = getType(arguments[i], formal);
						if (debug > 1) trace(indent() + th(i + 1) + ' argument actual: ' + pt(actual) + '\t formal: ' + pt(formal));
						if (! typeEnvironment.subtype(actual, formal)) {
							report(ppMaybe(clos) + 'expected ' + pt(formal) + ', not ' + pt(actual)
								   + if (al <= 1) why() else ', as ' + th(i + 1) + ' argument' + why(),
								   arguments[i]);
						}
					}
				}
				if (debug > 1) trace(indent() + 'checkArgs done: ' + pt(TFunction(formals, result)) + ']');
				return retType(result);
			}

			var uclosType = TypeEnvironment.untyvar(closType);
			if (uclosType != null) {
			switch (uclosType) {
				case TStruct(n, tds, max):
					// This is the bottleneck with 14% of the time
					// Profiler.get().profileStart("getType Struct");
					var fl : Int = tds.length;
					if (al != fl) {
						report('Give ' + fl + ' arguments, not ' + al + ' to struct ' + pt(closType), value);
						return retType(closType);
					} else {
						var resultArgs = new FlowArray();
						for (i in 0...al) {
							var td = tds[i];
							var formal = td.type;
							//trace('check arg to struct: ' + pp(arguments[i]) + ' formal: ' + pt(formal));
							var actual = getType(arguments[i], formal);
							// no newTyvar indirection: subtype(actual, alpha); subtype(alpha, formal);
							if (! (typeEnvironment.subtype(actual, formal))) {
								report('Give ' + pt(formal) + ', not ' + pt(actual)
									   + (if (al <= 1) '' else ' as .' + tds[i].name)
									   + ' to struct ' + pt(closType) + why(),
									   arguments[i]);
							}
							resultArgs.push({name: td.name, type: /*with newTyvar it would be alpha here*/
												   formal, position: td.position, is_mutable: td.is_mutable});
						}
						// Return the struct type resulting from the intersecting of the types rather
						// than just the original inferred for the clos expression.  This makes a
						// difference for instance for S : (b :  Behaviour); where otherwise the type
						// of b would not be propagated.  I am, however, not even sure we even want to
						// allow Behaviour without <>... as the semantics of a TName without its
						// arguments is anyway unclear to everyone.  If it does mean <?>, then it would
						// be better to demand that the user writes that explicitly.
						// Profiler.get().profileEnd("getType Struct");
						return TStruct(n, resultArgs, true);
					}
					// Hm notice TStruct(n, tds) doubles both as the type of the struct n
					// itself & as the type of the applied struct.  Pretty god damn Messy.
				case TFunction(formals, result):
				    return retType(checkArgs(formals, result));
				default:
			}
			}
			// Closure type is blank tyvar, so create a TFunction skeleton type
			var result = newTyvar();
			var expected = TFunction(FlowUtil.map(arguments, typecheck0), result);
			//Assert.check(closType != null, "closType != null");
			//Assert.check(expected != null, "expected != null");
			if (! typeEnvironment.subtype(closType, expected)) {
				report(ppMaybe(clos, ': ') + pt(closType) + ' should be a function' + why(), value);
				return retType(newTyvar());
			} else {
			    return retType(result);
			}
		case If(condition, then, elseExp, pos):
			var t0 = getType(condition);
			if (t0 == null || ! typeEnvironment.subtype(t0, TBool)) {
				report('if takes bool condition, not ' + pt(t0), condition);
			}
			var t1 = getType(then, context);
			var t2 = getType(elseExp, context);
			var union = typeEnvironment.lub(t1, t2);
			if (union == null) {
				report("if has type " + pt(t1) + " in then-branch but " + pt(t2) + " in the else-branch", value);
				return newTyvar();
			}
			pos.type = union;
			return union;
		case Not(e, pos):
			var t = getType(e);
			if (! typeEnvironment.subtype(t, TBool)) {
				report("! wants bool, not " + pt(t), e);
			}
			return TBool;
		case Negate(e, pos):
			pos.type = getType(e);	// TODO: bitch if type is string etc., allow flow & tyvar & int  & double
			arithOps.push(pos);
			return pos.type;
		case Multiply(e1, e2, pos): return getArithType(e1, e2, '*', pos);
		case Divide(e1, e2, pos): return getArithType(e1, e2, '/', pos);
		case Modulo(e1, e2, pos): return getArithType(e1, e2, '%', pos);
		case Plus(e1, e2, pos): return getArithStringType(e1, e2, '+', pos);
		case Minus(e1, e2, pos): return getArithType(e1, e2, '-', pos);
		case Equal(e1, e2, pos): return comparableTypes(e1, e2, '==', pos);
		case NotEqual(e1, e2, pos): return comparableTypes(e1, e2, '!=', pos);
		case LessThan(e1, e2, pos): return comparableTypes(e1, e2, '<', pos);
		case LessEqual(e1, e2, pos): return comparableTypes(e1, e2, '<=', pos);
		case GreaterThan(e1, e2, pos): return comparableTypes(e1, e2, '>', pos);
		case GreaterEqual(e1, e2, pos): return comparableTypes(e1, e2, '>=', pos);
		case And(e1, e2, pos): assertBools(e1, e2, "&&"); return retType(TBool);
		case Or(e1, e2, pos): assertBools(e1, e2, "||"); return retType(TBool);
		case Switch(e0, expects, cases, pos):
			expects = if (expects == null) null else normalise(expects, e0);
			var v = getType(e0, expects);
			// if no constraint on the switch is given, use the inferred input type
			var intype = if (expects == null) v else expects;
			var vok = typeEnvironment.subtype(v, intype);
			if (! vok) {
				report('Switch got ' + pt(v) + ' but expects ' + pt(intype), e0);
			}

			var result : FlowType = null;
			var hasDefault = false;	// for exhaustiveness check
			var covered = new Map<String, FlowType>(); // structs covered by the switch for exhaustiveness check
			for (c in cases) {
				var n = c.structname;
				if (n == 'default') {
					hasDefault = true;
				} else {
					covered.set(c.structname, null);
				}
			}
			var inferedIntype = if (expects == null) typeEnvironment.inferSwitchType(intype, covered) else intype;
			if (! hasDefault) {
				checkExhaustive(inferedIntype, covered, pos);
				if (expects == null) {
					// user provided no input type and no default case, so ensure this switch will only get subtypes of the structs it can match
					typeEnvironment.subtype(intype, if (inferedIntype == intype) TUnion(covered, covered) else inferedIntype);
				}

			}
			covered = new Map<String, FlowType>();

			for (c in cases) {
				var n = c.structname;
				var prev = new TypeEnvironment();
				var structType = null;
				if (n == 'default') {
					hasDefault = true;
				} else {
					var structSigma = typeEnvironment.lookup(n);
					if (structSigma == null) {
						report('Declare struct ' + n + ' before using it in a switch.', c.body);
					} else {
						structType = instantiate1('struct ' + n, structSigma);
						switch (structType) {
							case TStruct(structname, args, max):
								// maxout because this particular case can handle no more
								// than exactly this struct; we do not want covered to be
								// a unification of a tyvar related to this struct, we
								// want it to be a union of this struct & other structs

								// check this type is a subtype of the switch value 
								if (! typeEnvironment.subtype(structType, intype)) {
									report('Struct ' + pt(structType)
										   + ' is not part of ' + pt(intype) + ', so you can delete this case, or add a type annotation to the switch.', c.body);
								}
								if (covered.exists(structname)) {
									report('The struct ' + pt(structType) + ' has 2 cases in the switch.  Remove one of them.', c.body);
								} else {
									covered.set(structname, structType);
								}
								// make an environment defining the variables bound in this case
								if (args.length != c.args.length) {
									report('Give ' + args.length + ' arguments, not ' + c.args.length
										   + ' to struct ' + pt(structType), c.body);
									return newTyvar();
								}
								// definevars(zip(c.args, map getType args)
								for (i in 0...args.length) {
									var x = c.args[i];
									var prevx = shadowCheck('switch', x, c.body);
									var t = mono(args[i].type);
									if (debug > 1) trace(indent() + 'switch arg ' + x + " " + args[i].type);
									typeEnvironment.pushdefEnv(x, t, prev); // mono is safe as the type is already instantiated
								}
							default:
								report('You can only switch on structs, not ' + pt(structType), c.body);
						}
					}
				}
				refineSwitchVar(e0, prev, structType);
				var bodyType = getType(c.body, context);

				c.used_args = new FlowArray();
				for (name in c.args) {
					c.used_args.push(typeEnvironment.isUsedVar(name));
				}

				typeEnvironment.retract(prev);
				
				if (result == null) {
					result = bodyType;
				} else {
					var union = typeEnvironment.lub(result, bodyType);
					if (union == null) {
						report('Switch branch ' + c.structname + ' of type "' + pt(bodyType)
							   + '" incompatible with type of other branches "' + pt(result) + '"', c.body);
					} else {
						result = union;
					}
				}
			}
			if (vok && ! hasDefault && ! typeEnvironment.equalType(v, intype)) {
				report(pt(intype) + ' is too general, since "' + pp(e0) + '" is just ' + ppMaybe(e0, ' : ') + pt(v) + '.', e0);
			}
			return result;
		case SimpleSwitch(e0, cases, pos): throw 'getType SimpleSwitch';
		case Native(name, io, args, result, defbody, pos): return newTyvar();
			// TODO: TFlow is not very accurate, but better than 'result' which is
			// directly wrong.  Probably return a TFunction(args, result);
		case NativeClosure(nargs, fn, pos): return TFlow; // TODO: extend NativeClosure with result type & return this here
		case StackSlot(q0, q1, q2): return TFlow;
		}
	}

	// Consider:
	//		 switch (x : Maybe<int>) { 
	// 			Some(v): x.value // here we know x has type Some(), 
	//                           // and thus o.value should not give the type error "not all have a .value field"
	// refineSwitchVar(VarRef(x), ...) redeclares x in each branch of the switch
	function refineSwitchVar(e0 : Flow, prev : TypeEnvironment, structType : FlowType) : Void {
		switch (e0) {
			case VarRef(x, p):
				var t = typeEnvironment.lookup(x);
				if (t != null && structType != null) {
					typeEnvironment.pushdefEnv(x, mono(structType), prev);
				}
			default:		
		}
	}


	// getTypeVarRef handles getType(VarRef).  Use incall to enforce that struct names
	// occur only in calls:  Call(VarRef(x), ..), i.e., if x is a struct & ! incall, then
	// report an error.
	function getTypeVarRef(x : String, e : Flow, context : FlowType, incall : Bool) : FlowType {
		if (x == '__')
			report("The '__' identifier is reserved for values that are never used.", e);
		var sigma : TypeScheme = typeEnvironment.lookup(x);
		if (sigma == null) {
			// Put debugtyping/enddebugtyping around sections where you want the
			// typechecker to spew debug info.  The FlowInterpreter ignores these
			// identifiers, but BytecodeRunner does not, so avoid runnig the bytecode
			if (x == 'debugtyping') debug = 2;
			else if (x == 'enddebugtyping') debug = 0;
			else if (x != 'debugopt' && x != 'enddebugopt') report("*Unknown name during typing: " + x, e);
			return newTyvar();
		}
		if (! incall) {
			var sigma = typeEnvironment.getStruct(x);
			if (sigma != null) {
				switch (sigma.type) {
					default: throw 'getTypeVarRef non-struct';
					case TStruct(sn, args, m):
						if (args.length > 0) {
							var ax = '';
							for (a in args) {
								ax += (if (ax == '') '' else ', ') + a.name;
							}
							report('Structs must be applied. Change ' + x + ' to ' + x + '(' + ax + ')', e);
						}
				}
			}
		}
		if (typeEnvironment.isTypename(x)) {
			report(x + ' is a type name, not a value.', e);
			return newTyvar();
		}
		/* Do not allow a subtype step here (subtype(instantiate1(x, sigma),
		   alpha)), since that will make the type unnecessarily inaccurate in some
		   cases, e.g., final None will turn into a non-final None.  Make subtype steps
		   only where more than one control flow meets, e.g., in function calls & if.*/
		return instantiate1(x, sigma);
	}
	
	function typeLambda(name : String, arguments : FlowArray<String>, body, pos : Position, declared : FlowType) : FlowType {
		if (debug > 1) trace('typeLambda ' + (if (name == null) '*anon*' else name) + ', declared: ' + pt(declared));
		var previousTypes = new TypeEnvironment();
		var argTypes = new FlowArray();
		var result = null;
		// Find argument & result types.  We do not just subtype(alpha -> beta, declared)
		// because subtyping gives a less accurate input type.  None(final) < alpha makes
		// alpha := None(non-final), because in principle there could be other type <
		// alpha.  In this case we know there is not, so it is better to assign the more
		// accurate type alpha := None(final) when typechecking the body of the function.
		var udeclared = TypeEnvironment.untyvar(declared);
		if (udeclared != null) {
			// URGH! This does not work in JS!
			switch (udeclared) {
				default:
					report('Declare ' + name + ' as a function, not ' + pt(declared), body);
					declared = null; // de facto no function type declared
				case TFunction(ars, r):
					if (ars.length != arguments.length)
						report('Expected declared number of arguments ' + ars.length + ', not ' + arguments.length + ' in function ' + name , body);
					argTypes = ars;
					result = r;
			}
		}
		// if the user provided no proper argument types, assign tyvars to all formals
		if (udeclared == null) {
			for (i in 0...arguments.length) {
				argTypes.push(newTyvar());
			}
			result = newTyvar();
		}
		for (i in 0...arguments.length) {
			var a = arguments[i];
			shadowCheck(name, a, body);
			typeEnvironment.pushdefEnv(a, mono(argTypes[i]), previousTypes);
		}
		var inferredResult = getType(body);
		if (isInstantiated(result)) {
			if (! typeEnvironment.subtype(inferredResult, result)) {
				report((if (name != '') name + "'s return type " else 'Return type ')
					   + pt(inferredResult) + ' does not match the ' + (if (udeclared != null) 'declared/expected ' else 'expected ') + 'type ' + pt(result) + why(), body);
			}
		} else {
			// totodo: Maybe this is wrong? The return type needs to work in all
			// situations it is hooked into, so we may need to record that inferredResult
			// & result are connected to avoid type errors?
			result = inferredResult;
		}
		typeEnvironment.retract(previousTypes);
		var t = TFunction(argTypes, result);
		pos.type = t;
		if (debug > 1) trace('Lambda type result ' + pt(t));
		return t;
	}

	function differentFunctionTypes(tfun1 : FlowType, tfun2 : FlowType) : Bool {
		var notype = function (t : FlowType) : Bool {
			return t == null ||
				switch (t) {
					case TTyvar(alpha):
						//trace('notype TTyvar: ' + t + '  findtyvar=' + TypeEnvironment.findTyvar(alpha));
						TypeEnvironment.findTyvar(alpha).type == null;
						default: false;
				};
		}
		var equal = function (t1 : FlowType, t2 : FlowType) : Bool {
			//trace('equal: ' + (t1) + '. ' + (t2) +	 ': notype=' + notype(t1) + ': notype=' + notype(t2));
			return notype(t1) || notype(t2) || typeEnvironment.equalTypeHeur(t1, t2);
		}
		switch (tfun1) {
			case TFunction(ts1, tr1):
				switch (tfun2) {
					case TFunction(ts2, tr2):
						if (ts1.length != ts2.length || ! equal(tr1, tr2)) {
							return true;
						} else {
							for (i in 0...ts1.length) {
								if (! equal(ts1[i], ts2[i])) {
									return true;
								}
							}
							return false;
						}
						
					default: return false;
				}
			default: return false;
			// I thought these last 2 defaults impossible, but they are not:  a : ref ()
			// -> void = \ -> {}; causes it
		}
	}
	
	function isInstantiated(t : FlowType) : Bool {
		return if (t == null) false else
			switch (t) {
				case TTyvar(alpha): TypeEnvironment.findTyvar(alpha).type != null;
				default: true;
			};
	}
	
	function declaredError(id : String, declared : TypeScheme, pos1 : Position, inferred : FlowType, pos2 : Flow) : Void {
		report('Type mismatch:\tdeclared: ' + id + ' : ' + pts(declared), ConstantVoid(pos1));
		report('              \tinferred: ' + id + ' : ' + pt(inferred) + why(), pos2);
	}

	function checkExhaustive(intype : FlowType, covered : Map<String, FlowType>, pos) : Void {
		//if (debug > 1) trace('switch covers ' + covered + ' and it needs to cover the intype:  ' + intype + '.');
		// if the declared type is not a subtype of the type actually covered, the switch is not exhaustive
		var uncovered = '';
		var needed = getMax(intype);
		for (sn in needed.keys()) {
			if (! covered.exists(sn)) {
				uncovered += '\n      ' + pt(needed.get(sn));
			}
		}
		if (uncovered != '') {
			reportp('Switch does not cover all of ' + pt(intype) + '. Add cases for: ' + uncovered, pos);
		}
	}

	function getMax(t : FlowType) : Map<String, FlowType> {
		var nt = normalise(t, null);
		return switch (nt) {
			case TUnion(min, max): if (max == null) throw 'getMax: unmaxed' else max;
			case TStruct(sn, tds, max): getMax(TypeEnvironment.toUnion(nt));
			default: new Map();
		};
	}
	
	function getArithType(e1 : Flow, e2 : Flow, op : String, pos : Position) : FlowType {
		var t1 = getType(e1);
		var t2 = getType(e2, t1);
		var tm = typeEnvironment.typeMatch(t1, t2);
		var tu = TypeEnvironment.untyvar(tm);
		if (tu == TFlow) {
			reportp('I could not figure out whether this arithmetic operation is int or double', pos);
			pos.type = TInt;
			return newTyvar();
		}
		if (tu == TInt || tu == TDouble) {
			pos.type = tu;
			return tu;
		}
		if (tm != null) {
			switch (tm) {
				case TTyvar(alpha):
					pos.type = tm;
					arithOps.push(pos);
					return tm;
				default:
			}
		}
		report(pt(t1) + ' ' + op + ' ' + pt(t2) + ' is not possible', e1);
		pos.type = newTyvar();
		// already a type error, so no need to push on arithOps
		return pos.type;
	}

	function getArithStringType(e1 : Flow, e2 : Flow, op : String, pos : Position) : FlowType {
		var t1 = getType(e1);
		var t2 = getType(e2, t1);
		if (t1 == null || t2 == null) {
			report(pt(t1) + ' ' + op + ' ' + pt(t2) + ' not possible', e1);
			pos.type = newTyvar();
			return pos.type;
		}
		var tm = typeEnvironment.typeMatch(t1, t2);
		var tu = TypeEnvironment.untyvar(tm);
		if (tu == TFlow) {
			reportp('I could not figure out whether this operator is int, double or string', pos);
			pos.type = TInt;
			return newTyvar();
		}
		if (tu == TString || tu == TInt || tu == TDouble) {
			pos.type = tu;
			return tu;
		}
		if (tm != null) {
			switch (tm) {
				case TTyvar(alpha):
					pos.type = tm;
					arithStringOps.push(pos);
					return tm;
				default:
			}
		}
		report(pt(t1) + ' ' + op + ' ' + pt(t2) + ' not possible', e1);
		pos.type = newTyvar();
		return pos.type;
	}

	// Used for type checking ==, !=, <, >=, etc.  Unusually we demand no more than
	// matching types, & not that they are not functions, for the comparison operators are
	// implemented also for functions.  Lub is not ideal for this as it means sometimes
	// the types of e1 & e2 will be unified even though they need not be (e.g., comparing
	// a GramStainingCommand (which is < Command) with a Command, may cause the
	// GramStainingCommand to be unified with the Command, i.e., it infers an inaccurate
	// type for the GramStainingCommand).
	function comparableTypes(e1 : Flow, e2 : Flow, op : String, pos : Position) : FlowType {
		var t1 = getType(e1);
		var t2 = getType(e2, t1);
		if (t1 == null || t2 == null ) {
			// This can happen with code like
			// 	fold([], [], \i, acc, j -> if (j==0) 0 else 0);
			report('You cannot compare ' + pt(t1) + ' with ' + pt(t2) + ' (' + op + ')', e1);
			return TBool;
		}
		var tm = typeEnvironment.lub(t1, t2);
		if (tm == null) {
			// try the other way round, Goddammit
			tm = typeEnvironment.lub(t2, t1);
			if (tm == null) {
				report('You cannot compare ' + pt(t1) + ' with ' + pt(t2) + ' (' + op + ')', e1);
			}
		}
		pos.type2 = tm;
		return TBool;
	}

	function assertBools(e1 : Flow, e2 : Flow, op : String) : Void {
		var t1 = getType(e1);
		var t2 = getType(e2);
		if (typeEnvironment.typeMatch(t1, TBool) == null || typeEnvironment.typeMatch(t2, TBool) == null) {
			report(op + " wants 2 bools, not " + pt(t1) + " and " + pt(t2), e2);
		}
	}

	// Evaluate all toplevel declarations, so, for instance, all toplevel functions are
	// entered into the environment bound to a closure.  To give some predictability,
	// evaluate & bind them in the order they appear in the modules.
	public function evalTopdecs() : Void {
		for (d in order) {
			var c = topdecs.get(d);
			var value = eval(c);
			environment.define(d, value);
			//trace('    ' + d + ' : ' + pt(type));
		}
	}
	
	public function eval(code : Flow) : Flow {
		try {
			return run(code);
		} catch (e : Dynamic) {
			report('Exception from eval: ' + e, code);
			printCallstack();
			return SyntaxError(e, FlowUtil.getPosition(code));
		}
	}

	public function printCallstack() {
		if (debug > 0) {
			var depth = callstack.length;
			if (depth > 0) {
				Errors.warning('\n===Call stack===');
				var pr = function(c , s) {
					Errors.warning(Prettyprint.getLocation(c) + ': ' + s);
				}

				for (i in 1...10) {
					if (depth - i < 0) break;
					var c = callstack[depth - i];
					pr(c, switch (c) {
								case Let(n, sigma, v, s, p): n + ' = ' + Prettyprint.prettyprint(v, '') + '...';
								case Sequence(s, p): '{...}'; // We just ignore those, because we will get each in time
								default: Prettyprint.prettyprint(c, '');
						});
				}
				Errors.warning('===  o  ===\n');
			}

			if (debug > 1) {
				Errors.warning(serialize());
				Errors.warning(Assert.callStackToString(haxe.CallStack.exceptionStack()));
				Errors.warning('=== o0o ===\n');
			}
		}
	}

	// The public version of run() is eval()
	#if false
	function run(code : Flow) : Flow {
		var enumname = Type.enumConstructor(code);
		Profiler.get().profileStart(enumname);
//		trace(code);
//		trace(environment.serialize('  '));
		var r = doRun(code);
//		trace(Prettyprint.prettyprint(code) + ' evals to ' + Prettyprint.prettyprint(r));
		Profiler.get().profileEnd(enumname);
		return r;
	}
	function doRun(code : Flow) : Flow 
	#else
	public function run(code : Flow) : Flow 
	#end
												{
		switch (code) {
		case SyntaxError(s, pos) : throw error(s, code);
		case ConstantVoid(pos):
			return code;
		case ConstantString(value, pos):
			return code;
		case ConstantDouble(value, pos):
			return code;
		case ConstantBool(value, pos):
		    return code;
		case ConstantI32(value, pos):
			return code;
		case ConstantArray(values, pos):
			var as = new FlowArray();
			for (v in values) {
				as.push(run(v));
			}
			return Flow.ConstantArray(as, pos);
		case ConstantStruct(name, args, pos):
			return code;
			/*var as = new FlowArray();
			for (v in args) {
				as.push(run(v));
			}
			return Flow.ConstantStruct(name, as, pos);*/
		case ConstantNative(value, pos):
			return code;
		case ArrayGet(array, index, pos):
			var a = FlowUtil.getArray(run(array));
			var i = FlowUtil.getInt(run(index));
			if (i < 0 || i >= cast(a.length, Int)) {
				throw error("Index " + i + " out of range for " + a, index);
			}
			return a[i];
		case VarRef(name, pos) :
			var variable : Flow = environment.lookup(name);
			if (variable != null) {
				return variable;
			}
			var typeDeclaration = userTypeDeclarations.get(name);
			if (typeDeclaration == null) {
				if (name == 'debugtyping' || name == 'enddebugtyping') {
					return ConstantBool(true, pos);
				} else {
					throw error("**Unknown name: " + name, code);
				}
			}
			return code;
		case Field(call, name, pos): {
			var v = run(call);
			switch (v) {
			case VarRef(sname, p): {
				var typeDeclaration = userTypeDeclarations.get(sname);
				switch (typeDeclaration.type.type) {
				case TStruct(structname, cargs, max):
					if (name == "structname") {
						return ConstantString(sname, pos);
					}
				default:
				}
			}
			case ConstantStruct(sname, args, pos): {
				var typeDeclaration = userTypeDeclarations.get(sname);
				switch (typeDeclaration.type.type) {
				case TStruct(structname, cargs, max):
					if (name == "structname") {
						return ConstantString(sname, pos);
					}
					var i = 0;
					var nargs : Int = cargs.length;
					while (i < nargs) {
						if (cargs[i].name == name) {
							return args[i];
						}
						++i;
					}
				default:
				}
			}
			default:
			}
			throw error("Field ." + name + " not found in " + Prettyprint.print(v), call);
		}
		case SetMutable(call, name, value, pos): {
			var v = run(call);
			var val = run(value);
			switch (v) {
			case ConstantStruct(sname, args, pos): {
				var typeDeclaration = userTypeDeclarations.get(sname);
				switch (typeDeclaration.type.type) {
				case TStruct(structname, cargs, max):
					var i = 0;
					var nargs : Int = cargs.length;
					while (i < nargs) {
						if (cargs[i].name == name) {
							if (cargs[i].is_mutable) {
								args[i] = val;
								return ConstantVoid(pos);
							}

							throw error("Field ."+name+" is not mutable in "+Prettyprint.print(v),call);
						}
						++i;
					}
				default:
				}
			}
			default:
			}
			throw error("Field ." + name + " not found in " + Prettyprint.print(v), call);
		}
		case RefTo(value, pos) :
			var v = run(value);
			memory.cells.push(v);
			return Pointer(memory.cells.length - 1, pos);
		case Pointer(index, pos):
			return code;
		case Deref(pointer, pos):
			return getCell(run(pointer));
		case SetRef(pointer, value, pos):
			var cell = FlowUtilInternal.getAddress(run(pointer));
			var val = run(value);
			// Side-effect!
			memory.cells[cell] = val;
			return ConstantVoid(pos);

		case Cast(value, fromtype, totype, pos) :
			return coerce(run(value), fromtype, totype, pos);

		case Let(name, sigma, value, scope, pos):
			var previous = environment.lookup(name);
			var val = run(value);
			if (scope == null) {
				return ConstantVoid(pos);
			}
			if (debug > 1) {
				Errors.warning("Setting " + name + " = " + Prettyprint.print(val));
				Errors.warning("Running " + pp(scope));
			}
			environment.define(name, val);
			var r = run(scope);
			if (previous != null) {
				environment.define(name, previous);
				if (debug > 1) {
					Errors.warning(name + " is restored to previous scope");
				}
			} else {
				environment.revoke(name);
				if (debug > 1) {
					Errors.warning(name + " is out of scope");
				}
			}
			return r;

		case Lambda(arguments, type, body, _, pos):
			var environment = new Environment();
			// Capture free variables of this code into the environment
			capture(code, environment);
			return Closure(code, environment, pos);

		case Closure(body, environment, pos):
			return code;

		case Call(clos, arguments, pos):
			#if false
			var fnname = switch (clos) {
				case VarRef(n, pos): n;
				default: "unknown";
			};
			#end
			var closure = run(clos);
			switch (closure) {
			case Closure(lambda, closureEnvironment, pos):
				switch (lambda) {
				case Lambda(args, type, body, _, pos):
					return callLambda(code, lambda, closureEnvironment, args, body, arguments);
				default:
					throw error("The closure in a call expects a lambda", lambda);
				}
			case VarRef(n, pos):
				// Evaluate the children
				var as = new FlowArray();
				for (a in arguments) {
					as.push(run(a));
				}

				var typeDecl = userTypeDeclarations.get(n);
				switch (typeDecl.type.type) {
				case TStruct(structname, args, max):
					return ConstantStruct(n, as, pos);
				default:
				}
				throw error("Call to unknown function " + n, closure);
			case NativeClosure(nargs, fn, pos):
				var as = new FlowArray();
				for (a in arguments) {
					as.push(run(a));
				}
				return fn(as, FlowUtil.getPosition(code));
				
			default:
				throw error("Call expects a closure, var reference or native closure, got " + pp(closure), closure);
			}
		case Sequence(statements, pos):
			var r = null;
			for (s in statements) {
				if (debug > 1) {
					Errors.report("Running " + pp(s));
				}
				r = run(s);
			}
			return r;
		case If(condition, then, elseExp, pos):
			if (evalToBool(condition)) {
				return run(then);
			} else {
				return run(elseExp);
			}
		case Not(e, pos): return ConstantBool(! evalToBool(e), pos);
		case Negate(e, pos):
			var v = run(e);
		 	var t = runtimeType(v);
			if (t == TInt) {
				return ConstantI32(-(FlowUtil.getI32(v)), pos);
			} else if (t == TDouble) {
				return ConstantDouble(-FlowUtil.getDouble(v), pos);
			} else {
				throw error('Negate wants int or double, not ' + pt(t), code);
			}
		case Multiply(e1, e2, pos):
			var v1 = run(e1);
			var v2 = run(e2);
		 	var t1 = runtimeType(v1);
		 	var t2 = runtimeType(v2);
			if (t1 == TInt && t2 == TInt) {
				return ConstantI32((FlowUtil.getI32(v1) * FlowUtil.getI32(v2)), pos);
			} else if (t1 == TDouble && t2 == TDouble) {
				return ConstantDouble(FlowUtil.getDouble(v1) * FlowUtil.getDouble(v2), pos);
			} else {
				throw error('int*int or double*double, not ' + pt(t1) + '*' + pt(t2), code);
			}
		case Divide(e1, e2, pos):
			var v1 = run(e1);
			var v2 = run(e2);
		 	var t1 = runtimeType(v1);
		 	var t2 = runtimeType(v2);
			if (t1 == TInt && t2 == TInt) {
				return ConstantI32(Std.int(FlowUtil.getI32(v1) / FlowUtil.getI32(v2)), pos);
			} else if (t1 == TDouble && t2 == TDouble) {
				return ConstantDouble(FlowUtil.getDouble(v1) / FlowUtil.getDouble(v2), pos);
			} else {
				throw error('int/int or double/double, not ' + pt(t1) + '/' + pt(t2), code);
			}
		case Modulo(e1, e2, pos):
			var v1 = run(e1);
			var v2 = run(e2);
		 	var t1 = runtimeType(v1);
		 	var t2 = runtimeType(v2);
			if (t1 == TInt && t2 == TInt) {
				return ConstantI32((FlowUtil.getI32(v1) % FlowUtil.getI32(v2)), pos);
			} else if (t1 == TDouble && t2 == TDouble) {
				return ConstantDouble(FlowUtil.getDouble(v1) % FlowUtil.getDouble(v2), pos);
			} else {
				throw error('int % int or double % double, not ' + pt(t1) + '%' + pt(t2), code);
			}
		case Plus(e1, e2, pos):
			var v1 = run(e1);
			var v2 = run(e2);
		 	var t1 = runtimeType(v1);
		 	var t2 = runtimeType(v2);
			if (t1 == TInt && t2 == TInt) {
				return ConstantI32((FlowUtil.getI32(v1) + FlowUtil.getI32(v2)), pos);
			} else if (t1 == TDouble && t2 == TDouble) {
				return ConstantDouble(FlowUtil.getDouble(v1) + FlowUtil.getDouble(v2), pos);
			} else if (t1 == TString && t2 == TString) {
				return ConstantString(FlowUtil.getString(v1) + FlowUtil.getString(v2), pos);
			} else {
				throw error("Can only add ints, doubles and strings. Found " + pt(t1) + " + " + pt(t2) +
							" Forgot a cast or to dereference?", e1);
			}
		case Minus(e1, e2, pos):
			var v1 = run(e1);
			var v2 = run(e2);
		 	var t1 = runtimeType(v1);
		 	var t2 = runtimeType(v2);
			if (t1 == TInt && t2 == TInt) {
				return ConstantI32((FlowUtil.getI32(v1) - FlowUtil.getI32(v2)), pos);
			} else if (t1 == TDouble && t2 == TDouble) {
				return ConstantDouble(FlowUtil.getDouble(v1) - FlowUtil.getDouble(v2), pos);
			} else {
				throw error("Can only subtract ints and doubles. Found " +
							pt(t1) + " - " + pt(t2) + " Forgot a cast or to dereference?", e1);
			}
		case Equal(e1, e2, pos):
			var r1 = run(e1);
			var r2 = run(e2);
			return ConstantBool(compare(r1, r2, pos) == 0, pos);
		case NotEqual(e1, e2, pos):
			var r1 = run(e1);
			var r2 = run(e2);
			return ConstantBool(compare(r1, r2, pos) != 0, pos);
		case LessThan(e1, e2, pos):
			var r1 = run(e1);
			var r2 = run(e2);
			var t1 = runtimeType(r1);
			var t2 = runtimeType(r2);
			switch (t1) {
			case TStruct(s, a, max): 0;
			default: requireEqualType(r1, r2, t1, t2, e1);
			}
			return ConstantBool(compare(r1, r2, pos) < 0, pos);
		case LessEqual(e1, e2, pos):
			var r1 = run(e1);
			var r2 = run(e2);
			var t1 = runtimeType(r1);
			var t2 = runtimeType(r2);
			switch (t1) {
			case TStruct(s, a, max): 0;
			default: requireEqualType(r1, r2, t1, t2, e1);
			}
			return ConstantBool(compare(r1, r2, pos) <= 0, pos);
		case GreaterThan(e1, e2, pos):
			var r1 = run(e1);
			var r2 = run(e2);
			var t1 = runtimeType(r1);
			var t2 = runtimeType(r2);
			switch (t1) {
			case TStruct(s, a, max): 0;
			default: requireEqualType(r1, r2, t1, t2, e1);
			}
			return ConstantBool(compare(r1, r2, pos) > 0, pos);
		case GreaterEqual(e1, e2, pos):
			var r1 = run(e1);
			var r2 = run(e2);
			var t1 = runtimeType(r1);
			var t2 = runtimeType(r2);
			switch (t1) {
			case TStruct(s, a, max): 0;
			default: requireEqualType(r1, r2, t1, t2, e1);
			}
			return ConstantBool(compare(r1, r2, pos) >= 0, pos);
		case And(e1, e2, pos):
			return ConstantBool(evalToBool(e1) && evalToBool(e2), pos);
		case Or(e1, e2, pos):
			return ConstantBool(evalToBool(e1) || evalToBool(e2), pos);
		case Switch(value, type, cases, pos):

			var codeForCase = function (c : SwitchCase, args : FlowArray<Flow>) : Flow {
					// Bind the arguments to the variables
					if (c.args.length != args.length) {
						throw error("Wrong number of arguments to " + c.structname + " in switch. Got "
									 + args.length + " but expected " + c.args.length, ConstantVoid(pos));
					}
					var backup = [];
					for (i in 0...c.args.length) {
						var v = c.args[i];
						backup.push({name:v, val:environment.lookup(v)});
						environment.define(v, args[i]);
					}
					var rv = run(c.body);
					backup.reverse();
				    for (b in backup) {
						if (b.val != null)
							environment.define(b.name, b.val);
						else
							environment.revoke(b.name);
				    }
					return rv;
				}
			return runSwitch(code, value, cases, codeForCase);
		case SimpleSwitch(value, cases, pos):
			var codeForCase = function (ca : SimpleCase, args : FlowArray<Flow>) : Flow {return run(ca.body);}
			return runSwitch(code, value, cases, codeForCase);
		case Native(name, io, args, result, defbody, pos):
			try {
				var fn = makeNativeFn(name, args, result);
				return NativeClosure(args.length, fn, pos);
			} catch (e : Dynamic) {
				if (defbody != null)
					return run(defbody);
				throw e;
			}
		case NativeClosure(nargs, fn, pos):
			return code;
		case StackSlot(q0, q1, q2):
			return code;
		}
	}

	function runSwitch(code, value, cases : FlowArray<Dynamic>,
					   codeForCase : Dynamic -> FlowArray<Flow> -> Flow) {
		// Dynamic == SwitchCase or SimpleCase.  Haxe typing cannot handle it with a type
		// parameter for some reason
		var v = run(value);
		var constructor = null;
		try {
			constructor = FlowUtilInternal.getConstructor(v);
		} catch (d : Dynamic) {
			report('Exception when evaluating switch: ' + d, code);
			printCallstack();
			throw d;
		}
		var defaul = null;
		for (c in cases) {
			if (c.structname == constructor.name) {
				return codeForCase(c, constructor.args);
			}
			if (c.structname == "default") {
				defaul = c;
			}
		}
		if (defaul != null) {
			return run(defaul.body);
		}
		throw error("Value not caught in switch: " + pp(v), code);
	}

	function callLambda(code, lambda, closureEnvironment, args : FlowArray<String>, body, arguments : FlowArray<Flow>) {
		// TODO: If arguments is < args, then build a curried version
		if (arguments.length != args.length) {
			throw error("Call to closure that takes " + args.length + " but got " + arguments.length, lambda);
		}
					
		// Evaluate arguments in the current environment
		var v = new FlowArray();
		for (a in arguments) {
			v.push(run(a));
		}
		
		// Then bind these guys in the environment along with the current closure
		var orig = environment.add(closureEnvironment);
		var l = arguments.length - 1;
		for (i in 0...arguments.length) {
			var name = args[i];
			var previous = environment.lookup(name);
			if (previous != null) {
				orig.define(name, previous);
			}
			var val = v[i];
			environment.define(name, val);
		}
		if (debug > 0) {
			if (callstack.length > 1000) {
				throw error("Stack is too deep!", code);
			}
			callstack.push(code);
		}
		#if false
				Profiler.get().profileStart(fnname);
		#end
		var r = run(body);
		#if false
				Profiler.get().profileEnd(fnname);
		#end
		if (debug > 0) {
			callstack.pop();
		}
		for (n in args) {
			environment.revoke(n);
		}
		environment.retract(orig);
		return r;
	}
	
	function runtimeType(value : Flow) : FlowType {
		switch (value) {
		case ConstantVoid(pos): return TVoid;
		case ConstantString(value, pos): return TString;
		case ConstantDouble(value, pos): return TDouble;
		case ConstantBool(value, pos): return TBool;
		case ConstantI32(value, pos): return TInt;
		case ConstantArray(values, pos): {
			// if all types are compatible, return the lub of them, otherwise TFlow
			var lastType : FlowType = null;
			for (v in values) {
				var t = runtimeType(v);
				lastType = if (lastType == null) t else typeEnvironment.lub(t, lastType);
				if (lastType == null) {
					// the types are incompatible, so this is just a flow array
					return TArray(TFlow);
				}
			}
			return TArray(if (lastType != null) lastType else TFlow);
		}
		case ConstantStruct(name, values, pos):
			var type = userTypeDeclarations.get(name);
			if (type == null) {
				trace('ConstantStruct ' + name + ' not found in userTypeDeclarations');
				trace('userTypeDeclarations HAS: ' + userTypeDeclarations);
			} else {
				var monotype = instantiate1('runtime struct ' + name, type.type);
				switch (monotype) {
					case TStruct(structname, args, max):
						return monotype;
					default:
						trace('ConstantStruct that does not have struct type');
				}
			}
			return TFlow;
		case ConstantNative(val, pos):
			return TNative;
		case Pointer(address, pos):
		 	return TPointer(runtimeType(getCell(value)));
		case Closure(b, e, pos):
			return TFlow;		// Not accurate, but if we are to check runtime values, we need to store type info at runtime too
		case NativeClosure(nargs, fn, pos): return TFlow; // Extend NativeClosure with result type & return this here
		case StackSlot(q0, q1, q2): return TFlow;
		case VarRef(name, pos):
			var td = userTypeDeclarations.get(name);
			if (td != null) {
				var monotype = instantiate1('runtime struct ' + name, td.type);
				switch (monotype) {
					case TStruct(n, args, max):
						return monotype;
					default:
				}
			}
			throw error(name + ' is not a struct.  Only VarRefs that are structs should occur at runtime.', value);
		default:
			throw 'runtimeType of ' + value + ': this value should not appear at runtime!';
		}
	}
	
	public function typeRun(code : Flow) : Flow {
		var r = null;
		if (typecheck(code) != null) {
			//reportInstantiations();
			reportUntypedArithOps();
			r = eval(code);
		}
		return r;
	}

	private function recordInstantiation(name, t) {
		var i = instantiations.get(name);
		if (i == null) {
			i = new FlowArray();
			instantiations.set(name, i);
		}
		i.push(t);
	}

	private function reportInstantiations() {
		trace('');
		trace('REPORT OF INSTANTIATIONS OF POLYMORPHIC FUNCTIONS');
		for (id in instantiations.keys()) {
			var i = instantiations.get(id);
			trace('    ' + id + ' was instantiated to:');
			for (t in i) {
				trace('            ' + pt(t));
			}
		}
		trace('');
	}

	function reportUntypedArithOps() {
		for (p in arithOps) {
			if (p.type == null) throw 'arith op with no type in its position' + p;
			var t = FlowUtil.untyvar(p.type);
			if (t == null) {
				reportp('I could not figure out whether this arithmetic operation is int or double', p);
			} else {
				switch (t) {
					case TInt:
					case TDouble:
					default:
						reportp('This arithmetic operator must be int or double, not ' + pt(t), p);
				}
			}
		}

		for (p in arithStringOps) {
			if (p.type == null) throw 'arith/string op with no type in its position' + p;
			var t = FlowUtil.untyvar(p.type);
			if (t == null) {
				reportp('I could not figure out whether this operator is int, double or string', p);
			} else {
				switch (t) {
					case TInt:
					case TDouble:
					case TString:
					default:
						reportp('Operator must be int, double or string, not ' + pt(t), p);
				}
			}
		}
		// reset them now these are reported
		arithOps = new FlowArray();
		arithStringOps = new FlowArray();
	}
	
	function requireEqualType(v1, v2, t1, t2, site) : Void {
		if (typeEnvironment.lub(t1, t2) == null) {
			throw error("Can not compare " + pp(v1) + " with " + pp(v2) + ". Use a cast (v : " + pt(t1) + " -> " + pt(t2) + "),", site);
		}
	}
	
	function compare(r1 : Flow, r2 : Flow, pos : Position) : Int {
		if (r1 == r2) { return 0; }
		var t1 = runtimeType(r1);
		var t2 = runtimeType(r2);
		if (t1 == TVoid && t2 == TVoid) {
			return 0;
		}
		var match = TypeEnvironment.untyvar(typeEnvironment.lub(t1, t2));
		if (match != null) {
			switch (match) {
			case TBool: {
				var b1 = FlowUtil.getBool(r1) ? 1 : 0;
				var b2 = FlowUtil.getBool(r2) ? 1 : 0;
				return b1 < b2 ? -1 : (b1 == b2 ? 0 : 1);
			}
			case TInt: return I2i.compare(FlowUtil.getI32(r1), FlowUtil.getI32(r2));
			case TDouble: {
				var d1 = FlowUtil.getDouble(r1);
				var d2 = FlowUtil.getDouble(r2);
				return d1 < d2 ? -1 : (d1 == d2 ? 0 : 1);
			}
			case TString: {
				var s1 = FlowUtil.getString(r1);
				var s2 = FlowUtil.getString(r2);
				return s1 < s2 ? -1 : (s1 == s2 ? 0 : 1);
			}
			case TArray(at1): {
				var a1 = FlowUtil.getArray(r1);
				var a2 = FlowUtil.getArray(r2);
				return compareArray(a1, a2, pos);
			}
			case TStruct(structname1, s1, max1):
				var st1 = FlowUtilInternal.getConstructor(r1);
				var st2 = FlowUtilInternal.getConstructor(r2);
				if (st1.name < st2.name) return -1;
				if (st1.name > st2.name) return 1;
				return compareArray(st1.args, st2.args, pos);
			case TUnion(min, max):
				var st1 = FlowUtilInternal.getConstructor(r1);
				var st2 = FlowUtilInternal.getConstructor(r2);
				if (st1.name < st2.name) return -1;
				if (st1.name > st2.name) return 1;
				return compareArray(st1.args, st2.args, pos);
			case TPointer(rt):
				var a1 = FlowUtilInternal.getAddress(r1);
				var a2 = FlowUtilInternal.getAddress(r2);
				return a1 < a2 ? -1 : (a1 == a2 ? 0 : 1);
			case TFunction(a,r):
				return -1;
			case TFlow:
				switch (r1) {
				case Closure(body, env, pos): return -1;
				default:
				}
			default:
			}
		}
		throw error("I cannot compare " + pp(r1) + " with " + pp(r2) + ". Use a cast (v : " + pt(t1) + " -> " + pt(t2) + "),", ConstantVoid(pos));
	}

	public static function isSameObj(r1 : Flow, r2 : Flow, pos : Position) : Bool {
		if (r1 == r2) { return true; }
		switch (r1) {
		case ConstantVoid(pos):
			switch (r2) {
				case ConstantVoid(pos2): return true;
				default: return false;
			}
		case ConstantString(value, pos):
			switch (r2) {
				case ConstantString(value2, pos2): return value == value2;
				default: return false;
			}
		case ConstantDouble(value, pos):
			switch (r2) {
				case ConstantDouble(value2, pos2): return value == value2;
				default: return false;
			}
		case ConstantBool(value, pos):
			switch (r2) {
				case ConstantBool(value2, pos2): return value == value2;
				default: return false;
			}
		case ConstantI32(value, pos):
			switch (r2) {
				case ConstantI32(value2, pos2): return value == value2;
				default: return false;
			}
		case ConstantArray(values, pos):
			switch (r2) {
				case ConstantArray(values2, pos2): return values == values2;
				default: return false;
			}
		case ConstantStruct(name, values, pos):
			switch (r2) {
				case VarRef(name2, pos2):
					return name == name2 && values.length == 0;
				case ConstantStruct(name2, values2, pos2):
					if (name != name2)
						return false;
					if (values.length == 0 && values2.length == 0)
						return true;
					return values == values2;
				default: return false;
			}
		case ConstantNative(value, pos):
			switch (r2) {
				case ConstantNative(value2, pos2): return value == value2;
				default: return false;
			}
		case Pointer(address, pos):
			switch (r2) {
				case Pointer(address2, pos2): return address == address2;
				default: return false;
			}
		case Closure(b, e, pos):
			switch (r2) {
				case Closure(b2, e2, pos2): return b == b2 && e == e2;
				default: return false;
			}
		case NativeClosure(nargs, fn, pos):
			switch (r2) {
				case NativeClosure(nargs2, fn2, pos2): return fn == fn2;
				default: return false;
			}
		case VarRef(name, pos):
			switch (r2) {
				case VarRef(name2, pos2): return name == name2;
				case ConstantStruct(name2, values2, pos2):
					return name == name2 && values2.length == 0;
				default: return false;
			}
		case StackSlot(a,b,c):
			throw "this target is not supported";
		default:
			return false;
		}
	}

	function evalToBool(e : Flow) : Bool {
		var v = run(e);
		switch (v) {
			case ConstantBool(b, pos): return b;
			default: throw error('Expected bool, not ' + pp(v), e);
		}
	}
	
	function compareArray(a1 : FlowArray<Flow>, a2 : FlowArray<Flow>, pos : Position) : Int {
		var l = Math.floor(Math.min(a1.length, a2.length));
		for (i in 0...l) {
			var c = compare(a1[i], a2[i], pos);
			if (c != 0) return c;
		}
		if (a1.length < a2.length) {
			return -1;
		} else if (a1.length == a2.length) {
			return 0;
		} else {
			return 1;
		} 
	}

	public function capture(code : Flow, env : Environment) : Void {
		if (code == null) return;
		switch (code) {
		case SyntaxError(s, pos) : 0;
		case ConstantVoid(pos): 0;
		case ConstantBool(value, pos): 0;
		case ConstantI32(value, pos): 0;
		case ConstantDouble(value, pos): 0;
		case ConstantString(value, pos): 0;
		case ConstantArray(value, pos):
			for (a in value) {
				capture(a, env);
			}
		case ConstantStruct(name, values, pos):
			for (a in values) {
				capture(a, env);
			}
		case ConstantNative(value, pos): 0;
		case ArrayGet(array, index, pos):
			capture(array, env);
			capture(index, env);
		case VarRef(name, pos):
			var variable : Flow = environment.lookup(name);
			if (variable != null) {
				env.define(name, variable);
				return;
			}
		case Field(call, name, pos):
			capture(call, env);
		case RefTo(value, pos):
			capture(value, env);
		case Pointer(index, pos):
		case Deref(pointer, pos):
			capture(pointer, env);
		case SetRef(pointer, value, pos):
			capture(pointer, env);
			capture(value, env);
		case SetMutable(pointer, name, value, pos):
			capture(pointer, env);
			capture(value, env);
		case Cast(value, fromtype, totype, pos):
			capture(value, env);

		case Let(name, sigma, value, scope, pos):
			capture(scope, env);
			env.revoke(name);
			// If name appears in the value, it is free
			capture(value, env);

		case Lambda(arguments, type, body, _, pos):
			capture(body, env);
			for (a in arguments) {
				env.revoke(a);
			}

		case Closure(body, environment, pos):
			capture(body, env);

		case Call(closure, arguments, pos):
			capture(closure, env);
			for (a in arguments) {
				capture(a, env);
			}

		case Sequence(statements, pos):
			for (a in statements) {
				capture(a, env);
			}

		case If(condition, then, elseExp, pos):
			capture(condition, env);
			capture(then, env);
			capture(elseExp, env);
		case Not(e, pos): capture(e, env);
		case Negate(e, pos): capture(e, env);
		case Multiply(e1, e2, pos):
			capture(e1, env);
			capture(e2, env);
		case Divide(e1, e2, pos):
			capture(e1, env);
			capture(e2, env);
		case Modulo(e1, e2, pos):
			capture(e1, env);
			capture(e2, env);
		case Plus(e1, e2, pos):
			capture(e1, env);
			capture(e2, env);
		case Minus(e1, e2, pos):
			capture(e1, env);
			capture(e2, env);
		case Equal(e1, e2, pos):
			capture(e1, env);
			capture(e2, env);
		case NotEqual(e1, e2, pos):
			capture(e1, env);
			capture(e2, env);
		case LessThan(e1, e2, pos):
			capture(e1, env);
			capture(e2, env);
		case LessEqual(e1, e2, pos):
			capture(e1, env);
			capture(e2, env);
		case GreaterThan(e1, e2, pos):
			capture(e1, env);
			capture(e2, env);
		case GreaterEqual(e1, e2, pos):
			capture(e1, env);
			capture(e2, env);
		case And(e1, e2, pos):
			capture(e1, env);
			capture(e2, env);
		case Or(e1, e2, pos):
			capture(e1, env);
			capture(e2, env);
		case Switch(value, type, cases, pos) :
			capture(value, env);
			for (c in cases) {
				//TODO: This is wrong with
				// x = something;
				// switch() {
				// S1(x): x refers to local variable
				// S2(): x should refer to closure, not local variable from S1
				// S3(x): x refers to local variable
				// }
				capture(c.body, env);
				// The names in a constructor should not
				// be captured into the environment
				for (a in c.args) {
					env.revoke(a);
				}
			}
		case SimpleSwitch(value, cases, pos):
			capture(value, env);
			for (c in cases) {
				capture(c.body, env);
			}
		case Native(name, io, args, result, defbody, pos):
		case NativeClosure(nargs, fn, pos):
		case StackSlot(q0, q1, q2):
		}
	}

	function coerce(value : Flow, fromtype : FlowType, totype : FlowType, pos : Position) : Flow {
		// A special case: We support "downcasting" to flow
		if (totype == TFlow) {
			return value;
		}
		switch (fromtype) {
		case TVoid: throw error("Void type of " + value, value);
		case TInt:
			var i = FlowUtil.getI32(value);
			if (totype == TDouble) {
				return ConstantDouble(I2i.floatFromInt(i), pos);
			} else if (totype == TString) {
				return ConstantString('' + i, pos);
			}
		case TDouble:
			var f = FlowUtil.getDouble(value);
			if (totype == TInt) {
				return ConstantI32(I2i.intFromFloat(f), pos);
			} else if (totype == TString) {
				return ConstantString('' + f, pos);
			}
		case TString:
			if (totype == TString) {
				return value;
			}
		default:
			if (FlowUtil.isStructType(fromtype)) {
				var from = typeEnvironment.normalise(fromtype);
				var to = typeEnvironment.normalise(totype);
				var t = runtimeType(value);
				if (typeEnvironment.subtype(t, to)) {
					return value;
				}
			}
		}
		throw error("Could not cast " + pt(fromtype) + " to " + pt(totype) + " (" + pp(value) + ")", value);
	}

	static private function mono(t : FlowType) : TypeScheme {
		return FlowUtil.mono(t);
	}

	static function error(error : String, code : Flow) : String {
		return Prettyprint.getLocation(code) + ": " + error;
	}

	static private function report(s : String, code : Flow) : Void {
		Errors.report(error(s, code));
	}

	static private function reportp(s : String, pos : Position) : Void {
		Errors.report(Prettyprint.position(pos) + ': ' + s);
	}

	function pt(t : FlowType) : String {
		return Prettyprint.prettyprintType(t, typeEnvironment.normalise);
	}

	function pts(t : TypeScheme) : String {
		return Prettyprint.prettyprintTypeScheme(t, typeEnvironment.normalise);
	}

	static function pp(code : Flow) : String {
		return Prettyprint.prettyprint(code, '');
	}
	
	function makeNativeFn(name : String, args : FlowArray<FlowType>, result : FlowType) : FlowArray<Flow> -> Position -> Flow {
		var clas = null;
		var method = name;
		var lastDot = name.lastIndexOf(".");
		if (lastDot > 0) {
			clas = name.substr(0, lastDot);
			method = name.substr(lastDot + 1);
		}

		if (clas != null) {
			try {
				var cl = Type.resolveClass(clas);
				if (cl == null) {
					throw "Could not resolve native " + clas;
				}
				var obj = Type.createInstance(cl, [this]);
				var meth = Reflect.field(obj, method);
				if (meth == null) {
					throw "Could not find native " + method + " in " + clas;
				}

				// TODO: We could implement automatic conversion to/from flow/native types here
				return function(args : FlowArray<Flow>, pos : Position) : Flow {
					#if false
					if (name.indexOf("profile") == -1) {
						Profiler.get().profileStart(name);
					}
					var r = Reflect.callMethod(obj, meth, [args, pos]);
					if (name.indexOf("profile") == -1) {
						Profiler.get().profileEnd(name);
					}
					return r;
					#else
					try {
						var r = Reflect.callMethod(obj, meth, [args, pos]);
					/*TODO: to check at runtime that a native function does return the
					  right type requires runtime types
					  
					if (debug > 0 && typeEnvironment.typeMatch(me.runtimeType(r), result) == null) {
						throw ( 'Native ' + name + ' returned ' + runtimeType(r) + ', but should have returned ' + result);
					}
					*/
						return r;
					} catch (e : Dynamic) {
						throw "Exception caught in native implementation of " + name + ": " + e;
					}
					#end
				}
			} catch (e : Dynamic) {
				throw "I could not make native " + name + ": " + e + ". Recompile flowrunner.hxml, flowflash.hxml";
			}
		}
		throw "Native " + name + " requires a class in this target";
	}

	// Returns the name of the first unknown user type
	function checkForUnknownUserTypes(t : FlowType) : String {
		switch (t) {
		case TVoid: return null;
		case TFlow: return null;
		case TBool: return null;
		case TInt: return null;
		case TDouble: return null;
		case TString: return null;
		case TNative: return null;
		case TTyvar(ref):
			return null; 		// if unknown names are in an instantiated tyvar, they originate somewhere else
		case TBoundTyvar(i): return null;
		case TReference(rt):
			return checkForUnknownUserTypes(rt);
		case TPointer(rt):
			return checkForUnknownUserTypes(rt);
		case TArray(rt):
			return checkForUnknownUserTypes(rt);
		case TFunction(args, rt):
			var r = checkForUnknownUserTypes(rt);
			if (r != null) return r;
			for (a in args) {
				r = checkForUnknownUserTypes(a);
				if (r != null) return r;
 			}
			return null;
		case TStruct(structname, args, max):
			for (a in args) {
				var r = checkForUnknownUserTypes(a.type);
				if (r != null) return r;
 			}
			return null;
		case TUnion(min, max):
			if (min != null) {
				for (t in min) {
					var r = checkForUnknownUserTypes(t);
					if (r != null) return r;
				}
			}
			if (max != null) {
				for (t in max) {
					var r = checkForUnknownUserTypes(t);
					if (r != null) return r;
				}
			}
			return null;
		case TName(n, args):
			for (a in args) {
				var r = checkForUnknownUserTypes(a);
				if (r != null) return r;
 			}			
			return checkTypeNameDefined(n);
		}
	}

	// null=ok, otherwise the name of the undefined typename
	function checkTypeNameDefined(name : String) : String {
		var td = userTypeDeclarations.get(name);
		return if (td != null && FlowUtil.isStructType(td.type.type)) null else name;
	}

	function shadowCheck(infunction : String, name : String, e : Flow) : TypeScheme {
		var previous = typeEnvironment.lookup(name, false);
		if (previous != null && name != '__') {
			report((if (infunction != '') infunction + ': ' else '') + 'Do not redefine ' + name + ' : ' + pts(previous), e);
			var td = userTypeDeclarations.get(name);
			if (td != null) {
				reportp('     ' + name + ' is declared globally here: ', td.position);
			}
			var topdec = topdecs.get(name);
			if (topdec != null) {
				report('     ' + name + ' is defined here: ', topdec);
			}
		}
		return previous;
	}
	
	function instantiate1(name : String, sigma : TypeScheme) : FlowType {
		if (FlowUtil.isPolymorphic(sigma)) {
			var t = FlowUtil.instantiate(sigma);
			// recordInstantiation(name, t); // get rid of this; it is for debugging only
			return t;
		} else {
			return sigma.type;
		}
	}

	// What type will .name return?  If t is a struct, we can see it directly in the
	// struct; if it is a union, we must take the type union of all occurrences of the
	// type of name.  Do not call fieldType(flow, name), instead call fieldType([all
	// structs that have a .name field], name).
	function fieldType(code: Flow, t : FlowType, context : FlowType, name : String) : FlowType {
		var nt = typeEnvironment.normalise(TypeEnvironment.untyvar(t));
		if (nt == null) return newTyvar();
		switch (nt) {
			case TStruct(sn, tds, max):	// totodo: take max into consideration ... if it is not maxed out, the fieldtype too can grow...
				var r = field(nt, name);
				if (r == null) 
					throw 'fieldType did not find the field .' + name + ' in struct ' + pt(t)
						  + ', which is impossible as fieldType is only called on the intersection of structs that DO have this field';
				else return r;
			case TUnion(min, max):
				// lub() all types of field called 'name' to return the best approximation
				// of the type of this field.
				var u = if (context != null) context else newTyvar();
				if (max == null) throw 'fieldType: max must be more specific'; // else return TFlow..
				for (st in min) {
					var r = field(st, name);
					if (r == null) 
						throw 'fieldType did not find the field .' + name + ' in union ' + pt(t)
							  + ', which is impossible as fieldType is only called on the intersection of structs that DO have this field';
					else {
						if (! typeEnvironment.subtype(r, u)) {
							report('I could not find a common type for .' + name + ' in all structs in '
												 + pt(t) + ". Add type annotation to mark which one is correct", code);
							return newTyvar();
						}
					}
				}
				// Find the ones in max that are potential subtypes,
				var candidates = new Map();
				var names = new Array();
				for (sn in max.keys()) {
					var st = max.get(sn);
					var r = field(st, name);
					if (typeEnvironment.isSubtype(r, u)) {
						candidates.set(sn, r);
						names.push(sn);
					}
				}

				// Next, check if all candidates are compatible in a ring
				var error = false;
				for (i in 0...names.length) {
					var sn1 = names[i];
					var sn2 = names[(i + 1) % names.length];
					var st1 = candidates.get(sn1);
					var st2 = candidates.get(sn2);
					if (!typeEnvironment.isSubtype(st1, st2) ||
						!typeEnvironment.isSubtype(st2, st1)) {
						error = true;
						break;
					}
				}
				if (!error) {
					// They all agree, so do the subtyping to unify stuff
					for (r in candidates) {
						if (!typeEnvironment.subtype(r, u)) {
							throw "isSubtype is not conservative enough";
						}
					}
				}
				return u;
			default:
				throw('fieldType default ' + t + ', normalised: ' + nt);	// totodo: return TFlow or newTyvar()?
				// TODO: this does happen, e.g., TFlow, or type errors (e.g., "(ref 42).value")
				// We should return the toType from typeEnvironment.structFields
		}
		return newTyvar();
	}

	// works only on TStruct
	function fieldDef(st : FlowType, name : String) : MonoTypeDeclaration {
		switch (st) {
			default: throw 'field ' + st;
			case TStruct(sn, tds, max):	// totodo: take max into consideration ... if it is not maxed out, the fieldtype too can grow...
				for (td in tds) {
					if (td.name == name) {
						return td;
					}
				}
				return null;
		}
	}

	function field(st : FlowType, name : String) : FlowType {
		var td = fieldDef(st, name);
		return (td == null) ? null : td.type;
	}
	
	function swap(st : FlowType) : FlowType {
		var ut = TypeEnvironment.untyvar(st);
		return switch (ut) {
			case TUnion(min, max): if (max != null) throw 'swap field type'
														  else TUnion(new Map(), min);
			case TStruct(sn, tds, max): TypeEnvironment.toUnion(ut);
			default: throw 'swap not union ' + st;
		};
	}
	
	public function isHidden(name : String) : Bool {
		return hidden.exists(name);
	}

	public function hiddenWhere(name : String) : String {
		return hidden.get(name);
	}

	// Mark name hidden in module (i.e., there is an export section in that module that
	// does NOT mention name)
	public function hide(name : String, module : String) : Void {
		hidden.set(name, module);
	}

	function newTyvar() : FlowType {
		return FlowUtil.newTyvar();
	}
	
	static function spaces(n : Int) {
		return if (n <= 0) '' else ' ' + spaces(n - 1);
	}

	static function th(i) {
		return i + (if (i <= 0) '' else if (i % 10 == 1) 'st' else if (i % 10 == 2) 'nd' else if (i % 10 == 3) 'rd' else 'th');
	}

	// for appending further explanations to type errors
	function why() : String {
		var s = typeEnvironment.why();
		return if (s != 'incompatible' && s != 'mismatch') ' (' + s + ')' else '';
	}
	
	static function ppMaybe(e : Flow, suffix : String = ' ', nothing : String = '') : String {
		var n = FlowUtil.size(e);
		return if (n < 7) pp(e) + suffix else nothing;
	}

	function replacePointersWithReferences(v : Flow) : Flow {
		return FlowUtil.mapFlow2(v, function(f : Flow) : Flow {
			return switch (f) {
				case ConstantStruct(name,args,pos):
					if (name == "DList")
						ConstantStruct(name,new FlowArray(), pos);
					else
						f;
				case Pointer(p, pos): {
					RefTo(getCell(f), pos);
				}
				default: f;
			}
		});
	}
	
	function normalise(t : FlowType, e : Flow) : FlowType {
		try {
			return typeEnvironment.normalise(t);
		} catch (m : Mismatch) {
			report(m.why, e);
			return newTyvar();
		}
	}
	
 	// Order of toplevel declarations, so that we can evaluate & bind them in the
	// environment in the order they are declared.
	public var order : FlowArray<String>;

	// Toplevel declarations.  Why not just use the environment? because we cannot afford
	// to have lambda in the environment, only closures.  This is an evalTopdecs()
	// combined with Lambda/Closure mixup technicality that only happens when a topdec has
	// a forward reference.
	public var topdecs : Map<String, Flow>;

	// Toplevel identifiers that are hidden because they are not part of an export section
	// in the module where they are declared.
	private var hidden : Map<String, String>;
	
	public var environment : Environment;

	// Type environment used during type checking mapping each identifier to the type
	// inferred (or declared) so far.
	public var typeEnvironment : TypeEnvironment;

	// Explicit type declarations by the user, e.g., makeAspect : (string, [string]) ->
	// Aspect; & nothing if the user did not declare a type & also (for now) nothing if he
	// did not declare it toplevel, e.g., \ x : int ->, results in no entry.  Populated
	// from the userTypeDeclarations in modules included in this interpreter.
	public var userTypeDeclarations : OrderedHash<TypeDeclaration>; // name -> {name, type, position}
	//public var userTypeDeclarationsOrder : Array<String>; 

	private var allNodeTypes : Bool;

	var memory : Memory;

	// 0: No debug, 1: callstacks, 2: verbose
	static public var debug : Int;
	public var callstack : FlowArray<Flow>;
	
	// for debugging: record a list of type instantiations for each identifier
	public var instantiations : Map<String, FlowArray<FlowType>>;

	var arithOps : FlowArray<Position>;
	var arithStringOps : FlowArray<Position>;
}
