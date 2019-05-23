import Flow;
import FlowInterpreter;
import Position;

class Prettyprint {
	public static function print(code : Flow) : String {
		var r = prettyprint(code, '');
		if (r.length > 500) {
			r = r.substr(0, 500) + '...';
		}
		var pos = getLocation(code);
		if (pos != 'unknown') {
			return '/*' + pos + '*/ ' + r;
		}
		return r;
	}
	
	public static function getLocation(code : Flow) : String {
		return position(FlowUtil.getPosition(code));
	}

	static public function position(pos : Position) : String {
	  //return if (pos != null) (if (pos.f.indexOf('/') != -1) pos.f else 'flow/' + pos.f) + ':' + pos.l else 'unknown';
		return if (pos != null) pos.f + ':' + pos.l else 'unknown';
	}

	// The optional normalise function is for looking up TNames to print their definition
	// where available.  bracket=true means wrap the type in parens to indicate binding,
	// i.e., so (a->b)->c is prettyprinted that way & not as a->b->c.  Atomic types of
	// course need no brackets, nor do arrays, as they are naturally bracketed by the [ ].
	public static function prettyprintTypePos(type : FlowTypePos, ?normalise : FlowType -> FlowType, ?bracket : Bool, ?fields: Bool = true) : String {
	    return prettyprintType(PositionUtil.getValue(type), normalise, bracket, fields);
	}

	public static function ppTD(td : TypeDeclaration, ?normalise : FlowType -> FlowType, ?bracket : Bool, ?fields: Bool = true) {
		return if (td == null) 'null' else {
			var type = td.type.type;
			switch (type) {
			case TVoid: td.name + " : void";
			case TBool: td.name + " : bool";
			case TInt: td.name + " : int";
			case TDouble: td.name + " : double";
			case TString: td.name + " : string";
			case TReference(type): "ref " + td.name + " : " + prettyprintType(PositionUtil.getValue(type), normalise, true, fields);
			case TPointer(type): "pointer to "+ prettyprintType(PositionUtil.getValue(type), normalise, true, fields);
			case TArray(type): td.name + " : [" + prettyprintType(PositionUtil.getValue(type), normalise, false, fields) + "]";
			case TFunction(args, returns): 
				var r = td.name + '(';
				var sep = '';
				for (a in args) {
					// in the case of only one argument, we need brackets around that argument in case it is a function
				    r += sep + prettyprintType(PositionUtil.getValue(a), normalise, args.length == 1, fields);
					sep = ', ';
				}
				// no brackets around the return type: ok to prettyprint a->(b->c) as a->b->c.
				r += ') -> ' + prettyprintType(PositionUtil.getValue(returns), normalise, false, fields);
				if (bracket == true) '(' + r + ')' else r;
			case TStruct(structname, args, max): 
				var r = structname;
				if (fields) {
					r += '(';
					var sep = '';
					for (a in args) {
					  r += sep + a.name + ' : ' + prettyprintType(PositionUtil.getValue(a.type), normalise, false, false);
						sep = ', ';
					}
					r += ')';
				}
				r;
			case TUnion(min, max): td.name + ' ::= ' + ppUnion(min, max, false, ', ');
			case TTyvar(ref): if (ref.type == null) '#' + lookupAlpha(ref)
							  else prettyprintType(ref.type, normalise, bracket, fields);
			case TBoundTyvar(i): FlowUtil.repeat(i + 1, '?');
			case TFlow: "flow";
			case TNative : "native";
			case TName(name, args):
				prettyprintTname(name, args, normalise);
			}
		}
	}

