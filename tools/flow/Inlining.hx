import FlowUtil;
import Flow;

typedef Inlines = {
	functions : Map<String, Flow>,
	variables : Map<String, Flow>,
}

// Adjust cost estimates according to the target. Right now, they are somewhat useful for bytecode.
// inline-limit 15 gives the shortest code with a saving of 9603 bytes for formdesigner.

//   flow -c unittest.bytecode -I c:/flowapps --inline-limit 15 flowunit/flowunit_flash.flow

// TODO:
// - Consider different cost models for different targets
// - Profile and improve performance?
// - Constant folding
// - Profile guided inlining
// - Speculative inlining, and then check if the result is smaller

class Inlining {
	public static function inlineCalls(p : Program, limit : Int, verbose : Bool) : Void {
		sideEffects = new Map();
		codeSizes = new Map();
		useCounts = new Map();
		useCounts.set("main", 1);

		var inlines = {
			functions: new Map(),
			variables: new Map()
		}

		for (d in p.declsOrder) {
			hasTopLevelSideEffects(p, d, false);
			var e = p.topdecs.get(d);
			if (e != null) {
				countUses(p, e);
			} else {
				Sys.println(d + " is empty!");
			}
		}

		var newOrder = new FlowArray();

		// First, inline top-level variables
		for (d in p.declsOrder) {
			var e = p.topdecs.get(d);
			if (e != null) {
				switch (e) {
					case Lambda(arguments, type, body, _, pos): {
						newOrder.push(d);
					}
					case Native(name, io, args, result, defbody, pos): {
						newOrder.push(d);
					}
					default: {
						// Variables
						var eff = sideEffects.get(d);
						var uses = useCounts.get(d);
						var dead = false;

						var inlined = doInlining(p, e, inlines, verbose);
						var sz = estimateSize(inlined);
						codeSizes.set(d, sz);

						if (!eff && sz > 0 && uses > 0) {
							// We only inline variables is they are shorter than a variable reference, or only used once
							if (sz <= 3 || uses == 1) {
								inlines.variables.set(d, inlined);
								dead = true;
							}
						}

						if (dead) {
							p.topdecs.set(d, null);
						} else {
							newOrder.push(d);
							p.topdecs.set(d, inlined);
						}
					}
				}
			}
		}
		p.declsOrder = newOrder;

		/* Next, inline all these variables everywhere. Since we can have code like
			cos(x) { sin(PI/2.0 - x) }
			PI = 3.14159265358979323846264338327950;
		in that order, we inline the constant variables that were removed again.
		*/
		for (d in p.declsOrder) {
			var e = p.topdecs.get(d);
			var inlined = doInlining(p, e, inlines, verbose);
			p.topdecs.set(d, inlined);
		}

		// Next, find out what functions to inline
		var functionsToInline = new Map();
		for (d in p.declsOrder) {
			var e = p.topdecs.get(d);

			var eff = sideEffects.get(d);
			var uses = useCounts.get(d);
			var dead = false;

			var inlined = doInlining(p, e, inlines, verbose);
			var sz = estimateSize(inlined);
			codeSizes.set(d, sz);

			if (!eff && sz > 0 && uses > 0) {
				switch (inlined) {
					case Lambda(arguments, type, body, _, pos): {
						var callSize = 6 * uses;
						var inlineSz = uses * (sz - (10 + 2 * arguments.length)); // We have a saving from inlining
						// Sys.println(d + " was " + callSize + " becomes " + inlineSz + ", size " + sz + " " + Prettyprint.prettyprint(inlined));
						if (sz < limit) {
							functionsToInline.set(d, inlined);
						}
					}
					default:
				}
			}
		}

		/* Now, inline functions. */
		inlines.variables = new Map();
		inlines.functions = functionsToInline;
		for (d in p.declsOrder) {
			var e = p.topdecs.get(d);
			var inlined = doInlining(p, e, inlines, verbose);
			p.topdecs.set(d, inlined);
		}

		if (false && verbose) {
			for (d in p.declsOrder) {
				var e = p.topdecs.get(d);
				Sys.println(d + "=" + Prettyprint.prettyprint(e) + ";");
			}
		}
	}

