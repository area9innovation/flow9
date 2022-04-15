syntax lambda+quotestring+array {
	// This adds records to a language

	// TODO: This is wrong. If you construct more than one
	// record of the same type, we will get multiple accessor functions.
	// Also, the scope of the record is not defined.

	// Syntax:
	// { a: 2, b : 3 } constructs a record/object a la js

	// From this, we should generate these
	//  => a(record) -> int;	 == field(record, "a")
	//  => b(record) -> int;	 == field(record, "b")
	//
	// r.b => b(r); 	from the dot notation

	// a.b = b; 		is another extension possible
	//					which is 	a = record(a.a, b);
	//					or maybe it is named parameters with some kind of defaults
	//					a = record(b = b);
	//				    or probably, it is "with" a la flow:
	//					a = record(a with b = b)

	registerDslParserExtension("records", << 
		atom = atom | '{' ws recordFields '}' ws $"record_1";

		// listOf(recordfield, ",")
		recordFields = $"nil" recordField $"cons" ("," ws recordField $"cons")* ("," ws)? | $"nil";
		recordField = id ":" ws exp $"record_field_2";

		// Extend any type syntax with record types
		type = '{' recordTypeFields '}' ws $"record_type_2" | type;

		// listOf(recordfield, ",")
		recordTypeFields = $"nil" recordTypeField $"cons" ("," ws recordTypeField $"cons") ("," ws)? | $"nil";
		recordTypeField = id ":" ws type $"record_field_type_2";
	>>);

	// TODO: Add type reductions to unifications and subtyping constraints.

	// After parsing, we have a phase where we construct new runtime
	// functions for the field accessors after parsing and desugaring.

	// Given a record like { myfield : 1, second : 2} , this constructs functions like 
	// 	myfield = \r -> field(r, "myfield");
	// 	second = \r -> field(r, "second");
	registerDslLowering("desugar", "records", "ast", "lambda+array", ";;", <<
			record($fields) => 
				fold(fields, record(fields), \acc, f -> {
					name = nodeChild(f, 0);
					// TODO: We should lift this directly into the environment so
					// the helpers become accessible in code like "a = { foo : 1}; foo(a)"
					let(name, lambda(["r"], call(var("field"), [r, name])), acc)
				}) ;;
		>>);

	// If a named type is defined, we should construct constructor functions for it
	// as well
	registerDslRuntime("records", "lambda+array", <<
		field = \record, fieldname -> {
			fields = nodeChild(record, 0);
			fold(fields, nil(), \acc, f -> {
				name = nodeChild(f, 0);
				if (name == fieldname) {
					nodeChild(f, 1);
				} else acc;
			})
		};
		hasField = \record, fieldname -> {
			fields = nodeChild(record, 0);
			fold(fields, false, \acc, f -> {
				acc || {
					name = nodeChild(f, 0);
					name == fieldname
				}
			})
		};
		["fold"]
	>>);
}
