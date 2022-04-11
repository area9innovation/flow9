{

	// See https://files.openscad.org/grammar.xhtml
	registerDslParserExtension("openscad", <<
		package = ws $"nil" (statement $"cons")+ $"package_1";
		statement = include | use | assignment | named_function_definition | named_module_definition | module_instantiation;
		include = "include" !letterOrDigit ws filename ";" ws $"include_1";
		use = "use" !letterOrDigit ws filename ";" ws $"use_1";
			filename = "<" $(!'>' anychar)+ ">" ws;

/*
		range = [ start : end ] | [ start : increment : end ];

		list = [ exp ("," exp)* ] | [ ];
		listcomprehension = [ elements ];
			[ for exp ] => basically map on the for
			[ for each exp ] => does concatA at the end
			[ for if cond exp ] => filtermap

		prefix = "+" ws exp;
		if = exp "?" exp ":" exp;

		call allows "let-bindings"
		let-bindings do not have a body

		exp "," ws exp - comma as in C

		exp "^" ws exp

		"let" id = exp;
		for(id = exp (, id = exp)+) exp

		intersection_for(id = exp (, id = exp)+) exp

		"$" id -- special variables

		if without else

		"function" id "(" pars" ")" "=" exp ";"
*/
	>>);

	/*
	The most important is the call syntax with argument names.
	*/
}
