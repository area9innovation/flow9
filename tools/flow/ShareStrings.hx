import FlowUtil;
import Flow;

typedef StringShare = {
	varName : String,
	string : Flow,
	count : Int
}

// A pass to change the code to share identical strings by introducing new global variables for them
class ShareStrings {
	public static function shareStrings(p : Program) : Void {
		var vars = 0;
		var bigStrings = new Map<String,StringShare>();
		// First, register all strings and find the duplicated ones
		for (d in p.declsOrder) {
			var e = p.topdecs.get(d);
			FlowUtil.traverseExp(e, function(f) {
				switch (f) {
					case ConstantString(s, p): {
						var seen = bigStrings.get(s);
						if (seen != null) {
							seen.count = seen.count + 1;
							bigStrings.set(s, seen);
						} else {
							if (s.length > 5) {
								var share = { 
									varName: "%" + vars,
									string: f,
									count: 1
								};
								bigStrings.set(s, share);
								vars++;
							}
						}
					}
					default:
				}
			});
		}
		
		// Next, share the ones that can be shared
		for (d in p.declsOrder) {
			var e = p.topdecs.get(d);
			var changed = FlowUtil.mapFlow(e, function(f) {
				return switch (f) {
					case ConstantString(s, p): {
						var seen = bigStrings.get(s);
						if (shouldShare(seen)) {
							VarRef(seen.varName, p);
						} else {
							f;
						}
					}
					default: f;
				}
			});
			p.topdecs.set(d, changed);
		}
		
		var sharedStrings = new FlowArray();
		for (s in bigStrings.iterator()) {
			if (shouldShare(s)) {
				sharedStrings.push(s.varName);
				p.topdecs.set(s.varName, s.string);
			}
		}
		
		p.declsOrder = sharedStrings.concat(p.declsOrder);
		
		#if false
		for (d in p.order) {
			var e = p.topdecs.get(d);
			Sys.println(d + "=" + Prettyprint.print(e));
		}
		#end
	}
	
	static function shouldShare(s : StringShare) : Bool {
		if (s == null || s.count < 2) {
			return false;
		}
		var saving = (s.count - 1) * FlowUtil.getString(s.string).length;
		return saving > 0;
	}
}
