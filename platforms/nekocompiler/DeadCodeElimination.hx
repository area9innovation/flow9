import Flow;

class DeadCodeElimination {
	public function new(p: Program) {
		program = p;
		used = new Map();
		queue = new FlowArray();
		queue.push("main");

		for (n in program.declsOrder) {
			var td = program.topdecs.get(n);
			if (td != null) {
				switch (td) {
					case Lambda(arguments, type, body, uniqNo, pos): {
						// We only remove dead functions
					}
					// These are trivially safe to DCE
					case ConstantBool(v, pos): {}
					case ConstantI32(v, pos): {}
					case ConstantDouble(v, pos): {}
					case ConstantString(v, pos): {}
					case Native(name, io, args, result, body, pos): {}

					default: {
						// We check whether this global thing has any dangerous side effects
						if (safeForDCE(program, td))  {
							// To make sure things are right, this is helpful
							// Sys.println(Prettyprint.prettyprint(td));
						} else {
							// This does something we can not predict, so include it for safety
							queue.push(n);
						}
					}
				}
			}
		}

		recurse();

		var newOrder = new FlowArray();
		for (n in program.declsOrder) {
			if (used.exists(n)) {
				/*
				var td = program.topdecs.get(n);
				if (td != null) {
					switch (td) {
					case Native(name, io, args, result, body, pos): {
						Sys.println("Alive: " + n);
					}
					default: {}
					}
				}*/
				newOrder.push(n);
			} else {
				/*
				var td = program.topdecs.get(n);
				if (td != null) {
					switch (td) {
					case Native(name, io, args, result, body, pos): {
						Sys.println("Dead: " + n);
					}
					default: {}
					}
				}*/
				program.topdecs.set(n, null);
			}
		}
		program.declsOrder = newOrder;
	}

	function recurse() {
		while (queue.length > 0) {
			var name = queue.pop();
			var f = program.topdecs.get(name);
			if (f != null) {
				used.set(name, 1);
				FlowUtil.traverseExp(f, function (e) {
				    switch (e) {
			    	    case VarRef(name, pos): {
			    	    	if (!used.exists(name)) {
			    	    		used.set(name, 0);
				    	    	queue.push(name);
			    	    	}
			    	    }
			    	    default:
				    }
				});
			}
		}
	}

	function safeForDCE(program : Program, f : Flow) : Bool {
		var safe = true;
		FlowUtil.traverseExp(f, function (e) {
		    switch (e) {
		    	case Call(c, as, pos): {
		    		switch (c) {
						case VarRef(n, p): {
							// Check if this is a struct constructor
							var s = program.typeEnvironment.getStruct(n);
							if (s != null) {
								// If so, just check that all arguments are safe
								for (a in as) {
									safeForDCE(program, a);
								}
							} else {
								safe = false;
							}
						}
						default: safe = false;
					}
		    	}
	    	    default:
		    }
		});
		return safe;
	}

	public var program : Program;
	var queue : FlowArray<String>;
	var used : Map<String,Int>;
}
