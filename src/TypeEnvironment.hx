import Flow;
import FlowArray;
import Position;

class TypeEnvironment {
	public function new() {
		variables = new Map();
		used_vars = new Map();
		structTypes = new Map();
		structFields = new Map();
		typedefs = new Map();
		normalise_cache = new Map();
	}
	public function add(e : TypeEnvironment) : TypeEnvironment {
		var overridden = new TypeEnvironment();
		for (variableName in e.variables.keys()) {
			var value = e.variables.get(variableName);
			// Save the original value to be able to restore this later
			if (variables.exists(variableName)) {
				overridden.variables.set(variableName, variables.get(variableName));
				if (used_vars.exists(variableName))
					overridden.used_vars.set(variableName, true);
			}
			variables.set(variableName, value);
			used_vars.remove(variableName);
		}
		return overridden;
	}
	public function retract(e : TypeEnvironment) : Void {
		for (variableName in e.variables.keys()) {
			var value = e.variables.get(variableName);
			if (value == null) {
				variables.remove(variableName);
			} else {
				variables.set(variableName, value);
			}
			if (e.used_vars.exists(variableName))
				used_vars.set(variableName, true);
			else
				used_vars.remove(variableName);
		}
	}
	
	public function serialize() : String {
		var r = "TypeEnvironment([";
		var sep = '';
		for (v in variables.keys()) {
			r += sep + v + ':' + variables.get(v);
			sep = '\n';
		}
		return r + '])';
	}
	public function lookup(name : String, ?use : Bool = true) : TypeScheme {
		var rv = variables.get(name);
		if (rv != null && use)
			used_vars.set(name, true);
		return rv;
	}
	public function isUsedVar(name : String) : Bool {
		return used_vars.exists(name);
	}
	public function define(name : String, value : TypeScheme) : Void {
		variables.set(name, value);
		used_vars.remove(name);
	}
	public function revoke(name : String) : Void {
		variables.remove(name);
		used_vars.remove(name);
	}

	public function pushdef(name : String, value : TypeScheme) 
		: { name: String, old: TypeScheme, used: Bool }
	{
		var rv = { name: name, old: variables.get(name), used: used_vars.exists(name) };
		define(name, value);
		return rv;
	}
	public function pushdefEnv(name : String, value : TypeScheme, save : TypeEnvironment)
	{
		save.variables.set(name, variables.get(name));
		if (used_vars.exists(name))
			save.used_vars.set(name, true);
		define(name, value);
	}
	public function popdef(info : { name: String, old: TypeScheme, used: Bool })
	{
		if (info.old != null)
			variables.set(info.name, info.old);
		else
			variables.remove(info.name);

		if (info.used)
			used_vars.set(info.name, true);
		else
			used_vars.remove(info.name);
	}

	// This finds a type that unifies the two types. It is strict in the sense that
	// it will not return flow for int/double and similar pairs eventhough flow would
	// be a unified type for those. This is because this is most useful. If you need
	// a unified type nomatter what, use laxlub.
	public function lub(t1 : FlowType, t2 : FlowType) : FlowType {
		if (FlowInterpreter.debug > 1) trace(FlowInterpreter.indent() + 'lub(' + (t1) + ',' + pt(t2) + '): now calling subtype:');
		var alpha = newTyvar();
/*
   This did not help.  Instead I call lub() twice in FlowInterpreter.comparableTypes()
		var ok = if (FlowUtil.isTighter(t1)) subtype(t2, alpha) && subtype(t1, alpha) else subtype(t1, alpha) && subtype(t2, alpha);
		var result = if (ok) alpha else null;
*/
		var result = if (subtype(t1, alpha) && subtype(t2, alpha)) alpha else null;
		if (FlowInterpreter.debug > 1) trace(FlowInterpreter.indent() + '  resulting in lub(' + pt(t1) + ',' + pt(t2) + ')==' + pt(result));
		return result;
	}

	
	// Checks whether two types are the same, and returns the most specific of them. If
	// incompatible, returns null.  (In other words, typeMatch returns the greatest lower
	// bound, as opposed to the least upper bound.)
	public function typeMatch(t1 : FlowType, t2 : FlowType) : FlowType {
		if (FlowInterpreter.debug > 1) {
			//trace(FlowInterpreter.indent() + 'intersect(' + ppUnion(t1) + ', ' + ppUnion(t2) + ')');
			FlowInterpreter.depth++;
		}
		var alpha = newTyvar();
		var ok = if (FlowUtil.isTighter(t1)) subtype(alpha, t1) && subtype(alpha, t2) else subtype(alpha, t2) && subtype(alpha, t1);
		var r = if (ok) alpha else null;
		if (FlowInterpreter.debug > 1) FlowInterpreter.depth--;
		return r;
	}	

	public function equalType(t1 : FlowType, t2 : FlowType) : Bool {
		return subtype(t1, t2) && subtype(t2, t1);
	}

	private var normalise_cache : Map<String, Map<String,FlowType>>;

	// If t is a type name return the type bound to it.  If the user has given type
	// arguments, instantiate them in the type: normalise(Maybe<int>) =
	// None|Some(value:int).  If the user did not provide type arguments, instantiate with
	// free tyvars:  normalise(Maybe) = None|Some(value:newTyvar()).  Will throw Mismatch
	// if the type name is undefined.
	public function normalise(t : FlowType) : FlowType {
		return switch (t) {
			case TName(n, args):
				var sigma = lookupType(n);
				if (args.length == 0) {
					FlowUtil.instantiate1(sigma);
				} else {
					if (sigma.tyvars.length != args.length) {
						// pt(t) here causes endless recursion
/*totodo comment in again once we have Behaviours as polymorphic types;
  until then, this error message is annoying because there are several places where
  Behaviour has arguments < >
						Errors.report(if (sigma.tyvars.length == 0) 
									  'Remove type arguments <...> as ' + n + ' is not a type function.';
									  else
									  'Give ' + sigma.tyvars.length + ' type arguments, not ' + args.length + ' to ' + n);
*/
						// error recovery: instantiate with fresh tyvars
						FlowUtil.instantiate1(sigma);
					} else {
						var rv = null;
						var key = new StringBuf();

						if (formatTypeKeys(args, key, COMMA)) {
							var n2 = key.toString();
							var tbl = normalise_cache.get(n);
							if (tbl == null)
								normalise_cache.set(n, tbl = new Map());
							rv = tbl.get(n2);
							if (rv == null)
								tbl.set(n2, rv = FlowUtil.instantiateTo(sigma, args));
						}
						//else trace('? ' + key.toString() + " @ " + Prettyprint.prettyprintType(t));

						// correct amount of type arguments provided, instantiate the type scheme to them
						if (rv == null)
							rv = FlowUtil.instantiateTo(sigma, args);

						rv;
					}
				}
			case TUnion(min, max): {
				isUnionReallyStruct(t, min, max);
			}
			default: t;
		}
	}

