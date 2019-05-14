import Flow;
import FlowArray;
import Aform;
import OptEnv;

class Optimiser {
	function new() {
			tmps = new Map();
			exceptionCount = 0;
	}
	
	static public function optimise(p : Program, noDelet : Bool, inlineLimit_ : Int, cb : Program -> Void) : Void {
		Profiler.get().profileStart('optimise');
		debug = FlowInterpreter.debug;
		//debugrename = 2;
		inlineLimit = inlineLimit_;
		if (debug > 0) tr('// optimising,  inlineLimit = ' + inlineLimit);
		new Optimiser().optimise0(p, noDelet, function(p) {
			if (debug > 0) tr('// done');
			cb(p);
		});
		Profiler.get().profileEnd('optimise');
	}

	// convert VarRef occurrences of structs to ConstantStruct, i.e., convert
	// Call(VarRef("Some"), [e1]) to ConstantStruct("Some", [e1]) & convert VarRef("None")
	// to ConstantStruct("None", []).  Side-effect p.
	function structConvert(p : Program) : Void {
		var isStruct = function (x : String) : Bool {
			var td = p.userTypeDeclarations.get(x);
			if (td != null) {
				switch (td.type.type) {
					case TStruct(sn, args, max): return true;
					default:
				}
			}
			return false;
		}
	
		var structConvert0 = function (e : Flow) : Flow {
			switch (e) {
				case Call(e0, es, pos): {
					switch (e0) {
						case ConstantStruct(x, args, pos0): return ConstantStruct(x, es, pos);
						default:
					}
				}
				case VarRef(x, pos): {
					if (isStruct(x)) return ConstantStruct(x, new FlowArray(), pos);
				}
				default:
			}
			return e;
		}
		for (d in p.declsOrder) {
			var e1 = p.topdecs.get(d);
			var e2 = FlowUtil.mapFlow(e1, structConvert0);
			p.topdecs.set(d, e2);
		}
	}
	
	function optimise0(p, noDelet : Bool, cb : Program -> Void) {
		structConvert(p);

		initEnvs(p);
		var env = OptEnv.make();
		done = new Map();
		todoOrder = new FlowArray();
		todoSet = new Map();
		aformed = new Map();
		aform = new Aform(this);

		// Schedule all relevant topdecs in declaration order
		for (d in p.declsOrder) {
			var e = p.topdecs.get(d);
			switch (e) {
				case Lambda(xs, type, e0, _, p0): // ignore it until it is needed (if ever)
				case Closure(lambda, freevars, p0): impossible('Closure in program - do not preevaluate the code before optimising');
				case Native(name, io, args, result, defbody, pos): // ignore it until it is needed (if ever)
				default:
					// all other globally declared ids must be initialised before main() is run	
					scheduleVar(d /*, ' because it is: ' + pp(e)*/);
			}
		}
		
		scheduleVar("main");
		poll(p, env, noDelet, cb, haxe.Timer.stamp());
	}

	function initEnvs(p : Program) : Void {
		// init environments from program p
		structs = new Map();
		for (d in p.userTypeDeclarations) {
			switch (d.type.type) {
				case TStruct(sn, args, max): structs.set(sn, d.type);
				default:
			}
		}
		toplevel = new Map();
		for (d in p.declsOrder) {
			toplevel.set(d, p.topdecs.get(d));
		}
		interpreterhack = new FlowInterpreter();
		interpreterhack.userTypeDeclarations = p.userTypeDeclarations;
		interpreterhack.typeEnvironment = p.typeEnvironment;
		staticTopdecs = new Map();
	}
	
	function poll(p : Program, env : OptEnv, noDelet : Bool, cb : Program -> Void, startTime : Float) {
		while (todoOrder.length > 0) {
			#if !sys
			var time = haxe.Timer.stamp();
			if (time - startTime > 5.0) {
				tr("// Time-out closing in: Postpone a frame!");
				haxe.Timer.delay(poll.bind(p, env, noDelet, cb, time), 1);
				return;
			}
			#end
			
			var d = todoOrder.shift();
			if (debug > 1) tr("// optimizing " + d);
			var u = aformed.get(d);
			if (u == null) {
				var e = p.topdecs.get(d);
				if (e != null) {
					u = convert(e);
					//tr('aform(' + pp(e) + ') = ' + pp(u));
					aformed.set(d, u);
				}
			}
			if (u != null) {
				var showit = false; //was: debug > 1 || debug > 0 && FlowUtil.size(u) > 5;
				if (showit) tr('\n' + d + ' === ');
				var optimized = noclosure(pe(u, env));
				if (showit) tr('           ' + pp(optimized));
				done.set(d, optimized);
				schedule(optimized, env);
			}
		}

		// remove names from order that are no longer in the program
		var order = new FlowArray();
		for (d in p.declsOrder) {
			if (done.get(d) != null) {
				order.push(d);
			} else {
				if (debug > 1) tr(d + ' was optimised away');
			}
		}

		// de-let, i.e., flatten, i.e., no longer aform
		if (!noDelet) {
			for (d in done.keys()) {
				var w = Delet.delet(done.get(d), done);
				done.set(d, w);
			}
		}
		if (debug > 1 || debug > 0) {
			traceOptimised(p, order);
		}
		cb({userTypeDeclarations: p.userTypeDeclarations,
				typeEnvironment: p.typeEnvironment,
				modules: null, declsOrder: order, topdecs: done});
	}

	// Schedule global variables in e for specialisation
	function schedule(e : Flow, o : OptEnv) : Void {
		var me = this;
		FlowUtil.traverseExp(e, function (e) {
			switch (e) {
				case VarRef(x, p):
					// mark for specialisation if it is a global varref
					if (me.toplevel.get(x) != null) {
						me.scheduleVar(x);
					}
				default:
			}});
	}

	function scheduleVar(x : String, why : String = '') : Void {
		if (done.get(x) == null && todoSet.get(x) == null) {
			//tr('scheduling ' + x + why);
			todoOrder.push(x);
			todoSet.set(x, true);
		}
	}
	
	// change occurrences of closures to lambdas
	static function noclosure(e : Flow) : Flow {
		return FlowUtil.mapFlow(e, function (e) {
			return switch (e) {
				case Closure(code, freevars, pos):
					var e0 = noclosure(code); // mapFlow skips code within a Closure, so recurse explicitly
					var trivial = true;
					if (freevars != null) {
						for (x in freevars.variables.keys()) {
							var v = freevars.variables.get(x);
							switch (v) {
								case VarRef(y, p): if (y == x) {
									// fine
									continue;
								}
								default:
									// maybe not impossible; we will see
									impossible('    FREE VARIABLE ' + x + ' HAS RESIDUAL CODE' + pp(v));
							}
							trivial = false;
							e0 = Let(x, null, v, e0, pos);
						}
					}
					if (debug > 1 && ! trivial) {
						tr('a closure that had non-trivial free variables was wrapped in lets:');
						tr('  Closure:        ' + pp(e));
						tr('  Converted to:   ' + pp(e0));
					}
					e0;

				default: e;
			}});
	}
	
	public function pe(e : Flow, o : OptEnv) : Flow {
		var showit = debug > 2 && FlowUtil.size(e) > 1;
		if (showit) depth++;
		if (showit) tr('pe(' + pp(e) + ') = [');
		var r = null;
		
		try {
		
			r = pe0(e, o);
		
		} catch (excn : Dynamic) {
			if (exceptionCount == 0) {
				trace('exception during optimisation: ' + excn + ', from expression: ' + pp(e));
			} else if (exceptionCount == 7) {
				trace('surrounding expression: ' + pp(e));
				trace('variables in that:');
				FlowUtil.traverseExp(e, function (e1) {
					switch (e1) {
						case VarRef(x, p): 
							trace('    var ' + x + ' -> ' + pp(lookup0(x, o)));
						default:
					}
				});
			}
			exceptionCount++;
			throw excn;
		}
		
		if (showit) tr('        ' + pp(r) + ']');
		if (r == null && exceptionCount == 0) impossible('pe of "' + pp(e) + '" yields null');
		if (showit) depth--;
		return r;
	}
	
