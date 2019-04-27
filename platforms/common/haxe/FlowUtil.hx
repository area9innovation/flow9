import Flow;
import Position;

/// These are helper functions that can be used by native callbacks
class FlowUtil {
  static public function getPosition(code : Flow) : Null<Position> {
    if (code == null) return null;
    var en = Type.getEnum(code);
    if (en != null) {
      var pars = Type.enumParameters(code);
      var pos = pars[pars.length - 1];
      return pos;
    }
    return null;
  }
  static public function error(error : String, code : Flow) : String {
    return Prettyprint.getLocation(code) + ": " + error;
  }
	
  static public function getArray(code : Flow) : FlowArray<Flow> {
    switch (code) {
    case ConstantArray(a, pos): return a;
    default: throw "Expected an array, not: " + Prettyprint.print(code);
    }
  }

  static public function getNative(code : Flow) : Dynamic {
    switch (code) {
    case ConstantNative(v, pos): return v;
    default: throw "Expected a native value, not: " + Prettyprint.print(code);
    }
  }

  static public function getString(code : Flow) : String {
    switch (code) {
    case ConstantStruct(s, v, pos): return s;
    case ConstantString(s, pos): return s;
    default: throw "Not a string:" + Prettyprint.print(code);
    }
  }

  static public function getInt(code : Flow) : Int {
    switch (code) {
    case ConstantI32(i, pos): return i;
    default: throw "Not an int:" + Prettyprint.print(code);
    }
  }

  static public function getI32(code : Flow) : Int {
    switch (code) {
    case ConstantI32(i, pos): return i;
    default: throw "Not an int:" + Prettyprint.print(code);
    }
  }

  static public function getDouble(code : Flow) : Float {
    switch (code) {
    case ConstantDouble(f, pos): return f;
    default: throw "Not a double:" + Prettyprint.print(code);
    }
  }

  static public function getBool(code : Flow) : Bool {
    switch (code) {
    case ConstantBool(b, pos): return b;
    default: throw "Not a bool:" + Prettyprint.print(code);
    }
  }

  static public function isStructType(t : FlowType) : Bool {
    return switch (t) {
    case TName(n, args): true;
    case TStruct(n, tds, max): true;
    case TUnion(min, max): true;
    case TTyvar(ref): if (ref.type == null) false else isStructType(ref.type);
    default: false;
    };
  }
	
  static public function isUnion(t : FlowType) : Bool {
    return switch (untyvar(t)) {
    case TUnion(min, max): true;
    default: false;
    };
  }

  private static var next_tyvar_id : Int = 0;

  static public inline function mkTyvar(arg : FlowType) {
    return { type:arg, id:(next_tyvar_id++) };
  }

	
  static public function traverseTypePos(t : FlowTypePos, f : FlowType -> Void) : Void {
	traverseType(PositionUtil.getValue(t), f);
  }

  // traverseType(t, f) = apply f to every node in the type t
  static public function traverseType(t : FlowType, f : FlowType -> Void) : Void {
    f(t);
    switch (t) {
    case TVoid:
    case TBool:
    case TInt:
    case TDouble:
    case TString:
    case TReference(t): traverseTypePos(t, f);
    case TPointer(t): traverseTypePos(t, f);
    case TArray(t): traverseTypePos(t, f);
    case TFunction(args, returns): traverseTypesPos(args, f); traverseTypePos(returns, f);
    case TStruct(n, args, max):
      for (td in args) {
        traverseTypePos(td.type, f);
      }
    case TUnion(min, max): traverseTypeHash(min, f); traverseTypeHash(max, f);
    case TTyvar(ref): if (ref.type != null) traverseType(ref.type, f);
    case TBoundTyvar(i):
    case TFlow:
    case TNative:
    case TName(n, args): traverseTypesPos
(args, f);
    }
  }

  static public function traverseTypeHash(h : Map<String, FlowType>, f : FlowType -> Void) : Void {
    if (h != null) {
      for (t in h) {
        traverseType(t, f);
      }
    }
  }
  
  static public function traverseTypesPos(ts : FlowArray<FlowTypePos>, f : FlowType -> Void) : Void {
#if typepos
	return null;
#else
	return traverseTypes(ts, f);
#end	 
  }

  static public function traverseTypes(ts : FlowArray<FlowType>, f : FlowType -> Void) : Void {
    for (t in ts) {
      traverseType(t, f);
    }
  }

  static public function traverseTypedecs(tds : FlowArray<MonoTypeDeclaration>, f : FlowType -> Void) : Void {
    for (td in tds) {
      traverseTypedec(td, f);
    }
  }

  static public function traverseTypedec(td : MonoTypeDeclaration, f : FlowType -> Void) : Void {
    traverseType(td.type, f);
  }
	