	private static var COMMA = ',';
	private static var NULLSTR = '';

	private function formatTypeKeys(args : FlowArray<FlowType>, buf : StringBuf, sep : String) : Bool {
		var cur = NULLSTR;
		for (a in args) {
			buf.add(cur);
			if (!formatTypeKey(a, buf))
				return false;
			cur = sep;
		}
		return true;
	}

	private static var NULL = 'null';
	private static var VOID = 'void';
	private static var BOOL = 'bool';
	private static var INT = 'int';
	private static var DOUBLE = 'double';
	private static var STRING = 'string';
	private static var FLOW = 'flow';
	private static var NATIVE = 'native';
	private static var REF = 'ref(';
	private static var PTR = 'ptr(';
	private static var ARR = '[';
	private static var RARR = '[';
	private static var LPAREN = '(';
	private static var RPAREN = ')';
	private static var RPARENFN = ')->';
	private static var UNION = '{';
	private static var UNIONSEP = '|';
	private static var RUNION = '}';
	private static var VAR = '#';
	private static var NAME = '<';
	private static var RNAME = '>';

	private function formatTypeKey(arg : FlowType, buf : StringBuf) : Bool {
		if (arg == null) {
			buf.add(NULL);
			return true;
		}
		switch (arg) {
		case TVoid: buf.add(VOID);
		case TBool: buf.add(BOOL);
		case TInt: buf.add(INT);
		case TDouble: buf.add(DOUBLE);
		case TString: buf.add(STRING);
		case TReference(type):
			buf.add(REF);
			if (!formatTypeKey(type, buf))
				return false;
			buf.add(RPAREN);
		case TPointer(type):
			buf.add(PTR);
			if (!formatTypeKey(type, buf))
				return false;
			buf.add(RPAREN);
		case TArray(type):
			buf.add(ARR);
			if (!formatTypeKey(type, buf))
				return false;
			buf.add(RARR);
		case TFunction(args, returns):
			buf.add(LPAREN);
			if (!formatTypeKeys(args, buf, COMMA))
				return false;
			buf.add(RPARENFN);
			if (!formatTypeKey(returns, buf))
				return false;
		case TStruct(structname, args, max):
			buf.add(structname);
			var sigma = getStruct(structname);
			if (sigma == null || FlowUtil.isPolymorphic(sigma))
				return false;
		case TUnion(min, max):
			if (min == null || max == null)
				return false;
			var ok = true;
			var sb1 = new StringBuf();
			var fmt = function(v) {
				sb1.add(UNIONSEP);
				if (!ok || !formatTypeKey(v, sb1))
					ok = false;
			}
			FlowUtil.iterhash(min, fmt);
			if (!ok) return false;
			var str = sb1.toString();
			buf.add(UNION);
			buf.add(str);
			if (max != min) {
				sb1 = new StringBuf();
				FlowUtil.iterhash(max, fmt);
				if (!ok || sb1.toString() != str)
					return false;
			}
			buf.add(RUNION);
		case TTyvar(ref):
			var final = findTyvar(ref);
			if (final.type == null)
				return false;
			buf.add(VAR);
			buf.add(final.id);
		case TBoundTyvar(i):
			return false;
		case TFlow:
			buf.add(FLOW);
		case TNative :
			buf.add(NATIVE);
		case TName(name, args):
			buf.add(name);
			buf.add(NAME);
			if (!formatTypeKeys(args, buf, COMMA))
				return false;
			buf.add(RNAME);
		}
		return true;
	}


	function isUnionReallyStruct(t : FlowType, min : Map<String, FlowType>, max : Map<String, FlowType>) : FlowType {
		if (FlowUtil.emptyHash(min) && max != null) {
			var c = 0;
			var l = null;
			for (m in max) {
				l = m;
				c++;
			}
			if (c == 1) return l;
			return t;
		} else {
			return t;
		}
	}

	// null if n is not a structname, otherwise TStruct(n, ...)
	public function getStruct(n : String) : TypeScheme {
		return structTypes.get(n);
	}
	
	public function isTypename(n : String) : Bool {
		var oe = getTypedef(n);
		return if (oe == null) false else switch (oe.expanded.type) {
			case TUnion(min, max): true;
			default: false;
		}
	}
	
	// Build structTypes, structFields & typedefs datastructures.  Call when you are
	// done calling define() on all topdecs, i.e., after linking & before typechecking.
	public function resolveStructs(debug : Int) {
		resolveTypedefs();
		if (debug > 1) {
			printTypedefs();
		}
		resolveFields();
	}

	// collect all structs Struct(field: ...) & unions T ::= Struct1, Struct2 in typedefs map
	function resolveTypedefs() {
		for (v in variables.keys()) {
			var sigma = variables.get(v);
			switch (sigma.type) {
				case TUnion(min, max):
					if (typedefs.exists(v)) {
						Errors.report('Struct union ' + pts(sigma) + ' multiply defined.');
					} else {
						typedefs.set(v, {declared: sigma, expanded: null, expanding: false});
					}
				case TStruct(sn, args, max):
					if (sn == v) {
						if (typedefs.exists(sn)) {
							Errors.report('Struct ' + pts(sigma) + ' already defined.');
						} else {
							typedefs.set(sn, {declared: sigma, expanded: null, expanding: false});
						}
					}
				default:
			}
		}

		// expand all references to other typedefs in typedefs to TStructs
		for (s in typedefs.keys()) {
			getTypedef(s);
		}
	}

