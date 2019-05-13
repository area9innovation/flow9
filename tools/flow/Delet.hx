import Flow;

class Delet {
	function new(topdecs : Map<String,Flow>) {
		deathrow = new Map();
		this.topdecs = topdecs;
	}

	// Mark all lets that have only one or no uses for culling.  Then in the cull phase
	// some of them might still be allowed to remain if side effect interferences prevent
	// them from being inlined.
	function mark(e : Flow, o : Map<String,Int>) : Void {
		switch (e) {
			case SyntaxError(s, pos): impossible('mark: SyntaxError');
			case ConstantVoid(p):
			case ConstantString(s, p): 
			case ConstantDouble(d, p): 
			case ConstantBool(b, p): 
			case ConstantI32(i, p):
			case ConstantNative(nat, p):
			case ConstantArray(es, p): marks(es, o);
			case ConstantStruct(sn, es, p): marks(es, o);
			case ArrayGet(e1, e2, p): mark2(e1, e2, o);
			case VarRef(x, p):
				var n = o.get(x);
				if (n != null) {
					o.set(x, n + 1);
				}
			case Field(e0, field, p): mark(e0, o);
			case RefTo(e0, p): mark(e0, o);
			case Pointer(index, pos): impossible('mark: pointer');
			case Deref(e0, p): mark(e0, o);
			case SetRef(e1, e2, p): mark2(e1, e2, o);
			case SetMutable(e1, field, e2, p): mark2(e1, e2, o);
			case Cast(e0, fromtype, totype, p): mark(e0, o);
			case Let(x, sigma, e1, e2, p):
				mark(e1, o);
				var oldx = o.get(x);
				o.set(x, 0);
				mark(e2, o);
				if (o.get(x) <= 1) {
					deathmark(e);
				}
				if (oldx == null) o.remove(x) else o.set(x, oldx);
                        case Lambda(xs, type, e0, _, p):
				var overridden = new Map();
				for (x in xs) {
					if (o.exists(x)) {
						overridden.set(x, o.get(x));
					}
					o.set(x, 0);
				}
				mark(e0, o);
				revoke(o, xs);
				retract(o, overridden);
			case Closure(body, freevars, p): impossible('Delet: closure');
			case Call(e0, es, p): mark(e0, o); marks(es, o);
			case Sequence(es, p): marks(es, o);
			case If(e0, e1, e2, p): mark(e0, o); mark2(e1, e2, o);
			case Not(e0, p): mark(e0, o); 
			case Negate(e0, p): mark(e0, o); 
			case Multiply(e1, e2, p): mark2(e1, e2, o);
			case Divide(e1, e2, p): mark2(e1, e2, o);
			case Modulo(e1, e2, p): mark2(e1, e2, o);
			case Plus(e1, e2, p): mark2(e1, e2, o);
			case Minus(e1, e2, p): mark2(e1, e2, o);
			case Equal(e1, e2, p): mark2(e1, e2, o);
			case NotEqual(e1, e2, p): mark2(e1, e2, o);
			case LessThan(e1, e2, p): mark2(e1, e2, o);
			case LessEqual(e1, e2, p): mark2(e1, e2, o);
			case GreaterThan(e1, e2, p): mark2(e1, e2, o);
			case GreaterEqual(e1, e2, p): mark2(e1, e2, o);
			case And(e1, e2, p): mark2(e1, e2, o);
			case Or(e1, e2, p): mark2(e1, e2, o);
			case Switch(e0, type, cases, p): impossible('mark: complex switch');
			case SimpleSwitch(e0, cases, p):
				// it is more accurate to count the number of occurrences of x in the
				// branches as the max rather than the sum of the count from the branches;
				// similar with Switch & If.
				mark(e0, o);
				for (c in cases) {
					mark(c.body, o);
				}
			case Native(name, io, args, result, defbody, p): 
			case NativeClosure(nargs, fn, p): impossible('mark: NativeClosure');
			case StackSlot(q0, q1, q2): impossible('mark: StackSlot');
		}
	}

	function mark2(e1, e2, o) : Void {
		mark(e1, o);
		mark(e2, o);
	}

	function marks(es : FlowArray<Flow>, o) : Void {
		for (e in es) {
			mark(e, o);
		}
	}

	// side effect o to have the values in overridden that were overridden
	function retract<X>(o : Map<String,X>, overridden : Map<String,X>) : Void {
		for (x in overridden.keys()) {
			o.set(x, overridden.get(x));
		}
	}

	// side effect o to no longer have xs.
	function revoke<X>(o : Map<String,X>, xs : FlowArray<String>) : Void {
		for (x in xs) {
			o.remove(x);
		}
	}
	