	public static function prettyprintType(type : FlowType, ?normalise : FlowType -> FlowType, ?bracket : Bool, ?fields: Bool = true) : String {
		return if (type == null) 'null' else
		switch (type) {
		case TVoid: "void";
		case TBool: "bool";
		case TInt: "int";
		case TDouble: "double";
		case TString: "string";
		case TReference(type): "ref " + prettyprintType(PositionUtil.getValue(type), normalise, true, fields);
		case TPointer(type): "pointer to "+ prettyprintType(PositionUtil.getValue(type), normalise, true, fields);
		case TArray(type): "[" + prettyprintType(PositionUtil.getValue(type), normalise, false, fields) + "]";
		case TFunction(args, returns): 
			var r = '(';
			var sep = '';
			for (a in args) {
				// in the case of only one argument, we need brackets around that argument in case it is a function
			    r += sep + prettyprintType(PositionUtil.getValue(a), normalise, args.length == 1, fields);
				sep = ', ';
			}
			// no brackets around the return type: ok to prettyprint a->(b->c) as a->b->c.
			r += ') -> ' + prettyprintType(PositionUtil.getValue(returns), normalise, false, fields);
			if (bracket == true) '(' + r + ')' else r;
		case TStruct(structname, args, max): 
			var r = structname;
			if (fields) {
				r += '(';
				var sep = '';
				for (a in args) {
				  r += sep + a.name + ': ' + prettyprintType(PositionUtil.getValue(a.type), normalise, false, false);
					sep = ', ';
				}
				r += ')';
			}
			r;
		case TUnion(min, max): ppUnion(min, max, fields);
		case TTyvar(ref): if (ref.type == null) '#' + lookupAlpha(ref)
						  else prettyprintType(ref.type, normalise, bracket, fields);
		case TBoundTyvar(i): FlowUtil.repeat(i + 1, '?');
		case TFlow: "flow";
		case TNative : "native";
		case TName(name, args):
			prettyprintTname(name, args, normalise);
		}
	}

	// if !fields, prettyprint without distinguishing min & max.
	static public function ppUnion(min : Map<String,FlowType>, max : Map<String,FlowType>, ?fields : Bool = true, ?sep = '|') : String {
		return 
		if (fields) {
			if (min == null) '_any struct'
			else if (FlowUtil.emptyHash(min)) '<' + ppUnion0(max, fields, sep)
			else if (max == null) ppUnion0(min, fields, sep) + '..'
			else if (max == min) '_' + ppUnion0(max, fields, sep)
			else {
				var s1 = ppUnion0(min, fields, sep);
				var s2 = ppUnion0(max, fields, sep);
				if (s1 == s2) '_' + s1;
				else '(' + s1 + '<' + s2 + ')';
			}
		} else ppUnion0(if (min == null || FlowUtil.emptyHash(min)) max else min, false, sep);
	}

	static public function ppUnion0(structs : Map<String,FlowType>, ?fields : Bool = true, ?sep = '|') : String {
		return (if (structs == null) 'any struct'
				else if (! structs.iterator().hasNext()) 'no struct';
				else {
					var r = '';
					var sepLoc = '';
					var sns = [];
					for (k in structs.keys()) {
						sns.push(k);
					}
					sns.sort(function (a1, a2) {return if (a1 < a2) -1 else if (a1 > a2) 1 else 0;});
					for (a in sns) {
						r += sepLoc + (if (FlowInterpreter.debug > 1) prettyprintType(structs.get(a), null, null, fields) else a);
						sepLoc = sep;
					}
					// if we are debugging, give a hint that it is a TUnion rather than just a TStruct
					if (FlowInterpreter.debug > 1) '{' + r + '}' else r;
				});
	}
	
	static public function prettyprintTypeScheme(scheme : TypeScheme, ?normalise : FlowType -> FlowType, ?fields : Bool = true) : String {
		return if (scheme == null) 'null' else
			(if (FlowInterpreter.debug > 1) (('/\\' + if (scheme.tyvars == null || scheme.tyvars.length == 0) '' else scheme.tyvars.join(' '))
											 + '.' + prettyprintTypePos(scheme.type, normalise, false, fields))
			 else ((if (scheme.tyvars == null || scheme.tyvars.length == 0) '' else '/\\' + scheme.tyvars.join(' ') + '.')
				   + prettyprintTypePos(scheme.type, normalise, false, fields)));
	}
	