  static public function mapFlow(e : Flow, f : Flow -> Flow) : Flow {
    return f(
             switch (e) {
             case SyntaxError(s, pos): e;
             case ConstantVoid(pos): e;
             case ConstantString(value, pos): e;
             case ConstantDouble(value, pos): e;
             case ConstantBool(value, pos): e;
             case ConstantI32(value, pos): e;
             case ConstantNative(value, pos): e;
             case ConstantArray(values, pos): {
               var c = mapFlows(values, f);
               if (c == null) e else Flow.ConstantArray(c, pos);
             }
             case ConstantStruct(name, args, pos): {
               var c = mapFlows(args, f);
               if (c == null) e else Flow.ConstantStruct(name, c, pos);
             }
             case ArrayGet(array, index, pos): {
               var a = mapFlow(array, f);
               var i = mapFlow(index, f);
               if (a == array && i == index) e else ArrayGet(a, i, pos);
             }
             case VarRef(name, pos): e;
             case Field(call, name, pos): {
               var c = mapFlow(call, f);
               if (c == call) e else Field(c, name, pos);
             }
             case RefTo(value, pos): {
               var v = mapFlow(value, f);
               if (v == value) e else RefTo(v, pos);
             }
             case Pointer(index, pos): e;
             case Deref(pointer, pos): {
               var p = mapFlow(pointer, f);
               if (p == pointer) e else Deref(p, pos);
             }
             case SetRef(pointer, value, pos): {
               var p = mapFlow(pointer, f);
               var v = mapFlow(value, f);
               if (p == pointer && v == value) e else SetRef(p, v, pos);
             }
             case SetMutable(pointer, field, value, pos): {
               var p = mapFlow(pointer, f);
               var v = mapFlow(value, f);
               if (p == pointer && v == value) e else SetMutable(p, field, v, pos);
             }
             case Cast(value, fromtype, totype, pos): {
               var v = mapFlow(value, f);
               if (v == value) e else Cast(v, fromtype, totype, pos);
             }
             case Let(name, sigma, value, scope, pos): {
               var v = mapFlow(value, f);
               var s = if (scope == null) null else mapFlow(scope, f);
               if (v == value && s == scope) e else Let(name, sigma, v, s, pos);
             }
             case Lambda(arguments, type, body, _, pos): {
               var b = mapFlow(body, f);
               if (b == body) e else FlowUtil.lambda(arguments, type, b, pos);
             }
             case Closure(body, environment, pos): e;
             case Call(e0, es, pos): {
               var e00 = mapFlow(e0, f);
               var ess = mapFlows(es, f);
               if (e00 == e0 && ess == null) e else {
                   Call(e00, if (ess == null) es else ess, pos);
                 }
             }
             case Sequence(es, pos): {
               var ess = mapFlows(es, f);
               if (ess == null) e else Sequence(ess, pos);
             }
             case If(e0, e1, e2, pos): {
               var e00 = mapFlow(e0, f);
               var e01 = mapFlow(e1, f);
               var e02 = mapFlow(e2, f);
               if (e00 == e0 && e01 == e1 && e02 == e2) e else If(e00, e01, e02, pos);
             }
             case Not(e0, pos): {
               var e00 = mapFlow(e0, f);
               if (e00 == e0) e else Not(e00, pos);
             }
             case Negate(e0, pos): {
               var e00 = mapFlow(e0, f);
               if (e00 == e0) e else Negate(e00, pos);
             }
             case Multiply(e1, e2, pos): {
               var e01 = mapFlow(e1, f);
               var e02 = mapFlow(e2, f);
               if (e01 == e1 && e02 == e2) e else Multiply(e01, e02, pos);
             }
             case Divide(e1, e2, pos): {
               var e01 = mapFlow(e1, f);
               var e02 = mapFlow(e2, f);
               if (e01 == e1 && e02 == e2) e else Divide(e01, e02, pos);
             }
             case Modulo(e1, e2, pos): {
               var e01 = mapFlow(e1, f);
               var e02 = mapFlow(e2, f);
               if (e01 == e1 && e02 == e2) e else Modulo(e01, e02, pos);
             }
             case Plus(e1, e2, pos): {
               var e01 = mapFlow(e1, f);
               var e02 = mapFlow(e2, f);
               if (e01 == e1 && e02 == e2) e else Plus(e01, e02, pos);
             };
             case Minus(e1, e2, pos): {
               var e01 = mapFlow(e1, f);
               var e02 = mapFlow(e2, f);
               if (e01 == e1 && e02 == e2) e else Minus(e01, e02, pos);
             };
             case Equal(e1, e2, pos): {
               var e01 = mapFlow(e1, f);
               var e02 = mapFlow(e2, f);
               if (e01 == e1 && e02 == e2) e else Equal(e01, e02, pos);
             };
             case NotEqual(e1, e2, pos): {
               var e01 = mapFlow(e1, f);
               var e02 = mapFlow(e2, f);
               if (e01 == e1 && e02 == e2) e else NotEqual(e01, e02, pos);
             };
             case LessThan(e1, e2, pos): {
               var e01 = mapFlow(e1, f);
               var e02 = mapFlow(e2, f);
               if (e01 == e1 && e02 == e2) e else LessThan(e01, e02, pos);
             };
             case LessEqual(e1, e2, pos): {
               var e01 = mapFlow(e1, f);
               var e02 = mapFlow(e2, f);
               if (e01 == e1 && e02 == e2) e else LessEqual(e01, e02, pos);
             };
             case GreaterThan(e1, e2, pos): {
               var e01 = mapFlow(e1, f);
               var e02 = mapFlow(e2, f);
               if (e01 == e1 && e02 == e2) e else GreaterThan(e01, e02, pos);
             };
             case GreaterEqual(e1, e2, pos): {
               var e01 = mapFlow(e1, f);
               var e02 = mapFlow(e2, f);
               if (e01 == e1 && e02 == e2) e else GreaterEqual(e01, e02, pos);
             };
             case And(e1, e2, pos): {
               var e01 = mapFlow(e1, f);
               var e02 = mapFlow(e2, f);
               if (e01 == e1 && e02 == e2) e else And(e01, e02, pos);
             };
             case Or(e1, e2, pos): {
               var e01 = mapFlow(e1, f);
               var e02 = mapFlow(e2, f);
               if (e01 == e1 && e02 == e2) e else Or(e01, e02, pos);
             };
             case Switch(value, type, cases, pos):
               var v = mapFlow(value, f);
               var nc = new FlowArray();
               var different = v != value;
               for (c in cases) {
                 var b = mapFlow(c.body, f);
                 if (b != c.body) different = true;
                 nc.push({structname: c.structname, args: c.args, used_args: c.used_args, body: b});
               }
               if (!different) e else Switch(v, type, nc, pos);
             case SimpleSwitch(value, cases, pos):
               var v = mapFlow(value, f);
               var nc = new FlowArray();
               var different = v != value;
               for (c in cases) {
                 var b = mapFlow(c.body, f);
                 if (b != c.body) different = true;
                 nc.push({structname: c.structname, body: b});
               }
               if (!different) e else SimpleSwitch(v, nc, pos);
             case Native(name, io, args, result, defbody, pos):
               var db = if (defbody == null) null else mapFlow(defbody, f);
               if (db == defbody) e else Native(name, io, args, result, db, pos);
             case NativeClosure(nargs, fn, pos): e;
             case StackSlot(q0, q1, q2): e;
             });
  }