	// Performs variable and function inlining, and other optimizations
	static function doInlining(p : Program, exp : Flow, inlines : Inlines, verbose : Bool) : Flow {
		var inlined = FlowUtil.mapFlow(exp, function (e) {
			var r = switch (e) {
				case VarRef(n, pos): {
					var def = inlines.variables.get(n);
					if (def != null) {
						if (verbose) {
							Sys.println("Inlining " + n + " as " + Prettyprint.prettyprint(def)
							 	// + " with size " + codeSizes.get(n) + " and " + useCounts.get(n) + " uses"
							 );
						}
						def;
					} else e;
				}
				case Call(closure, arguments, pos): {
					switch (closure) {
						case VarRef(n, pos): {
							var def = inlines.functions.get(n);
							if (def != null) {
								var inlined = doInlineFunction(p, def, arguments, pos, inlines, verbose);
								if (inlined != null) {
									if (verbose) {
										Sys.println("Inlining " + Prettyprint.prettyprint(e) + " as " + Prettyprint.prettyprint(inlined)
										 //+ " with size " + codeSizes.get(n) + " and " + useCounts.get(n) + " uses"
										 );
									}
									inlined;
								} else {
									e;
								}
							} else {
								if (n == "strlen") {
									switch (arguments[0]) {
										case ConstantString(s, p): {
											// strlen("constant") -> int
											ConstantI32(s.length, pos);
										}
										default: e;
									}
								} else if (n == "length") {
									switch (arguments[0]) {
										case ConstantArray(a, p): {
											// length( constant ) -> int
											ConstantI32(a.length, pos);
										}
										default: e;
									}
								} else {
									e;
								}
							}
						}
						default: e;
					}
				}
				case Let(name, sigma, value, scope, pos): {
					// Local let: See if it is worth inlining
					var optValue = doInlining(p, value, inlines, verbose);
					var lambda = isLambda(optValue);
					var sideEffect = hasSideEffects(p, optValue, true);
					if (!sideEffect && scope != null) {
						var cnt = countNameUse(scope, name);
						var sz = estimateSize(optValue);
						if (cnt == 0) {
							if (verbose) {
								Sys.println("Unused let! " + name);
							}
							scope;
						} else if ((cnt == 1 || (sz <= 3 && !lambda)) && !inlines.variables.exists(name)) {
							var oldVal = inlines.variables.get(name);
							inlines.variables.set(name, optValue);
							var res = doInlining(p, scope, inlines, verbose);
							if (oldVal == null) {
								inlines.variables.remove(name);
							} else {
								inlines.variables.set(name, oldVal);
							}
							res;
						} else {
							e;
						}
					} else {
						e;
					}
				}
				case If(condition, then, else_, pos): {
					switch (condition) {
						case ConstantBool(b, p): {
							// if (true) ... -> then, if (false) ... -> else
							if (b) then else else_;
						}
						case Not(exp, p2): {
							// if (!e1) e2 else e3 -> if (e1) e3 else e2
							If(exp, else_, then, pos);
						}
						default: {
							return e;
						}
					}
				}
				case Not(ee, po): {
					switch (ee) {
						case ConstantBool(b, p): {
							// not true -> false, not false -> true
							ConstantBool(!b, po);
						}
						case Not(e2, p): {
							// Double negation cancels
							e2;
						}
						default: {
							return e;
						}
					}
				}
				case And(e1, e2, po): {
					switch (e1) {
						case ConstantBool(b1, p): {
							if (b1 == false) e1 else e2;
						}
						default: {
							return e;
						}
					}
				}
				case Or(e1, e2, po): {
					switch (e1) {
						case ConstantBool(b1, p): {
							if (b1 == true) e1 else e2;
						}
						default: {
							return e;
						}
					}
				}
				// TODO: Do more constant folding here
				default: e;
			};
			return r;
		});
		return inlined;
	}

	static function isLambda(e : Flow) : Bool {
		switch (e) {
			case Lambda(args, type, body, _, pos): return true;
			default: return false;
		}
	}

