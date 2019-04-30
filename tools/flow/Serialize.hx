class Serialize {
	public static function serialize(object : Dynamic, indent : String) : String {
		var en = Type.getEnum(object);
		if (en != null) {
			var enumname = Type.enumConstructor(object);
			var pars = Type.enumParameters(object);
			return enumname + '(' + formatList(pars, indent) + ')';
		}
		var type = Type.typeof(object);
		switch (type) {
		case TClass(class_):
			var name = Type.getClassName(class_);
			if (name == "Array") {
				var a : Array<Dynamic> = object;
				return '[' + formatList(a, indent) + ']';
			} else if (name == "String") {
				// TODO: Escape qoutes and newlines here
				return  '"' + Std.string(object) + '"';
			} else if (name == "Environment") {
				var e : Environment = object;
				return e.serialize(indent);
			} else {
				// TODO: Depending on what this is, do something about it
				return name + '"' + Std.string(object) + '"';
			}
		case TInt:
			return '' + object;
		case TFloat:
			return '' + object;
		case TBool:
			return '' + object;
		case TObject:
			if (object.f != null) {
				return object.f + ':' + object.l;
			}
		case TFunction:
			return '/* ' + object + ' */';
		default:
			Errors.report('unknown:' + type);
		}
		return "unknown";
//		return Std.string(object) + '\n';
	}
	
	static public function formatList(a : Array<Dynamic>, indent : String) : String {
		var result = '';
		var sep = '';
		var l = 0;
		var i = 0;
		for (p in a) {
			var c = serialize(p, indent + '  ');
			l += (c.length - c.lastIndexOf('\n'));
			if (l >= 70 && i != 0) {
				sep = ',\n' + indent;
				l = 0;
			} else {
				if (i != 0) {
					sep = ',';
				}
			}
			++i;
			result += sep + c;
		}
		return result;
	}
	
/*	public static function deserialize(s : String) : Dynamic {
		// TODO
	}*/
}
