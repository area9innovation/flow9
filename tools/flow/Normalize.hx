import Flow;

// A normalizer meant to convert code to a normal form in order to expose
// code with minor differences that are technically identical.

// Currently, it does not normalize anything at all.

class Normalize {
	 static public function normalize(code : Flow) : Flow {
		return switch (code) {
			case SyntaxError(s, pos) : code;
			case ConstantVoid(pos): code;
			case ConstantString(value, pos): code;
			case ConstantDouble(value, pos): code;
			case ConstantBool(value, pos): code;
			case ConstantI32(value, pos): code;
			case ConstantNative(value, pos): code;
			case ConstantArray(values, pos):
				var as = new FlowArray();
				for (v in values) {
					as.push(normalize(v));
				}
				return Flow.ConstantArray(as, pos);
			case ConstantStruct(name, args, pos):
				var as = new FlowArray();
				for (v in args) {
					as.push(normalize(v));
				}
				return Flow.ConstantStruct(name, as, pos);
			case ArrayGet(array, index, pos):
				var a = normalize(array);
				var i = normalize(index);
				return ArrayGet(a, i, pos);
			case VarRef(name, pos) : code;
			case Field(call, name, pos):
				var v = normalize(call);
				return Field(v, name, pos);
			case RefTo(value, pos) :
				RefTo(normalize(value), pos);
			case Pointer(index, pos): code;
			case Deref(pointer, pos): 
				Deref(normalize(pointer), pos);
			case SetRef(pointer, value, pos):
				SetRef(normalize(pointer), normalize(value), pos);
			case Cast(value, fromtype, totype, pos) :
				Cast(normalize(value), fromtype, totype, pos);
			case Let(name, sigma, value, scope, pos):
				var val = normalize(value);
				if (scope == null) {
					return Let(name, sigma, val, scope, pos);
				}
				var s = normalize(scope);
				return Let(name, sigma, val, s, pos);
			case Lambda(arguments, type, body, _, pos):
				Flow.Lambda(arguments, type, normalize(body), pos);
			case Closure(body, environment, pos): code;
			case Call(clos, arguments, pos):
				var closure = normalize(clos);
				// TODO: Maybe convert struct calls to structs here?
				var as = new FlowArray();
				for (v in arguments) {
					as.push(normalize(v));
				}
				return Call(closure, as, pos);
			case Sequence(statements, pos):
				var s = new FlowArray();
				for (v in statements) {
					s.push(normalize(v));
				}
				return Sequence(s, pos);
			case If(condition, then, elseExp, pos):
				If(normalize(condition), normalize(then), normalize(elseExp), pos);
			case Not(e, pos): 
				Not(normalize(e), pos);
			case Negate(e, pos):
				Negate(normalize(e), pos);
			case Multiply(e1, e2, pos):
				var v1 = normalize(e1);
				var v2 = normalize(e2);
				Multiply(v1, v2, pos);
			case Divide(e1, e2, pos):
				var v1 = normalize(e1);
				var v2 = normalize(e2);
				Divide(v1, v2, pos);
			case Modulo(e1, e2, pos):
				var v1 = normalize(e1);
				var v2 = normalize(e2);
				Modulo(v1, v2, pos);
			case Plus(e1, e2, pos):
				var v1 = normalize(e1);
				var v2 = normalize(e2);
				// Here, for non-strings, + is commutative and thus we can introduce some
				// ordering
				Plus(v1, v2, pos);
			case Minus(e1, e2, pos):
				var v1 = normalize(e1);
				var v2 = normalize(e2);
				Minus(v1, v2, pos);
			case Equal(e1, e2, pos):
				var r1 = normalize(e1);
				var r2 = normalize(e2);
				Equal(r1, r2, pos);
			case NotEqual(e1, e2, pos):
				var r1 = normalize(e1);
				var r2 = normalize(e2);
				NotEqual(r1, r2, pos);
			case LessThan(e1, e2, pos):
				var r1 = normalize(e1);
				var r2 = normalize(e2);
				LessThan(r1, r2, pos);
			case LessEqual(e1, e2, pos):
				var r1 = normalize(e1);
				var r2 = normalize(e2);
				LessEqual(r1, r2, pos);
			case GreaterThan(e1, e2, pos):
				var r1 = normalize(e1);
				var r2 = normalize(e2);
				GreaterThan(r1, r2, pos);
			case GreaterEqual(e1, e2, pos):
				var r1 = normalize(e1);
				var r2 = normalize(e2);
				GreaterEqual(r1, r2, pos);
			case And(e1, e2, pos):
				var v1 = normalize(e1);
				var v2 = normalize(e2);
				And(v1, v2, pos);
			case Or(e1, e2, pos):
				var v1 = normalize(e1);
				var v2 = normalize(e2);
				Or(v1, v2, pos);
			case Switch(value, type, cases, pos):
				var v = normalize(value);
				var nc = new FlowArray();
				for (c in cases) {
					var code = normalize(c.body);
					nc.push({structname: c.structname, args : c.args, body : code});
				}
				Switch(v, type, nc, pos);
			case Native(name, args, result, pos): code;
			case NativeClosure(nargs, fn, pos): code;
			case StackSlot(q0, q1, q2): code;
		}
	}
 }