	function pe0(code : Flow, env : OptEnv) : Flow {
		switch (code) {
			case SyntaxError(s, pos): return impossible('SyntaxError ' + s);
			case ConstantVoid(pos): return code;
			case ConstantString(value, pos): return code;
			case ConstantDouble(value, pos): return code;
			case ConstantBool(value, pos): return code;
			case ConstantI32(value, pos): return code;
			case ConstantNative(value, pos): return code;
			case ConstantArray(values, pos):
				var as = new FlowArray();
				for (v in values) {
					as.push(pe(v, env));
				}
				return Flow.ConstantArray(as, pos);
			case ConstantStruct(name, args, pos):
				var as = new FlowArray();
				for (v in args) {
					as.push(pe(v, env));
				}
				return Flow.ConstantStruct(name, as, pos);
			case ArrayGet(e1, e2, pos):
				return binop(e1, e2, env, function (v1, v2) { return ArrayGet(v1, v2, pos); } );
			case VarRef(x, pos): return peVarRef(x, pos, env);
			case Field(e0, name, p):
				var v0 = pe(e0, env);
				var w0 = deep(v0, env);
				switch (w0) {
					case ConstantStruct(sn, args, p2):
						var st = structs.get(sn).type;
						switch (st) {
							default: {
								impossible('pe field: not structtype');
								return null;
							}
							case TStruct(_, fields, max):
								for (i in 0...fields.length) {
									if (fields[i].name == name) {
										var r = args[i];
										return if (isDynamic(r)) Field(v0, name, p) else r;
									}
								}
								return if (name == 'structname') ConstantString(sn, p2)
									   else impossible('Field .' + name + ' not in ' + st + ' in ' + pp(code));
						}
					//case Let(_, _, _, _, _): impossible('field not in aform ' + pp(code) + ' gives: ' + pp(w0) + p);
					//case Sequence(_, _): impossible('field not in aform: sequence');
					// todo: things are NOT always in aform: global ids may be bound to an
					// expression in aform (b = make(0.0), i.e., b=(t1=ref 0; t2=...;
					// DynamicBehaviour(t1, t2))), but when you access it as a variable,
					// you get something NOT in aform.  To fix that we need to make the
					// locals inside the global (t1 & t2) into globals too...
					case VarRef(x, p2):
						return Field(v0, name, p);
					default:
						//trace('Field extraction: pe(' + pp(code) + ') : deep gives:' + pp(w0));
						return Field(v0, name, p);
				};
			case RefTo(value, pos):
				return RefTo(pe(value, env), pos);
			case Pointer(index, pos): return code;
			case Deref(pointer, pos): 
				return Deref(pe(pointer, env), pos);
			case SetRef(pointer, value, pos):
				return SetRef(pe(pointer, env), pe(value, env), pos);
			case SetMutable(pointer, field, value, pos):
				return SetMutable(pe(pointer, env), field, pe(value, env), pos);
			case Cast(e0, fromtype, totype, pos) : return monop(e0, env, function (v0) {return Cast(v0, fromtype, totype, pos);});
			case Let(x, sigma, e1, e2, pos): return wlet(x, sigma, e1, e2, pos, env);
			case Lambda(xs, type, body, _, pos):
				var id = pos.f + pos.s;
				//if (debug > 1) tr('pe Lambda ' + id + ' (');
				env.unfolding.set(id, true);
				var ys = new FlowArray();
				var renamehash = new Map();
				var renameneeded = false;
				for (x in xs) {
					if (lookup0(x, env) != null) {
						var y = newtmp1(x, env);
						renamehash.set(x, y);
						renameneeded = true;
						ys.push(y);
						if (debugrename > 1) tr('\\-bound ' + x + ' renamed to ' + y);
					} else {
						ys.push(x);
					}
				}
				if (renameneeded) {
					if (debugrename > 1) tr('[\\-body rename : ' + pp(body));
					body = rename(body, renamehash);
					xs = ys;
					if (debugrename > 1) tr('     to : ' + pp(body) + ']');
				}
				var r = close(FlowUtil.lambda(xs, type, pe(body, envForVars(xs, env, pos)), pos), env);
				env.unfolding.remove(id);
				//if (debug > 1) tr('  ) ==== ' + pp(r));
				return r;
			case Closure(body, freevars, pos):
				return code;
			case Call(e0, es, pos): return pelet(code, null, null, env);
			case Sequence(statements, pos):
				var s = new FlowArray();
				var n = statements.length;
				for (i in 0...n) {
					var v = statements[i];
					var v1 = pe(v, env);
					var last = (i == n - 1);
					// We only have to keep side-effecting expressions and the last value
					if (last || hasSideeffects(v1, env)) {
						s.push(v1);
					}
				}
				if (s.length == 1) {
					// If it is just a single value, no need for a sequence
					return s[0];
				}
				return Sequence(s, pos);
			case If(e0, e1, e2, pos): return pelet(code, null, null, env);
			case Not(e, pos): return monop(e, env, function (v) {return Not(v, pos);});
			case Negate(e, pos): return monop(e, env, function (v) {return Negate(v, pos);});
			case Multiply(e1, e2, pos): {
				switch (e1) {
					case SyntaxError(id, p):
						env.unfolding.remove(id);
						return pe(e2, env);
					default:
				}
				var v1 = pe(e1, env);
				var v2 = pe(e2, env);
				var e = Multiply(v1, v2, pos);
				var v1s = isStatic(v1, env);
				var v2s = isStatic(v2, env);
				if (v1s && v2s) {
					return eval(e, env);
				} else {
					if (v1s || v2s) {
						// Check for some multiplications simplications
						var staticValue = v1s ? v1 : v2;
						var otherValue = v1s ? v2 : v1;
						switch (staticValue) {
							case ConstantDouble(d, p): {
								if (d == 1.0) {
									return otherValue;
								} else if (d == 0.0) {
									if (hasSideeffects(otherValue, env)) {
										// If there are side-effects, we have to keep them
										return e;
									} else {
										return ConstantDouble(0.0, pos);
									}
								} else if (d == -1.0) {
									return Negate(otherValue, pos);
								}
							}
							case ConstantI32(i, p): {
								if (i == 1) {
									return otherValue;
								} else if (i == 0) {
									if (hasSideeffects(otherValue, env)) {
										// If there are side effects, we have to keep them
										return e;
									} else {
										return ConstantI32((0), pos);
									}
								} else if (i == -1) {
									return Negate(otherValue, pos);
								}
							}
							default: {}
						}
					}
				}
				return e;
			}
			case Divide(e1, e2, pos): return binop(e1, e2, env, function (v1, v2) {return Divide(v1, v2, pos);});
			case Modulo(e1, e2, pos): return binop(e1, e2, env, function (v1, v2) {return Modulo(v1, v2, pos);});
			case Plus(e1, e2, pos): {
				var v1 = pe(e1, env);
				var v2 = pe(e2, env);
				var e = Plus(v1, v2, pos);
				var v1s = isStatic(v1, env);
				var v2s = isStatic(v2, env);
				if (v1s && v2s) {
					return eval(e, env);
				} else {
					if (v1s || v2s) {
						// Check for some addition simplications
						var staticValue = v1s ? v1 : v2;
						var otherValue = v1s ? v2 : v1;
						switch (staticValue) {
							case ConstantDouble(d, p): {
								// x + 0.0
								if (d == 0.0) {
									return otherValue;
								}
							}
							case ConstantI32(i, p): {
								// x + 0
								if (i == 0) {
									return otherValue;
								}
							}
							default: {}
						}
					}
				}
				switch (v2) {
					case Negate(nv, npos): {
						// a+-x == a-x
						return Minus(v1, nv, pos);
					}
					default: {}
				}
				return e;
			}
			case Minus(e1, e2, pos): return binop(e1, e2, env, function (v1, v2) {return Minus(v1, v2, pos);});
			case Equal(e1, e2, pos): return binop(e1, e2, env, function (v1, v2) {return Equal(v1, v2, pos);});
			case NotEqual(e1, e2, pos): return binop(e1, e2, env, function (v1, v2) {return NotEqual(v1, v2, pos);});
			case LessThan(e1, e2, pos): return binop(e1, e2, env, function (v1, v2) {return LessThan(v1, v2, pos);});
			case LessEqual(e1, e2, pos): return binop(e1, e2, env, function (v1, v2) {return LessEqual(v1, v2, pos);});
			case GreaterThan(e1, e2, pos): return binop(e1, e2, env, function (v1, v2) {return GreaterThan(v1, v2, pos);});
			case GreaterEqual(e1, e2, pos): return binop(e1, e2, env, function (v1, v2) {return GreaterEqual(v1, v2, pos);});
			case And(e1, e2, pos): {
				var v1 = pe(e1, env);
				var v1s = isStatic(v1, env);
				var v2 = pe(e2, env);
				var v2s = isStatic(v2, env);
				var e = And(v1, v2, pos);
				if (v1s && v2s) {
					return eval(e, env);
				} else if (v1s || v2s) {
					var staticValue = FlowUtil.getBool(v1s ? v1 : v2);
					var otherValue = v1s ? v2 : v1;					
					if (staticValue == false) {
						if (v1s) {
							// (false && x) == false;
							return ConstantBool(false, pos);
						} else {
							if (hasSideeffects(otherValue, env)) {
								// We have to preserve the side-effects
								// (sideeffect && false) == (sideeffect && false)
								return e;
							} else {
								// If x is side-effect free, we can simplify to false.
								// (x && false) == false
								return ConstantBool(false, pos);
							}
						}
					} else {
						// (true && x) == x
						// (x && true) == x
						return otherValue;
					}
				} else {
					return e;
				}
			}
			case Or(e1, e2, pos): {
				var v1 = pe(e1, env);
				var v1s = isStatic(v1, env);
				var v2 = pe(e2, env);
				var v2s = isStatic(v2, env);
				var e = Or(v1, v2, pos);
				if (v1s && v2s) {
					return eval(e, env);
				} else if (v1s || v2s) {
					var staticValue = FlowUtil.getBool(v1s ? v1 : v2);
					var otherValue = v1s ? v2 : v1;					
					if (staticValue == false) {
						// (false || x) == x
						// (x || false) == x
						return otherValue;
					} else {
						if (v1s) {
							// (true || x) == true;
							return ConstantBool(true, pos);
						} else {
							if (hasSideeffects(otherValue, env)) {
								// (sideeffect() || true) == (sideeffect() || true)
								return e;
							} else {
								// Without side-effects, (x || true) == true
								return ConstantBool(true, pos);
							}
						}
					}
				} else {
					return e;
				}
			}
			case SimpleSwitch(e0, cases, pos): return pelet(code, null, null, env);
			case Switch(e0, type, cases, pos):
				trace('pe: switch was not aform.converted');
				var v = pe(e0, env);
				var v0 = deep(v, env);
				switch (v0) {
					case ConstantStruct(sn, es, p):
						for (c in cases) {
							if (c.structname == sn) {
								if (debug > 1) tr('(optimising switch ' + pp(code) + ' where ' + pp(e0) + ' is ' + pp(v0) + ':');
								var fields = FlowUtil.fieldNames(structs.get(sn).type);
								var tmp = newtmp1('schwtch', env);
								var t = VarRef(tmp, pos);
								var formals = new FlowArray();
								formals.push(tmp);
								var actuals = new FlowArray();
								actuals.push(v);
								for (i in 0...c.args.length) {
									formals.push(c.args[i]);
									var a = es[i];
									actuals.push(switch (a) {
													case VarRef(x, p): a;
													default: Field(t, fields[i], pos);});
								}
								//tr('before unfold actuals=' + actuals.join(',') + '  ');
								var u = unfold(formals, actuals, c.body, pos, env, new Environment());
								u = pe(u, env);
								if (debug > 1) tr('to: ' + pp(u) + ')');
								return u;
							}
						}
						for (c in cases) {
							if (c.structname == 'default') {
								return pe(c.body, env);
							}
						}
						impossible('Case missing for ' + pp(v0) + ' in this switch: ' + pp(code));
					default:
				}
				var nc = new FlowArray();
				//trace('      pe switch ' + pos.f + ': ' + pos.l);
				for (c in cases) {
					var o2 = envForVars(c.args, env, pos);
					//trace('          pe case '  + c.structname);
					var code = pe(c.body, o2);
					nc.push({structname: c.structname, args : c.args, used_args: c.used_args, body : code});
 				}
				return Switch(v, type, nc, pos);
			case Native(name, io, args, result, defbody, pos):
				if (defbody == null) return code;
				else return Native(name, io, args, result, pe0(defbody, env), pos);
			case NativeClosure(nargs, fn, pos): impossible('nativeclosure occurrence'); return null;
			case StackSlot(q0, q1, q2): return code;
		}
	}

