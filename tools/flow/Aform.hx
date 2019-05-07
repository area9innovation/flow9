// (c) 2011 area9 aps.

// Convert a Flow expression to an "A normal form" Flow expression, i.e., with all
// (intermediate) value constructing expressions bound to a temporary variable, e.g.,
// a+b+c -> let t1 = a+b in t1+c

import Flow;
import Position;
import FlowArray;
import Optimiser;
import FlowMap;

// Context is used internally in L.  It is used to tell subexpressions their context.
// Atomic(f) means the context expects an atomic expression, e.g., a constant or a
// variable.  If the subexpression e does not deliver that, a let x = e in ...  is
// inserted.  Destination(t, sigma, f) means the context expects the subexpression to put
// the value in t (which has type sigma).  Discard means the context does not need the
// result of the subexpression.  The subexpression can be culled to only contain side
// effects.  AformExp means the context expects any A normal form flow expression, i.e.,
// an atomic expression or one operator on atomic expressions (i.e., x+y or x+7, but not
// x+y+7).  q is an environment mapping old names to fresh names generated for them, used
// to generate fresh names for let-bound variables.

enum Context {
	Atomic(f: Flow -> Flow);
	Destination(t: String, sigma: Null<TypeScheme>, f: Flow -> Flow);
	Discard;
	AformExp;
}

class Aform {
	public function new (optimiser0 : Optimiser) {
			optimiser = optimiser0;
			count = 0;
	}
	
	public function convert(e : Flow) : Flow {
		return convert0(e, new FlowMap<String>());
	}
	
	function convert0(e : Flow, q : FlowMap<String>) : Flow {
		var r = Lprofiled(e, q, AformExp);
		//trace('Aform.convert ' + pp(e) + ' === ' + pp(r));
		return r;
	}
	
	public function convertFresh(e : Flow, refresh0 : Bool) : Flow {
		refresh = refresh0;
		var r = Lprofiled(e, new FlowMap<String>(), AformExp);
		//trace('Aform.convertFresh ' + pp(e) + ' === ' + pp(r));
		refresh = false;
		return r;
	}
	
	// Use N when you have no natural variable to put the result in, e.g., in e1+e2, there
	// is no variable in which to put e1 & e2, so probably a new temporary is needed.
	// Whatever the case, N will tell you the variable to find the result in by applying f
	// to that variable.  If a t is passed to N, N tries to use that as the variable for
	// the result. L is as N, but with a suggestion t from above for a destination
	// variable.  If we need a destination variable but t is null, then we createwe a new
	// temporary.  If L gets a non-null t, then L will guarantee that the result is in t,
	// if necessary inserting a copy ("let t = x in f(t)") (i.e., f is guaranteed to be
	// applied to t, not some other variable).

	// Conventions: Variable f is used for Flow code abstracted over a variable, i.e.,
	// f(x) is Flow code that will access x for the value it needs.  Variable t is used to
	// mean a variable name.  sigma is the type (if any) that is always accompanying the
	// t.

	// As an argument to a function, t==null means "no suggestion for a variable, generate
	// a new temporary if you need".  If a function takes t & sigma & f, it takes them
	// always in that order.  Preferably function arguments are last to avoid more
	// arguments after a long function passed as an argument.
	
	public function Lfresh(e : Flow, c : Context, refresh0 : Bool) : Flow {
		refresh = refresh0;
		var r = Lprofiled(e, new FlowMap<String>(), c);
		refresh = false;
		return r;
	}

	public function Lpublic(e, c) {
		var r = Lprofiled(e, new FlowMap<String>(), c);
		//trace('Aform.L(' + pp(e) + ') === ' + pp(r));
		return r;
	}
	
	private function Lprofiled(e : Flow, q, c : Context) : Flow {
		//Profiler.get().profileStart('L');
		var r = L(e, q, c);
		//Profiler.get().profileEnd('L');
		return r;
	}
	
