syntax lambda+quotestring+array {
	// Adds for-iteration over a collection, syntax like: 'for x in [1,2,3] print(x * 2)'
	registerDslParserExtension("for", <<
		atom = "for" ws idbind "in" ws exp exp $"for_3" | atom;
	>>);

	registerDslLowering("desugar", "for", "ast", "lambda", ";", <<
		for($id, $e1, $e2) => @iter($e1, \$id -> $e2);
	>>);

	registerDslRuntime("for", "lambda+array", << ["iter"] >>);
}