	function pelet(e1 : Flow, x : String, e2 : Flow, o : OptEnv) : Flow {
		var me = this;
		var wrap = function (u1) {return if (x != null) {
			//tr(Assert.callStackToString(haxe.CallStack.callStack()));
			//tr('wrap ulet(' + x + '===' + pp(u1) + ' in ' + pp(e2) + ')');
			me.ulet(x, null, u1, e2, dummypos, o);
		} else u1;}
		switch (e1) {
			default: impossible('pelet'); return null;
			case If(e0, et, ef, p):
				var v0 = pe(e0, o);
				var w0 = deep(v0, o);
				return switch (w0) {
							case ConstantBool(b, pos):
								if (x != null) pe(aformletFresh(x, null, if (b) et else ef, e2, dummypos), o);
								else pe(if (b) et else ef, o);
							case Not(ne, pos):
								pelet(If(ne, ef, et, p), x, e2, o);
							default: {
								var vt = pe(et, o);
								var vf = pe(ef, o);
								var wt = deep(vt, o);
								var wf = deep(vf, o);
								if (pp(wt) == pp(wf)) {
									// if they look the same, are they the samme (?!).  This is not just a nice optimisation, without it
									// conditions in ifs are not evaluated aggressively enough: assume s is statically -1 and d dynamic:
									//     if (d and s > 0) substring("foo", s)
									// the dynamic expression will prevent the statically false expression from being taken into account, so pe
									// will evaluate substring("foo", -1), crashing.  Shortcircuit implementation turns it into
									//     if (if (d) s > 0 else false) substring("foo", -1), i.e., 
									//     if (if (d) false else false) substring("foo", -1).  With this code, that turns into:
									//     d; let x = false; in if (x) substring("foo", -1)
									if (debug > 1) tr("driving both if brances to the same: " + pp(wt));
									Sequence(FlowArrayUtil.two(v0, wrap(vt)), p);
								} else {
									wrap(If(v0, vt, vf, p));
								}
							}
				};
				
			case SimpleSwitch(e0, cases, pos):
				var v = pe(e0, o);
				var v0 = deep(v, o);
				return switch (v0) {
					case ConstantStruct(sn, es, p):
						var c = FlowUtil.findSimpleCase(cases, sn);
						if (c == null) {
							impossible('Case missing for ' + pp(v0) + ' in this simple switch: ' + pp(e1));
						}
						if (x != null) pe(aformletFresh(x, null, c.body, e2, pos), o) else pe(c.body, o);
					default:
						var nc = new FlowArray();
						//tr('      pe switch ' + pos.f + ': ' + pos.l);
						for (c in cases) {
							// if it is a switch on a var, we know in each case what that
							// var is (partially), e.g., in switch (o) {Some(v): e1;
							// None(): e2}, we know in e1 that o has the form
							// Some(<dynamic>), &c.
							var switchOnVar = null;
							if (c.structname != 'default') {
								switch (e0) {
									case VarRef(x, p): switchOnVar = x;
									default:
								}
								switch (v) {
									case VarRef(x, p): switchOnVar = x;
									default:
								}
							}
							var body = c.body;
							var ocase = o;
							if (switchOnVar != null) {
								var st = structs.get(c.structname);
								var fields = FlowUtil.fieldNames(st.type);
								var partiallyStatic = ConstantStruct(
									c.structname,
									FlowUtil.map(fields, function (x) {return SyntaxError('dynamic', dummypos);}),
									dummypos);
								ocase = o.setLocal(switchOnVar, partiallyStatic);
							}

							nc.push({structname: c.structname, body: pe(body, ocase)});
						}
						wrap(SimpleSwitch(v, nc, pos));
				};
				
			case Call(e0, es, pos):
				var v0 = pe(e0, o);
				var w0 = deep(v0, o);
				var vs = pes(es, o);
				var ws = deeps(vs, o);
				// for dynamic calls, if the caller was just a variable, use that rather than the function unfolded
				var nounfold = function () {
					return wrap(Call(if (me.isVarRef(e0)) e0 else v0, vs, pos));
				}
				var maybeunfold = function (formals, body, pos1 : Position, freevars) {
					// ensure termination by not unfolding something we are already
					// unfolding.  Both caller & callee must be the same, i.e., unique id
					// is position of call + position of callee
					// No, that is wrong! For recursion check to work, only the position of
					// the lambda is what is important. Otherwise will each recursive call always
					// be inlined, since the position of the first call to the recursive function
					// OUTSIDE the fucntion is also inlined, along with each recursive call INSIDE
					// the function.

					// TODO: Now, with this change, no recursion is resolved. To fix this, we should 
					// check whether a call is completely static, and the body of the lambda side effect 
					// free and without references in or out. 
					// In that case, it does NOT matter that it is recursive (or that it uses refs internally): 
					// We should just call it with the interpreter and get the return value out!

					var id = pos1.f + pos1.l + ':' + pos1.s /*+ ' ' + pos.f + pos.l + ':' + pos.s*/;
					return 
						if (me.isUnfoldable(e1, w0, ws, pos, id, body, o)) {
							if (debug > 1) tr('inlining call: ' + pp(e1) + ':');
							o.unfolding.set(id, true);
							var r = me.unfold(formals, vs, body, pos1, o, freevars);
							// ensure after unfolding & before evaluating that the unfolded code is still in aform
							if (x != null) {
								if (e2 == null) impossible('non-null x, but null e2');
								r = me.aformlet(x, null, r, Multiply(SyntaxError(id, dummypos), e2, dummypos), dummypos);
								// Multiply(SyntaxError(id), ___) is a marker to tell pe
								// where we should stop considering id being unfolded (so
								// pe(Multiply(SyntaxError(id), ___) ) will do:
								// o.unfolding.remove(id).  Without it, the 2nd floor in
								// floor(x)+floor(y) would not be unfolded, because it
								// would think it was still unfolding the first floor...
							}
							if (debug > 1 || debugrename > 1) depth++;
							r = me.pe(r, o);
							if (debug > 1 || debugrename > 1) depth--;
							o.unfolding.remove(id);
							if (debug > 1) tr('       pe of unfold call is: ' + pp(r) + ')');
							r;
						} else {
							if (debug > 1) tr('   DO NOT UNFOLD: ' + pp(e1));
							nounfold();
						}
				}
				return switch (w0) {
				case Closure(lambda, freevars, pos0):
					switch (lambda) {
						case Lambda(formals, type, body, _, pos1):
							maybeunfold(formals, body, pos1, freevars);
						default: impossible('no Lambda in Closure');
					}
				case Native(name, io, args, result, defbody, pos0):
					if (! io && allStatic(ws, o) && defbody == null) {
						/*
						tr(' unfolding non-io native call: ' + pp(e1) + ' (which is: ' + pp(w0) + ' applied to ');
						for (wi in ws) {
							tr('    ' + pp(wi));
						}
						tr(')');
						*/
						wrap(eval(noclosure(Call(w0, ws, pos)), o));
					} else {
						//tr('   no unfold of native call ' + pp(e1));
						nounfold();
					}
				case Lambda(formals, type, body, _, pos1):
					maybeunfold(formals, body, pos1, null);
					//case Let(_, _, _, _, _): impossible('not in aform in call: ' + pp(e1) + ' gives: ' + pp(w0) + ', ' + pos);
					//case Sequence(_, _): impossible('not in aform in call: ' + pp(e1) + ' gives: ' + pp(w0) + ', ' + pos);
					// see todo by Field.  the same applies here
				default:
					// what weird stuff here causes no unfolding?
					//tr('   no unfold of call, because caller is ' + pp(w0));
					nounfold();
				}
		}
	}
	
