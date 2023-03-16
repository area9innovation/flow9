syntax lambda+quotestring+array {
	registerDslParserExtension("tuples", << 
		atom = atom | '(' ws ')' ws $"nil" $"tuple_1" 
			| '(' ws $"nil" exp "," ws $"cons" ')' ws $"tuple_1"
			| '(' ws exps ')' ws $"tuple_1";
	>>);

	registerDslLowering("desugar", "tuples", "ast", "lambda", ";", <<
		// We strip the tuple
		tuple($l) => reverse(l);
	>>);

	registerDslRuntime("tuples", "lambda+array", <<
		nth = \l, n -> {
				listAt(l, n)
			};
		first = \l -> nth(l, 0);
		second = \l -> nth(l, 1);
		third = \l -> nth(l, 2);
		fourth = \l -> nth(l, 3);
		fifth = \l -> nth(l, 4);
		sixth = \l -> nth(l, 5);
		["listAt", "reverse"]
	>>)
}
