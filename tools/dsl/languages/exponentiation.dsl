syntax lambda+quotestring+array {
	registerDslParserExtension("exponentiation", <<
		postfix = postfix | '^' ws exp $"exponent_2";
	>>);

	registerDslLowering("desugar", "exponentiation", "ast", "lambda", ";", <<
			exponent($x, $y) => @power($x, $y);
		>>);

	registerDslRuntime("exponentiation", "lambda+array", <<
		power = \x, y -> if (y == 0) 1 else x * power(x, y - 1);
		[]
	>>)
}