	function pes(es : FlowArray<Flow>, env : OptEnv) : FlowArray<Flow> {
		var vs = new FlowArray();
		for (v in es) {
			vs.push(pe(v, env));
		}
		return vs;
	}

	function deeps(vs : FlowArray<Flow>, o) {
		var ws = new FlowArray();
		for (v in vs) {
			ws.push(deep(v, o));
		}
		return ws;
	}		
	
	function monop(e1, env : OptEnv, op : Flow -> Flow) : Flow {
		var v1 = pe(e1, env);
		var w1 = deep(v1, env);
		return if (isStatic(w1, env)) eval(op(w1), env) else op(v1);
	}
	
	function binop(e1, e2, env : OptEnv, op : Flow -> Flow -> Flow) : Flow {
		var v1 = pe(e1, env);
		var w1 = deep(v1, env);
		var v2 = pe(e2, env);
		var w2 = deep(v2, env);
		return if (isStatic(w1, env) && isStatic(w2, env)) {
			var r = op(w1, w2);
			try {
				eval(r, env);
			} catch (E : Dynamic) {
				// happens (seldomly) when speculative code evaluation causes, e.g., array
				// indexing out of bounds.  I have only seen it in some code where it
				// actually seems like it could also go wrong at runtime...  Anyway,
				// handle by staying dynamic instead of static
				r;
			}} else op(v1, v2);
	}

	// lookup0 returns null if x not found
	function lookup0(x : String, o : OptEnv) : Flow {
		var v = o.getLocal(x);
		return if (v != null) {
			v;
		} else {
			v = toplevel.get(x);
			if (v != null) {
				var u = done.get(x);
				if (u == null) {
					switch (v) {
						case Lambda(_, _, _, _, _):
						case Native(_, _, _, _, _, _):
						default:
							trace(x + ' is in toplevel but not in done: ' + v);
					}
					var a = aformed.get(x);
					if (a == null) {
						a = convert(v);
						set(aformed, x, a);
					};
					a;
				} else {
					u;			// totodo: here you return something that has been noclosured! we should return the pe'ed thing in aform
				}
			} else {
				null;
			}
		}
	}

	// throw if x not found
	function lookup(x : String, o : OptEnv) : Flow {
		if (x == 'debugopt') {
			debug = 2;
			// debugrename = 2;
			return ConstantString(x, dummypos);
		} else if (x == 'enddebugopt') {
			debug = 0;
			return ConstantString(x, dummypos);
		}
		var v = lookup0(x, o);
		if (v == null) {
			var sigma = structs.get(x);
			impossible(if (sigma != null) 'struct outside call! ' + x
					   else 'not found in optimiser environment: ' + x);
		}
		return v;
	}

	// peVarRef() = optimise the variable reference.  If it is dynamic variable, return
	// code to reference the variable.  If it is a static value, return that.  If it
	// refers to another variable, optimise that variable.  This will optimise let j=i+i;
	// z=a; a=j; b=z in a+b+a to let j=i+i in j+a+j.
	function peVarRef(x : String, p : Position, o : OptEnv) : Flow {
		var v = lookup(x, o);
		return if (isAtomic(v) || isVarRef(v)) v else VarRef(x, p);
  	}
	
	function deep(v : Flow, o : OptEnv) : Flow {
		return switch (v) {
			case VarRef(x, px): deepPeVarRef(x, v, o);
			default: v;
		};
	}
	
	function deepPeVarRef(x : String, orig, o : OptEnv) : Flow {
		var v = lookup(x, o);
		return switch (v) {
			case SyntaxError(s, p):
				if (s == 'dynamic') orig else impossible('deepPeVarRef SyntaxError'); 
			case VarRef(y, p):
				if (x == y) {
					// x maps to x in the environment; this means x is dynamic
					v;
				} else {
					// x maps to another variable, i.e., we have something like let x = y in ..
					// so keep following
					deepPeVarRef(y, orig, o);
				}
			default:
				v;
		}
	}
	
