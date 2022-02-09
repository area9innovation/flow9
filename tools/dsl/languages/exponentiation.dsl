syntax lambda+quotestring+array {
	registerDslParserExtension("exponentiation", <<
		postfix = postfix | '^' ws exp $"exponent_2";
	>>);

	registerDslRewriting("desugar", "|exponentiation", "ast", "ast", ";", <<
			exponent($x, $y) => call(var("power"), [$x, $y]);
		>>, <<
			exponent => 10000 ;
		>>,
		<< 0 >>
	);

	registerDslRuntime("|exponentiation", "lambda+array", <<
		power = \x, y -> if (y == 0) 1 else x * power(x, y - 1);
		[]
	>>)
}