  static function mapFlows(es : FlowArray<Flow>, f : Flow -> Flow) : FlowArray<Flow> {
    var as = new FlowArray();
    var different = false;
    for (e in es) {
      var c = mapFlow(e, f);
      if (c != e) different = true;
      as.push(c);
    }
    if (!different) return null;
    return as;
  }

  // Map in pre-order
  static public function mapFlow2(e0 : Flow, f : Flow -> Flow) : Flow {
    var e = f(e0);
    return switch (e) {
             case SyntaxError(s, pos): e;
             case ConstantVoid(pos): e;
             case ConstantString(value, pos): e;
             case ConstantDouble(value, pos): e;
             case ConstantBool(value, pos): e;
             case ConstantI32(value, pos): e;
             case ConstantNative(value, pos): e;
             case ConstantArray(values, pos): {
               var c = mapFlows2(values, f);
               if (c == null) e else Flow.ConstantArray(c, pos);
             }
             case ConstantStruct(name, args, pos): {
               var c = mapFlows2(args, f);
               if (c == null) e else Flow.ConstantStruct(name, c, pos);
             }
             case ArrayGet(array, index, pos): {
               var a = mapFlow2(array, f);
               var i = mapFlow2(index, f);
               if (a == array && i == index) e else ArrayGet(a, i, pos);
             }
             case VarRef(name, pos): e;
             case Field(call, name, pos): {
               var c = mapFlow2(call, f);
               if (c == call) e else Field(c, name, pos);
             }
             case RefTo(value, pos): {
               var v = mapFlow2(value, f);
               if (v == value) e else RefTo(v, pos);
             }
             case Pointer(index, pos): e;
             case Deref(pointer, pos): {
               var p = mapFlow2(pointer, f);
               if (p == pointer) e else Deref(p, pos);
             }
             case SetRef(pointer, value, pos): {
               var p = mapFlow2(pointer, f);
               var v = mapFlow2(value, f);
               if (p == pointer && v == value) e else SetRef(p, v, pos);
             }
             case SetMutable(pointer, field, value, pos): {
               var p = mapFlow2(pointer, f);
               var v = mapFlow2(value, f);
               if (p == pointer && v == value) e else SetMutable(p, field, v, pos);
             }
             case Cast(value, fromtype, totype, pos): {
               var v = mapFlow2(value, f);
               if (v == value) e else Cast(v, fromtype, totype, pos);
             }
             case Let(name, sigma, value, scope, pos): {
               var v = mapFlow2(value, f);
               var s = if (scope == null) null else mapFlow2(scope, f);
               if (v == value && s == scope) e else Let(name, sigma, v, s, pos);
             }
             case Lambda(arguments, type, body, _, pos): {
               var b = mapFlow2(body, f);
               if (b == body) e else FlowUtil.lambda(arguments, type, b, pos);
             }
             case Closure(body, environment, pos): e;
             case Call(e0, es, pos): {
               var e00 = mapFlow2(e0, f);
               var ess = mapFlows2(es, f);
               if (e00 == e0 && ess == null) e else {
                   Call(e00, if (ess == null) es else ess, pos);
                 }
             }
             case Sequence(es, pos): {
               var ess = mapFlows2(es, f);
               if (ess == null) e else Sequence(ess, pos);
             }
             case If(e0, e1, e2, pos): {
               var e00 = mapFlow2(e0, f);
               var e01 = mapFlow2(e1, f);
               var e02 = mapFlow2(e2, f);
               if (e00 == e0 && e01 == e1 && e02 == e2) e else If(e00, e01, e02, pos);
             }
             case Not(e0, pos): {
               var e00 = mapFlow2(e0, f);
               if (e00 == e0) e else Not(e00, pos);
             }
             case Negate(e0, pos): {
               var e00 = mapFlow2(e0, f);
               if (e00 == e0) e else Negate(e00, pos);
             }
             case Multiply(e1, e2, pos): {
               var e01 = mapFlow2(e1, f);
               var e02 = mapFlow2(e2, f);
               if (e01 == e1 && e02 == e2) e else Multiply(e01, e02, pos);
             }
             case Divide(e1, e2, pos): {
               var e01 = mapFlow2(e1, f);
               var e02 = mapFlow2(e2, f);
               if (e01 == e1 && e02 == e2) e else Divide(e01, e02, pos);
             }
             case Modulo(e1, e2, pos): {
               var e01 = mapFlow2(e1, f);
               var e02 = mapFlow2(e2, f);
               if (e01 == e1 && e02 == e2) e else Modulo(e01, e02, pos);
             }
             case Plus(e1, e2, pos): {
               var e01 = mapFlow2(e1, f);
               var e02 = mapFlow2(e2, f);
               if (e01 == e1 && e02 == e2) e else Plus(e01, e02, pos);
             };
             case Minus(e1, e2, pos): {
               var e01 = mapFlow2(e1, f);
               var e02 = mapFlow2(e2, f);
               if (e01 == e1 && e02 == e2) e else Minus(e01, e02, pos);
             };
             case Equal(e1, e2, pos): {
               var e01 = mapFlow2(e1, f);
               var e02 = mapFlow2(e2, f);
               if (e01 == e1 && e02 == e2) e else Equal(e01, e02, pos);
             };
             case NotEqual(e1, e2, pos): {
               var e01 = mapFlow2(e1, f);
               var e02 = mapFlow2(e2, f);
               if (e01 == e1 && e02 == e2) e else NotEqual(e01, e02, pos);
             };
             case LessThan(e1, e2, pos): {
               var e01 = mapFlow2(e1, f);
               var e02 = mapFlow2(e2, f);
               if (e01 == e1 && e02 == e2) e else LessThan(e01, e02, pos);
             };
             case LessEqual(e1, e2, pos): {
               var e01 = mapFlow2(e1, f);
               var e02 = mapFlow2(e2, f);
               if (e01 == e1 && e02 == e2) e else LessEqual(e01, e02, pos);
             };
             case GreaterThan(e1, e2, pos): {
               var e01 = mapFlow2(e1, f);
               var e02 = mapFlow2(e2, f);
               if (e01 == e1 && e02 == e2) e else GreaterThan(e01, e02, pos);
             };
             case GreaterEqual(e1, e2, pos): {
               var e01 = mapFlow2(e1, f);
               var e02 = mapFlow2(e2, f);
               if (e01 == e1 && e02 == e2) e else GreaterEqual(e01, e02, pos);
             };
             case And(e1, e2, pos): {
               var e01 = mapFlow2(e1, f);
               var e02 = mapFlow2(e2, f);
               if (e01 == e1 && e02 == e2) e else And(e01, e02, pos);
             };
             case Or(e1, e2, pos): {
               var e01 = mapFlow2(e1, f);
               var e02 = mapFlow2(e2, f);
               if (e01 == e1 && e02 == e2) e else Or(e01, e02, pos);
             };
             case Switch(value, type, cases, pos):
               var v = mapFlow2(value, f);
               var nc = new FlowArray();
               var different = v != value;
               for (c in cases) {
                 var b = mapFlow2(c.body, f);
                 if (b != c.body) different = true;
                 nc.push({structname: c.structname, args: c.args, used_args: c.used_args, body: b});
               }
               if (!different) e else Switch(v, type, nc, pos);
             case SimpleSwitch(value, cases, pos):
               var v = mapFlow2(value, f);
               var nc = new FlowArray();
               var different = v != value;
               for (c in cases) {
                 var b = mapFlow2(c.body, f);
                 if (b != c.body) different = true;
                 nc.push({structname: c.structname, body: b});
               }
               if (!different) e else SimpleSwitch(v, nc, pos);
             case Native(name, io, args, result, defbody, pos):
               var db = if (defbody == null) null else mapFlow2(defbody, f);
               if (db == defbody) e else Native(name, io, args, result, db, pos);
             case NativeClosure(nargs, fn, pos): e;
             case StackSlot(q0, q1, q2): e;
             };
  }