	function eval(e : Flow, o : OptEnv) : Flow {
		return interpreterhack.run(e);
	}	

	// Use SyntaxError('dynamic') as a marker for stuff that is dynamic inside partially
	// static structes, e.g., ConstantStruct("Some", [SyntaxError('dynamic')]) means
	// partially static data, Some applied to something dynamic.
	function isDynamic(e : Flow) : Bool {
		return switch (e) {
			case SyntaxError(s, p): s == 'dynamic';
			default: false;
		}
	}
	
	function isUnfoldable(call, w0, ws : FlowArray<Flow>, pos : Position, id : String, body, o : OptEnv) : Bool {
		var sizeEst = FlowUtil.size(body); // only an estimate since there may be reductions but also more unfolding
		var staticArgs = allStatic(ws, o);
		var recursive = o.unfolding.get(id) != null;
		if (recursive) {
			return false;  // I tried, there is no point in allowing recursive unfolding
						   // in the special case that all arguments are 100% static
		}
		return if (ws.length > 0 && staticArgs) {
			if (debug > 1) tr('ss unfold ' + ppn(call) + ' ' + sizeEst + '  (=' + ppn(Call(w0, ws,  pos)) + ')');
			if (recursive) tr('whoa this is recursive:  ss unfold ' + ppn(call) + ' ' + sizeEst + '  (=' + ppn(Call(w0, ws,  pos)) + ')');
			true;
		} else if (hasStatic(ws, o) && sizeEst < 4 * inlineLimit) {
			if (debug > 1) tr('sd unfold ' + ppn(call) + ' ' + sizeEst + '  (=' + ppn(Call(w0, ws,  pos)) + ')');
			true;
		} else if (sizeEst < inlineLimit) {
			if (debug > 1) tr('d< unfold ' + ppn(call) + ' ' + sizeEst + '  (=' + ppn(Call(w0, ws,  pos)) + ')');
			true;
		} else {
			false;
		};
	}
	
	function unfold(formals : FlowArray<String>, actuals : FlowArray<Flow>, body : Flow,
						  pos : Position, o : OptEnv, freevars : Environment) : Flow {
		if (debug > 1) tr(' Unfold ' + pp(body) + '(...)');
		if (formals.length != actuals.length) impossible('formals.length != actuals.length');
		// we may need to rename variables in the function as part of unfolding it
		var renamehash = new Map();
		var me = this;
		var doRename= function (y : String) {
			var t = me.newtmp1(y, o);
			renamehash.set(y, t);
			if (debug > 1) tr('  rename ' + y + ' to ' + t);
		}
		for (y in formals) {
			doRename(y);
		}
		if (freevars != null) {
			for (y in freevars.variables.keys()) {
				doRename(y);
			}
		}

		if (debug > 2) tr('    [rename:  ' + pp(body));
		body = rename(body, renamehash);
		// only rename(body), not renameFreevars(freevars) because we rename the
		// freevars themselves, not the expressions they are bound to!
		if (debug > 2) tr('     to:      ' + pp(body) + ']');
		
		var e = body;
		// add a let for each free variable
		if (freevars != null) {
			for (y in freevars.variables.keys()) {
				var ey = freevars.variables.get(y);
				e = aformlet(renameVar(y, renamehash), null, ey, e, pos);
			}
		}

		// add a let for each argument
		var n = formals.length;
		for (i in 0...n) {
			var j = n - i - 1; // j in {n-1, ..., 0}
			e = aformlet(renameVar(formals[j], renamehash), null, actuals[j], e, pos);
		}
		if (debug > 1) tr(' To: ' + pp(e) + ')(');
		// since all operations to e have been with aformlet, e is still in aform
		return e;
	}
	
	function aformlet(x, sigma, e1, u2, p : Position) : Flow {
		return aform.Lpublic(e1, Destination(x, sigma, function (t) {return u2;}));
	}
	
	function aformletFresh(x, sigma, e1, u2, p : Position) : Flow {
		return aform.Lfresh(e1, Destination(x, sigma, function (t) {return u2;}), true);
	}

	function convert(e) {
		var r = aform.convertFresh(e, true);
		/*
		var s = '(convert: ' + pp(e) + '\n to aform: ' + pp(r) + ')';
		if (s.indexOf('scructname') != -1) {
			trace(s);
		}
		*/
		return r;
	}
	
	public function newtmp1(suggestion : String, o : OptEnv) : String {
		var tmp = newtmp0(suggestion);
		if (lookup0(tmp, o) != null) {
			impossible('newtmp nonunique ' + tmp + ' for suggestion ' + suggestion);
		}
		return tmp;
	}

	public function newtmp0(suggestion : String) : String {
		var s = nodollar(suggestion);
		var n = tmps.get(s);
		if (n == null) {
			n = 0;
		}
		var tmp = s + '$' + n;
		n++;
		tmps.set(s, n);
		return tmp;
	}

	static public function nodollar(x : String) : String {
		return x.split('$')[0];
	}
	
	// Optionally wrap a let around an expression if needed.  Notice v1 must be pe'ed
	// already and in "A normal form" flow.
	function ulet(x : String, sigma, v1 : Flow, e2 : Flow, p : Position, o : OptEnv) : Flow {
		// totodo: need to check that v1 has no side effects, otherwise we cannot inline
		// it, duplicate it, or omit it.  If it is pure, we can do all those things
		if (e2 == null) impossible('null scope in let - should not happen, we would have had a crash in Aform.L()');
		var me = this;
		return mayberename(x, e2, o, function (x, e2) {
		
		var o2 = o.setLocal(x, v1);
		var v2 = me.pe(e2, o2);

		var v = me.maybelet(x, v1, v2, p, o2);
		return v;});
	}

	function mayberename(x, e2, o, acceptor) {
		if (lookup0(x, o) != null) {
			var t = newtmp1(x, o);
			var h = new Map();
			h.set(x, t);
			e2 = rename(e2, h);
			if (debugrename > 1) tr('let-bound ' + x + ' renamed to ' + t + '   giving:  ' + pp(e2));
			x = t;
		};
		return acceptor(x, e2);
	}

	function maybelet(x, v1, v2, p, o) : Flow {
		var n = varOccurrences(x, v2);
		var me = this;
		var r = function () : Flow {
			return me.aform.Lpublic(v1, Destination(x, null, function (t) {return v2;}));
		};
		
		return (if (n == 0) if (me.hasSideeffects(v1, o)) Sequence(FlowArrayUtil.two(v1, v2), p) else v2;
				else if (n == 1 && ! hasSideeffects(v1, o)) r()
					 // TODO: Consider to instantiate x in v2 here! This hits 1700 times in overviewtest alone.
					 // If the code occurs outside a loop, then it most likely pays to inline it.
				else r());
	}
	
	// handle the pe(Let(...)) case, but without using recursion if there are many nested Lets.
	function wlet(x : String, sigma, e1 : Flow, e2 : Flow, p : Position, o : OptEnv) : Flow {
		var v = null;
		var lets = new FlowArray();
		while (true) {
		// after pe of e1 in a let, if the result, say, u1, is in aform, the let
		// may no longer be in aform, so we need explicitly to convert the let
		// back to aform.  Then call ulet() to deal with the aformed let.  This
		// may cause infinite loops (in somewhat rare cases), so we need infinite
		// unfolding prevention.  The id must be without the $ in generated tmps,
		// otherwise we can unfold indefinitely renaming the tmp by increasing the
		// number after the $.
		
		// check for stuff that may cause unfolding in e1; if e1 is expanded, this
		// let will no longer be in aform.  Unfolding may occur only in calls:
			if (mayGiveNonAform(e1)) {
				v = pelet(e1, x, e2, o);
				break;
			}
			var v1 = pe(e1, o);
			//tr('ulet(' + x + '===' + pp(u1) + ' in ' + pp(e2) + ')');
		
			// totodo: need to check that v1 has no side effects, otherwise we cannot inline
			// it, duplicate it, or omit it.  If it is pure, we can do all those things
			if (e2 == null) impossible('null scope in let - should not happen, we would have had a crash in Aform.L()');
			
			if (lookup0(x, o) != null) {
				var t = newtmp1(x, o);
				var h = new Map();
				h.set(x, t);
				e2 = rename(e2, h);			
				if (debugrename > 1) tr('let-bound ' + x + ' renamed to ' + t + '   giving:  ' + pp(e2));
				x = t;
			}
		
			var oldo = o;
			o = o.setLocal(x, v1);
			lets.unshift({x: x, v1: v1, oldo: oldo});

			switch (e2) {
				default:
					v = pe(e2, o);
					break;
				case Let(xx, ssigma, ee1, ee2, pp):
					x = xx;
					sigma = ssigma;
					e1 = ee1;
					e2 = ee2;
			}
		}
		// v contains the body of the lets
		for (let in lets) {
			v = maybelet(let.x, let.v1, v, p, o);
			o = let.oldo;
		}
		return v;
	}