	static function doInlineFunction(p : Program, fn : Flow, arguments : FlowArray<Flow>, pos : Position, inlines : Inlines, verbose : Bool) : Flow {
		switch (fn) {
			case Lambda(args, type, body, _, pos): {
				var argTypes = null;
				var retType = null;
				switch (pos.type) {
					case TFunction(args, returns): {
						argTypes = args;
						retType = returns;
					}
					default:
				}
				if (argTypes != null) {
					var b = body;
					var i = args.length - 1;
					for (j in 0...args.length) {
						var a = args[i];
						var type = FlowUtil.quantify(argTypes[i]);
						var arg = arguments[i];

						if (containNames(arg, args)) {
							// Name aliasing - don't inline!
							return null;
						}

						b = Let(a, type, arg, b, pos);
						--i;
					}
					return doInlining(p, b, inlines, verbose);
				} else {
					return null;
				}
			}
			default: return null;
		}
		return null;
	}

	static function countUses(p : Program, exp : Flow) : Int {
		var count = 0;
		FlowUtil.traverseExp(exp, function(e) {
			switch (e) {
				case VarRef(n, pos): {
					if (p.topdecs.exists(n)) {
						var cnt = useCounts.get(n);
						if (cnt == null) cnt = 0;
						useCounts.set(n, cnt + 1);
					}
				}
				default:
			}
		});
		return count;
	}

	static function containNames(e : Flow, names : FlowArray<String>) : Bool {
		var found = false;
		FlowUtil.traverseExp(e, function(e) {
			switch (e) {
			case VarRef(n, pos): {
				for (nm in names) {
					if (nm == n) found = true;
				}
			}
			default:
			}			
		});
		return found;
	}

	static function countNameUse(e : Flow, name : String) : Int {
		var count = 0;
		FlowUtil.traverseExp(e, function(e) {
			switch (e) {
			case VarRef(n, pos): {
				if (n == name) {
					count += 1;
				}
			}
			default:
			}
		});
		return count;
	}

	// Conservative estimate of whether this top level name has side-effects
	static function hasTopLevelSideEffects(p : Program, n : String, onlyKnownCalls : Bool) : Bool {
		if (sideEffects.exists(n)) {
			var h : Null<Bool> = sideEffects.get(n);
			return h == null || h;
		}
		// Prevent recursion
		sideEffects.set(n, null);
		var e = p.topdecs.get(n);
		var eff = hasSideEffects(p, e, onlyKnownCalls);
		sideEffects.set(n, eff);
		return eff;
	}

	// Does this code has side-effects? If onlyKnownCalls is set, we are skeptical about all calls we
	// can not prove is safe
	static function hasSideEffects(p : Program, exp : Flow, onlyKnownCalls : Bool) : Bool {
		var effect = false;
		if (exp == null) return false;
		FlowUtil.traverseExp(exp, function(e) {
			switch (e) {
			case RefTo(value, pos): effect = true;
			case SetRef(p, v, ps): effect = true;
			case Deref(pointer, pos): effect = true;
			case VarRef(name, ps): {
				if (p.topdecs.exists(name)) {
					var eff = hasTopLevelSideEffects(p, name, onlyKnownCalls);
					if (eff) effect = true;
				}
			}
			case Native(name, io, args, result, defbody, pos): {
				if (io) effect = true;
			}
			case SetMutable(pointer, field, value, pos): effect = true;
			case Call(closure, arguments, pos): {
				switch (closure) {
					case VarRef(name, ps): {
						var known = sideEffects.get(name);
						if (known || (known == null && onlyKnownCalls)) {
							effect = true;
						}
					}
					default: {
						if (onlyKnownCalls) {
							effect = true;
						}
					}
				}
			}
			default:
			}
		});
		return effect;
	}

	// Does this top-level name have side-effects?
	static var sideEffects : Map<String, Null<Bool>>;
	// An estimate of how big this code is
	static var codeSizes : Map<String, Int>;
	// How many times is this top-level symbol used?
	static var useCounts : Map<String, Int>;