	// aggregate some type info about fields in structs, so we can type e.field expressions
	function resolveFields() {
		var reserved = [ 
			"break", "case", "catch", "continue", "debugger", "default", "delete", 
			"do", "else", "finally", "for", "function", "if", "in", "instanceof", "new", "return", 
			"switch", "this", "throw", "try", "typeof", "var", "void", "while", "with",

			"class", "const", "enum", "export", "extends", "import", "super", "implements", 
			"interface", "let", "null", "package", "private", "protected", "public", "static", "yield",
		];
		var reservedHash = new Map();
		for (r in reserved) {
			reservedHash.set(r, true);
		}

		for (v in variables.keys()) {
			var sigma = variables.get(v);
			switch (sigma.type) {
				case TStruct(sn, args, max):
					// if sn != v it is not a struct declaration, but just a variable that happens to have this struct type
					if (sn == v) {
						if (structTypes.exists(sn)) {
							// error message would already be given when building typedefs map
							//Errors.report('Struct ' + pt(t) + ' multiply defined.');
						} else {
							structTypes.set(sn, sigma);
							for (td in args) {
								if (reservedHash.get(td.name)) {
									Errors.report(Prettyprint.position(td.position) 
										+ ': ' + "Struct '" + sn + "' can not have a field named '" + td.name + "' since it is a reserved word"
									);
								}
								var f = structFields.get(td.name);
								// totodo: when structs allow polymorphic types, we need
								// to deal better with field types than this because the
								// field type may contain tyvars that cannot be torn away
								// from their quantifier in the typescheme for the whole
								// struct...
								if (f == null) {
									// first occurrence of a struct field with this name
									f = {fromType: sigma, fromTypeMut: null, toType: {tyvars: sigma.tyvars, type: td.type},
											 /*fields: [td],*/ structs: [sigma]};
									structFields.set(td.name, f);
								} else {
									// find a common type for the fields with this name
									// totodo: need to extend laxlub to work on typeschemes for this to work...
									f.toType = mono(TFlow);    // totodo:  laxLub(f.toType, td.type);
									f.fromType = laxLubSigma(f.fromType, sigma);
									/*f.fields.push(td);*/
									f.structs.push(sigma);
								}
								if (td.is_mutable) {
									if (f.fromTypeMut == null)
										f.fromTypeMut = sigma;
									else
										f.fromTypeMut = laxLubSigma(f.fromTypeMut, sigma);
								}
							}
						}
					}
				default:
			}
		}
	}

	// Look up the name of a type in typedefs.  Yield null if not a typedef; if typedef is
	// unexpanded, expand it before returning.  Both structs & unions are - are what?
	function getTypedef(s : String) : {declared: TypeScheme, expanded: TypeScheme, expanding: Bool} {
		var oe = typedefs.get(s);
		if (oe == null) return null; // a struct, not a typedef
		if (oe.expanded == null) {
			switch (oe.declared.type) {
				case TUnion(min, max):
					oe.expanding = true;
					var structs = new Map<String, FlowType>();
					oe.expanded = {tyvars: null, type: TUnion(structs, structs)};
					expandType(oe.declared.type, structs);
					oe.expanded.tyvars = FlowUtil.boundtyvars(oe.expanded.type);
					oe.expanding = false;
				case TStruct(sn, args, max):
					oe.expanded = {tyvars: oe.declared.tyvars, type: TStruct(sn, args, true)};
				default:
					trace('impossible: getTypedef(' + pts(oe.declared) + ') must be struct type');
			}
		} else if (oe.expanding) {
			/* The user gets a warning about cyclic typedefs.  They expand to the least
			   fixpoint.  In the examples here, CyclicType expands to
			   Fill|FontFamily|FontSize; ExtremelyCyclic to []:

			   Type1 ::= Fill, FontFamily;
			   Type2 ::= Type1, CyclicType;
			   CyclicType ::= Type1, FontSize, Type2;
			   VeryCyclic1 ::= VeryCyclic2;
			   VeryCyclic2 ::= VeryCyclic1;
			   ExtremelyCyclic ::= ExtremelyCyclic;
			*/
			trace('Remove the cycle in the definition of type ' + s + ' ::= something dependent on ' + s + ' itself.');
		}
		return oe;
	}

	// If the intype is a single struct, we try to infer the type from what cases are covered
	public function inferSwitchType(intype : FlowType, covered : Map<String, FlowType>) : FlowType {
		var ut = untyvar(intype);
		if (ut == null) return intype;
		switch (ut) {
			case TStruct(sn, sa, sm): {
				// Look for the smallest union that covers all our cases
				var hit = null;
				var minCount = 100000;
				FlowUtil.iterhash(typedefs, function (tv) {
					var norm = tv.expanded.type;
					switch (norm) {
						case TUnion(min, max): {
							var missed = 0;
							for (k in covered.keys()) {
								if (!max.exists(k)) ++missed;
							}
							if (missed == 0) {
								var count = 0;
								for (k in max.keys()) ++count;
								if (count < minCount) {
									minCount = count;
									hit = norm;
								}
							}
						}
						default:
					}
				});
				if (hit != null) return hit;
			}
			case TUnion(min, max): {
				// Look for the smallest union that covers all our cases
				// We add the covered and the incoming together
				for (k in if (max == null) min.keys() else max.keys()) {
					if (!covered.exists(k)) {
						covered.set(k, null);
					}
				}
				// and search for the smallest union
				var dummyStruct = TStruct("", new FlowArray(), false);
				var t = inferSwitchType(dummyStruct, covered);
				if (t != dummyStruct) {
					// trace(pt(t));
					return t;
				}
				return intype;
			}
			default: {
			}
		}
		return intype;
	}

	// Like getTypedef(), but returns only the expanded version & throws if the type is
	// not found.
	function lookupType(n : String) : TypeScheme {
		var oe = typedefs.get(n);
		if (oe == null) mismatch('Type name ' + n + ' undefined');
		if (oe.expanded == null || oe.expanding) impossible('type name ' + n + ' not expanded.');
		return oe.expanded;
	}
	
	// If T ::= Typedef1, Struct1; Typedef1 ::= Struct2, Struct3; expandType(T) yields
	// [Struct1, Struct2, Struct3].
	public function expandType(t : FlowType, structs : Map<String, FlowType>) : Void {
		switch (t) {
			case TUnion(min, max):
				// enough to go through min only, as max==min
				if (min != max) {
					impossible('expandType min != max');
				}
				for (t1 in min) {
					expandType(t1, structs);
				}
			case TStruct(sn, args, max):
				structs.set(sn, t);
			case TName(n, args):
				expandTypename(n, structs);
			default:
				impossible('expandType(' + pt(t) + ')');
		}
	}
	
	function expandTypename(n : String, result : Map<String, FlowType>) : Void {
		var oe = getTypedef(n);
		if (oe == null) {
			// the struct or union is mentioned but defined nowhere
		} else {
			expandType(oe.expanded.type, result);
		}
	}

	// print all typedefs, as declared & as fully expanded to list of structs
	function printTypedefs() {
		var structs = [];
		trace('');
		trace('Typedefs declared:');
		for (s in typedefs.keys()) {
			var oe = typedefs.get(s);
			if (oe.expanded == null || oe.expanding) {
				trace('impossible: typedef ' + s + ' not fully expanded.');
			} else {
				switch (oe.expanded.type) {
					case TStruct(sn, args, max):
						structs.push(oe.expanded);
					case TUnion(min, max):
						trace('\t' + s + ' ::=\t' + ppUnionScheme(oe.declared));
						trace('\t\t\t\t' + ppUnionScheme(oe.expanded));
					default:
						trace('impossible: neither TUnion nor TStruct');
				}
			}
		}
		trace('');
		trace('Structs declared:');
		for (sigma in structs) {
			trace('\t' + pts(sigma));
		}
	}
	