  static function mapFlows2(es : FlowArray<Flow>, f : Flow -> Flow) : FlowArray<Flow> {
    var as = new FlowArray();
    var different = false;
    for (e in es) {
      var c = mapFlow2(e, f);
      if (c != e) different = true;
      as.push(c);
    }
    if (!different) return null;
    return as;
  }

  // Apply f to all sub-expressions of e, pre-order
  static public function traverseExp(e : Flow, f : Flow -> Void) : Void {
    f(e);
    switch (e) {
    case ConstantVoid(pos):
    case ConstantBool(value, pos):
    case ConstantI32(value, pos):
    case ConstantDouble(value, pos):
    case ConstantString(value, pos):
    case ConstantArray(es, pos): traverseExps(es, f);
    case ConstantStruct(name, values, pos): traverseExps(values, f);
    case ArrayGet(array, index, pos): traverseExp(array, f); traverseExp(index, f);
    case VarRef(name, pos):
    case RefTo(value, pos): traverseExp(value, f);
    case Pointer(pointer, pos):
    case Deref(pointer, pos): traverseExp(pointer, f);
    case SetRef(pointer, value, pos): traverseExp(pointer, f); traverseExp(value, f);
    case SetMutable(pointer, field, value, pos): traverseExp(pointer, f); traverseExp(value, f);
    case Let(name, sigma, value, scope, pos): traverseExp(value, f); if (scope != null) traverseExp(scope, f);
    case Lambda(arguments, type, body, _, pos): traverseExp(body, f);
    case Closure(body, freevars, pos): traverseExp(body, f);
    case Call(closure, arguments, pos): traverseExp(closure, f); traverseExps(arguments, f);
    case Sequence(statements, pos): traverseExps(statements, f);
    case If(condition, then, elseExp, pos): 
      traverseExp(condition, f);
      traverseExp(then, f);
      traverseExp(elseExp, f);
    case Not(e, pos): traverseExp(e, f);
    case Negate(e, pos): traverseExp(e, f);
    case Multiply(e1, e2, pos): traverseExp(e1, f); traverseExp(e2, f);
    case Divide(e1, e2, pos): traverseExp(e1, f); traverseExp(e2, f);
    case Modulo(e1, e2, pos): traverseExp(e1, f); traverseExp(e2, f);
    case Plus(e1, e2, pos): traverseExp(e1, f); traverseExp(e2, f);
    case Minus(e1, e2, pos): traverseExp(e1, f); traverseExp(e2, f);
    case Equal(e1, e2, pos): traverseExp(e1, f); traverseExp(e2, f);
    case NotEqual(e1, e2, pos): traverseExp(e1, f); traverseExp(e2, f);
    case LessThan(e1, e2, pos): traverseExp(e1, f); traverseExp(e2, f);
    case LessEqual(e1, e2, pos): traverseExp(e1, f); traverseExp(e2, f);
    case GreaterThan(e1, e2, pos): traverseExp(e1, f); traverseExp(e2, f);
    case GreaterEqual(e1, e2, pos): traverseExp(e1, f); traverseExp(e2, f);
    case And(e1, e2, pos): traverseExp(e1, f); traverseExp(e2, f);
    case Or(e1, e2, pos): traverseExp(e1, f); traverseExp(e2, f);
    case Field(call, name, pos): traverseExp(call, f);
    case Cast(value, fromtype, totype, pos): traverseExp(value, f);
    case Switch(e, type, cases, p):
      traverseExp(e, f);
      for (c in cases) {
        traverseExp(c.body, f);
      }
    case SimpleSwitch(e, cases, p):
      traverseExp(e, f);
      for (c in cases) {
        traverseExp(c.body, f);
      }
    case SyntaxError(e, p): 
    case StackSlot(q0, q1, q2): 
    case NativeClosure(args, fn, pos): 
    case Native(name, io, args, result, defbody, pos):
      if (defbody != null) traverseExp(defbody, f);
    case ConstantNative(value, pos):
    }
  }