	private function L(e : Flow, q : FlowMap<String>, c : Context) : Flow {
		return switch (e) {
			case SyntaxError(s, pos): impossible('L: SyntaxError ' + s);
			case ConstantVoid(p): atomic(e, c);
			case ConstantString(s, p): atomic(e, c);
			case ConstantDouble(d, p): atomic(e, c);
			case ConstantBool(b, p): atomic(e, c);
			case ConstantI32(i, p): atomic(e, c);
			case ConstantNative(nat, p): atomic(e, c);
			case ConstantArray(es, p): {
				if (es.length == 0) {
					// Empty arrays are atomic enough!
					atomic(e, c);
				} else {
					Ls(es, q,c, function (vs) { return ConstantArray(vs, p); } );
				}
			}
			case ConstantStruct(sn, es, p): Ls(es, q, c, function (vs) {return Flow.ConstantStruct(sn, vs, p);});
			case ArrayGet(e1, e2, p): L2(e1, e2, q, c, function (v1, v2) {return ArrayGet(v1, v2, p);});
			case VarRef(x, p): {
				if (refresh) {
					var newx = q.get(x);
					if (newx != null) {
						x = newx;
						e = VarRef(newx, p);
					} else {
						//trace('I looked up ' + x + ': not there');
					}
				}
				switch (c) {
					case Atomic(f): f(e);
					case Destination(t, sigma, f): if (x == t) f(e) else Let(t, sigma, e, f(mkvar(t)), p);
					case Discard: e; // totodo: cull the code here to contain only side effects
					case AformExp: e;
				}
			}
			case Field(e0, field, p): L1(e0, q, c, function (v0) {return Field(v0, field, p);});				
			case RefTo(e0, p): L1(e0, q, c, function (v0) {return RefTo(v0, p);});
			case Pointer(index, pos): impossible('L: pointer');
			case Deref(e0, p): L1(e0, q, c, function (v0) {return Deref(v0, p);});
			case SetRef(e1, e2, p): L2(e1, e2, q, c, function (v1, v2) {return SetRef(v1, v2, p);});
			case SetMutable(e1, field, e2, p): L2(e1, e2, q, c, function (v1, v2) {return SetMutable(v1, field, v2, p);});
			case Cast(e0, fromtype, totype, p): L1(e0, q, c, function (v0) {return Cast(v0, fromtype, totype, p);});
			case Let(x, sigma, e1, e2, p):
				if (refresh) {
					var newx = optimiser.newtmp0(x);
					L(e1, q, Destination(newx, sigma, function (t1) {
						return L(e2, q.set(x, newx), c);
					}));
				} else 
				L(e1, q, Destination(x, sigma, function (t1) {
					// here t1 will be x because of the guarantee; if necessary a copy
					// will be inserted, see the case L(VarRef()..) above.
					return L(e2, q, c);}));
                        case Lambda(xs, type, e0, _, p):
				/*
				   would we want to freshen up xs also? perhaps not, since they are not
				   used before the function is unfolded & will be freshened when unfolded
				if (refresh) {
					var ys = new FlowArray();
					for (x in xs) {
						var y = optimiser.newtmp0(x);
						ys.push(y);
						q = q.set(x, y);
					}
					xs = ys;
				}
				*/
				atomic(FlowUtil.lambda(xs, type, L(e0, q, AformExp), p), c);
			case Closure(body, freevars, p): atomic(Closure(convert0(body, q), freevars, p), c);
				// totodo: rename freevars env according too if refresh
			case Call(e0, es, p):
				L(e0, q, Atomic(function (t0) {
					return Ls(es, q, c, function (vs) {
						return Call(t0, vs, p);});}));
			case Sequence(es, p): S(es, p, q, c);
			case If(e0, e1, e2, p):
				// "if" is like an op with one argument only: e0.  e1 & e2 are converted
				// from scratch, we cannot pass the destination variable in to them as its
				// scope would not extend after the "if", so we need to bind it outside
				// the "if".
				L1(e0, q, c, function (v0) {return If(v0, convert0(e1, q), convert0(e2, q), p);});
			case Not(e0, p): L1(e0, q, c, function (v0) {return Not(v0, p);});
			case Negate(e0, p): L1(e0, q, c, function (v0) {return Negate(v0, p);});
			case Multiply(e1, e2, p): L2(e1, e2, q, c, function (v1, v2) {return Multiply(v1, v2, p);});
			case Divide(e1, e2, p): L2(e1, e2, q, c, function (v1, v2) {return Divide(v1, v2, p);});
			case Modulo(e1, e2, p): L2(e1, e2, q, c, function (v1, v2) {return Modulo(v1, v2, p);});
			case Plus(e1, e2, p): L2(e1, e2, q, c, function (v1, v2) {return Plus(v1, v2, p);});
			case Minus(e1, e2, p): L2(e1, e2, q, c, function (v1, v2) {return Minus(v1, v2, p);});
			case Equal(e1, e2, p): L2(e1, e2, q, c, function (v1, v2) {return Equal(v1, v2, p);});
			case NotEqual(e1, e2, p): L2(e1, e2, q, c, function (v1, v2) {return NotEqual(v1, v2, p);});
			case LessThan(e1, e2, p): L2(e1, e2, q, c, function (v1, v2) {return LessThan(v1, v2, p);});
			case LessEqual(e1, e2, p): L2(e1, e2, q, c, function (v1, v2) {return LessEqual(v1, v2, p);});
			case GreaterThan(e1, e2, p): L2(e1, e2, q, c, function (v1, v2) {return GreaterThan(v1, v2, p);});
			case GreaterEqual(e1, e2, p): L2(e1, e2, q, c, function (v1, v2) {return GreaterEqual(v1, v2, p);});
			case And(e1, e2, p): L(If(e1, e2, ConstantBool(false, p), p), q, c);
				//old: wrap(And(convert(e1), convert(e2), p), c);
				// totodo: L2(e1, e2, t, sigma, f, function (v1, v2) {return And(v1, v2, p);});
			case Or(e1, e2, p): L(If(e1, ConstantBool(true, p), e2, p), q, c);
				//old: wrap(Or(convert(e1), convert(e2), p), c);
				// totodo: L2(e1, e2, t, sigma, f, function (v1, v2) {return Or(v1, v2, p);});
			case Switch(e0, type, cases, p):
				// same as with "if"
				L1(e0, q, c, function (v0) {return SimpleSwitch(v0, FlowUtil.map(cases, function (sc) {return convertCase(v0, q, sc);}), p);});
			case SimpleSwitch(e0, cases, p):
				L1(e0, q, c, function (v0) {return SimpleSwitch(v0, FlowUtil.map(cases, function (ca : SimpleCase) {
					return {structname: ca.structname, body: convert0(ca.body, q)};}), p);});
			case Native(name, io, args, result, defbody, p): wrap(e, c);
			case NativeClosure(nargs, fn, p): impossible('L: NativeClosure');
			case StackSlot(q0, q1, q2): impossible('L: StackSlot');
		}
	}

