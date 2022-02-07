syntax lambda+quotestring+array {
	registerDslParserExtension("tuples", << 
		atom = atom | '(' ws ')' ws $"nil" $"tuple_1" 
			| '(' ws $"nil" exp "," ws $"cons" ')' $"tuple_1"
			| '(' ws exps  ')' $"tuple_1";
	>>);

	// TODO: We register a dummy lowering so the runtime can be activated
	registerDslLowering("desugar", "|tuples", "ast", "ast", ";", "");

	registerDslRuntime("|tuples", "lambda+array", <<
		nth = \l, n -> {
				// Extract from the tuple wrapper
				// TODO: We could do an optimization where we just
				// remove the tuple wrapper instead?

				li = nodeChild(l, 0);
				listAt(li, length(li) - n)
			};
		first = \l -> nth(l, 1);
		second = \l -> nth(l, 2);
		third = \l -> nth(l, 3);
		fourth = \l -> nth(l, 4);
		fifth = \l -> nth(l, 5);
		sixth = \l -> nth(l, 6);
		["listAt", "length"]
	>>)
}
