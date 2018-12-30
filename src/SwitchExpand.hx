import Flow;
import TypeEnvironment;

class SwitchExpand {
	static public function expandCases(typeEnvironment : TypeEnvironment, cases : FlowArray<SwitchCase>) : FlowArray<SwitchCase> {
		// This should expand unions in cases to structs
		var expanded = new FlowArray<SwitchCase>();
		var seen = new Map<String, Bool>();

		// First grab default and structs
		for (c in cases) {
			var structSigma = typeEnvironment.lookup(c.structname);
			if (structSigma == null) {
				expanded.push(c);
			} else {
				switch (structSigma.type) {
					case TStruct(sn, args, max): {
						seen.set(sn, true);
						expanded.push(c);
					}
					/*case TUnion(low, up): {
						Sys.println("Skipping");
					}*/
					default: {}
				}
			}
		}

		// Next, expand unions
		for (c in cases) {
			var structSigma = typeEnvironment.lookup(c.structname);
			if (structSigma == null) {
			} else {
				switch (structSigma.type) {
					case TUnion(low, up): {
						expandType(typeEnvironment, structSigma.type, c, expanded, seen);
					}
					default: {}
				}
			}
		}

		return expanded;
	}

	static function expandType(typeEnvironment : TypeEnvironment, type : FlowType, case_ : SwitchCase, 
			expanded : FlowArray<SwitchCase>, seen : Map<String, Bool> ) : Void {
		switch (type) {
			case TStruct(sn, args, max): {
				if (seen.get(sn)) {
					// Sys.println("Skipping " + sn);
				} else {
					var newCase : SwitchCase = {
						structname: sn,
						args: args.map(function(a) { return "__"; }),
						used_args: null,
						body: case_.body
					};
					// Sys.println("Adding " + sn);
					expanded.push(newCase);
					seen.set(sn, true);
				}
			}
			case TUnion(low, up): {
				for (e in low) {
					switch (e) {
						case TStruct(sn, args, max): {
							expandType(typeEnvironment, e, case_, expanded, seen);
						}
						case TName(name, p): {
							var structSigma = typeEnvironment.lookup(name);
							expandType(typeEnvironment, structSigma.type, case_, expanded, seen);
						}
						default: {
							Sys.println('Should not happen ' + e);
						}
					}
				}
			}
			default: {
				Sys.println('Should not happen ' + type);
				expanded.push(case_);
			}
		}
	}
}