	static public function prettyprintTname(n : String, args : FlowArray<FlowTypePos>, normalise) : String {
		var norm = '';
		/*
		if (normalise != null) {
			try {
				norm = prettyprintType(normalise(TName(n, args)), normalise, false, true);
			} catch (foo : Dynamic) {
			}
		}
		*/
		var d = FlowInterpreter.debug > 1;
		return n + (if (d) '_' else '')
			   + (if (args.length == 0) (if (d) '<>' else '')
				  else ('<' + FlowUtil.map(
										   args, function (t) {return prettyprintType(PositionUtil.getValue(t), normalise, false, true);}).join(', ') + '>'))
			   /*Asger hates it: + (if (norm != '' && norm != n) ' (=' + norm + ')' else '')*/;
	}
	
	public static function prettyprint(code : Flow, indent : String = '', bracket : Bool = false) : String {
		return if (code == null) "" else 
		switch (code) {
		// case SyntaxError(s, pos) : 
		case ConstantVoid(pos): '{}';
		case ConstantBool(value, pos): '' + value;
		case ConstantI32(value, pos):  '' + value;
		case ConstantDouble(value, pos): 
			var s = '' + value;
			s + if (s.indexOf('.') < 0) '.0' else '';
		case ConstantString(value, pos):
			var s = StringTools.replace(value, "\\", "\\\\");
			s = StringTools.replace(s, "\"", "\\\"");
			s = StringTools.replace(s, "\n", "\\n");
			s = StringTools.replace(s, "\t", "\\t");
			'"' + s + '"';
		case ConstantArray(value, pos):
			var r = '[';
			var sep = '';
			for (v in value) {
				r += sep + prettyprint(v, indent + ' ', false);
				sep = ', ';
			}
			r + ']';
		case ConstantStruct(name, values, pos):
			if (name == "DList") {
				"DList(<recursive type>)";
			} else {
				var r = name + '(';
				var sep = '';
				for (v in values) {
					r += sep + prettyprint(v, '', false);
					sep = ', ';
				}
				r + ')';
			}
		case ArrayGet(array, index, pos):
			prettyprint(array, indent, bracket) + '[' + prettyprint(index, indent, false) + ']';
		case VarRef(name, pos):
			name;
		case RefTo(value, pos):
			'ref ' + prettyprint(value, indent, true);
		case Pointer(pointer, pos):
			// Notice that the interpreter uses a function to convert all pointers to RefTo constructs
			// since otherwise, we needed to have the entire memory map sent into this function.
			// See FlowInterpreter.replacePointersWithReferences called by FlowInterpreter.toString.
			'pointer(' + pointer + ')';
		case Deref(pointer, pos):
			'^' + prettyprint(pointer, indent, bracket);
		case SetRef(pointer, value, pos): binop(' := ', pointer, value, indent, bracket);
		case SetMutable(pointer, field, value, pos):
			binop(' ::= ', Field(pointer, field, pos), value, indent, bracket);
		
		case Let(name, sigma, value, scope, pos):
			tuborg(true, name + (if (sigma != null) ' : ' + prettyprintTypeScheme(sigma) + ' ' else '')
				 + '=' + prettyprint(value, indent, true) 
				 + '; ' + prettyprint(scope, indent, false));
			
		case Lambda(arguments, type, body, _, pos):
			var r = '\\';
			var sep = '';
			for (a in arguments) {
					r += sep + a;
				sep = ', ';
			}
			r += ' -> ' + prettyprint(body, indent, bracket);
			r;
		case Closure(body, environment, pos):
			'[|' + prettyprint(body, indent, false) + ' | ' + ppEnvironment(environment) + ' |]';
		case Call(closure, arguments, pos):
			var c = prettyprint(closure, indent, true) + '(';
			var sep = '';
			for (a in arguments) {
				c += sep + prettyprint(a, indent, false);
				sep = ', ';
			}
			c + ')';

		case Sequence(statements, pos):
			var r = '{';
			for (a in statements) {
				r += prettyprint(a, indent + '  ', false) + ';\n' + indent;
			}
			r + '}';
		case If(condition, then, elseExp, pos): 
			var r = "if (" + prettyprint(condition, indent, false) + ') ';
			r += prettyprint(then, indent, false);
			r += ' else ' + prettyprint(elseExp, indent, bracket);
			r;
		case Not(e, pos): '!' + prettyprint(e, indent, bracket);
		case Negate(e, pos): '-' + prettyprint(e, indent, bracket);
			case Multiply(e1, e2, pos): binop('*', e1, e2, indent, bracket);
			case Divide(e1, e2, pos): binop('/', e1, e2, indent, bracket);
		case Modulo(e1, e2, pos): binop('%', e1, e2, indent, bracket);
		case Plus(e1, e2, pos): binop('+', e1, e2, indent, bracket);
		case Minus(e1, e2, pos): binop('-', e1, e2, indent, bracket);
		case Equal(e1, e2, pos):  binop('==', e1, e2, indent, bracket);
		case NotEqual(e1, e2, pos):  binop('!=', e1, e2, indent, bracket);
		case LessThan(e1, e2, pos): binop('<', e1, e2, indent, bracket);
		case LessEqual(e1, e2, pos):  binop('<=', e1, e2, indent, bracket);
		case GreaterThan(e1, e2, pos):  binop('>', e1, e2, indent, bracket);
		case GreaterEqual(e1, e2, pos): binop('>=', e1, e2, indent, bracket);
		case And(e1, e2, pos):  binop('&&', e1, e2, indent, bracket);
		case Or(e1, e2, pos): binop('||', e1, e2, indent, bracket);
		case Field(call, name, pos): '(' + prettyprint(call, indent, bracket) + "." + name + ')';
		case Cast(value, fromtype, totype, pos):
			 'cast(' + prettyprint(value, '', false) + " : "
					 + prettyprintTypePos(fromtype, null, true) + " to "
					 + prettyprintTypePos(totype, null, false) + ")";
		case Switch(e0, type, cases, p):
				var r = '\n' + indent + 'switch (' + prettyprint(e0, indent, false) 
					+  (if (type == null) '' else ' : ' + prettyprintTypePos(type)) + ') {';
				for (c in cases) {
					r += '\n' + indent + '    ' + c.structname + '(' + c.args.join(', ') + '): ' + prettyprint(c.body, indent + '    ', false);
				}
				r += '\n' + indent + '}';
				r;
		case SimpleSwitch(e0, cases, p):
				var r = '\n' + indent + 'switch (' + prettyprint(e0, indent, false) + ') {';
				for (c in cases) {
					r += '\n' + indent + '    ' + c.structname + ': ' + prettyprint(c.body, indent + '    ', false);
				}
				r += '\n' + indent + '}';
				r;
			
		case SyntaxError(e, p):
			'(' + Serialize.serialize(code, indent) + ')';
		case StackSlot(q0, q1, q2):
			'(' + Serialize.serialize(code, indent) + ')';
		case NativeClosure(args, fn, pos):
			'$'+ 'closure(' + Serialize.serialize(code, indent) + ')';
		case Native(name, io, args, result, defbody, pos):
			var r = 'native ' + (if (StringTools.startsWith(name, 'Native.')) name.substr(7) else name);
			if (defbody == null) r else r + ' = ' + prettyprint(defbody, indent, bracket);
		case ConstantNative(value, pos):
			'$'+ 'const(' + Serialize.serialize(code, indent) + ')';
		}
	}