  static public function traverseExps(es : FlowArray<Flow>, f : Flow -> Void) : Void {
    for (e in es) {
      traverseExp(e, f);
    }
  }

  // Apply f to all sub-expressions of e, just like traverseExp, except it does not go
  // into other functions, i.e., not below lambdas or closures.
  static public function traverseExp2(e : Flow, f : Flow -> Void) : Void {
    f(e);
    switch (e) {
    case ConstantVoid(pos):
    case ConstantBool(value, pos):
    case ConstantI32(value, pos):
    case ConstantDouble(value, pos):
    case ConstantString(value, pos):
    case ConstantArray(es, pos): traverseExp2s(es, f);
    case ConstantStruct(name, values, pos): traverseExp2s(values, f);
    case ArrayGet(array, index, pos): traverseExp2(array, f); traverseExp2(index, f);
    case VarRef(name, pos):
    case RefTo(value, pos): traverseExp2(value, f);
    case Pointer(pointer, pos):
    case Deref(pointer, pos): traverseExp2(pointer, f);
    case SetRef(pointer, value, pos): traverseExp2(pointer, f); traverseExp2(value, f);
    case SetMutable(pointer, field, value, pos): traverseExp2(pointer, f); traverseExp2(value, f);
    case Let(name, sigma, value, scope, pos): traverseExp2(value, f); if (scope != null) traverseExp2(scope, f);
    case Lambda(arguments, type, body, _, pos): // 
    case Closure(body, freevars, pos):
    case Call(closure, arguments, pos): traverseExp2(closure, f); traverseExp2s(arguments, f);
    case Sequence(statements, pos): traverseExp2s(statements, f);
    case If(condition, then, elseExp, pos): 
      traverseExp2(condition, f);
      traverseExp2(then, f);
      traverseExp2(elseExp, f);
    case Not(e, pos): traverseExp2(e, f);
    case Negate(e, pos): traverseExp2(e, f);
    case Multiply(e1, e2, pos): traverseExp2(e1, f); traverseExp2(e2, f);
    case Divide(e1, e2, pos): traverseExp2(e1, f); traverseExp2(e2, f);
    case Modulo(e1, e2, pos): traverseExp2(e1, f); traverseExp2(e2, f);
    case Plus(e1, e2, pos): traverseExp2(e1, f); traverseExp2(e2, f);
    case Minus(e1, e2, pos): traverseExp2(e1, f); traverseExp2(e2, f);
    case Equal(e1, e2, pos): traverseExp2(e1, f); traverseExp2(e2, f);
    case NotEqual(e1, e2, pos): traverseExp2(e1, f); traverseExp2(e2, f);
    case LessThan(e1, e2, pos): traverseExp2(e1, f); traverseExp2(e2, f);
    case LessEqual(e1, e2, pos): traverseExp2(e1, f); traverseExp2(e2, f);
    case GreaterThan(e1, e2, pos): traverseExp2(e1, f); traverseExp2(e2, f);
    case GreaterEqual(e1, e2, pos): traverseExp2(e1, f); traverseExp2(e2, f);
    case And(e1, e2, pos): traverseExp2(e1, f); traverseExp2(e2, f);
    case Or(e1, e2, pos): traverseExp2(e1, f); traverseExp2(e2, f);
    case Field(call, name, pos): traverseExp2(call, f);
    case Cast(value, fromtype, totype, pos): traverseExp2(value, f);
    case Switch(e, type, cases, p):
      traverseExp2(e, f);
      for (c in cases) {
        traverseExp2(c.body, f);
      }
    case SimpleSwitch(e, cases, p):
      traverseExp2(e, f);
      for (c in cases) {
        traverseExp2(c.body, f);
      }
    case SyntaxError(e, p): 
    case StackSlot(q0, q1, q2): 
    case NativeClosure(args, fn, pos): 
    case Native(name, io, args, result, defbody, pos):
      if (defbody != null) traverseExp2(defbody, f);
    case ConstantNative(value, pos):
    }
  }

  static public function traverseExp2s(es : FlowArray<Flow>, f : Flow -> Void) : Void {
    for (e in es) {
      traverseExp2(e, f);
    }
  }