	function inlineable(e : Flow) : Bool {
		var sideeffect = false;
		FlowUtil.traverseExp2(e, function(e : Flow) {
			switch(e) {
				case SetRef(d, e, p): 
					sideeffect = true;
				case SetMutable(d, f, e, p):
					sideeffect = true;
				case Call(c, args, p):
					if (callHasSideEffects(c, topdecs)) {
						sideeffect = true;
					}
				case Deref(_, _):
					sideeffect = true;
				default:
			}});
		return !sideeffect;
	}
	
	static public function callHasSideEffects(c : Flow, topdecs : Map<String,Flow>) : Bool {
		switch (c) {
			case VarRef(n, p): {
				var top = topdecs.get(n);
				if (top != null) {
					switch(top) {
						case Native(n, io, args, result, defbody, p):
							// Natives that are non-io with safe type signatures can never side-effect!
							if (!io) {
								for (a in args) {
									if (!inlinableType(a)) {
										return true;
									}
								}
								// Bingo!
								return false;
							}
						default: {
							// TODO: We could be smarter here
						}
					}
				}
			}
			default:
		}
		return true;
	}
	
	static function inlinableType(e : FlowType) : Bool {
		switch (e) {
			case TVoid: return true;
			case TBool: return true;
			case TInt: return true;
			case TDouble: return true;
			case TString: return true;
			case TReference(type): return false;
			case TPointer(type): return false;
			case TArray(type): 
				// TODO: We should use the real, inferred type instead.  But this works,
				// because no IO does special things with arrays in themselves!
				// (pushArray(), for instance, returns a NEW array)
				return true;
			case TFunction(args, returns): return false;
			case TStruct(structname, args, max): {
				for (a in args) {
					if (!inlinableType(a.type))
						return false;
				}
				return true;
			}
			case TUnion(min, max): return false;
			case TTyvar(ref): return false;
			case TBoundTyvar(id): 
				// TODO: We should use the real, inferred type instead, and then this should return false.
				return true;
			case TFlow: return false;
			case TNative: return false;
			case TName(name, args): return false;
		}
	}
	
	// mark this let to be inlined & eliminated
	function deathmark(e : Flow) : Void {
		// eliminate this let
		var id = letid(e);
		var deadlets = deathrow.get(id);
		if (deadlets == null) {
			deadlets = new FlowArray();
			deathrow.set(id, deadlets);
		}
		deadlets.push(e);
	}

	function isDead(let : Flow) : Bool {
		var id = letid(let);
		var deadlets = deathrow.get(id);
		return deadlets != null && FlowUtil.member(let, deadlets);
	}

	function letid(let : Flow) : String {
		return switch (let) {
			default: impossible('letid');
			case Let(x, sigma, e1, e2, p):  x + (if (p.f != null && p.s != 0) p.f + p.s else '');
		}
	}

