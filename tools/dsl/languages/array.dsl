// This adds arrays to a language
// Syntax:
// [] is the empty array
// [ 1, 2, ..., 3 ] is array construction
// a[1] is indexing
// The default runtime representation is lists, so expect linear time indexing.

{
	// This provides a grammar extension for arrays
	registerDslParserExtension("array", << 
		atom = atom | '[' ws exps ']' ws $"array_1";
		postfix = postfix | '[' ws exp ']' ws $"array_index_2";
	>>);

	registerDslLowering("desugar", "array", 
		"ast", "lambda", ";", <<
		// [ exps ] => exps - given the list representation is reversed
		array($e) => reverse(e);
		// a[i] => listAt(a, i);
		array_index($a, $i) => @listAt($a, $i);
	>>);

	registerDslRuntime("array", "lambda", << {"listAt"; "reverse"} >>)
}