	function lift(t : FlowType) : FlowType {
		return if (t == null) throw "What the hell" else t;
	}

	// Like lub(), except yield TFlow rather than null for non-compatible types
	public function laxLub(t1, t2) {
		return lift(lub(t1, t2));
	}

	function laxLubSigma(sigma1 : TypeScheme, sigma2 : TypeScheme) : TypeScheme {
		var t1 = FlowUtil.instantiate1(sigma1);
		var t2 = FlowUtil.instantiate1(sigma2);
		var u = laxLub(t1, t2);
		var sigma = FlowUtil.generalise(u);
		return sigma;
	}
	
	public function lookupField(name : String) : {fromType: TypeScheme, fromTypeMut: TypeScheme, toType: TypeScheme,
												structs: Array<TypeScheme>/*, fields: Array<MonoTypeDeclaration>*/} {
		return structFields.get(name);
	}

	// pretty print as "Struct1| ...| StructN" (& tyvars if it is polymorphic)
	public function ppUnionScheme(sigma : TypeScheme) : String {
		return if (sigma == null) 'null' else
			(if (FlowUtil.isPolymorphic(sigma)) '/\\' + sigma.tyvars.join(' ') + '.' else '')
				+ ppUnion(sigma.type);
	}

	// pretty print as "Struct1| ...| StructN" (& tyvars if it is polymorphic)
	// todo: why not just use pt()?
	public function ppUnion(t : FlowType) : String {
		return if (t == null) 'null' else pt(t);
	}
	
	// turn a type without tyvars into a type scheme trivially, i.e., make a monomorphic type
	static private function mono(t : FlowType) : TypeScheme {
		return FlowUtil.mono(t);
	}

	// Get the type from a type scheme that we know is really a monotype.  If t is not, throw.
	function checkMono(t : TypeScheme) : FlowType {
		return FlowUtil.checkMono(t);
	}

	function pt(t : FlowType) : String {
		return Prettyprint.prettyprintType(t, normalise);
	}

	function pts(t : TypeScheme) : String {
		return Prettyprint.prettyprintTypeScheme(t, normalise);
	}
	
	var variables : Map<String, TypeScheme>;
	var used_vars : Map<String, Bool>;

	// Struct types.  Keep track of struct types in structTypes, structFields & typedefs

	// all structs in the program
	var structTypes : Map<String, TypeScheme>; // always TStructs

	// map field name to the structs that have that field.  For each field record:
	// field.structs=the types it can be applied to (all of them TStructs),
	// field.fields=the MonoTypeDeclaration for that field (e.g., type of the field, td.type),
	// field.fromType=the type it can be applied to (i.e., a TUnion that is the union of all field.structs),
	// field.toType=the union (not intersection!) of the field types, i.e., of fields[_].type;
	// i.e., the type it returns---assuming we do not know what struct it was applied to.
	// When we know what TStruct type it was applied to, we can return a better estimation
	// of its return type.  In other words fields have dependent types.
	var structFields : Map<String, {fromType: TypeScheme, fromTypeMut: TypeScheme, toType: TypeScheme,
						   structs: Array<TypeScheme>/*, fields: Array<MonoTypeDeclaration>*/}>;

	// Typedefs (i.e., named type unions of struct types: T ::= _ | _).  TName ->
	// {declared: TUnion as written in the source, expanded: the type scheme to which this
	// TUnion expands, i.e., ``FORALL tyvars. TUnion(list of TStructs in this TUnion)´´}.
	// Initially, expanded=null.  If any TStructs themselves were polymorphic, their
	// FORALL quantifier is removed & the quantified variables are moved to the quantifier
	// for the whole TUnion.  expanding: for checking for cyclic type definitions.  Also
	// structs are kept in this map, since the struct name is implicitly assumed also to
	// be a typefed, i.e., with Foo(x: int); you can use Foo as a type name f : () -> Foo;
	var typedefs : Map<String, {declared: TypeScheme, expanded: TypeScheme, expanding: Bool}>;


	var recursiondepth : Int;

	// Subtype-based type inference

	// sub(t1, t2) = enforce t1 is a subtype of t2, causing relevant instantiations,
	// unification & updates to tyvars to make this happen, and returning false if it is
	// not possible.  TODO: I think change it all to throw instead of returning false,
	// then I can avoid propagating bools all over the place.
	public function subtype(t1 : FlowType, t2 : FlowType) : Bool {
		// speed optimisation
		if (t1 == t2) return true;
		if (FlowInterpreter.debug < 2) {
			return subtype0(t1, t2);
		}
		// trace(FlowInterpreter.indent() + 'subtype(' + ppUnion(t1) + ', ' + ppUnion(t2) + ')');
		FlowInterpreter.depth++;
		var t = subtype0(t1, t2);
		if (! t) trace(FlowInterpreter.indent() + '    *FAILED*' + if (reason != '') ' because ' + reason else ''); 
		FlowInterpreter.depth--;
		return t;
	}
	// todo: add inline when it works
	function subtype0(t1 : FlowType, t2 : FlowType) : Bool {
		try {
			recursiondepth = 0;
			reason = NO_REASON;
			sub(t1, t2);
			return true;
		} catch (e : Mismatch) {
			reason = e.why;
			return false;
		}
	}
	private static var NO_REASON : String = '';

	// use this to give the user more specific reasons for the latest type error
	public function why() : String {
		if (reason == null || reason == '') {
			impossible('there is no reason, so do not ask why');
		}
		var tmp = reason;
		reason = '';
		return tmp;
	}
	
	var reason : String;
	

	// throw if not a subtype
	function sub(t1 : FlowType, t2 : FlowType) : Void {
		if (t1 == t2) return;				// speed optimisation
		// if t1 or t2 are not tyvars, fake they are
		subTyvar(tyvarwrap(t1), tyvarwrap(t2));
	}

	// if t is not a tyvar, fake a tyvar that is instantiated to t
	function tyvarwrap(t : FlowType) : FlowTyvar {
		return switch (t) {
			case TTyvar(alpha): findTyvar(alpha);
			default: FlowUtil.mkTyvar(t);	// a throw-away tyvar
		};
	}