  // Apply f to all sub-expressions of e, post-order
  static public function traverseExp3(e : Flow, f : Flow -> Void) : Void {
    switch (e) {
    case ConstantVoid(pos):
    case ConstantBool(value, pos):
    case ConstantI32(value, pos):
    case ConstantDouble(value, pos):
    case ConstantString(value, pos):
    case ConstantArray(es, pos): traverseExps3(es, f);
    case ConstantStruct(name, values, pos): traverseExps3(values, f);
    case ArrayGet(array, index, pos): traverseExp3(array, f); traverseExp3(index, f);
    case VarRef(name, pos):
    case RefTo(value, pos): traverseExp3(value, f);
    case Pointer(pointer, pos):
    case Deref(pointer, pos): traverseExp3(pointer, f);
    case SetRef(pointer, value, pos): traverseExp3(pointer, f); traverseExp3(value, f);
    case SetMutable(pointer, field, value, pos): traverseExp3(pointer, f); traverseExp3(value, f);
    case Let(name, sigma, value, scope, pos): traverseExp3(value, f); if (scope != null) traverseExp3(scope, f);
    case Lambda(arguments, type, body, _, pos): traverseExp3(body, f);
    case Closure(body, freevars, pos): traverseExp3(body, f);
    case Call(closure, arguments, pos): traverseExp3(closure, f); traverseExps3(arguments, f);
    case Sequence(statements, pos): traverseExps3(statements, f);
    case If(condition, then, elseExp, pos): 
      traverseExp3(condition, f);
      traverseExp3(then, f);
      traverseExp3(elseExp, f);
    case Not(e, pos): traverseExp3(e, f);
    case Negate(e, pos): traverseExp3(e, f);
    case Multiply(e1, e2, pos): traverseExp3(e1, f); traverseExp3(e2, f);
    case Divide(e1, e2, pos): traverseExp3(e1, f); traverseExp3(e2, f);
    case Modulo(e1, e2, pos): traverseExp3(e1, f); traverseExp3(e2, f);
    case Plus(e1, e2, pos): traverseExp3(e1, f); traverseExp3(e2, f);
    case Minus(e1, e2, pos): traverseExp3(e1, f); traverseExp3(e2, f);
    case Equal(e1, e2, pos): traverseExp3(e1, f); traverseExp3(e2, f);
    case NotEqual(e1, e2, pos): traverseExp3(e1, f); traverseExp3(e2, f);
    case LessThan(e1, e2, pos): traverseExp3(e1, f); traverseExp3(e2, f);
    case LessEqual(e1, e2, pos): traverseExp3(e1, f); traverseExp3(e2, f);
    case GreaterThan(e1, e2, pos): traverseExp3(e1, f); traverseExp3(e2, f);
    case GreaterEqual(e1, e2, pos): traverseExp3(e1, f); traverseExp3(e2, f);
    case And(e1, e2, pos): traverseExp(e1, f); traverseExp3(e2, f);
    case Or(e1, e2, pos): traverseExp(e1, f); traverseExp3(e2, f);
    case Field(call, name, pos): traverseExp3(call, f);
    case Cast(value, fromtype, totype, pos): traverseExp3(value, f);
    case Switch(e, type, cases, p):
      traverseExp3(e, f);
      for (c in cases) {
        traverseExp3(c.body, f);
      }
    case SimpleSwitch(e, cases, p):
      traverseExp3(e, f);
      for (c in cases) {
        traverseExp3(c.body, f);
      }
    case SyntaxError(e, p): 
    case StackSlot(q0, q1, q2): 
    case NativeClosure(args, fn, pos): 
    case Native(name, io, args, result, defbody, pos):
      if (defbody != null) traverseExp3(defbody, f);
    case ConstantNative(value, pos):
    }
    f(e);
  }

  static public function traverseExps3(es : FlowArray<Flow>, f : Flow -> Void) : Void {
    for (e in es) {
      traverseExp3(e, f);
    }
  }

  static public function size(e : Flow) : Int {
    var i = 0;
    traverseExp(e, function (e) {++i;});
    return i;
  }
	
  static public function mapType(t : FlowType, f : FlowType -> FlowType) : FlowType {
    return f(
             switch (t) {
             case TVoid: t;
             case TBool: t;
             case TInt: t;
             case TDouble: t;
             case TString: t;
             case TReference(t): TReference(mapType(t, f));
             case TPointer(t): TPointer(mapType(t, f));
             case TArray(t): TArray(mapType(t, f));
             case TFunction(args, returns): TFunction(mapTypes(args, f), mapType(returns, f));
             case TStruct(n, args, max): TStruct(n, mapTypedecs(args, f), max);
             case TUnion(min, max): TUnion(mapTypeHash(min, f), mapTypeHash(max, f));
             case TTyvar(ref): t; // do not recurse on any instantiated type here; if
               // you want that, you must do it explicitly in f()
             case TBoundTyvar(i): t;
             case TFlow: t;
             case TNative: t;
             case TName(n, args): TName(n, mapTypes(args, f));
             });
  }

  static public function mapTypeHash(h : Map<String, FlowType>, f : FlowType -> FlowType) : Map<String, FlowType> {
    return mapHash(h, function (t) {return mapType(t, f);});
  }
	
  static public function mapTypes(ts : FlowArray<FlowType>, h : FlowType -> FlowType) : FlowArray<FlowType> {
    if (ts.length == 0) return NO_TYPES;
    return map(ts, function (t) {return mapType(t, h);});
  }

  private static var NO_TYPES : FlowArray<FlowType> = new FlowArray();

  static public function mapHash<X, Y>(ts : Map<String, X>, f : X -> Y) : Map<String, Y> {
    if (ts == null) return null;
    var h = new Map<String, Y>();
  #if neko
    var hh = untyped h.h;
    untyped __dollar__hiter(ts.h,function(k,v) {
      untyped __dollar__hset(hh,k,f(v),null);
    });
  #else
    for (s in ts.keys()) {
      h.set(s, f(ts.get(s)));
    }
  #end
    return h;
  }

  static public function iterhash<X>(h : Map<String, X>, f : X -> Void) : Void {
  #if neko
    untyped __dollar__hiter(h.h,function(_,v) { f(v); });
  #else
    for (v in h.iterator()) f(v);
  #end
  }

  static public function iterhashpairs<X>(h : Map<String, X>, f : String -> X -> Void) : Void {
  #if neko
    untyped __dollar__hiter(h.h,function(k,v) { f(new String(k), v); });
  #else
    for (k in h.keys()) f(k, h.get(k));
  #end
  }

  static public function mergehash<R,X,Y>(out : Map<String, R>, in1 : Map<String, X>, in2 : Map<String, Y>, f : X -> Y -> Null<R>)
  {
    if (untyped in1 == out) throw "cannot write and iterate at the same time";
  #if neko
    var oh = untyped out.h;
    var in2h = untyped in2.h;
    untyped __dollar__hiter(in1.h,function(k,v) {
      // By keeping k private, we avoid allocating String objects
      var v2 = untyped __dollar__hget(in2h,k,null);
      var r = f(v, v2);
      if (r != null)
        untyped __dollar__hset(oh,k,r,null);
    });
  #else
    for (k in in1.keys()) {
      var r = f(in1.get(k), in2.get(k));
      if (r != null)
        out.set(k, r);
    }
  #end
  }

  static public function hashlength<X>(h : Map<String, X>) : Int {
  #if neko
    return untyped __dollar__hcount(h.h);
  #else
    var n = 0;
    for (s in h.iterator()) {
      ++n;
    }
    return n;
  #end
  }

