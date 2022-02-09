syntax lambda+quotestring+array {
	// This adds structs to a language
	// Syntax:
	// 		struct Foo(a, b);
	//      scope
	// defines a struct. This is short for a constructor.
	// function, which builds a record:
	// 		Foo(1, 2) => { a=1, b=2 }
	//      scope

	registerDslParserExtension("structs", << 
		atom = 'struct' !letterOrDigit ws id "(" ws struct_args ")" ws (';' ws) ? expsemi $"brace_1" $"struct_3" 
			| atom;

		struct_args = $"nil" struct_arg $"cons" ("," ws struct_arg $"cons")* ("," ws)? | $"nil";
		struct_arg = id; // "=" ws exp $"default_struct_value";
	>>);

	// struct(id, args, scope) => struct = \*args -> {args[0]}; scope
	registerDslLowering("desugar", "structs", "ast", "lambda", ";;", <<
		struct($id, $fields, $scope) => {
			let(id, lambda(fields,
				record(
					fold(fields, nil(), \acc, f -> {
						cons(record_field(f, var(f)), acc)
					})
				)
			), scope) };;
	>>);
}