	// Remove all lets & inline their definitions of variables that are used only once,
	// but only if side effects allow it.  I.e., allow inlining somethinge1 with a
	// side-effect across a piece of code e2 that has no side effects itself.  Or allow
	// inlinining e1 without side effects across a piece of code e2 with side effects.
	// But disallow inlining a side effect across a piece of code that also has a side
	// effect.  Also disallow inlining inside a lambda or a conditional as that may change
	// the number of times of the side effect.  "inlineable" controls whether we crossed a
	// side effect or not.  When we do cross one, inlineable is set to false for all
	// expressions currently in the environment o.  "inlined" means that we already
	// inlined an expression.  The Let needs this in order to know whether it should be
	// eliminated or we still need a Let.
	function cull(e : Flow, o : Map<String,{e: Flow, inlineable: Bool, inlined: Bool}>) : Flow {
		return switch (e) {
			case SyntaxError(s, pos): impossible('cull: SyntaxError');
			case ConstantVoid(p): e;
			case ConstantString(s, p): e;
			case ConstantDouble(d, p): e;
			case ConstantBool(b, p): e;
			case ConstantI32(i, p): e;
			case ConstantNative(nat, p): e;
			case ConstantArray(es, p): ConstantArray(culls(es, o), p);
			case ConstantStruct(sn, es, p): ConstantStruct(sn, culls(es, o), p);
			case ArrayGet(e1, e2, p): ArrayGet(cull(e1, o), cull(e2, o), p);
			case VarRef(x, p):
				var oo = o.get(x);
				if (oo != null)
					if (oo.inlineable || inlineable(oo.e)) {
						oo.inlined = true;
						oo.e;
					} else e;
				else e;
			case Field(e0, field, p): Field(cull(e0, o), field, p);
			case RefTo(e0, p): RefTo(cull(e0, o), p);
			case Pointer(index, pos): impossible('Delet: pointer');
			case Deref(e0, p):
				var u = Deref(cull(e0, o), p);
				dirty(o);
				u;
			case SetRef(e1, e2, p):
				var u1 = cull(e1, o);
				var u2 = cull(e2, o);
				dirty(o);
				SetRef(u1, u2, p);
			case SetMutable(e1, field, e2, p):
				var u1 = cull(e1, o);
				var u2 = cull(e2, o);
				dirty(o);
				SetMutable(u1, field, u2, p);
			case Cast(e0, fromtype, totype, p): Cast(cull(e0, o), fromtype, totype, p);
			case Let(x, sigma, e1, e2, p):
				if (isDead(e)) {
					var oldx = o.get(x);
					o.set(x, {e: cull(e1, o), inlineable: true, inlined: false});
					var u = cull(e2, o);
					var xwas = o.get(x);
					if (! xwas.inlined) {
						u = Let(x, sigma, xwas.e, u, p);
					}
					if (oldx == null) o.remove(x) else o.set(x, oldx);
					u;
				} else {
					Let(x, sigma, cull(e1, o), cull(e2, o), p);
				}
			case Lambda(xs, type, e0, _, p):
				var overridden = new Map();
				for (x in xs) {
					if (o.exists(x)) {
						overridden.set(x, o.get(x));
						o.remove(x);
					}
				}
				dirty(o);
				var u = FlowUtil.lambda(xs, type, cull(e0, o), p);
				retract(o, overridden);
				u;
			case Closure(body, freevars, p): impossible('Delet: closure');
			case Call(e0, es, p):
				var u0 = cull(e0, o);
				var us = culls(es, o);
				if (callHasSideEffects(u0, topdecs)) {
					dirty(o);
				}
				Call(u0, us, p);
			case Sequence(es, p): Sequence(culls(es, o), p);
			case If(e0, e1, e2, p):
				var u0 = cull(e0, o);
				dirty(o);
				var u1 = cull(e1, o);
				var u2 = cull(e2, o);
				If(u0, u1, u2, p);
			case Not(e0, p): Not(cull(e0, o), p); 
			case Negate(e0, p): Negate(cull(e0, o), p); 
			case Multiply(e1, e2, p): Multiply(cull(e1, o), cull(e2, o), p);
			case Divide(e1, e2, p): Divide(cull(e1, o), cull(e2, o), p);
			case Modulo(e1, e2, p): Modulo(cull(e1, o), cull(e2, o), p);
			case Plus(e1, e2, p): Plus(cull(e1, o), cull(e2, o), p);
			case Minus(e1, e2, p): Minus(cull(e1, o), cull(e2, o), p);
			case Equal(e1, e2, p): Equal(cull(e1, o), cull(e2, o), p);
			case NotEqual(e1, e2, p): NotEqual(cull(e1, o), cull(e2, o), p);
			case LessThan(e1, e2, p): LessThan(cull(e1, o), cull(e2, o), p);
			case LessEqual(e1, e2, p): LessEqual(cull(e1, o), cull(e2, o), p);
			case GreaterThan(e1, e2, p): GreaterThan(cull(e1, o), cull(e2, o), p);
			case GreaterEqual(e1, e2, p): GreaterEqual(cull(e1, o), cull(e2, o), p);
			case And(e1, e2, p): impossible('cull And');
			case Or(e1, e2, p): impossible('cull Or');
			case Switch(e0, type, cases, p): impossible('cull: complex switch');
			case SimpleSwitch(e0, cases, p):
				// it is more accurate to count the number of occurrences of x in the
				// branches as the max rather than the sum of the count from the branches;
				// similar with Switch & If.
				var u0 = cull(e0, o);
				dirty(o);
				SimpleSwitch(u0, FlowUtil.map(cases, function (c : SimpleCase) {
					return {structname: c.structname, body: cull(c.body, o)};}), p);						  
			case Native(name, io, args, result, defbody, p):
				if (defbody == null) e
				else Native(name, io, args, result, cull(defbody, o), p);
			case NativeClosure(nargs, fn, p): impossible('cull: NativeClosure');
			case StackSlot(q0, q1, q2): impossible('cull: StackSlot');
		}
	}

	function culls(es : FlowArray<Flow>, o : Map<String,{e: Flow, inlineable: Bool, inlined: Bool}>) : FlowArray<Flow> {
		return FlowUtil.map(es, function (e : Flow) {return cull(e, o);});
	}

	function dirty(o : Map<String,{e: Flow, inlineable: Bool, inlined: Bool}>) : Void {
		for (x in o.keys()) {
			var oo = o.get(x);
			oo.inlineable = false;
		}
	}
	
	public static function delet(e : Flow, topdecs : Map<String,Flow>) : Flow {
		var d = new Delet(topdecs);
		d.mark(e, new Map());
		return d.cull(e, new Map());
	}

	static function impossible(s : String) : Dynamic {
		throw 'impossible: ' + s;
		return null;
	}

	static function pp(code : Flow) : String {
		return Prettyprint.prettyprint(code, '');
	}

	var deathrow : Map<String,FlowArray<Flow>>;
	var topdecs : Map<String,Flow>;
}