	static function estimateSize(exp : Flow) : Int {
		if (exp == null) return 0;
		var size = switch (exp) {
		case ConstantVoid(pos): 1;
		case ConstantBool(value, pos): 2;
		case ConstantI32(value, pos): 5;
		case ConstantDouble(value, pos): 9;
		case ConstantString(value, pos): 3 + value.length;
		case ConstantArray(es, pos): 3 + estimateSizes(es);
		case ConstantStruct(name, values, pos): 3 + estimateSizes(values);
		case ArrayGet(array, index, pos): 1 + estimateSize(array) + estimateSize(index);
		case VarRef(name, pos): 3;
		case RefTo(value, pos): 1 + estimateSize(value);
		case Pointer(pointer, pos): 1;
		case Deref(pointer, pos): 1 + estimateSize(pointer);
		case SetRef(pointer, value, pos): 1 + estimateSize(pointer) + estimateSize(value);
		case SetMutable(pointer, field, value, pos): 2 + estimateSize(pointer) + estimateSize(value);
		case Let(name, sigma, value, scope, pos): 3 + estimateSize(value) + (if (scope != null) estimateSize(scope) else 1);
		case Lambda(arguments, type, body, _, pos): 6 + 4 * arguments.length + estimateSize(body); // We should count 7 bytes for free vars as well, and a bit for other locals
		case Closure(body, freevars, pos): estimateSize(body);
		case Call(closure, arguments, pos): 1 + estimateSize(closure) + estimateSizes(arguments);
		case Sequence(statements, pos): statements.length - 1 + estimateSizes(statements);
		case If(condition, then, elseExp, pos): 
		  10 + estimateSize(condition)
		  + estimateSize(then)
		  + estimateSize(elseExp);
		case Not(e, pos): 1 + estimateSize(e);
		case Negate(e, pos): 1 + estimateSize(e);
		case Multiply(e1, e2, pos): 1 + estimateSize(e1) + estimateSize(e2);
		case Divide(e1, e2, pos): 1 + estimateSize(e1) + estimateSize(e2);
		case Modulo(e1, e2, pos): 1 + estimateSize(e1) + estimateSize(e2);
		case Plus(e1, e2, pos): 1 + estimateSize(e1) + estimateSize(e2);
		case Minus(e1, e2, pos): 1 + estimateSize(e1) + estimateSize(e2);
		case Equal(e1, e2, pos): 1 + estimateSize(e1) + estimateSize(e2);
		case NotEqual(e1, e2, pos): 2 + estimateSize(e1) + estimateSize(e2);
		case LessThan(e1, e2, pos): 1 + estimateSize(e1) + estimateSize(e2);
		case LessEqual(e1, e2, pos): 1 + estimateSize(e1) + estimateSize(e2);
		case GreaterThan(e1, e2, pos): 2 + estimateSize(e1) + estimateSize(e2);
		case GreaterEqual(e1, e2, pos): 2 + estimateSize(e1) + estimateSize(e2);
		case And(e1, e2, pos): 7 + estimateSize(e1) + estimateSize(e2);
		case Or(e1, e2, pos): 8 + estimateSize(e1) + estimateSize(e2);
		case Field(call, name, pos): 2 + estimateSize(call);
		case Cast(value, fromtype, totype, pos): 1 + estimateSize(value);
		case Switch(e, type, cases, p): {
		  var s = 7 + estimateSize(e);
		  for (c in cases) {
		    s += 6 + 3 * c.args.length + estimateSize(c.body);
		  }
		  s;
		}
		case SimpleSwitch(e, cases, p): {
		  var s = 7 + estimateSize(e);
		  for (c in cases) {
		    s += 6 + estimateSize(c.body);
		  }
		  s;
		}
		case SyntaxError(e, p): 1;
		case StackSlot(q0, q1, q2): 1;
		case NativeClosure(args, fn, pos): 1;
		case Native(name, io, args, result, defbody, pos): 0;
		case ConstantNative(value, pos): 1;
		}
		return size;
	}

	static function estimateSizes(es : Array<Flow>) : Int {
		var s = 0;
		for (e in es) {
			s += estimateSize(e);
		}
		return s;
	}
}