	// throw if not possible to make it a subtype.  Call with only canonical tyvars, i.e.,
	// no .type must be a TTyvar itself.
	function subTyvar(tyvar1 : FlowTyvar, tyvar2 : FlowTyvar) : Void {
		if (FlowInterpreter.debug > 2) {
			trace(FlowInterpreter.indent() + 'subTyvar(' + ppUnion(tyvar1.type) + ', ' + ppUnion(tyvar2.type) + ')');
			FlowInterpreter.depth++;
		}
		subTyvar0(tyvar1, tyvar2);
		if (FlowInterpreter.debug > 2) FlowInterpreter.depth--;
	}		
		
	function subTyvar0(tyvar1 : FlowTyvar, tyvar2 : FlowTyvar) : Void {
		// case: same tyvar, no need to process further down
		if (tyvar1 == tyvar2) {
			return;
		}
		var t1 = tyvar1.type;
		var t2 = tyvar2.type;		
		
		// case: one of the tyvars is uninstantiated.  Unify them, so the constraint
		// tyvar1<tyvar2 will not be violated later, or, in some cases, instantiate the
		// uninstantiated tyvar to the same structure as the instantiated one (e.g., a
		// function) but with fresh tyvars throughout & then the relevant recursive sub()
		// calls on these tyvars will do any further unification that might be needed.
		if (t1 == null && t2 == null) {
			unionCanonicalTyvars(tyvar1, tyvar2);
			if (FlowInterpreter.debug > 1) trace(FlowInterpreter.indent() + 'unify 2 uninstantiated tyvars');
			return;
		} else if (t1 == t2) {
			return;				// speed optimisation
		} else if (t1 == null) {
			tyvar1.type = skeleton(normalise(t2));
			if (FlowInterpreter.debug > 1) trace(FlowInterpreter.indent() + 'instantiate bottom tyvar to ' + pt(tyvar1.type));
			subTyvar(tyvar1, tyvar2);
			return;
		} else if (t2 == null) {
			// if t1 is not maxed out, we should not unify the two tyvars as in that case
			// it is enough to propagate to tyvar2 that it can be what tyvar1 is.
			tyvar2.type = skeleton(normalise(t1));
			if (FlowInterpreter.debug > 1) trace(FlowInterpreter.indent() + 'instantiate top tyvar to ' + pt(tyvar2.type));
			subTyvar(tyvar1, tyvar2);
			return;
		}
		// after this point we know t1 & t2 are not null or tyvars
		
		// case: one of the types is flow
		if (t1 == TFlow || t2 == TFlow) {
			// t<flow & flow<t for all types t except void, because anything except void
			// can be cast to flow (possibly requiring a boxing operation at runtime) and
			// flow can be cast to anything (possibly requiring a runtime typecheck)
			if (t1 == TVoid || t2 == TVoid) {
				throw incompatible(t1, t2);
			} else {
				return;
			}
		}

		switch (t1) {
			// case: base types
			case TVoid:   if (t1 != t2) incompatible(t1, t2);
			case TBool:   if (t1 != t2) incompatible(t1, t2);
			case TInt:    if (t1 != t2) incompatible(t1, t2);
			case TDouble: if (t1 != t2) incompatible(t1, t2);
			case TString: if (t1 != t2) incompatible(t1, t2);
			case TNative: if (t1 != t2) incompatible(t1, t2);
			case TBoundTyvar(i1):
				switch (t2) {
					case TBoundTyvar(i2): if (i1 != i2) incompatible(t1, t2);
					default: mismatch('not general enough: the code must work for all ' + pt(t1) + ', not just for ' + pt(t2));
				}
				
			// case:  structured types (ref, arrays, functions, &c.).  Do structural
			// subtyping: recurse on the constituent types
			case TReference(r1):
				switch (t2) {
					case TReference(r2): sub(r1, r2); sub(r2, r1);
					default: mismatch('not a ref');
				}
			case TPointer(r1): impossible('sub pointer');
			case TArray(r1):
				switch (t2) {
					case TArray(r2): sub(r1, r2);
						// NOT '&& sub(r2, r1)' as array elements are unassignable
					default: mismatch('not an array');
				}
			case TFunction(args1, return1):
				switch (t2) {
					case TFunction(args2, return2):
						subArrays(args2, args1);
						sub(return1, return2);
					default: mismatch('not a function');
				}

			// case: struct types
			case TStruct(n, args, max1):
				tyvar1.type = toUnion(t1);
				subTyvar(tyvar1, tyvar2); // handle by subTyvar(TUnion, _) below
			case TUnion(pB1, pT1):
				var nt2 = normalise(t2);
				switch (nt2) {
					case TUnion(pB2, pT2):
						subHashes(pB1, pT2);
						var tv1 = findTyvar(tyvar1);
						var tv2 = findTyvar(tyvar2);
						if (tv1 != tv2) {
							if (FlowUtil.emptyHash(pB2) && pT2 == null && ! FlowUtil.isFinalStructtype(t1)) {
								// totodo: check hash domains are same in isFinal
								// if both tyvars are minimally constrained, unify them to
								// enforce the subtype constraint
								tv2.type = TTyvar(tv1);
								if (FlowInterpreter.debug > 1)
									trace(FlowInterpreter.indent() + 'top tyvar uninstantiated, so unify:  2=' + pt(tv1.type));
							} else if (FlowUtil.emptyHash(pB1) && pT1 == null && ! FlowUtil.isFinalStructtype(nt2)) {
								tv1.type = TTyvar(tv2);
								if (FlowInterpreter.debug > 1)
									trace(FlowInterpreter.indent() + 'bottom tyvar uninstantiated, so unify:  1=' + pt(tv2.type));
							} else if (pT1 == null && pT2 == null) {
								// set b2 := b2 u b1, then t1 := b2
								var B2new = structsetUnion(pB1, pB2);
								if (! B2new.iterator().hasNext()) {
									impossible('new top is empty!  for:   ' + pt(t1) + '    <    ' + pt(nt2));
								}
								tv2.type = TUnion(B2new, pT2);
								tv1.type = TUnion(pB1, B2new);
								if (FlowInterpreter.debug > 1) trace(FlowInterpreter.indent() + 'both unbounded so set  1='
																	 + pt(tv1.type) + '  &  2=' + pt(tv2.type));
							} else if (FlowUtil.emptyHash(pB1) && pT1 != null && ! FlowUtil.emptyHash(pB2) && pT2 == null) {
								// another special case: the bottom union is open
								// downwards (=can be anything) & the top tyvar is open
								// upwards (=can be anything).  In this case we hope it is
								// better to represent the constraint as a single tyvar
								// with these limits built in.
								unifyTyvars(tv1, tv2);
								if (FlowInterpreter.debug > 1)
									trace(FlowInterpreter.indent() + 'back to back & unbounded outwards: unify  1='
										  + pt(tv1.type) + '  &  2=' + pt(tv2.type));
							} else {
								var T1new = structsetIntersect(pT1, pT2);
								tv1.type = TUnion(pB1, T1new);
								tv2.type = TUnion(structsetUnion(T1new, pB2), pT2);
								if (FlowInterpreter.debug > 1)
									trace(FlowInterpreter.indent() + 'propagate  1='
										  + pt(tv1.type) + '  &  2=' + pt(tv2.type) + '\n isFinal = ' + FlowUtil.isFinalStructtype(t1));
							}
						} else {
							impossible('cycle in subtype constraints: tyvar1 & tyvar2 are the same: ' + tyvar1);
						}
						
						// totodo: do we no longer want the shortcircuit n1 == n2 check
						// here?  If we insert it again, consider this again: comparing n1
						// with n2 is not enough, as they may have different
						// instantiations of their type arguments, e.g., Maybe<int> &
						// Maybe<bool>.  But we cannot just simply recurse
						// (structHashesEqual()), since that gives an infinite loop if
						// they are indeed the same.  To solve this, we can choose 1. to
						// recurse, but preempt the infinite loop, or 2. compare by name,
						// but then include instantiations in the comparison, i.e., store
						// <int> & <bool> respectively in the TUnion.
					case TStruct(sn2, args2, max2):
						tyvar2.type = toUnion(nt2);
						subTyvar(tyvar1, tyvar2); // handled by subTybar(TUnion, TUnion) above
					default: mismatch('not a struct');
				}

			// case: types that are impossible here
			case TTyvar(ref): impossible('sub tyvar');
			case TFlow: impossible('sub flow');
			case TName(n1, args1):
				switch (t2) {
					case TName(n2, args2):
						if (n1 == n2 && equalTypesHeur(args1, args2)) {
							//if (args1.length + args2.length > 0) trace('same args, so same: ' + pt(t1) + ' < ' + pt(t2));
							return;
						}
						// check for danger of infinite looping in recursively defined
						// types.  Only possible with typedefs, i.e., ::=, i.e., unions,
						// not with struct names.
						var nt1 = normalise(t1);
						var nt2 = normalise(t2);

						if (occurs_cached(nt1, nt2, n1, n2)) {
							//if (n1 != 'Tree') trace('danger of recursion: t1=' + pt(nt1) + '  , t2=' + pt(nt2));
							// danger of recursion, so be brutal & unify arguments
							if (n1 != n2) {
								// continue as if there was no danger of infinite recursion, but monitor the recursion
								if (recursiondepth > 4) {
									recursiondepth = 0;
									mismatch('sorry, but checking whether '
											 + pt(t1) + ' < ' + pt(t2)
											 + ' does not seem to terminate.  Please try to provide better type annotations.');
								}
								recursiondepth++;
								// sub each definition
								tyvar1.type = nt1;
								tyvar2.type = nt2;
								subTyvar(tyvar1, tyvar2);
								recursiondepth--;
								return;
							} else {
								if (args1.length == 0) {
									tyvar1.type = t2;
								} else if (args2.length == 0) {
									tyvar2.type = t1;
								} else {
									subArrays(args1, args2);
									subArrays(args2, args1);
								}
							}
						} else {
							// sub each definition
							tyvar1.type = nt1;
							tyvar2.type = nt2;
							subTyvar(tyvar1, tyvar2);
						}
						return;
					default:
				}
				tyvar1.type = normalise(t1);
				subTyvar(tyvar1, tyvar2);
		}
	}
	
