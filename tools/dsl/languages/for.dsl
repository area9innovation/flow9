syntax lambda+quotestring+array {
	// Adds for-iteration over a collection, syntax like: 'for x in [1,2,3] print(x * 2)'
	registerDslParserExtension("for", <<
		atom = "for" ws idbind "in" ws exp exp $"for_3" | atom;
	>>);

	registerDslLowering("desugar", "for", "ast", "ast", ";", <<
		for($id, $e1, $e2) => call(var("iter"), [$e1, lambda([$id], $e2)]);
	>>);

	registerDslRuntime("for", "lambda+array", << ["iter"] >>);
}