	function mayGiveNonAform(e1) {
		return switch (e1) {
			case Call(_, _, _): true;
				//case Switch(_, _, _): true;
			case SimpleSwitch(_, _, _): true;
			case If(_, _, _, _): true;
			default: false;
		}
	}
	
	static function rename(e : Flow, f : Map<String,String>) : Flow {
		return switch (e) {
			case SyntaxError(s, pos): e;
			case ConstantVoid(pos): e;
			case ConstantString(value, pos): e;
			case ConstantDouble(value, pos): e;
			case ConstantBool(value, pos): e;
			case ConstantI32(value, pos): e;
			case ConstantNative(value, pos): e;
			case ConstantArray(values, pos): Flow.ConstantArray(renames(values, f), pos);
			case ConstantStruct(name, args, pos): Flow.ConstantStruct(name, renames(args, f), pos);
			case ArrayGet(array, index, pos): ArrayGet(rename(array, f), rename(index, f), pos);
			case VarRef(x, pos):
				var t = f.get(x);
				if (t != null) VarRef(t, pos) else e;
			case Field(call, name, pos): Field(rename(call, f), name, pos);
			case RefTo(value, pos): RefTo(rename(value, f), pos);
			case Pointer(index, pos): e;
			case Deref(pointer, pos): Deref(rename(pointer, f), pos);
			case SetRef(pointer, value, pos): SetRef(rename(pointer, f), rename(value, f), pos);
			case SetMutable(pointer, field, value, pos): SetMutable(rename(pointer, f), field, rename(value, f), pos);
			case Cast(value, fromtype, totype, pos): Cast(rename(value, f), fromtype, totype, pos);
			case Let(x, sigma, e1, e2, pos):
				// do not rename occurrences of x within the scope, e2.  If there are no
				// more renames left in f, no need to even traverse e2.
				Let(x, sigma, rename(e1, f), renameInScope(FlowArrayUtil.one(x), e2, f), pos);
			case Lambda(xs, type, body, _, pos):
				FlowUtil.lambda(xs, type, renameInScope(xs, body, f), pos);
			case Closure(body, freevars, pos):
				Closure(body, renameFreevars(freevars, f), pos);
			case Call(e0, es, pos): Call(rename(e0, f), renames(es, f), pos);
			case Sequence(es, pos): Sequence(renames(es, f), pos);
			case If(e0, e1, e2, pos): If(rename(e0, f), rename(e1, f), rename(e2, f), pos);
			case Not(e0, pos): Not(rename(e0, f), pos);
			case Negate(e0, pos): Negate(rename(e0, f), pos);
			case Multiply(e1, e2, pos): {
				if (false) {
					switch (e1) {
					case SyntaxError(er, p): 
						// We stop renaming here;
						e;
					default: Multiply(rename(e1, f), rename(e2, f), pos);
					}
				} else {
					Multiply(rename(e1, f), rename(e2, f), pos);
				}
			}
			case Divide(e1, e2, pos): Divide(rename(e1, f), rename(e2, f), pos);
			case Modulo(e1, e2, pos): Modulo(rename(e1, f), rename(e2, f), pos);
			case Plus(e1, e2, pos): Plus(rename(e1, f), rename(e2, f), pos);
			case Minus(e1, e2, pos): Minus(rename(e1, f), rename(e2, f), pos);
			case Equal(e1, e2, pos): Equal(rename(e1, f), rename(e2, f), pos);
			case NotEqual(e1, e2, pos): NotEqual(rename(e1, f), rename(e2, f), pos);
			case LessThan(e1, e2, pos): LessThan(rename(e1, f), rename(e2, f), pos);
			case LessEqual(e1, e2, pos): LessEqual(rename(e1, f), rename(e2, f), pos);
			case GreaterThan(e1, e2, pos): GreaterThan(rename(e1, f), rename(e2, f), pos);
			case GreaterEqual(e1, e2, pos): GreaterEqual(rename(e1, f), rename(e2, f), pos);
			case And(e1, e2, pos): And(rename(e1, f), rename(e2, f), pos);
			case Or(e1, e2, pos): Or(rename(e1, f), rename(e2, f), pos);
			case Switch(value, type, cases, pos):
				var v = rename(value, f);
				var nc = new FlowArray();
				for (c in cases) {
					nc.push({structname: c.structname, args: c.args, used_args: c.used_args, body: renameInScope(c.args, c.body, f)});
				}
				Switch(v, type, nc, pos);
			case SimpleSwitch(value, cases, pos):
				var v = rename(value, f);
				var nc = new FlowArray();
				for (c in cases) {
					nc.push({structname: c.structname, body: rename(c.body, f)});
				}
				SimpleSwitch(v, nc, pos);
			case Native(name, io, args, result, defbody, pos):
				if (defbody == null) e
				else Native(name, io, args, result, rename(defbody, f), pos);
			case NativeClosure(nargs, fn, pos): e;
			case StackSlot(q0, q1, q2): e;
		}
	}

	static function renames(es : FlowArray<Flow>, f : Map<String,String>) : FlowArray<Flow> {
		var rs = new FlowArray();
		for (e in es) {
			rs.push(rename(e, f));
		}
		return rs;
	}

	static function renameVar(x : String, f : Map<String,String>) : String {
		var y = f.get(x);
		return if (y == null) x else y;
	}
	
	// Rename, but do not rename occurrences of newly bound variables x within their scope
	// e.  If, after removing the newly bound varialbes, there are no more renames left in
	// f, no need to even traverse e.
	static function renameInScope(xs : FlowArray<String>, e : Flow, f : Map<String,String>) : Flow {
		return (if (e == null) null
				else if (! existsString(xs, function (x) {return f.exists(x);})) rename(e, f)
				else {
					var fwithoutxs = new Map();
					var something = false;
					for (y in f.keys()) {
						if (! FlowUtil.member(y, xs)) {
							fwithoutxs.set(y, f.get(y));
							something = true;
						}
					}
					if (something) rename(e, fwithoutxs) else e;
				});
	}

	static function renameFreevars(freevars : Environment, f : Map<String,String>) : Environment {
		var r = new Environment();
		r.variables = FlowUtil.mapHash(freevars.variables, function (e) {return rename(e, f);});
		return r;
	}
	
	// convert a flow function with free variables to a closed function, i.e., a closure
	// with an environment defining the free variables.
	function close(lambda : Flow, o : OptEnv) : Flow {
		var p = FlowUtil.getPosition(lambda);
		var freevars = fv(lambda, o);
		for (y in freevars.variables.keys()) {
			var r = peVarRef(y, p, o);
			freevars.define(y, r);
			// totodo: is this good enough? what if peVarRef(y, p, o) itself contains free
			// variables!?  It probably does not work so, so in the case where the closure
			// is not called immediately, I think we need to generate residual code to
			// evaluate the free variables.
		}
		if (debug > 1) tr('close(' + pp(lambda) + ') is: ' + pp(Closure(lambda, freevars, p)));
		return Closure(lambda, freevars, p);
	}