	// null hash means: all set of all structs in program; be careful,
	// structsetIntersect() looks symmetric; it is not: it propagates "down" from h2 to
	// h1, i.e., it cuts down h1 with h2.
	function structsetIntersect(h1 : Map<String, FlowType>, h2 : Map<String, FlowType>) : Map<String, FlowType> {
		if (h1 == null) return h2;
		if (h2 == null) return h1;
		if (h1 == h2) return h1;
		var hi = new Map<String, FlowType>();
		FlowUtil.mergehash(hi, h1, h2, function(st1, st2) {
			return if (st2 != null) {
				if (st1 == null) impossible('struct is null: ' + st2);
				subStructStruct(st1, st2);
				st1;
			}
			else
				null;
		});
		return hi;
	}

  public function isSubtype(t1 : FlowType, t2 : FlowType) : Bool {
    if (t1 == t2) return true;

    t1 = untyvar(t1);
    t2 = untyvar(t2);

    if ((t1 == null && t2 == null) || t1 == t2) {
      return true;
    } else if (t1 == null) {
      return isSubtype(skeleton(normalise(t2)), t2);
    } else if (t2 == null) {
      return isSubtype(t1, skeleton(normalise(t1)));
    }

    if (t1 == TFlow || t2 == TFlow) {
      return t1 != TVoid && t2 != TVoid;
    }

    switch (t1) {
      case TVoid: return false;
      case TBool: return false;
      case TInt: return false;
      case TDouble: return false;
      case TString: return false;
      case TBoundTyvar(i1): {
        switch (t2) {
          case TBoundTyvar(i2): return i1 == i2;
          default: return false;
        }
      }
      case TReference(r1): {
        switch (t2) {
          case TReference(r2): return isSubtype(r1, r2) && isSubtype(r2, r1);
          default: return false;
        }
      };
      case TPointer(t): return false;
      case TArray(r1): {
        switch (t2) {
          case TArray(r2): return isSubtype(r1, r2);
          default: return false;
        }
      }
      default:
        return false;
/*
      case TFunction(args, returns): 1 + typeDepths(args) + typeDepth(returns);
      case TStruct(n, args, max):
        var n = 1;
        for (td in args) {
          n += typeDepth(td.type);
        }
        n;
      case TUnion(min, max): 1 + typeDepthHash(min) + typeDepthHash(max);
      case TTyvar(ref): if (ref.type == null) 0 else typeDepth(ref.type);
      case TFlow: 1;
      case TNative: 1;
      case TName(n, args): 1 + typeDepths(args);*/
    }
  }



	// be careful, structsetUnion() looks symmetric; it is not: it propagates from h1 to
	// h2
	function structsetUnion(h1 : Map<String, FlowType>, h2 : Map<String, FlowType>) : Map<String, FlowType> {
		if (h1 == null || h2 == null) return null;
		if (h1 == h2) return h1;
		var u = FlowUtil.copyhash(h1);
		FlowUtil.mergehash(u, h2, u, function(st2, st1) {
			return if (st1 == null) {
				st2;
			} else {
				subStructStruct(st1, st2);
				null; // don't write
			}
		});
		return u;
	}
	
