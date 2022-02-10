// Adds range syntax like:  1..5 for an array [1,2,3,4,5]
{
	registerDslParserExtension("range", <<
		postfix = postfix | ".." ws exp $"range_2";
	>>);

	registerDslRewriting("desugar", "range", "lambda+range", "lambda", ";", <<
			$e1 .. $e2 => range($e1, $e2);
		>>, <<
			range => 1000000;
		>>,
		<< 0 >>
	);

	registerDslRuntime("range", "lambda", << "range" >>);
}