	// fv(e, o) = find the free variables of e with respect to o (i.e., if x is not
	// defined in o, ignore it, do not consider it a free variable).  Do not consider a
	// toplevel variables free, even though it occurs free in e.
	function fv(e : Flow, o : OptEnv) : Environment {
		var freevars = new Environment();
		capture(e, freevars, o);
		return freevars;
	}
	
	function capture(code : Flow, fv : Environment, o : OptEnv) : Void {
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
				capture(a, fv, o);
			}
		case ConstantStruct(name, values, pos):
			for (a in values) {
				capture(a, fv, o);
			}
		case ConstantNative(value, pos): 0;
		case ArrayGet(array, index, pos):
			capture(array, fv, o);
			capture(index, fv, o);
		case VarRef(name, pos):
			var v : Flow = o.getLocal(name);
			if (v != null) {
				fv.define(name, v);
			}
		case Field(call, name, pos):
			capture(call, fv, o);
		case RefTo(value, pos):
			capture(value, fv, o);
		case Pointer(index, pos):
		case Deref(pointer, pos):
			capture(pointer, fv, o);
		case SetRef(pointer, value, pos):
			capture(pointer, fv, o);
			capture(value, fv, o);
		case SetMutable(pointer, field, value, pos):
			capture(pointer, fv, o);
			capture(value, fv, o);
		case Cast(value, fromtype, totype, pos):
			capture(value, fv, o);

		case Let(name, sigma, value, scope, pos):
			capture(scope, fv, o);
			fv.revoke(name);
			// If name appears in the value, it is free
			capture(value, fv, o);

		case Lambda(arguments, type, body, _, pos):
			capture(body, fv, o);
			for (a in arguments) {
				fv.revoke(a);
			}

		case Closure(body, environment, pos):
			capture(body, fv, o);

		case Call(closure, arguments, pos):
			capture(closure, fv, o);
			for (a in arguments) {
				capture(a, fv, o);
			}

		case Sequence(statements, pos):
			for (a in statements) {
				capture(a, fv, o);
			}