  static public function copyhash<X>(h : Map<String, X>) : Map<String, X> {
    var result = new Map<String, X>();
  #if neko
    var rh = untyped result.h;
    untyped __dollar__hiter(h.h,function(k,v) {
      untyped __dollar__hset(rh,k,v,null);
    });
  #else
    for (s in h.keys()) {
      result.set(s, h.get(s));
    }
  #end
    return result;
  }

  static public function emptyHash<X>(h : Map<String, X>) : Bool {
  #if neko
    return hashlength(h) == 0;
  #else
    return ! h.iterator().hasNext();
  #end
  }
	
  static public function mapTypedecs(tds : FlowArray<MonoTypeDeclaration>, h : FlowType -> FlowType) : FlowArray<MonoTypeDeclaration> {
    if (tds.length == 0) return NO_TYPEDECS;
    return map(tds, function (td) {return mapTypedec(td, h);});
  }

  private static var NO_TYPEDECS : FlowArray<MonoTypeDeclaration> = new FlowArray();

  inline static public function mapTypedec(td : MonoTypeDeclaration, f : FlowType -> FlowType) : MonoTypeDeclaration {
    return {name: td.name, type: mapType(td.type, f), position: td.position, is_mutable: td.is_mutable};
  }
	
  inline static public function map<X, Y>(xs : FlowArray<X>, g : X -> Y) : FlowArray<Y> {
    var ys = new FlowArray();
  #if neko
    untyped ys.__a = neko.NativeArray.alloc(xs.length);
  #end
    for (x in xs) {
      ys.push(g(x));
    }
    return ys;
  }

  static public function forAll<X>(xs : FlowArray<X>, predicate : X -> Bool) : Bool {
    for (x in xs) {
      if (! predicate(x)) {
        return false;
      }
    }
    return true;
  }
	
  static public function arrayFromIterator<X>(it : Iterator<X>) : FlowArray<X> {
    var xs = new FlowArray();
    for (x in it) {
      xs.push(x);
    }
    return xs;
  }

	
  // Make a typescheme from a type by generalising ALL tyvars.  Note that is wrong to
  // do, if the tyvars are not free in the current type environment.  In that case you
  // must generalise only those that are free.  So quantify() can only be used when there
  // is no type environment or we know for sure all tyvars in the type are free.  We can
  // know this for instance when the type is a declared type and thus the tyvars are
  // explicit by the user.
  inline static public function quantify(t : FlowType) : TypeScheme {
    return if (t == null) null else {tyvars: boundtyvars(t), type: t};
  }

  // replace tyvars (making the wild assumption none are aliased to something in the
  // environment!) with boundtyvars.
  static public function generalise(t : FlowType) : TypeScheme {
    if (t == null) return null;
    bounds = new FlowArray<Int>();
    n = 0;
    var t2 = mapType(t, replace);
    return {tyvars: bounds, type: t2};
  }

  static var bounds : FlowArray<Int> = null;
  static var n : Int;
	
  static function replace(t3 : FlowType) : FlowType {
    switch (t3) {
    case TTyvar(alpha): {
      var beta = TypeEnvironment.findTyvar(alpha);
      if (beta.type == null) {
        // uninstantiated, so instantiate it to a new TBoundTyvar
        var bound = TBoundTyvar(n);
        bounds.push(n);
        n++;
        beta.type = bound;	  
      } else {
        return mapType(beta.type, replace);
      }
    }
    default:
    }
    return t3;			
  }
	
  static public function tyvars(t : FlowType) : FlowArray<FlowTyvar> {
    var result = new FlowArray();
    traverseType(t, function (t) {
        switch (t) {
        case TTyvar(ref): result.push(ref);
        default:
        }});
    return result;
  }

  static public function boundtyvars(t : FlowType) : FlowArray<Int> {
    var result = new FlowArray();
    traverseType(t, function (t) {
        switch (t) {
        case TBoundTyvar(i): insertInt(result, i);
        default:
        }});
    return result;
  }
	
  static public function insertInt(xs : FlowArray<Int>, x : Int) : Void {
    // Note, we got a crash in flash when trying to do this with insertElement<X>
    // which was polymorphic in the element type.  So do not try that again.
    for (x1 in xs) {
      if (x == x1) return;
    }
    xs.push(x);
  }

  // replace all occurrences of the bound tyvars with fresh tyvars; throws if the number
  // of args is not the same as the number of bound tyvars in the typescheme
  static public function instantiateTo(sigma : TypeScheme, args : FlowArray<FlowType>) : FlowType {
    if (sigma.tyvars.length != args.length) {
      throw 'instantiateTo ' + sigma + ' wrong number arguments ' + args;
    }
    var h = new Map<Int, FlowType>();
    for (i in 0...args.length) {
      h.set(sigma.tyvars[i], args[i]);
    }
    return instantiateFromHash(sigma, h);
  }
	
  // replace all occurrences of the bound tyvars with fresh tyvars
  static public function instantiate(sigma : TypeScheme) : FlowType {
    var h = new Map<Int, FlowType>();
    for (tyvar in sigma.tyvars) {
      h.set(tyvar, newTyvar());
    }
    return instantiateFromHash(sigma, h);
  }

  static function instantiateFromHash(sigma : TypeScheme, h : Map<Int, FlowType>) : FlowType {
    return instantiateFromHash0(sigma.type, h);
  }

  static function instantiateFromHash0(t : FlowType, h : Map<Int, FlowType>) : FlowType {
    /*if (debug) {
      var s = 'instantiateFromHash0 ' + t;
      for (k in h.keys()) {
      s += '\n  ' + k + '->' + h.get(k);
      }
      trace(s);
      }
    */
    return mapType(t, function (t) {return switch (t) {
        case TBoundTyvar(i): h.get(i);
        case TTyvar(alpha):
          var beta = TypeEnvironment.findTyvar(alpha);
          if (beta.type == null) t else instantiateFromHash0(beta.type, h);
          // also replace TBoundTyvar inside instantiated TTyvars, otherwise we end
          // up with types with TBoundTyvars in them.  There can be instantiated
          // TTyvars in type schemes as a residue from type application T<int>
          // (TName("T", [int])).
        default: t;
        }});
  }