	function S(es : FlowArray<Flow>, p : Position, q : FlowMap<String>, c : Context) : Flow {
		if (es.length == 0) {
			impossible('empty sequence in call');
		}
		var us = S0(0, es, q, c);
		var r = if (us.length == 1) us[0] else Sequence(us, p);
		return r;
	}

	function S0(i : Int, es : FlowArray<Flow>, q, c) : FlowArray<Flow> {
		if (i == Std.int(es.length) - 1) {
			// last in sequence, convert it normally:
			var w = L(es[i], q, c);
			return FlowArrayUtil.one(w);
		} else {
			var w = L(es[i], q, Discard);
			var us = S0(i + 1, es, q, c);
			us.unshift(w);
			return us;
		}
	}
	
	function atomic(e : Flow, c : Context) : Flow {
		return switch (c) {
			case Atomic(f): f(e);
			case Destination(t, sigma, f): Let(t, sigma, e, f(mkvar(t)), dummypos);
			case Discard: e;
			case AformExp: e;
		}
	}

	// L an expression with 1 subexpression
	function L1(e1 : Flow, q, c : Context, op : Flow -> Flow) : Flow {
		return L(e1, q, Atomic(function (t1) {
			return wrap(op(t1), c);}));
	}

	// N an expression with 2 subexpressions
	function L2(e1 : Flow, e2 : Flow, q, c : Context, op : Flow -> Flow -> Flow) : Flow {
		return L(e1, q, Atomic(function (t1) {
			return L(e2, q, Atomic(function (t2) {
				return wrap(op(t1, t2), c);}));}));
	}

	// wrap an already converted non-atomic expression in let if context wants it
	function wrap(u : Flow, c : Context) : Flow {
		return switch (c) {
			case Atomic(f):
				var t = tmp();
				Let(t, null, u, f(mkvar(t)), dummypos);
			case Destination(t, sigma, f):
				Let(t, sigma, u, f(mkvar(t)), dummypos);
			case Discard: u;
			case AformExp: u;
		};
	}
	
	// Like N2, but for an array of subexpressions instead of just 2
	function Ls(es : FlowArray<Flow>, q, c, op : FlowArray<Flow> -> Flow) : Flow {
		var ts = new FlowArray();
		var u = wrap(op(ts), c);
		var n = es.length;
		for (i in 0...n) {
			var j = n - i - 1;
			u = L(es[j], q, Atomic(function (t) {
				ts.unshift(t);
				return u;
			}));
		}
		return u;
	}
	
	// convert all variables bound in the case to let-bound: convertCase("case Some(x):
	// ...") = "case Some: let x = t.value in ...".  switchVar is the variable whose value
	// we switch on.
	function convertCase(switchVar : Flow, q : FlowMap<String>, sc : SwitchCase) : SimpleCase {
		var e = convert0(sc.body, q);
		if (sc.structname != 'default') {
			var structType = optimiser.structs.get(sc.structname).type;
			var fields = switch (structType) {
							case TStruct(sn, args, max): args;
							default: throw 'impossible: convertCase non-struct';
						};
			var pos = FlowUtil.getPosition(sc.body);
			var n = fields.length;
			for (i in 0...n) {
				var j = n - i - 1;	// j in {n-1,...,0}
				var field = fields[j];
				var fieldType = PositionUtil.getValue(field.type);
				var p = PositionUtil.copy(pos);
				p.type = fieldType;
				e = Let(sc.args[j], null,  // we could get the field type & put it here instead of null
						Field(switchVar, field.name, p),
						e, dummypos);
			}
		}
		return {structname: sc.structname, body: e}
	}

	function tmp() : String {
		return optimiser.newtmp0('t');
	}

	var count : Int;
	
	static function mkvar(x : String) : Flow {
		return VarRef(x, dummypos);
	}

	static function impossible(s : String) : Dynamic {
		throw 'impossible: ' + s;
		return null;
	}

	static function pp(code : Flow) : String {
		return Prettyprint.prettyprint(code, '');
	}

	static var dummypos = {f: '', l: 0, s: 0, e: -1, type: null, type2: null};

	// Given initially to allow aform access to global stuff in the program (notably structs)
	var optimiser : Optimiser;

	// If non-null, aform conversion will make fresh names for all locally defined
	// identifiers.  Aform needs it in order to make new variable names.
	var refresh : Bool;
}