		case If(condition, then, elseExp, pos):
			capture(condition, fv, o);
			capture(then, fv, o);
			capture(elseExp, fv, o);
		case Not(e, pos): capture(e, fv, o);
		case Negate(e, pos): capture(e, fv, o);
		case Multiply(e1, e2, pos):
			capture(e1, fv, o);
			capture(e2, fv, o);
		case Divide(e1, e2, pos):
			capture(e1, fv, o);
			capture(e2, fv, o);
		case Modulo(e1, e2, pos):
			capture(e1, fv, o);
			capture(e2, fv, o);
		case Plus(e1, e2, pos):
			capture(e1, fv, o);
			capture(e2, fv, o);
		case Minus(e1, e2, pos):
			capture(e1, fv, o);
			capture(e2, fv, o);
		case Equal(e1, e2, pos):
			capture(e1, fv, o);
			capture(e2, fv, o);
		case NotEqual(e1, e2, pos):
			capture(e1, fv, o);
			capture(e2, fv, o);
		case LessThan(e1, e2, pos):
			capture(e1, fv, o);
			capture(e2, fv, o);
		case LessEqual(e1, e2, pos):
			capture(e1, fv, o);
			capture(e2, fv, o);
		case GreaterThan(e1, e2, pos):
			capture(e1, fv, o);
			capture(e2, fv, o);
		case GreaterEqual(e1, e2, pos):
			capture(e1, fv, o);
			capture(e2, fv, o);
		case And(e1, e2, pos):
			capture(e1, fv, o);
			capture(e2, fv, o);
		case Or(e1, e2, pos):
			capture(e1, fv, o);
			capture(e2, fv, o);
		case Switch(value, type, cases, pos) :
			capture(value, fv, o);
			for (c in cases) {
				//TODO: This is wrong with
				// x = something;
				// switch() {
				// S1(x): x refers to local variable
				// S2(): x should refer to closure, not local variable from S1
				// S3(x): x refers to local variable
				// }
				capture(c.body, fv, o);
				// The names in a constructor should not
				// be captured into the environment
				for (a in c.args) {
					fv.revoke(a);
				}
			}
		case SimpleSwitch(value, cases, pos) :
			capture(value, fv, o);
			for (c in cases) {
				capture(c.body, fv, o);
			}
		case Native(name, io, args, result, defbody, pos):
			if (defbody != null) capture(defbody, fv, o);
		case NativeClosure(nargs, fn, pos):
		case StackSlot(q0, q1, q2):
		}
	}

	function varOccurrences(x : String, e : Flow) : Int {
		var n = 0;
		var f = function (e) {}; // forward declaration of f to allow recursion on f
		f = function (e) {
			switch (e) {
				case VarRef(y, p): if (x == y) ++n;
				case Closure(lambda, freevars, p): {
					// explicitly traverse the freevars, as traverseExp() skips that
					// because it assumes they are only values, not code
					var h = freevars.variables;
					for (x in h.keys()) {
						FlowUtil.traverseExp(h.get(x), f);
					}
				}
				default:
			}};
		FlowUtil.traverseExp(e, f);
		return n;
	}

	/*not used
	function envForFunction(formals : FlowArray<String>, actuals : FlowArray<Flow>, env) : Env {
		var o = copyEnv(env);
		for (i in 0...formals.length) {
			o.locals.set(formals[i], actuals[i]);
			//tr("binding " + formals[i] + ' to ' + pp(actuals[i]));
		}
		return o;
	}
	*/

	function envForVars(xs : FlowArray<String>, o : OptEnv, p : Position) : OptEnv {
		for (x in xs) {
			o = o.setLocal(x, VarRef(x, p));
		}
		return o;
	}

	function isVarRef(e : Flow) : Bool {
		return switch (e) {
			case VarRef(x, p): true;
			default: false;
		}
	}
	
	function isStatic(e : Flow, o) : Bool {
		return switch (e) {
			case ConstantVoid(pos): true; // impossible?
			case ConstantString(value, pos): true;
			case ConstantDouble(value, pos): true;
			case ConstantBool(value, pos): true;
			case ConstantI32(value, pos): true;
			case ConstantNative(value, pos): true; // impossible?
			case ConstantArray(values, pos): allStatic(values, o);
			case ConstantStruct(name, args, pos): allStatic(args, o);
			case Closure(lambda, freevars, pos):
				switch (lambda) {
					case Lambda(formals, type, body, _, pos):
						// (=the function has no side effects, i.e., is not io, no refs input or
						// outputs, no free variables (why?), no unsafe function arguments)
						isSafeFunction(body, freevars, o);
					default: impossible('isStatic Closure');
				}
			case Lambda(xs, type, body, _, pos):
				// only occurs when the lambda is a topdec, so there are no freevars, so isSafe(body) is fine:x
				isSafe(body, o);
			//case RefTo(value, pos): true;
			//case Pointer(index, pos): code;
			case Native(name, io, args, result, defbody, pos):
				defbody == null || isStatic(defbody, o);
			case NativeClosure(nargs, fn, pos): impossible('nativeclosure occurrence');
			case StackSlot(q0, q1, q2): impossible('isStatic StackSlot');
			default: false;
		};
	}

	function allStatic(es : FlowArray<Flow>, o : OptEnv) : Bool {
		for (e in es) {
			if (! isStatic(e, o)) {
				return false;
			}
		}
		return true;
	}

	function hasStatic(es : FlowArray<Flow>, o) : Bool {
		for (e in es) {
			if (isStatic(e, o)) {
				return true;
			}
		}
		return false;
	}
	
	function isSafeFunction(body : Flow, freevars : Environment, o) : Bool {
		var nofree = FlowUtil.emptyHash(freevars.variables);
		var safeBody = isSafe(body, o);
		/*
		if (safeBody && ! nofree) {
			tr('FUNCTION IS SAFE, EXCEPT FOR FREE VARS:');
			tr('    body:     ' + pp(body));
			tr('    freevars: ' + freevars.serialize('    '));
		}
		if (safeBody && nofree) {
			tr('SAFE FUNCTION FOUND: ' + pp(body) + '  | ' + freevars.serialize('    ') + '|.');
		}
		*/
		return safeBody && nofree;
	}

	function isSafe(e : Flow, o : OptEnv) : Bool {
		var safe = true;
		var allocatesRef = false;
		var usesRef = false;
		var me = this;
		FlowUtil.traverseExp(e, function (e) {
			switch (e) {
				case VarRef(x, p):
					if (! me.isSafeVar(x, o)) {
						// not safe, because it references a topdec that is not static, so
						// the FlowInterpreter would not be able to evaluate it
						safe = false;
					}
				case RefTo(value, pos): allocatesRef = true;
				case SetRef(pointer, value, pos): usesRef = true;
				case SetMutable(pointer, field, value, pos): usesRef = true;
				case Deref(pointer, pos): usesRef = true;
				case Native(name, io, args, result, defbody, p):
					if (io) {
						safe = false;
					}
				case NativeClosure(args, fn, pos): impossible('isSafe NativeClosure');
				case ConstantNative(value, pos): impossible('isSafe ConstantNative');
				default:
			}
		});
		if (allocatesRef) {
			// todo: check from return type it does not return a ref, else:
			return false;
		}
		if (usesRef) {
			// todo: check it does not input a ref, else:
			return false;
		}
		return safe;
	}
	
	function isSafeVar(x : String, o : OptEnv) : Bool {
		return toplevel.get(x) == null || isStaticTopdec(x, o);
	}
	
	// is the topdec bound to x static?  This function has side effects: Keep a cache of
	// topdecs staticness (1) and also make sure the static topdecs are added to the
	// FlowInterpreter environment (2), so they can really be evaluated.
	function isStaticTopdec(x : String, o : OptEnv) : Bool {
		var b = staticTopdecs.get(x); // (1)
		if (b == null) {
			var e = toplevel.get(x); // we could take it from done here to get a more
								   // efficient version after being pe'ed.
			// Check whether s isStatic, assuming initially that it is (to handle
			// recursive occurrences of x in the body of x)
			staticTopdecs.set(x, true);
			b = isStatic(e, o);
			staticTopdecs.set(x, b);
			if (b) {
				interpreterhack.environment.define(x, eval(e, o));	// (2)
			}
		}
		return b;
	}
	
	// only if e is atomic do we inline it; if it is static but not atomic, we do not
	// inline, because that could lead to building the same complex data structure at
	// every use
	static function isAtomic(e : Flow) : Bool {
		return switch (e) {
			case ConstantVoid(pos): true; // impossible?
			case ConstantString(value, pos): true;
			case ConstantDouble(value, pos): true;
			case ConstantBool(value, pos): true;
			case ConstantI32(value, pos): true;
			case ConstantArray(xs, p): xs.length == 0;
			case ConstantStruct(sn, args, p): args.length == 0;
			default: false;
		};
	}

	// Notice: Can not be used to reorder code, since DeRef and SetRef is not commutable
	function hasSideeffects(e : Flow, env : OptEnv) : Bool {
		var sideeffect = false;
		var me = this;
		FlowUtil.traverseExp2(e, function(e : Flow) {
			switch (e) {
			case SetRef(d, e, p): {
				sideeffect = true;
			}
			case SetMutable(d, f, e, p): {
				sideeffect = true;
			}
			case Call(c, args, p): {
				if (Delet.callHasSideEffects(c, me.toplevel)) {
					sideeffect = true;
				}
			}
			default:
			}
		});
		if (sideeffect && debug > 1) tr(pp(e) + ' has side effect');
		return sideeffect;
	}

	static function forAll(xs : FlowArray<Flow>, predicate : Flow -> Bool) : Bool {
		for (x in xs) {
			if (! predicate(x)) {
				return false;
			}
		}
		return true;
	}

	static function existsFlow(xs : FlowArray<Flow>, predicate : Flow -> Bool) : Bool {
		for (x in xs) {
			if (predicate(x)) {
				return true;
			}
		}
		return false;
	}
	
	static function existsString(xs : FlowArray<String>, predicate : String -> Bool) : Bool {
		for (x in xs) {
			if (predicate(x)) {
				return true;
			}
		}
		return false;
	}

	// Same as .set() except we check no let or sequence gets into the environment,
	// otherwise we will no longer be in aform if we inline something from the
	// environment.  We cannot demand this on toplevel ids, but in reality it that
	// seldomly gives us something not in aform.  See totodo by pe(Field(__)).
	static function set(h : Map<String,Flow>, x : String, e : Flow) : Void {
		if (switch (e) {
			case Let(_, _, _, _, _): true;
			case Sequence(_, _): true;
			default: false;
		}) {
			impossible('set(' + x + ', ' + pp(e) + ') not aform');
		}
		h.set(x, e);
	}
	
	static function impossible(s : String) : Dynamic {
		throw 'impossible: ' + s;
		return null;
	}

	function traceOptimised(p : Program, order : FlowArray<String>) : Void {
		var printProgram = true;
		if (printProgram) {
			for (d in p.userTypeDeclarations) {
				switch (d.type.type) {
					case TStruct(n, a, m): {
						var declaration = Prettyprint.prettyprintType(d.type.type) + ";";
						declaration = StringTools.replace(declaration, "?0", "?");
						declaration = StringTools.replace(declaration, "?1", "?");
						declaration = StringTools.replace(declaration, "?2", "?");
						tr(declaration);
					}
					default:
				}
			}
		}
		for (d in order) {
			var w = done.get(d);
			switch (w) {
				case Native(name, io, args, result, defbody, pos) : {
					// native length : ([?]) -> int = Native.length;
						
					var declaration = '\nnative ' + d + ' : ' + (if (io) 'io ' else '') + '(';
						
					var sep = '';
					for (a in args) {
						declaration += sep + Prettyprint.prettyprintType(a);
						sep = ', ';
					}
					declaration += ') -> ' + Prettyprint.prettyprintType(result) + ' = ' + name + ';';  
						
					// To make it right, we just hack away here
					declaration = StringTools.replace(declaration, "?0", "?");
					declaration = StringTools.replace(declaration, "?1", "?");
					declaration = StringTools.replace(declaration, "?2", "?");

					tr(declaration);

					if (defbody != null) {
						var s = pp(defbody);
						// To make it right, we just hack away here
						s = StringTools.replace(s, "$", "S");
						tr('\n' + d + ' = ' + s + ';');
					}
				}
				default:
					var s = pp(w);
					// To make it right, we just hack away here
					s = StringTools.replace(s, "$", "S");
					tr('\n' + d + ' = ' + s + ';');
			}
		}
	}
	
	static function pp(code : Flow) : String {
		return Prettyprint.prettyprint(code, '');
	}

	static function ppn(code : Flow) : String {
		return StringTools.replace(Prettyprint.prettyprint(code, ''), "\n", " ");
	}

	static var dummypos = {f: '', l: 0, s: 0, e: -1, type: null, type2: null};

	static function tr(s : String) : Void {
		Errors.print(indent() + s);
	}

	public static function indent() : String {
		return FlowUtil.repeat(depth * 2, '  ');
	}

	// debug state
	public static var depth = 0;
	public static var debug : Int = 1;
	public static var debugrename : Int = 1;

	// Global environments defined based on the program
	public var structs : Map<String,TypeScheme>;
	public var toplevel : Map<String,Flow>;
	var interpreterhack : FlowInterpreter;


	// staticTopdecs.get(x): true=the topdec named x is static (in the sense of
	// Optimiser.isStatic); false=it is not; null=x was not processed yet.
	public var staticTopdecs : Map<String,Bool>;

	// list of global variables that are pending to be specialised
	var todoOrder : FlowArray<String>;
	var todoSet : Map<String,Bool>;

	// set of global variables that have been or are currently being optimised
	var done : Map<String,Flow>;

	// topdecs that have already been aformed are in this environment
	var aformed : Map<String,Flow>;

	var aform : Aform;

	// tmps.get('a') == 3 means next free temporary variable starting with a is a$4
	var tmps : Map<String,Int>;

	// command-line option --inline-limit
	static var inlineLimit : Int;

	// for counting the nesting level of a throw of an exception, so we can trace at
	// different expressions levels
	var exceptionCount : Int;
}