	// Instantiate the tyvar to a type that is a subtype by instantiating with a type with
	// the same type structure as t, but with fresh tyvars, e.g., 'aplha -> beta', &
	// calling subTyvars recursively to ensure they are subtypes.  Assume t is not a tyvar
	// or null.  Structtypes: instantiate it to the maximally free TUnion, i.e., one where
	// min=no structs, i.e., absolute minimum & max=all structs, i.e., absolute maximum, &
	// then leave it to the subtype relation to narrow that interval.
	function skeleton(t : FlowType) : FlowType {
		return switch (t) {
			case TReference(r1): TReference(newTyvar());
			case TArray(r1): TArray(newTyvar());
			case TFunction(args, result):
				TFunction(FlowUtil.map(args, function (x) {return TTyvar(FlowUtil.mkTyvar(null));}), newTyvar());
			case TUnion(min, max): newUnion();
			case TStruct(sn, args, max): newUnion();
			default: t;
		};
	}

	var occurs_cache : Map<String, Map<String,Bool> >;

	function occurs_cached(nt1 : FlowType, nt2 : FlowType, n1 : String, n2 : String) {
		if (occurs_cache == null)
			occurs_cache = new Map();

		var subcache = occurs_cache.get(n1);
		if (subcache == null)
			occurs_cache.set(n1, subcache = new Map());

		var rv : Null<Bool> = subcache.get(n2);
		if (rv == null) {
			var names = new FlowArray();
			if (FlowUtil.isStructType(nt1)) {
				names.push(n1);
			}
			if (FlowUtil.isStructType(nt2)) {
				names.push(n2);
			}
			subcache.set(n2, rv = occurs(FlowArrayUtil.two(nt1, nt2), names));
		}

		return rv;
	}

	static function occurs(ts : FlowArray<FlowType>, typenames : FlowArray<String>) : Bool {
		var result = false;
		try {
		FlowUtil.traverseTypes(ts, function (t) {
			switch (t) {
				case TName(n, args):
					for (n1 in typenames) {
						if (n == n1) result = true;
					}
				default:
			}});
		} catch (E : Dynamic) {
			// could be a stack overflow; if is, let us assume there is untoward
			// recursion, although this might really be only a fix of symptom of a bug
			// elsewhere
			return true;
		}
		return result;
	}
	
	// convert TStruct to TUnion
	static public function toUnion(st : FlowType) : FlowType {
		return switch (st) {
			default: impossible('toUnion');
			case TStruct(sn, args, max):
				//totodo: get rid of the max field in TStruct entirely.
				//if (! max) throw 'TStruct that is not final: ' + st;
				var h = new Map();
				h.set(sn, st);
				TUnion(h, h);
		}
	}

	// remove any max on the type (for when a struct is inserted in a union that should be
	// soft
	function soften(st : FlowType) : FlowType {
		return switch (st) {
			case TStruct(sn, args, max): if (max) TStruct(sn, args, false) else st;
			default: impossible('soften');
		};
	}

	// propagateStruct(TStruct(sn, args), h) = add the struct to the hash of structs; if a
	// struct of that name is already in h, ensure it is a supertype of this struct.
	function propagateStruct(st1 : FlowType, h : Map<String, FlowType>) : Void {
		switch (st1) {
			default: impossible('propagateStruct');
			case TStruct(sn1, args1, max1):
				var st2 = h.get(sn1);
				if (st2 == null) {
					h.set(sn1, if (max1) TStruct(sn1, args1, false) else st1);
					// soften max1; it makes no sense have a hard struct within a soft
					// union.  TODO: Consider removing the max attribute entirely from
					// TStruct, so it is only stored where truly relevant (on unions).  In
					// the case where we would then normally have a struct with max=true,
					// we can just instead make a singleton TUnion.
				} else {
					// if that structname is already there in the supertype,
					// leave it there, but ensure the subtype relations holds
					subStructStruct(st1, st2);
				}
		}
	}
	
	function subHashes(structs1 : Map<String, FlowType>, structs2 : Map<String, FlowType>) : Void {
		if (structs2 == null) return; // null means 'all structs', so all of structs1 will be subtypes
		if (structs1 == null) mismatch(Prettyprint.ppUnion0(structs2) + ' must allow all struct types');
		FlowUtil.iterhash(structs1, function(st1) {
			subStructHash(st1, structs2);
		});
	}

	// is the struct a subtype of the union (represented by the hash).  Call only with TStructs.
	function subStructHash(st : FlowType, structs : Map<String, FlowType>) : Void {
		switch (st) {
			default: impossible('subStructHash');
			case TStruct(sn, args, max):
				var st2 = structs.get(sn);
				if (st2 == null) {
					mismatch(sn + ' missing');
				} else {
					subStructStruct(st, st2);
				}
		};
	}
	
	// call only with TStructs
	function subStructStruct(st1 : FlowType, st2 : FlowType) : Void {
		if (st1 == st2)
			return;
		switch (st1) {
			default: impossible('subStructStruct I');
			case TStruct(sn1, args1, max1):
				switch (st2) {
					default: impossible('subStructStruct II');
					case TStruct(sn2, args2, max2):
						if (sn1 != sn2) {
							mismatch(sn1 + ' != ' + sn2);
						} else {
							subTypedecs(args1, args2);
						}
				}
		}
	}

	// Apply subtype relation pairwise to the two arrays
	function subArrays(ts1 : FlowArray<FlowType>, ts2 : FlowArray<FlowType>) : Void {
		if (ts1.length != ts2.length) mismatch(ts2.length + ', not ' + ts1.length + ' arguments');
		for (i in 0...ts1.length) {
			sub(ts1[i], ts2[i]);
		}
	}

	// Apply subtype relation pairwise to the two arrays
	function subTypedecs(tds1 : FlowArray<MonoTypeDeclaration>, tds2 : FlowArray<MonoTypeDeclaration>) : Void {
		if (tds1.length != tds2.length) mismatch(tds2.length + ', not ' + tds1.length + ' fields');
		for (i in 0...tds1.length) {
			sub(tds1[i].type, tds2[i].type);
		}
	}

