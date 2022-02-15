{

	registerDslParserExtension("while", <<
		atom = 'while' !letterOrDigit ws "(" ws exp ")" ws "{" ws expsemi "}" ws $"brace_1" $"while_2" | atom;
	>>);

	// TODO: We should extract the free vars in the condition, and turn those into
	// arguments on the while function
	registerDslLowering("desugar", "while", "ast", "lambda", ";;", <<
		while($cond, $b) => {
			// TODO: We need a general mechanism for this
			tmpId = "tmp";
			whileCall = call(var(tmpId), nil());
			let(tmpId, lambda(nil(), ifelse(cond, brace(
				cons(
					b,
					cons(whileCall, nil())
				)
			), nil())), whileCall)
		} ;;
	>>);
}
