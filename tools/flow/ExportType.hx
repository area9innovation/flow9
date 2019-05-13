import Flow;
import Position;

class ExportType {
	public static function exportType(type : String, env : TypeEnvironment) : Void {
		if (namesToResolve == null) {
			namesToResolve = new Map();
		}

		var schema = env.lookup(type);
		if (schema != null) {
			Sys.println(prettyprintType(type, schema.type) + ";");
		} else {
			Sys.println(type + " is unknown;");
		}

		namesToResolve.set(type, true);

		// Next, check all new remaining names
		for (s in namesToResolve.keys()) {
			if (namesToResolve.get(s) == false)  {
				exportType(s, env);
			}
		}
	}

	public static function prettyprintType(name : String, type : FlowType, ?bracket : Bool) : String {
		return if (type == null) 'null' else
		switch (type) {
		case TVoid: "void";
		case TBool: "bool";
		case TInt: "int";
		case TDouble: "double";
		case TString: "string";
		case TReference(type): "ref " + prettyprintType('', PositionUtil.getValue(type), false);
		case TPointer(type): "pointer to "+ prettyprintType('', PositionUtil.getValue(type), false);
		case TArray(type): "[" + prettyprintType('', PositionUtil.getValue(type), false) + "]";
		case TFunction(args, returns): 
			var r = '(';
			var sep = '';
			for (a in args) {
				// in the case of only one argument, we need brackets around that argument in case it is a function
			    r += sep + prettyprintType('', PositionUtil.getValue(a), args.length == 1);
				sep = ', ';
			}
			// no brackets around the return type: ok to prettyprint a->(b->c) as a->b->c.
			r += ') -> ' + prettyprintType('', PositionUtil.getValue(returns), false);
			if (bracket == true) '(' + r + ')' else r;
		case TStruct(structname, args, max): 
			var r = structname;
			r += '(';
			var sep = '';
			for (a in args) {
			  r += sep + a.name + ': ' + prettyprintType('', PositionUtil.getValue(a.type), false);
				sep = ', ';
			}
			r += ')';
			r;
		case TUnion(min, max): {
			var r = name + " ::= ";

			var collect = [];
			for (k in max) {
				collect.push(prettyprintType('', k, false));
			}
			collect.sort(Util.compareStrings);
			var sep = '';
			for (s in collect) {
				r += sep + s;
				sep = ", ";
			}
			r;
		}
		case TTyvar(ref): '?';
		case TBoundTyvar(i): FlowUtil.repeat(i + 1, '?');
		case TFlow: "flow";
		case TNative : "native";
		case TName(name, args): {
			if (!namesToResolve.exists(name)) {
				namesToResolve.set(name, false);
			}
			name;
		}
		}
	}

	static var namesToResolve : Map<String, Bool>;
}
