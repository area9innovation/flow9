syntax lambda+quotestring+array {
/*
	Adds syntax for named arguments in function calls
	with "top-level" function syntax

	foo(a = 1, b = 2) {
		exp
	}
	scope

	becomes

	foo = \a, b -> exp;
	foo = \record -> foo(if (hasField(record, "a")) record.a else 1, if (hasField(record, "b")) record.b else 2);
	scope

	and

	foo(b: 1)
	becomes 
	foo({b:1})
*/
	registerDslParserExtension("named_args", << 
		atom = id "(" ws fundef_args ")" ws "{" ws expsemi "}" ws (';' ws) ? expsemi $"brace_1" $"function_4" | atom;

		fundef_args = $"nil" fundef_arg $"cons" ("," ws fundef_arg $"cons")* ("," ws)? | $"nil";
		fundef_arg = id "=" ws exp $"funargdef_2" | id $"funarg_1";

		postfix = "(" ws funargs ")" ws $"named_call_2" | postfix;

		funargs = $"nil" funarg $"cons" ("," ws funarg $"cons")* ("," ws)? | $"nil";
		funarg = id ":" ws exp $"record_field_2";
	>>);

	// function(id, args, body) => id = \args -> body
	registerDslLowering("desugar", "named_args", "ast", "lambda+array", ";;", <<
		function($id, $args, $body, $scope) => {
			tmp = "tmp2"; // TODO: Make temporary
			hasDefVal = \node -> { nodeName(node) == "funargdef" };

			callargs = fold(args, nil(), \acc, arg -> {
				argName = nodeChild(arg, 0);
				defVal = nodeChild(arg, 1);
				cons(if (hasDefVal(arg)) {
					// a = if (hasField(tmp, "a")) a(tmp) else defVal;
					has = call(var("hasField"), [var(tmp), argName]);
					ifelse(
						has,
						call(var(argName), [var(tmp)]), 
						defVal
					);
				} else {
					// a = a(tmp);
					call(var(argName), [var(tmp)]);
				}, acc)
			});
			revargs = reverse(callargs);
			newbody = call(var(id), revargs);
			let(id, lambda(map(args, \a -> nodeChild(a, 0)), body),
				let(id, lambda(cons(tmp, nil()), newbody), scope));
			;
		} ;;

		named_call($fn, $args) => {
			call(fn, [record(args)])
		} ;;
	>>);
}
