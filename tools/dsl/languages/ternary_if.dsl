{
	registerDslParserExtension("ternary_if", <<
		postfix = postfix | ternary;
		ternary = "?" ws exp ":" ws exp $"ternary_3";
	>>);

	registerDslRewriting("desugar", "ternary_if", "ast", "ast", ";", <<
			ternary($cond, $pos, $neg) => ifelse($cond, $pos, $neg);
		>>, <<
			ternary => 10000 ;
		>>,
		<< 0 >>
	)
}