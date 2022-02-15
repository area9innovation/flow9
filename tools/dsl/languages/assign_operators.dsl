syntax lambda+quotestring {
	registerDslParserExtension("assign_operators", <<
		atom = assign_add | assign_sub | assign_mul | assign_div | assign_mod | atom;
		assign_add = idbind "+=" ws exp ";" ws expsemi $"brace_1" $"letadd_3";
		assign_sub = idbind "-=" ws exp ";" ws expsemi $"brace_1" $"letsub_3";
		assign_mul = idbind "*=" ws exp ";" ws expsemi $"brace_1" $"letmul_3";
		assign_div = idbind "/=" ws exp ";" ws expsemi $"brace_1" $"letdiv_3";
		assign_mod = idbind "%=" ws exp ";" ws expsemi $"brace_1" $"letmod_3";
	>>);

	registerDslLowering("desugar", "assign_operators", "ast", "ast", ";", <<
		letadd($e1, $e2, $e3) => let($e1, add(var($e1), $e2), $e3);
		letsub($e1, $e2, $e3) => let($e1, sub(var($e1), $e2), $e3);
		letmul($e1, $e2, $e3) => let($e1, mul(var($e1), $e2), $e3);
		letdiv($e1, $e2, $e3) => let($e1, div(var($e1), $e2), $e3);
		letmod($e1, $e2, $e3) => let($e1, mod(var($e1), $e2), $e3);
	>>);
}
