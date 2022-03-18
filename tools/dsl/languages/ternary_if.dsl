{
	registerDslParserExtension("ternary_if", <<
		postfix = postfix | ternary;
		ternary = "?" ws exp ":" ws exp $"ternary_3";
	>>);

	registerDslLowering("desugar", "ternary_if", "ast", "lambda", ";", <<
		ternary($cond, $pos, $neg) => @if ($cond) $pos else $neg;
	>>)
}