	// Only a heuristic.  If true, they are equal.  If not true, they may still be
	// equal...
	public function equalTypeHeur(t1 : FlowType, t2 : FlowType) : Bool {
		var ut1 = untyvar(t1);
		var ut2 = untyvar(t2);
		if (ut1 == null && ut2 == null) return true;
		if (ut1 == null || ut2 == null) return false;
		return switch (ut1) {
			case TVoid: ut1 == ut2;
			case TBool: ut1 == ut2;
			case TInt:  ut1 == ut2;
			case TDouble: ut1 == ut2;
			case TString: ut1 == ut2;
			case TReference(r1):
				switch (ut2) {
					case TReference(r2): equalTypeHeur(r1, r2);
					default: false;
				}
			case TPointer(r1): 
				switch (ut2) {
					case TPointer(r2): equalTypeHeur(r1, r2);
					default: false;
				}
			case TArray(r1):
				switch (ut2) {
					case TArray(r2): equalTypeHeur(r1, r2);
					default: false;
				}
			case TFunction(args1, res1):
				switch (ut2) {
					case TFunction(args2, res2):
						equalTypesHeur(args1, args2) && equalTypeHeur(res1, res2);
					default: false;
				}
			case TStruct(sn1, args1, foo):
				switch (ut2) {
					case TStruct(sn2, args2, foo):
						sn1 == sn2 && equalTypedecsHeur(args1, args2);
					default: false;
				}
			case TUnion(min1, max1):
				switch (ut2) {
					case TUnion(min2, max2):
						structHashesEqualHeur(min1, min2) && structHashesEqualHeur(max1, max2);
					default: false;
				}
			case TTyvar(alpha): impossible('equalTypeHeur tyvar');
			case TBoundTyvar(id1):
				switch (ut2) {
					case TBoundTyvar(id2): id1 == id2;
					default: false;
				}
			case TFlow: ut1 == ut2;
			case TNative: ut1 == ut2;
			case TName(n1, args1):
				switch (ut2) {
					case TName(n2, args2): n1 == n2 && equalTypesHeur(args1, args2);
					default: false;
				}
		}
	}

	function equalTypesHeur(ts1 : FlowArray<FlowType>, ts2 : FlowArray<FlowType>) : Bool {
		if (ts1.length != ts2.length) {
			// not the same number of arguments, so fail
			return false;
		}
		for (i in 0...ts1.length) {
			if (! equalTypeHeur(ts1[i], ts2[i])) return false;
		}
		return true;
	}

	function equalTypedecsHeur(tds1 : FlowArray<MonoTypeDeclaration>, tds2 : FlowArray<MonoTypeDeclaration>) : Bool {
		if (tds1.length != tds2.length) return false;
		for (i in 0...tds1.length) {
			if (! equalTypeHeur(tds1[i].type, tds2[i].type)) return false;
		}
		return true;
	}

	function structHashesEqualHeur(structs1 : Map<String, FlowType>, structs2 : Map<String, FlowType>) : Bool {
		if (structs1 == null && structs2 == null) return true;
		if (structs1 == null || structs2 == null) return false;
		var n1 = FlowUtil.hashlength(structs1);
		var n2 = FlowUtil.hashlength(structs2);
		if (n1 != n2) return false;
		for (sn1 in structs1.keys()) {
			var st1 = structs1.get(sn1);
			var st2 = structs2.get(sn1);
			if (st2 == null || ! equalTypeHeur(st1, st2)) return false;
		}
		return true;
	}
	

	
	// totodo: check what the difference between unionCanonicalTyvars & unifyTyvars is.
	// Is unionCanonicalTyvars outdated?
	function unifyTyvars(alpha1 : FlowTyvar, alpha2 : FlowTyvar) : Void {
		var beta1 = findTyvar(alpha1);
		var beta2 = findTyvar(alpha2);
		switch (beta1.type) {
			case TUnion(min1, max1):
				switch (beta2.type) {
					case TUnion(min2, max2):
						var newmin = structsetUnion(min1, min2);
						var newmax = structsetIntersect(max1, max2);
						beta1.type = TUnion(newmin, newmax); // beta1 is this union
						beta2.type = TTyvar(FlowUtil.mkTyvar(beta1.type)); // & beta2 is aliased to it
						return;
					default:
				}
			default:
		}
		impossible('unifyTyvars');	
	}

	function newTyvar() : FlowType {
		return TTyvar(FlowUtil.mkTyvar(null));
	}

	static public function newUnion() : FlowType {
		return TUnion(new Map<String, FlowType>(), null);
	}

	// find in a union-find algorithm on tyvars: find the canonical tyvar, i.e., the ref:
	// FlowTyvar that contains the actual instantiation (or null if the tyvar is
	// not instantiated).
	static public function findTyvar(alpha : FlowTyvar) : FlowTyvar {
		if (alpha == null) impossible('findTyvar(null)');
		return (if (alpha.type == null) alpha // this is the canonical tyvar (& it is instantiated to null)
				else switch (alpha.type) {
					case TTyvar(beta):
						if (beta == null) impossible('findTyvar TTyvar(null)');
						findTyvar(beta); // infinite loop here if someone screwed up & set ref.type = TTyvar(ref)
					default:
						// this is the canonical tyvar (instantiated to something non-null)
						alpha;
				});
	}

	// union of a union-find algorithm on tyvars.  unionTyvars(alpha1, alpha2) = set
	// alpha1 to be the same as alpha2 (overwriting whatever alpha1 might previously have
	// been instantiated to)
	function unionTyvars(alpha1 : FlowTyvar, alpha2 : FlowTyvar) : Void {
		unionCanonicalTyvars(findTyvar(alpha1), findTyvar(alpha2));
	}
	
	function unionCanonicalTyvars(alpha1 : FlowTyvar, alpha2 : FlowTyvar) : Void {
		if (alpha1 == alpha2) impossible('unionCanonicalTyvars: tyvar1 & tyvar2 are the same: ' + alpha1);
		if (alpha1.type == null) {
			alpha1.type = TTyvar(alpha2);
		} else if (alpha2.type == null) {
			alpha2.type = TTyvar(alpha1);
		} else {
			impossible('unionCanonicalTyvars: both instantiated');
		}
	}

	// What is this type really; null if it is an uninstantiated tyvar
	inline static public function untyvar(t : FlowType) : FlowType {
		return if (t == null) null else switch (t) {
			case TTyvar(alpha): findTyvar(alpha).type;
			default: t;
		};
	}

	static function impossible(s : String) : Dynamic {
		throw 'impossible: ' + s;
		return null;
	}

	function mismatch(s : String) : Dynamic {
		throw new Mismatch(s);
		return null;
	}

	function incompatible(t1 : FlowType, t2 : FlowType) : Dynamic {
		return mismatch(pt(t1) + ' != ' + pt(t2));
	}	
}

// Used for exceptions from subtyping & matching functions to distinguish exceptions that
// are type errors (e : Mismatch) from exceptions that are errors in the typechecker (e :
// String).
class Mismatch {
	public function new(why0 : String) {
			why = why0;
	}
	public var why : String;
}