	static function binop(o : String, e1 : Flow, e2 : Flow, indent : String, bracket : Bool) : String {
		return wrap(bracket, prettyprint(e1, indent, false) + o + prettyprint(e2, indent, false));
	}

	static function wrap(b, s) : String {
		return if (b) '(' + s + ')' else s;
	}

	static function tuborg(b, s) : String {
		return if (b) '{' + s + '}' else s;
	}

	static function ppEnvironment(environment : Environment) : String {
		var r = '';
		var sep = '';
		for (v in environment.variables.keys()) {
			var e = environment.variables.get(v);
			var s = prettyprint(e, '', false);
			if (s.length > 18) {
				s = s.substr(0, 12) + '..';
			}
			r += sep + v + ': ' + s;
			sep = ', ';
		}
		return if (r == '') '{}' else r;
	}
	
	// A quick and short string for each AST node (useful for profiling)
	static public function flowASTKind(code: Flow) : String {
		if (code == null) return "" else 
		return switch (code) {
		case SyntaxError(s, pos) : "SyntaxError";
		case ConstantVoid(pos): '{}';
		case ConstantBool(value, pos): 'bool';
		case ConstantI32(value, pos):  'int';
		case ConstantDouble(value, pos): 'double';
		case ConstantString(value, pos): 'string';
		case ConstantArray(value, pos): '[]';
		case ConstantStruct(name, values, pos): 'struct';
		case ArrayGet(array, index, pos): 'a[i]';
		case VarRef(name, pos): 'a';
		case RefTo(value, pos): 'ref';
		case Pointer(pointer, pos): 'pointer';
		case Deref(pointer, pos): '^';
		case SetRef(pointer, value, pos): ':=';
		case SetMutable(pointer, field, value, pos): '::=';
		case Let(name, sigma, value, scope, pos): '=';
		case Lambda(arguments, type, body, _, pos): "\\";
		case Closure(body, environment, pos): "[||]";
		case Call(closure, arguments, pos): "f()";
		case Sequence(statements, pos): '{ }';
		case If(condition, then, elseExp, pos): 'if';
		case Not(e, pos): '!';
		case Negate(e, pos): '-x';
		case Multiply(e1, e2, pos): '*';
		case Divide(e1, e2, pos): '/';
		case Modulo(e1, e2, pos): '%';
		case Plus(e1, e2, pos): '+';
		case Minus(e1, e2, pos): '-';
		case Equal(e1, e2, pos): '==';
		case NotEqual(e1, e2, pos): '!=';
		case LessThan(e1, e2, pos): '<';
		case LessEqual(e1, e2, pos): '<=';
		case GreaterThan(e1, e2, pos): '>';
		case GreaterEqual(e1, e2, pos): '>=';
		case And(e1, e2, pos): '&&';
		case Or(e1, e2, pos): '||';
		case Field(call, name, pos): ".";
		case Cast(value, fromtype, totype, pos): 'cast';
		case Switch(e0, type, cases, p): 'switch';
		case SimpleSwitch(e0, cases, p): 'sswitch';
		case StackSlot(q0, q1, q2): 'stackslot';
		case NativeClosure(args, fn, pos): 'nativeclosure';
		case Native(name, io, args, result, defbody, pos): 'native';
		case ConstantNative(value, pos): 'native constant';
		}
	}

	// Tyvar tracker (hack)
	//static var alphasSeen : Array<FlowTyvar>;

	// Try to give a sensible number for a tyvar, so that we can prettyprint it
	static function lookupAlpha(alpha : FlowTyvar) : Int {
		var beta = TypeEnvironment.findTyvar(alpha);
		return beta.id;
		/*if (alphasSeen == null) {
			alphasSeen = [];
		}
		for (i in 0...alphasSeen.length) {
			if (beta == alphasSeen[i]) return i;
		}
		alphasSeen.push(beta);
		return alphasSeen.length - 1;*/
	}
}