  static public function instantiate1(sigma : TypeScheme) : FlowType {
    return if (isPolymorphic(sigma)) instantiate(sigma) else sigma.type; 
  }
	
  // turn a type without tyvars into a type scheme trivially, i.e., make a monomorphic type
  inline static public function mono(t : FlowType) : TypeScheme {
    return {tyvars: notyvars, type: t};
  }
  static private var notyvars : FlowArray<Int> = new FlowArray();
	
  // Get the type from a type scheme that we know is really a monotype.  If t is not, throw.
  static public function checkMono(t : TypeScheme) : FlowType {
    if (isPolymorphic(t)) throw 'Expected monomorphic type, but found polymorphic type "'
                            + Prettyprint.prettyprintTypeScheme(t) + '"';
    return t.type;
  }

  inline static public function isPolymorphic(sigma : TypeScheme) : Bool {
    return sigma.tyvars.length > 0;
  }

  inline static public function newTyvar() : FlowType {
    return TTyvar(mkTyvar(null));
  }

  inline static public function typename(t : FlowType) : String {
    return if (t == null) null
      else switch (t) {
        case TName(n, args): n;
        default: '';
        }
  }

  // fieldNames(Some(value: ?)) = ["value"]
  static public function fieldNames(structType : FlowType) : FlowArray<String> {
    var ss = new FlowArray();
    switch (structType) {
    case TStruct(sn, args, max): {
      for (td in args) {
        ss.push(td.name);
      }
    }
    default:
      throw 'impossible: fieldNames';
    }
    return ss;
  }
	
  // Calculate an approximation of whether it is best to subtype a fresh uninstantiated
  // tyvar against this type first or not.  Used to choose a good order in which to call
  // subtype() (e.g., in typeMatch()).
  static public function isTighter(t : FlowType) : Bool {
	  var tu = untyvar(t);
	  var b = true;
	  if (tu == null) {
		  // regard uninstantiated tyvars as not tight
		  return false;
	  }
	  traverseType(tu, function (t) {
		  switch (t) {
			  case TUnion(min, max): if (min != max) b = false;
			  case TStruct(sn, args, max): if (! max) b = false;
			  //case TTyvar(alpha): if (TypeEnvironment.findTyvar(alpha).type == null) b = false;
			  default:
		  }});
	  return b;
  }

// check whether t is a structtype that cannot be changed further
  static public function isFinalStructtype(t : FlowType) : Bool {
    var tu = untyvar(t);
    return if (tu == null) false else
                             switch (tu) {
                             case TUnion(min, max): min == max;
                             case TStruct(sn, args, max): max;
                             case TName(n, args): true;
                             default: false;
                             };
  }


	static public function typeDepth(t : FlowType) : Int {
		return if (t == null) 0 else
		switch (t) {
			case TVoid: 1;
			case TBool: 1;
			case TInt: 1;
			case TDouble: 1;
			case TString: 1;
			case TReference(t): 1 + typeDepth(t);
			case TPointer(t): 1 + typeDepth(t);
			case TArray(t): 1 + typeDepth(t);
			case TFunction(args, returns): 1 + typeDepths(args) + typeDepth(returns);
			case TStruct(n, args, max):
				var n = 1;
				for (td in args) {
					n += typeDepth(td.type);
				}
				n;
			case TUnion(min, max): 1 + typeDepthHash(min) + typeDepthHash(max);
			case TTyvar(ref): if (ref.type == null) 0 else typeDepth(ref.type);
			case TBoundTyvar(i): 1;
			case TFlow: 1;
			case TNative: 1;
			case TName(n, args): 1 + typeDepths(args);
		}
	}

	static public function typeDepthHash(h : Map<String, FlowType>) : Int {
		var n = 0;
		if (h != null) {
			for (t in h) {
				n = n + typeDepth(t);
			}
		}
		return n;
	}

	static public function typeDepths(ts : FlowArray<FlowType>) : Int {
		var n : Int = 0;
		for (t in ts) {
			n = n + typeDepth(t);
		}
		return n;
	}

	
  // What is this type really; null if it is an uninstantiated tyvar
  inline static public function untyvar(t : FlowType) : FlowType {
    return TypeEnvironment.untyvar(t);
  }

  inline static public function isFlow(t : FlowType) : Bool {
    return TypeEnvironment.untyvar(t) == TFlow;
  }

  static public function isUninstantiated(alpha : {type: FlowType}) : Bool {
    var t = alpha.type;
    return t == null || switch (t) {
    case TUnion(min, max): max == null && emptyHash(min);
    default: false;
    };
  }

  static public function member<X>(x0 : X, xs : FlowArray<X>) : Bool {
    if (xs == null) {
      return false;
    }
    for (x1 in xs) {
      if (x0 == x1) {
        return true;
      }
    }
    return false;
  }


  static public function memberString(x0 : String, xs : FlowArray<String>) : Bool {
    for (x1 in xs) {
      if (x0 == x1) {
        return true;
      }
    }
    return false;
  }

  static public function repeat(n : Int, s : String) : String {
    var r = '';
    for (i in 0...n) {
      r += s;
    }
    return r;
  }

  static public function findSimpleCase(cases : FlowArray<SimpleCase>, structname : String) : SimpleCase {
    var c = findSimpleCase0(cases, structname);
    return if (c == null) findSimpleCase0(cases, 'default') else c;
  }

  static function findSimpleCase0(cases : FlowArray<SimpleCase>, name : String) : SimpleCase {
    for (c in cases) {
      if (c.structname == name) {
        return c;
      }
    }
    return null;
  }

  static private var uniq = 0;
  static public function lambda(arguments : FlowArray<String>, type : FlowTypePos, body : Flow, pos : Position) {
    return Flow.Lambda(arguments, type, body, ++uniq, pos);
  }
}
